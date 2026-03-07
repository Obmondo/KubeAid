# Prerequisites

This guide helps you prepare everything needed to deploy a KubeAid-managed Kubernetes cluster.

## Common Dependencies

Before setting up any KubeAid cluster, ensure you have the following tools installed on your local machine:

### Required Software

- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) - Kubernetes command-line tool
- [`jq`](https://jqlang.org/download/) - JSON processor
- [`terragrunt`](https://terragrunt.gruntwork.io/docs/getting-started/install/) - Terraform wrapper
- [`terraform`](https://developer.hashicorp.com/terraform/install) - Infrastructure as Code tool
- [`bcrypt`](https://www.npmjs.com/package/bcrypt) - Password hashing utility
- [`wireguard`](https://www.wireguard.com/install/) - VPN software (optional)
- [`yq`](https://github.com/mikefarah/yq) - YAML processor

### Docker

Ensure [Docker](https://docs.docker.com/get-docker/) is installed and running locally.

### Git Repositories

1. **KubeAid Repository**: Fork/mirror [Obmondo/KubeAid](https://github.com/Obmondo/KubeAid).
2. **KubeAid Config Repository**: Fork [Obmondo/kubeaid-config](https://github.com/Obmondo/kubeaid-config).

### Git Provider Credentials

- **GitHub**: Personal Access Token (PAT)
- **GitLab**: Project Access Token or PAT

---

## Provider-Specific Prerequisites

Each provider has specific requirements. Please check the dedicated page for your chosen provider:

- [AWS Prerequisites](../providers/aws/prerequisites.md)
- [Azure Prerequisites](../providers/azure/prerequisites.md)
- [Hetzner Prerequisites](../providers/hetzner/prerequisites.md)
- [Bare Metal Prerequisites](../providers/bare-metal/prerequisites.md)
- [Local K3D Prerequisites](../providers/local-k3d/prerequisites.md)

After setting up prerequisites, check the **Features** for your provider if applicable:

- [AWS Features](../providers/aws/features.md)
- [Azure Features](../providers/azure/features.md)
- [Hetzner Features](../providers/hetzner/features.md)

Once you are ready, proceed to [Pre-Configuration](./pre-configuration.md) and then [Bootstrap](./bootstrap.md).

