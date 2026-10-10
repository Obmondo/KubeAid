{{- define "cnpg-drill.name" -}}
{{- printf "%s-cnpg-drill" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cnpg-drill.clusterName" -}}
{{- .Values.drillClusterName | default (printf "%s-restore" (include "cnpg-drill.name" . | trunc 53 | trimSuffix "-")) -}}
{{- end -}}
