{{/*
Creates a list of image pull secrets and appends global.imagePullSecrets in case those are set
*/}}
{{- define "ox-common.pods.imagePullSecrets" -}}
{{- $imagePullSecrets := .imagePullSecrets -}}
{{- if .global.Values.global -}}
{{- if .global.Values.global.imagePullSecrets -}}
{{- $imagePullSecrets = concat $imagePullSecrets .global.Values.global.imagePullSecrets -}}
{{- end -}}
{{- end -}}
{{ toYaml $imagePullSecrets }}
{{- end -}}

{{/*
Generates basic attributes of a podspec to be used either in a Deployment, StatefulSet or Job (or anywhere else you need a Pod)
From the .podRoot it pulls in: serviceAccountName, automountServiceAccountToken, podSecurityContext/defaultPodSecurityContext or securityContext/defaultSecurityContext, nodeSelector, affinity and tolerations.
From the .global it pulls in: useDefaultSecurityContext.

automountServiceAccountToken is only rendered when explicitly set (true or false); leaving it unset keeps the Kubernetes default. Set it to false for components that never call the Kubernetes API (CIS 5.1.6).

Example:
spec:
  {{ include "ox-common.pods.podSpec" (dict "podRoot" .Values "context" . "global" $) | nindent 2 }}
*/}}
{{- define "ox-common.pods.podSpec" -}}
{{- $podRoot := .podRoot -}}
{{- $context := .context -}}
{{- $global := .global -}}
imagePullSecrets: {{ include "ox-common.pods.imagePullSecrets" (dict "imagePullSecrets" $podRoot.imagePullSecrets "global" $global ) | nindent 2 }}
serviceAccountName: {{ include "ox-common.serviceaccount.name" (dict "podRoot" $podRoot "context" $context "global" $global) }}
{{- if not (kindIs "invalid" $podRoot.automountServiceAccountToken) }}
automountServiceAccountToken: {{ $podRoot.automountServiceAccountToken }}
{{- end }}
{{- if $podRoot.podSecurityContext }}
securityContext: {{ toYaml $podRoot.podSecurityContext | nindent 2 }}
{{- else if .global.Values.global -}}
{{- if .global.Values.global.useDefaultSecurityContext -}}
{{- if $podRoot.defaultPodSecurityContext }}
securityContext: {{ toYaml $podRoot.defaultPodSecurityContext | nindent 2 }}
{{- end -}}
{{- end -}}
{{- end }}
nodeSelector: {{ toYaml $podRoot.nodeSelector | nindent 2 }}
affinity: {{ toYaml $podRoot.affinity | nindent 2 }}
tolerations: {{ toYaml $podRoot.tolerations | nindent 2 }}
{{- with $podRoot.extraPodSpec }}
{{ . | toYaml }}
{{- end }}
{{- end -}}

{{/*
Generates the securityContext attribute of a containerspec to be used either in a Deployment, StatefulSet or Job (or anywhere else you need a Container)
From the .podRoot it pulls in: securityContext/defaultSecurityContext.
From the .global it pulls in: useDefaultSecurityContext.

Example:
spec:
  {{- include "ox-common.containers.securityContext" (dict "podRoot" .Values "context" . "global" $) | nindent 10 }}
*/}}

{{- define "ox-common.containers.securityContext" -}}
{{- $podRoot := .podRoot -}}
{{- $global := .global -}}
{{- if $podRoot.securityContext -}}
securityContext: {{ toYaml $podRoot.securityContext | nindent 2 }}
{{- else if .global.Values.global -}}
{{- if .global.Values.global.useDefaultSecurityContext -}}
{{- if $podRoot.defaultSecurityContext -}}
securityContext: {{ toYaml $podRoot.defaultSecurityContext | nindent 2 }}
{{- end -}}
{{- end -}}
{{- end }}
{{- end -}}

{{/*
When configmaps or secrets change, a pod is usually not automatically restarted (Since it might react to new file content dynamically).
If it needs a restart a common trick is to write a checksum of a rendered template into an annotation. If the template output changes,
the checksum and therefore the annotation changes forcing kubernetes to restart the container.

You pass a list of template names to this function, and it generates the annotations.

Example:

annotations:
  {{ include "ox-common.pods.checksum" (list "configmap.yaml" "secret.yaml" "other-secret.yaml") | nindent 2 }}
*/}}
{{- define "ox-common.pods.checksum" -}}
{{- $context := .context -}}
{{- $global := .global -}}
{{- range .templates }}
checksum/{{ . }}: {{ include (print $global.Template.BasePath "/" . ) $context | sha256sum | trunc 10 | quote }}
{{- end -}}
{{- end -}}

