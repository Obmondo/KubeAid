{{/*
  Helpers that turn .Values.tenants into per-component configuration. The
  component charts are subcharts, and a parent cannot compute a subchart's
  values, so everything tenant-shaped is rendered by this chart as ConfigMaps
  the components mount (see tenants-configmaps.yaml and values.yaml).
*/}}

{{/* Validated tenant list with defaults filled in, as JSON: [{code,name,group,namespace,host,retentionDays,idp,agentPorts}]. */}}
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
{{- $tw := $.Values.tenantWazuh -}}
{{- $namespace := printf "%s%s" $tw.namespacePrefix $code -}}
{{- if gt (len $namespace) 63 -}}{{- fail (printf "tenant %s: namespace %q is longer than 63 characters" $code $namespace) -}}{{- end -}}
{{- $entry := dict "code" $code "name" $name "group" (printf "%s%s" $.Values.tenantGroupPrefix $code) "namespace" $namespace "host" (printf "%s%s.%s" $tw.hostPrefix $code $.Values.domain) "retentionDays" (int ($t.retentionDays | default $.Values.defaultRetentionDays)) -}}
{{- if $t.idp -}}{{- $_ := set $entry "idp" $t.idp -}}{{- end -}}
{{- if $t.agentPorts -}}{{- $_ := set $entry "agentPorts" $t.agentPorts -}}{{- end -}}
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
{{- /* Wazuh dashboards: the central search here, then one per tenant namespace. */ -}}
{{- $dash := list -}}
{{- if .Values.wazuh.enabled -}}
{{- $dash = append $dash (dict "id" "wazuh-dashboard" "name" "Wazuh dashboard" "host" (include "secops.host" (dict "root" . "c" "wazuh")) "namespace" $ns) -}}
{{- end -}}
{{- range include "secops.tenants" . | fromJsonArray -}}
{{- $dash = append $dash (dict "id" (printf "wazuh-dashboard-%s" .code) "name" (printf "Wazuh dashboard %s" .name) "host" .host "namespace" .namespace) -}}
{{- end -}}
{{- range $dash -}}
{{- $u := printf "https://%s" .host -}}
{{- $c = append $c (dict "clientId" .id "name" .name "standardFlowEnabled" true "rootUrl" $u "baseUrl" "/app/wz-home" "redirectUris" (list (printf "%s/auth/openid/login" $u)) "webOrigins" (list $u) "postLogoutRedirectUris" (list (printf "%s/*" $u) $u) "defaultClientScopes" (list "web-origins" "acr" "profile" "roles" "basic" "email") "protocolMappers" (list (dict "name" "realm roles (flat)" "protocolMapper" "oidc-usermodel-realm-role-mapper" "config" $flat) (dict "name" "groups" "protocolMapper" "oidc-group-membership-mapper" "config" $groups)) "secretRef" (dict "namespace" .namespace "name" "wazuh-dashboard-oidc" "key" "OPENSEARCH_OIDC_CLIENT_SECRET")) -}}
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
{{- $id := .clientId -}}
{{- with .secretRef -}}
{{- $keys := list (dict "key" .key) -}}
{{- if eq .name "wazuh-dashboard-oidc" -}}
{{- /* The Wazuh chart reads the client id from the same Secret. */ -}}
{{- $keys = list (dict "key" "OPENSEARCH_OIDC_CLIENT_ID" "value" $id) (dict "key" .key) (dict "key" "OPENSEARCH_COOKIE_PASSWORD") -}}
{{- end -}}
{{- $out = append $out (dict "namespace" .namespace "name" .name "keys" $keys) -}}
{{- end -}}
{{- end -}}
{{- if .root.Values.wazuh.enabled -}}
{{- /* The central dashboard mounts the API Secret although no manager runs here. */ -}}
{{- $out = append $out (dict "namespace" .root.Release.Namespace "name" "wazuh-api-cred" "keys" (list (dict "key" "API_USERNAME" "value" "wazuh-wui") (dict "key" "API_PASSWORD"))) -}}
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
{{- $sa := dict "login" .Values.ai.irisLogin "groups" .Values.ai.irisGroups "create" true -}}
{{- with .Values.ai.irisKeySecret -}}
{{- $_ := set $sa "apiKeySecretRef" (dict "namespace" $ns "name" . "key" "IRIS_API_KEY") -}}
{{- end -}}
{{- $_ := set $iris "serviceAccounts" (list $sa) -}}
{{- end -}}
{{- $_ := set $c "iris" $iris -}}
{{- end -}}
{{- $tw := .Values.tenantWazuh -}}
{{- $tenants := include "secops.tenants" . | fromJsonArray -}}
{{- if $tenants -}}
{{- $w := list -}}
{{- range $tenants -}}
{{- $w = append $w (dict "tenant" .code "url" (printf "https://%s.%s.svc:55000" $tw.managerService .namespace) "credSecretRef" (dict "namespace" .namespace "name" $tw.apiCredSecret "usernameKey" "API_USERNAME" "passwordKey" "API_PASSWORD") "insecureSkipVerify" true) -}}
{{- end -}}
{{- $_ := set $c "wazuh" $w -}}
{{- end -}}
{{- if .Values.wazuh.enabled -}}
{{- $remotes := list -}}
{{- range $tenants -}}
{{- $remotes = append $remotes (dict "alias" .code "seeds" (list (printf "%s.%s.svc:9300" $tw.indexerNodesService .namespace))) -}}
{{- end -}}
{{- $idx := (.Values.wazuh.wazuh.indexer | default dict) -}}
{{- $credSecret := ((($idx.cred | default dict).existingSecret) | default "indexer-cred") -}}
{{- $central := dict "url" "https://wazuh-indexer:9200" "credSecretRef" (dict "namespace" $ns "name" $credSecret "usernameKey" "INDEXER_USERNAME" "passwordKey" "INDEXER_PASSWORD") "insecureSkipVerify" true "remotes" $remotes "dashboardConfigSecret" (dict "namespace" $ns "name" "wazuh-app-config") -}}
{{- with .Values.centralSearch.indexPatterns -}}
{{- $_ := set $central "dashboardURL" "http://wazuh-dashboard:5601" -}}
{{- $_ := set $central "indexPatterns" . -}}
{{- end -}}
{{- $_ := set $c "wazuhCentral" $central -}}
{{- end -}}
{{- if .Values.velociraptor.enabled -}}
{{- $v := .Values.velociraptor.velociraptor | default dict -}}
{{- $ac := $v.apiClient | default dict -}}
{{- $velo := dict "apiClientSecretRef" (dict "namespace" $ns "name" ($ac.secretName | default "velociraptor-api-client") "key" ($ac.secretKey | default "api_client.yaml")) -}}
{{- if (($v.api | default dict).service | default dict).enabled -}}
{{- /* The api_client file names localhost; dial the API Service instead. */ -}}
{{- $_ := set $velo "address" (printf "%s-api:%v" ($v.fullnameOverride | default "velociraptor") ((($v.frontend | default dict).apiPort) | default 8001)) -}}
{{- end -}}
{{- with include "secops.velociraptorMonitoring" . | fromYamlArray -}}
{{- $_ := set $velo "serverMonitoring" . -}}
{{- end -}}
{{- $_ := set $c "velociraptor" $velo -}}
{{- end -}}
{{- range $k, $v := (.Values.reconciler.components | default dict) -}}
{{- if hasKey $c $k -}}{{- $_ := set $c $k (mergeOverwrite (get $c $k) $v) -}}{{- end -}}
{{- end -}}
{{- toYaml $c -}}
{{- end -}}

{{/*
  Enrolment bundles, as a YAML list: one per tenant with agentPorts, when
  tenantWazuh.agentHost is set. The reconciler writes Secret enrolment-bundle in
  the tenant namespace (manager address, ports, enrolment password, install
  one-liners).
*/}}
{{- define "secops.enrolment" -}}
{{- $tw := .Values.tenantWazuh -}}
{{- $out := list -}}
{{- if $tw.agentHost -}}
{{- range $t := include "secops.tenants" . | fromJsonArray -}}
{{- with $t.agentPorts -}}
{{- $out = append $out (dict "tenant" $t.code "namespace" $t.namespace "name" "enrolment-bundle" "managerHost" $tw.agentHost "registrationPort" (int .registration) "eventsPort" (int .events) "authdSecretRef" (dict "namespace" $t.namespace "name" $tw.authdSecret "key" "authd.pass") "agentVersion" $tw.agentVersion) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/*
  Secret copies between the central and the tenant namespaces, as a YAML list:
  the IRIS API key to every tenant manager (IRIS integration), and every tenant's
  Wazuh API login here for the MISP list export (wazuh-api-cred-<code>).
*/}}
{{- define "secops.secretCopies" -}}
{{- $ns := .Release.Namespace -}}
{{- $tw := .Values.tenantWazuh -}}
{{- $out := list -}}
{{- range $t := include "secops.tenants" . | fromJsonArray -}}
{{- if (index $.Values "dfir-iris").enabled -}}
{{- $out = append $out (dict "from" (dict "namespace" $ns "name" "iris-api-key" "key" "API_KEY") "to" (dict "namespace" $t.namespace "name" "iris-api-key" "key" "API_KEY")) -}}
{{- end -}}
{{- if $.Values.misp.enabled -}}
{{- range $k := list "API_USERNAME" "API_PASSWORD" -}}
{{- $out = append $out (dict "from" (dict "namespace" $t.namespace "name" $tw.apiCredSecret "key" $k) "to" (dict "namespace" $ns "name" (printf "wazuh-api-cred-%s" $t.code) "key" $k)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/*
  Velociraptor artifact files, as YAML: files/velociraptor/*.yaml by base name, with
  velociraptorArtifacts.extraFiles merged over (null drops a file).
*/}}
{{- define "secops.velociraptorArtifacts" -}}
{{- $out := dict -}}
{{- range $path, $_ := .Files.Glob "files/velociraptor/*.yaml" -}}
{{- $_ := set $out (base $path) ($.Files.Get $path) -}}
{{- end -}}
{{- range $k, $v := (.Values.velociraptorArtifacts.extraFiles | default dict) -}}
{{- if kindIs "invalid" $v -}}{{- $_ := unset $out $k -}}{{- else -}}{{- $_ := set $out $k (toString $v) -}}{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{/* sha256 of the Velociraptor artifact files (pod annotation checksum/server-artifacts). */}}
{{- define "secops.velociraptorArtifactsChecksum" -}}
{{- include "secops.velociraptorArtifacts" . | fromYaml | toJson | sha256sum -}}
{{- end -}}

{{/*
  Server monitoring entries for the reconciler, as a YAML list, from
  velociraptorArtifacts.monitoring: enabled entries (IrisCollector only with
  dfir-iris), parameters as strings, KeycloakSync's KcUrl/KcRealm from keycloak
  and its Protected users including the reconciler's API client.
*/}}
{{- define "secops.velociraptorMonitoring" -}}
{{- $out := list -}}
{{- $mon := .Values.velociraptorArtifacts.monitoring | default dict -}}
{{- range $name := keys $mon | sortAlpha -}}
{{- $m := index $mon $name | default dict -}}
{{- $skip := or (not $m.enabled) (and (eq $name "Custom.Server.IrisCollector") (not (index $.Values "dfir-iris").enabled)) -}}
{{- if not $skip -}}
{{- $p := dict -}}
{{- if eq $name "Custom.Server.KeycloakSync" -}}
{{- $_ := set $p "KcUrl" $.Values.keycloak.url -}}
{{- $_ := set $p "KcRealm" $.Values.keycloak.realm -}}
{{- /* The reconciler's own API user has no Keycloak user: never remove it. */ -}}
{{- $apiUser := ((($.Values.velociraptor.velociraptor | default dict).apiClient | default dict).name) | default "siem-reconciler" -}}
{{- $_ := set $p "Protected" (printf "^(admin|VelociraptorServer|svc_.*|%s)$" (regexQuoteMeta $apiUser)) -}}
{{- end -}}
{{- range $k, $v := ($m.parameters | default dict) -}}{{- $_ := set $p $k (toString $v) -}}{{- end -}}
{{- $out = append $out (dict "artifact" $name "parameters" $p) -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}
