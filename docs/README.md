# KubeAid Documentation

Welcome to the KubeAid documentation.

**KubeAid gives you one way to install and operate Kubernetes on any cloud (or your own servers)**, with GitOps,
security, monitoring, and compliance built in from day one. It uses [Cluster API](https://cluster-api.sigs.k8s.io/) to
unify installation across providers, ships 100+ curated Helm charts with best-practice defaults, and maps its security
posture to ISO 27001:2022.

→ New here? Start with [**Why KubeAid?**](./kubeaid/why-kubeaid.md) to understand the problem we solve, then follow the
[**Getting Started Guide**](./getting-started/README.md) to deploy your first cluster.

## Table of Contents

### Getting Started

> 🎬 **[Watch the Installation Video](https://drive.google.com/file/d/1d9EdghntjDoJRkCHj-DeRiEMfQ4xjBbw/view?usp=sharing)** - a step-by-step walkthrough of setting up KubeAid via KubeAid-cli.

The complete installation guide for setting up a KubeAid-managed Kubernetes cluster:

| Guide | Description |
| ------- | ------------- |
| [Getting Started Guide](./getting-started/README.md) | Complete installation walkthrough |
| [Prerequisites](./getting-started/prerequisites.md) | Required tools and setup |
| [Pre-Configuration](./getting-started/pre-configuration.md) | Configuration file setup |
| [Installation](./getting-started/installation.md) | Bootstrap your cluster |
| [Post-Configuration](./getting-started/post-configuration.md) | Access dashboards and verify setup |
| [Basic Operations](./getting-started/basic-operations.md) | Day-to-day operations and cleanup |

### Hosting Reference

Hosting-specific details and considerations:

| Guide | Description |
| ------- | ------------- |
| [Cloud Providers](./hosting/cloud-providers.md) | AWS, Azure, Hetzner HCloud |
| [Bare Metal](./hosting/bare-metal.md) | On-premise dedicated servers |
| [Single Host K8s](./hosting/single-host-k8s.md) | Single-node deployments |
| [Hybrid Setup](./hosting/hybrid-setup.md) | Mixed cloud and bare metal |

### Operations

Guides for ongoing cluster management:

| Guide | Description |
| ------- | ------------- |
| [Backup & Restore](./operations/backup-restore.md) | Disaster recovery procedures |
| [Node Reboot](./operations/node-reboot.md) | Safe node maintenance |
| [AWS Private Link Setup](./operations/aws-private-link-setup.md) | Cross-account connectivity |
| [Operations Tips](./operations/operations-tips.md) | Legacy operational procedures and debugging |

#### Monitoring

| Guide | Description |
| ------- | ------------- |
| [Pod Autoscaling](./operations/monitoring/pod-autoscaling.md) | HPA and VPA configuration |
| [Prometheus Namespaces](./operations/monitoring/prometheus-namespaces.md) | Namespace-level monitoring |

### Development

| Guide | Description |
| ------- | ------------- |
| [CI/CD Setup](./development/ci-cd-setup.md) | Pipeline configuration |
| [Helm Charts](./development/helm_charts.md) | Chart development |
| [Release Procedure](./guides/release.md) | Release workflow |
| [Update ArgoCD Apps](./update_kubeaid_argocd_apps.md) | Updating deployed apps |

### Access Tokens

| Guide | Description |
| ------- | ------------- |
| [GitHub Token](./access_token/github.md) | GitHub PAT setup |
| [GitLab Token](./access_token/gitlab.md) | GitLab PAT setup |

### About KubeAid

| Guide | Description |
| ------- | ------------- |
| [Why KubeAid](./kubeaid/why-kubeaid.md) | The problem KubeAid solves |
| [Features Technical Details](./kubeaid/features-technical-details.md) | In-depth feature documentation |
| [Helm Umbrella Pattern](./kubeaid/helm-umbrella-pattern.md) | How KubeAid manages applications |
| [Prometheus Configuration](./kubeaid/prometheus-configuration.md) | Configuring monitoring with kube-prometheus |
| [GitOps Drift Detection](./kubeaid/gitops-drift-detection.md) | ArgoCD sync status and alerting |

## Support

For general questions, bug reports, and feature requests, please use our **[GitHub Issues](https://github.com/Obmondo/KubeAid/issues)**.

For enterprise support, visit [Obmondo](https://obmondo.com).
