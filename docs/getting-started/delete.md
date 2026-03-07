# Cluster Deletion

## Warning

Cluster deletion is **irreversible**.
- Back up `general.yaml` files.
- Export sealed secrets.
- Save `secrets.yaml`.

## Deletion Steps

### 1. Delete Main Cluster

```bash
kubeaid-cli cluster delete main
```

This removes worker nodes, control plane, and cloud resources.

### 2. Delete Management Cluster (ClusterAPI only)

For AWS, Azure, Hetzner (HCloud/Hybrid):

```bash
kubeaid-cli cluster delete management
```

For Bare Metal (SSH-only), this step is not needed.

### Complete Cleanup

```bash
kubeaid-cli cluster delete main && kubeaid-cli cluster delete management
```

## Post-Deletion Cleanup

### Local Files

```bash
rm -rf outputs/
```

### Provider-Specific Cleanup

For some providers, you may need to manually remove resources that were not created by KubeAid or were left behind.

- **AWS**: Check for lingering ELBs or volumes.
- **Azure**: Check resource group.
- **Hetzner**: Check for leftover volumes.
- **Bare Metal**: You must manually reset the servers (e.g., `kubeadm reset`, wipe disks).

See specific provider documentation for details.
