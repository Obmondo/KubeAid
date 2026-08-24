# Upgrading a hybrid Hetzner cluster (Kubernetes + OS)

Manual, node-by-node checklist for a `mode: hybrid` Hetzner cluster (HCloud control-plane
VMs + bare-metal workers on a Robot vSwitch). ArgoCD cannot do this alone — the Kubernetes
version and OS image live on CAPI resources that are either immutable or only take effect
on re-provision, and bare-metal `Machine`s have no `MachineDeployment` to roll them for you.

All commands use `--context <cluster>`, namespace `capi-cluster`. Replace `<cluster>`,
`<serverID>`, `<node>` with your own.

## What changes what

| You want to change | Where it lives | How it reaches the node |
| --- | --- | --- |
| Kubernetes version | `global.kubernetes.version` | `KubeadmControlPlane` / `Machine` — rolls automatically |
| Control-plane OS | `hetzner.hcloud.imageName` | `HCloudMachineTemplate` — **immutable**, delete + recreate |
| Worker OS | `hetzner.bareMetal.installImage.imagePath` | `HetznerBareMetalMachine` — **immutable**, only applied on re-provision |

> **`wipeDisks` must stay `false`.** `true` secure-erases *every* disk on the node,
> including the Ceph OSD partitions and the ZFS pool.

---

## Before you start

- [ ] Render the chart against your values and catch schema breaks before you sync:

  ```shell
  helm template -f values.yaml -f <kubeaid-config>/k8s/<cluster>/argocd-apps/values-capi-cluster.yaml \
    argocd-helm-charts/capi-cluster
  ```

- [ ] `argocd app diff capi-cluster --refresh` — read every removal, not just additions. A
      values file written for an older chart can silently drop settings.
- [ ] `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status` → expect `HEALTH_OK`,
      3 mons in quorum, all OSDs `up`/`in`, all PGs `active+clean`.
- [ ] `kubectl top nodes` — confirm the survivors have room for each worker you take out.

---

## Step 1 — Update values and sync

- [ ] Edit `values-capi-cluster.yaml`, commit, sync the `capi-cluster` app.
- [ ] **Expect partial sync failure — this is normal.** Immutable resources are rejected by
      admission webhooks (`HCloudMachineTemplate.Spec is immutable`, etc.). Everything else
      applies; `HetznerBareMetalMachine` entries stay `OutOfSync` until each node is
      re-provisioned in Step 3.

---

## Step 2 — Upgrade the control plane

- [ ] A Kubernetes version bump reaches `KubeadmControlPlane.spec.version` through the sync,
      and KCP rolls machines on its own, one at a time. Watch:

  ```shell
  kubectl -n capi-cluster get kcp -w
  kubectl -n capi-cluster get machines -w
  ```

- [ ] Done when `DESIRED = CURRENT = READY = UP-TO-DATE`.

**Only if you're also changing the control-plane OS:**

- [ ] Delete the immutable template so ArgoCD can recreate it (safe — running machines are
      unaffected): `kubectl -n capi-cluster delete hcloudmachinetemplate <cluster>-control-plane`
- [ ] Sync `capi-cluster` again, then confirm the new image landed:
      `kubectl -n capi-cluster get hcloudmachinetemplate <cluster>-control-plane -o jsonpath='{.spec.template.spec.imageName}{"\n"}'`
- [ ] **Recreating the template does not roll anything by itself** — the KCP keeps the same
      template name and sees nothing to do. Force it:

  ```shell
  kubectl -n capi-cluster patch kcp <cluster>-control-plane --type merge \
    -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}"
  ```

  > v1beta2 field is `spec.rollout.after`, **not** `spec.rolloutAfter` — the old name
  > silently no-ops (`Warning: unknown field`, `(no change)`).
  > `clusterctl alpha rollout restart kubeadmcontrolplane/<name> -n capi-cluster` also works.

---

## Step 3 — Upgrade bare-metal workers, one at a time

> Each worker typically holds a Ceph mon + OSDs. Re-imaging destroys `/var/lib/rook` (root
> volume) even though the OSD partitions survive, so the node's mon is lost and recreated.
> **Never run this step on more than one node at once** — two nodes down loses quorum and
> stalls all storage.

### 3a. Pre-flight for this node

- [ ] `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd set noout`
- [ ] Clear orphaned `VolumeAttachment`s — a PV that's already gone leaves a finalizer that
      never clears and deadlocks the drain later:

  ```shell
  PVS=$(kubectl get pv -o jsonpath='{.items[*].metadata.name}')
  kubectl get volumeattachments -o json | python3 -c '
  import json, sys
  pvs = set("""'"$PVS"'""".split())
  for v in json.load(sys.stdin)["items"]:
      if v["spec"]["nodeName"] == "<node>" and v["spec"]["source"].get("persistentVolumeName") not in pvs:
          print(v["metadata"]["name"])'
  # for each name printed:
  kubectl patch volumeattachment <name> --type merge -p '{"metadata":{"finalizers":null}}'
  ```

- [ ] Check for pods in deleted namespaces on `<node>` — these make the drain fail outright:

  ```shell
  for ns in $(kubectl get pods -A -o wide --field-selector spec.nodeName=<node> --no-headers | awk '{print $1}' | sort -u); do
    kubectl get ns "$ns" >/dev/null 2>&1 || echo "DEAD NAMESPACE: $ns"
  done
  # force-delete anything found:
  kubectl delete pod -n <ns> <pod> --force --grace-period=0
  ```

- [ ] Check zero-disruption PDBs: `kubectl get pdb -A --no-headers | awk '$5==0 {print $1"/"$2}'`.
      Multi-instance DBs fail over cleanly; for a single-instance CloudNativePG cluster on
      this node, delete its pod so it restarts before you drain.
- [ ] `kubectl -n kube-system scale deploy kube-state-metrics --replicas=0` — it tolerates
      every taint and reschedules straight back onto the node being drained. Scale it back to
      1 only **after** the node is provisioned again.

### 3b. Drain, delete, recreate

- [ ] `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=900s`
- [ ] `kubectl -n capi-cluster delete machine <cluster>-general-<serverID>` — cascades to its
      `KubeadmConfig` and `HetznerBareMetalMachine`; CAPH deprovisions the Robot server.
      (A `deletionTimestamp` is irreversible — uncordoning the node is pointless, CAPI
      re-cordons it within seconds.)
- [ ] Wait until the host is released — empty `provisioningState`, empty `consumerRef`:

  ```shell
  kubectl -n capi-cluster get hetznerbaremetalhost <serverID> -w
  ```

- [ ] Sync **all three** resources in the `capi-cluster` app: `Machine`, `KubeadmConfig`, and
      `HetznerBareMetalMachine` for `<cluster>-general-<serverID>`. Syncing only the HBMM does
      nothing — CAPH needs a `Machine` to act on.

### 3c. Watch it provision

- [ ] `kubectl -n capi-cluster get hetznerbaremetalhost <serverID> -w` — walks
      `registering → image-installing → ensure-provisioned → provisioned`. Budget
      **15–35 minutes**; a quiet stretch during installimage is normal, not a hang.
- [ ] `kubectl get node <node> -o wide` — the node object only appears once `kubeadm join`
      succeeds.

### 3d. Verify before touching the next node

- [ ] `kubectl get node <node> -o custom-columns='NAME:.metadata.name,OS:.status.nodeInfo.osImage,KUBELET:.status.nodeInfo.kubeletVersion'`
- [ ] `ceph status` → 3 mons in quorum, all OSDs up, all PGs `active+clean`
- [ ] `ceph osd unset noout` — leaving it set stops Ceph self-healing between windows if a
      real OSD fails.

---

## Verification

- [ ] Every node on the expected OS and kubelet version (same custom-columns command as 3d,
      run against all nodes).
- [ ] `ceph status` clean, and `ceph osd dump | grep flags` shows no leftover flags.
- [ ] `kube-state-metrics` is back at 1 replica.
- [ ] `ceph crash ls` then `ceph crash archive-all` — clears the `osd-prepare` crash noise
      node rebuilds leave behind (these are `client.admin` entries, not real daemon crashes).

---

## Troubleshooting

Only needed if something above gets stuck.

### VolumeAttachment stuck

`Machine` deletion hangs at `WaitingForVolumeDetach`:

```shell
kubectl -n capi-cluster get machine <machine> \
  -o jsonpath='{.status.conditions[?(@.type=="Deleting")].message}{"\n"}'
# "VolumeAttachment with .spec.source.persistentVolumeName not matching a PersistentVolume: pvc-…"
```

The PV is gone, so the CSI external-attacher retries forever and never drops its finalizer —
a **pre-existing leak**, not something the upgrade causes. Run the same clear-finalizer
command as [3a pre-flight](#3a-pre-flight-for-this-node); deletion resumes immediately.

### Drain stuck (`DrainingNode`)

```shell
kubectl -n capi-cluster logs deploy/capi-controller-manager --tail=200 | grep <node>
```

- `Pod Namespace does not exist` → orphaned pod in a deleted namespace, same fix as
  [3a pre-flight](#3a-pre-flight-for-this-node).
- `deletionTimestamp set, but still not removed from the Node` → usually a pod tolerating
  every taint getting recreated on the node; scale its controller to 0.

### Node stuck at `ensure-provisioned` forever

```shell
kubectl -n capi-cluster get hetznerbaremetalmachine <machine> \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}{"\n"}'
# "failed to get cloud init output ... (ssh connection worked)"
```

SSH works, so the OS installed but cloud-init's `runcmd` failed. Get the real error, then
re-run it (networking is up by now, so failed steps often succeed):

```shell
ssh root@<public-ip> 'cloud-init status --long; grep -iE "error|fail" /var/log/cloud-init-output.log | tail -30'
ssh root@<public-ip> 'sh /var/lib/cloud/instance/scripts/runcmd > /tmp/rerun.log 2>&1; echo EXIT=$?; tail -20 /tmp/rerun.log'
```

CAPH still won't advance — `cloud-init status` persistently reports the *original* failure
(`/run/cloud-init/status.json` symlinks to `/var/lib/cloud/data/status.json`, survives
reboot). Clear the recorded error:

```shell
ssh root@<public-ip> 'cp -a /var/lib/cloud/data/status.json{,.bak} && python3 - <<PY && cloud-init status
import json
p = "/var/lib/cloud/data/status.json"
d = json.load(open(p))
m = d["v1"]["modules-final"]
m["errors"] = []
m["recoverable_errors"] = {}
json.dump(d, open(p, "w"))
PY'
```

### CAPH not reacting after you fix something

It backs off exponentially, up to ~16 minutes after a failure streak. Nudge it:

```shell
kubectl -n capi-cluster annotate hetznerbaremetalhost <serverID> \
  reconcile-nudge="$(date +%s)" --overwrite
```

### `logs` / `exec` / `port-forward` fail with `tls: internal error` on a re-provisioned node

kubelet has no serving certificate. Check denied CSRs:

```shell
kubectl get csr | grep -i denied | tail
kubectl get csr <csr> -o jsonpath='{.status.conditions[0].message}{"\n"}'
```

- **From CAPH** — `the IP address "10.0.1.x" is not allowed`. CAPH's allow-list is a
  pre-vSwitch NIC snapshot and can never include the private IP (upstream
  [#2095](https://github.com/syself/cluster-api-provider-hetzner/issues/2095)). KubeAid ships
  `kubelet-csr-approver` and passes `--disable-csr-approval` to CAPH so this shouldn't happen
  — confirm the flag is live:
  `kubectl -n capi-cluster get deploy caph-controller-manager -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'`
- **From kubelet-csr-approver** — `SAN IP … not part of the allowed IP Prefixes`. kubelet
  puts both private and public IP in the SAN list, so `providerIpPrefixes` needs the private
  subnet **and** one `/32` per bare-metal host:

  ```yaml
  kubelet-csr-approver:
    # single line, comma-separated, NO whitespace — feeds netip.ParsePrefix directly
    providerIpPrefixes: "10.0.0.0/16,<public-ip-1>/32,<public-ip-2>/32,<public-ip-3>/32"
    bypassDnsResolution: true
  ```

Denied CSRs are terminal — after fixing the cause, delete them so kubelet resubmits:

```shell
kubectl get csr -o name | xargs kubectl delete
kubectl get csr -w   # expect Approved,Issued
```

### ArgoCD app stuck in `ComparisonError`

`open …/values-<app>.yaml: no such file or directory` — the app is silently running a cached
manifest on old config. Check that `targetRevision` points at the branch where the values
file actually lives; mismatched refs are easy to miss because the app still looks alive.
