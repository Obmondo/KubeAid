# Hetzner Configuration

## `general.yaml`

### Hetzner HCloud

```yaml
cloud:
  hetzner:
    hcloud:
      region: nbg1
      sshKeyName: kubeaid-demo
      controlPlane:
        serverType: cpx31
        replicas: 3
      nodePools:
        - name: workers
          serverType: cpx41
          minSize: 1
          maxSize: 10
```

> [!NOTE]
> HCloud storage only allows a maximum of 16 buckets per physical node. Plan your PV usage accordingly.

### Hetzner Bare Metal

```yaml
cloud:
  hetzner:
    bareMetal:
      wipeDisks: false          # Set true to wipe existing RAID
      controlPlane:
        serverIds: [123456, 123457, 123458]  # Must be unique within the cluster
      nodePools:
        - name: workers
          serverIds: [234567, 234568]        # Must be unique within the cluster
          labels:
            node-type: worker
          taints: []
```

> [!NOTE]
> Server IDs must be unique within a cluster. Each server can only belong to one node pool.

### Hetzner Hybrid

```yaml
cloud:
  hetzner:
    hcloud:
      # Control plane in HCloud
      controlPlane:
        serverType: cpx31
        replicas: 3
    bareMetal:
      # Workers in Bare Metal
      nodePools:
        - name: bare-metal-workers
          serverIds: [234567, 234568]
```

## `secrets.yaml`

Hetzner credentials:

```yaml
hetzner:
  hcloudToken: <hcloud-api-token>
  robotUser: <robot-username>           # For bare metal only
  robotPassword: <robot-password>       # For bare metal only
```
