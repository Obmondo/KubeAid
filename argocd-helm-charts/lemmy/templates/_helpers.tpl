{{/*
Override the upstream lemmy.postgresql.password helper to avoid Helm lookup() issues with ArgoCD.
When existingSecret is set, we return a placeholder that will be replaced by the init container.
*/}}
{{- define "lemmy.postgresql.password" -}}
{{- if and (not .Values.postgresql.enabled) .Values.postgresql.auth.existingSecret -}}
CNPG_PASSWORD_PLACEHOLDER
{{- else if .Values.postgresql.auth.password -}}
{{- .Values.postgresql.auth.password -}}
{{- else if .Values.postgresql.enabled -}}
postgres
{{- else -}}
postgres
{{- end -}}
{{- end -}}
