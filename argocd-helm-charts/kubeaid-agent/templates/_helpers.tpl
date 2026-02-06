{{/* Determine the final chart name. */}}

{{- $basic := .Values.kubeaidConfig.repo.auth.basic }}
{{- $basicConfigured := and $basic.usernameSecretRef.secretName $basic.passwordSecretRef.secretName }}

{{- define "kubeaid-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Determine if basic auth is configured*/}}
{{- define "kubeaid-agent.basicAuthConfigured" -}}
{{- $basic := .Values.kubeaidConfig.repo.auth.basic -}}
{{- if and $basic.usernameSecretRef.secretName $basic.passwordSecretRef.secretName -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}


{{/* Determine the final application name. */}}
{{- define "kubeaid-agent.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Common conventional labels. */}}
{{- define "kubeaid-agent.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "kubeaid-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{/* Selector labels. */}}
{{- define "kubeaid-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubeaid-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
