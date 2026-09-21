#!/usr/bin/env bash
# Render tests for the dashboard Gateway API resources (HTTPRoute / ListenerSet /
# BackendTLSPolicy / Certificate) and for the config templating fix (#173).
#
# Usage: charts/wazuh/tests/render_test.sh
# Requires: helm on PATH. No cluster access needed (pure `helm template`).
# Fetches the chart's dependencies (cert-manager) on every run, so it works
# from a clean checkout without a manual `helm dependency build` step.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE=test

helm dependency build "$CHART_DIR" >/dev/null

pass=0
fail=0

render() {
  helm template "$RELEASE" "$CHART_DIR" "$@"
}

# render_only <template-path> [helm template args...]
# Renders a single template's manifest, so assertions can't accidentally
# match an unrelated resource elsewhere in the chart's output.
render_only() {
  local tmpl="$1"; shift
  render --show-only "$tmpl" "$@"
}

expect_success() {
  local name="$1"; shift
  if "$@" >/dev/null 2>/tmp/wazuh-render-test.err; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name (expected helm template to succeed)"
    cat /tmp/wazuh-render-test.err
    fail=$((fail + 1))
  fi
}

expect_failure() {
  local name="$1"; shift
  if "$@" >/dev/null 2>/tmp/wazuh-render-test.err; then
    echo "FAIL: $name (expected helm template to fail, it succeeded)"
    fail=$((fail + 1))
  else
    echo "PASS: $name"
    pass=$((pass + 1))
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name (expected to find: $needle)"
    fail=$((fail + 1))
  fi
}

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if grep -qF -- "$needle" <<<"$haystack"; then
    echo "FAIL: $name (expected NOT to find: $needle)"
    fail=$((fail + 1))
  else
    echo "PASS: $name"
    pass=$((pass + 1))
  fi
}

LISTENERSET=templates/dashboard/listenerset.yaml
HTTPROUTE=templates/dashboard/httproute.yaml
BACKENDTLSPOLICY=templates/dashboard/backendtlspolicy.yaml
GATEWAY_CERTIFICATE=templates/dashboard/certificate.yaml
INGRESS=templates/dashboard/ingress.yaml
INDEXER_SECURITYCONFIG=templates/indexer/secret-securityconfig.yaml

echo "== Gateway disabled (default): no Gateway API resource is rendered =="
expect_failure "no ListenerSet by default" render_only "$LISTENERSET"
expect_failure "no HTTPRoute by default" render_only "$HTTPROUTE"
expect_failure "no BackendTLSPolicy by default" render_only "$BACKENDTLSPOLICY"

echo "== Gateway enabled without parentRef.name must fail fast =="
expect_failure "missing parentRef.name" render --set dashboard.gateway.enabled=true

echo "== HTTP backend, attached via a chart-managed ListenerSet =="
gw_args=(--set dashboard.gateway.enabled=true --set dashboard.gateway.parentRef.name=my-gw)
out=$(render_only "$LISTENERSET" "${gw_args[@]}")
assert_contains "listener protocol is HTTP" "$out" "protocol: HTTP"
out=$(render_only "$HTTPROUTE" "${gw_args[@]}")
assert_contains "HTTPRoute parentRef targets the ListenerSet" "$out" "kind: ListenerSet"

echo "== Gateway enabled with edge TLS disabled never needs tls.secretName =="
expect_success "tls.enabled=false, certificate.create=false, no secretName" \
  render_only "$LISTENERSET" "${gw_args[@]}" --set dashboard.gateway.tls.enabled=false --set dashboard.gateway.tls.certificate.create=false

echo "== HTTPS backend (dashboard.enable_ssl) requires backendTLS.caCertificateRef.name =="
expect_failure "missing backendTLS.caCertificateRef.name" render "${gw_args[@]}" --set dashboard.enable_ssl=true

backend_tls_args=("${gw_args[@]}" --set dashboard.enable_ssl=true --set dashboard.gateway.backendTLS.caCertificateRef.name=dashboard-ca-bundle)
out=$(render_only "$BACKENDTLSPOLICY" "${backend_tls_args[@]}")
assert_contains "BackendTLSPolicy CA ref is a ConfigMap" "$out" "kind: ConfigMap"
assert_contains "BackendTLSPolicy CA ref name is passed through" "$out" "name: dashboard-ca-bundle"
assert_contains "BackendTLSPolicy hostname matches the dashboard certificate SAN" "$out" "hostname: test-wazuh-dashboard"

echo "== Edge TLS: a generated Certificate requires tls.issuerRef.name =="
expect_failure "missing tls.issuerRef.name" render "${gw_args[@]}" --set dashboard.gateway.tls.enabled=true

edge_tls_args=("${gw_args[@]}" --set dashboard.gateway.tls.enabled=true --set dashboard.gateway.tls.issuerRef.name=my-issuer)
out=$(render_only "$GATEWAY_CERTIFICATE" "${edge_tls_args[@]}")
assert_contains "gateway edge Certificate is rendered" "$out" "name: test-wazuh-dashboard-letsencrypt"
out=$(render_only "$LISTENERSET" "${edge_tls_args[@]}")
assert_contains "listener uses HTTPS" "$out" "protocol: HTTPS"

echo "== Edge TLS: certificate.create=false requires tls.secretName =="
expect_failure "missing tls.secretName" render "${gw_args[@]}" --set dashboard.gateway.tls.enabled=true --set dashboard.gateway.tls.certificate.create=false

echo "== Edge TLS: an existing Secret skips Certificate creation =="
existing_secret_args=("${gw_args[@]}" --set dashboard.gateway.tls.enabled=true --set dashboard.gateway.tls.certificate.create=false --set dashboard.gateway.tls.secretName=my-existing-secret)
out=$(render_only "$LISTENERSET" "${existing_secret_args[@]}")
assert_contains "listener references the existing secret" "$out" "name: my-existing-secret"
expect_failure "no Certificate is generated" render_only "$GATEWAY_CERTIFICATE" "${existing_secret_args[@]}"

echo "== Direct Gateway attachment (dashboard.gateway.listenerSet.enabled=false) =="
direct_attach_args=("${gw_args[@]}" --set dashboard.gateway.listenerSet.enabled=false)
expect_failure "no ListenerSet is rendered" render_only "$LISTENERSET" "${direct_attach_args[@]}"
out=$(render_only "$HTTPROUTE" "${direct_attach_args[@]}")
assert_contains "HTTPRoute parentRef targets the Gateway directly" "$out" "kind: Gateway"
assert_contains "HTTPRoute parentRef name is the parent Gateway" "$out" "name: my-gw"

echo "== Ingress and Gateway can coexist =="
coexist_args=(--set dashboard.ingress.enabled=true "${gw_args[@]}")
out=$(render_only "$INGRESS" "${coexist_args[@]}")
assert_contains "Ingress is still rendered" "$out" "kind: Ingress"
out=$(render_only "$HTTPROUTE" "${coexist_args[@]}")
assert_contains "HTTPRoute is rendered alongside the Ingress" "$out" "kind: HTTPRoute"

sso_args=(
  --set dashboard.sso.oidc.enabled=true
  --set dashboard.sso.oidc.existingSecret=my-oidc-secret
  --set dashboard.sso.oidc.url=https://issuer.example.com/auth
  --set dashboard.sso.oidc.logoutUrl=https://issuer.example.com/logout
  --set dashboard.sso.saml.enabled=true
  --set dashboard.sso.saml.metadataUrl=https://idp.example.com/metadata
  --set dashboard.sso.saml.idpEntityId=https://idp.example.com/entity
  --set dashboard.sso.saml.exchangeKey=exchange-key
)

echo "== SSO callback URLs are derived from the selected public dashboard endpoint =="
out=$(render_only "$INDEXER_SECURITYCONFIG" "${gw_args[@]}" "${sso_args[@]}" --set dashboard.gateway.host=gw.example.org --set dashboard.gateway.tls.enabled=false)
assert_contains "SAML uses http:// when Gateway TLS is disabled" "$out" "kibana_url: http://gw.example.org"
out=$(render_only "$INDEXER_SECURITYCONFIG" "${gw_args[@]}" "${sso_args[@]}" --set dashboard.gateway.host=gw.example.org --set dashboard.gateway.tls.enabled=true --set dashboard.gateway.tls.issuerRef.name=my-issuer)
assert_contains "SAML uses https:// when Gateway TLS is enabled" "$out" "kibana_url: https://gw.example.org"
out=$(render_only "templates/dashboard/configmap.yaml" "${gw_args[@]}" "${sso_args[@]}" --set dashboard.gateway.host=gw.example.org --set dashboard.gateway.tls.enabled=false)
assert_contains "OIDC uses http:// when Gateway TLS is disabled" "$out" "base_redirect_url: http://gw.example.org"
out=$(render_only "templates/dashboard/configmap.yaml" "${gw_args[@]}" "${sso_args[@]}" --set dashboard.gateway.host=gw.example.org --set dashboard.gateway.tls.enabled=true --set dashboard.gateway.tls.issuerRef.name=my-issuer)
assert_contains "OIDC uses https:// when Gateway TLS is enabled" "$out" "base_redirect_url: https://gw.example.org"
expect_failure "empty Gateway host fails rendering" \
  render_only "$INDEXER_SECURITYCONFIG" "${gw_args[@]}" "${sso_args[@]}" --set-string dashboard.gateway.host=''
out=$(render_only "$INDEXER_SECURITYCONFIG" "${gw_args[@]}" "${sso_args[@]}" --set dashboard.gateway.host=gw.example.org --set dashboard.sso.oidc.baseRedirectUrl=https://override.example.org --set dashboard.sso.saml.kibanaUrl=https://override.example.org)
assert_contains "explicit SSO URLs take precedence over derived URLs" "$out" "kibana_url: https://override.example.org"
out=$(render_only "templates/dashboard/configmap.yaml" "${gw_args[@]}" "${sso_args[@]}" --set dashboard.gateway.host=gw.example.org --set dashboard.sso.oidc.baseRedirectUrl=https://override.example.org --set dashboard.sso.saml.kibanaUrl=https://override.example.org)
assert_contains "explicit SSO URLs take precedence over derived URLs" "$out" "base_redirect_url: https://override.example.org"
out=$(render_only "$INDEXER_SECURITYCONFIG" --set dashboard.ingress.enabled=true --set dashboard.ingress.host=ing.example.org --set dashboard.gateway.enabled=true --set dashboard.gateway.parentRef.name=my-gw --set dashboard.gateway.host=gw.example.org --set dashboard.gateway.tls.enabled=false "${sso_args[@]}")
assert_contains "Ingress host wins and keeps the existing HTTPS fallback" "$out" "kibana_url: https://ing.example.org"
out=$(render_only "templates/dashboard/configmap.yaml" --set dashboard.ingress.enabled=true --set dashboard.ingress.host=ing.example.org --set dashboard.gateway.enabled=true --set dashboard.gateway.parentRef.name=my-gw --set dashboard.gateway.host=gw.example.org --set dashboard.gateway.tls.enabled=false "${sso_args[@]}")
assert_contains "Ingress host wins and keeps the existing HTTPS fallback" "$out" "base_redirect_url: https://ing.example.org"
out=$(render_only "$INDEXER_SECURITYCONFIG" "${sso_args[@]}")
assert_contains "SAML keeps the legacy HTTPS fallback when no frontend is enabled" "$out" "kibana_url: https://wazuh.example.com"
out=$(render_only "templates/dashboard/configmap.yaml" "${sso_args[@]}")
assert_contains "OIDC gets a complete legacy HTTPS fallback when no frontend is enabled" "$out" "base_redirect_url: https://wazuh.example.com"
expect_failure "direct Gateway attachment without explicit SSO URLs must fail" \
  render_only "$INDEXER_SECURITYCONFIG" "${gw_args[@]}" "${sso_args[@]}" --set dashboard.gateway.listenerSet.enabled=false

echo "== #173: single-quoted include() inside a templated config block renders through tpl =="
cat >/tmp/wazuh-render-test-173-values.yaml <<'EOF'
indexer:
  config:
    internalUsers: |-
      ---
      _meta:
        type: "internalusers"
        config_version: 2

      admin:
        hash: '{{ include "wazuh.indexer.passwordHash" . }}'
        reserved: true
        backend_roles:
          - "admin"
        description: "Admin user"
EOF
out=$(render_only "$INDEXER_SECURITYCONFIG" -f /tmp/wazuh-render-test-173-values.yaml)
assert_contains "internalUsers.hash is templated to the actual password hash" "$out" \
  "hash: '\$2a\$12\$zGWIT7wkPKT/zww3bmMyp.KuWXH4RzgxiB91Q8NGFcqpyPy.R2Rcq'"
rm -f /tmp/wazuh-render-test-173-values.yaml

MANAGER_CONFIGMAP=templates/manager/configmap.yaml
MASTER_STS=templates/manager/master/statefulset.yaml
WORKER_STS=templates/manager/worker/statefulset.yaml
FILEBEAT_MOUNT=/var/ossec/data_tmp/exclusion/etc/filebeat/filebeat.yml

echo "== #174: archives disabled (default) leaves the image's filebeat.yml alone =="
out=$(render_only "$MANAGER_CONFIGMAP")
assert_contains "logall_json stays off on the master" "$out" '<logall_json>no</logall_json>'
assert_not_contains "no filebeat.yml is added to the ConfigMap" "$out" "filebeat.yml:"
for sts in "$MASTER_STS" "$WORKER_STS"; do
  out=$(render_only "$sts")
  assert_not_contains "no filebeat.yml mount in ${sts##*/manager/}" "$out" "$FILEBEAT_MOUNT"
done

echo "== #174: wazuh.archives.enabled turns on both halves at once =="
archives_args=(--set wazuh.archives.enabled=true)
out=$(render_only "$MANAGER_CONFIGMAP" "${archives_args[@]}")
assert_not_contains "logall_json is on for master and worker alike" "$out" '<logall_json>no</logall_json>'
assert_contains "filebeat ships the archives fileset" "$out" 'archives:\n      enabled: true'
assert_contains "the alerts fileset is left enabled" "$out" 'alerts:\n      enabled: true'
# The entrypoint seds these lines in place; without them filebeat ships nothing.
for placeholder in "hosts: ['https://wazuh.indexer:9200']" '#username:' '#password:' \
                   '#ssl.verification_mode:' '#ssl.certificate_authorities:' '#ssl.certificate:' '#ssl.key:'; do
  assert_contains "entrypoint placeholder is preserved: $placeholder" "$out" "$placeholder"
done
for sts in "$MASTER_STS" "$WORKER_STS"; do
  out=$(render_only "$sts" "${archives_args[@]}")
  assert_contains "filebeat.yml is mounted in ${sts##*/manager/}" "$out" "$FILEBEAT_MOUNT"
done

echo "== #174: the new nested sections are optional (helm upgrade --reuse-values) =="
# A release upgraded with --reuse-values carries the old release's values, which have no
# wazuh.archives and no wazuh.filebeat at all. Absent must read as false / "", not explode.
absent_args=(--set wazuh.archives=null --set wazuh.filebeat=null)
expect_success "chart renders with both sections absent" render "${absent_args[@]}"
out=$(render_only "$MANAGER_CONFIGMAP" "${absent_args[@]}")
assert_contains "absent wazuh.archives reads as disabled" "$out" '<logall_json>no</logall_json>'
assert_not_contains "absent wazuh.filebeat adds no filebeat.yml" "$out" "filebeat.yml:"
out=$(render_only "$MASTER_STS" "${absent_args[@]}")
assert_not_contains "absent sections mount nothing" "$out" "$FILEBEAT_MOUNT"
expect_success "archives still works with only wazuh.filebeat absent" \
  render --set wazuh.filebeat=null --set wazuh.archives.enabled=true

echo "== #174: full-file overrides win over wazuh.archives.enabled =="
# Documented precedence: an override replaces the generated file, so it takes the archives
# setting with it. Each half can be left off, which ships no archives without failing.
out=$(render_only "$MANAGER_CONFIGMAP" --set wazuh.archives.enabled=true --set 'wazuh.masterConf=<ossec_config></ossec_config>')
assert_contains "masterConf wins: master.conf is the override verbatim" "$out" 'master.conf: "<ossec_config></ossec_config>"'
assert_contains "the worker is still generated, so it keeps logall_json" "$out" '<logall_json>yes</logall_json>'
out=$(render_only "$MANAGER_CONFIGMAP" --set wazuh.archives.enabled=true --set 'wazuh.workerConf=<ossec_config></ossec_config>')
assert_contains "workerConf wins: worker.conf is the override verbatim" "$out" 'worker.conf: "<ossec_config></ossec_config>"'
out=$(render_only "$MANAGER_CONFIGMAP" --set wazuh.archives.enabled=true --set 'wazuh.filebeat.config=# mine')
assert_contains "filebeat.config wins over the archives fileset" "$out" 'filebeat.yml: "# mine"'
assert_not_contains "the generated filebeat config is dropped entirely" "$out" 'filebeat.modules'
assert_contains "but logall_json is still set, so managers write archives nobody ships" "$out" '<logall_json>yes</logall_json>'

echo "== #174: wazuh.filebeat.config replaces the file without enabling archives =="
override_args=(--set 'wazuh.filebeat.config=# my own filebeat')
out=$(render_only "$MANAGER_CONFIGMAP" "${override_args[@]}")
assert_contains "the override replaces the generated config" "$out" '# my own filebeat'
assert_not_contains "the generated config is not also emitted" "$out" 'filebeat.modules'
assert_contains "an override alone does not enable archives" "$out" '<logall_json>no</logall_json>'
out=$(render_only "$MASTER_STS" "${override_args[@]}")
assert_contains "an override alone still mounts filebeat.yml" "$out" "$FILEBEAT_MOUNT"

echo
echo "==================================="
echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
