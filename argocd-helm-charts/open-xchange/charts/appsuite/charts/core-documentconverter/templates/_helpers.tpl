{{/*
Create dc-configmap name.
*/}}
{{- define "core-documentconverter.configmap" -}}
{{- printf "%s-%s" (include "ox-common.names.fullname" . | trunc 53 | trimSuffix "-") "dc-configmap" }}
{{- end -}}

{{/*
Definition of documentconverter cache directory
*/}}
{{- define "core-documentconverter.cacheDir" -}}
{{- if and .Values.persistence.enabled .Values.persistence.cacheDir.path }}
{{- .Values.persistence.cacheDir.path }}
{{- else }}
{{- "/var/spool/open-xchange/documentconverter/cache" }}
{{- end }}
{{- end -}}

{{/*
Create volume claim cacheDir name.
*/}}
{{- define "core-documentconverter.volumeClaim.cacheDir" -}}
{{- printf "%s-%s" (include "ox-common.names.fullname" . | trunc 53 | trimSuffix "-") "cachedir" }}
{{- end -}}

{{/*
Create envVars secret.
*/}}
{{- define "core-documentconverter.envVars" -}}
{{- printf "%s-%s" (include "ox-common.names.fullname" . | trunc 53 | trimSuffix "-") "envvars" }}
{{- end -}}

{{/*
KeyStore
*/}}
{{- define "core-documentconverter.keystore" -}}
{{- printf "%s-%s" (include "ox-common.names.fullname" . | trunc 53 | trimSuffix "-") "keystore" }}
{{- end -}}

{{/*
Provides the coolUrl that is used for conversions if documentConverter.engine is "cool"
*/}}
{{- define "core-documentconverter.coolUrl" -}}
{{- printf "http://%s-collabora-online.%s.svc.cluster.local:9980" .Release.Name .Release.Namespace }}
{{- end -}}
