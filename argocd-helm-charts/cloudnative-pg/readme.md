# Backup and Recovery

## Backup

Taking a backup of your data is very important since this is what gonna help you recover the data if data is lost

You can backup your data in S3 or Azure blob storage

The `spec.backup` section of the Cluster resource contains the parameters needed to configure backups.

CronJobs for postgresql logical backup cronjob template can be found [here](./examples/backup-template/postgresql-logical-backup.yaml).

### For S3

Here is a sample configuration for backing up data to S3-compatible storage:

```yaml
backup:
  retentionPolicy: "30d" # Archive retention period
  barmanObjectStore:
    destinationPath: "s3://grafana-backup/backups" # Path to the directory
    endpointURL: "https://s3.storage.foo.bar" # Endpoint of the S3 service
    s3Credentials: #  Credentials to access the bucket
      accessKeyId:
        name: s3-creds
        key: accessKeyId
      secretAccessKey:
        name: s3-creds
        key: secretAccessKey
    wal:
      compression: gzip # WAL compression is enabled
```

If you want to use `IAM` role then in the `spec` section you need to
add the `ServiceAccountTemplate` like -

```yaml
serviceAccountTemplate:
    metadata:
      annotations:
        eks.amazonaws.com/role-arn: arn:[...]
backup:
  retentionPolicy: "30d" # Archive retention period
  barmanObjectStore:
    destinationPath: "s3://grafana-backup/backups" # Path to the directory
    endpointURL: "https://s3.storage.foo.bar" # Endpoint of the S3 service
    wal:
      compression: gzip # WAL compression is enabled
```

### For Azure blob storage

```yaml
backup:
  retentionPolicy: "30d" # Archive retention period
  barmanObjectStore:
    destinationPath: "s3://grafana-backup/backups" # Path to the directory
    endpointURL: "https://s3.storage.foo.bar" # Endpoint of the S3 service
    azureCredentials:
        connectionString:
          name: azure-creds
          key: AZURE_CONNECTION_STRING
        storageAccount:
          name: azure-creds
          key: AZURE_STORAGE_ACCOUNT
        storageKey:
          name: azure-creds
          key: AZURE_STORAGE_KEY
        storageSasToken:
          name: azure-creds
          key: AZURE_STORAGE_SAS_TOKEN
    wal:
      compression: gzip # WAL compression is enabled
```

Note: -

CloudNativePG will save WAL files to the storage every 5 minutes once it is connected.
The Backup resource allows you to perform a full backup manually.
As the name suggests,the ScheduledBackup resource is for scheduled backups

```yaml
---
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: grafana-pg-backup # Name of the backup
spec:
  immediate: true # Backup starts immediately after ScheduledBackup has been created
  schedule: "0 0 0 * * *"
  cluster:
    name: grafana-pg # Cluster name
```

## Recovery

Incase unthinkable happens and data is lost.Then don't worry
you can recover your data,there are two scenarios which you can look at

### Recovery from cluster backup

If your cluster still has the backup resource - then you can recover
that easily by adding the below in your cloudnative cluster resource `spec` section

```yaml
bootstrap:
    recovery:
      backup:
        name: $backup-name # backup is the name which you stated in scheduled backup above
```

### Recovery from S3 bucket or Azure blob storage

# Disaster Recovery: Restoring from S3 Object Store

If your entire CloudNativePG cluster resource or namespace is deleted, you can recover your data from the external S3 bucket (or Azure Blob storage). 

## ⚠️ Critical Pre-checks

* **Postgres Version:** The `imageName` in your recovery manifest **must** match the major version of the backup (e.g., if the backup is from PG 15, you cannot use a PG 16+ image).
* **Initial Bootstrap Only:** Recovery configuration must be present in the **very first** `kubectl apply`. You cannot spin up a fresh DB and enable recovery later.
* **Unique Server Name:** You must change the `metadata.name` of the cluster or use a new `backup.barmanObjectStore.serverName`. If the folder already exists in S3, the operator will fail with an "Expected empty archive" error.

---

## Recovery Steps

1.  **Prepare the Manifest:** Do not sync from ArgoCD initially if it contains a "fresh" DB config. Prepare a manifest following the example below, ensuring the `database` and `owner` names match what was in the original DB.
2.  **Manual Apply:** Apply the recovery manifest using `kubectl apply -f recovery-cluster.yaml`.
3.  **Monitor Progress:** A "full-recovery" pod will spin up. Monitor the logs to see the download progress:
    ```bash
    kubectl logs -f <cluster-name>-1-full-recovery
    ```
4.  **Finalize Sync:** Once the recovery pod completes and the standard Postgres pods are in a `Ready` state, you can sync your application in ArgoCD to match the new state.

---

## Recovery Manifest Example (S3)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: oncall-pgsql-v2  # Use a new name for the restored cluster
spec:
  # 1. Image version MUST match the backup version
  imageName: ghcr.io/cloudnative-pg/postgresql:15 

  instances: 2

  bootstrap:
    recovery:
      # 2. Points to the 'name' defined in externalClusters below
      source: oncall-pgsql-old
      # 3. Must match the owner/db name within the restored data
      database: oncall 
      owner: oncall

  externalClusters:
    - name: oncall-pgsql-old
      barmanObjectStore:
        destinationPath: s3://your-backup-bucket-name
        endpointURL: [https://s3.your-provider.com](https://s3.your-provider.com)
        s3Credentials:
          accessKeyId:
            name: backup-creds
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: backup-creds
            key: ACCESS_SECRET_KEY
        wal:
          maxParallel: 8

  backup:
    barmanObjectStore:
      destinationPath: s3://your-backup-bucket-name
      endpointURL: [https://s3.your-provider.com](https://s3.your-provider.com)
      # 4. Use a NEW serverName to avoid "Expected empty archive" errors
      serverName: oncall-pgsql-v2 
      s3Credentials:
        accessKeyId:
          name: backup-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-creds
          key: ACCESS_SECRET_KEY
```
# Recovery From azure blob storage

```yaml
bootstrap:
    recovery:
      source: your-original-cluster-name
  externalClusters:
    - name: your-original-cluster-name
      barmanObjectStore:
      destinationPath: your s3 backup path
      endpointURL: your s3 endpoint
      azureCredentials:
        connectionString:
          name: azure-creds
          key: AZURE_CONNECTION_STRING
        storageAccount:
          name: azure-creds
          key: AZURE_STORAGE_ACCOUNT
        storageKey:
          name: azure-creds
          key: AZURE_STORAGE_KEY
        storageSasToken:
          name: azure-creds
          key: AZURE_STORAGE_SAS_TOKEN
        wal:
          maxParallel: 8
```

#### Using Restore Script

The [restore script](./bin/restore.sh) can run in two modes:

- **interactive mode** (default): it asks you for the required input values such as storage provider, credentials, backup file path, and database details.
- **non-interactive mode**: you must set all required environment variables before running the script. If any required variable is missing, the script will fail at validation.

Set `RESTORE_MODE=non-interactive` to run in non-interactive mode.

##### Example command for non-interactive mode:

```bash
RESTORE_MODE=non-interactive \
STORAGE_PROVIDER=s3 \
AWS_ACCESS_KEY_ID=your_access_key \
AWS_SECRET_ACCESS_KEY=your_secret_key \
LOGICAL_BACKUP_S3_BUCKET=your_bucket_name \
BACKUP_FILE_PATH=path/to/backup.sql.gz \
LOGICAL_BACKUP_S3_ENDPOINT=https://s3.your-endpoint.com \
DB_NAME=your_db \
DB_USER=your_db_user \
DB_PASS=your_db_password \
DB_HOST=your_db_host \
DB_PORT=5432 \
./restore_script.sh
```

---

##### Required Environment Variables

| Variable Name                  | Description                            | Required For           |
|-------------------------------|------------------------------------|-----------------------|
| `RESTORE_MODE`                 | Mode: `interactive` or `non-interactive` | Both                  |
| `STORAGE_PROVIDER`             | Storage backend: `s3` or `azure`   | Both                  |
| **S3 specifics:**              |                                    |                       |
| `AWS_ACCESS_KEY_ID`            | AWS S3 access key ID                | S3                    |
| `AWS_SECRET_ACCESS_KEY`        | AWS S3 secret access key            | S3                    |
| `LOGICAL_BACKUP_S3_BUCKET`     | S3 bucket name                     | S3                    |
| `BACKUP_FILE_PATH`             | Backup file path in bucket          | S3/Azure               |
| `LOGICAL_BACKUP_S3_ENDPOINT`   | S3 service endpoint URL             | S3                    |
| **Azure specifics:**           |                                    |                       |
| `AZURE_STORAGE_ACCOUNT_NAME`   | Azure storage account name          | Azure                 |
| `AZURE_STORAGE_ACCOUNT_KEY`    | Azure storage access key            | Azure                 |
| `AZURE_STORAGE_CONTAINER_NAME` | Azure blob storage container name  | Azure                 |
| `AZURE_STORAGE_BACKUP_PATH`    | Backup blob path                   | Azure                 |
| **Database connection:**       |                                    |                       |
| `DB_NAME`                     | Database name                      | Both                  |
| `DB_USER`                     | Database username                  | Both                  |
| `DB_PASS`                     | Database password                  | Both                  |
| `DB_HOST`                     | Database host address              | Both                  |
| `DB_PORT`                     | Database port                      | Both                  |

---


## Monitoring and Alerting

CloudNativePG provides metrics that can be used to monitor backup health. This chart includes PrometheusRule resources for alerting on backup failures.

### Enabling Backup Monitoring Alerts

To enable backup monitoring alerts, set the following in your values:

```yaml
cloudnative-pg:
  monitoring:
    podMonitorEnabled: true
    prometheusRule:
      enabled: true
      # Optional: Add labels for Prometheus selection
      labels:
        prometheus: k8s
      # Optional: Add labels to all alerts
      alertLabels: {}
      # Maximum age for last successful backup (default: 24 hours)
      backupMaxAgeSeconds: 86400
      # Maximum age for WAL archiving (default: 5 minutes)
      walArchiveMaxAgeSeconds: 300
      # Maximum age for first recoverability point (default: 7 days)
      firstRecoverabilityPointMaxAgeSeconds: 604800
```

### Available Alerts

| Alert Name | Severity | Description |
|------------|----------|-------------|
| `CNPGClusterNoRecentBackup` | critical | No successful backup in the last 24 hours (covers both stale and missing backups) |
| `CNPGClusterWALArchivingStale` | warning | WAL archiving has not occurred within the configured threshold (default: 5 min) |
| `CNPGClusterWALArchivingFailing` | warning | WAL archiving is actively failing |
| `CNPGClusterLowRecoverability` | warning | Point-in-time recovery window is too old (default: > 7 days) |

### Metrics Used

The alerts use the following CNPG metrics:

- `cnpg_collector_last_available_backup_timestamp` - Timestamp of the last successful backup
- `cnpg_collector_first_recoverability_point` - First point in time recovery is possible
- `cnpg_pg_stat_archiver_seconds_since_last_archival` - Seconds since last WAL archival
- `cnpg_pg_stat_archiver_failed_count` - Count of failed WAL archivals

**Note:** Some of these metrics may be deprecated in newer CNPG versions (>= 1.26). Check the CNPG documentation for the latest metrics available in your version.

## Triggering Backups Immediately

Unlike traditional CronJobs, CNPG ScheduledBackups cannot be triggered on-demand directly. The workaround is:

1. Delete the existing ScheduledBackup CR
2. Recreate it with `immediate: true`:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: my-backup
spec:
  immediate: true  # This triggers a backup immediately upon creation
  schedule: "0 0 0 * * *"
  cluster:
    name: my-cluster
```

Alternatively, you can create a one-off Backup CR:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: manual-backup
spec:
  cluster:
    name: my-cluster
```

## Docs and External References

- https://www.enterprisedb.com/blog/current-state-major-postgresql-upgrades-cloudnativepg-kubernetes
- https://cloudnative-pg.io/documentation/current/monitoring/
- https://cloudnative-pg.io/documentation/current/backup/
