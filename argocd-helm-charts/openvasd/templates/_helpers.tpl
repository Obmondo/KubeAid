{{/*
Return the fullname used by the dependent openvasd service.
This mirrors the subchart helper so the parent chart can point Ingress at it.
*/}}
{{- define "openvasd-parent.serviceName" -}}
{{- $subchartName := "openvasd" -}}
{{- $subvals := .Values.openvasd -}}
{{- if $subvals.fullnameOverride -}}
{{- $subvals.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default $subchartName $subvals.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "openvasd-parent.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}
