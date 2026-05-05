{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "funkwhale.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "funkwhale.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "funkwhale.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "funkwhale.selectorLabels" -}}
app.kubernetes.io/name: {{ include "funkwhale.name" $ }}
app.kubernetes.io/instance: {{ $.Release.Name }}
{{- end -}}

{{- define "funkwhale.labels" -}}
{{ include "funkwhale.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ $.Release.Service }}
helm.sh/chart: {{ include "funkwhale.chart" $ }}
{{- end -}}

{{/*
Create the correct image tag name
*/}}
{{- define "funkwhale.imageUri" -}}
{{- printf "%s/%s:%s" (.Scope.registry | default .Values.image.registry | default "docker.io/funkwhale") (.Scope.image | default .Values.image.image) (.Scope.tag | default .Values.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "funkwhale.dbUrl" -}}
{{- if .Values.postgresql.enabled -}}
{{- fail "Internal postgresql server is no longer available" -}}
{{- end -}}
postgres://{{ .Values.postgresql.username }}:{{ .Values.postgresql.password }}@{{ required "You need to specify postgresql.host" .Values.postgresql.host }}:{{ .Values.postgresql.port | default 5432 }}/{{ .Values.postgresql.database }}
{{- end -}}

{{- define "funkwhale.redisUrl" -}}
{{- if .Values.redis.enabled -}}
{{- fail "Internal postgresql server is no longer available" -}}
{{- end -}}
{{- if .Values.redis.password -}}
redis://:{{ .Values.redis.password }}@{{ required "You must specify redis.host" .Values.redis.host }}:{{ .Values.redis.port | default 6379 }}/{{ .Values.redis.database | default 0 }}
{{- else -}}
redis://{{ required "You must specify redis.host" .Values.redis.host }}:{{ .Values.redis.port | default 6379 }}/{{ .Values.redis.database | default 0 }}
{{- end -}}
{{- end -}}

{{- define "funkwhale.envVars" -}}
{{- if .Values.postgresql.existingSecret }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.existingSecret }}
      key: {{ .Values.postgresql.existingSecretKey | default "postgresql-url" }}
{{- end -}}
{{- if .Values.redis.existingSecret }}
- name: CACHE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.existingSecret }}
      key: {{ .Values.redis.existingSecretKey | default "redis-url" }}
{{- end -}}
{{- if .Values.s3.existingSecret }}
- name: AWS_SECRET_ACCESS_KEY 
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.existingSecret }}
      key: {{ .Values.s3.existingSecretKey | default "s3-secret-key" }}
{{- end -}}
{{- with .Values.extraEnvVars }}
{{ toYaml . }}
{{- end -}}
{{- end -}}
