{{/* Provider credential env vars. */}}
{{- define "etcd-backup-restore.snapstoreEnv" -}}
- name: STORAGE_CONTAINER
  value: {{ .Values.backup.storageContainer }}
{{- if eq .Values.backup.storageProvider "S3" }}
- name: "AWS_APPLICATION_CREDENTIALS"
  value: "/var/etcd-backup"
{{- if .Values.backup.s3.endpoint }}
- name: "AWS_ENDPOINT_URL_S3"
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-etcd-backup
      key: "endpoint"
      optional: true
{{- end }}
{{- else if eq .Values.backup.storageProvider "ABS" }}
- name: "AZURE_APPLICATION_CREDENTIALS"
  value: "/var/etcd-backup"
{{- else if eq .Values.backup.storageProvider "GCS" }}
- name: "GOOGLE_APPLICATION_CREDENTIALS"
{{- if .Values.backup.tokenAuth.enabled }}
  value: "/var/.gcp/credentialsConfig"
{{- else }}
  value: "/var/.gcp/serviceaccount.json"
{{- end }}
{{- else if eq .Values.backup.storageProvider "Swift" }}
- name: "OPENSTACK_APPLICATION_CREDENTIALS"
  value: "/var/etcd-backup"
{{- else if eq .Values.backup.storageProvider "OSS" }}
- name: "ALICLOUD_APPLICATION_CREDENTIALS"
  value: "/var/etcd-backup"
{{- else if eq .Values.backup.storageProvider "OCS" }}
- name: "OPENSHIFT_APPLICATION_CREDENTIALS"
  value: "/var/etcd-backup"
{{- else if eq .Values.backup.storageProvider "ECS" }}
- name: "ECS_ENDPOINT"
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-etcd-backup
      key: "endpoint"
- name: "ECS_ACCESS_KEY_ID"
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-etcd-backup
      key: "accessKeyID"
- name: "ECS_SECRET_ACCESS_KEY"
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-etcd-backup
      key: "secretAccessKey"
{{- end }}
{{- end -}}

{{/* Mount point for the provider credential secret. */}}
{{- define "etcd-backup-restore.snapstoreVolumeMount" -}}
{{- if eq .Values.backup.storageProvider "GCS" }}
- name: etcd-backup
  mountPath: "/var/.gcp/"
{{- else }}
- name: etcd-backup
  mountPath: "/var/etcd-backup/"
{{- end }}
{{- end -}}

{{/* The provider credential secret itself. */}}
{{- define "etcd-backup-restore.snapstoreVolume" -}}
- name: etcd-backup
  projected:
    defaultMode: 0440
    sources:
    - secret:
        name: {{ .Release.Name }}-etcd-backup
        optional: false
{{- if .Values.backup.tokenAuth.enabled }}
    - serviceAccountToken:
        path: token
        expirationSeconds: {{ .Values.backup.tokenAuth.expirationSeconds }}
        audience: {{ .Values.backup.tokenAuth.audience }}
{{- end }}
{{- end -}}
