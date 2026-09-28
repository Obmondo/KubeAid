{{- define "kubesoc-portal.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kubesoc-portal.selectorLabels" -}}
app.kubernetes.io/name: kubesoc-portal
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "kubesoc-portal.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "kubesoc-portal.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* nginx configuration: loopback behind oauth2-proxy, all interfaces otherwise. */}}
{{- define "kubesoc-portal.nginxConf" -}}
worker_processes 1;
pid /tmp/nginx.pid;
error_log /dev/stderr warn;
events { worker_connections 256; }
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /dev/stdout;
  server_tokens off;
  client_max_body_size 1k;
  client_body_temp_path /tmp/client_temp;
  proxy_temp_path /tmp/proxy_temp;
  fastcgi_temp_path /tmp/fastcgi_temp;
  uwsgi_temp_path /tmp/uwsgi_temp;
  scgi_temp_path /tmp/scgi_temp;
  server {
    listen {{ if .Values.oauth2Proxy.enabled }}127.0.0.1:{{ end }}8080;
    root /usr/share/nginx/html;
    add_header Content-Security-Policy "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header Referrer-Policy no-referrer always;
    expires -1;
    location = /healthz { access_log off; default_type text/plain; return 200 "ok\n"; }
    location = /links.json { alias /srv/links/links.json; default_type application/json; }
    location / { try_files $uri /index.html; }
  }
}
{{- end -}}

{{/* The page's links as JSON. */}}
{{- define "kubesoc-portal.linksJson" -}}
{{- toPrettyJson (dict "title" .Values.title "subtitle" .Values.subtitle "central" (.Values.links.central | default list) "tenants" (.Values.links.tenants | default list) "operatorRoles" (.Values.links.operatorRoles | default list)) -}}
{{- end -}}
