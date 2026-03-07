# Cloud Providers

KubeAid provisions Kubernetes clusters on cloud providers using **API-managed hosts**. The cloud APIs automatically create, configure, and manage your infrastructure lifecycle.

## Common Prerequisites

All cloud providers require:

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

---

## AWS

Provisions a KubeAid-managed Kubernetes cluster in AWS with:

- [Cilium](https://cilium.io) CNI in [kube-proxyless mode](https://cilium.io/use-cases/kube-proxy/)
- [Kube2IAM](https://github.com/jtblin/kube2iam) for dynamic IAM credentials
- Autoscalable node-groups (scale to/from 0)
- GitOps with [ArgoCD](https://argoproj.github.io/cd/), [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), [ClusterAPI](https://cluster-api.sigs.k8s.io)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)
- Disaster Recovery with [Velero](https://velero.io)

### AWS Prerequisites

- [Create an AWS SSH KeyPair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html) in your target region:

```bash
aws ec2 create-key-pair \
  --key-name kubeaid-demo \
  --query 'KeyMaterial' --output text --region <aws-region> > ./outputs/<cluster-name>.pem
```

### AWS Setup

```bash
# Generate configuration
kubeaid-cli config generate aws

# Edit outputs/configs/general.yaml and secrets.yaml

# Bootstrap the cluster
kubeaid-cli cluster bootstrap

# Access the cluster
export KUBECONFIG=./outputs/kubeconfigs/main.yaml
kubectl cluster-info
```

### AWS Cleanup

```bash
kubeaid-cli cluster delete main
kubeaid-cli cluster delete management
```

---

## Azure

Provisions a KubeAid-managed Kubernetes cluster in Azure with:

- [Cilium](https://cilium.io) CNI in [kube-proxyless mode](https://cilium.io/use-cases/kube-proxy/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/docs/)
- Autoscalable node-groups (scale to/from 0)
- GitOps with [ArgoCD](https://argoproj.github.io/cd/), [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), [ClusterAPI](https://cluster-api.sigs.k8s.io), [CrossPlane](https://www.crossplane.io)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)
- Disaster Recovery with [Velero](https://velero.io)

### Azure Prerequisites

- Linux or MacOS with at least 16GB RAM (8GB may cause OOM issues)
- [Register a Service Principal in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)
- OpenSSH keypair for VM access:
  ```bash
  ssh-keygen -t rsa -b 4096 -f azure-ssh-key
  ```
- RSA key pair in PEM format for Azure Workload Identity:
  ```bash
  openssl genrsa -out jwt-signing-key.pem 2048
  openssl rsa -in jwt-signing-key.pem -pubout -out jwt-signing-pub.pem
  ```

### Azure Setup

```bash
# Generate configuration
kubeaid-cli config generate azure

# Edit outputs/configs/general.yaml and secrets.yaml

# Bootstrap the cluster
kubeaid-cli cluster bootstrap

# Access the cluster
export KUBECONFIG=./outputs/kubeconfigs/main.yaml
kubectl cluster-info
```

### Azure Upgrade

```bash
kubeaid-cli cluster upgrade --new-k8s-version v1.32.0
# Add --new-image-offer for OS upgrade
```

### Azure Cleanup

```bash
kubeaid-cli cluster delete main
kubeaid-cli cluster delete management
```

---

## Hetzner

Hetzner supports three deployment modes:

| Mode | Control Plane | Workers | Autoscaling |
|------|--------------|---------|-------------|
| **HCloud** | HCloud VMs | HCloud VMs | ✅ Scale to/from 0 |
| **Bare Metal** | Bare Metal | Bare Metal | ❌ |
| **Hybrid** | HCloud VMs | HCloud + Bare Metal | ✅ (HCloud only) |

All modes include:
- [Cilium](https://cilium.io) CNI in [kube-proxyless mode](https://cilium.io/use-cases/kube-proxy/)
- GitOps with [ArgoCD](https://argoproj.github.io/cd/), [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), [ClusterAPI](https://cluster-api.sigs.k8s.io)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)

### HCloud Mode

#### HCloud Prerequisites

- [Create an HCloud SSH KeyPair](https://www.youtube.com/watch?v=mxN6fyMuQRI)
  > No 2 HCloud SSH KeyPairs can have the same public key

#### HCloud Setup

```bash
kubeaid-cli config generate hetzner hcloud
# Edit outputs/configs/general.yaml and secrets.yaml
kubeaid-cli cluster bootstrap
```

---

### Bare Metal Mode

#### Bare Metal Prerequisites

- Create SSH KeyPair at [https://robot.hetzner.com/key/index](https://robot.hetzner.com/key/index)
  > No 2 Hetzner Bare Metal SSH KeyPairs can have the same public key
- If setting `cloud.hetzner.bareMetal.wipeDisks: True`, remove pre-existing RAID:
  ```bash
  wipefs -fa <partition-name>  # For each partition
  ```

#### Bare Metal Disk Layout

For each server:
- **Level 1 SWRAID** across specified disk WWNs
- **25G LVG** named `vg0` with 10G root volume

Configure further via `diskLayoutSetupCommands`. Recommendations:
- Allocate HDDs/SSDs to **Ceph**
- Allocate NVMes to a **ZPool** (mirror mode) for ContainerD, logs, and OpenEBS ZFS LocalPV

#### Bare Metal Setup

```bash
kubeaid-cli config generate hetzner bare-metal
# Edit outputs/configs/general.yaml and secrets.yaml
kubeaid-cli cluster bootstrap
```

---

### Hybrid Mode

Combines HCloud control plane with mixed HCloud + Bare Metal workers.

#### Hybrid Prerequisites

- Both HCloud and Bare Metal SSH KeyPairs (see above)
- Same disk wipe requirements as Bare Metal mode

#### Hybrid Setup

```bash
kubeaid-cli config generate hetzner hybrid
# Edit outputs/configs/general.yaml and secrets.yaml
kubeaid-cli cluster bootstrap
```

---

### Hetzner Cleanup

All modes:
```bash
kubeaid-cli cluster delete main
kubeaid-cli cluster delete management
```

---

## Common Operations

### Access Cluster

```bash
export KUBECONFIG=./outputs/kubeconfigs/main.yaml
kubectl cluster-info
```

Logs are saved in `outputs/.log`. Access ArgoCD and Grafana dashboards for monitoring.

## See Also

- [Bare Metal (On-Prem)](./bare-metal.md) - SSH-based multi-node without cloud APIs
- [Single Host K8s](./single-host-k8s.md) - Local K3D for development
- [Hybrid Setup](./hybrid-setup.md) - Cilium Cluster Mesh for multi-cloud connectivity
