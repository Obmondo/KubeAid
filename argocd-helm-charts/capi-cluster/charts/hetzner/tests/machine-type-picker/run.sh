#!/bin/sh
# The jq programs below are single-quoted on purpose: $now etc. are jq variables.
# shellcheck disable=SC2016
#
# Tests for the decision logic of files/machine-type-picker.sh (its `decide`
# mode). Each case patches base-input.json with a jq program and asserts on the
# decision with another. Needs sh and jq; no cluster, no HCloud API.
#
#   sh argocd-helm-charts/capi-cluster/charts/hetzner/tests/machine-type-picker/run.sh
#
# PICKER_SHELL picks the shell that runs the picker (default sh), e.g. dash or
# busybox sh to match the image.
set -eu
PICKER_SHELL=${PICKER_SHELL:-sh}

here=$(cd "$(dirname "$0")" && pwd)
picker="$here/../../files/machine-type-picker.sh"
base="$here/base-input.json"

# Helpers available to every patch.
helpers='
def loc($type; $region; f):
  .serverTypes |= map(if .name == $type then .locations |= map(if .name == $region then f else . end) else . end);
def unavailable($type; $region): loc($type; $region; .available = false);
def hcm($name; $type; $template; $machine):
  {metadata: {name: $name,
              labels: {"cluster.x-k8s.io/cluster-name": "demo"},
              annotations: {"cluster.x-k8s.io/cloned-from-name": $template},
              ownerReferences: [{kind: "Machine", name: $machine}]},
   spec: {type: $type},
   status: {conditions: [{type: "ServerCreateSucceeded", status: "False", reason: "ServerCreateFailedIrrecoverableError"}]}};
def machine($name; $region): {metadata: {name: $name}, spec: {failureDomain: $region}, status: {}};
def stuckControlPlane:
  .hcloudMachines = [hcm("demo-control-plane-a1"; "cax21"; "demo-control-plane"; "demo-control-plane-m1")]
  | .machines = [machine("demo-control-plane-m1"; "nbg1")];
'

passed=0
failed=0

# check NAME PATCH ASSERT
check() {
  if ! out=$(jq "$helpers $2" "$base" | "$PICKER_SHELL" "$picker" decide); then
    failed=$((failed + 1))
    echo "FAIL $1 (decide failed)"
    return 0
  fi
  if printf '%s' "$out" | jq -e "$3" >/dev/null; then
    passed=$((passed + 1))
    echo "ok   $1"
  else
    failed=$((failed + 1))
    echo "FAIL $1"
    echo "     assert: $3"
    echo "     output: $out"
  fi
}

check "configured types available: nothing to do" \
  '.' \
  '.overrides == {} and .deletes == [] and .events == []'

check "configured type unavailable in one control-plane region: next listed type" \
  'unavailable("cax21"; "hel1")' \
  '.overrides == {"demo-control-plane": "cax31"} and ([.events[].reason] == ["MachineTypeFallbackActive"])'

check "configured type not offered in one control-plane region: next listed type" \
  '.serverTypes |= map(if .name == "cax21" then .locations |= map(select(.name != "nbg1")) else . end)' \
  '.overrides == {"demo-control-plane": "cax31"}'

check "configured type past unavailable_after: next listed type" \
  'loc("cax21"; "fsn1"; .deprecation = {announced: "2019-06-01T00:00:00+00:00", unavailable_after: "2020-01-01T00:00:00+00:00"})' \
  '.overrides == {"demo-control-plane": "cax31"}'

check "configured type with unavailable_after in the future: kept" \
  'loc("cax21"; "fsn1"; .deprecation = {announced: "2026-01-01T00:00:00+00:00", unavailable_after: "2099-01-01T00:00:00+00:00"})' \
  '.overrides == {}'

check "fallback of another architecture is skipped" \
  'unavailable("cax21"; "fsn1") | unavailable("cax31"; "fsn1")' \
  '.overrides == {} and .state.noCandidate == ["demo-control-plane"] and ([.events[].reason] == ["MachineTypeFallbackNoCandidate"])'

check "fallback of another architecture when allowed" \
  'unavailable("cax21"; "fsn1") | unavailable("cax31"; "fsn1") | .fallbacks["demo-control-plane"].allowArchitectureChange = true' \
  '.overrides == {"demo-control-plane": "cpx31"}'

check "bigger fallback is taken" \
  'unavailable("cpx32"; "fsn1")' \
  '.overrides == {"demo-md-0": "cpx42"}'

check "smaller fallback is skipped" \
  'unavailable("cpx32"; "fsn1") | unavailable("cpx42"; "fsn1")' \
  '.overrides == {} and .state.noCandidate == ["demo-md-0"]'

check "recent create failure beats the API" \
  '.now as $now | .state.failures = {"cax21@fsn1": ($now - 100)}' \
  '.overrides == {"demo-control-plane": "cax31"} and (.state.failures | has("cax21@fsn1"))'

check "failure older than the cooldown is forgotten" \
  '.now as $now | .state.failures = {"cax21@fsn1": ($now - 4000)}' \
  '.overrides == {} and .state.failures == {}'

check "stuck machine: failure recorded, override set, Machine deleted" \
  'stuckControlPlane' \
  '(.state.failures | keys) == ["cax21@nbg1"]
   and .overrides == {"demo-control-plane": "cax31"}
   and ([.deletes[].machine] == ["demo-control-plane-m1"])
   and .state.deletes["demo-control-plane"].count == 1
   and ([.events[].reason] | sort == ["MachineTypeFallbackActive", "MachineTypeFallbackRetry"])'

check "stuck machine reported only in v1beta2 conditions" \
  'stuckControlPlane
   | .hcloudMachines[0].status = {v1beta2: {conditions: [{type: "ServerCreated", status: "False", reason: "CreationFailedIrrecoverably"}]}}' \
  '[.deletes[].machine] == ["demo-control-plane-m1"]'

check "server exists (providerID set): not treated as stuck" \
  'stuckControlPlane | .hcloudMachines[0].spec.providerID = "hcloud://1"' \
  '.deletes == [] and .state.failures == {} and .overrides == {}'

check "node already joined: no delete" \
  'stuckControlPlane | .machines[0].status.nodeRef = {name: "demo-control-plane-m1"}' \
  '.deletes == [] and .overrides == {"demo-control-plane": "cax31"}'

check "Machine already deleting: no delete" \
  'stuckControlPlane | .machines[0].metadata.deletionTimestamp = "2026-11-05T00:00:00Z"' \
  '.deletes == []'

check "machines of another cluster are ignored" \
  'stuckControlPlane | .hcloudMachines[0].metadata.labels["cluster.x-k8s.io/cluster-name"] = "other"' \
  '.deletes == [] and .state.failures == {} and .overrides == {}'

check "unknown region: failure recorded in every region of the template" \
  'stuckControlPlane | .machines = []' \
  '(.state.failures | keys) == ["cax21@fsn1", "cax21@hel1", "cax21@nbg1"] and .deletes == []'

check "region from HCloudMachine status when the Machine has none" \
  'stuckControlPlane | .machines[0].spec = {} | .hcloudMachines[0].status.region = "hel1"' \
  '(.state.failures | keys) == ["cax21@hel1"]'

check "backoff holds the next delete" \
  'stuckControlPlane | .now as $now | .state.deletes = {"demo-control-plane": {last: ($now - 60), count: 1}}' \
  '.deletes == [] and .state.deletes["demo-control-plane"].count == 1'

check "backoff over: deleted again, longer backoff next" \
  'stuckControlPlane | .now as $now | .state.deletes = {"demo-control-plane": {last: ($now - 200), count: 1}}' \
  '([.deletes[].machine] == ["demo-control-plane-m1"]) and .state.deletes["demo-control-plane"].count == 2'

check "backoff is capped at 15 minutes" \
  'stuckControlPlane | .now as $now | .state.deletes = {"demo-control-plane": {last: ($now - 901), count: 9}}' \
  '[.deletes[].machine] == ["demo-control-plane-m1"]'

check "backoff resets once nothing is stuck" \
  '.now as $now | .state.deletes = {"demo-control-plane": {last: ($now - 60), count: 3}}' \
  '.state.deletes == {}'

check "deleteFailedMachines false: no delete" \
  'stuckControlPlane | .deleteFailedMachines = false' \
  '.deletes == [] and .overrides == {"demo-control-plane": "cax31"}'

check "configured type usable again: override cleared" \
  '.overrides = {"demo-control-plane": "cax31"}' \
  '.overrides == {} and ([.events[].reason] == ["MachineTypeFallbackCleared"])'

check "server types unknown (API unreadable): overrides kept" \
  '.serverTypes = null | .overrides = {"demo-control-plane": "cax31"}' \
  '.overrides == {"demo-control-plane": "cax31"} and .decisions == null and .events == []'

check "nothing usable: current choice kept" \
  '.overrides = {"demo-control-plane": "cax31"} | unavailable("cax21"; "fsn1") | unavailable("cax31"; "fsn1")' \
  '.overrides == {"demo-control-plane": "cax31"}'

check "no repeated no-candidate event" \
  '.state.noCandidate = ["demo-control-plane"] | unavailable("cax21"; "fsn1") | unavailable("cax31"; "fsn1")' \
  '.events == []'

check "configured type unknown to the API: first listed type that is usable" \
  '.serverTypes |= map(select(.name != "cax21"))' \
  '.overrides == {"demo-control-plane": "cax31"} and (.decisions[] | select(.template == "demo-control-plane") | .primaryKnown == false)'

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
