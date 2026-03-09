# Bootstrap the Cluster

This guide covers bootstrapping your KubeAid-managed Kubernetes cluster. The installation process is **the same for all providers**.

## Before You Begin

Ensure you have completed:

- [x] [Prerequisites](./prerequisites.md) - All required tools installed
- [x] Provider-specific setup (see [Prerequisites](./prerequisites.md))
- [x] [Pre-Configuration](./pre-configuration.md) - `general.yaml` and `secrets.yaml` configured

Make sure:
- Docker is running locally
- Your configuration files are in `outputs/configs/`
- Your `secrets.yaml` is backed up in your password store

## Step 1: Install KubeAid CLI

The KubeAid CLI is required to bootstrap and manage your cluster. If you haven't installed it yet, run the following script to download and install the latest release:
```bash
KUBEAID_CLI_VERSION=$(curl -s "https://api.github.com/repos/Obmondo/kubeaid-cli/releases/latest" | jq -r .tag_name)
OS=$([ "$(uname -s)" = "Linux" ] && echo "Linux" || echo "Darwin")
CPU_ARCHITECTURE=$([ "$(uname -m)" = "x86_64" ] && echo "amd64" || echo "arm64")

wget "https://github.com/Obmondo/kubeaid-cli/releases/download/${KUBEAID_CLI_VERSION}/kubeaid-cli_${OS}_${CPU_ARCHITECTURE}.tar.gz"
tar -xzf kubeaid-cli_${OS}_${CPU_ARCHITECTURE}.tar.gz
sudo mv kubeaid-cli /usr/local/bin/kubeaid-cli
sudo chmod +x /usr/local/bin/kubeaid-cli
rm kubeaid-cli_${OS}_${CPU_ARCHITECTURE}.tar.gz
```

Verify the installation:
```bash
kubeaid-cli --version
```

## Step 2: Run Bootstrap

With the CLI installed and your configuration files in place, run the bootstrap command:

```bash
kubeaid-cli cluster bootstrap
```

### What Happens During Bootstrap

1. **Create a local management cluster** - A temporary K3D cluster for orchestration (ClusterAPI only)
2. **Provision infrastructure** - Create cloud resources or configure SSH access
3. **Initialize Kubernetes** - Deploy control plane and workers
4. **Install core components** - Cilium, ArgoCD, Sealed Secrets, KubePrometheus
5. **Configure GitOps** - Sync with your kubeaid-config repository

### Monitoring Progress

- Logs are streamed to simple terminal output
- Detailed logs saved to `outputs/.log`
- Process takes 10-30 minutes

## Step 3: Verify Access

Once the bootstrap process is complete, verify you can access the cluster:

```bash
export KUBECONFIG=./outputs/kubeconfigs/main.yaml
kubectl cluster-info
kubectl get nodes
```

## Troubleshooting

- **Bootstrap leads**: Check `outputs/.log`
- **Management cluster fails**: Restart Docker
- **Cloud resources fail**: Verify `secrets.yaml`
