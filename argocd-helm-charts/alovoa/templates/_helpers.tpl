{{/*
Expand the name of the chart.
*/}}
{{- define "alovoa.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "alovoa.fullname" -}}
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
{{- define "alovoa.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "alovoa.labels" -}}
helm.sh/chart: {{ include "alovoa.chart" . }}
{{ include "alovoa.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "alovoa.selectorLabels" -}}
app.kubernetes.io/name: {{ include "alovoa.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "alovoa.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "alovoa.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database host
*/}}
{{- define "alovoa.databaseHost" -}}
{{- if .Values.mariadb.enabled }}
{{- .Values.mariadb.name | default (printf "%s-mariadb" .Release.Name) }}
{{- else if .Values.postgres.enabled }}
{{- printf "%s-pgsql-rw" .Release.Name }}
{{- else }}
{{- .Values.alovoa.database.host }}
{{- end }}
{{- end }}

{{/*
Database port
*/}}
{{- define "alovoa.databasePort" -}}
{{- if .Values.mariadb.enabled }}
{{- 3306 }}
{{- else if .Values.postgres.enabled }}
{{- 5432 }}
{{- else }}
{{- .Values.alovoa.database.port | default 3306 }}
{{- end }}
{{- end }}

{{/*
Database name
*/}}
{{- define "alovoa.databaseName" -}}
{{- if .Values.mariadb.enabled }}
{{- .Values.mariadb.database | default "alovoa" }}
{{- else if .Values.postgres.enabled }}
{{- .Values.postgres.bootstrap.initdb.database | default "alovoa" }}
{{- else }}
{{- .Values.alovoa.database.name | default "alovoa" }}
{{- end }}
{{- end }}

{{/*
Database user
*/}}
{{- define "alovoa.databaseUser" -}}
{{- if .Values.mariadb.enabled }}
{{- .Values.mariadb.username | default "alovoa" }}
{{- else if .Values.postgres.enabled }}
{{- .Values.postgres.bootstrap.initdb.owner | default "alovoa" }}
{{- else }}
{{- .Values.alovoa.database.user | default "alovoa" }}
{{- end }}
{{- end }}

{{/*
Database secret name
*/}}
{{- define "alovoa.databaseSecretName" -}}
{{- if .Values.mariadb.enabled }}
{{- .Values.mariadb.passwordSecretRef.name | default (printf "%s-mariadb" .Release.Name) }}
{{- else if .Values.postgres.enabled }}
{{- printf "%s-pgsql-app" .Release.Name }}
{{- else }}
{{- .Values.alovoa.database.existingSecret }}
{{- end }}
{{- end }}

{{/*
Database secret key
*/}}
{{- define "alovoa.databaseSecretKey" -}}
{{- if .Values.mariadb.enabled }}
{{- .Values.mariadb.passwordSecretRef.key | default "password" }}
{{- else if .Values.postgres.enabled }}
{{- "password" }}
{{- else }}
{{- .Values.alovoa.database.existingSecretKey | default "password" }}
{{- end }}
{{- end }}

