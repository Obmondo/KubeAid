# Technical details on the features

### GitOps setup and change detection

**All** changes in a cluster are done via Git AND we detect if anyone adds anything in cluster or modifies existing
resources without doing it through Git.

We use ArgoCD to do this, which means we are able to alert on anything being out of sync with (or unmanaged by) Git.

Read our detailed guide on **[GitOps Drift Detection and Alerting](./gitops-drift-detection.md)** to learn how to:
- Detect unmanaged resources
- Configure alerts for out-of-sync applications
- Interpret sync status and drift types

### Auto-scaling for all cloud Kubernetes clusters and easy scaling for physical servers

We currently have working autoscale for Amazon Web Services (AWS).

**TODO:** Get autoscaling working for Azure Kubernetes Service (AKS) and Google Cloud Platform (GCP).

### Manage an ever-growing list of Open Source Kubernetes applications (see [`argocd-helm-charts`](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/) folder for a list)

We use upstream Helm charts preferably - and use the Helm Umbrella pattern in ArgoCD - so the 'root' application,
manages the rest of the applications in a cluster.

Learn more in our **[Helm Umbrella Pattern documentation](./helm-umbrella-pattern.md)**.

### Build advanced, customised Prometheus monitoring using just a per-cluster config file

We use [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus), and CI in repo automatically builds a new setup for all managed Kubernetes clusters, and submits PR to
your 'kubernetes-config' repo - when changes are made (by doing `git pull` on repo - so you get our latest improvements).

You can also adjust your settings for Prometheus per-cluster - in your `kubernetes-config` repo, and trigger a CI
rebuild in this repo, to get an updated build PR generated - which can then be sync'ed to production.

See our **[Prometheus Configuration Guide](./prometheus-configuration.md)** for details on:
- Customising scraping rules
- Adding custom dashboards
- Configuring Alertmanager
- Automatic CI/CD updates

We currently have CI support for GitLab and GitHub Actions.

**TODO:** Implement Robusta to automate handling of trivial tasks, like increasing size of a PVC (and running disk cleanup
scripts first to try and avoid it), or scaling up instead.

### Regular application updates with security and bug fixes, ready to be issued to your cluster(s) at will

We update this repository with updated versions of the applications, and improvements - which you will get automatically
if you have a subscription with [Obmondo](https://obmondo.com), or you can just `git pull` to get.

Once your copy of this repo is updated, ArgoCD will notice and register which applications have updates waiting, and you
can go view exact diff this update will cause on your cluster (`app diff`) or just sync it into production.

### Air-gapped operation of your clusters, to ensure operational stability

We maintain a copy of everything needed to set up your cluster (or do full recovery) in this repo, and run regular
backups of PVCs.

**TODO:** Maintain copy of all used Docker images and override images on all charts used to use that instead.

### Cluster security

Ensuring least privilege between applications in your clusters, via resource limits and per-namespace/per-pod firewalling.

We use Calico and NetworkPolicy resources to firewall each pod, so they cannot access anything in the cluster that they
do not need to.

This protects against a pod compromise and WHEN we block traffic from a pod, it triggers an event in the namespace that raises an alert, so
the application developers can see what happened AND it enables us to detect pod compromises.

### Backup, recovery and live-migration of applications or entire clusters

We use Velero to do regular backups of cluster and PVC data.

On AWS we have snapshot scripts to do regular and quick PVC backups.

**TODO:** Get live cluster migration working - hopefully Calico team will soon enable multi-cluster mesh - so we can get
start writing it.

### Major cluster upgrades, via a shadow Kubernetes setup utilising the recovery and live-migration features

**TODO:** Get live cluster migration working - hopefully Calico team will soon enable multi-cluster mesh - so we can get
start writing it.

### Supply chain attack protection and discovery - and security scans of all software used in the clusters

We currently store all Helm charts from upstream in the [KubeAid repository](https://github.com/Obmondo/KubeAid). Upon updates to newer versions, we generate a `git diff`, which we review for any unexpected changes. This means that we would ONLY be vulnerable to supply chain attacks when downloading charts, but we have CI comparing OUR copy of the charts in the version we run to the upstream chart repo version (which we download and diff regularly) - that way we will detect if anyone has changed the upstream chart code compared to the version we run - which could indicate a supply chain attack on the chart repo.

**TODO:** Add something like Threadmapper - to scan clusters for security issues

**TODO:** Add detection of in-use Docker images in cluster and cache all in local registry

**TODO:** Add vulnerability scanning of Docker images used