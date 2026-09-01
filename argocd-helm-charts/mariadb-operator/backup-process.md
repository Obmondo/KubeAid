# MariaDB operator backup process

This documents the generic backup process for MariaDB instances managed by the
MariaDB operator in KubeAid-managed clusters.

The process applies to any customer cluster where the MariaDB operator is
installed and the target MariaDB instance is managed through GitOps.

Expected MariaDB operator CRDs:

- `mariadbs.k8s.mariadb.com`
- `backups.k8s.mariadb.com`
- `restores.k8s.mariadb.com`
- `pointintimerecoveries.k8s.mariadb.com`

## Ownership model

Keep the split between shared KubeAid and customer-specific config clear:

- KubeAid provides the shared platform components, including the MariaDB
  operator and CRDs.
- `kubeaid-config-*` provides customer-specific application charts, values,
  namespaces, S3 paths, and sealed secrets.
- MariaDB backup templates for customer applications should live with the
  application chart that owns the MariaDB instance, for example:
  - `k8s/argocd-helm-charts/<application>/templates/mariadb-backup.yaml`
- Do not create a separate top-level Argo CD application only for these
  backups unless there is a clear ownership reason. The backup should follow
  the same GitOps lifecycle as the application database.

## How the backup works

The MariaDB operator `Backup` resource creates a Kubernetes Job. That Job:

1. Connects to the referenced MariaDB instance.
2. Runs a logical database dump.
3. Compresses the dump, usually with `gzip`.
4. Uploads it to the configured S3 bucket and prefix.
5. Applies the configured retention.

The template described here creates a backup resource/job. It does not, by
itself, define a recurring schedule. If periodic backups are required, add the
operator-supported schedule field or a separate scheduling mechanism after
confirming the exact operator version and CRD schema in the target cluster.

The backup is not a Rook/Ceph block-level snapshot. It is a logical MariaDB
backup, which makes it suitable for restoring into a fresh MariaDB instance in
another namespace.

## Required inputs

Each backup needs these inputs:

| Input | Source |
| --- | --- |
| MariaDB CR name | Application chart values |
| Backup namespace | Same namespace as the MariaDB instance |
| Database list | Application chart values |
| S3 bucket | Customer values |
| S3 endpoint | Customer values |
| S3 region | Customer values |
| S3 prefix | Customer values |
| S3 credentials secret | Customer sealed secret |

The S3 credential secret contains only credentials. It does not contain the S3
bucket or path. Bucket, region, endpoint, and prefix are configured in the
`Backup` resource.

For S3-compatible storage with the MariaDB operator, use the endpoint without
the URL scheme:

```yaml
endpoint: s3.example.com
region: example-region
```

Do not use an endpoint like `https://s3.example.com` in the MariaDB operator
backup spec. The operator job can fail with an endpoint validation error when
the endpoint is configured as a full URL. TLS is enabled separately in the S3
config.

## Secret requirements

The backup credential secret must exist in the namespace where the `Backup`
resource runs.

If a cluster already has a working S3 credential secret for another backup
tool, check whether the same credentials can be reused. The secret should only
contain access credentials, for example:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

The secret name is customer-specific. Example:

```text
s3-backup-credentials
```

Because Kubernetes secrets are namespace-scoped, each application namespace
that runs a MariaDB backup needs its own copy of the secret, preferably as a
sealed secret in the customer `kubeaid-config-*` repository.

For example:

```text
example-app/s3-backup-credentials
another-app/s3-backup-credentials
```

Do not print or commit the decoded secret values.

## Example Backup values

Example for a single-database application:

```yaml
mariadb:
  enabled: true
  name: example-mariadb
  backup:
    enabled: true
    name: example-mariadb-backup
    namespace: example-app
    databases:
      - example_database
    compression: gzip
    maxRetention: 168h
    storage:
      s3:
        bucket: example-backups
        endpoint: s3.example.com
        region: example-region
        prefix: mariadb/example-app/example-mariadb
        credentialsSecretName: s3-backup-credentials
```

Example for a multi-database application:

```yaml
mariadb:
  enabled: true
  name: shared-mariadb
  backup:
    enabled: true
    name: shared-mariadb-backup
    namespace: shared-app
    databases:
      - app_database
      - reporting_database
      - integration_database
    compression: gzip
    maxRetention: 168h
    storage:
      s3:
        bucket: example-backups
        endpoint: s3.example.com
        region: example-region
        prefix: mariadb/shared-app/shared-mariadb
        credentialsSecretName: s3-backup-credentials
```

Use a unique prefix per MariaDB instance. Reusing the same S3 credentials is
fine, but reusing the same prefix for different databases will mix backup
objects and make restore selection unsafe.

## Verify before enabling

Check that the MariaDB operator and backup CRD exist:

```sh
kubectl get deploy -A | grep -i mariadb
kubectl get crd | grep k8s.mariadb.com
```

Check that the MariaDB instance is ready:

```sh
kubectl -n example-app get mariadb example-mariadb
kubectl -n example-app get pods,pvc
```

Check that the S3 secret exists in the same namespace:

```sh
kubectl -n example-app get secret s3-backup-credentials
```

Validate the chart render before syncing with Argo CD:

```sh
helm lint \
  k8s/argocd-helm-charts/example-app \
  -f k8s/<cluster-name>/argocd-apps/values-example-app.yaml

helm template example-app \
  k8s/argocd-helm-charts/example-app \
  -n example-app \
  -f k8s/<cluster-name>/argocd-apps/values-example-app.yaml \
  | kubectl apply --dry-run=server -f -
```

## Run and verify a backup

After syncing the application chart, check the `Backup` resource:

```sh
kubectl -n example-app get backup
kubectl -n example-app describe backup example-mariadb-backup
kubectl -n example-app get job,pod | grep example-mariadb-backup
```

Check the backup job logs:

```sh
kubectl -n example-app logs job/example-mariadb-backup
```

A successful backup should show the upload target and complete without errors.
Then verify the object exists in S3. Use the credentials from the Kubernetes
secret without printing them:

```sh
export AWS_ACCESS_KEY_ID="$(
  kubectl -n example-app get secret s3-backup-credentials \
    -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d
)"
export AWS_SECRET_ACCESS_KEY="$(
  kubectl -n example-app get secret s3-backup-credentials \
    -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d
)"

aws --endpoint-url https://s3.example.com s3 ls \
  s3://example-backups/mariadb/example-app/example-mariadb/

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
```

The S3 listing should show a timestamped backup object under the configured
MariaDB prefix.

## Restore test in another namespace

Use this flow to prove that a backup can be restored into a separate MariaDB
instance. Do not run this against the live application namespace.

Create a scratch namespace:

```sh
kubectl create namespace example-mariadb-restore-test
```

Create or seal a copy of the S3 credential secret in the scratch namespace.
For a one-off manual test, it can be copied without printing secret data:

```sh
kubectl -n example-mariadb-restore-test create secret generic \
  s3-backup-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$(
    kubectl -n example-app get secret s3-backup-credentials \
      -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d
  )" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$(
    kubectl -n example-app get secret s3-backup-credentials \
      -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d
  )" \
  --dry-run=client -o yaml \
  | kubectl apply -f -
```

Create a small MariaDB instance:

```yaml
apiVersion: k8s.mariadb.com/v1alpha1
kind: MariaDB
metadata:
  name: restore-example-mariadb
  namespace: example-mariadb-restore-test
spec:
  image: docker-registry1.mariadb.com/library/mariadb:11.8.2
  rootPasswordSecretKeyRef:
    name: restore-example-mariadb
    key: root-password
    generate: true
  storage:
    size: 5Gi
    storageClassName: "storage-class-name"
```

Wait until it is ready:

```sh
kubectl -n example-mariadb-restore-test get mariadb restore-example-mariadb
kubectl -n example-mariadb-restore-test get pod,pvc
```

Create the target database before restoring a single database dump:

```yaml
apiVersion: k8s.mariadb.com/v1alpha1
kind: Database
metadata:
  name: example-database
  namespace: example-mariadb-restore-test
spec:
  mariaDbRef:
    name: restore-example-mariadb
  name: example_database
```

Create a `Restore` resource using direct S3 settings. Do not use `backupRef`
for this cross-namespace test, because the restore should read from S3 and
target the scratch MariaDB instance.

```yaml
apiVersion: k8s.mariadb.com/v1alpha1
kind: Restore
metadata:
  name: restore-example-mariadb-backup
  namespace: example-mariadb-restore-test
spec:
  mariaDbRef:
    name: restore-example-mariadb
  database: example_database
  targetRecoveryTime: "<backup-timestamp>"
  s3:
    bucket: example-backups
    endpoint: s3.example.com
    region: example-region
    prefix: mariadb/example-app/example-mariadb
    accessKeyIdSecretKeyRef:
      name: s3-backup-credentials
      key: AWS_ACCESS_KEY_ID
    secretAccessKeySecretKeyRef:
      name: s3-backup-credentials
      key: AWS_SECRET_ACCESS_KEY
    tls:
      enabled: true
```

Use the timestamp of the backup object you want to restore. The tested backup
object used a timestamped name like:

```text
backup.<backup-timestamp>.gzip.sql
```

Verify the restore:

```sh
kubectl -n example-mariadb-restore-test get restore
kubectl -n example-mariadb-restore-test describe restore restore-example-mariadb-backup
kubectl -n example-mariadb-restore-test logs job/restore-example-mariadb-backup
```

Then verify the restored data exists:

```sh
ROOT_PASSWORD="$(
  kubectl -n example-mariadb-restore-test get secret restore-example-mariadb \
    -o jsonpath='{.data.root-password}' | base64 -d
)"

kubectl -n example-mariadb-restore-test exec restore-example-mariadb-0 -- \
  mariadb -uroot -p"${ROOT_PASSWORD}" \
  -e "SHOW DATABASES LIKE 'example_database';"

unset ROOT_PASSWORD
```

Check the restored schema and table count before considering the restore test
successful.

Clean up the scratch namespace after the test:

```sh
kubectl delete namespace example-mariadb-restore-test
```

## Point-in-time recovery

`PointInTimeRecovery` is different from a normal restore. It restores a base
backup and then replays binary logs up to a target timestamp.

Use it only when binary log archiving has been configured and verified. For the
basic MariaDB operator backup test above, normal `Backup` and `Restore`
resources are enough.

## Troubleshooting

If the backup job cannot find MariaDB TLS or root secrets, check that the
`Backup` resource is running in the same namespace as the MariaDB instance.

If the backup upload fails with an endpoint URL validation error, check that
the S3 endpoint does not include `https://`.

If the restore fails with `Unknown database`, create the target `Database`
resource first or restore the full dump without specifying `spec.database`.

If the S3 object is not visible after a successful Kubernetes job, verify the
bucket, prefix, region, endpoint, and credential secret keys. The secret only
proves access; it does not define the destination path.
