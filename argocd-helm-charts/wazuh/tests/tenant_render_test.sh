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
q() { yq -N "$1" "$out" | sed '/^$/d'; }

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
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-manager-flows") | .spec.ingress[] | select(.ports[0].port==1514) | .from[0].ipBlock.cidr')"
for c in wazuh-node wazuh-admin wazuh-dashboard wazuh-filebeat; do
  check "$c from the shared ClusterIssuer" "soc-ca/ClusterIssuer" \
    "$(q "select(.kind==\"Certificate\" and .metadata.name==\"$c\") | .spec.issuerRef.name + \"/\" + .spec.issuerRef.kind")"
done
check "node DN carries the tenant" "CN=wazuh-indexer,O=tenant-001,L=California,C=US" \
  "$(q 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-indexer-config") | .data["opensearch.yml"]' | yq '.["plugins.security.nodes_dn"][0]')"
check "central search DN allowed" "CN=wazuh-indexer,O=central,L=California,C=US" \
  "$(q 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-indexer-config") | .data["opensearch.yml"]' | yq '.["plugins.security.nodes_dn"][1]')"
check "indexer 9300 open to the central indexer" "security-operations/wazuh-indexer" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-indexer-flows") | .spec.ingress[] | select(.ports[0].port==9300) | .from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"] + "/" + .from[0].podSelector.matchLabels.app')"
check "indexer 9200 open to the SIEM reconciler" "security-operations/siem-reconciler" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-indexer-flows") | .spec.ingress[] | select(.ports[0].port==9200) | .from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"] + "/" + .from[0].podSelector.matchLabels["app.kubernetes.io/name"]')"
check "no generated passwords" "" \
  "$(q 'select(.kind=="Secret") | .metadata.name' | grep -E 'indexer-cred|dashboard-cred|wazuh-api-cred|wazuh-authd-pass' || true)"
check "fixed IRIS customer in ossec.conf" "1" \
  "$(q 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-manager-config") | .data["master.conf"]' | grep -c '"customer_name": "Tenant 001"')"

# --- network policies and TLS ------------------------------------------------
check "manager API only for named central clients" "siem-reconciler,misp-wazuh-cdb-export,wazuh-dashboard" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-manager-flows") | .spec.ingress[] | select(.ports[0].port==55000) | [.from[] | .podSelector.matchLabels["app.kubernetes.io/name"] // .podSelector.matchLabels.app] | join(",")')"
check "manager API clients only from the central namespace" "security-operations" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-manager-flows") | .spec.ingress[] | select(.ports[0].port==55000) | [.from[].namespaceSelector.matchLabels["kubernetes.io/metadata.name"]] | unique | join(",")')"
check "no HTTPS-to-anywhere rule on the manager" "" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-manager-master") | .spec.egress[] | select(.to == null) | .ports[0].port')"
check "CTI feed through the world entity" "world:443" \
  "$(q 'select(.kind=="CiliumNetworkPolicy" and .metadata.name=="wazuh-manager-cti") | .spec.egress[0].toEntities[0] + ":" + .spec.egress[0].toPorts[0].ports[0].port')"
check "dashboard subchart rule has no any-source ingress" "" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-dashboard") | .spec.ingress[] | select(.from == null) | .ports[0].port')"
check "dashboard reached from the ingress controller" "traefik" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-dashboard-flows") | .spec.ingress[0].from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"]')"
check "HTTP-01 solvers reachable" "8089" \
  "$(q 'select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-acme-solver") | .spec.ingress[0].ports[0].port')"
json=$(mktemp)
yq ea -o=json '[.]' "$out" >"$json"
check "default deny, a policy per workload, 0.0.0.0/0 only on the agent ports" "" \
  "$(python3 tests/netpol_check.py "$json" --ns wazuh-001 --open-ingress 1514,1515 --world-egress 443)"
helm template wazuh-001 . -n wazuh-001 -f tests/values-tenant.yaml --set networkPolicies.cilium=false | yq ea -o=json '[.]' >"$json"
check "without Cilium the CTI rule excludes private ranges" "0.0.0.0/0 10.0.0.0/8" \
  "$(yq -p=json -oy -N '.[] | select(.kind=="NetworkPolicy" and .metadata.name=="wazuh-manager-cti") | .spec.egress[0].to[0].ipBlock | .cidr + " " + .except[0]' "$json")"
helm template wazuh-001 . -n wazuh-001 -f tests/values-tenant.yaml --set networkPolicies.enabled=false \
  --set wazuh.dashboard.networkPolicy.ingressFrom=null | yq ea -o=json '[.]' >"$json"
check "the check catches a namespace without the SOC policies" "1" \
  "$(python3 tests/netpol_check.py "$json" --ns wazuh-001 --open-ingress 1514,1515 --world-egress 443 >/dev/null; echo $?)"
rm -f "$json"
check "manager certificate from the shared CA" "soc-ca/ClusterIssuer" \
  "$(q 'select(.kind=="Certificate" and .metadata.name=="wazuh-manager-tls") | .spec.issuerRef.name + "/" + .spec.issuerRef.kind')"
check "manager certificate names the API Service and the agent host" "wazuh.wazuh-001.svc,agents.example.com" \
  "$(q 'select(.kind=="Certificate" and .metadata.name=="wazuh-manager-tls") | [.spec.dnsNames[] | select(. == "wazuh.wazuh-001.svc" or . == "agents.example.com")] | join(",")')"
check "manager key pair replaces the API and authd defaults" \
  "/wazuh-config-mount/api/configuration/ssl/server.crt,/wazuh-config-mount/api/configuration/ssl/server.key,/wazuh-config-mount/etc/sslmanager.cert,/wazuh-config-mount/etc/sslmanager.key" \
  "$(q 'select(.kind=="StatefulSet" and .metadata.name=="wazuh-manager-master") | [.spec.template.spec.containers[0].volumeMounts[] | select(.name=="manager-tls") | .mountPath] | join(",")')"
check "dashboard verifies the indexer" "full" \
  "$(q 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-dashboard-config") | .data["opensearch_dashboards.yml"]' | yq '.["opensearch.ssl.verificationMode"]')"
# KubeAid wazuh.ruleset patch: extra lists and excludes land inside the stock <ruleset>.
rs=$(helm template wazuh-001 . -n wazuh-001 -f tests/values-tenant.yaml \
  --set 'wazuh.wazuh.ruleset.extraLists={etc/lists/misp-malicious-ip}' \
  --set 'wazuh.wazuh.ruleset.extraRuleExcludes={0999-malicious-ioc-rules.xml}' |
  yq -N 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-manager-config") | .data["master.conf"]' |
  sed -n '/<ruleset>/,/<\/ruleset>/p')
check "one <ruleset> block" "1" "$(grep -c '<ruleset>' <<<"$rs")"
check "extra list registered" "1" "$(grep -c '<list>etc/lists/misp-malicious-ip</list>' <<<"$rs")"
check "stock IoC file excluded" "1" "$(grep -c '<rule_exclude>0999-malicious-ioc-rules.xml</rule_exclude>' <<<"$rs")"
check "stock entries kept" "1" "$(grep -c '<rule_exclude>0215-policy_rules.xml</rule_exclude>' <<<"$rs")"

echo "tenant mode: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
