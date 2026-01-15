{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "funkwhale.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "funkwhale.postgresql.host" -}}
{{- $name := .Values.postgresql.nameOverride | default "postgresql" -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "funkwhale.dbUrl" -}}
{{- if (or .Values.postgresql.postgresqlUsername .Values.postgresql.postgresqlPassword .Values.postgresql.postgresqlDatabase) -}}
{{ fail "You are using the old postgresql auth config keys - please update your values to the new postgresql.auth config keys" }}
{{- end -}}
{{- if .Values.database -}}
{{ fail "You are using the old database config key - please update your values to the new postgresql config key" }}
{{- else if and .Values.postgresql.enabled .Values.postgresql.host -}}
{{ fail "Both postgresql.enabled and postgresql.host have been specified - you may want to set postgresql.enabled=false if you want to use an external database" }}
{{- else if .Values.postgresql.enabled -}}
postgres://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ template "funkwhale.postgresql.host" . }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- else if .Values.postgresql.host -}}
postgres://{{ .Values.postgresql.auth.username }}:{{ .Values.postgresql.auth.password }}@{{ .Values.postgresql.host }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.auth.database }}
{{- else -}}
{{ fail "Either postgresql.enabled or postgresql.host are required!" }}
{{- end -}}
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

{{/*
Create the correct image tag name
*/}}
{{- define "funkwhale.imageUri" -}}
{{- printf "%s/%s:%s" (.Scope.registry | default .Values.image.registry | default "docker.io/funkwhale") (.Scope.image | default .Values.image.image) (.Scope.tag | default .Values.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "funkwhale.redis.host" -}}
{{- $name := .Values.redis.nameOverride | default "redis" -}}
{{- printf "%s-%s-%s" .Release.Name $name "master" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "funkwhale.redisUrl" -}}
{{- if and .Values.redis.enabled .Values.redis.host -}}
{{ fail "Setting both redis.enabled and redis.host would deploy an internal Redis service and attempt to use an external one - please set only one of the two!" }}
{{- else if .Values.redis.enabled -}}
redis://:{{ .Values.redis.auth.password }}@{{ template "funkwhale.redis.host" . }}:{{ .Values.redis.master.service.port | default 6379 }}/0
{{- else if .Values.redis.host -}}
redis://:{{ .Values.redis.auth.password }}@{{ .Values.redis.host }}:{{ .Values.redis.master.service.port | default 6379 }}/{{ .Values.redis.database | default 0 }}
{{- else -}}
{{ fail "Either redis.enabled or redis.host are required!" }}
{{- end -}}
{{- end -}}
