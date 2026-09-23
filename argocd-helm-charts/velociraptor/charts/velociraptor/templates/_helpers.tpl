{{/* Expand the name of the chart. */}}
{{- define "velociraptor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fully qualified app name. */}}
{{- define "velociraptor.fullname" -}}
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

{{- define "velociraptor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels. */}}
{{- define "velociraptor.labels" -}}
helm.sh/chart: {{ include "velociraptor.chart" . }}
{{ include "velociraptor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: velociraptor
{{- end }}

{{- define "velociraptor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "velociraptor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* ServiceAccount name. */}}
{{- define "velociraptor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "velociraptor.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Full image reference (registry/repository:tag or @digest). */}}
{{- define "velociraptor.image" -}}
{{- $registry := .Values.image.registry -}}
{{- $repository := .Values.image.repository -}}
{{- $ref := $repository -}}
{{- if $registry -}}
{{- $ref = printf "%s/%s" $registry $repository -}}
{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $ref .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $ref (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/* Name of the Secret holding the server config. */}}
{{- define "velociraptor.configSecretName" -}}
{{- if .Values.config.existingSecret -}}
{{- .Values.config.existingSecret -}}
{{- else -}}
{{- printf "%s-config" (include "velociraptor.fullname" .) -}}
{{- end -}}
{{- end }}

{{/* "true" when a config overlay (init-container merge) is needed. */}}
{{- define "velociraptor.overlayEnabled" -}}
{{- if or .Values.gui.oidc.enabled .Values.config.initializeServer .Values.customArtifacts.enabled -}}true{{- end -}}
{{- end }}

{{/* Secret + key holding the OIDC client secret. */}}
{{- define "velociraptor.oidcSecretName" -}}
{{- if .Values.gui.oidc.existingSecret -}}
{{- .Values.gui.oidc.existingSecret -}}
{{- else -}}
{{- printf "%s-oidc" (include "velociraptor.fullname" .) -}}
{{- end -}}
{{- end }}
{{- define "velociraptor.oidcSecretKey" -}}
{{- if .Values.gui.oidc.existingSecret -}}
{{- .Values.gui.oidc.existingSecretKey -}}
{{- else -}}
oauth_client_secret
{{- end -}}
{{- end }}

{{/* Init container that deep-merges the chart overlay onto the base config. */}}
{{- define "velociraptor.overlayInitContainer" -}}
{{- if eq (include "velociraptor.overlayEnabled" .) "true" }}
- name: config-merge
  image: {{ .Values.config.overlay.image.repository }}:{{ .Values.config.overlay.image.tag }}{{ with .Values.config.overlay.image.digest }}@{{ . }}{{ end }}
  imagePullPolicy: {{ .Values.config.overlay.image.pullPolicy }}
  command: ["sh", "-c"]
  args:
    - |
      set -eu
      yq eval-all 'select(fi==0) * select(fi==1)' \
        /base/{{ .Values.config.secretKey }} /overlay/overlay.yaml \
        {{- if .Values.gui.oidc.enabled }}
        | CLIENT_SECRET="$CLIENT_SECRET" yq '.GUI.authenticator.oauth_client_secret = strenv(CLIENT_SECRET)' \
        {{- end }}
        > /merged/{{ base .Values.config.mountPath }}
  {{- if .Values.gui.oidc.enabled }}
  env:
    - name: CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: {{ include "velociraptor.oidcSecretName" . }}
          key: {{ include "velociraptor.oidcSecretKey" . }}
  {{- end }}
  securityContext:
    {{- toYaml .Values.securityContext | nindent 4 }}
  volumeMounts:
    - name: config-base
      mountPath: /base
      readOnly: true
    - name: config-overlay
      mountPath: /overlay
      readOnly: true
    - name: config
      mountPath: /merged
{{- end }}
{{- end }}

{{/* Custom-artifacts volume mount (main container, read-only). */}}
{{- define "velociraptor.customArtifactsVolumeMount" -}}
{{- if .Values.customArtifacts.enabled }}
- name: custom-artifacts
  mountPath: {{ .Values.customArtifacts.path | quote }}
  readOnly: true
{{- end }}
{{- end }}

{{/* Custom-artifacts volume (ConfigMap-backed). */}}
{{- define "velociraptor.customArtifactsVolume" -}}
{{- if .Values.customArtifacts.enabled }}
- name: custom-artifacts
  configMap:
    name: {{ .Values.customArtifacts.existingConfigMap | default (printf "%s-custom-artifacts" (include "velociraptor.fullname" .)) }}
{{- end }}
{{- end }}

{{/* Config-related volumes (overlay-aware). */}}
{{- define "velociraptor.configVolumes" -}}
{{- if eq (include "velociraptor.overlayEnabled" .) "true" }}
- name: config-base
  secret:
    secretName: {{ include "velociraptor.configSecretName" . }}
- name: config-overlay
  secret:
    secretName: {{ include "velociraptor.fullname" . }}-config-overlay
- name: config
  emptyDir: {}
{{- else }}
- name: config
  secret:
    secretName: {{ include "velociraptor.configSecretName" . }}
{{- end }}
{{- end }}

{{/* Config volume mount on the main container (overlay-aware). */}}
{{- define "velociraptor.configVolumeMount" -}}
{{- if eq (include "velociraptor.overlayEnabled" .) "true" }}
- name: config
  mountPath: {{ dir .Values.config.mountPath }}
{{- else }}
- name: config
  mountPath: {{ .Values.config.mountPath }}
  subPath: {{ .Values.config.secretKey }}
  readOnly: true
{{- end }}
{{- end }}
