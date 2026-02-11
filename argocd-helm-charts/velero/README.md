# Velero

## Setting up Velero

### Configuration

- **Plugin usage:**
  - Azure: `velero-plugin-for-microsoft-azure`
  - AWS: `velero-plugin-for-aws`
- **Snapshot mechanism:**
  - Azure: CSI snapshots via Azure Disk CSI Driver
  - AWS: EBS snapshots via AWS EBS CSI Driver
- **Storage bucket for Velero metadata:**
  - Azure: Azure Blob Storage
  - AWS: Amazon S3
- **Backup naming convention:** `daily-backup-<namespace>-<timestamp>`

### Scheduling

- Daily full-volume backups via `velero schedule` CRDs
- Retention policies configured using TTL settings in Velero schedules

Example value files can be found [here](./examples).

## How to check the backup in Velero

- using `kubectl`

```sh
kubectl get backup -n velero
```

- using `velero` 

```sh
velero get backups
```

## Check backup schedules

- using `kubectl`

```sh
kubectl get schedules -n velero
```

- using `velero`
```sh
velero get schedules
```

## Triggering manual backups

- To trigger a manual backup using existing schedule

```bash
velero create backup manual-backup --from-schedule daily-backup`
```

## Restoring using existing backups

- To restore from a backup

```bash
velero restore create --from-backup manual-backup
```

- To verify restore request has been created

```bash
velero get restores
```

## Docs

* https://github.com/vmware-tanzu/helm-charts/blob/main/charts/velero/README.md

## Upgrade

Velero can be updated by updating the helm chart.

NOTE: Please look at the respective plugin you use in velero, before updating the velero.

* Version Matrix

| Provider | Links |
|--------------|-----|
| AWS | https://github.com/vmware-tanzu/velero-plugin-for-aws#compatibility |
| CSI | https://github.com/vmware-tanzu/velero-plugin-for-csi#compatibility |
| Azure | https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure#compatibility |

## Issues

Velero keeps a track of schedules even when they are deleted.
https://github.com/vmware-tanzu/velero/issues/1333

It keeps publishing the metrics of older schedules even after removing them.
The available solution for now is to kill the pods when no backups/restores are being performed.

## Troubleshooting

Install the Velero CLI.
Use this command to describe and check logs of a particular backup.

```sh
# Get info about a backup
velero backup describe <backup_name>

# Get logs about a backup
velero backup logs <backup_name>
```

Velero uses `snapshot-controller` to backup PVCs by taking a Volume Snapshot.
It uses the Snapshot APIs (snapshot.storage.k8s.io) to create a VolumeSnapshot and
a VolumeSnapshotContent. The snapshot will be persisted to the cloud provider.
E.g.- EBS Snapshots if you are using AWS.

Sometimes, the volumesnapshot objects remain in the cluster even after the backup has
been deleted. We need to keep an eye on these objects taking up space and remove them
to avoid huge cloud bills.

To delete a VolumeSnapshot, set the underlying VolumeSnapshotContent object's `spec.deletionPolicy`
from `Retain` to `Delete`. Then delete the VolumeSnapshot and it will trigger the deletion
of VolumeSnapshotContent as well as the Snapshot on your cloud provider.

## Create SealedSecret for Velero using file

```sh
kubectl create secret generic cloud-credentials -n velero  --from-file=cloud=cloud-credentials.yaml -o yaml --dry-run=client | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml > cloud.yaml
```

Where, contents of file `cloud-credentials.yaml` is shown below. From cloud to cloud the variable
differs. And NOTE that this is only valid for Azure cloud.

```text
AZURE_SUBSCRIPTION_ID=fkfkfdfdfdkfjlss
AZURE_TENANT_ID=wellllcmdndkdkd
AZURE_CLIENT_ID=3920keeiwid93ri3jm3idn3din3
AZURE_CLIENT_SECRET=ekji2ieje8eje3ij3i
AZURE_RESOURCE_GROUP=MC_k8s-prod-ddkkwji
AZURE_CLOUD_NAME=AwsPublicCloud
```

## Create SealedSecret for Velero

Depending on the cloud provider, run the script located inside `/bin/<cloud>` directory. (Currently only `Azure` is supported)

```sh
# help
./azure --help

# running the script
./azure --client-secret xxxx --cluster-name cluster.company.com
```

Script will generate `credentials-velero.json` in same directory. User has to apply that file to the desired cluster.

## Create Token

Generating a azure token with role as contributor, scope as a subscription id for lifelong.

```sh
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<subscription-id>" --years 4000 --output json
```

## References

* [How Velero Works](https://velero.io/docs/v1.9/how-velero-works/)
* [Velero Troubleshooting Guide](https://velero.io/docs/v1.3.2/troubleshooting/)
* [Azure Resource not found](https://velero.io/docs/v1.3.2/troubleshooting/)
