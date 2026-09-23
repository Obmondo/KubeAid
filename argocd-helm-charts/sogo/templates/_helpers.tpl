{{/*
Name for the bundled OpenLDAP StatefulSet/Service/Certificate/etc.
*/}}
{{- define "sogo.openldap.name" -}}
{{- printf "%s-openldap" .Release.Name -}}
{{- end -}}

{{/*
Secret holding the OpenLDAP TLS cert - either brought in via
openldap.tls.existingSecret or the one this chart's own Certificate writes to.
*/}}
{{- define "sogo.openldap.tlsSecretName" -}}
{{- .Values.openldap.tls.existingSecret | default (printf "%s-tls" (include "sogo.openldap.name" .)) -}}
{{- end -}}
