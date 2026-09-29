{{/*
  Name of the upstream wazuh subchart's objects, computed exactly as its own
  fullname helper does (fullnameOverride, else the release name when it
  already contains "wazuh", else <release>-wazuh). The wrapper's own objects and
  its references to upstream Services use it, so they follow the subchart when
  the chart runs under another release name (for example inside the
  security-operations umbrella, which sets wazuh.fullnameOverride).
*/}}
{{- define "kubeaid-wazuh.fullname" -}}
{{- $sub := .Values.wazuh | default dict -}}
{{- if $sub.fullnameOverride -}}
{{- $sub.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "wazuh" $sub.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
