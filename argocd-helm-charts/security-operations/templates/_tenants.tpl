{{/*
  Helpers that turn .Values.tenants into per-component configuration. The
  component charts are subcharts, and a parent cannot compute a subchart's
  values, so everything tenant-shaped is rendered by this chart as ConfigMaps
  the components mount (see tenants-configmaps.yaml and values.yaml).
*/}}

{{/* Validated tenant list with defaults filled in, as JSON: [{code,name,group,retentionDays,idp}]. */}}
{{- define "secops.tenants" -}}
{{- $out := list -}}
{{- $codes := dict -}}
{{- $names := dict -}}
{{- range $i, $t := .Values.tenants -}}
{{- $code := toString (required (printf "tenants[%d].code is required" $i) $t.code) -}}
{{- if not (regexMatch "^[a-z0-9]{1,32}$" $code) -}}
{{- fail (printf "tenants[%d].code %q must match ^[a-z0-9]{1,32}$" $i $code) -}}
{{- end -}}
{{- $name := required (printf "tenants[%d].name is required" $i) $t.name -}}
{{- if hasKey $codes $code -}}{{- fail (printf "tenant code %q is listed twice" $code) -}}{{- end -}}
{{- if hasKey $names $name -}}{{- fail (printf "tenant name %q is listed twice" $name) -}}{{- end -}}
{{- $_ := set $codes $code true -}}
{{- $_ := set $names $name true -}}
{{- $entry := dict "code" $code "name" $name "group" (printf "%s%s" $.Values.tenantGroupPrefix $code) "retentionDays" (int ($t.retentionDays | default $.Values.defaultRetentionDays)) -}}
{{- if $t.idp -}}{{- $_ := set $entry "idp" $t.idp -}}{{- end -}}
{{- $out = append $out $entry -}}
{{- end -}}
{{- toJson $out -}}
{{- end -}}

{{/* Public hostname of a component: (dict "root" $ "c" "wazuh"). */}}
{{- define "secops.host" -}}
{{- $h := index .root.Values.hosts .c -}}
{{- if $h -}}{{ $h }}{{- else -}}{{ printf "%s.%s" .c .root.Values.domain }}{{- end -}}
{{- end -}}

{{/* Common labels for objects this chart renders itself. */}}
{{- define "secops.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: security-operations
{{- end -}}

{{/*
  OIDC clients the reconciler keeps in the realm, as a YAML list:
  keycloak.clients when set, else one per enabled component plus the
  read-only iris-sync client of the IRIS and Velociraptor Keycloak syncs.
  secretRef names follow the component charts' defaults.
*/}}
{{- define "secops.clients" -}}
{{- if .Values.keycloak.clients -}}
{{- toYaml .Values.keycloak.clients -}}
{{- else -}}
{{- $ns := .Release.Namespace -}}
{{- $flat := dict "claim.name" "roles" "multivalued" "true" "jsonType.label" "String" "id.token.claim" "true" "access.token.claim" "true" "userinfo.token.claim" "true" "introspection.token.claim" "true" -}}
{{- $groups := dict "claim.name" "groups" "full.path" "false" "id.token.claim" "true" "access.token.claim" "true" "userinfo.token.claim" "true" "introspection.token.claim" "true" -}}
{{- $c := list -}}
{{- if .Values.wazuh.enabled -}}
{{- $u := printf "https://%s" (include "secops.host" (dict "root" . "c" "wazuh")) -}}
{{- $c = append $c (dict "clientId" "wazuh-dashboard" "name" "Wazuh dashboard" "standardFlowEnabled" true "rootUrl" $u "baseUrl" "/app/wz-home" "redirectUris" (list (printf "%s/auth/openid/login" $u)) "webOrigins" (list $u) "postLogoutRedirectUris" (list (printf "%s/*" $u) $u) "defaultClientScopes" (list "web-origins" "acr" "profile" "roles" "basic" "email") "protocolMappers" (list (dict "name" "realm roles (flat)" "protocolMapper" "oidc-usermodel-realm-role-mapper" "config" $flat) (dict "name" "groups" "protocolMapper" "oidc-group-membership-mapper" "config" $groups)) "secretRef" (dict "namespace" $ns "name" "wazuh-dashboard-oidc" "key" "OPENSEARCH_OIDC_CLIENT_SECRET")) -}}
{{- end -}}
{{- if .Values.velociraptor.enabled -}}
{{- $u := printf "https://%s" (include "secops.host" (dict "root" . "c" "velociraptor")) -}}
{{- $c = append $c (dict "clientId" "velociraptor" "name" "velociraptor" "standardFlowEnabled" true "redirectUris" (list (printf "%s/auth/oidc/keycloak/callback" $u)) "defaultClientScopes" (list "profile") "protocolMappers" (list (dict "name" "groups" "protocolMapper" "oidc-group-membership-mapper" "config" $groups)) "secretRef" (dict "namespace" $ns "name" "velociraptor-oidc" "key" "oauth_client_secret")) -}}
{{- end -}}
{{- if (index .Values "dfir-iris").enabled -}}
{{- $u := printf "https://%s" (include "secops.host" (dict "root" . "c" "iris")) -}}
{{- $c = append $c (dict "clientId" "iris" "name" "iris" "standardFlowEnabled" true "redirectUris" (list (printf "%s/oidc-authorize" $u)) "postLogoutRedirectUris" (list (printf "%s/login" $u)) "secretRef" (dict "namespace" $ns "name" "dfir-iris-oidc" "key" "OIDC_CLIENT_SECRET")) -}}
{{- end -}}
{{- if .Values.misp.enabled -}}
{{- $u := printf "https://%s" (include "secops.host" (dict "root" . "c" "misp")) -}}
{{- $c = append $c (dict "clientId" "misp" "name" "misp" "standardFlowEnabled" true "redirectUris" (list (printf "%s/users/login" $u)) "webOrigins" (list $u) "postLogoutRedirectUris" (list (printf "%s/users/login" $u)) "defaultClientScopes" (list "email") "protocolMappers" (list (dict "name" "realm roles" "protocolMapper" "oidc-usermodel-realm-role-mapper" "config" $flat)) "secretRef" (dict "namespace" $ns "name" "oidc-credentials" "key" "password")) -}}
{{- end -}}
{{- if or (index .Values "dfir-iris").enabled .Values.velociraptor.enabled -}}
{{- $c = append $c (dict "clientId" "iris-sync" "name" "DFIR-IRIS access sync" "description" "Read-only service account for the IRIS and Velociraptor Keycloak syncs" "serviceAccountsEnabled" true "fullScopeAllowed" false "serviceAccountClientRoles" (dict "realm-management" (list "view-users")) "scopeMappings" (dict "clients" (dict "realm-management" (list "view-users" "query-users" "query-groups"))) "secretRef" (dict "namespace" $ns "name" "iris-keycloak-sync" "key" "KEYCLOAK_CLIENT_SECRET")) -}}
{{- end -}}
{{- toYaml $c -}}
{{- end -}}
{{- end -}}

{{/*
  Secrets the reconciler creates with random values when missing, as a YAML
  list: reconciler.secrets when set, else one per client secretRef (plus the
  dashboard's cookie password next to the Wazuh client secret).
  (dict "root" $ "clients" <list>)
*/}}
{{- define "secops.secrets" -}}
{{- if .root.Values.reconciler.secrets -}}
{{- toYaml .root.Values.reconciler.secrets -}}
{{- else -}}
{{- $out := list -}}
{{- range .clients -}}
{{- with .secretRef -}}
{{- $keys := list (dict "key" .key) -}}
{{- if eq .name "wazuh-dashboard-oidc" -}}{{- $keys = append $keys (dict "key" "OPENSEARCH_COOKIE_PASSWORD") -}}{{- end -}}
{{- $out = append $out (dict "namespace" .namespace "name" .name "keys" $keys) -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}
{{- end -}}

{{/*
  Component APIs for the reconciler, as YAML: same-namespace URLs and the
  Secrets the component charts use, with reconciler.components merged over.
*/}}
{{- define "secops.components" -}}
{{- $ns := .Release.Namespace -}}
{{- $c := dict -}}
{{- if (index .Values "dfir-iris").enabled -}}
{{- $iris := dict "url" "http://dfir-iris-app:8000" "apiKeySecretRef" (dict "namespace" $ns "name" "iris-keycloak-sync" "key" "IRIS_API_KEY") -}}
{{- if .Values.ai.irisLogin -}}
{{- $_ := set $iris "serviceAccounts" (list (dict "login" .Values.ai.irisLogin "groups" .Values.ai.irisGroups)) -}}
{{- end -}}
{{- $_ := set $c "iris" $iris -}}
{{- end -}}
{{- if .Values.wazuh.enabled -}}
{{- $_ := set $c "wazuh" (dict "url" "https://wazuh:55000" "credSecretRef" (dict "namespace" $ns "name" "wazuh-api-cred" "usernameKey" "API_USERNAME" "passwordKey" "API_PASSWORD") "insecureSkipVerify" true "createGroups" true) -}}
{{- end -}}
{{- if .Values.velociraptor.enabled -}}
{{- $_ := set $c "velociraptor" (dict "apiClientSecretRef" (dict "namespace" $ns "name" "velociraptor-api-client" "key" "api_client.yaml")) -}}
{{- end -}}
{{- range $k, $v := (.Values.reconciler.components | default dict) -}}
{{- if hasKey $c $k -}}{{- $_ := set $c $k (mergeOverwrite (get $c $k) $v) -}}{{- end -}}
{{- end -}}
{{- toYaml $c -}}
{{- end -}}
