{{/* Scheme the OpenBao API is served with, as the openbao subchart decides it */}}
{{- define "openbao.wrapper.scheme" -}}
{{- if .Values.openbao.global.tlsDisable }}http{{ else }}https{{ end }}
{{- end }}

{{/* Labels added to every config resource */}}
{{- define "openbao.config.labels" -}}
{{- with .Values.config.labels }}
labels:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/* Job spec fields shared by the config Job and the drift CronJob; pass the job's values */}}
{{- define "openbao.config.jobSpec" -}}
backoffLimit: {{ .backoffLimit }}
{{- if not (kindIs "invalid" .activeDeadlineSeconds) }}
activeDeadlineSeconds: {{ .activeDeadlineSeconds }}
{{- end }}
{{- if not (kindIs "invalid" .ttlSecondsAfterFinished) }}
ttlSecondsAfterFinished: {{ .ttlSecondsAfterFinished }}
{{- end }}
{{- end }}

{{/* Pod template shared by the config Job and the drift CronJob */}}
{{- define "openbao.config.podTemplate" -}}
{{- $pod := .Values.config.pod }}
{{- $server := .Values.openbao.server.image }}
{{- $podLabels := merge (deepCopy ($pod.labels | default dict)) (.Values.config.labels | default dict) }}
{{- if or $pod.annotations $podLabels }}
metadata:
  {{- with $pod.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $podLabels }}
  labels:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
spec:
  serviceAccountName: {{ include "openbao.fullname" . }}-config
  automountServiceAccountToken: {{ .Values.config.serviceAccount.automountServiceAccountToken }}
  restartPolicy: {{ $pod.restartPolicy }}
  {{- with $pod.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $pod.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $pod.priorityClassName }}
  priorityClassName: {{ . }}
  {{- end }}
  {{- with $pod.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $pod.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $pod.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: apply
      image: {{ $pod.image.registry | default $server.registry }}/{{ $pod.image.repository | default $server.repository }}:{{ $pod.image.tag | default $server.tag | default (trimPrefix "v" .Subcharts.openbao.Chart.AppVersion) }}
      imagePullPolicy: {{ $pod.image.pullPolicy }}
      command: ["sh", "/config/apply.sh"]
      env:
        - name: BAO_ADDR
          value: {{ .Values.config.address | default (printf "%s://%s-active.%s.svc:%v" (include "openbao.wrapper.scheme" .) (include "openbao.fullname" .) .Release.Namespace .Values.openbao.server.service.port) | quote }}
        - name: PRUNE
          value: {{ .Values.config.prune | quote }}
        - name: HOME
          value: /tmp
        {{- with $pod.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $pod.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $pod.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
        - name: token
          mountPath: /var/run/secrets/openbao
          readOnly: true
        - name: config
          mountPath: /config
          readOnly: true
        - name: tmp
          mountPath: /tmp
        {{- with $pod.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
  volumes:
    - name: token
      projected:
        sources:
          - serviceAccountToken:
              audience: openbao-config
              expirationSeconds: {{ $pod.tokenExpirationSeconds }}
              path: token
    - name: config
      configMap:
        name: {{ include "openbao.fullname" . }}-config-values
        items:
          - key: apply.sh
            path: apply.sh
          - key: mounts
            path: mounts
          {{- range $name, $_ := .Values.config.roles }}
          - key: k8s-role-{{ $name }}.json
            path: k8s-roles/{{ $name }}.json
          {{- end }}
          {{- range $name, $_ := .Values.config.policies }}
          - key: policy-{{ $name }}
            path: policies/{{ $name }}.hcl
          {{- end }}
          - key: auth-methods
            path: auth/methods
          - key: identity-groups
            path: identity-groups
          {{- range $path, $m := .Values.config.authMethods }}
          - key: auth-{{ $path }}-config.json
            path: auth/{{ $path }}/config.json
          - key: auth-{{ $path }}-files
            path: auth/{{ $path }}/files
          {{- range $name, $_ := $m.roles }}
          - key: auth-{{ $path }}-role-{{ $name }}.json
            path: auth/{{ $path }}/roles/{{ $name }}.json
          {{- end }}
          {{- end }}
    - name: tmp
      emptyDir: {}
    {{- with $pod.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end -}}
