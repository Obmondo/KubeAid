{{/*
Database credential source: an inline database.password takes precedence and
is rendered into the chart-owned Secret (templates/db-secret.yaml); otherwise
the externally managed database.existingSecret/existingSecretKey is used.
*/}}
{{- define "booking.database.secretName" -}}
{{- if .Values.database.password -}}
{{ printf "%s-db-password" (include "ox-common.names.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ .Values.database.existingSecret }}
{{- end -}}
{{- end }}

{{- define "booking.database.secretKey" -}}
{{- if .Values.database.password -}}
password
{{- else -}}
{{ .Values.database.existingSecretKey }}
{{- end -}}
{{- end }}

{{/*
Free/busy credential source, same two ways as the database password: inline
freeBusy.user/password win and are rendered into a chart-owned Secret
(templates/freebusy-secret.yaml), otherwise freeBusy.existingSecret is
referenced. Renders empty when neither is set — callers use that to decide
whether FREEBUSY_USER/FREEBUSY_PASS are wired at all.
*/}}
{{- define "booking.freeBusy.secretName" -}}
{{- if and .Values.freeBusy.user .Values.freeBusy.password -}}
{{ printf "%s-freebusy" (include "ox-common.names.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ .Values.freeBusy.existingSecret }}
{{- end -}}
{{- end }}

{{- define "booking.freeBusy.userKey" -}}
{{- if and .Values.freeBusy.user .Values.freeBusy.password -}}
login
{{- else -}}
{{ .Values.freeBusy.existingSecretUserKey }}
{{- end -}}
{{- end }}

{{- define "booking.freeBusy.passwordKey" -}}
{{- if and .Values.freeBusy.user .Values.freeBusy.password -}}
password
{{- else -}}
{{ .Values.freeBusy.existingSecretPasswordKey }}
{{- end -}}
{{- end }}

{{/*
Mail-template override source, same two ways again: inline
mailTemplates.files win and are rendered into a chart-owned ConfigMap
(templates/mail-templates-configmap.yaml), otherwise
mailTemplates.existingConfigMap is referenced. Renders empty when neither is
set — callers use that to decide whether the volume is mounted at all.

This is a ConfigMap of its own rather than extra keys in the config one
because the service reads the overrides from a subdirectory
($CONFIG_PATH/mail-templates) and ConfigMap keys cannot contain a slash.
*/}}
{{- define "booking.mailTemplates.configMapName" -}}
{{- if .Values.mailTemplates.files -}}
{{ printf "%s-mail-templates" (include "ox-common.names.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ .Values.mailTemplates.existingConfigMap }}
{{- end -}}
{{- end }}

{{/*
Extra CA bundle (same contract as ai-service): extraCaCerts.existingSecret
wins, otherwise inline extraCaCerts.certificates are rendered into a
chart-owned Secret (templates/extra-ca-secret.yaml). The enabled helper
renders "true" or nothing.
*/}}
{{- define "booking.extraCa.enabled" -}}
{{- if or .Values.extraCaCerts.existingSecret .Values.extraCaCerts.certificates -}}
true
{{- end -}}
{{- end }}

{{- define "booking.extraCa.secretName" -}}
{{- if .Values.extraCaCerts.existingSecret -}}
{{ .Values.extraCaCerts.existingSecret }}
{{- else -}}
{{ printf "%s-extra-ca" (include "ox-common.names.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end }}

{{- define "booking.extraCa.env" -}}
{{- if (include "booking.extraCa.enabled" .) -}}
- name: NODE_EXTRA_CA_CERTS
  value: {{ printf "/certs/ca/%s" (.Values.extraCaCerts.key | default "ca.crt") | quote }}
{{- end }}
{{- end }}

{{- define "booking.extraCa.volumeMount" -}}
{{- if (include "booking.extraCa.enabled" .) -}}
- name: extra-ca
  mountPath: /certs/ca
  readOnly: true
{{- end }}
{{- end }}

{{- define "booking.extraCa.volume" -}}
{{- if (include "booking.extraCa.enabled" .) -}}
- name: extra-ca
  secret:
    secretName: {{ include "booking.extraCa.secretName" . | quote }}
{{- end }}
{{- end }}
