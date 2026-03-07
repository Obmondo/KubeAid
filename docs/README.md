# KubeAid Documentation

Welcome to the KubeAid documentation. This is the central hub for all KubeAid guides and references.

## Table of Contents

### Getting Started

The complete installation guide for setting up a KubeAid-managed Kubernetes cluster:

| Guide | Description |
|-------|-------------|
| [Getting Started Guide](./getting-started/README.md) | Complete installation walkthrough |
| [Prerequisites](./getting-started/prerequisites.md) | Required tools and setup |
| [Pre-Configuration](./getting-started/pre-configuration.md) | Configuration file setup |
| [Bootstrap](./getting-started/bootstrap.md) | Bootstrap your cluster |
| [Post-Configuration](./getting-started/post-configuration.md) | Access dashboards and verify setup |
| [Upgrade](./getting-started/upgrade.md) | Upgrade procedure |
| [Deletion](./getting-started/delete.md) | Cleanup procedure |

### Hosting Reference

Hosting-specific details and considerations:

| Guide | Description |
|-------|-------------|
| [Cloud Providers](./hosting/cloud-providers.md) | AWS, Azure, Hetzner HCloud |
| [Bare Metal](./hosting/bare-metal.md) | On-premise dedicated servers |
| [Single Host K8s](./hosting/single-host-k8s.md) | Single-node deployments |
| [Hybrid Setup](./hosting/hybrid-setup.md) | Mixed cloud and bare metal |

### Operations

Guides for ongoing cluster management:

| Guide | Description |
|-------|-------------|
| [Backup & Restore](./operations/backup-restore.md) | Disaster recovery procedures |
| [Node Reboot](./operations/node-reboot.md) | Safe node maintenance |
| [AWS Private Link Setup](./operations/aws-private-link-setup.md) | Cross-account connectivity |
| [Operations Tips](./operations/operations-tips.md) | Legacy operational procedures and debugging |

#### Monitoring

| Guide | Description |
|-------|-------------|
| [Pod Autoscaling](./operations/monitoring/pod-autoscaling.md) | HPA and VPA configuration |
| [Prometheus Namespaces](./operations/monitoring/prometheus-namespaces.md) | Namespace-level monitoring |

### Development

| Guide | Description |
|-------|-------------|
| [CI/CD Setup](./development/ci-cd-setup.md) | Pipeline configuration |
| [Helm Charts](./development/helm_charts.md) | Chart development |
| [Release Procedure](./development/release-procedure.md) | Release workflow |
| [Update ArgoCD Apps](./update_kubeaid_argocd_apps.md) | Updating deployed apps |

### Access Tokens

| Guide | Description |
|-------|-------------|
| [GitHub Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) | GitHub PAT setup |
| [GitLab Token](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html) | GitLab PAT setup |

### About KubeAid

| Guide | Description |
|-------|-------------|
| [Why KubeAid](./kubeaid/why-kubeaid.md) | The problem KubeAid solves |
| [Features Technical Details](./kubeaid/features-technical-details.md) | In-depth feature documentation |
| [Helm Umbrella Pattern](./kubeaid/helm-umbrella-pattern.md) | How KubeAid manages applications |
| [Prometheus Configuration](./kubeaid/prometheus-configuration.md) | Configuring monitoring with kube-prometheus |
| [GitOps Drift Detection](./kubeaid/gitops-drift-detection.md) | ArgoCD sync status and alerting |

## Support

For general questions, bug reports, and feature requests, please use our **[GitHub Issues](https://github.com/Obmondo/KubeAid/issues)**.

For enterprise support, visit [Obmondo](https://obmondo.com).
