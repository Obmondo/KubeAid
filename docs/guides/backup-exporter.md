# Backup Exporter

The backup exporter is a Prometheus exporter that monitors the health of your backup infrastructure.
It exposes metrics and ships PrometheusRule alerts for **PostgreSQL**, **Velero**, **MongoDB**, and
**Sealed Secrets** backups.

It ships in the [`kubeaid-agent`](../../argocd-helm-charts/kubeaid-agent/) chart, as its own
Deployment alongside the agent, so one Argo CD application covers both.

## What It Monitors

| Backup System | Alert | Fires When |
| ------------- | ----- | ---------- |
| PostgreSQL | `PostgresBackupExporterJobFailed` | The exporter job itself reports an error (`backup_exporter_postgres_error == 1`) |
| PostgreSQL | `PostgresLogicalBackupExceededRPO` | Latest logical backup age exceeds `max_rpo` |
| PostgreSQL | `PostgresCNPGWALBackupExceededRPO` | Latest CNPG WAL backup age exceeds `max_rpo` |
| PostgreSQL | `PostgresLogicalBackupMissing` | No logical backup has ever been recorded |
| PostgreSQL | `PostgresWALBackupMissing` | No WAL backup has ever been recorded |
| Velero | `VeleroBackupExporterJobFailed` | The exporter job itself reports an error (`backup_exporter_velero_error == 1`) |
| Velero | `VeleroBackupExceededRPO` | Latest backup age exceeds `max_rpo` |
| Velero | `VeleroBackupMissing` | No backup has ever been recorded |
| MongoDB | `MongoDBBackupExporterJobFailed` | The exporter job itself reports an error (`backup_exporter_mongodb_error == 1`) |
| MongoDB | `MongoDBDumpBackupExceededRPO` | Latest dump backup age exceeds `max_rpo` |
| MongoDB | `MongoDBDumpBackupMissing` | No dump backup has ever been recorded |
| Sealed Secrets | `SealedSecretsBackupExporterJobFailed` | The exporter job itself reports an error (`backup_exporter_sealedsecrets_error == 1`) |
| Sealed Secrets | `SealedSecretsKeyBackupExceededRPO` | Latest key backup age exceeds `max_rpo` |
| Sealed Secrets | `SealedSecretsKeyBackupMissing` | No key backup has ever been recorded |

All alerts default to `critical` severity and fire after 5 minutes. These are configurable via the
values file. MongoDB and Sealed Secrets monitoring are opt-in (`enabled: false` by default) since
not every cluster runs those backups.

## Deployment

It is deployed with the `kubeaid-agent` Argo CD application, but is **off by default** — it needs S3
credentials for each backend it reports on, and there is no sane default for those. Set
`backup-exporter.enabled: true` along with the credentials below. The Helm dependency condition
and parent values key are both hyphenated (`backup-exporter`), matching `Chart.yaml`.

Key values, all under the `backup-exporter` key in `values-kubeaid-agent.yaml` (sibling of
`appConfig`, not nested under it):

```yaml
backup-exporter:
  enabled: true

  exporter:
    # Postgres and Velero collectors run when the chart is enabled; fill S3 for each.
    postgres:
      s3:
        secretName: ""            # Secret with access-key-id / secret-access-key (etc.)
    velero:
      s3:
        url: ""                   # S3 endpoint URL
        secretName: ""            # Or accessKeyId / secretAccessKey / region / bucket
    # Opt-in backends (default false):
    mongodb:
      enabled: false
      s3:
        secretName: ""
    sealedSecrets:
      enabled: false
      s3:
        bucket: ""                # Must match sealed-secrets chart backup.s3Bucket
        endpoint: ""              # Must match backup.s3Endpoint
        secretName: ""

  # Enable Prometheus alerting rules
  prometheusRule:
    enabled: true
    postgres:
      enabled: true
      namespace: monitoring        # Where the PrometheusRule is created
      severity: critical
      alertForDuration: 5m
    velero:
      enabled: true
      namespace: monitoring
      severity: critical
      alertForDuration: 5m
    mongodb:
      enabled: false               # Follows exporter.mongodb.enabled
      namespace: monitoring
      severity: critical
      alertForDuration: 5m
    sealedSecrets:
      enabled: false               # Follows exporter.sealedSecrets.enabled
      namespace: monitoring
      severity: critical
      alertForDuration: 5m
```

The exporter also ships a **ServiceMonitor** for automatic Prometheus scraping and supports
**HorizontalPodAutoscaler** configuration.

## Integration with Existing Monitoring

The backup exporter complements KubeAid's existing monitoring stack:

- **kube-prometheus** scrapes the exporter's metrics via the ServiceMonitor
- **Alertmanager** routes the backup failure alerts to your configured notification channels
- **Grafana** can visualise the backup health metrics alongside your cluster dashboards

## See Also

- [Monitoring](../monitoring.md) - overall monitoring architecture
- [Backup & Restore](../operations/backup-restore.md) - disaster recovery procedures
