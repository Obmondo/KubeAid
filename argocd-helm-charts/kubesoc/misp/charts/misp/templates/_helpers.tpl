{{/*
Expand the name of the chart.
*/}}
{{- define "misp-charts.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "misp-charts.fullname" -}}
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
{{- define "misp-charts.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "misp-charts.labels" -}}
helm.sh/chart: {{ include "misp-charts.chart" . }}
{{ include "misp-charts.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "misp-charts.selectorLabels" -}}
app.kubernetes.io/name: {{ include "misp-charts.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "misp-charts.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "misp-charts.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Returns the misp-core container image
*/}}
{{- define "misp-charts.misp.misp.image" -}}
{{- include "common.image" (dict "image" (dict "registry" .Values.misp.misp.image.registry "repository" .Values.misp.misp.image.repository "tag" (.Values.misp.misp.image.tag | default .Chart.AppVersion)) "global" .Values.global) }}
{{- end -}}

{{/*
Returns the misp-modules container image
*/}}
{{- define "misp-charts.modules.mispModules.image" -}}
{{- include "common.image" (dict "image" (dict "registry" .Values.modules.mispModules.image.registry "repository" .Values.modules.mispModules.image.repository "tag" (.Values.modules.mispModules.image.tag | default .Chart.AppVersion)) "global" .Values.global) }}
{{- end -}}

{{/*
The common image function that renders the container image
*/}}
{{- define "common.image" -}}
{{- $registryName := .image.registry }}
{{- $repositoryName := .image.repository }}
{{- $tag := .image.tag }}
{{- if .global }}
  {{- if .global.imageRegistry }}
    {{- $registryName = .global.imageRegistry }}
  {{- end }}
{{- end }}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag }}
{{- else }}
{{- printf "%s:%s" $repositoryName $tag }}
{{ end }}
{{- end -}}

{{/*
Returns the misp-core image pull secrets
*/}}
{{- define "misp-charts.misp.misp.image.imagePullSecrets" -}}
{{- $pullSecrets := list }}
{{- if .Values.global }}
  {{- range .Values.global.imagePullSecrets -}}
    {{- $pullSecrets = append $pullSecrets . -}}
  {{- end -}}
{{- end -}}
{{- range .Values.misp.misp.image.imagePullSecrets -}}
    {{- $pullSecrets = append $pullSecrets . -}}
{{- end -}}
{{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
{{- range $pullSecrets }}
- name: {{ . }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Returns the misp-modules image pull secrets
*/}}
{{- define "misp-charts.modules.mispModules.image.imagePullSecrets" -}}
{{- $pullSecrets := list }}
{{- if .Values.global }}
  {{- range .Values.global.imagePullSecrets -}}
    {{- $pullSecrets = append $pullSecrets . -}}
  {{- end -}}
{{- end -}}
{{- range .Values.modules.mispModules.image.imagePullSecrets -}}
    {{- $pullSecrets = append $pullSecrets . -}}
{{- end -}}
{{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
{{- range $pullSecrets }}
- name: {{ . }}
{{- end }}
{{- end }}
{{- end -}}