{{- define "core-ui-middleware.redisSecret" -}}
{{- if .Values.overrides.redisSecret -}}
{{- .Values.overrides.redisSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "core-ui-middleware-redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "core-ui-middleware.s3Secret" -}}
{{- if .Values.s3.auth.existingSecret -}}
{{- .Values.s3.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "core-ui-middleware-s3" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the storage backend for asset bytes (see ADR 0010, unify-cache-backends).
'auto' (the default) derives the backend from whether S3 is configured, so a
fresh install that supplies S3 (an endpoint or internal MinIO) gets the S3 path,
while a carried-forward 2.x values file (no S3, no MinIO) keeps running on Redis.
's3' or 'redis' force the choice explicitly.
*/}}
{{- define "core-ui-middleware.storageBackend" -}}
{{- if ne .Values.storage.backend "auto" -}}
{{- .Values.storage.backend -}}
{{- else if or .Values.s3.endpoint .Values.minio.enabled -}}
s3
{{- else -}}
redis
{{- end -}}
{{- end -}}

{{/*
S3 environment block, shared by the serving and updater containers. Emitted only
when the resolved storage backend is 's3'; callers gate on
core-ui-middleware.storageBackend.
*/}}
{{- define "core-ui-middleware.s3Env" -}}
- name: S3_ENDPOINT
  value: "{{ .Values.s3.endpoint | default (printf "http://%s-%s:9000" .Release.Name "minio") }}"
{{- if eq .Values.minio.enabled true }}
- name: S3_CREATE_BUCKET
  value: "true"
- name: S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name "minio" }}
      key: root-user
- name: S3_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name "minio" }}
      key: root-password
{{- else }}
- name: S3_CREATE_BUCKET
  value: "{{ .Values.s3.createBucket }}"
- name: S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "core-ui-middleware.s3Secret" . }}
      key: {{ .Values.s3.auth.userSecretKey }}
- name: S3_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "core-ui-middleware.s3Secret" . }}
      key: {{ .Values.s3.auth.passwordSecretKey }}
{{- end }}
- name: S3_BUCKET_NAME
  value: "{{ .Values.s3.bucketName }}"
{{- end -}}
