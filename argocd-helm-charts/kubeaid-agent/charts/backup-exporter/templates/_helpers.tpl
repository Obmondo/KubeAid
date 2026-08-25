{{/*
  app.kubernetes.io/name MUST stay "backup-exporter". kubeaid-agent discovers
  this exporter by listing Deployments AND Services with the selector
  app.kubernetes.io/name=backup-exporter (internal/core/backup/exporter.go), and
  kubeaid-cli does the same. Rename it and discover() returns errExporterAbsent,
  which is indistinguishable from "not installed" -- backups simply stop being
  reported, with nothing failing.

  Being a subchart, .Chart.Name is already "backup-exporter", so the default
  gives the right answer; nameOverride is the only way to get it wrong.
*/}}
{{- define "backup-exporter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "backup-exporter.fullname" -}}
{{- default (include "backup-exporter.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "backup-exporter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "backup-exporter.labels" -}}
helm.sh/chart: {{ include "backup-exporter.chart" . }}
{{ include "backup-exporter.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: backup-exporter
{{- end }}

{{/*
  Carries the label the agent selects on. Applied to both the Deployment and the
  Service, because discover() lists both with the same selector.
*/}}
{{- define "backup-exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backup-exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "backup-exporter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "backup-exporter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
  Convert duration strings (e.g. 24h, 60m, 60s) to seconds for Prometheus
  expressions.
*/}}
{{- define "backup-exporter.durationToSeconds" -}}
{{- $v := . | toString -}}
{{- if (hasSuffix "s" $v) -}}
  {{- trimSuffix "s" $v -}}
{{- else if (hasSuffix "m" $v) -}}
  {{- mul (trimSuffix "m" $v | int) 60 -}}
{{- else if (hasSuffix "h" $v) -}}
  {{- mul (trimSuffix "h" $v | int) 3600 -}}
{{- else if (hasSuffix "d" $v) -}}
  {{- mul (trimSuffix "d" $v | int) 86400 -}}
{{- else -}}
  {{- $v -}}
{{- end -}}
{{- end -}}
