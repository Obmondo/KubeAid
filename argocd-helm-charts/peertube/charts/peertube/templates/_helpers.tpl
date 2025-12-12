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


{{- define "peertube.valkey.fullname" -}}
{{- printf "%s-%s" .Release.Name "valkey" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peertube.postgresql.fullname" -}}
{{- printf "%s-%s" .Release.Name "postgresql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "peertube.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
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
Get the valkey secret name
*/}}
{{- define "peertube.valkey.secretName" -}}
{{- if .Values.valkey.auth.existingSecret }}
    {{- printf "%s" (tpl .Values.valkey.auth.existingSecret $) -}}
{{- else if .Values.externalValkey.existingSecret }}
    {{- printf "%s" (tpl .Values.externalValkey.existingSecret $) -}}
{{- else -}}
    {{- printf "%s-valkey" (tpl .Release.Name $) -}}
{{- end -}}
{{- end -}}

{{/*
Get the postgresql secret.
*/}}
{{- define "peertube.postgresql.secretName" -}}
{{- if (and (or .Values.postgresql.enabled .Values.postgresql.postgresqlHostname) .Values.postgresql.auth.existingSecret) }}
    {{- printf "%s" (tpl .Values.postgresql.auth.existingSecret $) -}}
{{- else if and .Values.postgresql.enabled (not .Values.postgresql.auth.existingSecret) -}}
    {{- printf "%s-postgresql" (tpl .Release.Name $) -}}
{{- else if and .Values.externalDatabase.enabled .Values.externalDatabase.existingSecret -}}
    {{- printf "%s" (tpl .Values.externalDatabase.existingSecret $) -}}
{{- else -}}
    {{- printf "%s" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}
