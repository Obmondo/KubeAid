#!/bin/sh
# Proof that the IRIS database backups restore (security-operations
# backup.verifyRestore). A backup nobody has ever restored is a hope, not a
# backup, so once a month:
#
#   1. find the newest completed CloudNativePG Backup of CLUSTER
#   2. recover it into a scratch Cluster (SCRATCH), which reads the same barman
#      object store and touches nothing the live cluster owns
#   3. run QUERY against it
#   4. delete the scratch Cluster and its volumes again
#
# The scratch Cluster is deleted whatever happens, so a failed run leaves no
# volume behind. Only kubectl is needed: the query runs with `kubectl exec` on
# the scratch pod, which has psql.
set -eu

: "${CLUSTER:?}" "${SCRATCH:?}" "${NAMESPACE:?}" "${DATABASE:?}" "${QUERY:?}"
INSTANCES="${INSTANCES:-1}"
STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"
STORAGE_CLASS="${STORAGE_CLASS:-}"
TIMEOUT_MINUTES="${TIMEOUT_MINUTES:-30}"

cleanup() {
  echo "==> deleting the scratch cluster $SCRATCH"
  kubectl -n "$NAMESPACE" delete cluster.postgresql.cnpg.io "$SCRATCH" --ignore-not-found --wait=false || true
  # CloudNativePG keeps the PVCs of a deleted cluster; they are only this check's.
  kubectl -n "$NAMESPACE" delete pvc -l "cnpg.io/cluster=$SCRATCH" --ignore-not-found --wait=false || true
}
trap cleanup EXIT

echo "==> newest completed Backup of $CLUSTER"
backup=$(kubectl -n "$NAMESPACE" get backups.postgresql.cnpg.io \
  -o jsonpath="{range .items[?(@.spec.cluster.name=='$CLUSTER')]}{.status.phase}{' '}{.metadata.creationTimestamp}{' '}{.metadata.name}{'\n'}{end}" \
  | grep '^completed ' | sort -k2 | tail -n1 | awk '{print $3}')
if [ -z "$backup" ]; then
  echo "no completed Backup of $CLUSTER to restore: has a ScheduledBackup ever run?" >&2
  exit 1
fi
echo "    $backup"

echo "==> recovering $backup into $SCRATCH"
# A recovery bootstrap needs no credentials of its own: CloudNativePG restores
# the roles with the data.
kubectl -n "$NAMESPACE" apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: $SCRATCH
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/part-of: security-operations
    kubesoc.io/backup: restore-check
spec:
  instances: $INSTANCES
  inheritedMetadata:
    labels:
      velero.io/exclude-from-backup: "true"
      kubesoc.io/backup: restore-check
  bootstrap:
    recovery:
      backup:
        name: $backup
  storage:
    size: $STORAGE_SIZE
$([ -n "$STORAGE_CLASS" ] && printf '    storageClass: %s\n' "$STORAGE_CLASS")
EOF

echo "==> waiting up to ${TIMEOUT_MINUTES}m for $SCRATCH"
kubectl -n "$NAMESPACE" wait --for=condition=Ready "pod/$SCRATCH-1" --timeout="${TIMEOUT_MINUTES}m"

echo "==> $QUERY"
result=$(kubectl -n "$NAMESPACE" exec "$SCRATCH-1" -c postgres -- \
  psql -U postgres -d "$DATABASE" -tAc "$QUERY")
echo "    $result"
if [ -z "$result" ]; then
  echo "the sanity query returned nothing: the restore is not usable" >&2
  exit 1
fi

echo "restore of $backup verified"
