# [![Mattermost logo](https://user-images.githubusercontent.com/7205829/137170381-fe86eef0-bccc-4fdd-8e92-b258884ebdd7.png)](https://mattermost.com)

[Mattermost](https://mattermost.com) is an open core, self-hosted collaboration platform that offers chat, workflow automation, voice calling, screen sharing, and AI integration.

# Configuration

- `mattermost.enabled: false` installs only the operator, without a Mattermost instance, for a
  cluster where one operator serves instances that other releases create.
- `mattermost.fileStore` selects where uploaded files live:
  - `external.enabled: true` with `url`, `bucket` and `secret`: an S3-compatible bucket.
  - `volume.storageClass`, optionally with `volume.size` (default `10Gi`) and
    `volume.accessMode` (default `ReadWriteOnce`): a PVC named `<name>-files` on that class,
    created by this chart.
    - With `ReadWriteOnce` set `mattermost.replicas: 1`. Only one node can hold the volume, so
      a rollout can hang when the new pod lands on another node than the old one.
    - On a shared-filesystem class such as CephFS set `accessMode: ReadWriteMany`. The new pod
      can then mount the volume from any node while the old one still runs.
    - Kubernetes does not allow changing the access mode or the class of an existing claim.
      To switch, copy the files out, delete the claim and let the chart create it again.
  - neither: the operator's own PVC sized by `local.storageSize` (default `10Gi`), which the
    operator requests as ReadWriteMany on the cluster's default storage class.
- `mattermost.podTemplate` goes into the CR's `spec.podTemplate`. With a `volume` or `local`
  file store set `fsGroup: 2000`, otherwise uploads fail with `permission denied`
  ([mattermost-operator#399](https://github.com/mattermost/mattermost-operator/issues/399)):

  ```yaml
  mattermost:
    podTemplate:
      securityContext:
        fsGroup: 2000
        runAsUser: 2000
        runAsGroup: 2000
  ```

# Restore Mattermost / Migration to Another Server

This guide outlines the steps to restore a Mattermost instance or migrate it to a new server.

## Steps

1. **Sync the Mattermost PostgreSQL database first.**

2. **Retrieve Mattermost database credentials from the secret `mattermost-pgsql-app`.**

3. **Create a Kubernetes secret `db-credentials` using the Mattermost database credentials.**

   Use this command to generate the DB connection string for the Mattermost operator:

   ```sh
   kubectl create secret generic db-credentials \
   --from-literal=DB_CONNECTION_STRING="$(kubectl get secret mattermost-pgsql-app -n mattermost-operator -o jsonpath='{.data.uri}' | base64 --decode | sed 's/^postgresql:/postgres:/')"
   --dry-run=client -o yaml
   ```
4. **Download the latest logical backup from S3 and extract it locally.**

   ```sh
   AWS_ACCESS_KEY_ID="mattermost" AWS_SECRET_ACCESS_KEY="secretkey" aws s3 --endpoint https://s3.bucket.com/ cp s3://mattermost-postgres-backups/spilo/logicalbackup/logical_backups/<latest>.sql.gz ./

   gunzip -d <filename>.sql.gz
   ```
5. **Access the `mattermost-pgsql` pod shell and reset the Mattermost database to avoid errors.**

   Connect to the pod and execute
   ```sh
   DROP DATABASE mattermost;
   CREATE DATABASE mattermost OWNER mattermost
   ```

6. **Restore the database from the extracted backup file.**

   Run the restore command:

   ```sh
   psql -h 172.20.36.240 -p 5432 -d mattermost -U mattermost < <backupfile>.sql
   ```
    > **Important:** Mattermost (v10.11+) stores the database connection string (`DataSource`)
    > inside the `configurations` table in the database itself. After restoring a backup, this
    > value will contain the **old** hostname and password from the source cluster, causing
    > Mattermost pods to crash with `password authentication failed` or `no such host` errors.
    >
    > You **must** update it after every restore.

    Run this one-liner to automatically fetch the current password from the Kubernetes secret
    and patch the `configurations` table:

    ```sh
    DB_PASS=$(kubectl get secret mattermost-operator-pgsql-app -n mattermost-operator -o jsonpath='{.data.password}' | base64 -d) && \
    kubectl run psql-fix --rm -i --restart=Never --image=postgres:15 -n mattermost-operator --env="PGPASSWORD=$DB_PASS" -- \
      psql -h mattermost-operator-pgsql-rw -U mattermost -d mattermost \
      -c "UPDATE configurations SET value = jsonb_set(value::jsonb, '{SqlSettings,DataSource}', to_jsonb('postgres://mattermost:'||'${DB_PASS}'||'@mattermost-operator-pgsql-rw.mattermost-operator:5432/mattermost?sslmode=disable'::text), false) WHERE active = true;"
    ```

    Then restart the Mattermost pods to pick up the corrected config:

    ```sh
    kubectl delete pod -l app=mattermost -n mattermost-operator
    ```

7. **Copy PVC files to the new S3 bucket to restore file storage.**

   If you have access to the node, upload files directly from the PVC mount path using the MinIO client:
   ```sh
   cd /var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~csi/<pvc-name>/mount

   mc alias set mattermost https://s3.bucket.com mattermost <password>

   mc mirror . mattermost/mattermost-backup --overwrite
   ```

8. **After syncing the data and restoring the DB, sync the entire Mattermost instance.**

   The new Mattermost will be restored to the state captured by the backup.

   ---
