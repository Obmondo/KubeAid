# Hybrid Setup

Connect multiple Kubernetes clusters across different cloud providers using **Cilium Cluster Mesh** for seamless cross-cluster workload communication.

## Cilium Cluster Mesh

[Cilium Cluster Mesh](https://cilium.io/use-cases/cluster-mesh/) provides:

- Cross-cluster service discovery
- Shared service load balancing
- Network policy enforcement across clusters
- Transparent encryption

## Use Cases

| Use Case | Description |
|----------|-------------|
| Multi-cloud resilience | Run workloads across Hetzner + Azure for redundancy |
| Geographic distribution | Place clusters close to users in different regions |
| Cost optimization | Use cheaper providers for burst capacity |
| Hybrid cloud | Connect on-premises with cloud providers |
| Migration | Gradually move workloads between clusters |

## Example: Hetzner + Azure

```
┌─────────────────┐         ┌─────────────────┐
│  Hetzner Cluster │◄──────►│  Azure Cluster  │
│                 │ Cilium  │                 │
│  Control Plane  │ Cluster │  Control Plane  │
│  Worker Nodes   │  Mesh   │  Worker Nodes   │
└─────────────────┘         └─────────────────┘
```

### Prerequisites

1. Multiple KubeAid clusters deployed (see [Cloud Providers](./cloud-providers.md))
2. Network connectivity between clusters (routable IPs or VPN)
3. Cilium installed on all clusters (included by default)
4. Compatible Cilium versions across clusters
5. Unique cluster names in the mesh

### Setup Steps

1. **Enable Cluster Mesh:**

```bash
cilium clustermesh enable --context <cluster1-context>
cilium clustermesh enable --context <cluster2-context>
```

2. **Connect clusters:**

```bash
cilium clustermesh connect \
  --context <cluster1-context> \
  --destination-context <cluster2-context>
```

3. **Verify connectivity:**

```bash
cilium clustermesh status --context <cluster1-context>
```

For detailed configuration, see the [Cilium Cluster Mesh documentation](https://docs.cilium.io/en/stable/network/clustermesh/).

## Hetzner Hybrid Mode

> [!NOTE]
> This is different from Cilium Cluster Mesh.

Hetzner's built-in hybrid mode creates a **single cluster** with mixed node types:
- Control plane in HCloud (VMs)
- Worker nodes in HCloud and/or Bare Metal

See [Cloud Providers - Hetzner Hybrid](./cloud-providers.md#hybrid-mode) for setup instructions.

## See Also

- [Cloud Providers](./cloud-providers.md) - Individual cloud provider setup
- [Bare Metal](./bare-metal.md) - On-premises clusters
