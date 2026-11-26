# Qdrant

Wrapper around the upstream [Qdrant](https://qdrant.tech/) chart from `https://qdrant.github.io/qdrant-helm`.
Qdrant is a vector database: it stores vectors with a JSON payload and returns the nearest ones to a query,
filtered on payload fields.

The chart deploys:
- a StatefulSet with one PersistentVolumeClaim per pod;
- a Service with ports 6333 (HTTP), 6334 (gRPC) and 6335 (peer-to-peer), plus a headless Service;
- a ConfigMap and a ServiceAccount.

It has no CRDs.

`values.yaml` changes one default: `qdrant.config.telemetry_disabled: true`. Without it, Qdrant sends anonymous
usage statistics to the Qdrant team. The chart writes `qdrant.config` into Qdrant's `production.yaml`. Cluster
values merge into that map, so they keep this key.

## Storage

Qdrant needs a block-level volume with a POSIX filesystem. Its installation guide says it won't work with network
file systems such as NFS, or with object storage such as S3. That rules out CephFS and RustFS. Use a local or block
StorageClass such as zfs-localpv or Ceph RBD:

```yaml
qdrant:
  persistence:
    storageClassName: <block StorageClass>
    size: <size>
```

## API keys

Qdrant has no authentication by default: anything that reaches the Service can read and write. Put the keys in a
Secret (a SealedSecret in your kubeaid-config) and pass them as environment variables:

```yaml
qdrant:
  env:
    - name: QDRANT__SERVICE__API_KEY
      valueFrom:
        secretKeyRef:
          name: qdrant-api-key
          key: api-key
    - name: QDRANT__SERVICE__READ_ONLY_API_KEY
      valueFrom:
        secretKeyRef:
          name: qdrant-api-key
          key: read-only-api-key
```

Leave the chart's own `apiKey` and `readOnlyApiKey` unset. Both read the existing Secret with Helm's `lookup` at
render time, and Argo CD renders without cluster access. So `true` gets a new random key on every sync, and
`valueFrom` gets an empty one.

Two more things:
- The pod doesn't restart when that Secret changes, so restart it after a rotation.
- To scrape `/metrics` once keys are set, put the API key in `qdrant.metrics.serviceMonitor.authorization`.

## Snapshots to S3-compatible storage

Snapshots can go to a bucket instead of the pod's volume. `endpoint_url` points Qdrant at an S3-compatible store
such as RustFS:

```yaml
qdrant:
  config:
    storage:
      snapshots_config:
        snapshots_storage: s3
        s3_config:
          bucket: <bucket>
          region: <region>
          endpoint_url: https://<s3 endpoint>
  env:
    - name: QDRANT__STORAGE__SNAPSHOTS_CONFIG__S3_CONFIG__ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: qdrant-snapshots-s3
          key: access-key
    - name: QDRANT__STORAGE__SNAPSHOTS_CONFIG__S3_CONFIG__SECRET_KEY
      valueFrom:
        secretKeyRef:
          name: qdrant-snapshots-s3
          key: secret-key
```

Notes:
- `qdrant.env` is a list. A cluster that sets both the API keys and these credentials must put all four entries in
  one list.
- Qdrant's docs don't say whether it uses path-style bucket addressing. Test creating and restoring a snapshot
  against your store before relying on it.
- Qdrant documents restores from a URL, a file or an upload, not from the bucket itself.
- Snapshots kept on the pod sit in an emptyDir unless `qdrant.snapshotPersistence.enabled` is set.

## Updating

The chart uses plain semver versions, so the weekly Helm update bumps it. To bump it by hand:

```sh
bin/manage-helm-chart.sh --update-helm-chart qdrant
```
