# vuls-dictionary

Helm chart for deploying [Vuls](https://github.com/future-architect/vuls), an agentless vulnerability scanner for Linux.

## How it works

Vuls uses a pre-built SQLite database ([vuls-nightly-db](https://github.com/vulsio/vuls-nightly-db)) that contains CVE, advisory, and detection data. The database (~7 GB uncompressed) is fetched once via init containers and cached on a PersistentVolume. The vuls server reads it locally at startup, so no outbound network access is needed at scan time.

1. **Init containers** pull and decompress the database into `/vuls/vuls.db`
2. **Vuls server** starts on port 5515 with a config pointing at the local database
3. **Clients** POST their installed package lists and receive vulnerability results

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

When enabled, two init containers run before the vuls server starts:
1. **fetch-vuls2-db** -- pulls the compressed database via `oras`
2. **decompress-vuls2-db** -- decompresses with `zstd`

Both init containers skip work if a valid database (>5 GB) already exists on the PVC.

### NVD CVE dictionary (`cveDictionary`)

The vuls-nightly-db carries distro advisory scores (e.g. `redhat_api`, `ubuntu_api`) but not NVD CVSS scores. A CronJob fills `/vuls/cve.sqlite3` on the results PVC with [go-cve-dictionary](https://github.com/vulsio/go-cve-dictionary) NVD data so scan results also include the `nvd` source.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cveDictionary.enabled` | Deploy the NVD refresh CronJob | `true` |
| `cveDictionary.image.repository` | go-cve-dictionary image | `vulsio/go-cve-dictionary` |
| `cveDictionary.image.tag` | Image tag | `v0.16.2` |
| `cveDictionary.schedule` | Cron schedule for the refresh | `0 3 * * 0` (Sunday 03:00) |
| `cveDictionary.resources` | Resource requests/limits | 100m/500m CPU, 256Mi/1Gi |

Notes:

- The first fill takes hours (unauthenticated NVD API). Trigger it manually instead of waiting for the schedule:
  ```sh
  kubectl create job --from=cronjob/<release>-cve-dictionary-fetch cve-fetch-initial -n <namespace>
  ```
- The job fetches into `cve.sqlite3.new` and swaps atomically, so the running vuls server never reads a half-written file. It keeps serving the old data until restarted — run `kubectl rollout restart deploy/<release>-vuls-server` after a refresh.
- The NVD dataset is several GB; size `vulsServer.resultsStorage.size` with headroom on top of the ~11 GB vuls.db.
- The job requires a node co-located with the vuls server pod (podAffinity) so the results PVC works with `ReadWriteOnce`.

### Vuls server

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vulsServer.enabled` | Deploy the Vuls scan server | `true` |
| `vulsServer.image.repository` | Vuls server image | `vuls/vuls` |
| `vulsServer.image.tag` | Vuls server image tag | `v0.38.6` |
| `vulsServer.port` | Listen port | `5515` |
| `vulsServer.resources` | Resource requests/limits | 50m/100m CPU, 256Mi/512Mi |
| `vulsServer.resultsStorage.size` | PVC size for scan results and database | `15Gi` |
| `vulsServer.resultsStorage.accessMode` | PVC access mode | `ReadWriteOnce` |
| `vulsServer.resultsStorage.storageClass` | Storage class (empty = default) | `""` |

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

## Client

Linux hosts run [obmondo-security-exporter](https://github.com/Obmondo/security-exporter), a daemon that collects installed packages, sends them to the Vuls server for scanning, and exposes CVE metrics via Prometheus.
