# Upgrading a hybrid Hetzner cluster (Kubernetes + OS)

How to take a `mode: hybrid` Hetzner cluster — HCloud control-plane VMs plus
bare-metal workers joined over a Robot vSwitch — through a Kubernetes and/or
Ubuntu upgrade.

This is a **manual, node-by-node operation**. ArgoCD alone cannot do it: the
resources that carry the Kubernetes version and the OS image are immutable in
CAPI, and bare-metal workers are standalone `Machine` objects with no
`MachineDeployment` above them, so nothing rolls them for you.

Every command below uses `--context <cluster>` and namespace `capi-cluster`;
adjust if your `global.capiClusterNamespace` differs. Replace `<cluster>`,
`<serverID>` and node names with your own.

---

## What actually changes what

| You want to change | Where it lives | How it reaches the node |
|---|---|---|
| Kubernetes version | `global.kubernetes.version` | `KubeadmControlPlane` / `Machine` `spec.version` |
| HCloud (control-plane) OS | `hetzner.hcloud.imageName` | `HCloudMachineTemplate` — **immutable**, delete + recreate |
| Bare-metal (worker) OS | `hetzner.bareMetal.installImage.imagePath` | `HetznerBareMetalMachine` — **immutable**, only applied on re-provision |

Omitting `imageName` / `imagePath` makes the chart defaults apply, which is
usually what you want when following a KubeAid release.

> **`wipeDisks` must stay `false`.** OS upgrades reuse the installimage path, and
> `wipeDisks: true` secure-erases *every* disk on the node — including the Ceph
> OSD partitions and the ZFS pool. See
> [bare-metal provisioning](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/bare-metal-provisioning.md).

---

## Before you start

**1. Validate the values file renders.** Chart schemas change between releases,
and a rejected schema is much cheaper to find locally than mid-sync:

```shell
helm template -f values.yaml -f <kubeaid-config>/k8s/<cluster>/argocd-apps/values-capi-cluster.yaml \
  argocd-helm-charts/capi-cluster
```

A typical failure after a chart bump:

```
Error: values don't meet the specifications of the schema(s) in the following chart(s):
hetzner:
- at '/hcloud': additional properties 'hetznerNetwork' not allowed
```

**2. Diff before you sync**, and read every removal — a values file written for
an older chart can silently drop settings (for example narrowing
`controlPlane.regions` from three regions to one):

```shell
argocd app diff capi-cluster --refresh
```

**3. Check cluster health.** Ceph must be fully clean before you start, and
again between every node:

```shell
kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
```

Expect `HEALTH_OK`, 3 mons in quorum, all OSDs `up`/`in`, all PGs
`active+clean`.

**4. Confirm capacity.** Each worker you take out must fit on the survivors:

```shell
kubectl --context <cluster> top nodes
```

---

## Step 1 — Update values and sync

Edit `values-capi-cluster.yaml`, commit, and sync the `capi-cluster` app.

**The sync will report partial failure. This is expected.** Immutable resources
are rejected by the admission webhooks:

```
admission webhook "validation.hcloudmachinetemplate.infrastructure.x-k8s.io" denied the request:
HCloudMachineTemplate.Spec is immutable
```

Everything else applies. The `HetznerBareMetalMachine` entries stay `OutOfSync`
until each node is re-provisioned, dropping off one at a time as you work
through them.

---

## Step 2 — Upgrade the control plane

A Kubernetes version bump reaches `KubeadmControlPlane.spec.version` through the
sync and the KCP rolls machines on its own — one at a time, oldest first.

Watch it:

```shell
kubectl --context <cluster> -n capi-cluster get kcp -w
kubectl --context <cluster> -n capi-cluster get machines -w
```

Done when `DESIRED` = `CURRENT` = `READY` = `UP-TO-DATE`.

### If you are also changing the control-plane OS

`HCloudMachineTemplate` is immutable, so the image change never applied. Delete
the template so ArgoCD can recreate it, then force a roll:

```shell
# 1. delete the immutable template (safe — it is only a stamp for new machines;
#    running machines are unaffected)
kubectl --context <cluster> -n capi-cluster delete hcloudmachinetemplate <cluster>-control-plane

# 2. sync capi-cluster in ArgoCD — recreates it with the new imageName

# 3. verify the new image landed
kubectl --context <cluster> -n capi-cluster get hcloudmachinetemplate <cluster>-control-plane \
  -o jsonpath='{.spec.template.spec.imageName}{"\n"}'
```

**Recreating the template does not roll anything.** The KCP keeps the same
template *name*, so its spec is unchanged and the controller sees nothing to do.
Force the roll explicitly:

```shell
# CAPI v1beta2
kubectl --context <cluster> -n capi-cluster patch kcp <cluster>-control-plane \
  --type merge -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}"
```

> **Field name changed in v1beta2.** It is `spec.rollout.after`, not the older
> `spec.rolloutAfter`. Patching the old name **silently does nothing** — you get
> `Warning: unknown field "spec.rolloutAfter"` and `(no change)`. Check with
> `kubectl explain kubeadmcontrolplane.spec.rollout`.

`clusterctl alpha rollout restart kubeadmcontrolplane/<name> -n capi-cluster`
works too.

---

## Step 3 — Upgrade bare-metal workers, one at a time

Bare-metal workers are standalone `Machine` objects owned directly by the
`Cluster`. There is no `MachineDeployment`, so **no controller will ever replace
them** — patching `spec.version` is inert bookkeeping. The OS and cloud-init
changes only take effect when a node is re-provisioned, which means: delete the
`Machine`, then sync to recreate it.

> **Strictly one node at a time.** Each worker typically holds a Ceph mon and
> its OSDs. The OSD partitions survive a re-image (installimage only touches
> EFI/`/boot`/`vg0`), but `/var/lib/rook` lives on the root volume and is
> destroyed, so the node's mon is lost and recreated. With one node down quorum
> is 2 of 3; with two down you lose quorum and all storage stalls.

### 3a. Pre-flight for this node

**Stop Ceph rebalancing** for the maintenance window:

```shell
kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd set noout
```

**Clear orphaned VolumeAttachments.** Attachments whose PV no longer exists can
never be detached, and they deadlock machine deletion later (see
[Troubleshooting](#machine-deletion-stuck-at-waitingforvolumedetach)). Clear
them *before* draining:

```shell
PVS=$(kubectl --context <cluster> get pv -o jsonpath='{.items[*].metadata.name}')
kubectl --context <cluster> get volumeattachments -o json | python3 -c "
import json,sys
pvs=set('''$PVS'''.split())
for v in json.load(sys.stdin)['items']:
    if v['spec']['nodeName']=='<node>' and v['spec']['source'].get('persistentVolumeName') not in pvs:
        print(v['metadata']['name'])
"
```

Remove the stale finalizer on each name printed:

```shell
kubectl --context <cluster> patch volumeattachment <name> --type merge \
  -p '{"metadata":{"finalizers":null}}'
```

**Find pods in deleted namespaces.** A pod whose namespace no longer exists
makes the CAPI drain fail outright (`Pod Namespace does not exist`) and blocks
deletion indefinitely:

```shell
for ns in $(kubectl --context <cluster> get pods -A -o wide \
    --field-selector spec.nodeName=<node> --no-headers | awk '{print $1}' | sort -u); do
  kubectl --context <cluster> get ns "$ns" >/dev/null 2>&1 || echo "DEAD NAMESPACE: $ns"
done
```

Force-delete anything found:

```shell
kubectl --context <cluster> delete pod -n <ns> <pod> --force --grace-period=0
```

**Deal with single-instance databases.** CloudNativePG creates a
zero-disruption PDB per primary, which blocks eviction forever. List them:

```shell
kubectl --context <cluster> get pdb -A --no-headers | awk '$5==0 {print $1"/"$2}'
```

Multi-instance clusters fail over cleanly if you delete the pod on this node.
Single-instance clusters take a short outage — delete the pod so it reschedules
elsewhere before draining.

**Scale down anything that tolerates every taint.** `kube-state-metrics` in
particular tolerates all taints, so it reschedules straight back onto the node
being drained (a drained node looks like the emptiest one) and blocks the drain
in a loop:

```shell
kubectl --context <cluster> -n kube-system scale deploy kube-state-metrics --replicas=0
```

Scale it back to 1 **only after** the node is provisioned again.

### 3b. Drain, delete, recreate

```shell
kubectl --context <cluster> drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=900s

kubectl --context <cluster> -n capi-cluster delete machine <cluster>-general-<serverID>
```

Deleting the `Machine` cascades to its `KubeadmConfig` and
`HetznerBareMetalMachine`, and CAPH deprovisions the Robot server. Wait until
the host is released:

```shell
kubectl --context <cluster> -n capi-cluster get hetznerbaremetalhost <serverID> -w
```

Released means empty `provisioningState` and no `consumerRef`:

```shell
kubectl --context <cluster> -n capi-cluster get hetznerbaremetalhost <serverID> \
  -o jsonpath='state:{.spec.status.provisioningState} consumer:{.spec.consumerRef.name}{"\n"}'
```

> **A `deletionTimestamp` is irreversible.** There is no un-delete. Uncordoning a
> node whose Machine is being deleted is pointless — the CAPI machine controller
> re-cordons it within seconds as part of its drain.

Then **sync these three resources** in the `capi-cluster` app to recreate them:

- `cluster.x-k8s.io/Machine/<cluster>-general-<serverID>`
- `bootstrap.cluster.x-k8s.io/KubeadmConfig/<cluster>-general-<serverID>`
- `infrastructure.cluster.x-k8s.io/HetznerBareMetalMachine/<cluster>-general-<serverID>`

Syncing only the `HetznerBareMetalMachine` does nothing useful — CAPH has no
`Machine` to act on.

### 3c. Watch it provision

```shell
kubectl --context <cluster> -n capi-cluster get hetznerbaremetalhost <serverID> -w
kubectl --context <cluster> get node <node> -o wide
```

The host walks `registering → image-installing → ensure-provisioned →
provisioned`. Budget **15–35 minutes**, with a quiet stretch while installimage
writes the image — that is normal, not a hang. The node object only appears once
`kubeadm join` succeeds.

### 3d. Verify before touching the next node

```shell
kubectl --context <cluster> get node <node> \
  -o custom-columns='NAME:.metadata.name,OS:.status.nodeInfo.osImage,KUBELET:.status.nodeInfo.kubeletVersion'

kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
```

Wait for **3 mons in quorum, all OSDs up, all PGs `active+clean`**. Then clear
the flag and move on:

```shell
kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd unset noout
```

Leaving `noout` set between windows is worse than useless — it stops Ceph
self-healing if a real OSD fails.

---

## Troubleshooting

### Machine deletion stuck at `WaitingForVolumeDetach`

```shell
kubectl --context <cluster> -n capi-cluster get machine <machine> \
  -o jsonpath='{.status.conditions[?(@.type=="Deleting")].message}{"\n"}'
```

```
VolumeAttachment with .spec.source.persistentVolumeName not matching a PersistentVolume: pvc-…
```

The PV is gone, so the external-attacher can never build the CSI unpublish call.
It retries forever and never drops its
`external-attacher/…` finalizer, while CAPI refuses to proceed. Clear the stale
finalizers as in [3a](#3a-pre-flight-for-this-node) — deletion resumes
immediately. This is a **pre-existing leak**, not something the upgrade causes;
check for it before every drain.

### Machine deletion stuck at `DrainingNode`

```shell
kubectl --context <cluster> -n capi-cluster logs deploy/capi-controller-manager --tail=200 | grep <node>
```

Two common causes:

- `failed to get Pods for eviction: Pods with error "Pod Namespace does not exist": <ns>/<pod>` —
  an orphaned pod in a deleted namespace. Force-delete it.
- `Pod …: deletionTimestamp set, but still not removed from the Node` — usually
  a pod that tolerates all taints being recreated on the node. Scale its
  controller to 0.

### Node provisioned but never joins (`ensure-provisioned` forever)

```shell
kubectl --context <cluster> -n capi-cluster get hetznerbaremetalmachine <machine> \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}{"\n"}'
```

```
failed to get cloud init output: command of CloudInitStatus failed (ssh connection worked): status: error
```

SSH works, so the OS installed — cloud-init's `runcmd` failed. Get the real
error from the node:

```shell
ssh root@<public-ip> 'cloud-init status --long; grep -iE "error|fail" /var/log/cloud-init-output.log | tail -30'
```

To recover a node in this state without a full re-provision:

```shell
# networking is up by now, so the failed steps succeed on a re-run
ssh root@<public-ip> 'sh /var/lib/cloud/instance/scripts/runcmd > /tmp/rerun.log 2>&1; echo EXIT=$?; tail -20 /tmp/rerun.log'
```

CAPH will still refuse to advance, because `cloud-init status` keeps reporting
the original failure. That status is **persistent** —
`/run/cloud-init/status.json` is a symlink to `/var/lib/cloud/data/status.json`,
so a reboot does not clear it. Clear the recorded error:

```shell
ssh root@<public-ip> 'cp -a /var/lib/cloud/data/status.json /var/lib/cloud/data/status.json.bak && python3 - <<PY && cloud-init status
import json
p="/var/lib/cloud/data/status.json"
d=json.load(open(p))
m=d["v1"]["modules-final"]
m["errors"]=[]
m["recoverable_errors"]={}
json.dump(d,open(p,"w"))
PY'
```

### CAPH not reacting after you fix something

The controller backs off exponentially — up to ~16 minutes after a long failure
streak. Force an immediate reconcile with a no-op annotation:

```shell
kubectl --context <cluster> -n capi-cluster annotate hetznerbaremetalhost <serverID> \
  reconcile-nudge="$(date +%s)" --overwrite
```

### `logs` / `exec` / `port-forward` fail on a re-provisioned node

```
Error from server: Get "https://10.0.1.x:10250/containerLogs/…": remote error: tls: internal error
```

kubelet has no serving certificate. Check the CSRs:

```shell
kubectl --context <cluster> get csr | grep -i denied | tail
kubectl --context <cluster> get csr <csr> -o jsonpath='{.status.conditions[0].message}{"\n"}'
```

Two different denials are possible:

**a) From CAPH** — `Validation by cluster-api-provider-hetzner failed: the IP
address "10.0.1.x" is not allowed`. CAPH's allow-list comes from the
`hardwareDetails` NIC snapshot taken in the **rescue system**, before cloud-init
creates the vSwitch VLAN, so the private IP can never be in it (upstream
[#2095](https://github.com/syself/cluster-api-provider-hetzner/issues/2095)).
KubeAid ships `kubelet-csr-approver` and passes `--disable-csr-approval` to CAPH
so this does not happen; if you see it, confirm the flag is live:

```shell
kubectl --context <cluster> -n capi-cluster get deploy caph-controller-manager \
  -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
```

**b) From kubelet-csr-approver** — `One of the SAN IP addresses, <public-ip>, is
not part of the allowed IP Prefixes/Subnets`. kubelet puts **both** its private
and public address in the SAN list, so `providerIpPrefixes` must contain the
private subnet **and** one `/32` per bare-metal host:

```yaml
kubelet-csr-approver:
  # single line, comma-separated, NO whitespace — entries go straight to
  # netip.ParsePrefix and a stray space crashes the controller at startup
  providerIpPrefixes: "10.0.0.0/16,<public-ip-1>/32,<public-ip-2>/32,<public-ip-3>/32"
  bypassDnsResolution: true
```

Denied CSRs are terminal. After fixing the cause, delete them so kubelet
resubmits:

```shell
kubectl --context <cluster> get csr -o name | xargs kubectl --context <cluster> delete
kubectl --context <cluster> get csr -w   # expect Approved,Issued
```

### ArgoCD app stuck in `ComparisonError`

```
Failed to load target state: … open …/values-<app>.yaml: no such file or directory
```

The app renders from a cached manifest and silently keeps running old
configuration. Check that the values `targetRevision` points at the branch where
the values file actually lives — mismatched refs are easy to miss because the
app still looks alive.

---

## Verification

```shell
# every node on the expected OS and version
kubectl --context <cluster> get nodes \
  -o custom-columns='NAME:.metadata.name,OS:.status.nodeInfo.osImage,KUBELET:.status.nodeInfo.kubeletVersion'

# storage fully healthy
kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

# no leftover maintenance flags
kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd dump | grep flags

# anything scaled down for the window is back
kubectl --context <cluster> -n kube-system get deploy kube-state-metrics
```

Finally, clear the crash reports that node rebuilds leave behind (they are
`client.admin` entries from the `osd-prepare` jobs, not daemon crashes):

```shell
kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph crash ls
kubectl --context <cluster> -n rook-ceph exec deploy/rook-ceph-tools -- ceph crash archive-all
```
