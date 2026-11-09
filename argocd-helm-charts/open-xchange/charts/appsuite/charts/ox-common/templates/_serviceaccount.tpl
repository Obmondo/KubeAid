{{/*
Determines if a service account should get created. This is the case when `.Values.serviceAccountName` is empty or `serviceAccount.create` is `true`.

Example:
{{- if eq (include "ox-common.serviceaccount.create" (dict "podRoot" .Values "context" . "global" $)) "true" }}
...
{{- end }}

*/}}
{{- define "ox-common.serviceaccount.create" -}}
{{- $podRoot := .podRoot -}}
{{- if ($podRoot.serviceAccount).create -}}
true
{{- else -}}
false
{{- end }}
{{- end -}}

{{/*
Determines the name of a service account. The service account name is

- the value of `.Values.serviceAccountName`
- if `.Values.serviceAccountName` is empty and `.Values.serviceAccount.create` is `true` the service accout name will be a combination
  of `.Release.Name` and `.Values.serviceAccount.name`.
- otherwise the default service account name will be used.

Example:
serviceAccountName: {{- print (include "ox-common.serviceaccount.name" (dict "podRoot" .Values "context" . "global" $)) }}

*/}}
{{- define "ox-common.serviceaccount.name" -}}
{{- $podRoot := .podRoot -}}
{{- $context := .context -}}
{{- $global := .global -}}
{{- if $podRoot.serviceAccountName -}}
{{ print $podRoot.serviceAccountName }}
{{- else -}}
{{- if ($podRoot.serviceAccount).create -}}
{{- default (include "ox-common.names.fullname" $context) $podRoot.serviceAccount.name }}
{{- else -}}
default
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Renders a dedicated ServiceAccount resource when `serviceAccount.create` is `true`, so a chart no longer has to fall back to the namespace default ServiceAccount (CIS 5.1.5).
Honours `serviceAccount.annotations` and, at the ServiceAccount level, `serviceAccount.automountServiceAccountToken`.

Example (chart's templates/serviceaccount.yaml):
{{ include "ox-common.serviceaccount.resource" (dict "podRoot" .Values "context" . "global" $) }}
*/}}
{{- define "ox-common.serviceaccount.resource" -}}
{{- $podRoot := .podRoot -}}
{{- $context := .context -}}
{{- $global := .global -}}
{{- if and (eq (include "ox-common.serviceaccount.create" (dict "podRoot" $podRoot)) "true") (not $podRoot.serviceAccountName) -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "ox-common.serviceaccount.name" (dict "podRoot" $podRoot "context" $context "global" $global) }}
  namespace: {{ $context.Release.Namespace }}
  labels:
    {{- include "ox-common.labels.standard" $context | nindent 4 }}
  {{- with ($podRoot.serviceAccount).annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- if not (kindIs "invalid" ($podRoot.serviceAccount).automountServiceAccountToken) }}
automountServiceAccountToken: {{ ($podRoot.serviceAccount).automountServiceAccountToken }}
{{- end }}
{{- end -}}
{{- end -}}
