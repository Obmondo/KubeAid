{{/*
Expand the name of the chart.
*/}}
{{- define "openobserve.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openobserve.fullname" -}}
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
{{- define "openobserve.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openobserve.labels" -}}
helm.sh/chart: {{ include "openobserve.chart" . }}
{{ include "openobserve.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}

{{- $custom := .Values.labels | default dict -}}
{{- range $key, $value := $custom }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openobserve.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openobserve.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Merge multiple env var lists, with each later list taking precedence over earlier ones.
Usage: include "openobserve.mergeEnv" (list .Values.extraEnv .Values.someComponent.extraEnv)
       include "openobserve.mergeEnv" (list $defaults .Values.extraEnv .Values.someComponent.extraEnv)
*/}}
{{- define "openobserve.mergeEnv" -}}
{{- $merged := list -}}
{{- range . -}}
{{- $override := . | default list -}}
{{- $overrideNames := list -}}
{{- range $override -}}
{{- $overrideNames = append $overrideNames .name -}}
{{- end -}}
{{- $filtered := list -}}
{{- range $merged -}}
{{- if not (has .name $overrideNames) -}}
{{- $filtered = append $filtered . -}}
{{- end -}}
{{- end -}}
{{- $merged = concat $filtered $override -}}
{{- end -}}
{{- if $merged -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end -}}

{{/*
Kubernetes metadata environment variables using the Downward API.
Injects node name, namespace, pod name, and optionally cluster name into containers.
Usage: {{- include "openobserve.k8sMetaEnv" . | nindent 12 }}
*/}}
{{- define "openobserve.k8sMetaEnv" -}}
- name: K8S_NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: K8S_NAMESPACE_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: K8S_POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: K8S_POD_ID
  valueFrom:
    fieldRef:
      fieldPath: metadata.uid
- name: K8S_CONTAINER_IMAGE
  value: {{ if .Values.enterprise.enabled }}"{{ .Values.image.enterprise.repository }}:{{ .Values.image.enterprise.tag | default .Chart.AppVersion }}"{{ else }}"{{ .Values.image.oss.repository }}:{{ .Values.image.oss.tag | default .Chart.AppVersion }}"{{ end }}
{{- if .Values.clusterName }}
- name: K8S_CLUSTER
  value: {{ .Values.clusterName | quote }}
- name: K8S_CLUSTER_NAME
  value: {{ .Values.clusterName | quote }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openobserve.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openobserve.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the dedicated Secret that holds ZO_REPORT_SERVER_SECRET.
*/}}
{{- define "openobserve.reportServerSecretName" -}}
{{- printf "%s-report-server" (include "openobserve.fullname" . | trunc 49 | trimSuffix "-") }}
{{- end }}

{{/*
Effective ZO_REPORT_SERVER_SECRET: the user's value, else the one in the existing dedicated Secret, else a new random one.
*/}}
{{- define "openobserve.reportServerSecret" -}}
{{- if not .Values.auth.ZO_REPORT_SERVER_SECRET -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "openobserve.reportServerSecretName" .) | default dict -}}
{{- $stored := dig "data" "ZO_REPORT_SERVER_SECRET" "" $existing | b64dec -}}
{{- /* Cached in .Values so every include in one render (Secret and all checksums) sees the same value. */ -}}
{{- $_ := set .Values.auth "ZO_REPORT_SERVER_SECRET" ($stored | default (randAlphaNum 48)) -}}
{{- end -}}
{{- .Values.auth.ZO_REPORT_SERVER_SECRET -}}
{{- end }}
