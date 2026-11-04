#!/bin/sh
# machine-type-picker: keeps every HCloud machine template of the cluster on a
# server type that Hetzner can create right now.
#
# Why this exists: CAPH treats "server type not offered in this location"
# (invalid_input) and "no capacity" (resource_unavailable) as irrecoverable,
# HCloudMachine.spec.type and HCloudMachineTemplate.spec are immutable, and the
# MachineHealthCheck replaces a stuck Machine with one of the same type. So a
# control-plane node that dies while its type is unavailable in that region is
# replaced by a Machine that fails forever, and the cluster sits one failure
# away from losing etcd quorum.
#
# The fix has two halves, both rendered by templates/MachineTypeFallback.yaml:
#   - this script decides, per template, which listed server type to use and
#     writes it to the <cluster>-machine-type-overrides ConfigMap;
#   - a Kyverno MutatingPolicy rewrites spec.type on HCloudMachine CREATE from
#     that ConfigMap. Nothing that already exists is changed, so no rollout.
#
# Each iteration:
#   1. refresh GET /v1/server_types (per-location availability and deprecation)
#      every API_INTERVAL_SECONDS;
#   2. record server types that really failed to create, as type@region, for
#      FAILURE_COOLDOWN_SECONDS (the API's "available" is only an indicator);
#   3. pick, per template, the first listed type usable in every region the
#      template can land in, and no smaller / no other architecture than the
#      configured type;
#   4. write the overrides and state ConfigMaps when they change;
#   5. delete Machines whose server was never created and whose template now
#      has another type, so they are recreated straight away instead of after
#      the MachineHealthCheck's node startup timeout.
#
# Usage: machine-type-picker.sh [loop|once|decide]
#   loop    (default) run an iteration every INTERVAL_SECONDS, forever
#   once    run one iteration
#   decide  read the decision input as JSON on stdin, print the decision; the
#           pure core of step 3-5, used by tests/machine-type-picker/run.sh
set -eu

FALLBACKS_FILE=${FALLBACKS_FILE:-/config/fallbacks.json}
INTERVAL_SECONDS=${INTERVAL_SECONDS:-30}
API_INTERVAL_SECONDS=${API_INTERVAL_SECONDS:-60}
FAILURE_COOLDOWN_SECONDS=${FAILURE_COOLDOWN_SECONDS:-3600}
DELETE_FAILED_MACHINES=${DELETE_FAILED_MACHINES:-true}
HCLOUD_ENDPOINT=${HCLOUD_ENDPOINT:-https://api.hetzner.cloud/v1}
HEARTBEAT_FILE=${HEARTBEAT_FILE:-/tmp/heartbeat}
WORK_DIR=${WORK_DIR:-/tmp/machine-type-picker}
DRY_RUN=${DRY_RUN:-false}

# Decision input:
#   {now, cooldown, cluster, deleteFailedMachines,
#    fallbacks: {<template>: {types: [configured, fallback...], regions: [...], allowArchitectureChange}},
#    serverTypes: [{name, architecture, cores, memory, disk,
#                   locations: [{name, available, deprecation: {unavailable_after}}]}] or null when unknown,
#    hcloudMachines: [...], machines: [...],
#    overrides: {<template>: <type>}, state: {failures, deletes, noCandidate}}
# Output: {overrides, state, deletes: [{machine, hcloudMachine, template, type, region}], events, decisions}
DECIDE_JQ=$(cat <<'EOF'
def ts: .[0:19] + "Z" | fromdateiso8601;
def lookup($types; $name): first($types[] | select(.name == $name)) // null;
def location($t; $region): [($t.locations // [])[] | select(.name == $region)] | .[0];
def usable($t; $region; $now; $failures):
  location($t; $region) as $loc
  | $loc != null
    and $loc.available == true
    and (($loc.deprecation.unavailable_after // null) as $ua | $ua == null or ($ua | ts) > $now)
    and $failures[$t.name + "@" + $region] == null;
# A fallback must not break what was sized for the configured type: the
# MachineDeployment's cluster-autoscaler capacity annotations, and images and
# workloads built for one CPU architecture.
def fits($t; $primary; $allowArch):
  $primary == null
  or (($allowArch or $t.architecture == $primary.architecture)
      and $t.cores >= $primary.cores
      and $t.memory >= $primary.memory
      and $t.disk >= $primary.disk);

.now as $now
| .cooldown as $cooldown
| .cluster as $cluster
| (.deleteFailedMachines == true) as $deleteFailed
| (.fallbacks // {}) as $fallbacks
| .serverTypes as $types
| (.overrides // {}) as $previous
| (.state.failures // {}) as $previousFailures
| (.state.deletes // {}) as $previousDeletes
| (.state.noCandidate // []) as $previousNoCandidate
| ([(.machines // [])[] | {key: .metadata.name, value: .}] | from_entries) as $machines

# HCloudMachines of this cluster whose server CAPH gave up creating.
| [ (.hcloudMachines // [])[]
    | select((.metadata.labels["cluster.x-k8s.io/cluster-name"] // "") == $cluster)
    | select(
        ((.status.conditions // []) | any(.type == "ServerCreateSucceeded" and .status == "False" and .reason == "ServerCreateFailedIrrecoverableError"))
        or ((.status.v1beta2.conditions // []) | any(.type == "ServerCreated" and .status == "False" and .reason == "CreationFailedIrrecoverably")))
    | select((.spec.providerID // "") == "")
    | ((.metadata.ownerReferences // []) | map(select(.kind == "Machine")) | .[0].name // "") as $machine
    | {
        hcloudMachine: .metadata.name,
        type: .spec.type,
        template: (.metadata.annotations["cluster.x-k8s.io/cloned-from-name"] // ""),
        machine: $machine,
        region: ($machines[$machine].spec.failureDomain // .status.region // "")
      }
  ] as $failed

# A real create failure beats the API: type@region stays unusable for $cooldown
# after it was last seen. Unknown region: every region of the template.
| ($previousFailures
   + ([ $failed[] as $f
        | (if $f.region != "" then [$f.region] else ($fallbacks[$f.template].regions // []) end)[]
        | {key: ($f.type + "@" + .), value: $now} ] | from_entries)
   | with_entries(select(.value + $cooldown > $now))
  ) as $failures

# Per template: the first listed type usable in every region it can land in.
| (if $types == null then null else
    [ $fallbacks | to_entries[]
      | .key as $template
      | .value as $cfg
      | $cfg.types[0] as $primaryName
      | lookup($types; $primaryName) as $primary
      | [ $cfg.types[] as $name
          | lookup($types; $name) as $t
          | select($t != null)
          | select($name == $primaryName or fits($t; $primary; ($cfg.allowArchitectureChange // false)))
          | select(all(($cfg.regions // [])[]; usable($t; .; $now; $failures)))
          | $name
        ] as $candidates
      | {
          template: $template,
          primary: $primaryName,
          chosen: ($candidates[0] // null),
          primaryKnown: ($primary != null)
        }
    ]
  end) as $decisions

# Only templates that need another type get a key. When nothing is usable, or
# the API could not be read, the current choice stays.
| (if $decisions == null then $previous
   else reduce $decisions[] as $d ({};
     if $d.chosen == null then
       (if $previous[$d.template] != null then .[$d.template] = $previous[$d.template] else . end)
     elif $d.chosen != $d.primary then .[$d.template] = $d.chosen
     else . end)
   end) as $overrides

| (if $decisions == null then $previousNoCandidate
   else [$decisions[] | select(.chosen == null) | .template] end) as $noCandidate

# Delete a stuck Machine only when its server never existed (no node, no etcd
# member) and its template now gets another type. Backoff per template: 2 min,
# doubling, at most 15 min; it resets once the template has no stuck Machines.
| ([$failed[].template] | unique) as $failingTemplates
| ($previousDeletes | with_entries(select(.key as $k | any($failingTemplates[]; . == $k)))) as $backoff
| [ $failed[]
    | select(.machine != "")
    | select(($overrides[.template] // null) != null and $overrides[.template] != .type)
    | select($machines[.machine] != null)
    | select($machines[.machine].metadata.deletionTimestamp == null)
    | select($machines[.machine].status.nodeRef == null)
  ] as $deletable
| (if $deleteFailed | not then {deletes: [], backoff: $backoff}
   else reduce ($deletable | group_by(.template))[] as $group ({deletes: [], backoff: $backoff};
     $group[0].template as $template
     | (.backoff[$template] // {last: 0, count: 0}) as $b
     | (if $b.count == 0 then 0 else ([120 * pow(2; $b.count - 1), 900] | min) end) as $delay
     | if $now >= $b.last + $delay then
         .deletes += $group
         | .backoff[$template] = {last: $now, count: ($b.count + 1)}
       else . end)
   end) as $deleting

| [ ($overrides | to_entries[]
      | select($previous[.key] != .value)
      | {type: "Warning", reason: "MachineTypeFallbackActive",
         message: "\(.key): new machines are created as \(.value) instead of \($fallbacks[.key].types[0] // "the configured type"), which cannot be created in every region it can land in right now."}),
    ($previous | to_entries[]
      | select($overrides[.key] == null)
      | {type: "Normal", reason: "MachineTypeFallbackCleared",
         message: "\(.key): new machines are created with the configured server type again (was \(.value))."}),
    ($noCandidate[] | select(. as $t | any($previousNoCandidate[]; . == $t) | not)
      | {type: "Warning", reason: "MachineTypeFallbackNoCandidate",
         message: "\(.): none of the listed server types can be created in every region it can land in; keeping the current choice."}),
    ($deleting.deletes[]
      | {type: "Normal", reason: "MachineTypeFallbackRetry",
         message: "Deleted Machine \(.machine): its server could not be created as \(.type), so it is recreated as \($overrides[.template])."})
  ] as $events

| {
    overrides: $overrides,
    state: {failures: $failures, deletes: $deleting.backoff, noCandidate: $noCandidate},
    deletes: $deleting.deletes,
    events: $events,
    decisions: $decisions
  }
EOF
)

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

k() {
  kubectl --request-timeout=20s -n "$NAMESPACE" "$@"
}

# Refresh the cached server type list when it is older than API_INTERVAL_SECONDS.
# On any API error the previous cache stays; run_once decides whether it is
# still fresh enough to act on.
refresh_server_types() {
  cache="$WORK_DIR/server_types.json"
  if [ -s "$cache" ] && [ $(($1 - $(stat -c %Y "$cache"))) -lt "$API_INTERVAL_SECONDS" ]; then
    return 0
  fi
  : >"$WORK_DIR/server_types.ndjson"
  page=1
  while [ -n "$page" ]; do
    # The token goes to curl on stdin, never on the command line.
    if ! printf 'header = "Authorization: Bearer %s"\n' "$HCLOUD_TOKEN" |
      curl -fsS --max-time 20 -K - "$HCLOUD_ENDPOINT/server_types?per_page=50&page=$page" >"$WORK_DIR/page.json"; then
      log "could not read $HCLOUD_ENDPOINT/server_types; keeping the last known server types"
      return 0
    fi
    jq -c '.server_types[] | {name, architecture, cores, memory, disk,
      locations: [(.locations // [])[] | {name, available, deprecation}]}' \
      "$WORK_DIR/page.json" >>"$WORK_DIR/server_types.ndjson"
    page=$(jq -r '.meta.pagination.next_page // empty' "$WORK_DIR/page.json")
  done
  jq -s . "$WORK_DIR/server_types.ndjson" >"$cache.new"
  mv "$cache.new" "$cache"
}

# apply_configmap NAME DATA_JSON
apply_configmap() {
  if [ "$DRY_RUN" = true ]; then
    log "dry run: would write ConfigMap $1: $2"
    return 0
  fi
  jq -n \
    --arg name "$1" --arg ns "$NAMESPACE" --arg cluster "$CLUSTER_NAME" \
    --arg owner "$OWNER_CM" --arg uid "$owner_uid" --argjson data "$2" '{
      apiVersion: "v1", kind: "ConfigMap",
      metadata: {
        name: $name, namespace: $ns,
        labels: {
          "app.kubernetes.io/managed-by": "hcloud-machine-type-picker",
          "cluster.x-k8s.io/cluster-name": $cluster
        },
        # Owned by the chart-managed fallbacks ConfigMap, so both go away when
        # the feature is switched off and ArgoCD prunes it.
        ownerReferences: (if $uid == "" then [] else
          [{apiVersion: "v1", kind: "ConfigMap", name: $owner, uid: $uid}] end)
      },
      data: $data
    }' | k apply --server-side --force-conflicts --field-manager=hcloud-machine-type-picker -f - >/dev/null
}

# emit_event EVENT_JSON ({type, reason, message}), recorded on the Cluster.
emit_event() {
  if [ -z "$cluster_uid" ]; then
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    log "dry run: would record event $1"
    return 0
  fi
  printf '%s' "$1" | jq -c \
    --arg ns "$NAMESPACE" --arg cluster "$CLUSTER_NAME" --arg uid "$cluster_uid" \
    --arg apiVersion "$cluster_api_version" --arg pod "${POD_NAME:-}" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
      apiVersion: "v1", kind: "Event",
      metadata: {generateName: ($cluster + ".machine-type-"), namespace: $ns},
      involvedObject: {apiVersion: $apiVersion, kind: "Cluster", name: $cluster, namespace: $ns, uid: $uid},
      type: .type, reason: .reason, message: .message,
      source: {component: "hcloud-machine-type-picker"},
      reportingComponent: "hcloud-machine-type-picker", reportingInstance: $pod,
      firstTimestamp: $ts, lastTimestamp: $ts, count: 1
    }' | k create -f - >/dev/null
}

run_once() {
  : "${CLUSTER_NAME:?CLUSTER_NAME is required}"
  : "${NAMESPACE:?NAMESPACE is required}"
  : "${HCLOUD_TOKEN:?HCLOUD_TOKEN is required}"
  case "$DELETE_FAILED_MACHINES" in
  true | false) ;;
  *)
    log "DELETE_FAILED_MACHINES must be true or false, got $DELETE_FAILED_MACHINES"
    exit 1
    ;;
  esac
  OVERRIDES_CM=${OVERRIDES_CM:-$CLUSTER_NAME-machine-type-overrides}
  STATE_CM=${STATE_CM:-$CLUSTER_NAME-machine-type-fallback-state}
  OWNER_CM=${OWNER_CM:-$CLUSTER_NAME-machine-type-fallbacks}
  # Server type data older than this is not acted on: overrides stay as they are.
  STALE_SECONDS=${STALE_SECONDS:-$((API_INTERVAL_SECONDS * 10))}

  mkdir -p "$WORK_DIR"
  now=$(date +%s)

  refresh_server_types "$now"
  if [ -s "$WORK_DIR/server_types.json" ] &&
    [ $((now - $(stat -c %Y "$WORK_DIR/server_types.json"))) -le "$STALE_SECONDS" ]; then
    cp "$WORK_DIR/server_types.json" "$WORK_DIR/types.input.json"
  else
    echo null >"$WORK_DIR/types.input.json"
    log "no server type data younger than ${STALE_SECONDS}s; overrides stay as they are"
  fi

  k get hcloudmachines.infrastructure.cluster.x-k8s.io -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o json >"$WORK_DIR/hcloudmachines.json"
  k get machines.cluster.x-k8s.io -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o json >"$WORK_DIR/machines.json"
  k get configmap "$OVERRIDES_CM" -o json --ignore-not-found >"$WORK_DIR/overrides.cm.json"
  k get configmap "$STATE_CM" -o json --ignore-not-found >"$WORK_DIR/state.cm.json"
  k get clusters.cluster.x-k8s.io "$CLUSTER_NAME" -o json --ignore-not-found >"$WORK_DIR/cluster.json"
  owner_uid=$(k get configmap "$OWNER_CM" -o jsonpath='{.metadata.uid}' --ignore-not-found)

  if [ -s "$WORK_DIR/overrides.cm.json" ]; then
    overrides_exist=true
    jq '.data // {}' "$WORK_DIR/overrides.cm.json" >"$WORK_DIR/overrides.json"
  else
    overrides_exist=false
    echo '{}' >"$WORK_DIR/overrides.json"
  fi
  if [ -s "$WORK_DIR/state.cm.json" ]; then
    jq '.data["state.json"] // "{}" | fromjson' "$WORK_DIR/state.cm.json" >"$WORK_DIR/state.json"
  else
    echo '{}' >"$WORK_DIR/state.json"
  fi
  cluster_uid=""
  cluster_api_version=""
  if [ -s "$WORK_DIR/cluster.json" ]; then
    cluster_uid=$(jq -r '.metadata.uid' "$WORK_DIR/cluster.json")
    cluster_api_version=$(jq -r '.apiVersion' "$WORK_DIR/cluster.json")
  fi

  jq -n \
    --argjson now "$now" --argjson cooldown "$FAILURE_COOLDOWN_SECONDS" \
    --arg cluster "$CLUSTER_NAME" --argjson deleteFailed "$DELETE_FAILED_MACHINES" \
    --slurpfile fallbacks "$FALLBACKS_FILE" \
    --slurpfile types "$WORK_DIR/types.input.json" \
    --slurpfile hcloudMachines "$WORK_DIR/hcloudmachines.json" \
    --slurpfile machines "$WORK_DIR/machines.json" \
    --slurpfile overrides "$WORK_DIR/overrides.json" \
    --slurpfile state "$WORK_DIR/state.json" \
    '{now: $now, cooldown: $cooldown, cluster: $cluster, deleteFailedMachines: $deleteFailed,
      fallbacks: $fallbacks[0], serverTypes: $types[0],
      hcloudMachines: $hcloudMachines[0].items, machines: $machines[0].items,
      overrides: $overrides[0], state: $state[0]}' >"$WORK_DIR/input.json"
  jq -c "$DECIDE_JQ" "$WORK_DIR/input.json" >"$WORK_DIR/result.json"

  jq -r '(.decisions // [])[] | select(.chosen != .primary or (.primaryKnown | not)) |
    "\(.template): " +
    (if .chosen == null then "no listed server type can be created in all its regions"
     elif .chosen == .primary then "using the configured \(.primary)"
     else "using \(.chosen) instead of \(.primary)" end) +
    (if .primaryKnown then "" else " (\(.primary) is unknown to the API, so size and architecture checks are skipped)" end)' \
    "$WORK_DIR/result.json" | while read -r line; do log "$line"; done

  # Overrides first: a Machine deleted below must be recreated on the new type.
  # The ConfigMap is written even when empty, so the Kyverno policy always finds it.
  new_overrides=$(jq -cS '.overrides' "$WORK_DIR/result.json")
  if [ "$overrides_exist" = false ] || [ "$new_overrides" != "$(jq -cS . "$WORK_DIR/overrides.json")" ]; then
    apply_configmap "$OVERRIDES_CM" "$new_overrides"
    log "overrides now $new_overrides"
  fi

  new_state=$(jq -cS '.state' "$WORK_DIR/result.json")
  if [ "$new_state" != "$(jq -cS . "$WORK_DIR/state.json")" ]; then
    apply_configmap "$STATE_CM" "$(jq -cn --arg state "$new_state" '{"state.json": $state}')"
  fi

  jq -r '.deletes[] | .machine' "$WORK_DIR/result.json" | while read -r machine; do
    if [ "$DRY_RUN" = true ]; then
      log "dry run: would delete Machine $machine"
    elif k delete machines.cluster.x-k8s.io "$machine" --wait=false >/dev/null; then
      log "deleted Machine $machine, its server was never created; it is recreated on the new type"
    else
      log "could not delete Machine $machine"
    fi
  done

  jq -c '.events[]' "$WORK_DIR/result.json" | while read -r event; do
    emit_event "$event" || log "could not record event $event"
  done
}

case "${1:-loop}" in
decide)
  jq -c "$DECIDE_JQ"
  ;;
once)
  run_once
  ;;
loop)
  log "starting for cluster ${CLUSTER_NAME:-?}: every ${INTERVAL_SECONDS}s, server types every ${API_INTERVAL_SECONDS}s"
  while :; do
    # A separate process per iteration: set -e stops a failing iteration, not
    # the daemon. The heartbeat only proves the loop is not stuck.
    sh "$0" once || log "iteration failed; next try in ${INTERVAL_SECONDS}s"
    touch "$HEARTBEAT_FILE"
    sleep "$INTERVAL_SECONDS"
  done
  ;;
*)
  echo "usage: $0 [loop|once|decide]" >&2
  exit 2
  ;;
esac
