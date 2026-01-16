{{- define "flohmarkt.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "flohmarkt.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "flohmarkt.labels" -}}
app.kubernetes.io/name: {{ include "flohmarkt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
