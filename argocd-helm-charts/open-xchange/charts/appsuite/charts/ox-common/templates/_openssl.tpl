{{/*
Functions to control the feature set of using SSL encryption for SSL based services, including to access the
keystore related data stored in a secret.

Supported configuration options to control the feature:

global:
    openssl:
      enabled: false
      secretName: <RELEASE-NAME>-openssl-secret
      certFile: ""
      keyFile: ""
      keyPassword: ""
*/}}

{{/*
Generate an OpenSSL secret manifest depending on the global configuration.

Usage:
{{- if and (eq (include "ox-common.openssl.enabled" . ) "true") -}}
{{- include "ox-common.openssl.createOpenSSLSecret" -}}
{{- end -}}

This code snippet must be part of the top-most stack-chart included in a separate
yaml file.
*/}}
{{- define "ox-common.openssl.createOpenSSLSecret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "ox-common.openssl.secretName" . | quote }}
type: Opaque
data:
  certfile: {{ required "A certificate file is required to enable SSL for OpenSSL services! Use --set-file global.openssl.certFile=<path to certificate file>" (include "ox-common.openssl.certFile" . ) | b64enc }}
  keyfile: {{ required "A key file is required to enable SSL for OpenSSL services! Use --set-file global.openssl.keyFile=<path to key file>" (include "ox-common.openssl.keyFile" . ) | b64enc }}
  keyfile-password: {{ required "A key file password is required for OpenSSL services!" (include "ox-common.openssl.keyPassword" . ) | b64enc }}
{{- end -}}

{{/*
Determines if OpenSSL should be used for service.
*/}}
{{- define "ox-common.openssl.enabled" -}}
{{- $enabled := false -}}
{{- if .Values -}}
  {{- if .Values.global -}}
    {{- if .Values.global.openssl -}}
      {{- $enabled = .Values.global.openssl.enabled | default false -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- default $enabled -}}
{{- end -}}

{{/*
Provides the global secret name for the certificate file and key file data for OpenSSL services.
*/}}
{{- define "ox-common.openssl.secretName" -}}
{{- $secretName := "" -}}
{{- if .Values -}}
  {{- if .Values.global -}}
    {{- if .Values.global.openssl }}
      {{- $secretName = .Values.global.openssl.secretName | default "" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if empty $secretName -}}
{{- $secretName = printf "%s-%s" .Release.Name "openssl-secret" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- default $secretName -}}
{{- end -}}

{{/*
Provides the data of the certificate file.
*/}}
{{- define "ox-common.openssl.certFile" -}}
{{- $certFileData := "" -}}
{{- if .Values -}}
  {{- if .Values.global -}}
    {{- if .Values.global.openssl -}}
      {{- $certFileData = .Values.global.openssl.certFile | default "" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- default $certFileData -}}
{{- end -}}

{{/*
Provides the data of the key file.
*/}}
{{- define "ox-common.openssl.keyFile" -}}
{{- $keyFileData := "" -}}
{{- if .Values -}}
  {{- if .Values.global -}}
    {{- if .Values.global.openssl -}}
      {{- $keyFileData = .Values.global.openssl.keyFile | default "" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- default $keyFileData -}}
{{- end -}}

{{/*
Provides the keystore password.
*/}}
{{- define "ox-common.openssl.keyPassword" -}}
{{- $keyPassword := "" -}}
{{- if .Values -}}
  {{- if .Values.global -}}
    {{- if .Values.global.openssl -}}
      {{- $keyPassword = .Values.global.openssl.keyPassword | default "" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- default $keyPassword -}}
{{- end -}}

{{/*
Provides the key for the keystore PEM based data stored in the openssl-secret
*/}}
{{- define "ox-common.openssl.secret.certFileKey" -}}
{{- default "certfile" -}}
{{- end -}}

{{/*
Provides the key for the truststore PEM based data stored in the openssl secret
*/}}
{{- define "ox-common.openssl.secret.keyFileKey" -}}
{{- default "keyfile" -}}
{{- end -}}

{{/*
Provides the key for the keystore password stored in the openssl secret
*/}}
{{- define "ox-common.openssl.secret.keyPasswordKey" -}}
{{- default "keyfile-password" -}}
{{- end -}}

{{/*
Generates a valueFrom structure for the keystore password to be used in the
deployment.yaml.
*/}}
{{- define "ox-common.openssl.secret.keyPassword.asValueFromSecretKeyRef" -}}
{{- $secretName := (include "ox-common.openssl.secretName" . ) -}}
valueFrom:
  secretKeyRef:
    name: {{ $secretName }}
    key: {{ include "ox-common.openssl.secret.keyPasswordKey" . }}
{{- end -}}
