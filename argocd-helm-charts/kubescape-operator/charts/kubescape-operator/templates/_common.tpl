{{/* validate alertCRD.scopeClustered and alertCRD.scopeNamespaced are mutual exclusive */}}
{{- if and .Values.alertCRD.scopeClustered .Values.alertCRD.scopeNamespaced }}
{{- fail "alertCRD.scopeClustered and alertCRD.scopeNamespaced cannot both be true" }}
{{- end }}

{{- define "checksums" -}}
capabilitiesConfig: {{ include (printf "%s/%s/%s" $.Template.BasePath $.Values.global.configMapsDirectory "components-configmap.yaml") . | replace .Chart.AppVersion "" | sha256sum }}
cloudConfig: {{ include (printf "%s/%s/%s" $.Template.BasePath $.Values.global.configMapsDirectory "cloudapi-configmap.yaml") . | replace .Chart.AppVersion "" | sha256sum }}
cloudSecret: {{ include (printf "%s/%s/%s" $.Template.BasePath $.Values.global.configMapsDirectory "cloud-secret.yaml" ) . | replace .Chart.AppVersion "" | sha256sum }}
hostScannerConfig: {{ include (printf "%s/kubescape/host-scanner-definition-configmap.yaml" $.Template.BasePath ) . | replace .Chart.AppVersion "" | sha256sum }}
matchingRulesConfig: {{ include (printf "%s/%s/%s" $.Template.BasePath $.Values.global.configMapsDirectory "matchingRules-configmap.yaml") . | replace .Chart.AppVersion "" | sha256sum }}
nodeAgentConfig: {{ include (printf "%s/node-agent/configmap.yaml" $.Template.BasePath) . | replace .Chart.AppVersion "" | sha256sum }}
operatorConfig: {{ include (printf "%s/operator/configmap.yaml" $.Template.BasePath) . | replace .Chart.AppVersion "" | sha256sum }}
otelConfig: {{ include (printf "%s/otel-collector/configmap.yaml" $.Template.BasePath) . | replace .Chart.AppVersion "" | sha256sum }}
proxySecret: {{ include (printf "%s/%s/%s" $.Template.BasePath $.Values.global.proxySecretDirectory "proxy-secret.yaml") . | replace .Chart.AppVersion "" | sha256sum }}
synchronizerConfig: {{ include (printf "%s/synchronizer/configmap.yaml" $.Template.BasePath) . | replace .Chart.AppVersion "" | sha256sum }}
{{- end -}}


{{- define "configurations" -}}
{{- $createCloudSecret := (empty .Values.credentials.cloudSecret) -}}
{{- $ksOtel := empty .Values.otelCollector.disable -}}
{{- $otel := not (empty .Values.configurations.otelUrl) -}}
{{- $submit := not (empty .Values.server) -}}
{{- $virtualCrds := not (empty .Values.storage.forceVirtualCrds) -}}
continuousScan: {{ and (eq .Values.capabilities.continuousScan "enable") (not $submit) }}
createCloudSecret: {{ $createCloudSecret }}
ksOtel: {{ and $ksOtel $submit }}
otel: {{ $otel }}
otelPort : {{ if $otel }}{{ splitList ":" .Values.configurations.otelUrl | last }}{{ else }}""{{ end }}
runtimeObservability: {{ eq .Values.capabilities.runtimeObservability "enable" }}
backendStorageEnabled: {{ eq (index .Values.capabilities "backend-storage" | default "") "enable" }}
virtualCrds: {{ or $virtualCrds (not $submit) }}
submit: {{ $submit }}
  {{- if $submit -}}
    {{- if and (empty .Values.account) $createCloudSecret -}}
      {{- fail "submitting is enabled but value for account is not defined: please register at https://cloud.armosec.io to get yours and re-run with  --set account=<your Guid>" }}
    {{- end -}}
    {{- if and (empty .Values.accessKey) $createCloudSecret -}}
      {{- fail "submitting is enabled but value for accessKey is not defined: To obtain an access key, go to 'Settings' -> 'Agent Access Keys' at https://cloud.armosec.io and re-run with  --set accessKey=<your key>" }}
    {{- end -}}
    {{- if empty .Values.clusterName -}}
      {{- fail "value for clusterName is not defined: re-run with  --set clusterName=<your cluster name>" }}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "components" -}}
{{- $configurations := fromYaml (include "configurations" .) }}
{{- $nodeScanEnabled := and (eq .Values.capabilities.nodeScan "enable") (not $configurations.backendStorageEnabled) }}
{{- $configurationScanEnabled := and (eq .Values.capabilities.configurationScan "enable") (not $configurations.backendStorageEnabled) }}
{{- $vulnerabilityScanEnabled := and (eq .Values.capabilities.vulnerabilityScan "enable") (not $configurations.backendStorageEnabled) }}
hostScanner:
  enabled: {{ $nodeScanEnabled }}
kubescape:
  enabled: {{ $configurationScanEnabled }}
kubescapeScheduler:
  enabled: {{ $configurationScanEnabled }}
kubevuln:
  enabled: {{ $vulnerabilityScanEnabled }}
kubevulnScheduler:
  enabled: {{ $vulnerabilityScanEnabled }}
nodeAgent:
  enabled: {{ or
   (eq .Values.capabilities.relevancy "enable")
   (eq .Values.capabilities.runtimeObservability "enable")
   (eq .Values.capabilities.networkPolicyService "enable")
   (eq .Values.capabilities.runtimeDetection "enable")
   (eq .Values.capabilities.malwareDetection "enable")
   (eq .Values.capabilities.nodeProfileService "enable")
   (eq .Values.capabilities.seccompProfileService "enable")
  }}
operator:
  enabled: {{ eq .Values.capabilities.operator "enable" }}
otelCollector:
  enabled: {{ and (empty .Values.otelCollector.disable) (or $configurations.ksOtel $configurations.otel) }}
serviceDiscovery:
  enabled: {{ $configurations.submit }}
storage:
  enabled: {{ not $configurations.backendStorageEnabled }}
prometheusExporter:
  enabled: {{ eq .Values.capabilities.prometheusExporter "enable" }}
cloudSecret:
  create: {{ $configurations.createCloudSecret }}
  name: {{ if $configurations.createCloudSecret }}"cloud-secret"{{ else }}{{ .Values.credentials.cloudSecret }}{{ end }}
synchronizer:
  enabled: {{ $configurations.submit }}
clamAV:
  enabled: {{ eq .Values.capabilities.malwareDetection "enable" }}
sbomScanner:
  enabled: {{ and (eq .Values.capabilities.nodeSbomGeneration "enable") .Values.nodeAgent.sbomScanner.enabled }}
customCaCertificates:
  name: custom-ca-certificates
autoUpdater:
  enabled: {{ eq .Values.capabilities.autoUpgrading "enable" }}
{{- end -}}

{{- define "admission-certificates" -}}
{{- $svcName := (printf "kubescape-admission-webhook.%s.svc" .Values.ksNamespace) -}}
{{- $ca := dict "Key" "mock-ca-key" "Cert" "mock-ca-cert" -}}
{{- $cert := dict "Key" "mock-cert-key" "Cert" "mock-cert-cert" -}}
{{- if not .Values.unittest }}
  {{- $existingCASecret := (lookup "v1" "Secret" .Values.ksNamespace "kubescape-admission-ca") -}}
  {{- if and $existingCASecret $existingCASecret.data -}}
    {{- $_ := set $ca "Key" (index $existingCASecret.data "tls.key" | b64dec) -}}
    {{- $_ := set $ca "Cert" (index $existingCASecret.data "tls.crt" | b64dec) -}}
    {{- $existingCA := buildCustomCert ($ca.Cert | b64enc) ($ca.Key | b64enc) -}}
    {{/* Leaf cert validity: 10 years (3650 days). After expiry, delete the kubescape-admission-ca Secret and run helm upgrade to regenerate. */}}
    {{- $generatedCert := genSignedCert $svcName nil (list $svcName) 3650 $existingCA -}}
    {{- $_ := set $cert "Key" $generatedCert.Key -}}
    {{- $_ := set $cert "Cert" $generatedCert.Cert -}}
  {{- else -}}
    {{/* CA and leaf cert validity: 10 years (3650 days). After expiry, delete the kubescape-admission-ca Secret and run helm upgrade to regenerate. */}}
    {{- $generatedCA := genCA (printf "*.%s.svc" .Values.ksNamespace) 3650 -}}
    {{- $generatedCert := genSignedCert $svcName nil (list $svcName) 3650 $generatedCA -}}
    {{- $_ := set $ca "Key" $generatedCA.Key -}}
    {{- $_ := set $ca "Cert" $generatedCA.Cert -}}
    {{- $_ := set $cert "Key" $generatedCert.Key -}}
    {{- $_ := set $cert "Cert" $generatedCert.Cert -}}
  {{- end -}}
{{- end -}}
{{- $certData := dict "ca" $ca "cert" $cert -}}
{{- toYaml $certData -}}
{{- end -}}
