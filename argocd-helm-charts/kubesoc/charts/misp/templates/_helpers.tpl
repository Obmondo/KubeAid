{{/*
  Name of the upstream misp subchart's objects, computed exactly as its own
  fullname helper does (fullnameOverride, else the release name when it
  already contains "misp", else <release>-misp). The wrapper's own objects and
  its references to upstream Services use it, so they follow the subchart when
  the chart runs under another release name (for example inside the
  security-operations umbrella, which sets misp.fullnameOverride).
*/}}
{{- define "kubeaid-misp.fullname" -}}
{{- $sub := .Values.misp | default dict -}}
{{- if $sub.fullnameOverride -}}
{{- $sub.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "misp" $sub.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
