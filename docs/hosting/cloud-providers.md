# Cloud Providers

KubeAid provisions Kubernetes clusters on cloud providers using **API-managed hosts**. The cloud APIs automatically
create, configure, and manage your infrastructure lifecycle.

## Common Prerequisites

All cloud providers require:

- Fork the [KubeAid Config](https://github.com/Obmondo/kubeaid-config) repository
- Git provider credentials (e.g., [GitHub
  PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)
  with write access)
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
- GitOps with [ArgoCD](https://argoproj.github.io/cd/), [Sealed
  Secrets](https://github.com/bitnami-labs/sealed-secrets), [ClusterAPI](https://cluster-api.sigs.k8s.io)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)
- Disaster Recovery with [Velero](https://velero.io)

### AWS Prerequisites

- [Create an AWS SSH KeyPair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html) in your target
  region:

```bash
aws ec2 create-key-pair \
  --key-name kubeaid-demo \
  --query 'KeyMaterial' --output text --region <aws-region> > ./<cluster-name>.pem
```

### AWS Setup

```bash
# Generate configuration (interactive prompt; select aws when asked for a provider)
kubeaid-cli config generate

# Edit ~/.config/kubeaid-cli/<cluster>/configs/general.yaml and secrets.yaml

# Bootstrap the cluster
kubeaid-cli cluster bootstrap --cluster-name <cluster>

# Access the cluster
export KUBECONFIG=~/.config/kubeaid-cli/<cluster>/kubeconfigs/main.yaml
kubectl cluster-info
```

### AWS EKS (managed control plane)

Set `cloud.aws.eks: true` to get an AWS-managed (EKS) control plane instead of the self-managed
CAPA one. `cluster bootstrap` and `cluster delete` work as above; `cluster upgrade` refuses on EKS
clusters - bump `global.kubernetes.version` in the kubeaid-config repo's `values-capi-cluster.yaml`
instead and let ArgoCD/CAPA roll the control plane and node-groups. `cluster recover` isn't
supported yet for EKS. See [Pre-Configuration](../getting-started/pre-configuration.md#aws-eks-managed-control-plane)
for the full field list.

### AWS Cleanup

```bash
kubeaid-cli cluster delete main --cluster-name <cluster>
kubeaid-cli cluster delete management --cluster-name <cluster>
```

---

## Azure

Provisions a KubeAid-managed Kubernetes cluster in Azure with:

- [Cilium](https://cilium.io) CNI in [kube-proxyless mode](https://cilium.io/use-cases/kube-proxy/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/docs/)
- Autoscalable node-groups (scale to/from 0)
- GitOps with [ArgoCD](https://argoproj.github.io/cd/), [Sealed
  Secrets](https://github.com/bitnami-labs/sealed-secrets), [ClusterAPI](https://cluster-api.sigs.k8s.io),
  [CrossPlane](https://www.crossplane.io)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)
- Disaster Recovery with [Velero](https://velero.io)

### Azure Prerequisites

- Linux or MacOS with at least 16GB RAM (8GB may cause OOM issues)
- [Register a Service Principal in Microsoft Entra
  ID](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)
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
# Generate configuration (interactive prompt; select azure when asked for a provider)
kubeaid-cli config generate

# Edit ~/.config/kubeaid-cli/<cluster>/configs/general.yaml and secrets.yaml

# Bootstrap the cluster
kubeaid-cli cluster bootstrap --cluster-name <cluster>

# Access the cluster
export KUBECONFIG=~/.config/kubeaid-cli/<cluster>/kubeconfigs/main.yaml
kubectl cluster-info
```

### Azure AKS (managed control plane)

Set `cloud.azure.aks: true` to get an Azure-managed (AKS) control plane instead of the self-managed
CAPZ one. `cluster bootstrap` and `cluster delete` work as above; `cluster upgrade` refuses on AKS
clusters - bump `global.kubernetes.version` in the kubeaid-config repo's `values-capi-cluster.yaml`
instead and let ArgoCD/CAPZ roll the control plane and agent pools. `cluster recover` isn't
supported yet for AKS. See [Pre-Configuration](../getting-started/pre-configuration.md#azure-aks-managed-control-plane)
for the full field list.

### Azure Upgrade

There are no `--new-k8s-version` / `--new-image-offer` flags. Edit `cluster.k8sVersion` (and the
machine image fields) in `general.yaml`, then run:

```bash
kubeaid-cli cluster upgrade --cluster-name <cluster>
# --skip-pr-workflow pushes changes directly instead of opening a PR
```

### Azure Cleanup

```bash
kubeaid-cli cluster delete main --cluster-name <cluster>
kubeaid-cli cluster delete management --cluster-name <cluster>
```

---

## Hetzner

Hetzner supports three deployment modes:

| Mode | Control Plane | Workers | Autoscaling |
| ------ | -------------- | --------- | ------------- |
| **HCloud** | HCloud VMs | HCloud VMs | ✅ Scale to/from 0 |
| **Bare Metal** | Bare Metal | Bare Metal | ❌ |
| **Hybrid** | HCloud VMs | HCloud + Bare Metal | ✅ (HCloud only) |

All modes include:

- [Cilium](https://cilium.io) CNI in [kube-proxyless mode](https://cilium.io/use-cases/kube-proxy/) with **VXLAN tunnel
  routing** (pod traffic is encapsulated over the node network - no routes programmed in HCloud)
- [CAPH](https://github.com/syself/cluster-api-provider-hetzner) **v1.1.8** with default OS image **Ubuntu 26.04**
- GitOps with [ArgoCD](https://argoproj.github.io/cd/), [Sealed
  Secrets](https://github.com/bitnami-labs/sealed-secrets), [ClusterAPI](https://cluster-api.sigs.k8s.io)
- Monitoring with [KubePrometheus](https://prometheus-operator.dev)

### HCloud Mode

#### HCloud Prerequisites

- [Create an HCloud SSH KeyPair](https://www.youtube.com/watch?v=mxN6fyMuQRI)
  > No 2 HCloud SSH KeyPairs can have the same public key

#### HCloud Setup

```bash
# Interactive prompt; select hetzner, then hcloud, when asked
kubeaid-cli config generate
# Edit ~/.config/kubeaid-cli/<cluster>/configs/general.yaml and secrets.yaml
kubeaid-cli cluster bootstrap --cluster-name <cluster>
```

---

### Bare Metal Mode

#### Bare Metal Prerequisites

- Create SSH KeyPair at <https://robot.hetzner.com/key/index>
  > No 2 Hetzner Bare Metal SSH KeyPairs can have the same public key
- If setting `cloud.hetzner.bareMetal.wipeDisks: True`, remove pre-existing RAID:

  ```bash
  wipefs -fa <partition-name>  # For each partition
  ```

#### Bare Metal Disk Layout

For each server:

- **Level 1 SWRAID** across specified disk WWNs
- **25G LVG** named `vg0` with 10G root volume

Configure further via `installImage.vg0.{size,rootVolumeSize}` and `wipeDisks`. Recommendations:

- Allocate HDDs/SSDs to **Ceph**
- Allocate NVMes to a **ZPool** (mirror mode) for ContainerD, logs, and OpenEBS ZFS LocalPV

> **Provider IDs:** Bare-metal nodes use the canonical `hrobot://<server-id>` provider-ID format (enabled
> via the `capi.syself.com/use-hrobot-provider-id-for-baremetal` annotation on the HetznerCluster). This
> aligns CAPH's Machine providerID with the upstream Hetzner CCM robot provider.

#### Bare Metal Setup

```bash
# Interactive prompt; select hetzner, then bare-metal, when asked
kubeaid-cli config generate
# Edit ~/.config/kubeaid-cli/<cluster>/configs/general.yaml and secrets.yaml
kubeaid-cli cluster bootstrap --cluster-name <cluster>
```

---

### Hybrid Mode

Combines HCloud control plane with mixed HCloud + Bare Metal workers.

#### Hybrid Cloud Controller Manager (CCM) Architecture

Hybrid clusters run **two CCM instances** from the same upstream chart, because the Hetzner CCM cannot
enable its route controller (networking) and Robot bare-metal support at the same time:

| CCM Instance | Purpose | Scope |
| ------------ | ------- | ----- |
| `ccm-hcloud` | Networking (`HCLOUD_NETWORK`), InternalIP assignment, LoadBalancers, routes | HCloud nodes only |
| `ccm-hetzner` | Robot provider-ID (`hrobot://`), node lifecycle | Bare-metal nodes only (controllers: `cloud-node`, `cloud-node-lifecycle`) |

The HCloud CCM provides the `InternalIP` for the private-only control-plane nodes - without it, the
apiserver cannot reach the kubelet and control-plane scale-up stalls on etcd health checks. The robot
CCM is scoped to `cloud-node` + `cloud-node-lifecycle` only so it does not fight `ccm-hcloud` over
LoadBalancers.

> **Pure HCloud or pure Bare Metal clusters** use a single CCM instance.

#### Floating IPs on Control-Plane Nodes

Control-plane nodes can bind HCloud **Floating IPs** via netplan for a stable public endpoint. The
[hcloud-fip-controller](../../argocd-helm-charts/hcloud-fip-controller/README.md) chart handles IP
failover across nodes (leader-elected, ~15 s failover). The node-side IP binding (cloud-init/netplan)
is the operator's responsibility.

#### Hybrid Prerequisites

- Both HCloud and Bare Metal SSH KeyPairs (see above)
- Same disk wipe requirements as Bare Metal mode

#### Hybrid Setup

```bash
# Interactive prompt; select hetzner, then hybrid, when asked
kubeaid-cli config generate
# Edit ~/.config/kubeaid-cli/<cluster>/configs/general.yaml and secrets.yaml
kubeaid-cli cluster bootstrap --cluster-name <cluster>
```

---

### Hetzner Cleanup

All modes:

```bash
kubeaid-cli cluster delete main --cluster-name <cluster>
kubeaid-cli cluster delete management --cluster-name <cluster>
```

---

## Common Operations

### Access Cluster

```bash
export KUBECONFIG=~/.config/kubeaid-cli/<cluster>/kubeconfigs/main.yaml
kubectl cluster-info
```

Logs are saved in `~/.config/kubeaid-cli/<cluster>/logs`. Access the ArgoCD and Grafana dashboards for monitoring.

## See Also

- [Bare Metal (On-Prem)](./bare-metal.md) - SSH-based multi-node without cloud APIs
- [Single Host K8s](./single-host-k8s.md) - Local K3D for development
- [Hybrid Setup](./hybrid-setup.md) - Cilium Cluster Mesh for multi-cloud connectivity
