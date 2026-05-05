{{/*
Expand the name of the chart.
*/}}
{{- define "kubescape-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kubescape-operator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kubescape-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "kubescape-operator.annotations" -}}
{{- if .Values.additionalAnnotations }}
{{ toYaml .Values.additionalAnnotations }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubescape-operator.labels" -}}
helm.sh/chart: {{ include "kubescape-operator.chart" . }}
{{ include "kubescape-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: kubescape
app: {{ .app }}
tier: {{ .tier }}
kubescape.io/ignore: "true"
{{- if .Values.additionalLabels }}
{{ toYaml .Values.additionalLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubescape-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubescape-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ .app }}
{{- end }}

{{/*
Resolve priorityClassName for a component with customScheduling fallback.
Usage: {{ include "kubescape-operator.priorityClassName" (dict "component" .Values.<component> "global" .Values.customScheduling) }}
*/}}
{{- define "kubescape-operator.priorityClassName" -}}
{{- if .component.priorityClassName }}
priorityClassName: {{ .component.priorityClassName }}
{{- else if .global.priorityClassName }}
priorityClassName: {{ .global.priorityClassName }}
{{- end }}
{{- end }}

{{/*
Convert a Kubernetes memory string (e.g. "1Gi", "512Mi", "2147483648") to bytes
as a float. Adapted from traefik.convertMemToBytes — supports SI (k/M/G/T/P/E)
and IEC (Ki/Mi/Gi/Ti/Pi/Ei) prefixes plus the milli (m) suffix and bare numbers.

Usage: {{ include "kubescape-operator.convertMemToBytes" "1Gi" }}
*/}}
{{- define "kubescape-operator.convertMemToBytes" }}
  {{- $mem := . -}}
  {{- if hasSuffix "Ei" $mem -}}
    {{- $mem = mulf (trimSuffix "Ei" $mem | float64) 0x1p60 -}}
  {{- else if hasSuffix "E" $mem -}}
    {{- $mem = mulf (trimSuffix "E" $mem | float64) 1e18 -}}
  {{- else if hasSuffix "Pi" $mem -}}
    {{- $mem = mulf (trimSuffix "Pi" $mem | float64) 0x1p50 -}}
  {{- else if hasSuffix "P" $mem -}}
    {{- $mem = mulf (trimSuffix "P" $mem | float64) 1e15 -}}
  {{- else if hasSuffix "Ti" $mem -}}
    {{- $mem = mulf (trimSuffix "Ti" $mem | float64) 0x1p40 -}}
  {{- else if hasSuffix "T" $mem -}}
    {{- $mem = mulf (trimSuffix "T" $mem | float64) 1e12 -}}
  {{- else if hasSuffix "Gi" $mem -}}
    {{- $mem = mulf (trimSuffix "Gi" $mem | float64) 0x1p30 -}}
  {{- else if hasSuffix "G" $mem -}}
    {{- $mem = mulf (trimSuffix "G" $mem | float64) 1e9 -}}
  {{- else if hasSuffix "Mi" $mem -}}
    {{- $mem = mulf (trimSuffix "Mi" $mem | float64) 0x1p20 -}}
  {{- else if hasSuffix "M" $mem -}}
    {{- $mem = mulf (trimSuffix "M" $mem | float64) 1e6 -}}
  {{- else if hasSuffix "Ki" $mem -}}
    {{- $mem = mulf (trimSuffix "Ki" $mem | float64) 0x1p10 -}}
  {{- else if hasSuffix "k" $mem -}}
    {{- $mem = mulf (trimSuffix "k" $mem | float64) 1e3 -}}
  {{- else if hasSuffix "m" $mem -}}
    {{- $mem = divf (trimSuffix "m" $mem | float64) 1e3 -}}
  {{- end }}
{{- $mem }}
{{- end }}

{{/*
Compute GOMEMLIMIT as a percentage of a memory limit string.
Returns a string formatted as "<N>MiB" suitable for the Go runtime.

Usage:
  {{ include "kubescape-operator.gomemlimit" (dict "memory" .Values.foo.resources.limits.memory "percentage" .Values.foo.gomemlimitPercentage) }}
*/}}
{{- define "kubescape-operator.gomemlimit" }}
{{- $percentage := .percentage -}}
{{- $bytes := include "kubescape-operator.convertMemToBytes" .memory | mulf $percentage -}}
{{- printf "%dMiB" (divf $bytes 0x1p20 | floor | int64) -}}
{{- end }}
