# Check a CloudNativePG backup restore

This optional chart restores a completed Barman Cloud plugin backup into a disposable CNPG Cluster,
runs read-only SQL assertions, and checks cleanup. It wraps cnpg-drill chart 0.1.8 (CLI 0.1.5).
The image is pinned by digest. No hosted account or telemetry upload is required.
I maintain cnpg-drill and publish its chart and image in my personal GHCR account.

The wrapper is disabled by default. Enabling it creates namespace-scoped RBAC and a suspended CronJob;
installation with these defaults does not start a restore. Run one Job and review its report before enabling a schedule.

## Before running

- Install CloudNativePG and its Barman Cloud plugin using the [cloudnative-pg chart](../cloudnative-pg/readme.md).
- Choose a primary Cluster with a completed plugin backup within your required freshness window.
  A primary originally restored from an external source must have completed its own plugin backup.
  cnpg-drill checks that its current primary has left recovery, then uses the current writer archive.
  Active replicas, distributed replica topologies, pg_basebackup sources, snapshots and tablespaces are unsupported.
- Allow capacity for another copy of the database. Custom source node placement is not copied;
  use your native recovery procedure if it requires specific nodes.
- Create a separate recovery ObjectStore in the source namespace. It must reference the same archive with
  credentials already verified to allow reads and deny writes and deletes. Do not reuse the writer identity.
- Choose application-data assertions that can fail when expected data is missing. `SELECT 1` only checks connectivity.

KubeAid's `kubeaid-addons` chart names the source `<instanceName>-pgsql` and its writer ObjectStore
`<instanceName>-pgsql-backups`. The archive server name is `revision-<revision>`, which differs from the Cluster name.
cnpg-drill reads that server name from the source plugin configuration. Do not change the archive prefix
or server name to the disposable Cluster's name.

For S3 credentials, copy only the writer ObjectStore's `spec.configuration` into a new ObjectStore,
replace its credential references with a read-only Secret, and omit the writer's retention policy.
Match destinationPath, endpointURL, compression and encryption. Do not copy Secret contents into Git.
If using cloud workload identity, configure a separate read-only identity explicitly; see the
[pinned first-run guide](https://github.com/danielgaskins/cnpg-drill/blob/8f4007a12518301c6b6b18f7f34fc0c236c0221f/docs/FIRST-RUN.md).
Cloud IAM permissions are not verified by the tool.

Gitea also stores repository files, attachments and LFS outside PostgreSQL. Back those up and test their
recovery separately. These assertions check database metadata; they do not establish a complete Gitea restore.

## Verify the dependency

The vendored files come from the signed chart 0.1.8 archive. Before enabling the chart,
review the source and verify its release using the [pinned verification guide](https://github.com/danielgaskins/cnpg-drill/blob/8f4007a12518301c6b6b18f7f34fc0c236c0221f/docs/VERIFY-RELEASE.md).
Use a current, authenticated GitHub CLI with attestation support. The expected artifacts are:

| Artifact | Digest | Source commit |
| --- | --- | --- |
| Chart OCI manifest | `sha256:2557d1371806360d0843b5982683998d2670b69d71b2cf5f60b8e00539761737` | `86bad48b4d7c6d5aa6d47b4db751c8d85274da27` |
| Chart archive | `sha256:0bf7c05f31781f3a9acdc7c4066b59587308a6fb6e29c66845f0245be7f8a5ca` | `86bad48b4d7c6d5aa6d47b4db751c8d85274da27` |
| CLI 0.1.5 image | `sha256:139c1e5cd6a1188838aab7396945381b9d015bde56bff0ff360613aa210d286c` | `091ee1d9c379b737ee8c1279f40365a74fcd24cb` |

After the guide verifies and downloads the archive, compare its contents with this wrapper's
vendored dependency. Run this block as a script or in a subshell from the KubeAid repository root:

```bash
set -euo pipefail
shopt -s nullglob
archives=("$CNPG_ARTIFACT_DIR"/cnpg-drill*.tgz)
[[ ${#archives[@]} -eq 1 ]]
tar -xzf "${archives[0]}" -C "$CNPG_ARTIFACT_DIR"
diff -r "$CNPG_ARTIFACT_DIR/cnpg-drill" ./argocd-helm-charts/cnpg-drill/charts/cnpg-drill
```

Stop on any verification failure or unexpected difference. Chart.lock locks the dependency version;
it does not replace this digest and attestation check. Review any image overrides independently.
An attestation identifies a build; it does not establish that its code is safe or satisfy your registry policy.

## Configure and preview

Copy [example-values.yaml](example-values.yaml) into your kubeaid-config repository and adapt it.
The example uses `gitea-pgsql`, database `giteadb`, and requires at least one Gitea user and repository.
It expects a daily backup no older than 25 hours. Use your own database, assertion and freshness requirement.

Export these variables with your chosen names. Use the same KUBECONFIG for Helm and kubectl:

```bash
export KUBECONFIG=/path/to/kubeconfig
export DRILL_CONTEXT=your-context
export DRILL_NAMESPACE=your-source-namespace
export DRILL_RELEASE=backup-check
export DRILL_JOB=backup-check-first
export DRILL_VALUES=/path/to/values-cnpg-drill.yaml
```

Run each block containing `set -euo pipefail` as a script or in a subshell, so a failed check
does not close your interactive shell. From the KubeAid repository root, preview and validate the enabled chart:

```bash
set -euo pipefail
helm template "$DRILL_RELEASE" ./argocd-helm-charts/cnpg-drill \
  --namespace "$DRILL_NAMESPACE" --values "$DRILL_VALUES" \
  --set cnpg-drill.suspended=true --set cnpg-drill.retainOnFailure=false
helm template "$DRILL_RELEASE" ./argocd-helm-charts/cnpg-drill \
  --namespace "$DRILL_NAMESPACE" --values "$DRILL_VALUES" \
  --set cnpg-drill.suspended=true --set cnpg-drill.retainOnFailure=false \
  | kubectl --context "$DRILL_CONTEXT" -n "$DRILL_NAMESPACE" apply --dry-run=server -f -
```

Review the source, recovery store, checks, image digest and RBAC. By default, the Role limits Cluster
deletion to `<release>-cnpg-drill-restore` and Pod exec to that Cluster's first instance (`-1`).
Cleanup removes the Cluster; CNPG removes its owned Pods and PVCs. Backup and Pod/PVC metadata reads
remain namespace-wide. If CNPG replaces the first instance with a differently named Pod, the drill fails.

Cluster creation remains namespace-wide. A compromised image could ask CNPG to use other Secrets in
that namespace through a new Cluster; these permissions do not isolate the tool from production data.
Run it only where your admission and access policies permit this behavior.

For a source originally restored from an external source, set `cnpg-drill.rbac.sourcePrimaryPodName`
to its current primary Pod. This grants get and exec on that named source Pod for the recovery-state
query. The tool runs a read-only query, but RBAC does not restrict exec to that query. Update the value
if the primary changes; do not widen Pod exec permissions. See the [permission details](https://github.com/danielgaskins/cnpg-drill/blob/8f4007a12518301c6b6b18f7f34fc0c236c0221f/deploy/helm/cnpg-drill/README.md#permissions-in-chart-018).

## Run one restore

Use a dedicated release, and a new Job name for each new drill. Keep one drill active per release:
the chart uses a fixed disposable Cluster name and scheduled runs forbid overlap.

```bash
set -euo pipefail
helm upgrade --install "$DRILL_RELEASE" ./argocd-helm-charts/cnpg-drill \
  --namespace "$DRILL_NAMESPACE" --values "$DRILL_VALUES" \
  --set cnpg-drill.suspended=true --set cnpg-drill.retainOnFailure=false \
  --kube-context "$DRILL_CONTEXT" --wait --timeout 5m
kubectl --context "$DRILL_CONTEXT" -n "$DRILL_NAMESPACE" create job "$DRILL_JOB" \
  --from="cronjob/${DRILL_RELEASE}-cnpg-drill"
SECONDS=0
while (( SECONDS < 2400 )); do
  job=$(kubectl --context "$DRILL_CONTEXT" -n "$DRILL_NAMESPACE" get job "$DRILL_JOB" -o json)
  if jq -e 'any(.status.conditions[]?; .type == "Failed" and .status == "True")' <<< "$job" >/dev/null; then
    echo "Restore failed; inspect the Job report." >&2
    exit 1
  fi
  if jq -e 'any(.status.conditions[]?; .type == "Complete" and .status == "True")' <<< "$job" >/dev/null; then
    break
  fi
  sleep 5
done
if (( SECONDS >= 2400 )); then
  echo "Restore timed out; inspect the Job report and temporary resources." >&2
  exit 1
fi
kubectl --context "$DRILL_CONTEXT" -n "$DRILL_NAMESPACE" logs "job/$DRILL_JOB" -c drill \
  | tee recovery-result.json
jq -e -s 'length == 1 and (.[0] | .status == "passed" and .cleanup == "cluster-and-pvcs-deleted"
  and (.checks | length > 0) and all(.checks[]; .passed == true))' recovery-result.json
```

Confirm the report's source, source UID, backup ID and optional targetTime match the intended drill.
Inspect the reported drillCluster and confirm its Cluster, Pods and PVCs are absent; inspect backing PVs
or cloud disks under their reclaim policy. Save the report before deleting the Job.
A failed or missing report is not a verified backup, even if PostgreSQL became ready.
Abrupt termination can leave resources: inspect ownership before cleanup and never delete the source.

## Scheduling through Argo CD

After a successful first run, follow the [umbrella chart guide](../../docs/kubeaid/helm-umbrella-pattern.md)
to add an Application pointing at `argocd-helm-charts/cnpg-drill`. Its destination must be the source namespace;
put your overrides under `cnpg-drill` in its values file. Keep scheduling suspended during setup.
Use one scheduler per source. Review the schedule and SQL checks before setting `cnpg-drill.suspended: false`.

For optional report persistence, alerts and PITR, see the
[upstream chart documentation](https://github.com/danielgaskins/cnpg-drill/blob/8f4007a12518301c6b6b18f7f34fc0c236c0221f/deploy/helm/cnpg-drill/README.md).
The result proves the selected backup and configured assertions in this environment. It does not verify
application login, a regional outage, or every recovery point.
