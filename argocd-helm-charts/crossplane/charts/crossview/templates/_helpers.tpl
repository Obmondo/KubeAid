{{/*
Expand the name of the chart.
*/}}
{{- define "crossview.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "crossview.fullname" -}}
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
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "crossview.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "crossview.labels" -}}
helm.sh/chart: {{ include "crossview.chart" . }}
{{ include "crossview.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "crossview.selectorLabels" -}}
app.kubernetes.io/name: {{ include "crossview.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Get namespace - prefers Release.Namespace → global.namespace → "default"
*/}}
{{- define "crossview.namespace" -}}
{{- if .Release.Namespace }}
  {{- .Release.Namespace }}
{{- else if .Values.global.namespace }}
  {{- .Values.global.namespace }}
{{- else }}
  {{- "default" }}
{{- end }}
{{- end -}}

{{/*
Get ConfigMap name - uses existing ref if set, otherwise generates standard name
*/}}
{{- define "crossview.configMapName" -}}
{{- if .Values.config.ref }}
  {{- .Values.config.ref }}
{{- else }}
  {{- printf "%s-config" (include "crossview.fullname" .) }}
{{- end }}
{{- end -}}

{{/*
Generate valueFrom block for secrets or configmaps.
Supports:
- plain string → references chart-created secret
- map with secretKeyRef → direct external secret reference
- map with configMapKeyRef → direct configmap reference

Params:
  .secret     = value from .Values.secrets.xxx (string or map)
  .secretName = name of the chart-managed secret (when using string)
  .secretKey  = key inside the chart-managed secret (when using string)
*/}}
{{- define "crossview.secretValueFrom" -}}
{{- $secret := .secret -}}
{{- $secretName := .secretName | required ".secretName is required" -}}
{{- $secretKey := .secretKey | required ".secretKey is required" -}}

{{- if kindIs "map" $secret }}
  {{- if hasKey $secret "secretKeyRef" }}
valueFrom:
  secretKeyRef:
    name: {{ $secret.secretKeyRef.name | quote }}
    key:  {{ $secret.secretKeyRef.key | quote }}
  {{- else if hasKey $secret "configMapKeyRef" }}
valueFrom:
  configMapKeyRef:
    name: {{ $secret.configMapKeyRef.name | quote }}
    key:  {{ $secret.configMapKeyRef.key | quote }}
  {{- end -}}
{{- else if and $secret (kindIs "string" $secret) (ne $secret "") }}
valueFrom:
  secretKeyRef:
    name: {{ $secretName | quote }}
    key:  {{ $secretKey | quote }}
{{- end -}}
{{- end -}}