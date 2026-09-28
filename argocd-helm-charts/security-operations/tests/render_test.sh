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
# renders when enabled, with Secret access in each tenant namespace; the
# Velociraptor API, API client bootstrap and server artifacts.
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
            "Service velociraptor-api" "ConfigMap velociraptor-artifacts" \
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
extra=$(jq -r '(keys - ["domain","tenantGroupPrefix","keycloak","operators","tenants","clients","secrets","components","enrolment","secretCopies","retention"]),
               ([.tenants[] | keys[]] | unique - ["code","name","retentionDays","idp"]),
               (.components | keys - ["iris","wazuh","wazuhCentral","velociraptor","misp"]) | .[]' <<<"$cfg")
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
[ "$(jq -c '[.components.wazuhCentral.dashboardURL, .components.wazuhCentral.indexPatterns[0]]' <<<"$cfg")" = '["http://wazuh-dashboard:5601",{"default":true,"timeFieldName":"timestamp","title":"*:wazuh-alerts-*"}]' ] \
  && ok "central dashboard index pattern" || ko "index patterns: $(jq -c .components.wazuhCentral <<<"$cfg")"
[ "$(jq -r '[.enrolment[] | .tenant + ":" + .managerHost + ":" + (.registrationPort|tostring) + "/" + (.eventsPort|tostring) + "@" + .namespace] | join(",")' <<<"$cfg")" = "001:agents.example.com:20015/20014@wazuh-001,002:agents.example.com:20025/20024@wazuh-002" ] \
  && ok "enrolment bundles" || ko "enrolment: $(jq -c .enrolment <<<"$cfg")"
[ "$(jq -r '[.enrolment[].agentVersion] | unique | join(",")' <<<"$cfg")" = "4.14.3-1" ] \
  && ok "enrolment agent version matches the managers" || ko "agentVersion: $(jq -c '[.enrolment[].agentVersion]' <<<"$cfg")"
[ "$(jq -r '[.secretCopies[] | .to.namespace + "/" + .to.name + ":" + .to.key] | join(",")' <<<"$cfg")" = "$NS/wazuh-api-cred-001:API_USERNAME,$NS/wazuh-api-cred-001:API_PASSWORD,$NS/wazuh-api-cred-002:API_USERNAME,$NS/wazuh-api-cred-002:API_PASSWORD" ] \
  && ok "Secret copies (no shared IRIS key)" || ko "secretCopies: $(jq -c .secretCopies <<<"$cfg")"
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
if render --set wazuh.enabled=false --set velociraptor.enabled=false --set dfir-iris.enabled=false --set misp.enabled=false --set ollama.enabled=false --set socCA.enabled=false --set networkPolicies.enabled=false >"$TMP/none.yaml"; then
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

# --- Velociraptor API and server artifacts --------------------------------
velo=$(jq -c '.components.velociraptor' <<<"$cfg")
[ "$(jq -r '.address' <<<"$velo")" = "velociraptor-api:8001" ] && ok "reconciler dials the Velociraptor API Service" || ko "velociraptor address: $velo"
extra=$(jq -r 'keys - ["apiClientSecretRef","apiClientFile","address","serverMonitoring"] | .[]' <<<"$velo")
[ -z "$extra" ] && ok "components.velociraptor keeps to the reconciler schema" || ko "unknown velociraptor fields: $extra"
[ "$(jq -r '[.serverMonitoring[].artifact] | join(",")' <<<"$velo")" = "Custom.Server.IrisCollector,Custom.Server.KeycloakSync" ] \
  && ok "server monitoring entries" || ko "serverMonitoring: $velo"
[ "$(jq -r '.serverMonitoring[1].parameters | .KcUrl + " " + .KcRealm + " " + .KcClientId + " " + .DryRun + " " + .GroupMapFile' <<<"$velo")" = "https://keycloak.example.com/auth soc iris-sync N /etc/siem/group-map.json" ] \
  && ok "KeycloakSync parameters from keycloak" || ko "KeycloakSync parameters: $velo"
[ "$(jq -r '.serverMonitoring[1].parameters.Protected' <<<"$velo")" = '^(admin|VelociraptorServer|svc_.*|siem-reconciler)$' ] \
  && ok "KeycloakSync never removes the reconciler's API user" || ko "KeycloakSync Protected: $velo"
[ "$(jq -r '.serverMonitoring[0].parameters | .IrisUrl + " " + .IrisKeyFile + " " + .OrgMapFile' <<<"$velo")" = "http://dfir-iris-app:8000 /etc/iris/API_KEY /etc/siem/org-map.json" ] \
  && ok "IrisCollector parameters" || ko "IrisCollector parameters: $velo"
if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set dfir-iris.enabled=false >"$TMP/noiris.yaml"; then
  [ "$(yq 'select(.kind == "ConfigMap" and .metadata.name == "siem-tenants") | .data["tenants.json"]' "$TMP/noiris.yaml" | jq -r '[.components.velociraptor.serverMonitoring[].artifact] | join(",")')" = "Custom.Server.KeycloakSync" ] \
    && ok "no IrisCollector without IRIS" || ko "IrisCollector without IRIS"
else
  ko "render without IRIS"; cat "$TMP/err"
fi
[ "$(yq 'select(.kind == "Secret" and .metadata.name == "velociraptor-config-overlay") | .stringData["overlay.yaml"]' "$R2" | yq '.API.bind_address')" = "0.0.0.0" ] \
  && ok "API bound to all interfaces through the overlay" || ko "overlay API.bind_address"
[ "$(yq -N 'select(.kind == "NetworkPolicy" and .metadata.name == "velociraptor") | .spec.ingress[] | select(.ports[0].port == 8001) | .from[0].podSelector.matchLabels["app.kubernetes.io/name"]' "$R2")" = "siem-reconciler" ] \
  && ok "API port admits the reconciler" || ko "API NetworkPolicy"
sts=$(yq -o=json -I=0 'select(.kind == "StatefulSet" and .metadata.name == "velociraptor") | .spec.template.spec' "$R2")
[ "$(jq -r '[.containers[0].ports[].name] | join(",")' <<<"$sts")" = "frontend,gui,api,metrics" ] && ok "API container port" || ko "ports: $(jq -c '.containers[0].ports' <<<"$sts")"
[ "$(jq -r '.volumes[] | select(.name == "custom-artifacts") | .configMap.name' <<<"$sts")" = "velociraptor-artifacts" ] \
  && ok "server loads the chart's artifacts" || ko "custom-artifacts volume: $(jq -c .volumes <<<"$sts")"
[ "$(jq -r '[.containers[0].volumeMounts[] | select(.name == "tenants" or .name == "iris-api-key" or .name == "keycloak-sync") | .mountPath] | join(",")' <<<"$sts")" = "/etc/siem,/etc/iris,/etc/keycloak" ] \
  && ok "artifact inputs mounted" || ko "mounts: $(jq -c '.containers[0].volumeMounts' <<<"$sts")"
[ "$(jq -c '.volumes[] | select(.name == "keycloak-sync") | .secret.items' <<<"$sts")" = '[{"key":"KEYCLOAK_CLIENT_SECRET","path":"client_secret"}]' ] \
  && ok "only the Keycloak client secret in /etc/keycloak" || ko "keycloak-sync volume"
[ "$(jq -r '[.initContainers[].name] | join(",")' <<<"$sts")" = "config-merge" ] && ok "no API client bootstrap by default" || ko "init containers: $(jq -c '[.initContainers[].name]' <<<"$sts")"
[ "$(jq -r '.automountServiceAccountToken' <<<"$sts")" = "false" ] && ok "no ServiceAccount token by default" || ko "automount"
grep -q "^Role velociraptor-api-client " "$TMP/objs2" && ko "API client RBAC without apiClient" || ok "no API client RBAC by default"
# Every file in files/velociraptor is shipped unchanged.
for f in "$CHART_DIR"/files/velociraptor/*.yaml; do
  n=$(basename "$f")
  if yq "select(.kind == \"ConfigMap\" and .metadata.name == \"velociraptor-artifacts\") | .data[\"$n\"]" "$R2" | diff -q - "$f" >/dev/null; then
    ok "artifact $n shipped"
  else
    ko "artifact $n differs from files/velociraptor"
  fi
done
expect_failure "artifact change needs a new checksum" "checksum/server-artifacts to" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set-json 'velociraptorArtifacts.extraFiles={"Custom.Extra.yaml":"name: Custom.Extra\n"}'

# API client bootstrap with the reconciler
AC=(-f "$SCRIPT_DIR/values-2-tenants.yaml" --set reconciler.enabled=true --set reconciler.image.tag=test
    --set velociraptor.velociraptor.apiClient.enabled=true --set velociraptor.velociraptor.apiClient.publisherImage.tag=test
    --set-json 'velociraptor.velociraptor.apiClient.imagePullSecrets=[{"name":"registry-pull"}]')
if render "${AC[@]}" >"$TMP/ac.yaml"; then
  ok "renders with the API client bootstrap"
  sts=$(yq -o=json -I=0 'select(.kind == "StatefulSet" and .metadata.name == "velociraptor") | .spec.template.spec' "$TMP/ac.yaml")
  [ "$(jq -r '[.initContainers[].name] | join(",")' <<<"$sts")" = "config-merge,api-client,api-client-publish" ] \
    && ok "API client init containers after the config merge" || ko "init containers: $(jq -c '[.initContainers[].name]' <<<"$sts")"
  [ "$(jq -r '.initContainers[1].args | join(" ")' <<<"$sts")" = "--config /etc/velociraptor/server.config.yaml config api_client --name siem-reconciler --role administrator /api-client/api_client.yaml" ] \
    && ok "api_client minted with the merged config" || ko "api-client args: $(jq -c '.initContainers[1].args' <<<"$sts")"
  [ "$(jq -r '.initContainers[1].volumeMounts[] | select(.name == "datastore") | .mountPath' <<<"$sts")" = "/datastore" ] \
    && ok "api_client sees the datastore" || ko "api-client mounts"
  [ "$(jq -r '.initContainers[2].image + " " + (.initContainers[2].command + .initContainers[2].args | join(" "))' <<<"$sts")" = "ghcr.io/obmondo/siem-reconciler:test /usr/local/bin/siem-reconciler publish-api-client --file /api-client/api_client.yaml --name velociraptor-api-client --key api_client.yaml" ] \
    && ok "publisher runs the reconciler image" || ko "publisher: $(jq -c '.initContainers[2]' <<<"$sts")"
  [ "$(jq -r '.initContainers[2].env[] | select(.name == "POD_NAMESPACE") | .valueFrom.fieldRef.fieldPath' <<<"$sts")" = "metadata.namespace" ] \
    && ok "publisher namespace from the downward API" || ko "POD_NAMESPACE"
  [ "$(jq -r '[.automountServiceAccountToken, ([.containers[0].volumeMounts[].name] | index("api-client-token")), ([.initContainers[2].volumeMounts[].name] | index("api-client-token") != null)] | map(tostring) | join(",")' <<<"$sts")" = "false,null,true" ] \
    && ok "only the publisher gets a token" || ko "token mounts"
  [ "$(jq -r '[.imagePullSecrets[].name] | join(",")' <<<"$sts")" = "registry-pull" ] && ok "publisher pull secret" || ko "pull secrets: $(jq -c .imagePullSecrets <<<"$sts")"
  [ "$(yq -o=json -I=0 'select(.kind == "Role" and .metadata.name == "velociraptor-api-client") | .rules' "$TMP/ac.yaml")" = '[{"apiGroups":[""],"resources":["secrets"],"resourceNames":["velociraptor-api-client"],"verbs":["get","update","patch"]},{"apiGroups":[""],"resources":["secrets"],"verbs":["create"]}]' ] \
    && ok "API client Role on its Secret" || ko "API client Role"
  [ "$(yq -N 'select(.kind == "RoleBinding" and .metadata.name == "velociraptor-api-client") | .subjects[0].name' "$TMP/ac.yaml")" = "velociraptor" ] \
    && ok "API client Role bound to the Velociraptor ServiceAccount" || ko "API client RoleBinding"
  [ "$(yq -N 'select(.kind == "CiliumNetworkPolicy" and .metadata.name == "velociraptor-apiserver") | .spec.egress[0].toEntities[0]' "$TMP/ac.yaml")" = "kube-apiserver" ] \
    && ok "publisher reaches the Kubernetes API" || ko "API server egress"
else
  ko "renders with the API client bootstrap"; cat "$TMP/err"
fi
expect_failure "publisher image must be the reconciler image" "must equal reconciler.image" "${AC[@]}" --set velociraptor.velociraptor.apiClient.publisherImage.tag=other

# --- hardening: indexer users, soc-ca scope, MISP Valkey password ---------
users=$(yq -N 'select(.kind == "Secret" and .metadata.name == "wazuh-securityconfig") | .stringData["internal_users.yml"]' "$R2" | yq -r 'del(._meta) | keys | join(",")')
[ "$users" = "admin,kibanaserver" ] && ok "central indexer: no demo users" || ko "central internal users: $users"
grep -qE 'JJSXNfTowz7Uu5ttXfeYpeYE0arACvcwlPBStB1F|ae4ycwzwvLtZxwZ82RmiEunBbIPiAmGZduBAjKN0|u1ShR4l4uBS3Uv59Pa2y5|DpwmetHKwgYnorbgdvORCenv4NAK8cPUg8AI6pxLC' "$R2" \
  && ko "demo user hash rendered" || ok "no demo user hash rendered"
[ -z "$(yq -N 'select(.kind == "CertificateRequestPolicy") | .metadata.name' "$R2")" ] && ok "no soc-ca policy by default" || ko "soc-ca policy rendered by default"
[ -z "$(yq -N 'select(.kind == "Certificate" and .metadata.name == "wazuh-root-ca") | .metadata.name' "$R2")" ] \
  && ok "central Wazuh has no CA of its own under soc-ca" || ko "central wazuh-root-ca rendered"
if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set socCA.approverPolicy.enabled=true >"$TMP/crp.yaml"; then
  ok "renders with socCA.approverPolicy"
  got=$(yq -N 'select(.kind == "CertificateRequestPolicy") | .metadata.name + "=" + (.spec.selector.namespace.matchNames | join(",")) + "/" + ((.spec.allowed.subject.organizations.values // []) | join(","))' "$TMP/crp.yaml" | paste -sd' ' -)
  [ "$got" = "soc-ca-root=cert-manager/ soc-ca-central=security-operations/central soc-ca-tenant-001=wazuh-001/tenant-001 soc-ca-tenant-002=wazuh-002/tenant-002" ] \
    && ok "one soc-ca policy per namespace, with its own organization" || ko "soc-ca policies: $got"
  [ "$(yq -N 'select(.kind == "CertificateRequestPolicy" and .metadata.name == "soc-ca-tenant-001") | .spec.allowed.isCA' "$TMP/crp.yaml")" = "false" ] \
    && ok "tenant policy allows no CA" || ko "tenant policy isCA"
  [ "$(yq -N 'select(.kind == "RoleBinding" and .metadata.name == "soc-ca-approver-policy-use") | .metadata.namespace' "$TMP/crp.yaml" | paste -sd, -)" = "cert-manager,security-operations,wazuh-001,wazuh-002" ] \
    && ok "policy use bound per namespace" || ko "policy RoleBindings"
else
  ko "renders with socCA.approverPolicy"; cat "$TMP/err"
fi
if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set misp.misp.env.redisPasswordSecret.name=misp-redis >"$TMP/redis.yaml"; then
  [ "$(yq -N 'select(.kind == "ConfigMap" and (.metadata.name == "misp-env" or .metadata.name == "misp-modules-env")) | .data | keys | .[]' "$TMP/redis.yaml" | grep -cE '^REDIS_(PASSWORD|PW)$')" = 0 ] \
    && ok "MISP Valkey password not in a ConfigMap" || ko "MISP Valkey password in a ConfigMap"
  [ "$(yq -N 'select(.kind == "Deployment" and (.metadata.name == "misp" or .metadata.name == "misp-modules")) | .spec.template.spec.containers[0].env[] | select(.name == "REDIS_PASSWORD" or .name == "REDIS_PW") | .valueFrom.secretKeyRef.name' "$TMP/redis.yaml" | paste -sd, -)" = "misp-redis,misp-redis" ] \
    && ok "MISP and misp-modules read the Valkey password from the Secret" || ko "MISP Valkey password env"
else
  ko "renders with misp redisPasswordSecret"; cat "$TMP/err"
fi
# --- identities and API keys (README 6.1) ---------------------------------
iris=$(jq -c '.components.iris' <<<"$cfg")
[ "$(jq -c '.groups' <<<"$iris")" = '[{"description":"Alerts from one tenant'"'"'s Wazuh manager (custom-iris)","name":"Wazuh alert intake","permissions":["alerts_write","customers_read"]}]' ] \
  && ok "IRIS intake group with alert write and customer read only" || ko "IRIS groups: $iris"
[ "$(jq -r '[.serviceAccounts[] | select(.login | startswith("svc_wazuh_")) | .login + ":" + (.customers | join("+")) + ":" + .apiKeySecretRef.namespace + "/" + .apiKeySecretRef.name + "/" + .apiKeySecretRef.key] | join(",")' <<<"$iris")" = "svc_wazuh_001:Tenant A:wazuh-001/iris-api-key/API_KEY,svc_wazuh_002:Tenant B:wazuh-002/iris-api-key/API_KEY" ] \
  && ok "one IRIS account per tenant, own customer, key in the tenant namespace" || ko "tenant IRIS accounts: $iris"
[ "$(jq -r '.serviceAccounts[] | select(.login == "svc_ai") | has("customers")' <<<"$iris")" = "false" ] \
  && ok "svc_ai keeps every customer" || ko "svc_ai customers: $iris"
[ "$(yq 'select(.metadata.name == "velociraptor-tenants") | .data["alert-creators.json"]' "$R2" | jq -c .)" = '{"Tenant A":"svc_wazuh_001","Tenant B":"svc_wazuh_002"}' ] \
  && ok "alert creator map for the IrisCollector guard" || ko "alert-creators.json"
[ "$(jq -r '.serverMonitoring[0].parameters | .AutoRules + " " + .CreatorMapFile' <<<"$velo")" = "{} /etc/siem/alert-creators.json" ] \
  && ok "automatic response off by default, creator map wired" || ko "IrisCollector AutoRules: $velo"
grep -q "^    default: '{}'$" "$CHART_DIR/files/velociraptor/Custom.Server.IrisCollector.yaml" && ! grep -q "RemoveByHash\"}}'$" "$CHART_DIR/files/velociraptor/Custom.Server.IrisCollector.yaml" \
  && ok "IrisCollector AutoRules artifact default is empty" || ko "IrisCollector AutoRules default"
if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set tenantIris.enabled=false >"$TMP/shared.yaml"; then
  c=$(yq 'select(.metadata.name == "siem-tenants") | .data["tenants.json"]' "$TMP/shared.yaml")
  [ "$(jq -r '[.secretCopies[] | select(.to.name == "iris-api-key") | .to.namespace] | join(",")' <<<"$c"),$(jq -r '[.components.iris.serviceAccounts[].login] | join("+")' <<<"$c"),$(jq -r '.components.iris | has("groups")' <<<"$c")" = "wazuh-001,wazuh-002,svc_ai,false" ] \
    && ok "tenantIris.enabled=false copies the shared key again" || ko "tenantIris off: $(jq -c '[.secretCopies, .components.iris]' <<<"$c")"
else
  ko "render with tenantIris off"; cat "$TMP/err"
fi
misp=$(jq -c '.components.misp' <<<"$cfg")
[ "$(jq -r '.apiKeySecretRef.name + " " + .users[0].role + " " + .users[0].apiKeySecretRef.name + "/" + .users[0].apiKeySecretRef.key' <<<"$misp")" = "misp-api-key Read Only misp-export-key/key" ] \
  && ok "read-only MISP user for the export" || ko "components.misp: $misp"
EXP=(-f "$SCRIPT_DIR/values-2-tenants.yaml" --set misp.wazuhCdbExport.enabled=true --set checks.mispTargets=false
     --set-json 'misp.wazuhCdbExport.targets=[{"name":"001","url":"https://wazuh.wazuh-001.svc:55000","credentialsSecret":"wazuh-api-cred-001"}]')
if render "${EXP[@]}" >"$TMP/exp.yaml"; then
  [ "$(yq -o=json -I=0 'select(.kind == "CronJob" and .metadata.name == "misp-wazuh-cdb-export") | .spec.jobTemplate.spec.template.spec.containers[0].env[] | select(.name == "MISP_READONLY_KEY") | .valueFrom.secretKeyRef' "$TMP/exp.yaml")" = '{"name":"misp-export-key","key":"key","optional":true}' ] \
    && ok "export prefers the read-only key, optional" || ko "export MISP_READONLY_KEY"
else
  ko "render with the export"; cat "$TMP/err"
fi
RC=(-f "$SCRIPT_DIR/values-2-tenants.yaml" --set reconciler.enabled=true --set reconciler.image.tag=test --set keycloak.reconcilerClient.enabled=true)
if render "${RC[@]}" >"$TMP/rc.yaml"; then
  c=$(yq 'select(.metadata.name == "siem-tenants") | .data["tenants.json"]' "$TMP/rc.yaml")
  [ "$(jq -c '.keycloak.clientCredentials' <<<"$c")" = "{\"clientId\":\"siem-reconciler\",\"secretRef\":{\"key\":\"KEYCLOAK_CLIENT_SECRET\",\"name\":\"siem-reconciler-keycloak\",\"namespace\":\"$NS\"}}" ] \
    && ok "reconciler logs in with its client" || ko "clientCredentials: $(jq -c .keycloak <<<"$c")"
  [ "$(jq -r '.keycloak | has("reconcilerClient")' <<<"$c"),$(jq -r '.keycloak.adminSecretRef.name' <<<"$c")" = "false,keycloak-admin" ] \
    && ok "admin kept as bootstrap fallback" || ko "keycloak block: $(jq -c .keycloak <<<"$c")"
  [ "$(jq -c '.clients[] | select(.clientId == "siem-reconciler") | [.serviceAccountsEnabled, (.serviceAccountClientRoles["realm-management"] | index("manage-realm") != null), (.serviceAccountClientRoles["realm-management"] | index("realm-admin"))]' <<<"$c")" = '[true,true,null]' ] \
    && ok "reconciler client: service account with realm-management roles, not realm-admin" || ko "reconciler client: $(jq -c '.clients[-1]' <<<"$c")"
  [ "$(jq -r '.secrets[] | select(.name == "siem-reconciler-keycloak") | .keys[0].key' <<<"$c")" = "KEYCLOAK_CLIENT_SECRET" ] \
    && ok "reconciler client secret generated" || ko "reconciler client secret"
else
  ko "renders with the reconciler client"; cat "$TMP/err"
fi
if render "${RC[@]}" --set keycloak.adminSecretRef=null >"$TMP/rc2.yaml"; then
  c=$(yq 'select(.metadata.name == "siem-tenants") | .data["tenants.json"]' "$TMP/rc2.yaml")
  [ "$(jq -r '.keycloak | has("adminSecretRef")' <<<"$c")" = "false" ] && ok "no admin login once adminSecretRef is null" || ko "adminSecretRef still rendered"
  objects "$TMP/rc2.yaml" | grep -q " keycloakx$" && ko "Keycloak Secret reader without admin" || ok "no Keycloak Secret reader without admin"
else
  ko "renders with the reconciler client only"; cat "$TMP/err"
fi
expect_failure "Keycloak needs the admin or the reconciler client" "anyOf" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set keycloak.adminSecretRef=null
IR=(-f "$SCRIPT_DIR/values-2-tenants.yaml" --set dfir-iris.authentication.type=oidc --set dfir-iris.authentication.oidc.issuerUrl=https://keycloak.example.com/auth/realms/soc
    --set dfir-iris.authentication.oidc.clientId=iris --set dfir-iris.authentication.oidc.existingSecret=dfir-iris-oidc
    --set dfir-iris.keycloakSync.enabled=true --set dfir-iris.keycloakSync.existingSecret=iris-keycloak-sync
    --set dfir-iris.keycloakSync.keycloak.url=https://keycloak.example.com/auth --set dfir-iris.keycloakSync.keycloak.realm=soc --set dfir-iris.keycloakSync.keycloak.clientId=iris-sync)
if render "${IR[@]}" >"$TMP/iris.yaml"; then
  envs=$(yq -o=json -I=0 'select(.kind == "Deployment" and .metadata.name == "dfir-iris-app") | .spec.template.spec.containers[0].env' "$TMP/iris.yaml")
  [ "$(jq -r '[.[] | select(.name == "IRIS_AUTHENTICATION_LOCAL_FALLBACK" or .name == "OIDC_MAPPING_USERNAME") | .value] | join(",")' <<<"$envs")" = "False,sub" ] \
    && ok "IRIS SSO: no local fallback, users matched on sub" || ko "IRIS auth env: $envs"
  [ "$(yq 'select(.kind == "CronJob" and .metadata.name == "dfir-iris-keycloak-sync") | .spec.jobTemplate.spec.template.spec.containers[0].env[] | select(.name == "LOGIN_ATTRIBUTE") | .value' "$TMP/iris.yaml")" = "id" ] \
    && ok "keycloakSync logins follow the sub claim" || ko "keycloakSync LOGIN_ATTRIBUTE"
else
  ko "renders with IRIS SSO"; cat "$TMP/err"
fi
expect_failure "keycloakSync refuses an unmapped login claim" "mappingUsername preferred_username, email or sub" "${IR[@]}" --set dfir-iris.authentication.oidc.mappingUsername=nickname
# --- network policies and TLS -------------------------------------------
# Every workload on (values-netpol.yaml). netpol_check.py: a default deny, a policy
# of its own for every workload, and no rule open to anywhere except the agent
# frontend (Velociraptor 8000) and MISP's internet egress (Cilium world, 80/443).
NP=(-f "$SCRIPT_DIR/values-2-tenants.yaml" -f "$SCRIPT_DIR/values-netpol.yaml")
NETPOL_CHECK="$CHARTS_ROOT/wazuh/tests/netpol_check.py"
if render "${NP[@]}" >"$TMP/np.yaml"; then
  ok "renders with every workload"
  yq ea -o=json '[.]' "$TMP/np.yaml" >"$TMP/np.json"
  if out=$(python3 "$NETPOL_CHECK" "$TMP/np.json" --ns "$NS" --open-ingress 8000 --world-egress 80,443); then
    ok "default deny, a policy per workload, nothing open beyond the agent frontend"
  else
    ko "network policies: $out"
  fi
  npq() { yq -N "select(.kind == \"$1\" and .metadata.name == \"$2\") | $3" "$TMP/np.yaml" | sed '/^$/d'; }
  [ "$(npq NetworkPolicy secops-default-deny '.spec.egress[0].ports | map(.protocol + "/" + (.port|tostring)) | join(",")')" = "UDP/53,TCP/53" ] \
    && ok "default deny keeps DNS" || ko "default deny DNS"
  [ "$(npq NetworkPolicy secops-iris-app '.spec.ingress[0].from[] | select(.namespaceSelector.matchExpressions) | .podSelector.matchLabels.app')" = "wazuh-manager" ] \
    && ok "tenant managers reach IRIS" || ko "IRIS ingress from the tenant managers"
  [ "$(npq NetworkPolicy secops-reconciler '[.spec.egress[].ports[].port] | map(tostring) | join(",")')" = "443,8443,8080,8000,55000,9200,5601,8001" ] \
    && ok "reconciler egress: Keycloak, IRIS, managers, indexers, dashboard, Velociraptor" || ko "reconciler egress: $(npq NetworkPolicy secops-reconciler '[.spec.egress[].ports[].port]' | tr '\n' ' ')"
  for w in reconciler iris-postgres iris-rabbitmq; do
    [ "$(npq CiliumNetworkPolicy "secops-$w-apiserver" '.spec.egress[0].toEntities[0]')" = "kube-apiserver" ] \
      && ok "$w reaches the Kubernetes API" || ko "$w API server egress"
  done
  [ "$(npq CiliumNetworkPolicy secops-misp-internet '.spec.egress[0].toEntities[0]')" = "world" ] \
    && ok "MISP feeds through the world entity" || ko "MISP internet egress"
  [ "$(npq NetworkPolicy secops-misp-wazuh-cdb-export '.spec.egress[1].ports[0].port')" = "55000" ] \
    && ok "MISP export reaches the tenant managers" || ko "MISP export egress"
  [ "$(npq NetworkPolicy wazuh-dashboard '.spec.ingress[] | select(.from == null) | .ports[0].port')" = "" ] \
    && ok "central dashboard not open to any source" || ko "central dashboard any-source rule"
  [ "$(npq NetworkPolicy velociraptor '.spec.ingress[] | select(.ports[0].port == 8003) | .from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"]')" = "monitoring" ] \
    && ok "Velociraptor metrics for Prometheus only" || ko "Velociraptor metrics peers"
  [ "$(npq NetworkPolicy velociraptor '.spec.egress[].to[]? | select(.ipBlock) | .ipBlock.cidr')" = "" ] \
    && ok "Velociraptor has no CIDR egress" || ko "Velociraptor CIDR egress"
  # TLS: the reconciler and the MISP export verify against the soc-ca.
  [ "$(npq Certificate soc-ca-trust '.spec.issuerRef.name + "/" + .spec.secretName')" = "soc-ca/soc-ca-trust" ] \
    && ok "soc-ca trust Certificate here" || ko "soc-ca trust Certificate"
  cfg=$(npq ConfigMap siem-tenants '.data["tenants.json"]')
  [ "$(jq -r '[.components.wazuh[] | (.caFile + ":" + (.insecureSkipVerify // false | tostring))] + [.components.wazuhCentral.caFile + ":" + (.components.wazuhCentral.insecureSkipVerify // false | tostring)] | unique | join(",")' <<<"$cfg")" = "/etc/soc-ca/ca.crt:false" ] \
    && ok "reconciler verifies managers and indexer against the soc-ca" || ko "reconciler TLS: $(jq -c '.components.wazuh' <<<"$cfg")"
  [ "$(yq -N 'select(.kind == "CronJob" and .metadata.name == "siem-reconciler") | .spec.jobTemplate.spec.template.spec.volumes[] | select(.name == "soc-ca") | .secret.secretName + "/" + (.secret.optional | tostring)' "$TMP/np.yaml")" = "soc-ca-trust/true" ] \
    && ok "reconciler mounts the CA" || ko "reconciler CA volume"
  [ "$(yq -N 'select(.kind == "CronJob" and .metadata.name == "misp-wazuh-cdb-export") | .spec.jobTemplate.spec.template.spec.containers[0].env[] | select(.name == "WAZUH_TARGETS") | .value' "$TMP/np.yaml" | jq -r 'map(.caFile) | unique | join(",")')" = "/wazuh-ca/ca.crt" ] \
    && ok "MISP export verifies against the soc-ca" || ko "MISP export CA"
  [ "$(jq -r '[.enrolment[].caSecretRef | .namespace + "/" + .name + "/" + .key] | join(",")' <<<"$cfg")" = "wazuh-001/wazuh-manager-tls/ca.crt,wazuh-002/wazuh-manager-tls/ca.crt" ] \
    && ok "enrolment bundles carry the manager CA" || ko "enrolment CA: $(jq -c '.enrolment' <<<"$cfg")"
  [ "$(npq ConfigMap wazuh-dashboard-config '.data["opensearch_dashboards.yml"]' | yq '.["opensearch.ssl.verificationMode"]')" = "full" ] \
    && ok "central dashboard verifies the indexer" || ko "dashboard verificationMode"
else
  ko "renders with every workload"; cat "$TMP/err"
fi
if render "${NP[@]}" --set tls.insecureSkipVerify=true >"$TMP/insecure.yaml"; then
  [ "$(yq -N 'select(.kind == "ConfigMap" and .metadata.name == "siem-tenants") | .data["tenants.json"]' "$TMP/insecure.yaml" | jq -r '[.components.wazuh[].insecureSkipVerify, .components.wazuhCentral.insecureSkipVerify] | unique | map(tostring) | join(",")')" = "true" ] \
    && ok "tls.insecureSkipVerify is an explicit opt-out" || ko "tls.insecureSkipVerify"
else
  ko "renders with tls.insecureSkipVerify"; cat "$TMP/err"
fi
if render "${NP[@]}" --set networkPolicies.cilium=false --set-json 'networkPolicies.kubeApiServer.to=[{"ipBlock":{"cidr":"192.0.2.1/32"}}]' >"$TMP/nocilium.yaml"; then
  [ "$(yq -N 'select(.kind == "CiliumNetworkPolicy" and .metadata.name == "secops-*") | .metadata.name' "$TMP/nocilium.yaml")" = "" ] \
    && ok "no CiliumNetworkPolicy of this chart without Cilium" || ko "Cilium policies with cilium=false"
  [ "$(yq -N 'select(.kind == "NetworkPolicy" and .metadata.name == "secops-reconciler-apiserver") | .spec.egress[0].to[0].ipBlock.cidr' "$TMP/nocilium.yaml")" = "192.0.2.1/32" ] \
    && ok "API server egress from kubeApiServer.to without Cilium" || ko "API server ipBlock"
else
  ko "renders without Cilium"; cat "$TMP/err"
fi
expect_failure "API server peers required without Cilium" "networkPolicies.kubeApiServer.to is required" "${NP[@]}" --set networkPolicies.cilium=false
if render "${NP[@]}" --set networkPolicies.enabled=false >"$TMP/nonp.yaml"; then
  [ "$(yq -N 'select(.metadata.name == "secops-*") | .metadata.name' "$TMP/nonp.yaml")" = "" ] \
    && ok "networkPolicies.enabled=false renders none" || ko "policies with networkPolicies.enabled=false"
else
  ko "renders with networkPolicies.enabled=false"; cat "$TMP/err"
fi
# --- retention and monitoring --------------------------------------------
[ "$(jq -c '.retention' <<<"$cfg")" = '{"centralDays":90,"policyId":"kubesoc-retention","warmAfterDays":0}' ] \
  && ok "retention settings in siem-tenants" || ko "retention: $(jq -c .retention <<<"$cfg")"
[ "$(jq -r '[.components.wazuh[] | .indexer.url + "@" + .indexer.credSecretRef.name] | join(",")' <<<"$cfg")" = "https://wazuh-indexer.wazuh-001.svc:9200@wazuh-indexer-cred,https://wazuh-indexer.wazuh-002.svc:9200@wazuh-indexer-cred" ] \
  && ok "each tenant indexer for retention and health" || ko "tenant indexers: $(jq -c '[.components.wazuh[].indexer]' <<<"$cfg")"
extra=$(jq -r '([.components.wazuh[].indexer | keys[]] | unique - ["url","credSecretRef","caFile","insecureSkipVerify"]), (.retention | keys - ["policyId","indexPatterns","warmAfterDays","centralDays","centralIndexPatterns"]) | .[]' <<<"$cfg")
[ -z "$extra" ] && ok "retention keeps to the reconciler schema" || ko "unknown retention fields: $extra"
if render -f "$SCRIPT_DIR/values-2-tenants.yaml" --set retention.enabled=false >"$TMP/noret.yaml"; then
  noret=$(yq 'select(.kind == "ConfigMap" and .metadata.name == "siem-tenants") | .data["tenants.json"]' "$TMP/noret.yaml")
  [ "$(jq -c '[.retention, .components.wazuh[0].indexer]' <<<"$noret")" = "[null,null]" ] \
    && ok "retention off: no policy, no indexer access" || ko "retention off: $(jq -c '[.retention, .components.wazuh[0].indexer]' <<<"$noret")"
else
  ko "renders without retention"; cat "$TMP/err"
fi
expect_failure "retentionDays is bounded" "retentionDays" -f "$SCRIPT_DIR/values-2-tenants.yaml" --set 'tenants[0].retentionDays=5000'
[ -z "$(yq -N 'select((.kind == "PrometheusRule" and .metadata.name == "security-operations") or (.kind == "ServiceMonitor" and .metadata.name == "siem-reconciler")) | .kind' "$R2")" ] \
  && ok "no monitoring objects by default" || ko "monitoring objects rendered by default"

MON=(-f "$SCRIPT_DIR/values-2-tenants.yaml" --set reconciler.enabled=true --set reconciler.image.tag=test
     --set reconciler.mode=deployment --set monitoring.serviceMonitor.enabled=true --set monitoring.prometheusRule.enabled=true)
if render "${MON[@]}" >"$TMP/mon.yaml"; then
  ok "renders the reconciler Deployment with monitoring"
  [ -z "$(yq -N 'select(.kind == "CronJob" and .metadata.name == "siem-reconciler") | .kind' "$TMP/mon.yaml")" ] \
    && ok "deployment mode replaces the CronJob" || ko "CronJob rendered in deployment mode"
  dep=$(yq -o=json -I=0 'select(.kind == "Deployment" and .metadata.name == "siem-reconciler") | .spec.template.spec' "$TMP/mon.yaml")
  [ "$(jq -r '.containers[0].args | join(" ")' <<<"$dep")" = "--config /etc/siem/tenants.json --dry-run=true --interval=5m --metrics-addr=:9090" ] \
    && ok "long-running reconciler args" || ko "deployment args: $(jq -c '.containers[0].args' <<<"$dep")"
  [ "$(jq -r '.restartPolicy + "," + .containers[0].ports[0].name + "," + .containers[0].livenessProbe.httpGet.path' <<<"$dep")" = "Always,metrics,/healthz" ] \
    && ok "deployment pod: restart, named metrics port, liveness" || ko "deployment pod: $dep"
  [ "$(yq -N 'select(.kind == "Service" and .metadata.name == "siem-reconciler-metrics") | .spec.ports[0].name + "," + .spec.selector["security-operations.kubeaid.io/reconciler-mode"]' "$TMP/mon.yaml")" = "metrics,deployment" ] \
    && ok "metrics Service selects the Deployment pod only" || ko "metrics Service"
  [ "$(yq -N 'select(.kind == "Job" and .metadata.name == "siem-reconciler-sync") | .spec.template.metadata.labels["security-operations.kubeaid.io/reconciler-mode"]' "$TMP/mon.yaml")" = "null" ] \
    && ok "hook Jobs are not behind the metrics Service" || ko "hook Job labels"
  [ "$(yq -N 'select(.kind == "ServiceMonitor" and .metadata.name == "siem-reconciler") | .spec.endpoints[0].port + "," + .spec.selector.matchLabels["app.kubernetes.io/name"]' "$TMP/mon.yaml")" = "metrics,siem-reconciler" ] \
    && ok "ServiceMonitor on the metrics port" || ko "ServiceMonitor"
  alerts=$(yq -N 'select(.kind == "PrometheusRule") | .spec.groups[].rules[].alert' "$TMP/mon.yaml" | sort -u | tr '\n' ' ')
  for a in KubeSocIndexerHealthRed KubeSocIndexerHealthYellow KubeSocIndexerDiskWarning KubeSocIndexerDiskCritical KubeSocIndexerVolumeWarning KubeSocIndexerVolumeCritical KubeSocReconcilerErrors \
           KubeSocReconcilerNoSuccessfulRun KubeSocWazuhEventsDropped KubeSocWazuhAgentsDisconnected KubeSocJobFailed KubeSocComponentDown KubeSocKeycloakDown; do
    grep -qw "$a" <<<"$alerts" || { ko "alert $a missing: $alerts"; continue; }
  done
  ok "PrometheusRule alerts"
  if command -v promtool >/dev/null 2>&1; then
    yq 'select(.kind == "PrometheusRule") | .spec' "$TMP/mon.yaml" >"$TMP/rules.yaml"
    promtool check rules "$TMP/rules.yaml" >"$TMP/promtool" 2>&1 && ok "promtool check rules" || { ko "promtool check rules"; cat "$TMP/promtool"; }
  fi
  [ -z "$(yq -N 'select(.kind == "PrometheusRule") | .spec.groups[].rules[] | select(.labels.alert_id != .alert or .labels.severity == null) | .alert' "$TMP/mon.yaml")" ] \
    && ok "every alert has alert_id and severity" || ko "alert labels"
  grep -q 'namespace=~\\"security-operations|wazuh-.+\\"' <(yq -o=json 'select(.kind == "PrometheusRule")' "$TMP/mon.yaml") \
    && ok "workload alerts cover the release and tenant namespaces" || ko "namespace regex"
else
  ko "renders the reconciler Deployment with monitoring"; cat "$TMP/err"
fi
if render "${MON[@]}" --set reconciler.mode=cronjob --set misp.wazuhCdbExport.enabled=true --set dfir-iris.aiTriage.enabled=true \
     --set-json 'misp.wazuhCdbExport.targets=[{"name":"001","url":"https://w1","credentialsSecret":"c1"},{"name":"002","url":"https://w2","credentialsSecret":"c2"}]' >"$TMP/mon2.yaml"; then
  [ -z "$(yq -N 'select(.kind == "ServiceMonitor" and .metadata.name == "siem-reconciler") | .kind' "$TMP/mon2.yaml")" ] && ok "no ServiceMonitor for the CronJob" || ko "ServiceMonitor in cronjob mode"
  cj=$(yq -N 'select(.kind == "PrometheusRule") | .spec.groups[] | select(.name == "kubesoc-cronjobs") | .rules[].alert' "$TMP/mon2.yaml" | tr '\n' ' ')
  [ "$cj" = "KubeSocDfirIrisAiTriageFailing KubeSocDfirIrisAiTriageStale KubeSocMispWazuhCdbExportFailing KubeSocMispWazuhCdbExportStale KubeSocSiemReconcilerFailing KubeSocSiemReconcilerStale " ] \
    && ok "CronJob failing/stale alerts (MISP export, AI triage, reconciler)" || ko "cronjob alerts: $cj"
  [ -z "$(yq -N 'select(.kind == "PrometheusRule") | .spec.groups[].rules[] | select(.alert == "KubeSocReconcilerNoSuccessfulRun") | .alert' "$TMP/mon2.yaml")" ] \
    && ok "cronjob mode watches the CronJob, not the metrics" || ko "metric staleness alert in cronjob mode"
else
  ko "renders monitoring in cronjob mode"; cat "$TMP/err"
fi
if render "${MON[@]}" --set monitoring.prometheusRule.namespace=monitoring >"$TMP/mon3.yaml"; then
  [ "$(yq -N 'select(.kind == "PrometheusRule") | .metadata.namespace' "$TMP/mon3.yaml")" = "monitoring" ] \
    && ok "PrometheusRule namespace override" || ko "rule namespace"
else
  ko "renders the rule in another namespace"; cat "$TMP/err"
fi

echo
echo "==================================="
echo "PASS: $pass  FAIL: $fail"
[ "$fail" -eq 0 ]
