{{/*
Expand the name of the chart.
*/}}
{{- define "vuls-dictionary.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vuls-dictionary.fullname" -}}
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
{{- define "vuls-dictionary.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "vuls-dictionary.labels" -}}
helm.sh/chart: {{ include "vuls-dictionary.chart" . }}
{{ include "vuls-dictionary.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "vuls-dictionary.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vuls-dictionary.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "vuls-dictionary.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vuls-dictionary.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Define a helper function to sanitize names and convert floats to strings */}}
{{- define "vuls-dictionary.sanitizeName" -}}
{{- $input := . -}}
{{- $name := $input | replace "." "-" -}}
{{- $name | replace " " "-" -}}  {{/* Optional: Replace spaces with dashes as well */}}
{{- end -}}

{{/*
Name of the Traefik InFlightReq middleware in front of the Vuls server.
*/}}
{{- define "vuls-dictionary.inFlightReqMiddlewareName" -}}
{{- printf "%s-vuls-inflight" (include "vuls-dictionary.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
