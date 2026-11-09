{{- define "switchboard.appsuiteSecret" -}}
{{- if .Values.overrides.appsuiteSecret -}}
{{- .Values.overrides.appsuiteSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "appsuite" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "switchboard.jwtSecret" -}}
{{- if .Values.overrides.jwtSecret -}}
{{- .Values.overrides.jwtSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "jwt" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "switchboard.redisSecret" -}}
{{- if .Values.overrides.redisSecret -}}
{{- .Values.overrides.redisSecret -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "redis-secret" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "switchboard.mysqlSecret" -}}
{{- if .Values.mysql.existingSecret -}}
{{ .Values.mysql.existingSecret }}
{{- else -}}
{{ include "ox-common.names.fullname" . }}-mysql
{{- end -}}
{{- end -}}

{{- define "switchboard.vapidSecret" -}}
{{- if .Values.vapid.existingSecret -}}
{{ .Values.vapid.existingSecret }}
{{- else -}}
{{ include "ox-common.names.fullname" . }}-vapid
{{- end -}}
{{- end -}}

{{- define "switchboard.env" -}}
- name: BIND_ADDR
  value: {{ .Values.bindAddr | default "::" | quote }}
- name: PORT
  value: {{ .Values.containerPort | default 8080 | quote }}
- name: LOG_LEVEL
  value: {{ .Values.logLevel | quote }}
- name: LOG_JSON
  value: {{ .Values.logJson | quote }}
- name: PRESENCE_TTL_SECONDS
  value: {{ .Values.presence.ttlSeconds | int64 | quote }}
- name: AS_API_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.appsuiteSecret" . }}
      key: token-login-secret
- name: WEBHOOK_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.appsuiteSecret" . }}
      key: webhook-secret
- name: AS_SIGNATURE_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.appsuiteSecret" . }}
      key: signature-secret
- name: ORIGINS
  value: {{ .Values.origins | quote }}
- name: REDIS_MODE
  value: {{ .Values.redis.mode | quote}}
- name: REDIS_HOSTS
  value: {{ .Values.redis.hosts | join "," | quote }}
- name: REDIS_PREFIX
  value: {{ .Values.redis.prefix | quote }}
- name: REDIS_TLS_ENABLED
  value: "{{ .Values.redis.tls.enabled }}"
{{- if .Values.redis.tls.enabled }}
- name: REDIS_TLS_CA
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.redisSecret" . }}
      key: ca.crt
{{- end }}
- name: REDIS_DB
  value: {{ .Values.redis.db | quote }}
{{- if eq .Values.redis.mode "sentinel" }}
- name: REDIS_SENTINEL_MASTER_ID
  value: {{ .Values.redis.sentinelMasterId | quote }}
{{- end }}
{{- if .Values.redis.auth.enabled }}
- name: REDIS_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.redisSecret" . }}
      key: username
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.redisSecret" . }}
      key: password
{{- end }}
{{- if .Values.jwtSecret.enabled }}
- name: JWT_SHARED_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.jwtSecret" . }}
      key: jwt-shared-secret
{{- end }}
{{- if .Values.oidc.issuer }}
- name: OIDC_ISSUER
  value: {{ .Values.oidc.issuer | quote }}
{{- end }}
{{- if .Values.jwks.enabled }}
- name: JWKS_CERT_PATH
  value: "/app/jwks-cert/"
{{- end }}
- name: JWT_EXPIRATION
  value: {{ .Values.jwt.tokenExpiration | quote }}
- name: JWT_ALGORITHM
  value: {{ .Values.jwt.algorithm | quote }}
- name: SERVICE_CAPABILITIES
  value: {{ .Values.jwt.serviceCapabilities | quote }}
- name: SQL_ENABLED
  value: {{ .Values.mysql.enabled | quote }}
{{- if .Values.mysql.enabled }}
- name: DATABASES
  value: "switchboard"
- name: DB_SWITCHBOARD_CONNECTIONS
  value: {{ .Values.mysql.connections | quote }}
- name: DB_SWITCHBOARD_NAME
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.mysqlSecret" . }}
      key: MYSQL_DATABASE
- name: DB_SWITCHBOARD_HOST
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.mysqlSecret" . }}
      key: MYSQL_HOST
- name: DB_SWITCHBOARD_PORT
  value: {{ .Values.mysql.port | quote }}
- name: DB_SWITCHBOARD_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.mysqlSecret" . }}
      key: MYSQL_PASSWORD
- name: DB_SWITCHBOARD_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.mysqlSecret" . }}
      key: MYSQL_USER
{{- if .Values.mysql.tls.enabled }}
- name: DB_SWITCHBOARD_SSL
  value: "true"
- name: DB_SWITCHBOARD_SSL_REJECT_UNAUTHORIZED
  value: {{ .Values.mysql.tls.rejectUnauthorized | quote }}
- name: DB_SWITCHBOARD_SSL_CA
  valueFrom:
    secretKeyRef:
      name: {{ .Values.mysql.tls.caSecretName | default (include "switchboard.mysqlSecret" .) }}
      key: {{ .Values.mysql.tls.caSecretKey | default "MYSQL_SSL_CA" }}
      optional: true
{{- end }}
{{- end }}
- name: VAPID_ENABLED
  value: {{ .Values.vapid.enabled | quote }}
{{- if .Values.vapid.enabled }}
- name: VAPID_SUBJECT
  value: {{ .Values.vapid.subject | quote }}
- name: VAPID_PUBLIC_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.vapidSecret" . }}
      key: vapid-public-key
- name: VAPID_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "switchboard.vapidSecret" . }}
      key: vapid-private-key
{{- end }}
{{- if .Values.httpProxy }}
- name: http_proxy
  value: {{ .Values.httpProxy | quote }}
{{- end }}
{{- end }}
