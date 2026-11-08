# Graylog

## Log monitoring in KubeAid

Graylog is a **log-only** monitoring option in KubeAid. It runs alongside
[`kube-prometheus`](../../docs/kubeaid/prometheus-configuration.md) (Prometheus, Alertmanager, Grafana), which
continues to handle metrics and metric-based alerts.

| | |
| - | - |
| **Scope** | Log ingestion, search, pipelines, and log-based alerting |
| **Log collection** | Fluent Bit, Fluentd, Beats, Syslog, GELF, and other Graylog inputs |
| **Prometheus integration** | None — Graylog does not pull metrics or alerts from Prometheus |
| **Storage** | OpenSearch (indexed logs) and MongoDB (Graylog metadata) |

See [Monitoring](../../docs/monitoring.md) for how Graylog compares to
OpenObserve and OpenSearch + Kibana.

The sections below cover installation, configuration, and operations.

---

## Initial admin secret setup

Generate the `graylog` secret (holds the admin password and its sha256, referenced by the Helm chart):

```sh
pwgen 20 1 | tr -d '\n' > graylog-password
cat graylog-password | sha256sum | tr -d '\n' > graylog-sha2
kubectl create secret generic graylog -n graylog --dry-run=client --from-file=graylog-password-secret=./graylog-password --from-file=graylog-password-sha2=./graylog-sha2 -o json >graylog.json
kubeseal --controller-name sealed-secrets --controller-namespace system < graylog.json > graylog-final.json
```

> NOTE: `--controller-namespace system` is this chart's default sealed-secrets controller namespace — see the
> [sealed-secrets README](../sealed-secrets/README.md#a-note-on-the-controller-namespace) if your cluster deploys
> the controller elsewhere.

See [Opensearch](#opensearch-elasticsearch-fork-with-open-source-license) below for the separate `graylog-es-svc`
secret.

## Port forwarding to access the Graylog

**Note: this is handy when authentication via header is enabled.**

```sh
kubectl port-forward -n graylog svc/graylog 9091:9000
```

## set admin password (in standalone setup)

Helm chart takes care of converting the password into `sha256` hash. [configure](https://docs.graylog.org/en/4.0/pages/getting_started/configure.html)

```sh
echo -n "Enter Password: " && head -1 </dev/stdin | tr -d '\n' | sha256sum | cut -d" " -f1
```

Push this new string out in graylog secret - key graylog-password-sha2

## Beats input

To create Beats input, go to the web interface:

* Go to the inputs page (Menu bar->System->Inputs)
* In the "Select input" drop down menu, select "Beats"
* Click "Launch new input"
* Enter the following in the form:
  * Title: Beats
  * Port: 5044
  * Enable the "Do not add Beats type as prefix" option, at the bottom
* Click "Save"

## Index and log retention configuration

* Go to the "Configure Index Set" page (Menu bar->System->Indices)
* Click the `edit` button, next to the "Default index set"
* In the "Index Rotation Configuration" section
  * Select rotation strategy: `Index Time`
  * Rotation period: `P1D`
* In the "Index Retention Configuration" section
  * Select retention strategy: `Delete Index`
  * Max number of indices: `180`

## trigger index cycle now (instead of at night)

```sh
curl -XPOST http://127.0.0.1:9000/api/system/deflector/cycle -H 'X-Requested-By: localhost'
```

login (user+password) can be found in secret called graylog - field `data.graylog-password-secret`

## Connecting MongoDB

Graylog needs to connect to MongoDB to store configs. This chart uses the MongoDB operator to
add a database by creating an object of `kind: MongoDBCommunity`.

The object also tells the operator to create a separate `graylog` database
and a `graylog-user` with the `readWrite` and `dbAdmin` roles. It expects a secret `graylog-user-password`
containing the password which will be used by graylog client later.

Graylog 7.2 needs `dbAdmin`: at startup it runs `collMod` on `cluster_events`, which fails with `Unauthorized`
without it. Helm replaces lists instead of merging them, so if you override `global.mongodb.users`, repeat the whole
user with both roles.

The connection string for the graylog client is generated and kept in a secret
called `mongodb-replica-set-graylog-graylog-user`. The string is of the form :

```bash
mongodb://graylog-user:<password>@mongodb-replica-set-0.mongodb-replica-set-svc.graylog.svc.cluster.local:27017/graylog?replicaSet=mongodb-replica-set&ssl=false
```

This username and password combination allows the Graylog client to authenticate itself to the MongoDB instance.

**NOTE: Do not use `userAdminAnyDatabase` role of MongoDB as it does not have permissions to create index.**

Create the mongodb graylog-user password. `passwordSecretRef.name: graylog-user-password` in values.yaml expects
this secret in the same namespace as the `MongoDBCommunity` object (`graylog`, not `default`):

```bash
kubectl create secret generic graylog-user-password -n graylog --dry-run=client --from-literal=password=lolpassword -o yaml
```

## Critical configuration: prevent deflector race conditions

By default, OpenSearch allows the automatic creation of indices. If the cluster experiences temporary instability
during a Graylog index rotation, incoming log traffic can cause OpenSearch to mistakenly auto-create a physical
`graylog_deflector` index before Graylog has a chance to create the routing alias. This creates a roadblock that
completely breaks the log ingestion pipeline.

To prevent this race condition, you must explicitly forbid OpenSearch from auto-creating any index containing the
word "deflector".

Apply the following persistent cluster setting:

```bash
curl -X PUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "action.auto_create_index": "-*deflector*,+*"
  }
}
'
```

## Opensearch (elasticsearch fork with open source license)

```bash
kubectl create secret generic graylog-es-svc -n graylog --from-literal=url='http://admin:admin@opensearch-cluster-master:9200' -o yaml
```

## Upgrade Instruction

> [!CAUTION]
> Upgrade Graylog one minor version at a time (6.3 → 7.0 → 7.1 → 7.2) and MongoDB one major version at a time
> (5.0 → 6.0 → 7.0), each at its latest patch. Skipping a version can break Graylog's database migrations. Check
> every step against the compatibility matrix in
> [Graylog's upgrade guide](https://go2docs.graylog.org/current/upgrading_graylog/upgrading_graylog.html).

Tested path: Graylog 6.3.1 → 7.2.1, MongoDB 5.0.14 → 7.0.45 and OpenSearch 2.19.2 → 3.7.0. Go in the order below,
one version per sync, and check the pods and logs after each sync.

### Before you start

* Back up MongoDB. With `global.mongodb.logicalbackup.enabled`, run the backup job:

    ```bash
    kubectl create job --from=cronjob/mongodb-replica-set-backup manual-backup -n graylog
    ```

* Set the PVs to `Retain` and check that no PVC is already being deleted. A PVC deleted while its pod runs stays
  `Terminating` until the next restart. The upgrade restart then finishes the delete, and the pod comes back on an
  empty disk. With the default `Delete` policy, the old disk is gone too.

    ```bash
    kubectl -n graylog get pvc -o jsonpath='{range .items[*]}{.spec.volumeName}{"\n"}{end}' \
      | xargs -I{} kubectl patch pv {} -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
    kubectl -n graylog get pvc -o custom-columns=NAME:.metadata.name,DELETING:.metadata.deletionTimestamp   # DELETING must be <none>
    ```

### 1. Upgrading MongoDB

Graylog 7.0 needs MongoDB 7.0 or newer, so MongoDB goes first.

* Set `global.mongodb.version` to the latest patch of the next major version, sync, and wait until every member runs
  it.
* Raise `featureCompatibilityVersion` to the new major version before the next step. The operator keeps the old
  value after an upgrade, and this chart doesn't set it:

    ```bash
    kubectl -n graylog patch mongodbcommunity mongodb-replica-set --type merge -p '{"spec":{"featureCompatibilityVersion":"6.0"}}'
    ```

### 2. Upgrading Graylog

Pin `graylog.graylog.image.tag` to the latest patch of the next minor version, then sync.

* 7.0: only the leader, `graylog-0`, runs the database migrations, but the StatefulSet updates the highest pod first.
  With TCP inputs, a follower on 7.0 fails with `Couldn't deserialize value (encrypted_value and salt must be strings
  and cannot be missing)` until the leader has migrated. Move the leader to 7.0, then delete any follower that still
  fails:

    ```bash
    # Without an explicit partition, the StatefulSet recreates graylog-0 on the old version.
    kubectl -n graylog patch sts graylog --type merge -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
    kubectl -n graylog delete pod graylog-0
    ```

* 7.1 ends all sessions, so everyone has to log in again.
* 7.2 needs the `dbAdmin` role on the `graylog` database (see [Connecting MongoDB](#connecting-mongodb)).

### 3. Upgrading OpenSearch

OpenSearch goes last. Graylog 7.2 supports OpenSearch up to 3.7.x, and the opensearch chart defaults to a newer
version, so pin the image in the opensearch values:

```yaml
opensearch:
  image:
    tag: "3.7.0"
```

OpenSearch can't be downgraded. With `backup.enable` set in the opensearch values, take a snapshot first:

```bash
kubectl create job --from=cronjob/opensearch-s3-snapshot-create manual-snapshot -n graylog
```

1. Pause message processing on every Graylog node (System → Nodes → More actions). Messages then wait in the
   journal instead of failing to index while OpenSearch restarts.
2. From an OpenSearch pod, restrict shard allocation to primaries and flush:

    ```bash
    curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}'
    curl -X POST localhost:9200/_flush
    ```

3. Sync the opensearch application and wait until every pod runs the new version. During a major upgrade, a node
   still on the old version drops out of the cluster until it's upgraded. This is expected.
4. Re-enable allocation, then restart Graylog. Graylog has to be restarted after a major OpenSearch upgrade, and the
   restart also resumes processing:

    ```bash
    curl -X PUT localhost:9200/_cluster/settings -H 'Content-Type: application/json' -d '{"persistent":{"cluster.routing.allocation.enable":null}}'
    kubectl -n graylog rollout restart sts/graylog
    ```

## Backup and Restore (source -> target migration runbook)

This section documents a tested procedure to migrate Graylog configuration data from a
source cluster to a target cluster.

### Naming convention used in this guide

* `source -> target`: generic migration direction.
* `<source-context>` / `<target-context>`: `kubectl` contexts for source and target clusters.
* Replace placeholders with your environment-specific names before running commands.

### Scope

* Backs up and restores the Graylog MongoDB config database.
* Does **not** restore OpenSearch indices (target OpenSearch stays empty by design).

### 1) Audit source versions

Capture and document exact runtime versions before migration:

* Graylog image tag
* MongoDB image tag
* OpenSearch image tag

Example:

```bash
kubectl --context <source-context> -n graylog get pods -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{range .spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
```

### 2) Create MongoDB dump on source

Use the generated Graylog Mongo connection string from secret
`mongodb-replica-set-graylog-graylog-user` and run `mongodump` inside the MongoDB pod.

```bash
CTX_SOURCE='<source-context>'
NS='graylog'
URI="$(kubectl --context "$CTX_SOURCE" -n "$NS" get secret mongodb-replica-set-graylog-graylog-user -o jsonpath='{.data.connectionString\.standard}' | base64 -d)"

kubectl --context "$CTX_SOURCE" -n "$NS" exec mongodb-replica-set-0 -c mongod -- \
  env HOME=/tmp sh -c "mongodump --uri='$URI' --db graylog --excludeCollection=index_failures --out /tmp/graylog-dump"
kubectl --context "$CTX_SOURCE" -n "$NS" exec mongodb-replica-set-0 -c mongod -- \
  tar czf /tmp/graylog-mongo-dump.tgz -C /tmp graylog-dump
kubectl --context "$CTX_SOURCE" -n "$NS" cp mongodb-replica-set-0:/tmp/graylog-mongo-dump.tgz ./graylog-mongo-dump.tgz
```

Note: `index_failures` may need to be excluded if pod memory is constrained.

### 3) Restore dump on target

Scale Graylog down before restore, restore DB, then scale Graylog back up.

```bash
CTX_TARGET='<target-context>'
NS='graylog'
URI="$(kubectl --context "$CTX_TARGET" -n "$NS" get secret mongodb-replica-set-graylog-graylog-user -o jsonpath='{.data.connectionString\.standard}' | base64 -d)"

kubectl --context "$CTX_TARGET" -n "$NS" scale statefulset graylog --replicas=0
kubectl --context "$CTX_TARGET" -n "$NS" cp ./graylog-mongo-dump.tgz mongodb-replica-set-0:/tmp/graylog-mongo-dump.tgz
kubectl --context "$CTX_TARGET" -n "$NS" exec mongodb-replica-set-0 -c mongod -- \
  sh -c "mkdir -p /tmp/restore && tar xzf /tmp/graylog-mongo-dump.tgz -C /tmp/restore"
kubectl --context "$CTX_TARGET" -n "$NS" exec mongodb-replica-set-0 -c mongod -- \
  env HOME=/tmp mongorestore --uri "$URI" --drop /tmp/restore/graylog-dump/graylog
kubectl --context "$CTX_TARGET" -n "$NS" scale statefulset graylog --replicas=2
```

### 4) Post-restore requirements

If Graylog fails with `Invalid password_secret! Failed to decrypt values from MongoDB`,
sync the target `graylog` secret values with the source cluster values for:

* `graylog-password-secret`
* `graylog-password-sha2`

These are crypto settings used by Graylog to decrypt DB content and must match restored data.

### 5) Login/password reset note

In this dataset, MongoDB user passwords are stored in legacy format:

`{bcrypt}<hash>{salt}<hash-prefix>`

If manual password reset is needed, preserve this format; storing plain `$2a$...` or
`{bcrypt}$2a$...` only can lead to login failures.

### 6) Validation checklist

After restore, verify:

* Graylog UI is accessible on target.
* Key config object counts match source for:
  * `streams`
  * `dashboards`
  * `event_definitions`
  * `pipeline_processor_rules`
  * `pipeline_processor_pipelines`
  * `inputs`
* OpenSearch has no historical data (fresh/empty target as intended).

The `mongodb-operator` chart was renamed to [`mongodb-kubernetes`](../mongodb-kubernetes/README.md); as of this
writing its README is an MCO-to-MCK migration guide and doesn't cover backup/restore yet — the manual `mongodump`/
`mongorestore` procedure above is the current reference for Graylog's MongoDB data.

### Example migration outcome (source -> target)

Migration is complete and acceptance criteria are satisfied.

* Audited and documented source runtime versions:
  1. Graylog `6.3.1`
  2. MongoDB `5.0.14-ubi8`
  3. OpenSearch `2.19.2`
* Captured MongoDB backup from source (authenticated dump).
* Deployed fresh Graylog/MongoDB/OpenSearch stack on target with matching versions.
* Restored MongoDB dump to target successfully (no restore failures reported).
* Verified Graylog UI accessibility on target and successful admin-capable login.
* Verified restored configuration parity between source and target for key collections:
  1. `streams` `3/3`
  2. `dashboards` `1/1`
  3. `event_definitions` `1/1`
  4. `pipeline_processor_rules` `0/0`
  5. `pipeline_processor_pipelines` `0/0`
  6. `inputs` `1/1`
  7. `event_notifications` `missing/missing`
  8. `lookup_tables` `missing/missing`

Notes:

* `index_failures` was excluded from backup due to OOM on full dump attempt; this is an expected limitation in constrained environments.
* Password reset/login issue was resolved by using the dataset's expected legacy Graylog password storage format: `{bcrypt}...{salt}...`.

## Docs

- [Monitoring in KubeAid](../../docs/monitoring.md) — how Graylog compares to OpenObserve and OpenSearch + Kibana.
- [mongodb-kubernetes](../mongodb-kubernetes/README.md) — the MongoDB operator backing Graylog's config store.
