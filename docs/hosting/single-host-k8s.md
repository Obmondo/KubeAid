# Single Host Kubernetes

The local provider provisions a KubeAid-managed **K3D** cluster on your local machine for development and testing.

> [!CAUTION]
> The local provider does **not** support cluster upgrades or disaster recovery. Use for testing only.

## Features

- [Cilium](https://cilium.io) CNI in [kube-proxyless mode](https://cilium.io/use-cases/kube-proxy/)
- GitOps with [ArgoCD](https://argoproj.github.io/cd/) and [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)
- Runs entirely in Docker containers

## Prerequisites

- Fork the [KubeAid Config](https://github.com/Obmondo/kubeaid-config) repository
- Git provider credentials (e.g., [GitHub PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) with write access)
- [Docker](https://www.docker.com/products/docker-desktop/) running locally

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
kubeaid-cli config generate local

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
kubeaid-cli cluster delete management
```

## See Also

- [Cloud Providers](./cloud-providers.md) - API-managed cloud infrastructure with HA
- [Bare Metal](./bare-metal.md) - On-premises multi-node clusters
- [Hybrid Setup](./hybrid-setup.md) - Cilium Cluster Mesh for multi-cloud
