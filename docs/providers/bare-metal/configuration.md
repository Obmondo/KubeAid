# Bare Metal (SSH-only) Configuration

## `general.yaml`

```yaml
cloud:
  bareMetal:
    controlPlane:
      hosts:
        - address: 10.0.0.1
          user: root
        - address: 10.0.0.2
          user: root
        - address: 10.0.0.3
          user: root
    nodePools:
      - name: workers
        hosts:
          - address: 10.0.0.10
            user: root
          - address: 10.0.0.11
            user: root
        labels:
          node-type: worker
        taints: []
```

> [!NOTE]
> IPs (e.g., 10.0.0.1) are examples. Use valid private IP ranges (RFC 1918) like 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16.

## `secrets.yaml`

SSH private key for node access:

```yaml
ssh:
  privateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
```
