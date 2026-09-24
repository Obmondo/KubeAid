#!/usr/bin/env bash
# Render tests for the security-operations umbrella chart.
#
# Usage: tests/render_test.sh
# Requires: helm, yq (v4), python3 on PATH. No cluster access (pure `helm template`).
#
# Checks: lint; renders with a generic 2-tenant and 3-tenant fixture; no
# duplicate kind/name/namespace; every object in the release namespace; the
# component object names a standalone install has; iris-pgsql/iris-rabbitmq
# once; no selector that matches on app.kubernetes.io/instance alone (one
# release = one instance label for every component); the 3-tenant render
# differs from the 2-tenant one only by tenant 003 entries; schema and
# template checks reject bad input; the reconciler renders when enabled.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHARTS_ROOT="$(cd "$CHART_DIR/.." && pwd)"
RELEASE=security-operations
NS=security-operations
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok() { echo "PASS: $1"; pass=$((pass + 1)); }
ko() { echo "FAIL: $1"; fail=$((fail + 1)); }

render() {
  helm template "$RELEASE" "$CHART_DIR" -n "$NS" "$@" 2>"$TMP/err"
}

expect_failure() {
  local name="$1" needle="$2"; shift 2
  if render "$@" >/dev/null; then
    ko "$name (expected helm template to fail)"
  elif grep -qF -- "$needle" "$TMP/err"; then
    ok "$name"
  else
    ko "$name (failed without \"$needle\")"; cat "$TMP/err"
  fi
}

# kind name namespace (release namespace when unset), one line per object
objects() {
  yq -N 'select(.kind != null) | .kind + " " + .metadata.name + " " + (.metadata.namespace // "'"$NS"'")' "$1"
}

# --- lint ---------------------------------------------------------------
if helm lint "$CHART_DIR" -n "$NS" -f "$SCRIPT_DIR/values-2-tenants.yaml" >"$TMP/lint" 2>&1; then
  ok "helm lint (2 tenants)"
else
  ko "helm lint (2 tenants)"; cat "$TMP/lint"
fi

# --- renders ------------------------------------------------------------
for n in 2 3; do
  if render -f "$SCRIPT_DIR/values-$n-tenants.yaml" >"$TMP/r$n.yaml"; then
    ok "renders with $n tenants"
  else
    ko "renders with $n tenants"; cat "$TMP/err"
  fi
done
R2="$TMP/r2.yaml"
objects "$R2" >"$TMP/objs2"

dups=$(sort "$TMP/objs2" | uniq -d)
[ -z "$dups" ] && ok "no duplicate kind/name/namespace" || ko "duplicate objects: $dups"

foreign=$(awk -v ns="$NS" '$3 != ns' "$TMP/objs2")
[ -z "$foreign" ] && ok "every object in namespace $NS" || ko "objects outside $NS: $foreign"

stray=$(awk '$2 ~ /security-operations/' "$TMP/objs2")
[ -z "$stray" ] && ok "no component object named after the release" || ko "release-named objects: $stray"

for want in "StatefulSet wazuh-manager-master" "StatefulSet wazuh-manager-worker" \
            "StatefulSet wazuh-indexer" "Service wazuh" "Deployment wazuh-dashboard" \
            "StatefulSet velociraptor" "Service velociraptor-frontend" "Service velociraptor-gui" \
            "Deployment dfir-iris-app" "Deployment dfir-iris-worker" "Service dfir-iris-app" \
            "Deployment misp" "Service misp" "MariaDB misp-mariadb" \
            "Deployment ollama" "Service ollama" \
            "ConfigMap wazuh-tenants" "ConfigMap velociraptor-tenants" \
            "ConfigMap dfir-iris-tenants" "ConfigMap siem-tenants"; do
  if grep -qx "$want $NS" "$TMP/objs2"; then ok "has $want"; else ko "missing $want"; fi
done

for once in "Cluster iris-pgsql" "RabbitmqCluster iris-rabbitmq"; do
  c=$(grep -cx "$once $NS" "$TMP/objs2")
  [ "$c" = 1 ] && ok "$once rendered once" || ko "$once rendered $c times"
done

# Every object of a standalone wrapper install (release == chart name) keeps
# its kind and name inside the umbrella.
for c in wazuh velociraptor dfir-iris misp ollama; do
  helm template "$c" "$CHARTS_ROOT/$c" -n "$NS" --skip-tests 2>/dev/null >"$TMP/alone-$c.yaml"
  missing=$(comm -23 <(objects "$TMP/alone-$c.yaml" | sort -u) <(sort -u "$TMP/objs2"))
  [ -z "$missing" ] && ok "standalone $c names kept" || ko "standalone $c objects missing: $missing"
done

# Selectors: podSelectors (policy target and peers), workload and Service
# selectors must not be app.kubernetes.io/instance alone.
inst_only=$(yq -N -o=json -I=0 '
  select(.kind != null) |
  [.spec.selector.matchLabels, .spec.podSelector.matchLabels,
   (select(.kind == "Service") | .spec.selector),
   (.spec.ingress[]?.from[]?.podSelector.matchLabels),
   (.spec.egress[]?.to[]?.podSelector.matchLabels)] |
  .[] | select(. != null) | select((keys | length) == 1 and has("app.kubernetes.io/instance"))' "$R2")
[ -z "$inst_only" ] && ok "no instance-only selectors" || ko "instance-only selectors: $inst_only"

# --- tenant 003 adds entries and nothing else ---------------------------
yq ea -o=json '[.]' "$TMP/r2.yaml" >"$TMP/r2.json"
yq ea -o=json '[.]' "$TMP/r3.yaml" >"$TMP/r3.json"
if python3 "$SCRIPT_DIR/tenant_diff.py" "$TMP/r2.json" "$TMP/r3.json" 003 "Tenant C" >"$TMP/diff"; then
  ok "3 tenants = 2 tenants + tenant 003 entries ($(grep -c 'tenant entries only' "$TMP/diff") objects)"
else
  ko "3 tenants vs 2 tenants"; cat "$TMP/diff"
fi
for obj in ConfigMap/wazuh-tenants ConfigMap/velociraptor-tenants ConfigMap/dfir-iris-tenants \
           ConfigMap/siem-tenants Secret/wazuh-securityconfig; do
  grep -qx "tenant entries only: $obj" "$TMP/diff" && ok "tenant 003 reaches $obj" || ko "tenant 003 missing from $obj"
done
if python3 "$SCRIPT_DIR/tenant_diff.py" "$TMP/r2.json" "$TMP/r3.json" no-such-marker >/dev/null; then
  ko "tenant diff detects unexplained changes"
else
  ok "tenant diff detects unexplained changes"
fi

# --- content ------------------------------------------------------------
cfg=$(yq 'select(.kind == "ConfigMap" and .metadata.name == "siem-tenants") | .data["tenants.json"]' "$R2")
[ "$(jq -r '[.tenants[].code] | join(",")' <<<"$cfg")" = "001,002" ] && ok "siem-tenants lists 001,002" || ko "siem-tenants tenants: $cfg"
[ "$(jq -r '.tenants[1].retentionDays' <<<"$cfg")" = 90 ] && ok "retentionDays per tenant" || ko "retentionDays"
[ "$(jq -r '.tenants[0].retentionDays' <<<"$cfg")" = 365 ] && ok "retentionDays default" || ko "retentionDays default"
# kubeaid-cli pkg/siem/config rejects unknown fields; keep to its schema.
extra=$(jq -r '(keys - ["domain","tenantGroupPrefix","keycloak","operators","tenants","clients","secrets","components"]),
               ([.tenants[] | keys[]] | unique - ["code","name","retentionDays","idp"]),
               (.components | keys - ["iris","wazuh","velociraptor"]) | .[]' <<<"$cfg")
[ -z "$extra" ] && ok "siem-tenants keeps to the reconciler schema" || ko "unknown siem-tenants fields: $extra"
[ "$(jq -r '.tenantGroupPrefix' <<<"$cfg")" = tenant- ] && ok "tenant group prefix" || ko "tenant group prefix"
[ "$(jq -r '[.secrets[].name] | join(",")' <<<"$cfg")" = "wazuh-dashboard-oidc,velociraptor-oidc,dfir-iris-oidc,oidc-credentials,iris-keycloak-sync" ] \
  && ok "generated Secrets follow the clients" || ko "secrets: $(jq -c .secrets <<<"$cfg")"
[ "$(jq -r '.components.iris.url' <<<"$cfg")" = "http://dfir-iris-app:8000" ] && ok "same-namespace IRIS URL" || ko "IRIS URL"
[ "$(jq -r '[.clients[].clientId] | join(",")' <<<"$cfg")" = "wazuh-dashboard,velociraptor,iris,misp,iris-sync" ] && ok "default OIDC clients" || ko "clients: $(jq -c .clients <<<"$cfg")"

grp=$(yq 'select(.metadata.name == "wazuh-tenants") | .data["tenant-002.conf"]' "$R2")
grep -qF '<label key="tenant">002</label>' <<<"$grp" && ok "wazuh agent group label" || ko "wazuh agent group: $grp"
opts=$(yq 'select(.metadata.name == "wazuh-tenants") | .data["iris-options.json"]' "$R2")
[ "$(jq -r '.customer_names["001"]' <<<"$opts")" = "Tenant A" ] && ok "custom-iris customer names" || ko "iris options: $opts"
map=$(yq 'select(.metadata.name == "dfir-iris-tenants") | .data["mapping.json"]' "$R2")
[ "$(jq -c '.groups["tenant-001"].customers' <<<"$map")" = '["Tenant A"]' ] && ok "IRIS mapping per tenant" || ko "IRIS mapping: $map"
[ "$(jq -c '.roles.analyst.customers' <<<"$map")" = '["*"]' ] && ok "IRIS mapping for operators" || ko "IRIS operator mapping"
gm=$(yq 'select(.metadata.name == "velociraptor-tenants") | .data["group-map.json"]' "$R2")
[ "$(jq -c '.["tenant-002"]' <<<"$gm")" = '{"orgs":["Tenant B"],"role":"investigator"}' ] && ok "Velociraptor group map" || ko "group map: $gm"

# Wiring into the components
yq 'select(.kind == "StatefulSet" and .metadata.name == "wazuh-manager-master") | .spec.template.spec.initContainers[].name' "$R2" | grep -x agent-group-conf >/dev/null \
  && ok "wazuh managers copy tenant agent groups" || ko "agent-group-conf init container"
wconf=$(yq 'select(.kind == "ConfigMap" and .metadata.name == "wazuh-manager-config") | .data["worker.conf"]' "$R2")
grep -qF 'iris-options.json' <<<"$wconf" && ok "worker integration reads iris-options.json" || ko "worker integration options_file"
grep -qx "CronJob misp-wazuh-cdb-export $NS" "$TMP/objs2" \
  && ko "cdb export rendered by default" || ok "cdb export stays off by default"
yq 'select(.kind == "NetworkPolicy" and .metadata.name == "ollama-ollama") | .spec.ingress[0].from[0].podSelector.matchLabels["app.kubernetes.io/component"]' "$R2" | grep -x ai-triage >/dev/null \
  && ok "ollama admits the triage job only" || ko "ollama policy"

# --- input validation ---------------------------------------------------
expect_failure "schema rejects a dash in a tenant code" "does not match pattern" -f "$SCRIPT_DIR/values-bad-tenant.yaml"
expect_failure "schema rejects a numeric code" "tenants/0/code" --set-json 'tenants=[{"code":1,"name":"A"}]'
expect_failure "duplicate tenant code" "listed twice" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'tenants=[{"code":"001","name":"A"},{"code":"001","name":"B"}]'
expect_failure "duplicate tenant name" "listed twice" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'tenants=[{"code":"001","name":"A"},{"code":"002","name":"A"}]'
expect_failure "tenant without reader role" "extraRoles.tenant-003-reader" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'tenants=[{"code":"001","name":"A"},{"code":"003","name":"C"}]'
expect_failure "label key mismatch" "must equal tenantLabelKey" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set tenantLabelKey=other

if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'tenants=[{"code":"001","name":"A"},{"code":"003","name":"C"}]' --set checks.wazuhTenantRoles=false >/dev/null; then
  ok "checks.wazuhTenantRoles=false skips the role check"
else
  ko "checks.wazuhTenantRoles=false"; cat "$TMP/err"
fi
if render --set wazuh.enabled=false --set velociraptor.enabled=false --set dfir-iris.enabled=false --set misp.enabled=false --set ollama.enabled=false >"$TMP/none.yaml"; then
  [ "$(objects "$TMP/none.yaml" | awk '{print $1" "$2}' | tr '\n' ' ')" = "ConfigMap siem-tenants " ] \
    && ok "all components off leaves only siem-tenants" || ko "components off: $(objects "$TMP/none.yaml")"
else
  ko "render with all components off"; cat "$TMP/err"
fi

# --- reconciler ---------------------------------------------------------
if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set reconciler.enabled=true --set reconciler.image.tag=test >"$TMP/rec.yaml"; then
  ok "renders with the reconciler"
  args=$(yq -o=json -I=0 'select(.kind == "CronJob" and .metadata.name == "siem-reconciler") | .spec.jobTemplate.spec.template.spec.containers[0].args' "$TMP/rec.yaml")
  [ "$args" = '["--config","/etc/siem/tenants.json","--dry-run=true"]' ] && ok "reconciler args" || ko "reconciler args: $args"
  yq 'select(.kind == "Job" and .metadata.name == "siem-reconciler-postsync") | .metadata.annotations["argocd.argoproj.io/hook"]' "$TMP/rec.yaml" | grep -x PostSync >/dev/null \
    && ok "reconciler PostSync job" || ko "reconciler PostSync job"
  outside=$(objects "$TMP/rec.yaml" | awk -v ns="$NS" '$3 != ns {print $1" "$2" "$3}' | sort | tr '\n' ';')
  [ "$outside" = "Role security-operations-siem-reconciler keycloakx;RoleBinding security-operations-siem-reconciler keycloakx;" ] \
    && ok "only the Keycloak Secret reader leaves the namespace" || ko "objects outside $NS: $outside"
else
  ko "renders with the reconciler"; cat "$TMP/err"
fi
expect_failure "reconciler needs an image tag" "reconciler.image.tag is required" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set reconciler.enabled=true

echo
echo "==================================="
echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
