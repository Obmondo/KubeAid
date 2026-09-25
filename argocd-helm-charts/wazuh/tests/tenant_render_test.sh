#!/usr/bin/env bash
# Render checks for one-Wazuh-per-tenant mode (README section 11), values in
# tests/values-tenant.yaml. Needs helm and yq v4, no cluster. The subchart is
# vendored in charts/, so no dependency build.
#   argocd-helm-charts/wazuh/tests/tenant_render_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

out=$(mktemp)
trap 'rm -f "$out"' EXIT
helm template wazuh-001 . -n wazuh-001 -f tests/values-tenant.yaml >"$out"

pass=0 fail=0
check() { # description, expected, actual
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: expected [$2] got [$3]"; fi
}
q() { yq -N "$1" "$out"; }

check "no worker" "" "$(q 'select(.kind=="StatefulSet" and .metadata.name=="wazuh-manager-worker") | .metadata.name')"
check "no in-cluster agent" "" "$(q 'select(.kind=="DaemonSet") | .metadata.name')"
check "master service takes enrolment, API and events" "1515,55000,1514" \
  "$(q 'select(.kind=="Service" and .metadata.name=="wazuh") | .spec.ports | map(.port) | join(",")')"
check "agent Service maps the tenant ports" "20015:1515,20014:1514" \
  "$(q 'select(.kind=="Service" and .metadata.name=="wazuh-agents") | .spec.ports | map((.port|tostring) + ":" + (.targetPort|tostring)) | join(",")')"
check "agent Service on the external address" "192.0.2.10" \
  "$(q 'select(.kind=="Service" and .metadata.name=="wazuh-agents") | .spec.externalIPs[0]')"
check "agent Service selects the master" "master" \
  "$(q 'select(.kind=="Service" and .metadata.name=="wazuh-agents") | .spec.selector["node-type"]')"
check "no Traefik routes" "" "$(q 'select(.kind=="IngressRouteTCP") | .metadata.name')"
check "manager admits agents from outside" "0.0.0.0/0" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-manager-master") | .spec.ingress[] | select(.ports[0].port==1514) | .from[0].ipBlock.cidr')"
for c in wazuh-node wazuh-admin wazuh-dashboard wazuh-filebeat; do
  check "$c from the shared ClusterIssuer" "soc-ca/ClusterIssuer" \
    "$(q "select(.kind==\"Certificate\" and .metadata.name==\"$c\") | .spec.issuerRef.name + \"/\" + .spec.issuerRef.kind")"
done
check "node DN carries the tenant" "CN=wazuh-indexer,O=tenant-001,L=California,C=US" \
  "$(q 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-indexer-config") | .data["opensearch.yml"]' | yq '.["plugins.security.nodes_dn"][0]')"
check "central search DN allowed" "CN=wazuh-indexer,O=central,L=California,C=US" \
  "$(q 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-indexer-config") | .data["opensearch.yml"]' | yq '.["plugins.security.nodes_dn"][1]')"
check "indexer 9300 open to the central namespace" "security-operations" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-indexer") | .spec.ingress[] | select(.ports[0].port==9300 and .from[0].namespaceSelector) | .from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"]')"
check "no generated passwords" "" \
  "$(q 'select(.kind=="Secret") | .metadata.name' | grep -E 'indexer-cred|dashboard-cred|wazuh-api-cred|wazuh-authd-pass' || true)"
check "fixed IRIS customer in ossec.conf" "1" \
  "$(q 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-manager-config") | .data["master.conf"]' | grep -c '"customer_name": "Tenant 001"')"

echo "tenant mode: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
