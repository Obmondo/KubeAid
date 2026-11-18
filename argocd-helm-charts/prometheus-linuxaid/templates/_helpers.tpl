{{/*
Construct the namespace for all namespaced resources
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
Preserve the default behavior of the Release namespace if no override is provided
*/}}
{{- define "prometheus-linuxaid.namespace" -}}
{{- if .Values.namespaceOverride -}}
{{- .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "prometheus-linuxaid.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.namespaceOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
The keys the Grafana JWT middleware verifies with, as a YAML list: public_keys, else the single
public_key. Empty when the middleware is disabled or has no key. The jwt, header and chain
middlewares all gate on it, so the chain is never rendered without the middlewares it names.
*/}}
{{- define "prometheus-linuxaid.jwtKeys" -}}
{{- $jwt := .Values.middleware.jwt -}}
{{- $keys := default (list) $jwt.public_keys -}}
{{- if and (eq (len $keys) 0) $jwt.public_key -}}
{{- $keys = list $jwt.public_key -}}
{{- end -}}
{{- if and $jwt.enabled (gt (len $keys) 0) -}}
{{- toYaml $keys -}}
{{- end -}}
{{- end -}}
