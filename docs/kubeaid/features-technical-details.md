# Technical details on the features

## GitOps setup and change detection

**All** changes in a cluster are done via Git AND we detect if anyone adds anything in cluster or modifies existing
resources without doing it through Git.

We use ArgoCD to do this, which means we are able to alert on anything being out of sync with (or unmanaged by) Git.

Read our detailed guide on **[GitOps Drift Detection and Alerting](./gitops-drift-detection.md)** to learn how to:

- Detect unmanaged resources
- Configure alerts for out-of-sync applications
- Interpret sync status and drift types

### Auto-scaling for all cloud Kubernetes clusters and easy scaling for physical servers

We currently have working autoscale for Amazon Web Services (AWS). On AKS, agent pools are scaled by AKS's
built-in cluster autoscaler.

KubeAid also supports the managed control planes on EKS and AKS: it can bootstrap and delete such clusters, and
upgrades are done as a version bump in your GitOps repository.

### Manage an ever-growing list of Open Source Kubernetes applications

See the [`argocd-helm-charts`](../../argocd-helm-charts/) folder for the full list of applications.

We use upstream Helm charts preferably - and use the Helm Umbrella pattern in ArgoCD - so the 'root' application,
manages the rest of the applications in a cluster.

Learn more in our **[Helm Umbrella Pattern documentation](./helm-umbrella-pattern.md)**.

### Build advanced, customised Prometheus monitoring using just a per-cluster config file

We use [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), and CI in repo automatically builds a
new setup for all managed Kubernetes clusters, and submits PR to
your 'kubernetes-config' repo - when changes are made (by doing `git pull` on repo - so you get our latest
improvements).

You can also adjust your settings for Prometheus per-cluster - in your `kubernetes-config` repo, and trigger a CI
rebuild in this repo, to get an updated build PR generated - which can then be sync'ed to production.

See our **[Prometheus Configuration Guide](./prometheus-configuration.md)** for details on:

- Customising scraping rules
- Adding custom dashboards
- Configuring Alertmanager
- Automatic CI/CD updates

We currently have CI support for GitLab and GitHub Actions.

### Regular application updates with security and bug fixes, ready to be issued to your cluster(s) at will

We update this repository with updated versions of the applications, and improvements - which you will get automatically
if you have a subscription with [Obmondo](https://obmondo.com), or you can just `git pull` to get.

Once your copy of this repo is updated, ArgoCD will notice and register which applications have updates waiting, and you
can go view exact diff this update will cause on your cluster (`app diff`) or just sync it into production.

### Air-gapped operation of your clusters, to ensure operational stability

We maintain a copy of everything needed to set up your cluster (or do full recovery) in this repo, and run regular
backups of PVCs.

Container images are redirected to your own Harbor registry by the `harbor-proxy-cache-mutate` Kyverno policy
(shipped in the kyverno chart), which mutates image references at admission time - no per-chart image overrides
needed. A fully disconnected install (every image pre-mirrored, with no upstream access at all) is on the
[roadmap](../../ROADMAP.md).

### Cluster security

Ensuring least privilege between applications in your clusters, via resource limits and per-namespace/per-pod
firewalling.

We use Cilium and NetworkPolicy resources to firewall each pod, so they cannot access anything in the cluster that they
do not need to.

This protects against a pod compromise and WHEN we block traffic from a pod, it triggers an event in the namespace that
raises an alert, so
the application developers can see what happened AND it enables us to detect pod compromises.

### Backup, recovery and live-migration of applications or entire clusters

We use Velero to do regular backups of cluster and PVC data.

On AWS we have snapshot scripts to do regular and quick PVC backups.

**TODO:** Get live cluster migration working - for example built on Cilium's Cluster Mesh multi-cluster support.

### Major cluster upgrades, via a shadow Kubernetes setup utilising the recovery and live-migration features

**TODO:** Get live cluster migration working - for example built on Cilium's Cluster Mesh multi-cluster support.

### Supply chain attack protection and discovery - and security scans of all software used in the clusters

We store all upstream Helm charts vendored in the [KubeAid repository](https://github.com/Obmondo/KubeAid). Chart
updates arrive as a pull request whose `git diff` is reviewed for unexpected changes before merging, and clusters
deploy from your own mirror — so what runs is exactly the code that was reviewed, never something fetched live from
an upstream registry at deploy time. The window for a supply-chain attack is limited to the moment a chart update is
downloaded, and the update diff review is the checkpoint that catches it.

Complementing this, in-cluster scanning ships as charts:

- [trivy-operator](../../argocd-helm-charts/trivy-operator/README.md) with
  [version-checker](../../argocd-helm-charts/version-checker/README.md) scans running images for vulnerabilities and
  alerts when a fixable CVE has an upgrade available (`cluster.security.vulnerabilityScanning`).
- [kubescape-operator](../../argocd-helm-charts/kubescape-operator/README.md) scans cluster configuration and
  workloads for security issues.
- [Harbor](../../argocd-helm-charts/harbor/README.md) with the
  [kyverno](../../argocd-helm-charts/kyverno/README.md) proxy-cache policy caches in-use images in your own
  registry, on clusters that deploy Harbor.
