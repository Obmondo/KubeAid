{{/*
In-cluster API authentication (global.apiAuth).
Servers (kubescape, kubevuln, synchronizer, operator) validate the caller's
service-account token with a TokenReview for the configured audience and
authorize it with a SubjectAccessReview in POD_NAMESPACE.
Callers (operator, node-agent) send a projected token mounted from
apiauth.callerVolume.
*/}}

{{/*
Effective switch. global.apiAuth.enabled, unless the node-agent is pinned to a
GKE Autopilot allowlist that does not include the token volume: then the mount
would get the node-agent rejected by GKE Warden, so the chart renders the
caller without a token and the servers with the check off.
Usage: {{- if eq (include "apiauth.enabled" .) "true" }}
*/}}
{{- define "apiauth.enabled" -}}
{{- $allowlist := .Values.nodeAgent.gke.allowlist -}}
{{- if and .Values.global.apiAuth.enabled (not (and $allowlist.enabled (not $allowlist.supportsApiToken))) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "apiauth.tokenDir" -}}
/var/run/secrets/kubescape.io/api-token
{{- end -}}

{{- define "apiauth.tokenFile" -}}
{{ include "apiauth.tokenDir" . }}/token
{{- end -}}

{{/*
Server env. Always rendered so that a disabled check (apiauth.enabled false)
reaches the servers as KS_API_AUTH_DISABLED.
Usage: {{- include "apiauth.serverEnv" . | nindent 12 }}
*/}}
{{- define "apiauth.serverEnv" -}}
- name: KS_API_AUDIENCE
  value: {{ .Values.global.apiAuth.audience | quote }}
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
{{- if ne (include "apiauth.enabled" .) "true" }}
- name: KS_API_AUTH_DISABLED
  value: "true"
{{- end }}
{{- end -}}

{{/*
Projected service-account token volume for callers; empty when apiAuth is disabled.
*/}}
{{- define "apiauth.callerVolume" -}}
{{- if eq (include "apiauth.enabled" .) "true" -}}
- name: kubescape-api-token
  projected:
    sources:
      - serviceAccountToken:
          audience: {{ .Values.global.apiAuth.audience | quote }}
          expirationSeconds: 3600
          path: token
{{- end }}
{{- end -}}

{{- define "apiauth.callerVolumeMount" -}}
{{- if eq (include "apiauth.enabled" .) "true" -}}
- name: kubescape-api-token
  mountPath: {{ include "apiauth.tokenDir" . }}
  readOnly: true
{{- end }}
{{- end -}}
