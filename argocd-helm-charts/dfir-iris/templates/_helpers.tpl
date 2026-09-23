{{- define "dfir-iris.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "dfir-iris.fullname" -}}
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

{{- define "dfir-iris.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "dfir-iris.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "dfir-iris.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dfir-iris.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "dfir-iris.pvcName" -}}
{{- default (printf "%s-data" (include "dfir-iris.fullname" .)) .Values.persistence.existingClaim }}
{{- end }}

{{/* Environment shared by the app and the worker. */}}
{{- define "dfir-iris.env" -}}
- name: DOCKERIZED
  value: "1"
- name: LOG_LEVEL
  value: {{ .Values.logLevel | quote }}
- name: POSTGRES_SERVER
  value: {{ .Values.postgres.host | quote }}
- name: POSTGRES_PORT
  value: {{ .Values.postgres.port | quote }}
- name: POSTGRES_DB
  value: {{ .Values.postgres.database | quote }}
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret }}
      key: username
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret }}
      key: password
- name: POSTGRES_ADMIN_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret }}
      key: username
- name: POSTGRES_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret }}
      key: password
- name: DB_RETRY_COUNT
  value: "30"
- name: DB_RETRY_DELAY
  value: "5"
- name: RABBITMQ_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.rabbitmq.existingSecret }}
      key: username
- name: RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.rabbitmq.existingSecret }}
      key: password
- name: CELERY_BROKER
  value: "amqp://$(RABBITMQ_USERNAME):$(RABBITMQ_PASSWORD)@{{ .Values.rabbitmq.host }}:{{ .Values.rabbitmq.port }}"
- name: IRIS_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret }}
      key: IRIS_SECRET_KEY
- name: IRIS_SECURITY_PASSWORD_SALT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret }}
      key: IRIS_SECURITY_PASSWORD_SALT
- name: IRIS_ADM_USERNAME
  value: {{ .Values.admin.username | quote }}
- name: IRIS_ADM_EMAIL
  value: {{ .Values.admin.email | quote }}
- name: IRIS_ADM_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret }}
      key: IRIS_ADM_PASSWORD
{{- end }}

{{- define "dfir-iris.volumeMounts" -}}
- name: data
  mountPath: /home/iris/downloads
  subPath: downloads
- name: data
  mountPath: /home/iris/user_templates
  subPath: user_templates
- name: data
  mountPath: /home/iris/server_data
  subPath: server_data
{{- end }}

{{- define "dfir-iris.volumes" -}}
- name: data
{{- if .Values.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ include "dfir-iris.pvcName" . }}
{{- else }}
  emptyDir: {}
{{- end }}
{{- end }}
