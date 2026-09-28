#!/usr/bin/env bash
# Static checks of the content package, no container needed:
#   - every rule/decoder file and agent.conf is well-formed XML (rule files hold
#     several top-level <group>s, so each is wrapped in one root first);
#   - rule ids are unique across the package (tenant overlays may redefine a
#     shared file by name, not an id in another file);
#   - list names are what the Wazuh API accepts, list lines look like CDB;
#   - every fixture has input.log and an expected.json with rule_id, level, decoder
#     (tests/pending/ holds fixtures that have not been replayed yet: neither this
#     script nor logtest.sh looks at them);
#   - rules without a fixture are listed (a warning).
#   argocd-helm-charts/kubesoc-content/tests/lint.sh
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
err() { echo "FAIL: $*"; fail=1; }

shopt -s nullglob
for f in wazuh/rules/*.xml wazuh/decoders/*.xml tenants/*/wazuh/rules/*.xml tenants/*/wazuh/decoders/*.xml; do
  { echo '<kubesoc-lint>'; cat "$f"; echo '</kubesoc-lint>'; } | xmllint --noout - 2>/dev/null || err "$f is not well-formed XML"
done
for f in wazuh/agent-groups/*/agent.conf tenants/*/wazuh/agent-groups/*/agent.conf; do
  xmllint --noout "$f" 2>/dev/null || err "$f is not well-formed XML"
done

ids() { grep -ho '<rule[^>]*id="[0-9]*"' "$@" 2>/dev/null | sed 's/.*id="\([0-9]*\)"/\1/'; }
dups=$(ids wazuh/rules/*.xml | sort | uniq -d)
[[ -z "$dups" ]] || err "rule ids defined twice: $(tr '\n' ' ' <<<"$dups")"

for f in wazuh/lists/* tenants/*/wazuh/lists/*; do
  b=$(basename "$f")
  [[ "$b" == *.* ]] && continue # README.md and the like
  [[ "$b" =~ ^[-A-Za-z0-9_]+$ ]] || err "$f: list names match ^[-\\w]+$"
  bad=$(grep -vnE '^("[^"]+"|[^:" ]+):("[^"]*"|[^:"]*)$' "$f" | head -n 3 || true)
  [[ -z "$bad" ]] || err "$f: not CDB lines: $bad"
done

tested=""
for d in tests/*/; do
  d=${d%/}
  case "$(basename "$d")" in lists | pending) continue ;; esac
  [[ -f "$d/input.log" ]] || err "$d: no input.log"
  python3 - "$d/expected.json" <<'PY' || err "$d/expected.json needs rule_id, level (int) and decoder"
import json, sys
e = json.load(open(sys.argv[1]))
assert str(e["rule_id"]).isdigit() and isinstance(e["level"], int) and e["decoder"]
PY
  tested+=" $(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["rule_id"])' "$d/expected.json" 2>/dev/null || true)"
done
for id in $(ids wazuh/rules/*.xml | sort -u); do
  grep -qw "$id" <<<"$tested" || echo "WARN: rule $id has no fixture"
done

[[ $fail -eq 0 ]] && echo "lint: ok"
exit "$fail"
