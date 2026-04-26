{{- define "funkwhale.import-library" -}}
{{- $name := (.Import.name | default .Import.library) -}}
{{- if .Import.watch }}
apiVersion: apps/v1
kind: Deployment
{{- else if .Import.cron }}
apiVersion: batch/v1
kind: CronJob
{{- else }}
apiVersion: batch/v1
kind: Job
{{- end }}
metadata:
  name: {{ printf "%s-import-%s" (include "funkwhale.fullname" .) $name | trunc 63 | trimSuffix "-" }}
  labels:
    {{- include "funkwhale.labels" . | nindent 4 }}
    audio.funkwhale/component: importer
    audio.funkwhale/import-library: {{ .Import.library }}
spec:
{{- if .Import.watch }}
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      {{- include "funkwhale.selectorLabels" . | nindent 6 }}
      audio.funkwhale/component: importer
      audio.funkwhale/import-library: {{ .Import.library }}
  template:
{{- else if .Import.cron }}
  concurrencyPolicy: Forbid
  schedule: {{ .Import.cron }}
  jobTemplate:
{{- else }}
  completions: 1
  template:
{{- end }}
    metadata:
      labels:
        {{- include "funkwhale.selectorLabels" . | nindent 8 }}
        audio.funkwhale/component: importer
        audio.funkwhale/import-library: {{ .Import.library }}
    spec:
      containers:
        - name: importer
          image: {{ include "funkwhale.imageUri" (merge (dict "Scope" (.Import.image | default .Values.api.image)) .) | quote }}
          imagePullPolicy: {{ (.Import.image | default (dict)).pullPolicy | default .Values.api.image.pullPolicy | default .Values.image.pullPolicy }}
          command:
            - funkwhale-manage
            - import_files
            - {{ required "A library ID must be specified" .Import.library | quote }}
            - "/srv/funkwhale/data/music/{{ .Import.name | default .Import.library }}"
            - --noinput
            - --recursive
          {{- if .Import.watch }}
            - --watch
          {{- end }}
          {{- if .Import.inPlace }}
            - --in-place
          {{- end }}
          {{- if .Import.prune }}
            - --prune
          {{- end }}
          {{- if .Import.replace }}
            - --replace
          {{- end }}
          env:
            {{ include "funkwhale.envVars" . | nindent 12 }}
          envFrom:
          - configMapRef:
              name: {{ include "funkwhale.fullname" . }}
          - secretRef:
              name: {{ include "funkwhale.fullname" . }}
          {{- with .Values.extraEnvFrom }}
            {{ . | toYaml | nindent 12 }}
          {{- end }}
          volumeMounts:
            - name: data
              mountPath: "/srv/funkwhale/data/music/{{ .Import.name | default .Import.library }}"
            {{- with .Import.subPath }}
              subPath: {{ . | quote }}
            {{- end }}
          resources:
            {{- toYaml (.Import.resources | default .Values.api.resources) | nindent 12 }}
    {{- if not .Import.watch }}
      restartPolicy: OnFailure
    {{- end }}
    {{- with (.Import.nodeSelector | default .Values.api.nodeSelector) }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
    {{- end }}
    {{- with (.Import.affinity | default .Values.api.affinity) }}
      affinity:
        {{- toYaml . | nindent 8 }}
    {{- end }}
    {{- with (.Import.tolerations | default .Values.api.tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
    {{- end }}
      volumes:
        - name: data
          {{- toYaml (required "A volume definition must be specified" .Import.volume) | nindent 10 }}
{{- end -}}
