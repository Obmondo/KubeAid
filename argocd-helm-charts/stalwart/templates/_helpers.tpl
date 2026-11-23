{{- define "stalwart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "stalwart.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains (include "stalwart.name" .) .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "stalwart.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "stalwart.labels" -}}
app.kubernetes.io/name: {{ include "stalwart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "stalwart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stalwart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "stalwart.redisName" -}}
{{- printf "%s-redis" (include "stalwart.fullname" .) -}}
{{- end -}}

{{- define "stalwart.redisUrl" -}}
{{- if .Values.redis.url -}}
{{- .Values.redis.url -}}
{{- else -}}
{{- printf "redis://%s:6379" (include "stalwart.redisName" .) -}}
{{- end -}}
{{- end -}}

{{- define "stalwart.dbHost" -}}
{{- .Values.database.host | default (printf "%s-pgsql-rw" .Values.global.postgresql.instanceName) -}}
{{- end -}}

{{- define "stalwart.dbSecret" -}}
{{- .Values.database.existingSecret | default (printf "%s-pgsql-app" .Values.global.postgresql.instanceName) -}}
{{- end -}}

{{/*
config.json: only the DataStore. The password comes from the CNPG app secret
through the STALWART_DB_PASSWORD environment variable.
*/}}
{{- define "stalwart.configJson" -}}
{{- $cfg := dict
  "@type" "PostgreSql"
  "host" (include "stalwart.dbHost" .)
  "port" (int .Values.database.port)
  "database" .Values.global.postgresql.database
  "authUsername" .Values.global.postgresql.owner
  "authSecret" (dict "@type" "EnvironmentVariable" "variableName" "STALWART_DB_PASSWORD")
-}}
{{- toPrettyJson $cfg -}}
{{- end -}}

{{/*
NDJSON plan applied by stalwart-cli. One operation per line, ordered so that
in-plan references (#id) are defined before use and the in-memory store is set
before the coordinator (the server refuses the reverse order).
*/}}
{{- define "stalwart.plan" -}}
{{- $ops := list -}}
{{- /* Logs to stdout so `kubectl logs` works (the default Log tracer writes to a missing dir). */ -}}
{{- $ops = append $ops (dict "@type" "upsert" "object" "Tracer" "matchOn" (list "@type") "value" (dict "tr-stdout" (dict "@type" "Stdout" "level" .Values.plan.logLevel "ansi" false) "tr-log" (dict "@type" "Log" "path" "/var/log/stalwart" "enable" false))) -}}
{{- /* Shared stores: required before replicaCount > 1. */ -}}
{{- $ops = append $ops (dict "@type" "update" "object" "InMemoryStore" "value" (dict "@type" "Redis" "url" (include "stalwart.redisUrl" .))) -}}
{{- $ops = append $ops (dict "@type" "update" "object" "Coordinator" "value" (dict "@type" "Default")) -}}
{{- if .Values.s3.enabled }}
{{- $s3 := dict
  "@type" "S3"
  "bucket" (required "s3.bucket is required" .Values.s3.bucket)
  "region" (dict "@type" "Custom" "url" (required "s3.endpoint is required" .Values.s3.endpoint) "region" .Values.s3.region)
  "accessKeyId" (dict "@type" "EnvironmentVariable" "variableName" "STALWART_S3_ACCESS_KEY")
  "secretKey" (dict "@type" "EnvironmentVariable" "variableName" "STALWART_S3_SECRET_KEY")
-}}
{{- with .Values.s3.keyPrefix }}{{- $_ := set $s3 "keyPrefix" . -}}{{- end }}
{{- $ops = append $ops (dict "@type" "update" "object" "BlobStore" "value" $s3) -}}
{{- else }}
{{- $ops = append $ops (dict "@type" "update" "object" "BlobStore" "value" (dict "@type" "Default")) -}}
{{- end }}
{{- $ops = append $ops (dict "@type" "update" "object" "SearchStore" "value" (dict "@type" "Default")) -}}
{{- /* Domains and server identity. */ -}}
{{- if .Values.domains }}
{{- $doms := dict -}}
{{- range $i, $d := .Values.domains }}{{- $_ := set $doms (printf "dom-%d" $i) (dict "name" $d) -}}{{- end }}
{{- $ops = append $ops (dict "@type" "upsert" "object" "Domain" "matchOn" (list "name") "value" $doms) -}}
{{- $ops = append $ops (dict "@type" "update" "object" "SystemSettings" "value" (dict "defaultHostname" .Values.hostname "defaultDomainId" "#dom-0")) -}}
{{- else }}
{{- $ops = append $ops (dict "@type" "update" "object" "SystemSettings" "value" (dict "defaultHostname" .Values.hostname)) -}}
{{- end }}
{{- /* TLS certificate read from the mounted cert-manager secret; matched by its file path. */ -}}
{{- if .Values.tls.enabled }}
{{- $ops = append $ops (dict "@type" "upsert" "object" "Certificate" "matchOn" (list "certificate") "value" (dict "cert-main" (dict "certificate" (dict "@type" "File" "filePath" "/etc/stalwart/tls/tls.crt") "privateKey" (dict "@type" "File" "filePath" "/etc/stalwart/tls/tls.key")))) -}}
{{- end }}
{{- /* Keycloak. The OAuthClient with the same id keeps Stalwart's own
       authorization server (recovery admin) working once the WebUI uses a
       static client id. */ -}}
{{- if .Values.oidc.enabled }}
{{- $cid := .Values.oidc.webuiClientId -}}
{{- $aud := dict $cid true -}}
{{- range .Values.oidc.acceptedAudiences }}{{- $_ := set $aud . true -}}{{- end }}
{{- $dir := dict
  "@type" "Oidc"
  "description" .Values.oidc.description
  "issuerUrl" (required "oidc.issuerUrl is required" .Values.oidc.issuerUrl)
  "claimUsername" .Values.oidc.claimUsername
  "acceptedAudiences" $aud
-}}
{{- with .Values.oidc.usernameDomain }}{{- $_ := set $dir "usernameDomain" . -}}{{- end }}
{{- with .Values.oidc.claimGroups }}{{- $_ := set $dir "claimGroups" . -}}{{- end }}
{{- if .Values.oidc.allowIdTokenClaims }}{{- $_ := set $dir "allowIdTokenClaims" true -}}{{- end }}
{{- $redirects := dict (printf "https://%s/admin/oauth/callback" .Values.hostname) true (printf "https://%s/account/oauth/callback" .Values.hostname) true -}}
{{- $ops = append $ops (dict "@type" "upsert" "object" "OAuthClient" "matchOn" (list "clientId") "value" (dict "oc-webui" (dict "clientId" $cid "description" "Stalwart WebUI" "redirectUris" $redirects "scopes" (dict "full" true)))) -}}
{{- $ops = append $ops (dict "@type" "upsert" "object" "Application" "matchOn" (list "description") "value" (dict "app-webui" (dict "description" "Stalwart Web Interface" "oauthClientId" $cid "oauthScopes" (dict "urn:stalwart:oauth:scope:full" true)))) -}}
{{- $ops = append $ops (dict "@type" "upsert" "object" "Directory" "matchOn" (list "description") "value" (dict "dir-oidc" $dir)) -}}
{{- $ops = append $ops (dict "@type" "update" "object" "Authentication" "value" (dict "directoryId" "#dir-oidc")) -}}
{{- end }}
{{- /* Built-in DNSBL servers to turn off; upsert by name keeps their zone and tag rules. */ -}}
{{- with .Values.spamFilter.disabledDnsbl }}
{{- $dnsbl := dict -}}
{{- range $i, $d := . }}{{- $_ := set $dnsbl (printf "dnsbl-%d" $i) (dict "@type" $d.type "name" $d.name "enable" false) -}}{{- end }}
{{- $ops = append $ops (dict "@type" "upsert" "object" "SpamDnsblServer" "matchOn" (list "name") "value" $dnsbl) -}}
{{- end }}
{{- range .Values.plan.extra }}{{- $ops = append $ops . -}}{{- end }}
{{- range $ops }}
{{ toJson . }}
{{- end }}
{{- end -}}
