#!/usr/bin/env bash
# Render tests for the kubesoc-portal chart. Requires helm, yq (v4), jq; node optional.
set -uo pipefail
CHART="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok() { echo "PASS: $1"; pass=$((pass + 1)); }
ko() { echo "FAIL: $1"; fail=$((fail + 1)); }
ISSUER=(--set oauth2Proxy.oidcIssuerUrl=https://keycloak.example.com/auth/realms/soc)
render() { helm template portal "$CHART" "$@" 2>"$TMP/err"; }

helm lint "$CHART" "${ISSUER[@]}" >"$TMP/lint" 2>&1 && ok "helm lint" || { ko "helm lint"; cat "$TMP/lint"; }

render --set oauth2Proxy.oidcIssuerUrl= >/dev/null && ko "issuer required" || { grep -q "oidcIssuerUrl is required" "$TMP/err" && ok "issuer required" || ko "issuer error"; }

LINKS='{"central":[{"name":"IRIS","url":"https://iris.example.com"}],"tenants":[{"code":"001","name":"Tenant A","roles":["tenant-001"],"links":[{"name":"Wazuh","url":"https://wazuh-001.example.com"}]}],"operatorRoles":["analyst"]}'
if render "${ISSUER[@]}" --set-json "links=$LINKS" >"$TMP/r.yaml"; then
  ok "renders with inline links"
  [ "$(yq 'select(.kind == "ConfigMap" and .metadata.name == "portal-kubesoc-portal-links") | .data["links.json"]' "$TMP/r.yaml" | jq -r '.tenants[0].links[0].url')" = "https://wazuh-001.example.com" ] \
    && ok "inline links rendered" || ko "inline links"
  dep=$(yq -o=json -I=0 'select(.kind == "Deployment") | .spec.template.spec' "$TMP/r.yaml")
  [ "$(jq -r '[.containers[].name] | join(",")' <<<"$dep")" = "nginx,oauth2-proxy" ] && ok "nginx behind oauth2-proxy" || ko "containers"
  [ "$(jq -r '[.containers[].securityContext | .readOnlyRootFilesystem, .allowPrivilegeEscalation] | map(tostring) | join(",")' <<<"$dep")" = "true,false,true,false" ] \
    && ok "read-only roots, no privilege escalation" || ko "container security"
  [ "$(jq -r '.containers[0].ports // [] | length' <<<"$dep")" = "0" ] && ok "nginx port not exposed" || ko "nginx port exposed"
  [ "$(jq -r '.volumes[] | select(.name == "links") | .configMap.name' <<<"$dep")" = "portal-kubesoc-portal-links" ] && ok "links volume" || ko "links volume"
  jq -r '.containers[1].args[]' <<<"$dep" | grep -qx -- '--redirect-url=https://portal.example.com/oauth2/callback' && ok "redirect URL from the ingress host" || ko "redirect URL"
  conf=$(yq 'select(.kind == "ConfigMap" and .metadata.name == "portal-kubesoc-portal") | .data["nginx.conf"]' "$TMP/r.yaml")
  grep -q "listen 127.0.0.1:8080;" <<<"$conf" && ok "nginx on loopback" || ko "nginx listen"
  grep -q "Content-Security-Policy \"default-src 'none'; script-src 'self'" <<<"$conf" && ok "strict CSP" || ko "CSP"
else
  ko "renders with inline links"; cat "$TMP/err"
fi

if render --set oauth2Proxy.enabled=false --set linksConfigMap.name=external-links >"$TMP/fa.yaml"; then
  ok "renders for forward auth"
  dep=$(yq -o=json -I=0 'select(.kind == "Deployment") | .spec.template.spec' "$TMP/fa.yaml")
  [ "$(jq -r '[.containers[].name] | join(",")' <<<"$dep")" = "nginx" ] && ok "no oauth2-proxy with forward auth" || ko "containers (forward auth)"
  [ "$(jq -r '.containers[0].ports[0].containerPort' <<<"$dep")" = "8080" ] && ok "nginx port exposed with forward auth" || ko "nginx port"
  [ "$(jq -r '.volumes[] | select(.name == "links") | .configMap.name' <<<"$dep")" = "external-links" ] && ok "external links ConfigMap" || ko "external links"
  [ -z "$(yq 'select(.metadata.name == "portal-kubesoc-portal-links") | .kind' "$TMP/fa.yaml")" ] && ok "no inline links ConfigMap" || ko "inline links rendered"
else
  ko "renders for forward auth"; cat "$TMP/err"
fi

! grep -n "innerHTML\|outerHTML\|insertAdjacentHTML\|document.write\|eval(" "$CHART/files/app.js" && ok "page script sets text only" || ko "page script uses HTML sinks"
if command -v node >/dev/null; then
  node --check "$CHART/files/app.js" && ok "page script parses" || ko "page script syntax"
  node "$CHART/tests/app_test.js" >/dev/null && ok "page shows each user their tenants" || ko "page behaviour (node tests/app_test.js)"
fi

echo
echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
