#!/bin/sh
# OpenSearch snapshots of one indexer (the central search or a tenant's).
#
# A run is idempotent: it registers the snapshot repository, keeps the Snapshot
# Management policy in step, applies the shard-copy setting, takes a snapshot
# and deletes the expired ones. `kubeaid-cli siem backup` runs the same Job once
# to take a snapshot out of schedule, so nothing here may depend on the
# schedule or on state from a previous run.
#
# Everything comes from the environment (security-operations backup.opensearch);
# only curl is needed, which the wazuh-indexer image carries.
set -eu

: "${INDEXER_URL:?}" "${REPOSITORY:?}" "${SNAPSHOT_PREFIX:?}" "${INDICES:?}"
: "${INDEXER_USERNAME:?}" "${INDEXER_PASSWORD:?}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
SNAPSHOT_ON_RUN="${SNAPSHOT_ON_RUN:-true}"
NUMBER_OF_REPLICAS="${NUMBER_OF_REPLICAS:-}"
POLICY_BODY="${POLICY_BODY:-}"
POLICY_NAME="${POLICY_NAME:-}"

# The indexer serves HTTPS with a certificate from the SOC CA; /etc/soc-ca/ca.crt
# is mounted when the chart knows it, otherwise fall back to not verifying (the
# call never leaves the pod network).
if [ -r /etc/soc-ca/ca.crt ]; then
  TLS="--cacert /etc/soc-ca/ca.crt"
else
  TLS="--insecure"
fi

# api <method> <path> [body] - prints the response body, fails on a 4xx/5xx.
api() {
  method="$1"
  path="$2"
  body="${3:-}"
  out=$(mktemp)
  if [ -n "$body" ]; then
    code=$(curl -sS $TLS -o "$out" -w '%{http_code}' -X "$method" \
      -u "$INDEXER_USERNAME:$INDEXER_PASSWORD" \
      -H 'Content-Type: application/json' -d "$body" "$INDEXER_URL$path")
  else
    code=$(curl -sS $TLS -o "$out" -w '%{http_code}' -X "$method" \
      -u "$INDEXER_USERNAME:$INDEXER_PASSWORD" "$INDEXER_URL$path")
  fi
  cat "$out"
  rm -f "$out"
  case "$code" in
    2*) return 0 ;;
    *) echo "" >&2; echo "$method $path failed with HTTP $code" >&2; return 1 ;;
  esac
}

echo "==> registering snapshot repository $REPOSITORY"
api PUT "/_snapshot/$REPOSITORY" "$REPOSITORY_BODY" >/dev/null
echo "    ok"

if [ -n "$POLICY_NAME" ] && [ -n "$POLICY_BODY" ]; then
  echo "==> snapshot policy $POLICY_NAME"
  # A policy that exists already is updated, which needs its sequence numbers.
  existing=$(api GET "/_plugins/_sm/policies/$POLICY_NAME" 2>/dev/null || true)
  query=""
  case "$existing" in
    *'"_seq_no"'*)
      seq=$(printf '%s' "$existing" | tr ',' '\n' | sed -n 's/.*"_seq_no":\([0-9]*\).*/\1/p' | head -n1)
      primary=$(printf '%s' "$existing" | tr ',' '\n' | sed -n 's/.*"_primary_term":\([0-9]*\).*/\1/p' | head -n1)
      [ -n "$seq" ] && query="?if_seq_no=$seq&if_primary_term=$primary"
      ;;
  esac
  api PUT "/_plugins/_sm/policies/$POLICY_NAME$query" "$POLICY_BODY" >/dev/null
  echo "    ok"
fi

if [ -n "$NUMBER_OF_REPLICAS" ]; then
  # Applied to the indices that exist; new ones are picked up by the next run.
  # ignore_unavailable, so a pattern that matches nothing yet is not an error.
  echo "==> number_of_replicas=$NUMBER_OF_REPLICAS on $INDICES"
  api PUT "/$INDICES/_settings?ignore_unavailable=true&allow_no_indices=true" \
    "{\"index\":{\"number_of_replicas\":$NUMBER_OF_REPLICAS}}" >/dev/null || \
    echo "    could not set the shard copies (no matching index yet?)" >&2
fi

if [ "$SNAPSHOT_ON_RUN" = "true" ]; then
  name="$SNAPSHOT_PREFIX-$(date -u +%Y%m%d-%H%M%S)"
  echo "==> snapshot $name of $INDICES"
  # wait_for_completion, so the Job's exit status is the snapshot's.
  api PUT "/_snapshot/$REPOSITORY/$name?wait_for_completion=true" \
    "{\"indices\":\"$INDICES\",\"ignore_unavailable\":true,\"include_global_state\":false,\"partial\":false}" \
    >/dev/null
  echo "    ok"
fi

if [ "$RETENTION_DAYS" -gt 0 ]; then
  # The snapshot names carry their UTC timestamp, so an expired one is any whose
  # name sorts before the cutoff. Only this prefix is touched: a snapshot another
  # policy or an operator took is left alone.
  cutoff="$SNAPSHOT_PREFIX-$(date -u -d "-$RETENTION_DAYS days" +%Y%m%d-%H%M%S 2>/dev/null || \
    date -u -v-"$RETENTION_DAYS"d +%Y%m%d-%H%M%S)"
  echo "==> deleting snapshots before $cutoff"
  api GET "/_cat/snapshots/$REPOSITORY?h=id&format=json" \
    | tr ',' '\n' | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' \
    | while read -r snapshot; do
        case "$snapshot" in
          "$SNAPSHOT_PREFIX"-*) ;;
          *) continue ;;
        esac
        if [ "$snapshot" \< "$cutoff" ]; then
          echo "    $snapshot"
          api DELETE "/_snapshot/$REPOSITORY/$snapshot" >/dev/null || true
        fi
      done
fi

echo "done"
