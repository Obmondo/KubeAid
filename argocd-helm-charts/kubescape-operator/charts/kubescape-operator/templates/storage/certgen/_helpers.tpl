{{- define "storage.certgen.name" -}}
{{- printf "%s-certgen" .Values.storage.name -}}
{{- end }}

{{- define "storage.certgen.clusterScopedName" -}}
{{- printf "%s-%s" (include "storage.certgen.name" .) .Values.ksNamespace | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "storage.certgen.secretName" -}}
{{- $strategy := include "kubescape.certificates.strategy" . }}
{{- if eq $strategy "hook" -}}
{{- printf "%s-tls-hook" .Values.storage.name -}}
{{- else -}}
{{- printf "%s-tls" .Values.storage.name -}}
{{- end -}}
{{- end }}

{{- define "storage.certgen.caSecretName" -}}
{{- printf "%s-tls-ca" .Values.storage.name -}}
{{- end }}

{{- define "storage.certgen.apiServiceName" -}}
v1beta1.spdx.softwarecomposition.kubescape.io
{{- end }}

{{- define "storage.certgen.svcDomainName" -}}
{{- printf "%s.%s.svc" .Values.storage.name .Values.ksNamespace -}}
{{- end }}

{{- define "storage.certgen.certificateData" -}}
{{- if not .Values.global._storageCertData -}}
  {{- $svcDomainName := (include "storage.certgen.svcDomainName" .) -}}
  {{- $svcDomainNameLocal := printf "%s.cluster.local" $svcDomainName -}}
  {{- $validityDays := int .Values.storage.mtls.certificateValidityInDays -}}
  {{- $ca := dict "Key" "mock-ca-key" "Cert" "mock-ca-cert" -}}
  {{- $cert := dict "Key" "mock-cert-key" "Cert" "mock-cert-cert" -}}
  {{- if not .Values.unittest }}
    {{- $existingCASecret := (lookup "v1" "Secret" .Values.ksNamespace (include "storage.certgen.caSecretName" .)) -}}
    {{- if and $existingCASecret $existingCASecret.data -}}
      {{- $_ := set $ca "Key" (index $existingCASecret.data "tls.key" | b64dec) -}}
      {{- $_ := set $ca "Cert" (index $existingCASecret.data "tls.crt" | b64dec) -}}
      {{- $existingCA := buildCustomCert ($ca.Cert | b64enc) ($ca.Key | b64enc) -}}
      {{/* Leaf cert validity governed by storage.mtls.certificateValidityInDays. After expiry, delete the storage-tls-ca Secret and run helm upgrade to regenerate. */}}
      {{- $generatedCert := genSignedCert $svcDomainName nil (list $svcDomainName $svcDomainNameLocal) $validityDays $existingCA -}}
      {{- $_ := set $cert "Key" $generatedCert.Key -}}
      {{- $_ := set $cert "Cert" $generatedCert.Cert -}}
    {{- else -}}
      {{/* CA and leaf cert validity governed by storage.mtls.certificateValidityInDays. After expiry, delete the storage-tls-ca Secret and run helm upgrade to regenerate. */}}
      {{- $generatedCA := genCA (printf "%s-ca" .Values.storage.name) $validityDays -}}
      {{- $generatedCert := genSignedCert $svcDomainName nil (list $svcDomainName $svcDomainNameLocal) $validityDays $generatedCA -}}
      {{- $_ := set $ca "Key" $generatedCA.Key -}}
      {{- $_ := set $ca "Cert" $generatedCA.Cert -}}
      {{- $_ := set $cert "Key" $generatedCert.Key -}}
      {{- $_ := set $cert "Cert" $generatedCert.Cert -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values.global "_storageCertData" (dict "ca" $ca "cert" $cert) -}}
{{- end -}}
{{- toYaml .Values.global._storageCertData -}}
{{- end -}}

