# Frequently Asked Questions

Answers to common questions from engineers evaluating or operating KubeAid. For step-by-step setup, start with the
[Getting Started guide](./getting-started/README.md); for symptom-driven fixes, see
[Troubleshooting](./troubleshooting.md).

## What is the difference between KubeAid, kubeaid-cli, and kubeaid-config?

Three pieces, three jobs. **KubeAid** (this repository) contains the curated Helm wrapper charts in
[`argocd-helm-charts/`](../argocd-helm-charts/) and templates - the software catalogue your clusters deploy from.
**kubeaid-config** is your own repository holding cluster-specific configuration: values files, ArgoCD Application
manifests, and sealed secrets, laid out per cluster under `k8s/<cluster-name>/`. **kubeaid-cli** is the command-line
tool that generates configuration and bootstraps, upgrades, and deletes clusters. See
[Prerequisites](./getting-started/prerequisites.md#git-repositories) for how the repositories relate and the
[Helm Umbrella Pattern](./kubeaid/helm-umbrella-pattern.md) for how they combine at runtime.

## Do I need to mirror the KubeAid repository?

Not to get started - the only repository you must create is your own kubeaid-config (from the
[sample template](https://github.com/Obmondo/kubeaid-config)); the platform repository is consumed from upstream by
default. Mirroring KubeAid is recommended for production: your cluster's ArgoCD Applications then point at *your*
mirror, so nothing lands on your cluster that you didn't pull into your own Git first, and updates only arrive when
you update the mirror. Upstream charts are vendored into the
repository, so what you deploy is exactly what was reviewed - a defence against supply-chain attacks. See
[Prerequisites](./getting-started/prerequisites.md#git-repositories).

## Why can't I commit to my mirror's master branch?

The master/main branch of your KubeAid mirror is used to deliver updates from upstream - local commits there will
conflict with incoming updates. All customization belongs in your kubeaid-config repository instead, which overrides
chart values per cluster. See the warning in
[Prerequisites](./getting-started/prerequisites.md#git-repositories) and the override mechanism in the
[Helm Umbrella Pattern](./kubeaid/helm-umbrella-pattern.md#customizing-an-application).

## How do updates reach my cluster?

Obmondo updates the upstream KubeAid repository with new application versions and improvements, published as
[release tags](https://github.com/Obmondo/KubeAid/releases). Your ArgoCD Applications consume KubeAid either
directly from the [Obmondo repository](https://github.com/Obmondo/KubeAid) or from your own fork, which you keep in
sync with `git fetch upstream --tags && git merge upstream/master`. Either way, a new release changes nothing on
the cluster by itself: every Application pins the KubeAid repository to a specific release tag (`targetRevision`).
To roll an update out, bump that pinned tag across all apps with
`bin/update-kubeaid-argocd-app.sh -c <cluster-name> -r <tag>` and push the resulting kubeaid-config change - only
then does ArgoCD mark the affected applications `OutOfSync`, and you can inspect the exact diff before syncing
during a service window. See
[Post-Configuration, Step 6](./getting-started/post-configuration.md#step-6-configure-updates) and
[Update KubeAid ArgoCD Apps](./operations/update-kubeaid-argocd-apps.md).

## Is auto-sync enabled - who actually applies changes?

ArgoCD continuously *detects* drift between Git and the cluster, but detection and application are separate steps.
An Application only applies changes automatically if its `syncPolicy.automated` (optionally with `selfHeal`) is set -
and `selfHeal` should be enabled carefully, since it reverts any manual change. The documented operational practice
for KubeAid app updates is human-driven: review the diff, then selectively sync only the out-of-sync resources
during a service window. See [GitOps Drift Detection](./kubeaid/gitops-drift-detection.md) and the
[service window guide](./operations/argocd-apps-service-window.md).

## What clouds and managed control planes are supported?

Self-managed clusters on AWS, Azure, and Hetzner (HCloud, bare metal, and hybrid) via ClusterAPI; managed control
planes on **AWS EKS** (via CAPA) and **Azure AKS** (via CAPZ); SSH-only bare metal via KubeOne; and local K3D for
development. Autoscaling (including scale to/from zero) is available on the API-managed clouds. See the provider
table in the [Getting Started guide](./getting-started/README.md#choosing-your-platform) and the
[hosting reference](./hosting/cloud-providers.md).

## How do I upgrade Kubernetes - and why is EKS/AKS different?

For self-managed clusters, edit `cluster.k8sVersion` in your `general.yaml` and run `kubeaid-cli cluster upgrade`;
the CLI upgrades the cluster to the declared Kubernetes version and machine images. On EKS and AKS, `cluster upgrade`
refuses to run because the control plane is owned by the cloud provider - instead you bump
`global.kubernetes.version` in `argocd-apps/values-capi-cluster.yaml` in your kubeaid-config repo and let ArgoCD
sync, after which CAPA/CAPZ upgrade the control plane and roll the node groups. See
[Basic Operations](./getting-started/basic-operations.md#cluster-upgrade).

## How are secrets handled?

With [sealed-secrets](../argocd-helm-charts/sealed-secrets/README.md): secrets are encrypted with the cluster
controller's public key before being committed to your kubeaid-config repository, and only the controller running in
the target cluster can decrypt them - so encrypted secrets are safe to store in Git. Note that the namespace is
cryptographically bound at seal time, and you should back up the controller's keys so recreated clusters can decrypt
existing sealed secrets. See
[Post-Configuration, Step 5](./getting-started/post-configuration.md#step-5-secret-management) and the
[backup/restore procedure](../argocd-helm-charts/sealed-secrets/README.md#how-to-backup-and-restore-sealed-secrets)
in the sealed-secrets README.

## What monitoring comes built in?

Every KubeAid cluster ships with [kube-prometheus](./kubeaid/prometheus-configuration.md): Prometheus for metrics,
Alertmanager for alert routing, and Grafana for dashboards, configured per cluster via a Jsonnet variables file. Log
monitoring is a separate, optional layer - one of OpenObserve, Graylog, or OpenSearch + Dashboards - running
alongside the metrics stack. See [Monitoring](./monitoring.md) for the full picture.

## Can KubeAid run air-gapped?

Partially, by design. The repository vendors everything needed to set up (or fully recover) a cluster - charts,
templates, and configuration - and regular PVC backups are part of the model. For container images, the kyverno
chart ships a `harbor-proxy-cache-mutate` ClusterPolicy that rewrites image references (docker.io, and optionally
ghcr.io and registry.k8s.io) to your own [Harbor](./guides/harbor-registry.md) registry at admission time, so
workloads pull through your registry instead of the upstream ones - no per-chart image overrides needed. A fully
disconnected install (every image pre-mirrored, with no upstream access at all) is still on the
[roadmap](../ROADMAP.md). See [Features Technical Details](./kubeaid/features-technical-details.md).

## What is a VPN-type cluster?

A cluster configured with `cluster.type: vpn`, which uses NetBird (with Keycloak) to put cluster access on a private
mesh network. After bootstrap, the public kube-apiserver load balancer is disabled and API access moves to the
NetBird mesh, so the generic kubeconfig flow doesn't apply - follow the
[post-bootstrap operator guide](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/post-bootstrap.md) instead.
The related `keycloak`, `netbird`, and `acme` secrets are described in
[Pre-Configuration](./getting-started/pre-configuration.md#keycloak--netbird--acme-vpn-type-clusters).

## Do I need Terraform or other infrastructure tooling?

No. `kubeaid-cli` bundles its tooling (K3D, Helm, clusterctl, KubeOne) as Go libraries, so you don't install
Terraform, Terragrunt, or similar tools. Your workstation needs `kubectl`, `jq`, `yq`, Docker, and optionally
`cilium-cli` (for `cluster test`) and WireGuard (for private cluster access). See
[Prerequisites](./getting-started/prerequisites.md#common-dependencies).

## Can I try KubeAid without a cloud account?

Yes - the local K3D deployment runs the whole stack in Docker on your machine at zero cost, using the same four-step
flow as the cloud providers. It is for testing only: local K3D clusters don't support cluster upgrades or disaster
recovery. See [Prerequisites](./getting-started/prerequisites.md#choose-your-deployment).

## Where do I get help?

For general questions, bug reports, and feature requests, use
[GitHub Issues](https://github.com/Obmondo/KubeAid/issues). For platform-level problems, check
[Troubleshooting](./troubleshooting.md) first, and for bootstrap failures the
[kubeaid-cli troubleshooting guide](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/troubleshooting.md).
Professional support for KubeAid-managed clusters is available from [Obmondo](https://obmondo.com).
