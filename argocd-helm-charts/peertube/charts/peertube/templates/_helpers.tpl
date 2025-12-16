{{/*
Expand the name of the chart.
*/}}
{{- define "peertube.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "peertube.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "peertube.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Build a valid peertube image tag
*/}}
{{- define "peertube.imageTag" -}}
{{- if .Values.image.tag }}
{{- .Values.image.tag }}
{{- else }}
{{-   if semverCompare ">=8.0.0" .Chart.AppVersion }}
{{- printf "v%s" .Chart.AppVersion }}
{{-   else if semverCompare ">=6.0.0" .Chart.AppVersion }}
{{- printf "v%s-bookworm" .Chart.AppVersion }}
{{-   else }}
{{- printf "v%s-bullseye" .Chart.AppVersion }}
{{-   end}}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "peertube.labels" -}}
helm.sh/chart: {{ include "peertube.chart" . }}
{{ include "peertube.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "peertube.selectorLabels" -}}
app.kubernetes.io/name: {{ include "peertube.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "peertube.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "peertube.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
include "peertube.randHex" 2  > result "4e"
*/}}
{{- define "peertube.randHex" -}}
    {{- $result := "" -}}
    {{- range $i := until . -}}
        {{- $base := shuffle "0123456789abcdef" -}}
        {{- $i_curr := (randNumeric 1) | int -}}
        {{- $i_next := add $i_curr 1 | int -}}
        {{- $rand_hex := substr $i_curr $i_next $base -}}
        {{- $result = print $result $rand_hex -}}
    {{- end -}}
    {{- $result -}}
{{- end -}}


{{/*
Replicate the Postgres fullname
*/}}
{{- define "peertube.postgresql.fullname" -}}
{{- printf "%s-%s" .Release.Name "postgresql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get the postgres hostname
*/}}
{{- define "peertube.postgresql.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- template "peertube.postgresql.fullname" . -}}
{{- else -}}
{{ required "A valid externalPostgresql.host is required" .Values.externalPostgresql.host }}
{{- end -}}
{{- end -}}

{{/*
Get the postgres port
*/}}
{{- define "peertube.postgresql.port" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.port | default 5432 }}
{{- else -}}
{{- .Values.externalPostgresql.port | default 5432 }}
{{- end -}}
{{- end -}}

{{/*
Get the postgres SSL capability
*/}}
{{- define "peertube.postgresql.ssl" -}}
{{- if .Values.postgresql.enabled -}}
{{- true }}
{{- else -}}
{{- .Values.externalPostgresql.ssl | default true }}
{{- end -}}
{{- end -}}

{{/*
Get the postgres database
*/}}
{{- define "peertube.postgresql.database" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.database | default "peertube" }}
{{- else -}}
{{- .Values.externalPostgresql.database | default "peertube" }}
{{- end -}}
{{- end -}}

{{/*
Get the postgres username
*/}}
{{- define "peertube.postgresql.username" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username | default "peertube" }}
{{- else -}}
{{- .Values.externalPostgresql.username | default "peertube" }}
{{- end -}}
{{- end -}}

{{/*
Replicate the Redis fullname
*/}}
{{- define "peertube.redis.fullname" -}}
{{- printf "%s-%s" .Release.Name "redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get the redis hostname
*/}}
{{- define "peertube.redis.host" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-%s" (include "peertube.redis.fullname" .) "master" | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{ required "A valid externalRedis.host is required" .Values.externalRedis.host }}
{{- end -}}
{{- end -}}

{{/*
Get the redis port
*/}}
{{- define "peertube.redis.port" -}}
{{- if .Values.redis.enabled -}}
{{- .Values.redis.master.port | default 6379 }}
{{- else -}}
{{- .Values.externalRedis.port | default 6379 }}
{{- end -}}
{{- end -}}
