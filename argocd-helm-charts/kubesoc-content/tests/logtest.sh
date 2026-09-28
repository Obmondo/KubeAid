#!/usr/bin/env bash
# Replays every fixture under tests/<name>/ through wazuh-logtest in a Wazuh
# manager container loaded with this package's rules, decoders and lists, and
# checks the rule id, level and decoder in tests/<name>/expected.json.
#
#   argocd-helm-charts/kubesoc-content/tests/logtest.sh
#
# Needs docker and python3. WAZUH_IMAGE picks the manager image (default the
# version the tenants run); KEEP=1 leaves the container running for debugging.
#
# Fixture layout:
#   tests/<name>/input.log      one event per line, each must match
#   tests/<name>/expected.json  {"rule_id": "99904", "level": 9, "decoder": "sshd",
#                                "location": "optional, e.g. EventChannel"}
#   tests/lists/<name>          test content for lists the package does not ship
#                               (the MISP-fed ones), registered like the real ones
#   tests/rule-excludes.txt     stock rule files the tenants exclude
set -euo pipefail
cd "$(dirname "$0")/.."

image=${WAZUH_IMAGE:-wazuh/wazuh-manager:4.14.3}
name=kubesoc-content-logtest-$$
ossec=/var/ossec

cleanup() {
  if [[ "${KEEP:-}" == 1 ]]; then
    echo "container $name kept"
  else
    docker rm -f "$name" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

wait_analysisd() {
  for _ in $(seq 1 90); do
    if docker exec "$name" "$ossec/bin/wazuh-control" status 2>/dev/null | grep -q 'wazuh-analysisd is running'; then
      # The logtest socket comes up a moment after the process.
      docker exec "$name" test -S "$ossec/queue/sockets/logtest" && return 0
    fi
    sleep 2
  done
  echo "wazuh-analysisd did not start" >&2
  docker exec "$name" tail -n 30 "$ossec/logs/ossec.log" >&2 || true
  return 1
}

docker run -d --name "$name" "$image" >/dev/null
wait_analysisd

# Content in the user directories, as the reconciler uploads it.
stage=$(mktemp -d)
trap 'rm -rf "$stage"; cleanup' EXIT
mkdir -p "$stage/rules" "$stage/decoders" "$stage/lists"
cp wazuh/rules/*.xml "$stage/rules/" 2>/dev/null || true
cp wazuh/decoders/*.xml "$stage/decoders/" 2>/dev/null || true
lists=()
for f in wazuh/lists/* tests/lists/*; do
  b=$(basename "$f")
  [[ -f "$f" && "$b" =~ ^[-A-Za-z0-9_]+$ ]] || continue
  cp "$f" "$stage/lists/$b"
  lists+=("$b")
done
for d in rules decoders lists; do
  if compgen -G "$stage/$d/*" >/dev/null; then
    docker cp "$stage/$d/." "$name:$ossec/etc/$d/"
  fi
done

# Register the lists and exclude the stock files, as wazuh.ruleset.extraLists and
# extraRuleExcludes do on the tenants.
extra=""
for l in "${lists[@]}"; do extra+="    <list>etc/lists/$l</list>\n"; done
while read -r x; do
  [[ -n "$x" ]] && extra+="    <rule_exclude>$x</rule_exclude>\n"
done < <(grep -v '^#' tests/rule-excludes.txt 2>/dev/null || true)
docker exec "$name" sh -c "
  sed -i '0,/<\/ruleset>/s||$extra  </ruleset>|' $ossec/etc/ossec.conf &&
  chown -R wazuh:wazuh $ossec/etc/rules $ossec/etc/decoders $ossec/etc/lists &&
  $ossec/bin/wazuh-analysisd -t" || { echo "wazuh-analysisd -t rejects the ruleset" >&2; exit 1; }
docker exec "$name" "$ossec/bin/wazuh-control" restart >/dev/null 2>&1 || true
wait_analysisd

pass=0 fail=0
for dir in tests/*/; do
  dir=${dir%/}
  [[ -f "$dir/expected.json" && -f "$dir/input.log" ]] || continue
  read -r rule level decoder location < <(python3 -c '
import json, sys
e = json.load(open(sys.argv[1]))
print(e["rule_id"], e["level"], e["decoder"], e.get("location", "-"))' "$dir/expected.json")
  args=(-U "$rule:$level:$decoder")
  [[ "$location" != "-" ]] && args+=(-l "$location")
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if out=$(printf '%s\n' "$line" | docker exec -i "$name" "$ossec/bin/wazuh-logtest" "${args[@]}" 2>&1) \
      && grep -q 'Unit test OK' <<<"$out"; then
      pass=$((pass + 1))
      echo "PASS: $(basename "$dir")"
    else
      fail=$((fail + 1))
      echo "FAIL: $(basename "$dir"): $(grep -E 'Unit test|ERROR' <<<"$out" | head -n 3)"
    fi
  done <"$dir/input.log"
done

echo "logtest: $pass passed, $fail failed"
[[ $fail -eq 0 && $pass -gt 0 ]]
