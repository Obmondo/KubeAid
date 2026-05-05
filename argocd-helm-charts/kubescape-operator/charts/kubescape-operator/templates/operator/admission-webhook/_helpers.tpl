{{- define "kubescape-admission.name" -}}
kubescape-admission-webhook
{{- end }}

{{- define "kubescape-admission.clusterScopedName" -}}
{{- printf "%s-%s" (include "kubescape-admission.name" .) .Values.ksNamespace | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "kubescape-admission.secretName" -}}
{{- $strategy := include "kubescape.certificates.strategy" . }}
{{- if eq $strategy "hook" -}}
{{- printf "%s-tls-hook" (include "kubescape-admission.name" .) -}}
{{- else -}}
{{- printf "%s-tls" (include "kubescape-admission.name" .) -}}
{{- end -}}
{{- end }}

{{- define "kubescape-admission.caSecretName" -}}
{{- printf "%s-ca" (include "kubescape-admission.name" .) -}}
{{- end }}

{{- define "kubescape-admission.legacyCaSecretName" -}}
kubescape-admission-ca
{{- end }}

{{- define "kubescape-admission.svcDomainName" -}}
{{- printf "kubescape-admission-webhook.%s.svc" .Values.ksNamespace -}}
{{- end }}

{{- define "kubescape-admission.certificateData" -}}
{{- if not .Values.global._admissionCertData -}}
  {{- $svcDomainName := (include "kubescape-admission.svcDomainName" .) -}}
  {{- $ca := dict "Key" "mock-ca-key" "Cert" "mock-ca-cert" -}}
  {{- $cert := dict "Key" "mock-cert-key" "Cert" "mock-cert-cert" -}}
  {{- if not .Values.unittest }}
    {{- $existingCASecret := (lookup "v1" "Secret" .Values.ksNamespace (include "kubescape-admission.caSecretName" .)) -}}
    {{- if not (and $existingCASecret $existingCASecret.data) -}}
      {{/* Fallback to legacy CA secret name to preserve the webhook trust chain across the first upgrade after the rename. */}}
      {{- $existingCASecret = (lookup "v1" "Secret" .Values.ksNamespace (include "kubescape-admission.legacyCaSecretName" .)) -}}
    {{- end -}}
    {{- if and $existingCASecret $existingCASecret.data -}}
      {{- $_ := set $ca "Key" (index $existingCASecret.data "tls.key" | b64dec) -}}
      {{- $_ := set $ca "Cert" (index $existingCASecret.data "tls.crt" | b64dec) -}}
      {{- $existingCA := buildCustomCert ($ca.Cert | b64enc) ($ca.Key | b64enc) -}}
      {{/* Leaf cert validity: 10 years (3650 days). After expiry, delete the kubescape-admission-ca Secret and run helm upgrade to regenerate. */}}
      {{- $generatedCert := genSignedCert $svcDomainName nil (list $svcDomainName) 3650 $existingCA -}}
      {{- $_ := set $cert "Key" $generatedCert.Key -}}
      {{- $_ := set $cert "Cert" $generatedCert.Cert -}}
    {{- else -}}
      {{/* CA and leaf cert validity: 10 years (3650 days). After expiry, delete the kubescape-admission-ca Secret and run helm upgrade to regenerate. */}}
      {{- $generatedCA := genCA (printf "*.%s.svc" .Values.ksNamespace) 3650 -}}
      {{- $generatedCert := genSignedCert $svcDomainName nil (list $svcDomainName) 3650 $generatedCA -}}
      {{- $_ := set $ca "Key" $generatedCA.Key -}}
      {{- $_ := set $ca "Cert" $generatedCA.Cert -}}
      {{- $_ := set $cert "Key" $generatedCert.Key -}}
      {{- $_ := set $cert "Cert" $generatedCert.Cert -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values.global "_admissionCertData" (dict "ca" $ca "cert" $cert) -}}
{{- end -}}
{{- toYaml .Values.global._admissionCertData -}}
{{- end -}}
