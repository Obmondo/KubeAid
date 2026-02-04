{{/*
Override the upstream funkwhale.dbUrl helper to avoid requiring password in values.
When postgresql.auth.existingSecret is set, we use a placeholder that will be replaced
by the PreSync Job with the actual password from the CNPG secret.
*/}}
{{- define "funkwhale.dbUrl" -}}
{{- if (or .Values.postgresql.postgresqlUsername .Values.postgresql.postgresqlPassword .Values.postgresql.postgresqlDatabase) -}}
{{ fail "You are using the old postgresql auth config keys - please update your values to the new postgresql.auth config keys" }}
{{- end -}}
{{- if .Values.database -}}
{{ fail "You are using the old database config key - please update your values to the new postgresql config key" }}
{{- else if and .Values.postgresql.enabled .Values.postgresql.host -}}
{{ fail "Both postgresql.enabled and postgresql.host have been specified - you may want to set postgresql.enabled=false if you want to use an external database" }}
{{- else if .Values.postgresql.enabled -}}
postgres://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ template "funkwhale.postgresql.host" . }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- else if .Values.postgresql.host -}}
{{- if .Values.postgresql.auth.existingSecret -}}
postgres://{{ .Values.postgresql.auth.username }}:CNPG_PASSWORD_PLACEHOLDER@{{ .Values.postgresql.host }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- else -}}
postgres://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ .Values.postgresql.host }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- end -}}
{{- else -}}
{{ fail "Either postgresql.enabled or postgresql.host are required!" }}
{{- end -}}
{{- end -}}
