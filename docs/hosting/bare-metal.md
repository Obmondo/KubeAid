# Bare Metal (On-Premises)

The bare-metal provider provisions a KubeAid-managed Kubernetes cluster across your own Linux servers using **SSH-based access**. There is no cloud API host management-you manage the server lifecycle yourself.

> [!NOTE]
> Uses [Kubermatic KubeOne](https://github.com/kubermatic/kubeone) under the hood for SSH-only access platforms without API host management support.

## Features

- [Cilium](https://cilium.io) CNI in [kube-proxyless mode](https://cilium.io/use-cases/kube-proxy/)
- Node-groups with labels and taints propagation
- GitOps with [ArgoCD](https://argoproj.github.io/cd/) and [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)

## Prerequisites

### Common Requirements

- Fork the [KubeAid Config](https://github.com/Obmondo/kubeaid-config) repository
- Git provider credentials (e.g., [GitHub PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) with write access)
- [Docker](https://www.docker.com/products/docker-desktop/) running locally

### Server Requirements

Each server must meet these prerequisites:

| Requirement | Details |
|-------------|---------|
| **SSH Access** | KubeAid CLI must SSH as `root` user |
| **Hostname** | Must be lowercase (no uppercase letters in `/etc/hostname`) |
| **No Docker** | Docker must not be installed; remove Docker's APT source and keyring |
| **Packages** | `socat`, `conntrack`, `pigz` must be installed |

> [!IMPORTANT]
> If you fixed an uppercase hostname with `hostnamectl`, also update `/etc/hosts` mappings for 127.0.0.1 and the server's public/private IPs.

## Install KubeAid CLI

```bash
KUBEAID_CLI_VERSION=$(curl -s "https://api.github.com/repos/Obmondo/kubeaid-cli/releases/latest" | jq -r .tag_name)
OS=$([ "$(uname -s)" = "Linux" ] && echo "linux" || echo "darwin")
CPU_ARCHITECTURE=$([ "$(uname -m)" = "x86_64" ] && echo "amd64" || echo "arm64")

wget "https://github.com/Obmondo/kubeaid-cli/releases/download/${KUBEAID_CLI_VERSION}/kubeaid-cli-${KUBEAID_CLI_VERSION}-${OS}-${CPU_ARCHITECTURE}"
sudo mv kubeaid-cli-${KUBEAID_CLI_VERSION}-${OS}-${CPU_ARCHITECTURE} /usr/local/bin/kubeaid-cli
sudo chmod +x /usr/local/bin/kubeaid-cli
```

## Setup

```bash
# Generate configuration
kubeaid-cli config generate bare-metal

# Edit outputs/configs/general.yaml and secrets.yaml

# Bootstrap the cluster
kubeaid-cli cluster bootstrap

# Access the cluster
export KUBECONFIG=./outputs/kubeconfigs/main.yaml
kubectl cluster-info
```

Logs are saved in `outputs/.log`. Access ArgoCD and Grafana dashboards.

## Cleanup

```bash
kubeaid-cli cluster delete main
kubeaid-cli cluster delete management
```

## See Also

- [Cloud Providers](./cloud-providers.md) - API-managed cloud infrastructure
- [Single Host K8s](./single-host-k8s.md) - Local K3D for development
- [Hybrid Setup](./hybrid-setup.md) - Cilium Cluster Mesh for multi-cloud
