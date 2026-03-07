# AWS Configuration

## `general.yaml`

The `cloud` section for AWS:

```yaml
cloud:
  aws:
    region: eu-central-1         # Frankfurt; change to your preferred region
    sshKeyName: kubeaid-demo    # Name of your AWS SSH keypair
    controlPlane:
      instanceType: t3.medium
      replicas: 3
    nodePools:
      - name: workers
        instanceType: t3.large
        minSize: 1
        maxSize: 10
```

## `secrets.yaml`

AWS credentials:

```yaml
aws:
  accessKeyId: <aws-access-key>
  secretAccessKey: <aws-secret-key>
```
