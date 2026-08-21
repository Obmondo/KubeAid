# Loki

## Log monitoring in KubeAid

Loki is a **log-only** monitoring option in KubeAid. It runs alongside
[`kube-prometheus`](../../docs/kubeaid/prometheus-configuration.md) (Prometheus, Alertmanager, Grafana), which
continues to handle metrics and metric-based alerts. Loki is queried from the same Grafana you already use for
metrics, which is its main advantage over the other log options.

| | |
| - | - |
| **Scope** | Log ingestion, storage, and querying with LogQL |
| **Log collection** | Fluent Bit, OpenTelemetry Collector, Promtail, Grafana Alloy, or anything that can push to the Loki API |
| **Prometheus integration** | Queried from the same Grafana as Prometheus; optional ServiceMonitor for Loki's own metrics |
| **Storage** | Filesystem PVC by default, object storage (S3 / GCS / Azure Blob / MinIO / Garage / Ceph RGW) for larger installs |

See [Monitoring](../../docs/monitoring.md) for how Loki compares to OpenObserve, Graylog, and OpenSearch + Kibana.

> **Replaces the old `loki-stack` chart.** This chart used to live at `argocd-helm-charts/loki-stack` and wrap
> `grafana/loki-stack`, which was deprecated and abandoned upstream. It now wraps
> [`grafana-community/loki`](https://github.com/grafana-community/helm-charts), the maintained replacement that
> tracks current Loki releases. If you have an Argo CD application pointing at the old path, see
> [Migrating from the old loki-stack chart](#migrating-from-the-old-loki-stack-chart).

---

## What you get by default

The defaults in `values.yaml` target a single cluster ingesting up to a few tens of GB of logs per day:

- **Monolithic mode** - one Loki StatefulSet running every component in a single binary
- **Filesystem storage** on a 50Gi PVC, with the `tsdb` store and the `v13` schema
- **30 day retention**, actually enforced by the compactor
- **Nginx gateway** in front of Loki, so shippers and Grafana have one address to talk to
- **Single tenant** (`auth_enabled: false`), so no `X-Scope-OrgID` header is needed

Turned off by default because they cost resources without buying much at this scale: the memcached chunk and
result caches, the Loki canary, the Helm test hook, the chart's built-in MinIO, and the ServiceMonitor,
PrometheusRules and dashboards.

**This chart ships Loki only.** It does not install a log shipper. Deploy one separately, see
[Shipping logs to Loki](#shipping-logs-to-loki).

## Install

Add it as a regular Argo CD application in your `kubeaid-config` repository, pointing at
`argocd-helm-charts/loki`, and override whatever you need in your cluster's values file.

Set the retention you actually want, the default is 30 days:

```yaml
loki:
  loki:
    limits_config:
      retention_period: 2160h  # 90 days
```

The PVC is sized at 50Gi. Grow it before you need to, a StatefulSet volume claim template cannot be resized in
place by Helm:

```yaml
loki:
  singleBinary:
    persistence:
      size: 200Gi
      storageClass: my-storage-class
```

## Shipping logs to Loki

Point your shipper at the gateway service:

```raw
http://<release-name>-gateway.<namespace>.svc.cluster.local/loki/api/v1/push
```

KubeAid ships two charts that can do the shipping:

- [`fluent-bit`](../fluent-bit/) - lightweight, use the `loki` output plugin
- [`opentelemetry-operator`](../opentelemetry-operator/) - use the `loki` or `otlphttp` exporter if you
  also want traces going to the same collector

Grafana Alloy and Promtail work too, they just are not packaged here. Promtail in particular is end-of-life
upstream, prefer Alloy or the OpenTelemetry Collector for new setups.

## Adding the Grafana datasource

The old `loki-stack` chart created the Grafana datasource for you. This one does not, so add it yourself. If your
Grafana runs the datasource sidecar, a ConfigMap is enough:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki-gateway.loki.svc.cluster.local
        isDefault: false
```

Adjust the label to whatever your Grafana's sidecar watches for, and the URL to your release name and namespace.

## Scraping Loki's own metrics

Off by default because it needs the Prometheus Operator CRDs in the cluster. With `kube-prometheus` installed:

```yaml
loki:
  monitoring:
    serviceMonitor:
      enabled: true
    rules:
      enabled: true
    dashboards:
      enabled: true
```

## Growing beyond a single node

Monolithic mode with a filesystem PVC caps out at one replica, there is nothing to replicate to and no shared
storage. Once you outgrow it, move to object storage and a larger deployment mode:

```yaml
loki:
  deploymentMode: SimpleScalable
  loki:
    commonConfig:
      replication_factor: 3
    storage:
      type: s3
      bucketNames:
        chunks: loki-chunks
        ruler: loki-ruler
      s3:
        endpoint: <your-endpoint>
        region: <your-region>
        accessKeyId: <access-key>
        secretAccessKey: <secret-key>
  singleBinary:
    replicas: 0
  write:
    replicas: 3
  read:
    replicas: 3
  backend:
    replicas: 3
  chunksCache:
    enabled: true
  resultsCache:
    enabled: true
```

Put the credentials in a [sealed secret](../sealed-secrets/README.md) and reference them with
`loki.storage.s3.secretAccessKey` read from the environment, rather than committing them. Any S3-compatible
backend works, including the [`minio`](../minio/), [`garage`](../garage/), and
[`rook-ceph`](../rook-ceph/README.md) charts in this repository.

`SimpleScalable` and `Distributed` **require** object storage, they will not run on a filesystem PVC.

## Editing the schema

`loki.schemaConfig.configs` is a list of periods, each one saying how data written from that date onward is
stored. Never change the `from` date or the settings of an entry that already has data behind it, Loki will not
be able to read those chunks back. To change anything, append a new entry with a date in the future:

```yaml
loki:
  loki:
    schemaConfig:
      configs:
        - from: "2024-04-01"
          store: tsdb
          object_store: filesystem
          schema: v13
          index:
            prefix: loki_index_
            period: 24h
        - from: "2026-09-01"   # must be in the future when you deploy this
          store: tsdb
          object_store: s3
          schema: v13
          index:
            prefix: loki_index_
            period: 24h
```

## Multi-tenancy

`auth_enabled` is `false`, so everything lands in a single tenant. If you turn it on, every client, shippers and
Grafana alike, has to send an `X-Scope-OrgID` header or its requests are rejected.

```yaml
loki:
  loki:
    auth_enabled: true
```

## Troubleshooting

**Loki pod is `CrashLoopBackOff` right after install.** Check the config it rendered:

```sh
kubectl -n <namespace> get cm loki -o jsonpath='{.data.config\.yaml}'
```

A `replication_factor` higher than the number of running instances is the usual cause.

**Writes rejected with `entry too far behind`.** `reject_old_samples_max_age` is 168h. Logs older than a week
are dropped, which is what you want for a shipper catching up, but not if you are backfilling. Raise it under
`loki.loki.limits_config`.

**The PVC keeps growing past the retention period.** Retention only takes effect when the compactor is running
with `retention_enabled: true`, which is set in `loki.loki.structuredConfig`. Confirm it made it into the
rendered config, then check the compactor logs in the Loki pod.

**Queries time out on large ranges.** Raise `query_timeout` and lower `split_queries_by_interval` under
`loki.loki.limits_config`, or enable the results cache.

## Migrating from the old loki-stack chart

There is no in-place upgrade. The Loki 2.x boltdb-shipper index and the Loki 3.x tsdb index are not
interchangeable, and the values keys are completely different. Do not just repoint your existing Argo CD
application from `argocd-helm-charts/loki-stack` to `argocd-helm-charts/loki`, that will try to upgrade the
release in place and fail.

1. Deploy this chart as a **new** Argo CD application with a new release name and namespace.
2. Repoint your shipper at the new gateway URL.
3. Add the new Grafana datasource alongside the old one.
4. Leave the old release running until its retention window has passed, then delete it and its PVC.
