#!/usr/bin/env bash
# Render tests for the security-operations umbrella chart.
#
# Usage: tests/render_test.sh
# Requires: helm, yq (v4), python3 on PATH. No cluster access (pure `helm template`).
#
# Checks: lint; renders with a generic 2-tenant and 3-tenant fixture; no
# duplicate kind/name/namespace; every namespaced object in the release
# namespace except the tenant namespaces' own and the CA in cert-manager; the
# component object names a standalone install has (Wazuh: central search only,
# no manager); iris-pgsql/iris-rabbitmq once; no selector that matches on
# app.kubernetes.io/instance alone (one release = one instance label for every
# component); the 3-tenant render differs from the 2-tenant one only by tenant
# 003 entries; schema and template checks reject bad input; the reconciler
# renders when enabled, with Secret access in each tenant namespace.
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

# Cluster-scoped: the tenant namespaces and the CA issuers. The CA key lives in
# cert-manager's namespace.
foreign=$(awk -v ns="$NS" '$3 != ns' "$TMP/objs2" | grep -v -E '^(Namespace wazuh-00[12]|ClusterIssuer soc-ca(-selfsigned)?) '"$NS"'$' | grep -vx 'Certificate soc-ca cert-manager')
[ -z "$foreign" ] && ok "every namespaced object in namespace $NS" || ko "objects outside $NS: $foreign"

stray=$(awk '$2 ~ /security-operations/' "$TMP/objs2")
[ -z "$stray" ] && ok "no component object named after the release" || ko "release-named objects: $stray"

for want in "StatefulSet wazuh-indexer" "Service wazuh-indexer-nodes" "Deployment wazuh-dashboard" \
            "StatefulSet velociraptor" "Service velociraptor-frontend" "Service velociraptor-gui" \
            "Deployment dfir-iris-app" "Deployment dfir-iris-worker" "Service dfir-iris-app" \
            "Deployment misp" "Service misp" "MariaDB misp-mariadb" \
            "Deployment ollama" "Service ollama" \
            "ConfigMap velociraptor-tenants" "ConfigMap dfir-iris-tenants" "ConfigMap siem-tenants" \
            "Namespace wazuh-001" "Namespace wazuh-002" "ClusterIssuer soc-ca"; do
  if grep -qx "$want $NS" "$TMP/objs2"; then ok "has $want"; else ko "missing $want"; fi
done

for gone in "StatefulSet wazuh-manager-master" "StatefulSet wazuh-manager-worker" "Service wazuh" \
            "DaemonSet wazuh-agent" "ConfigMap wazuh-tenants"; do
  if grep -q "^$gone " "$TMP/objs2"; then ko "central side has $gone"; else ok "no $gone on the central side"; fi
done

for once in "Cluster iris-pgsql" "RabbitmqCluster iris-rabbitmq"; do
  c=$(grep -cx "$once $NS" "$TMP/objs2")
  [ "$c" = 1 ] && ok "$once rendered once" || ko "$once rendered $c times"
done

# Every object of a standalone wrapper install (release == chart name) keeps
# its kind and name inside the umbrella.
# Wazuh is left out: the central instance is a search-only subset of it.
for c in velociraptor dfir-iris misp ollama; do
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
grep -qx "added: Namespace/wazuh-003" "$TMP/diff" && ok "tenant 003 gets its namespace" || ko "no namespace for tenant 003"
for obj in ConfigMap/velociraptor-tenants ConfigMap/dfir-iris-tenants ConfigMap/siem-tenants; do
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
extra=$(jq -r '(keys - ["domain","tenantGroupPrefix","keycloak","operators","tenants","clients","secrets","components","enrolment","secretCopies"]),
               ([.tenants[] | keys[]] | unique - ["code","name","retentionDays","idp"]),
               (.components | keys - ["iris","wazuh","wazuhCentral","velociraptor"]) | .[]' <<<"$cfg")
[ -z "$extra" ] && ok "siem-tenants keeps to the reconciler schema" || ko "unknown siem-tenants fields: $extra"
[ "$(jq -r '.tenantGroupPrefix' <<<"$cfg")" = tenant- ] && ok "tenant group prefix" || ko "tenant group prefix"
[ "$(jq -r '[.secrets[] | .namespace + "/" + .name] | join(",")' <<<"$cfg")" = "$NS/wazuh-dashboard-oidc,wazuh-001/wazuh-dashboard-oidc,wazuh-002/wazuh-dashboard-oidc,$NS/velociraptor-oidc,$NS/dfir-iris-oidc,$NS/oidc-credentials,$NS/iris-keycloak-sync,$NS/wazuh-api-cred" ] \
  && ok "generated Secrets follow the clients" || ko "secrets: $(jq -c .secrets <<<"$cfg")"
[ "$(jq -c '.secrets[1].keys[0]' <<<"$cfg")" = '{"key":"OPENSEARCH_OIDC_CLIENT_ID","value":"wazuh-dashboard-001"}' ] \
  && ok "tenant dashboard Secret carries its client id" || ko "tenant OIDC secret: $(jq -c '.secrets[1]' <<<"$cfg")"
[ "$(jq -r '.components.iris.url' <<<"$cfg")" = "http://dfir-iris-app:8000" ] && ok "same-namespace IRIS URL" || ko "IRIS URL"
[ "$(jq -r '[.clients[].clientId] | join(",")' <<<"$cfg")" = "wazuh-dashboard,wazuh-dashboard-001,wazuh-dashboard-002,velociraptor,iris,misp,iris-sync" ] && ok "default OIDC clients" || ko "clients: $(jq -c .clients <<<"$cfg")"
[ "$(jq -r '.clients[1].redirectUris[0]' <<<"$cfg")" = "https://wazuh-001.example.com/auth/openid/login" ] && ok "tenant dashboard redirect URI" || ko "tenant redirect: $(jq -c '.clients[1].redirectUris' <<<"$cfg")"
[ "$(jq -r '[.components.wazuh[] | .tenant + "=" + .url + "@" + .credSecretRef.namespace] | join(",")' <<<"$cfg")" = "001=https://wazuh.wazuh-001.svc:55000@wazuh-001,002=https://wazuh.wazuh-002.svc:55000@wazuh-002" ] \
  && ok "one Wazuh manager per tenant" || ko "wazuh managers: $(jq -c .components.wazuh <<<"$cfg")"
[ "$(jq -r '[.components.wazuhCentral.remotes[] | .alias + "=" + .seeds[0]] | join(",")' <<<"$cfg")" = "001=wazuh-indexer-nodes.wazuh-001.svc:9300,002=wazuh-indexer-nodes.wazuh-002.svc:9300" ] \
  && ok "cross-cluster search remotes" || ko "remotes: $(jq -c .components.wazuhCentral <<<"$cfg")"
[ "$(jq -r '[.enrolment[] | .tenant + ":" + .managerHost + ":" + (.registrationPort|tostring) + "/" + (.eventsPort|tostring) + "@" + .namespace] | join(",")' <<<"$cfg")" = "001:agents.example.com:20015/20014@wazuh-001,002:agents.example.com:20025/20024@wazuh-002" ] \
  && ok "enrolment bundles" || ko "enrolment: $(jq -c .enrolment <<<"$cfg")"
[ "$(jq -r '[.enrolment[].agentVersion] | unique | join(",")' <<<"$cfg")" = "4.14.3-1" ] \
  && ok "enrolment agent version matches the managers" || ko "agentVersion: $(jq -c '[.enrolment[].agentVersion]' <<<"$cfg")"
[ "$(jq -r '[.secretCopies[] | .to.namespace + "/" + .to.name + ":" + .to.key] | join(",")' <<<"$cfg")" = "wazuh-001/iris-api-key:API_KEY,$NS/wazuh-api-cred-001:API_USERNAME,$NS/wazuh-api-cred-001:API_PASSWORD,wazuh-002/iris-api-key:API_KEY,$NS/wazuh-api-cred-002:API_USERNAME,$NS/wazuh-api-cred-002:API_PASSWORD" ] \
  && ok "Secret copies" || ko "secretCopies: $(jq -c .secretCopies <<<"$cfg")"
[ "$(yq 'select(.kind == "Namespace" and .metadata.name == "wazuh-002") | .metadata.labels["security-operations.kubeaid.io/tenant"]' "$R2")" = "002" ] \
  && ok "tenant namespace label" || ko "tenant namespace label"
[ "$(yq 'select(.kind == "Namespace" and .metadata.name == "wazuh-002") | .metadata.annotations["argocd.argoproj.io/sync-options"]' "$R2")" = "Prune=false,Delete=false" ] \
  && ok "tenant namespaces are never pruned" || ko "tenant namespace sync options"
map=$(yq 'select(.metadata.name == "dfir-iris-tenants") | .data["mapping.json"]' "$R2")
[ "$(jq -c '.groups["tenant-001"].customers' <<<"$map")" = '["Tenant A"]' ] && ok "IRIS mapping per tenant" || ko "IRIS mapping: $map"
[ "$(jq -c '.roles.analyst.customers' <<<"$map")" = '["*"]' ] && ok "IRIS mapping for operators" || ko "IRIS operator mapping"
gm=$(yq 'select(.metadata.name == "velociraptor-tenants") | .data["group-map.json"]' "$R2")
[ "$(jq -c '.["tenant-002"]' <<<"$gm")" = '{"orgs":["Tenant B"],"role":"investigator"}' ] && ok "Velociraptor group map" || ko "group map: $gm"

# Wiring into the components
[ "$(yq 'select(.kind == "Certificate" and .metadata.name == "wazuh-node") | .spec.issuerRef.name + "/" + .spec.issuerRef.kind' "$R2")" = "soc-ca/ClusterIssuer" ] \
  && ok "central indexer certificate from the shared CA" || ko "central node certificate issuer"
yq 'select(.kind == "Deployment" and .metadata.name == "wazuh-dashboard") | .spec.template.spec.volumes[].secret.secretName' "$R2" | grep -x wazuh-app-config >/dev/null \
  && ok "central dashboard mounts wazuh-app-config" || ko "central dashboard wazuh.yml"
grep -qx "CronJob misp-wazuh-cdb-export $NS" "$TMP/objs2" \
  && ko "cdb export rendered by default" || ok "cdb export stays off by default"
yq 'select(.kind == "NetworkPolicy" and .metadata.name == "ollama-ollama") | .spec.ingress[0].from[0].podSelector.matchLabels["app.kubernetes.io/component"]' "$R2" | grep -x ai-triage >/dev/null \
  && ok "ollama admits the triage job only" || ko "ollama policy"

# --- input validation ---------------------------------------------------
expect_failure "schema rejects a dash in a tenant code" "does not match pattern" -f "$SCRIPT_DIR/values-bad-tenant.yaml"
expect_failure "schema rejects a numeric code" "tenants/0/code" --set-json 'tenants=[{"code":1,"name":"A"}]'
expect_failure "duplicate tenant code" "listed twice" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'tenants=[{"code":"001","name":"A"},{"code":"001","name":"B"}]'
expect_failure "duplicate tenant name" "listed twice" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'tenants=[{"code":"001","name":"A"},{"code":"002","name":"A"}]'
expect_failure "agent port used twice" "used twice" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'tenants=[{"code":"001","name":"A","agentPorts":{"registration":20015,"events":20014}},{"code":"002","name":"B","agentPorts":{"registration":20015,"events":20024}}]'
expect_failure "MISP export without a tenant target" 'targets entry named "002"' -f "$SCRIPT_DIR/values-2-tenants.yaml" --set misp.wazuhCdbExport.enabled=true --set-json 'misp.wazuhCdbExport.targets=[{"name":"001","url":"https://wazuh.wazuh-001.svc:55000","credentialsSecret":"wazuh-api-cred-001"}]'

if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set misp.wazuhCdbExport.enabled=true --set checks.mispTargets=false \
     --set-json 'misp.wazuhCdbExport.targets=[{"name":"001","url":"https://wazuh.wazuh-001.svc:55000","credentialsSecret":"wazuh-api-cred-001"}]' >/dev/null; then
  ok "checks.mispTargets=false skips the target check"
else
  ko "checks.mispTargets=false"; cat "$TMP/err"
fi
if render --set wazuh.enabled=false --set velociraptor.enabled=false --set dfir-iris.enabled=false --set misp.enabled=false --set ollama.enabled=false --set socCA.enabled=false >"$TMP/none.yaml"; then
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
  [ "$(yq -N 'select(.kind == "Job" and .metadata.name == "siem-reconciler-sync") | .metadata.annotations["argocd.argoproj.io/hook"] + "@" + .metadata.annotations["argocd.argoproj.io/sync-wave"]' "$TMP/rec.yaml")" = "Sync@-1" ] \
    && ok "reconciler Sync hook before the components" || ko "reconciler Sync hook"
  [ "$(yq -N -o=json -I=0 'select(.kind == "Job" and .metadata.name == "siem-reconciler-sync") | .spec.template.spec.containers[0].args[-1]' "$TMP/rec.yaml")" = '"--exit-zero"' ] \
    && ok "hook runs do not fail the sync" || ko "hook args"
  [ "$(yq -N 'select(.kind == "ConfigMap" and .metadata.name == "siem-tenants") | .metadata.annotations["argocd.argoproj.io/sync-wave"]' "$TMP/rec.yaml")" = "-2" ] \
    && ok "reconciler input before its hook" || ko "siem-tenants wave"
  [ "$(yq 'select(.kind == "CronJob" and .metadata.name == "siem-reconciler") | .spec.jobTemplate.spec.template.spec.imagePullSecrets' "$TMP/rec.yaml")" = "null" ] \
    && ok "no pull secrets by default" || ko "pull secrets rendered by default"
  outside=$(objects "$TMP/rec.yaml" | awk -v ns="$NS" '$3 != ns && $1 ~ /^Role/ {print $1" "$2" "$3}' | sort | tr '\n' ';')
  [ "$outside" = "Role security-operations-siem-reconciler keycloakx;Role security-operations-siem-reconciler wazuh-001;Role security-operations-siem-reconciler wazuh-002;RoleBinding security-operations-siem-reconciler keycloakx;RoleBinding security-operations-siem-reconciler wazuh-001;RoleBinding security-operations-siem-reconciler wazuh-002;" ] \
    && ok "reconciler RBAC: Keycloak Secret reader and each tenant namespace" || ko "reconciler RBAC outside $NS: $outside"
else
  ko "renders with the reconciler"; cat "$TMP/err"
fi
if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set reconciler.enabled=true --set reconciler.image.tag=test \
     --set-json 'reconciler.imagePullSecrets=[{"name":"registry-pull"}]' \
     --set-json 'reconciler.hostAliases=[{"ip":"10.0.0.10","hostnames":["keycloak.example.com"]}]' >"$TMP/pull.yaml"; then
  [ "$(yq -N 'select((.kind == "Job" or .kind == "CronJob") and (.metadata.name | test("^siem-reconciler"))) | (.spec.template.spec.imagePullSecrets // .spec.jobTemplate.spec.template.spec.imagePullSecrets)[0].name' "$TMP/pull.yaml" | sort -u)" = "registry-pull" ] \
    && ok "reconciler pull secrets on Job and CronJob" || ko "reconciler pull secrets: $(yq -N 'select(.kind == "Job" or .kind == "CronJob") | .metadata.name' "$TMP/pull.yaml")"
  [ "$(yq -N 'select(.kind == "CronJob" and .metadata.name == "siem-reconciler") | .spec.jobTemplate.spec.template.spec.hostAliases[0].hostnames[0]' "$TMP/pull.yaml")" = "keycloak.example.com" ] \
    && ok "reconciler host aliases" || ko "reconciler host aliases"
else
  ko "renders with reconciler pull secrets"; cat "$TMP/err"
fi
expect_failure "reconciler needs an image tag" "reconciler.image.tag is required" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set reconciler.enabled=true

echo
echo "==================================="
echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
