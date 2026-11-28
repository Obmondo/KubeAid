{{/*
Expand the name of the chart.
*/}}
{{- define "sogo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sogo.fullname" -}}
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
{{- define "sogo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create image name that is used in the deployment
*/}}
{{- define "sogo.image" -}}
{{- if .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- else -}}
{{- if .Values.image.revision -}}
{{- printf "%s:%s-%s" .Values.image.repository .Chart.AppVersion .Values.image.revision -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Chart.AppVersion -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Create DB URL paths
*/}}
{{- define "sogo.db.baseUrl" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "postgresql://%s:%s@%s:5432/%s" (or .Values.postgresql.global.postgresql.auth.username .Values.postgresql.auth.username) (or .Values.postgresql.global.postgresql.auth.password .Values.postgresql.auth.password) (include "postgresql.v1.primary.fullname" .Subcharts.postgresql) (or .Values.postgresql.global.postgresql.auth.database .Values.postgresql.auth.database) -}}
{{- else if .Values.mariadb.enabled -}}
{{- printf "mysql://%s:%s@%s:3306/%s" .Values.mariadb.auth.username .Values.mariadb.auth.password (include "mariadb.primary.fullname" .Subcharts.mariadb) .Values.mariadb.auth.database -}}
{{- end -}}
{{- end -}}

{{- define "sogo.db.configs" -}}
SOGoProfileURL: {{ printf "%s/sogo_user_profile" (include "sogo.db.baseUrl" .) }}
OCSFolderInfoURL: {{ printf "%s/sogo_folder_info" (include "sogo.db.baseUrl" .) }}
OCSSessionsFolderURL: {{ printf "%s/sogo_sessions_folder" (include "sogo.db.baseUrl" .) }}
OCSAdminURL: {{ printf "%s/sogo_admin" (include "sogo.db.baseUrl" .) }}
OCSStoreURL: {{ printf "%s/sogo_store" (include "sogo.db.baseUrl" .) }}
OCSAclURL: {{ printf "%s/sogo_acl" (include "sogo.db.baseUrl" .) }}
OCSCacheFolderURL: {{ printf "%s/sogo_cache_folder" (include "sogo.db.baseUrl" .) }}
OCSEMailAlarmsFolderURL: {{ printf "%s/sogo_alarms_folder" (include "sogo.db.baseUrl" .) }}
SOGoUserSources:
  - type: sql
    id: directory
    viewURL: {{ printf "%s/sogo_view" (include "sogo.db.baseUrl" .) }}
    canAuthenticate: true
    isAddressBook: true
    userPasswordAlgorithm: md5
{{- end -}}

{{- define "sogo.db.parsed.type" -}}
{{- if .Values.sogo.configs.OCSFolderInfoURL }}
{{- $parts := split "://" .Values.sogo.configs.OCSFolderInfoURL -}}
{{- $db_type := $parts._0 -}}
{{- printf "%s" $db_type -}}
{{- end -}}
{{- end -}}

{{- define "sogo.db.parsed.hostname" -}}
{{- if .Values.sogo.configs.OCSFolderInfoURL }}
{{- $parts := split "://" .Values.sogo.configs.OCSFolderInfoURL -}}
{{- $db_type := $parts._0 -}}
{{- $remaining := $parts._1 -}}
{{- $parts = split "/" $remaining -}}
{{- $base_url := split "@" $parts._0 -}}
{{- $host := split ":" $base_url._1 -}}
{{- printf "%s" $host._0 -}}
{{- end -}}
{{- end -}}

{{- define "sogo.db.parsed.port" -}}
{{- if .Values.sogo.configs.OCSFolderInfoURL }}
{{- $parts := split "://" .Values.sogo.configs.OCSFolderInfoURL -}}
{{- $db_type := $parts._0 -}}
{{- $remaining := $parts._1 -}}
{{- $parts = split "/" $remaining -}}
{{- $base_url := split "@" $parts._0 -}}
{{- $host := split ":" $base_url._1 -}}
{{- printf "%s" $host._1 -}}
{{- end -}}
{{- end -}}

{{- define "sogo.db.parsed.username" -}}
{{- if .Values.sogo.configs.OCSFolderInfoURL }}
{{- $parts := split "://" .Values.sogo.configs.OCSFolderInfoURL -}}
{{- $db_type := $parts._0 -}}
{{- $remaining := $parts._1 -}}
{{- $parts = split "/" $remaining -}}
{{- $base_url := split "@" $parts._0 -}}
{{- $auth := split ":" $base_url._0 -}}
{{- printf "%s" $auth._0 -}}
{{- end -}}
{{- end -}}

{{- define "sogo.db.parsed.password" -}}
{{- if .Values.sogo.configs.OCSFolderInfoURL }}
{{- $parts := split "://" .Values.sogo.configs.OCSFolderInfoURL -}}
{{- $db_type := $parts._0 -}}
{{- $remaining := $parts._1 -}}
{{- $parts = split "/" $remaining -}}
{{- $base_url := split "@" $parts._0 -}}
{{- $auth := split ":" $base_url._0 -}}
{{- printf "%s" $auth._1 -}}
{{- end -}}
{{- end -}}

{{- define "sogo.mariadb.fullname" -}}
{{- if or .Values.mariadb.enabled (eq (include "sogo.db.parsed.type" .) "mysql") -}}
{{- include "sogo.db.parsed.hostname" . | default (ternary (printf "%s-mariadb" .Release.Name) "" .Values.mariadb.enabled) -}}
{{- end -}}
{{- end -}}

{{- define "sogo.postgresql.fullname" -}}
{{- if or .Values.postgresql.enabled (eq (include "sogo.db.parsed.type" .) "postgresql") -}}
{{- include "sogo.db.parsed.hostname" . | default (ternary (include "postgresql.v1.primary.fullname" .Subcharts.postgresql) "" .Values.postgresql.enabled) -}}
{{- end -}}
{{- end -}}

{{- define "sogo.memcached.fullname" -}}
{{ template "common.names.fullname" .Subcharts.memcached }}
{{- end -}}

{{- define "sogo.memcached.configs" -}}
SOGoMemcachedHost: {{ template "sogo.memcached.fullname" . }}
{{- end -}}

{{- define "sogo.ingress.apiVersion" -}}
{{- if semverCompare "<1.14-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "<1.19-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "networking.k8s.io/v1" -}}
{{- end }}
{{- end -}}


{{/*
Create volume mounts for the sogo container.
*/}}
{{- define "sogo.volumeMounts" -}}
{{- if .Values.sogo.extraVolumeMounts }}
{{ toYaml .Values.sogo.extraVolumeMounts }}
{{- end }}
{{- end -}}
