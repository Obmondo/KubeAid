#!/usr/bin/env bash
# Render checks for the KubeAid hardening patches of the vendored subchart: no
# OpenSearch demo users, SSO-only dashboard login unless break-glass is asked for,
# the cluster key from an existing Secret, no per-release CA under a shared
# issuer. Needs helm and yq v4, no cluster.
#   argocd-helm-charts/kubesoc/wazuh/tests/hardening_render_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0 fail=0
check() { # description, expected, actual
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1: expected [$2] got [$3]"; fi
}
render() { # out file, helm args...
  local out=$1; shift
  helm template wazuh . -n wazuh-001 "$@" >"$out"
}
users() { yq -N 'select(.kind=="Secret" and .metadata.name=="wazuh-securityconfig") | .stringData["internal_users.yml"]' "$1"; }
authtype() { yq -N 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-dashboard-config") | .data["opensearch_dashboards.yml"]' "$1" | yq -o=json -I=0 '.["opensearch_security.auth.type"]'; }

# The upstream demo users and their public bcrypt hashes.
demo_users="kibanaro logstash readall snapshotrestore"
demo_hashes='JJSXNfTowz7Uu5ttXfeYpeYE0arACvcwlPBStB1F|u1ShR4l4uBS3Uv59Pa2y5.1uQuZBrZtmNfqB3iM|ae4ycwzwvLtZxwZ82RmiEunBbIPiAmGZduBAjKN0|DpwmetHKwgYnorbgdvORCenv4NAK8cPUg8AI6pxLC'

render "$tmp/default.yaml"
render "$tmp/tenant.yaml" -f tests/values-tenant.yaml
for f in default tenant; do
  check "$f: internal users are admin and the dashboard server user" "admin,kibanaserver" \
    "$(users "$tmp/$f.yaml" | yq -r 'del(._meta) | keys | join(",")')"
  for u in $demo_users; do
    check "$f: no demo user $u" "0" "$(users "$tmp/$f.yaml" | grep -c "^$u:" || true)"
  done
  check "$f: no demo hash anywhere" "0" "$(grep -cE "$demo_hashes" "$tmp/$f.yaml" || true)"
done

render "$tmp/demo.yaml" --set wazuh.indexer.config.demoUsers=true \
  --set-json 'wazuh.indexer.config.extraInternalUsers={"breakglass":{"hash":"$2y$12$x","backend_roles":["admin"]}}'
check "demoUsers and extraInternalUsers render on request" "admin,kibanaserver,breakglass,kibanaro,logstash,readall,snapshotrestore" \
  "$(users "$tmp/demo.yaml" | yq -r 'del(._meta) | keys | join(",")')"

# Dashboard login: basic auth only without SSO, or as break-glass next to it.
oidc=(--set wazuh.dashboard.sso.oidc.enabled=true --set wazuh.dashboard.sso.oidc.url=https://idp.example.com/.well-known/openid-configuration
      --set wazuh.dashboard.sso.oidc.logoutUrl=https://idp.example.com/logout --set wazuh.dashboard.sso.oidc.existingSecret=wazuh-dashboard-oidc)
check "no SSO: login form" '["basicauth"]' "$(authtype "$tmp/default.yaml")"
render "$tmp/oidc.yaml" "${oidc[@]}"
check "SSO: SSO only" '["openid"]' "$(authtype "$tmp/oidc.yaml")"
check "SSO: indexer still takes basic auth (server user, API clients)" "true" \
  "$(yq -N 'select(.kind=="Secret" and .metadata.name=="wazuh-securityconfig") | .stringData["config.yml"]' "$tmp/oidc.yaml" | yq '.config.dynamic.authc.basic_internal_auth_domain.http_enabled')"
render "$tmp/breakglass.yaml" "${oidc[@]}" --set wazuh.dashboard.basicAuth.breakGlass=true
check "SSO + breakGlass: both" '["openid","basicauth"]' "$(authtype "$tmp/breakglass.yaml")"

# Cluster key from an existing Secret.
check "wazuh.key: chart Secret" "wazuh-cluster-key" "$(yq -N 'select(.kind=="Secret" and .metadata.name=="wazuh-cluster-key") | .metadata.name' "$tmp/default.yaml")"
render "$tmp/key.yaml" -f tests/values-tenant.yaml --set wazuh.wazuh.clusterKeySecret.name=wazuh-manager-cluster-key
check "clusterKeySecret: no chart Secret" "" "$(yq -N 'select(.kind=="Secret" and .metadata.name=="wazuh-cluster-key") | .metadata.name' "$tmp/key.yaml")"
check "clusterKeySecret: key not rendered" "0" "$(grep -c 0123456789abcdef0123456789abcdef "$tmp/key.yaml" || true)"
check "clusterKeySecret: placeholder in ossec.conf" "<key>___WAZUH_CLUSTER_KEY___</key>" \
  "$(yq -N 'select(.kind=="ConfigMap" and .metadata.name=="wazuh-manager-config") | .data["master.conf"]' "$tmp/key.yaml" | grep -o '<key>___.*</key>')"
master='select(.kind=="StatefulSet" and .metadata.name=="wazuh-manager-master") | .spec.template.spec'
check "clusterKeySecret: init container reads the Secret" "wazuh-manager-cluster-key/key" \
  "$(yq -N "$master | .initContainers[] | select(.name==\"update-index\") | .env[] | select(.name==\"WAZUH_CLUSTER_KEY\") | .valueFrom.secretKeyRef.name + \"/\" + .valueFrom.secretKeyRef.key" "$tmp/key.yaml")"
check "clusterKeySecret: init container substitutes it" "1" \
  "$(yq -N "$master | .initContainers[] | select(.name==\"update-index\") | .command[2]" "$tmp/key.yaml" | grep -c 's/___WAZUH_CLUSTER_KEY___/')"
check "clusterKeySecret: manager env reads the Secret" "wazuh-manager-cluster-key" \
  "$(yq -N "$master | .containers[0].env[] | select(.name==\"WAZUH_CLUSTER_KEY\") | .valueFrom.secretKeyRef.name" "$tmp/key.yaml")"
check "wazuh.key: init container unchanged" "sh,-c,/script.sh" \
  "$(yq -r "$master | .initContainers[] | select(.name==\"update-index\") | .command | join(\",\")" "$tmp/default.yaml")"

# Shared issuer: no CA of this release's own.
check "shared issuer: no root CA or CA issuer" "" \
  "$(yq -N 'select((.kind=="Certificate" and .metadata.name=="wazuh-root-ca") or (.kind=="Issuer")) | .metadata.name' "$tmp/tenant.yaml")"
check "own issuer: root CA kept" "wazuh-root-ca" \
  "$(yq -N 'select(.kind=="Certificate" and .metadata.name=="wazuh-root-ca") | .metadata.name' "$tmp/default.yaml")"

echo "hardening: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
