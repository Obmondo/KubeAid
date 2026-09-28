#!/usr/bin/env bash
# Render checks for the kubesoc-content chart. Needs helm and yq v4.
#   argocd-helm-charts/kubesoc-content/tests/render_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

pass=0 fail=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: expected [$2] got [$3]"; fi; }
fails() { # description, expected message, helm args...
  local d=$1 m=$2; shift 2
  if out=$(helm template t . "$@" 2>&1); then check "$d" "failure" "rendered"
  else check "$d" "1" "$(grep -c -- "$m" <<<"$out" || true)"; fi
}

out=$(helm template t . -n security-operations --set-json 'tenants={"001":{"include":["wazuh/agent-groups/kubesoc-linux-baseline/agent.conf"]}}')
cm() { yq -N "select(.kind==\"ConfigMap\" and .metadata.name==\"kubesoc-content\") | $1" <<<"$out"; }
check "one ConfigMap" "kubesoc-content" "$(yq -N 'select(.kind) | .metadata.name' <<<"$out")"
check "VERSION" "$(tr -d '[:space:]' <VERSION)" "$(cm '.data.VERSION')"
check "version label" "$(tr -d '[:space:]' <VERSION)" "$(cm '.metadata.labels["kubesoc.io/content-version"]')"
check "rules under flattened keys" "1" "$(cm '.data | keys | .[]' | grep -c '^wazuh__rules__kubesoc-0999-malicious-ioc.xml$')"
check "rule content kept" "$(grep -c '<rule id=' wazuh/rules/kubesoc-0999-malicious-ioc.xml)" \
  "$(cm '.data["wazuh__rules__kubesoc-0999-malicious-ioc.xml"]' | grep -c '<rule id=')"
check "agent group" "1" "$(cm '.data | keys | .[]' | grep -c '^wazuh__agent-groups__kubesoc-linux-baseline__agent.conf$')"
# One system prompt and one JSON schema for each AI mode (triage, summary, hunt);
# tests/test_content_prompts.py in the dfir-iris chart checks they match the code.
check "prompts" "6" "$(cm '.data | keys | .[]' | grep -c '^ai__prompts__')"
check "no tests or docs" "0" "$(cm '.data | keys | .[]' | grep -cE 'tests|README' || true)"
check "manifest carries tenant selection" '["wazuh/agent-groups/kubesoc-linux-baseline/agent.conf"]' \
  "$(cm '.data["manifest.json"]' | yq -p json -o json -I0 '.tenants["001"].include')"
fails "tenant codes are checked" "a tenant code matches" --set-json 'tenants={"Bad Code":{}}'
fails "size is capped" "more than maxBytes" --set maxBytes=100

echo "kubesoc-content render: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
