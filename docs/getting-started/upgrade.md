# Cluster Upgrade

## Before Upgrading

1. **Backup important data**
2. **Review changelogs** (Kubernetes release notes)
3. **Test in staging**

## Upgrade Command

To upgrade the Kubernetes version of your cluster:

```bash
kubeaid-cli cluster upgrade --new-k8s-version v1.32.0
```

> [!TIP]
> Replace `v1.32.0` with your target Kubernetes version.

## Monitoring

The upgrade process will:
1. Upgrade the control plane
2. Upgrade worker nodes (rolling update)
3. Update core components if necessary

Check `outputs/.log` if issues arise.
