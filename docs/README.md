# KubeAid Documentation

Welcome to the KubeAid documentation.

**KubeAid gives you one way to install and operate Kubernetes on any cloud (or your own servers)**, with GitOps,
security, monitoring, and compliance built in from day one. It uses [Cluster API](https://cluster-api.sigs.k8s.io/) to
unify installation across providers — including managed EKS and AKS control planes — ships 100+ curated Helm charts
with best-practice defaults, and maps its security posture to ISO 27001:2022.

The documentation is organised by what you're trying to do: **learn** (Start Here), **solve a problem** (How-To &
Troubleshooting), **look something up** (Reference), or **understand** (Concepts).

→ New here? Start with [**Why KubeAid?**](./kubeaid/why-kubeaid.md) to understand the problem we solve, then follow the
[**Getting Started Guide**](./getting-started/README.md) to deploy your first cluster.

## Start Here

A guided journey from nothing to a running, GitOps-managed cluster — the local K3D path costs nothing and the workflow
is identical to production:

| Step | Guide | Description |
| ------ | ------- | ------------- |
| — | [Getting Started Guide](./getting-started/README.md) | The tutorial entry point: what you'll build, and the journey |
| 1 | [Prerequisites](./getting-started/prerequisites.md) | Required tools and provider access |
| 2 | [Pre-Configuration](./getting-started/pre-configuration.md) | Generate and review `general.yaml` / `secrets.yaml` |
| 3 | [Installation](./getting-started/installation.md) | Bootstrap your cluster |
| 4 | [Post-Configuration](./getting-started/post-configuration.md) | Access dashboards and verify setup |
| ✓ | [Basic Operations](./getting-started/basic-operations.md) | Day-to-day operations and cleanup |

## How-To & Troubleshooting

Problem-oriented guides for a running cluster:

| Guide | Description |
| ------- | ------------- |
| [Troubleshooting](./troubleshooting.md) | Symptom → cause → fix for common platform problems |
| [FAQ](./faq.md) | Short answers to the questions everyone asks |
| [Backup & Restore](./operations/backup-restore.md) | Disaster recovery procedures and backup health checks |
| [Backup Exporter](./guides/backup-exporter.md) | Alerting on Velero, PostgreSQL, MongoDB and Sealed Secrets backups |
| [Node Reboot](./operations/node-reboot.md) | Safe node maintenance |
| [Node Disk Repair](./operations/fixing-a-k8s-node-disk.md) | Replace and fix corrupted node disks |
| [ArgoCD Apps Service Window](./operations/argocd-apps-service-window.md) | Service windows and stakeholder communication for app updates |
| [Update KubeAid ArgoCD Apps](./operations/update-kubeaid-argocd-apps.md) | Rolling KubeAid application updates to a cluster |
| [CI/CD Setup](./guides/ci-cd-setup.md) | Pipeline configuration |
| [Cilium Host-Firewall](./guides/cilium-host-firewall.md) | Node-level network policy for bare-metal clusters |
| [CISO Assistant](./guides/ciso-assistant.md) | GRC compliance platform setup |
| [GitHub Token](./guides/access-token/github.md) | GitHub access-token setup |
| [GitLab Token](./guides/access-token/gitlab.md) | GitLab access-token setup |

## Hosting Reference

Provider-specific details and considerations:

| Guide | Description |
| ------- | ------------- |
| [Cloud Providers](./hosting/cloud-providers.md) | AWS (self-managed & EKS), Azure (self-managed & AKS), Hetzner HCloud |
| [Bare Metal](./hosting/bare-metal.md) | On-premise dedicated servers (KubeOne, SSH-only) |
| [Single Host K8s](./hosting/single-host-k8s.md) | Single-node deployments |
| [Hybrid Setup](./hosting/hybrid-setup.md) | Mixed cloud and bare metal |
| [Hetzner Server Buying Guide](./guides/hetzner-server-buy-guides.md) | Bare metal and HCloud server purchasing recommendations |
| [Harbor Registry](./guides/harbor-registry.md) | Host your own central container registry |

## Reference

| Guide | Description |
| ------- | ------------- |
| [Monitoring](./monitoring.md) | kube-prometheus metrics stack and log monitoring options (OpenObserve, Graylog, OpenSearch) |
| [Prometheus Configuration](./kubeaid/prometheus-configuration.md) | Per-cluster monitoring config: vars, namespaces, autoscaling, dashboards |
| [Application Catalogue](../argocd-helm-charts/) | The 100+ curated chart wrappers KubeAid can deploy |
| [Features Technical Details](./kubeaid/features-technical-details.md) | Implementation status of every feature |
| [Configuration Reference](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/config-reference.md) | Generated `general.yaml` / `secrets.yaml` schema (kubeaid-cli) |
| [SBOM](../sbom.md) | Software bill of materials for all chart images |

## Understanding KubeAid

Concept and design docs — why KubeAid works the way it does:

| Guide | Description |
| ------- | ------------- |
| [Why KubeAid](./kubeaid/why-kubeaid.md) | The problem KubeAid solves |
| [KubeAid Comparison](./kubeaid/comparison.md) | In-depth comparison with Terraform, Ansible, Puppet, and alternatives |
| [Helm Umbrella Pattern](./kubeaid/helm-umbrella-pattern.md) | How KubeAid packages and overrides applications |
| [GitOps Drift Detection](./kubeaid/gitops-drift-detection.md) | ArgoCD sync status, orphaned resources, and alerting |
| [Security Design](./kubeaid/security-design.md) | The security goals behind the platform's defaults |
| [Cluster Design](./cluster-design.md) | Control plane, storage, and database HA design principles |
| [Design Decisions](./kubeaid/decisions.md) | Technical choices and architectural evolution |
| [GitOps Decision Record](./kubeaid/decisions/gitops.md) | Real-world GitOps patterns and incident lessons |

## Maintainer Docs

For people working on KubeAid itself — see [CONTRIBUTING](../CONTRIBUTING.md) for the workflow:

| Guide | Description |
| ------- | ------------- |
| [Managing Helm Charts](./maintainers/manage-helm-charts.md) | Adding and updating the vendored chart wrappers |
| [Release Procedure](./maintainers/release.md) | Cutting a KubeAid release |

## Support

For general questions, bug reports, and feature requests, please use our
**[GitHub Issues](https://github.com/Obmondo/KubeAid/issues)**.

For enterprise support, visit [Obmondo](https://obmondo.com).
