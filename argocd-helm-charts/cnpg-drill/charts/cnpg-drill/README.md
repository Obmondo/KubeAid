# cnpg-drill Helm chart

This chart installs a suspended CronJob that restores a CloudNativePG Barman
Cloud Plugin backup into a disposable Cluster, checks the recovered database,
prints a JSON report, and removes the drill Cluster and PVCs. It creates a
namespace-scoped ServiceAccount and Role. The scheduled Job does not run until
you set `suspended: false` or create a Job manually.

The chart needs a source CloudNativePG `Cluster`, a completed plugin `Backup`,
and its Barman Cloud `ObjectStore` in the release namespace. A separately named
`ObjectStore` with read-only access to the same archive is recommended for
recovery. See the [full project guide](https://github.com/danielgaskins/cnpg-drill)
and [local validation matrix](https://github.com/danielgaskins/cnpg-drill/tree/main/integration/local).

## First drill

Create a values file with a query that proves useful recovered data is present:

```yaml
cluster: app-db
recoveryObjectStore: app-db-recovery-readonly
checks:
  - name: orders-exist
    database: app
    query: SELECT count(*) > 0 FROM public.orders
    expected: "t"
```

Install the chart in the **same namespace** as the source Cluster and both
ObjectStores. The default image is pinned to a published digest.

```bash
helm install recovery-check oci://ghcr.io/danielgaskins/charts/cnpg-drill \
  --version 0.1.8 --namespace production --values drill-values.yaml
kubectl -n production create job recovery-check-manual \
  --from=cronjob/recovery-check-cnpg-drill
kubectl -n production wait --for=condition=complete job/recovery-check-manual --timeout=35m
kubectl -n production logs job/recovery-check-manual
```

If the Job fails, read its logs for the JSON `failureReason` and `cleanup`
fields. Check the drill Cluster, PVCs, and storage provider volumes after the
first run. The default `SELECT 1` check only proves that the recovered server
accepts a connection; replace it before scheduling recurring drills.

## Important values

| Value | Default | Purpose |
| --- | --- | --- |
| `cluster` | required | Source CloudNativePG Cluster name. |
| `recoveryObjectStore` | empty | Separately credentialed read-only ObjectStore; empty uses the source store. |
| `drillClusterName` | derived from release | Fixed disposable Cluster name; at most 61 characters and different from the source. |
| `rbac.sourcePrimaryPodName` | empty | Explicit source Pod permission for recovered-primary preflight. |
| `rbac.recoveryLogs` | `false` | Grant namespace-wide Pod log access for failure diagnostics. |
| `checks` | `SELECT 1` | Read-only SQL assertions. |
| `schedule` | `0 3 * * 0` | Cron expression, used only after unsuspending. |
| `suspended` | `true` | Prevents an unreviewed scheduled restore. |
| `timeoutSeconds` | `1800` | Drill deadline; the Job gets another three minutes for cleanup. |
| `maxBackupAgeSeconds` | `691200` | Rejects a stale completed Backup before creating a Cluster. |
| `targetTime` | empty | Optional RFC3339 PITR target with a timezone. |
| `retainOnFailure` | `false` | Leaves a failed drill Cluster and its storage for investigation when true. |
| `image.digest` | pinned | Tested container image; set a new digest when updating. |
| `reports.enabled` | `false` | Write each Job's JSON report to a PVC as `<pod-name>.json`. |
| `reports.existingClaim` | empty | Use an existing claim instead of creating one. |
| `reports.size` | `1Gi` | Size of the chart-created claim. |
| `reports.storageClassName` | cluster default | Storage class for the chart-created claim. |
| `alerts.enabled` | `false` | Create a PrometheusRule for failed Jobs, missing success, and missing metrics. |
| `alerts.maxSecondsSinceSuccess` | `691200` | Alert after eight days without a successful scheduled drill. Set this for your schedule. |
| `alerts.labels` | `{}` | Metadata labels used by your Prometheus rule selector. |

The Job always writes the JSON result to its logs. With `reports.enabled: true`,
it also writes a separate file for each Pod to a PVC. The chart creates a
`ReadWriteOnce` claim unless `reports.existingClaim` is set. It retains a
chart-created claim on Helm uninstall so report history is not erased; delete
the claim yourself when you no longer need it. Protect the claim as operational
data: reports contain cluster and backup identifiers, check names, durations,
hashes, and error text.

To retrieve reports, mount the claim in a reader Pod or use your normal PVC
backup process. A scheduled Job runs with UID and GID 10001 and sets
`fsGroup: 10001` so it can write the mounted volume. Your storage driver must
support that ownership behavior. A `ReadWriteOnce` claim can also constrain
where overlapping manual Jobs run; use an existing `ReadWriteMany` claim if
you need concurrent readers or cross-node runs.

`alerts.enabled: true` requires the Prometheus Operator's `PrometheusRule`
CRD, a Prometheus instance that selects this rule through `alerts.labels`, and
kube-state-metrics Job and CronJob metrics. The rules alert when a scheduled
Job fails, when an unsuspended CronJob has no success within
`alerts.maxSecondsSinceSuccess`, or when its CronJob metric is missing. The
last-success rule also covers a CronJob that has never succeeded. Alert
routing is owned by your Prometheus setup; this chart does not send messages.

Turn on recurring drills only after validating the checks, restore cost,
cleanup, storage permissions, and alert routing for your cluster.

Maintained by [Daniel Gaskins](https://danielgaskins.com/).

## Recovery policies

The chart forwards `drillClusterName` and
`recoveryServiceAccountAnnotations` to the drill config. They require chart
0.1.6 and CLI v0.1.4 or later.
See the [recovery policy guide](../../../docs/FIRST-RUN.md#recovery-policies-and-extension-images)
for ownership checks, read-only identity setup, extension images and test limits.

### Permissions in chart 0.1.8

The chart sets a fixed disposable Cluster name, normally `<release>-cnpg-drill-restore`.
It does not use the source's incident restore name. Confirm the chosen name is
reserved for drills and unused before the first run. Concurrent manual runs fail
preflight if that Cluster already exists; retained failures also block later runs.

The Role grants:

- `get` on the named source and drill Clusters.
- `delete`, `list`, and `watch` on the drill Cluster only. kubectl's deletion wait
  includes a name field selector.
- `get` and `pods/exec` on the expected single-instance restore Pod, `<drill-name>-1`.
- Namespace-wide Cluster creation, Backup listing, ObjectStore metadata reads,
  Pod listing, and PVC listing.

The Role does not grant source deletion or source SQL exec by default. It does
not grant Pod log access unless `rbac.recoveryLogs: true`; without that option,
recovery timeouts have a generic failure reason. The drill Job's own report logs
remain available to an operator who has normal log-reading permissions.

Kubernetes RBAC cannot restrict top-level creation by name or constrain a new
Cluster's spec. A compromised drill image could still create a Cluster using
other namespace-local Secret references through the CNPG operator. These narrower
permissions are not isolation from production data. Use admission restrictions
or a separately designed recovery namespace when your trust policy requires it;
this chart currently restores in the source namespace. Review the pinned image
and its provenance before granting access.

The restore uses one instance. If CNPG replaces its first instance with another
Pod name, the Role denies exec and the drill fails; it does not widen permissions.
See [Kubernetes RBAC restrictions](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-resources)
and the [release verification guide](../../../docs/VERIFY-RELEASE.md).

## Recovered primary sources

Chart 0.1.7 uses CLI v0.1.5, which supports a primary originally restored from an
external source once it has its own completed Barman plugin backup. Preflight
checks the source Pod ownership and confirms PostgreSQL has left recovery in a
read-only transaction. The drill reads the current writer archive and the new
backup; it does not reuse the old bootstrap recovery target.

With chart 0.1.8, inspect `status.currentPrimary` and set
`rbac.sourcePrimaryPodName` to that exact Pod name before running against a
recovered source. This deliberately grants exec permission on that source Pod;
a read-only SQL transaction is application behavior, not an RBAC restriction.
If the primary changes, preflight fails until an operator reviews and updates
the allowed name. Ordinary initdb sources need no source exec permission.
