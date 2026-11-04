# Bootstrap add-ons from a ClusterResourceSet

Status: proposed. This page is the plan; nothing in it is implemented yet.

## Why

The Hetzner control-plane template
(`argocd-helm-charts/capi-cluster/charts/hetzner/templates/KubeadmControlPlane.yaml`) installs the first add-ons
from `postKubeadmCommands`. It downloads Helm (`curl .../get-helm-4 | bash`), clones KubeAid at
`global.kubeaid.version`, and pipes `helm template` into `kubectl apply` for Cilium, the Hetzner CCM (`ccm-hcloud`
and/or `ccm-hetzner`, by `mode`), kubelet-csr-approver (bare-metal, hybrid) and hetzner-robot (bare-metal with a
failover IP). The aws and azure templates do the same for Cilium and their CCM.

KubeadmControlPlane runs `postKubeadmCommands` on every control-plane machine: the one that runs `kubeadm init`, and
every later `kubeadm join` (scale-up, rollout, remediation, reinstall). So each replacement control plane re-applies
those charts with chart-default values onto a live cluster, overwriting what Argo CD manages and rolling the Cilium
agents. Reboots don't re-run it, since cloud-init runs `runcmd` once per instance.

[#461](https://github.com/Obmondo/KubeAid/pull/461) (commit `864d80b8d`, released in 34.0.2) gated each install on
a marker ConfigMap (`<name>-bootstrapped` in `default`), and replaced Cilium's `k8sServiceHost=${API_SERVER_HOST}`
with a hardcoded `10.0.0.2` (port 6443). Clusters created before 34.0.2 have no markers, so their next control-plane
replacement re-applies Cilium pointing at `10.0.0.2`. The aws and azure templates have no markers.

The underlying problem is a per-machine hook doing a once-per-cluster job. Cluster API has a native mechanism for that.

## Today vs proposed

```text
Today: on every control-plane machine (kubeadm init, and every kubeadm join)
  cloud-init runcmd -> kubeadm init|join -> postKubeadmCommands
    curl get-helm | bash, git clone KubeAid
    helm template <chart> | kubectl apply    cilium, CCM(s), kubelet-csr-approver, hetzner-robot
                                             (skipped only where a marker exists, since #461)

Proposed: once per cluster, from the management cluster
  KubeAid CI     helm template <chart> -> charts/hetzner/files/bootstrap/*.yaml (committed)
  capi-cluster   ConfigMaps (those files, API endpoint) + ClusterResourceSet (ApplyOnce) -> selects the Cluster
  Cluster API    first API server answers -> creates missing objects -> records them in ClusterResourceSetBinding
  kubeadm join   node-level steps only
  Argo CD        adopts the objects and manages them from then on
```

## Proposal

1. A script in `bin/` runs `helm template` on KubeAid's own `cilium`, `ccm-hetzner` (the hcloud and robot variants
   each mode needs) and `kubelet-csr-approver` charts with bootstrap values. It writes plain YAML, plus the `cilium`
   Namespace, into `argocd-helm-charts/capi-cluster/charts/hetzner/files/bootstrap/`.
2. The hetzner chart turns those files into ConfigMaps, with `argocd.argoproj.io/sync-options: ServerSideApply=true`
   on the large ones because the client-side last-applied annotation is capped at 256 KiB. It adds a small templated
   ConfigMap holding the cluster's API endpoint, a label on the Cluster, and an `ApplyOnce` ClusterResourceSet that
   selects it.
3. The postKubeadm add-on block goes: the Helm download, the clone, the installs, the markers and `API_SERVER_*`.
   Node-level steps stay: the Floating IP bind on bare-metal joins, the load-balancer label removal on worker-less
   clusters, the package installs. hetzner-robot is left to Argo CD alone: it moves the failover IP between control
   planes, so it has nothing to do before a second one exists.
4. `.github/workflows/update-helm-chart.yml` runs the script after `bin/manage-helm-chart.sh --update-all`, and a CI
   check re-renders and fails if the committed files differ.
5. Existing clusters: a new ClusterResourceSet also applies to existing matching clusters, but only creates missing
   objects, and removing the block from the KubeadmControlPlane spec rolls the control planes once. So the bootstrap
   set must hold only objects that every cluster of that mode runs.

Cilium endpoint: `k8sServiceHost: auto` (Cilium 1.20.4, the vendored version) is a Helm `lookup`. It only resolves
during a real `helm install` and fails under `helm template`. The render sets `k8sServiceHostRef: {name, key}`
instead, so the agent, envoy and operator pods read `KUBERNETES_SERVICE_HOST` from that ConfigMap (in the `cilium`
namespace) at runtime. The chart templates the value per cluster, for example `192.0.2.10`. `k8sServicePort` stays
static: 6443, as in `HetznerCluster.yaml`.

## Why ClusterResourceSet

- Core Cluster API (`addons.cluster.x-k8s.io`), no extra provider. GA since v1.10, on by default in v1.11 (KubeAid's
  `cluster-api-operator` chart pins v1.11.11), and always on from v1.12, where the feature gate was removed.
- It selects Clusters by label and applies as soon as the workload API server answers after the first
  `kubeadm init`, with no CNI or Ready nodes needed. Cluster API's own e2e tests install their CNI this way.
- `ApplyOnce` does a `Create` and ignores AlreadyExists, so it never modifies an existing object. The Cluster API
  design proposal recommends it when an operator, here Argo CD, takes over afterwards.
- Applied state lives in the ClusterResourceSetBinding spec and survives `clusterctl move`.
- No templating: manifests are plain YAML in ConfigMap `.data`, at most 1 MiB per ConfigMap. Hence the pre-render.
- Precedent: cluster-api-provider-aws's default `templates/cluster-template.yaml` labels the Cluster `ccm: external`
  and `csi: external`, and two `ApplyOnce` sets (`crs-ccm`, `crs-csi`) install the rendered AWS CCM and EBS CSI
  manifests. None of its templates install add-ons from `postKubeadmCommands`.

Alternative considered: the Cluster API Add-on Provider for Helm (`HelmChartProxy` with
`reconcileStrategy: InstallOnce`, API `v1alpha1`). It runs real Helm with a `valuesTemplate`, but it is an extra
provider, needed in the bootstrap cluster and in every self-managed cluster after the move. On existing clusters,
whose objects lack Helm ownership metadata, the install fails and retries forever, and `takeOwnership` would
overwrite them instead. KubeAid's wrapper charts are not in an OCI registry either (only `kubeaid-addons` is), so it
would pull the upstream charts.

## Follow-ups

- The same change for the aws and azure charts.
- A KubeAid ↔ kubeaid-cli compatibility declaration: a file in KubeAid stating the minimum kubeaid-cli version,
  enforced by the CLI, with the compatibility table in the docs generated from it.
- Until this lands, a separate small fix: run the in-node installs only where `kubeadm init` ran, and restore
  `${API_SERVER_HOST}`/`${API_SERVER_PORT}` in place of `10.0.0.2`.

## Open questions

- Exact bootstrap values per mode (hcloud, bare-metal, hybrid).
- Size of the rendered Cilium manifest against the 1 MiB ConfigMap limit.
- The endpoint when CAPH creates the HCloud load balancer (`controlPlane.hcloud.loadBalancer.enabled`, the default):
  CAPH fills in the load balancer's address at runtime, so `controlPlane.endpoint.host` is unset and the chart has
  no value to template.
- The CCM credentials Secret (`kube-system/cloud-credentials`, created by kubeaid-cli) stays a bootstrap dependency,
  unchanged.
