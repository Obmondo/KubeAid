# Loki

## Log monitoring in KubeAid

Loki is a **log-only** monitoring option in KubeAid. It runs alongside
[`kube-prometheus`](../../docs/kubeaid/prometheus-configuration.md) (Prometheus, Alertmanager, Grafana), which
continues to handle metrics and metric-based alerts. Loki is queried from the same Grafana you already use for
metrics, which is its main advantage over the other log options.

See [Monitoring](../../docs/monitoring.md) for how Loki compares to OpenObserve, Graylog, and OpenSearch + Kibana.

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

### Choosing labels

This is the decision that determines whether Loki works well for you, and it is made in the shipper rather than
here.

Loki indexes labels, not log content. Every distinct combination of label values is one **stream**, and streams
are the unit of cost. Keep the set small and bounded: namespace, container, and stdout/stderr, plus a static
`job` or `cluster`. That is a few hundred streams on a normal cluster.

Do not make `pod` a label. Every restart mints a new pod name, so every restart creates another stream that stays
in the index forever. The same goes for node, pod IP, request ID, or anything else unbounded.

Put those in **structured metadata** instead. It is not indexed, still comes back on every line, and is still
filterable once a stream is selected:

```logql
{namespace="checkout"} | pod="checkout-7d9f4b8c6-xk2mn"
```

The syntax matters. `{pod="..."}` inside the braces does not error and does not warn, it matches no stream and
returns nothing, which reads like a broken pipeline rather than a wrong query.

## Adding the Grafana datasource

Add loki in the ConfigMap:

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

## Growing beyond a single node

Monolithic mode with a filesystem PVC caps out at one replica. There is nothing to replicate to and no shared
storage. Once you outgrow it, move to object storage and `Distributed`:

```yaml
loki:
  deploymentMode: Distributed
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
  ingester:
    replicas: 3
    persistence:
      # Chart default is false, which means emptyDir, and the chart's own comment says all
      # data in the ingester is lost on pod restart. This is the write ahead log, not the
      # chunk store: it exists so a crashed ingester can replay what it had not flushed yet.
      # Still wanted when chunks live in object storage.
      enabled: true
      claims:
        - name: data
          size: 10Gi
    zoneAwareReplication:
      # Chart default is true, which renders ingester-zone-a/b/c and expects the nodes to
      # carry real topology zone labels. Turn it off unless they do.
      enabled: false
  distributor:
    replicas: 3
  querier:
    replicas: 3
  queryFrontend:
    replicas: 2
  queryScheduler:
    replicas: 2
  indexGateway:
    replicas: 2
  compactor:
    # Exactly one. Two compactors will fight over the same objects.
    replicas: 1
  chunksCache:
    enabled: true
  resultsCache:
    enabled: true
  # Zero out the modes you are not running, their defaults collide with Distributed.
  singleBinary:
    replicas: 0
  write:
    replicas: 0
  read:
    replicas: 0
  backend:
    replicas: 0
```

Resource requests and limits for these components already come from this chart's `values.yaml`, override them if
your volume needs more. Replicas do not, set them as above.

Object storage here is a correctness requirement, not just more space. Each ingester flushes chunks to the
shared bucket and any querier can read any of them. On a filesystem PVC each ingester writes to its own volume,
no other querier can see those chunks, and queries come back missing data without reporting an error.

**Skip `SimpleScalable`.** It looks like the natural middle step and most guides still recommend it, but the
chart marks it `deprecated, removed in Loki 4`. Go from Monolithic straight to Distributed.

Put the credentials in a [sealed secret](../sealed-secrets/README.md) and reference them with
`loki.storage.s3.secretAccessKey` read from the environment, rather than committing them. Any S3-compatible
backend works, including the [`minio`](../minio/), [`garage`](../garage/), and
[`rook-ceph`](../rook-ceph/README.md) charts in this repository. Do not use the Loki chart's own bundled MinIO
subchart, it is deprecated to the point that the chart refuses to install with `minio.enabled=true` unless you
also set `ignoreMinioDeprecation`.

`SimpleScalable` and `Distributed` **require** object storage, they will not run on a filesystem PVC. The
ingester PVCs above are the write ahead log and are not a substitute for it.

## Multi-tenancy

`auth_enabled` is `false`, Turn it on when you want separate rate limits, retention, and query isolation, for example one tenant per cluster when several clusters ship into one central Loki.

```yaml
loki:
  loki:
    auth_enabled: true
```

Once it is on, every request needs an `X-Scope-OrgID` header, shippers and Grafana alike. Without one Loki
rejects reads and writes with a **404 and `no org id`**, which does not look like an auth failure and sends
people looking in the wrong place.

The gateway can supply that header for you. Set `loki.tenants` and enable gateway basic auth: the chart builds
an htpasswd file from the tenant list, and nginx maps the authenticated username straight to the tenant with
`proxy_set_header X-Scope-OrgID $remote_user`.

```yaml
loki:
  loki:
    tenants:
      # htpasswd -nbBC10 cluster-a '<password>'
      - name: cluster-a
        passwordHash: "<bcrypt-hash>"
      - name: cluster-b
        passwordHash: "<bcrypt-hash>"
  gateway:
    basicAuth:
      enabled: true
```

This is worth using rather than setting the header in each client. The tenant comes from the credentials, so a
client cannot write into another client's tenant no matter what it sends, and shippers only need `http_user` and
`http_passwd`. Keep the hashes in a [sealed secret](../sealed-secrets/README.md) rather than in the values file.

Grafana needs one datasource per tenant, each sending its own `X-Scope-OrgID` under the datasource's HTTP
Headers section.
