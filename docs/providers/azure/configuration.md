# Azure Configuration

## `general.yaml`

The `cloud` section for Azure:

```yaml
cloud:
  azure:
    subscriptionId: <subscription-id>
    resourceGroup: my-cluster-rg
    location: westeurope          # Amsterdam; change to your preferred region
    controlPlane:
      vmSize: Standard_D2s_v3
      replicas: 3
    nodePools:
      - name: workers
        vmSize: Standard_D4s_v3
        minSize: 1
        maxSize: 10
```

## `secrets.yaml`

Azure credentials:

```yaml
azure:
  clientId: <service-principal-client-id>
  clientSecret: <service-principal-secret>
  tenantId: <azure-tenant-id>
```
