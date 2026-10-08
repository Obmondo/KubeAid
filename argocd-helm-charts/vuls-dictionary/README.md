# vuls-dictionary

Helm chart for deploying [Vuls](https://github.com/future-architect/vuls), an agentless vulnerability scanner for Linux.

## How it works

Vuls uses a pre-built SQLite database ([vuls-nightly-db](https://github.com/vulsio/vuls-nightly-db)) that contains CVE, advisory, and detection data. The database (~7 GB uncompressed) is fetched once via init containers and cached on a PersistentVolume. The vuls server reads it locally at startup, so no outbound network access is needed at scan time.

1. **Init containers** pull and decompress the database into `/vuls-db/vuls.db`
2. **Vuls server** starts on port 5515 with a config pointing at the local database
3. **Clients** POST their installed package lists and receive vulnerability results

The database is kept on its own PVC, separate from `/vuls/results`, so database refresh bursts do not consume result-storage headroom. Scan results can be pruned by an init container before the server starts. During migration from older chart versions, legacy `/vuls/vuls.db*` files are removed from the results PVC to reclaim space.

## Components

| Component | Description |
|-----------|-------------|
| **Init containers** | Fetch and decompress the vuls-nightly-db into the PVC |
| **Vuls server** | Scan server (port 5515) that accepts package lists and returns vulnerability results |
| **Vuls exporter** | Optional sidecar that reads scan results and pushes them to the Obmondo API via mTLS |

## Quick start

```yaml
# values.yaml
vuls2:
  enabled: true

vulsServer:
  enabled: true
```

## Configuration

### Database (`vuls2`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vuls2.enabled` | Fetch the nightly database via init containers | `true` |
| `vuls2.image.repository` | Database OCI image | `ghcr.io/vulsio/vuls-nightly-db` |
| `vuls2.image.tag` | Database image tag | `"0"` |
| `vuls2.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `vuls2.dbPath` | Path to the decompressed SQLite DB | `/vuls-db/vuls.db` |
| `vuls2.minDbSizeBytes` | Minimum valid DB size before fetch/decompress is skipped | `"5368709120"` |

When enabled, two init containers run before the vuls server starts:
1. **fetch-vuls2-db** -- pulls the compressed database via `oras`
2. **decompress-vuls2-db** -- decompresses with `zstd`

Both init containers skip work if a valid database (>5 GB) already exists on the PVC.

### Vuls server

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vulsServer.enabled` | Deploy the Vuls scan server | `true` |
| `vulsServer.image.repository` | Vuls server image | `vuls/vuls` |
| `vulsServer.image.tag` | Vuls server image tag | `v0.41.0` |
| `vulsServer.port` | Listen port | `5515` |
| `vulsServer.resources` | Resource requests/limits | 50m/100m CPU, 256Mi/512Mi |
| `vulsServer.resultsDir` | Directory where Vuls writes scan results | `/vuls/results` |
| `vulsServer.databaseStorage.size` | PVC size for the vuls2 database | `25Gi` |
| `vulsServer.databaseStorage.accessMode` | Database PVC access mode | `ReadWriteOnce` |
| `vulsServer.databaseStorage.storageClass` | Database storage class (empty = default) | `""` |
| `vulsServer.resultsStorage.size` | PVC size for scan results | `15Gi` |
| `vulsServer.resultsStorage.accessMode` | Results PVC access mode | `ReadWriteOnce` |
| `vulsServer.resultsStorage.storageClass` | Results storage class (empty = default) | `""` |
| `vulsServer.resultRetention.enabled` | Prune old scan result directories at startup | `true` |
| `vulsServer.resultRetention.maxAgeDays` | Delete result directories older than this many days | `60` |

### Vuls exporter

Optional sidecar that reads scan result JSON files from the results PVC and pushes them to the Obmondo API using mTLS client certificates.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vulsExporter.enabled` | Enable the exporter sidecar | `false` |
| `vulsExporter.image.repository` | Exporter image | `ghcr.io/obmondo/vuls-exporter` |
| `vulsExporter.image.tag` | Exporter image tag | `1.0.0-9bd9ca5` |
| `vulsExporter.obmondo.url` | Obmondo API URL | `""` |
| `vulsExporter.interval` | Push interval | `"12h"` |
| `vulsExporter.tls.secretName` | Kubernetes Secret containing TLS client certs | `""` |
| `vulsExporter.tls.certFile` | Path to client certificate inside the container | `/etc/ssl/vuls-exporter/tls.crt` |
| `vulsExporter.tls.keyFile` | Path to client key inside the container | `/etc/ssl/vuls-exporter/tls.key` |
| `vulsExporter.tls.caFile` | Path to CA certificate (optional, omitted if empty) | `""` |
| `vulsExporter.resources` | Resource requests/limits | 20m/50m CPU, 32Mi/64Mi |

The TLS secret should contain `tls.crt`, `tls.key`, and optionally `ca.crt` keys. When `tls.secretName` is empty, TLS is not configured.

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Create an Ingress | `false` |
| `ingress.className` | Ingress class | `""` |
| `ingress.annotations` | Extra Ingress annotations | `{}` |
| `ingress.vulsServer.enabled` | Route the listed hosts and paths to the Vuls server | `false` |
| `ingress.vulsServer.hosts` | Hosts and paths for the Vuls server | one host, `/vuls` |
| `ingress.vulsServer.inFlightReq.enabled` | Traefik only: cap concurrent scan requests with an InFlightReq middleware, attached to the Ingress automatically | `false` |
| `ingress.vulsServer.inFlightReq.amount` | Scan requests allowed in flight at once; clients over it get 429 | `2` |
| `ingress.tls` | TLS secrets and hosts | `[]` |

Vuls server mode runs every request at once, each one holds a few GB while it detects, and it keeps working on a request after the client timed out. Without a cap, a handful of overlapping scans push the server past its memory limit and none of them finish, and every client retries. Size `inFlightReq.amount` as the server memory limit divided by about 2.5 GB. The security exporters treat 429 as an upstream failure and retry after their random delay.

## Client

Linux hosts run [obmondo-security-exporter](https://github.com/Obmondo/linuxaid-security-exporter), a daemon that collects installed packages, sends them to the Vuls server for scanning, and exposes CVE metrics via Prometheus.
