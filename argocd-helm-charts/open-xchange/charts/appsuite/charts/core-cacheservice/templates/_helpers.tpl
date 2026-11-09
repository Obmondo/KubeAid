{{/*
Create cacheservice-configmap name.
*/}}
{{- define "core-cacheservice.configmap" -}}
{{- printf "%s-%s" (include "ox-common.names.fullname" . | trunc 53 | trimSuffix "-") "cacheservice-configmap" }}
{{- end -}}

{{/*
Create fileItemStore name.
*/}}
{{- define "core-cacheservice.fileItemStore" -}}
  {{- printf "%s-%s" (include "ox-common.names.fullname" . | trunc 53 | trimSuffix "-") "fileitemstore" }}
{{- end -}}

{{/*
Name of the ServiceAccount to run the service pods with.
Only relevant if the serviceAccount value is set at all, see values.yaml.
*/}}
{{- define "core-cacheservice.serviceAccountName" -}}
  {{- if (.Values.serviceAccount).create -}}
    {{- default (include "ox-common.names.fullname" .) .Values.serviceAccount.name }}
  {{- else -}}
    {{- default "default" (.Values.serviceAccount).name }}
  {{- end -}}
{{- end -}}
