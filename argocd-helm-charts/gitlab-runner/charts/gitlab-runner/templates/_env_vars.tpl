{{- define "gitlab-runner.runner-env-vars" }}
- name: CI_SERVER_URL
  value: {{ include "gitlab-runner.gitlabUrl" . }}
- name: RUNNER_EXECUTOR
  value: {{ default "kubernetes" .Values.runners.executor | quote }}
- name: REGISTER_LOCKED
  {{ if or (not (hasKey .Values.runners "locked")) .Values.runners.locked -}}
  value: "true"
  {{- else -}}
  value: "false"
  {{- end }}
- name: RUNNER_TAG_LIST
  value: {{ default "" .Values.runners.tags | quote }}
{{- if eq (default "kubernetes" .Values.runners.executor) "kubernetes" }}
{{- if not (regexMatch "\\s*namespace\\s*=" .Values.runners.config) }}
- name: KUBERNETES_NAMESPACE
  value: {{ .Release.Namespace | quote }}
{{- end }}
{{- if and (hasKey .Values.runners "hostUsers") (not (kindIs "invalid" .Values.runners.hostUsers)) }}
{{- if not (kindIs "bool" .Values.runners.hostUsers) }}
{{- fail "runners.hostUsers must be true or false" }}
{{- end }}
{{- if not (regexMatch "(?m)^\\s*host_users\\s*=" (default "" .Values.runners.config)) }}
- name: KUBERNETES_HOST_USERS
  value: {{ .Values.runners.hostUsers | quote }}
{{- end }}
{{- end }}
{{- if and (hasKey .Values.runners "hostUsersOverwriteAllowed") (not (kindIs "invalid" .Values.runners.hostUsersOverwriteAllowed)) }}
{{- if not (kindIs "bool" .Values.runners.hostUsersOverwriteAllowed) }}
{{- fail "runners.hostUsersOverwriteAllowed must be true or false" }}
{{- end }}
{{- if and .Values.runners.hostUsersOverwriteAllowed (not (regexMatch "(?m)^\\s*host_users_overwrite_allowed\\s*=" (default "" .Values.runners.config))) }}
- name: KUBERNETES_HOST_USERS_OVERWRITE_ALLOWED
  value: "true"
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.envVars -}}
{{ range .Values.envVars }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
{{- end }}
{{- range $key, $value := .Values.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- range $key, $value := .Values.extraEnvFrom }}
- name: {{ $key }}
  valueFrom:
    {{- toYaml $value | nindent 4 }}
{{- end }}
{{- if (include "gitlab-runner.isSessionServerAllowed" .)}}
- name: SESSION_SERVER_ADDRESS
  {{- if .Values.sessionServer.publicIP }}
  value: {{ .Values.sessionServer.publicIP }}
  {{- else if eq (include "gitlab-runner.server-session-service-type" .) "ClusterIP" }}
  value: {{ printf "%s.%s.svc.cluster.local" (include "gitlab-runner.server-session-service-name" .) .Release.Namespace }}
  {{- else if eq (include "gitlab-runner.server-session-service-type" .) "NodePort" }}
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.hostIP
  {{- else if eq (include "gitlab-runner.server-session-service-type" .) "Headless" }}
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.podIP
  {{- else }}
  value:
  {{- end }}
{{- end }}
{{- end }}
