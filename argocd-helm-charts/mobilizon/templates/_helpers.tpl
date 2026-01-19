{{- define "mobilizon.name" -}}
mobilizon
{{- end }}

{{- define "mobilizon.fullname" -}}
{{ .Release.Name }}-mobilizon
{{- end }}

{{- define "mobilizon.labels" -}}
app.kubernetes.io/name: {{ include "mobilizon.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}