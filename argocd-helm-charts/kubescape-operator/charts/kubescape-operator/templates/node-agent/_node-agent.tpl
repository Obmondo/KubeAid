{{/*
Node Agent shared template definitions.
This is the single source of truth for node-agent DaemonSet configuration.
Used by: daemonset.yaml, daemonsets.yaml, and template-configmap.yaml
*/}}

{{/*
Node Agent Resources
Parameters:
  - autoscalerMode: boolean - if true, outputs Go template placeholders
  - resources: the resources object to use (when autoscalerMode is false)
*/}}
{{- define "node-agent.resources" -}}
{{- if .autoscalerMode }}
requests:
  cpu: "{{`{{ .Resources.Requests.CPU }}`}}"
  memory: "{{`{{ .Resources.Requests.Memory }}`}}"
limits:
  cpu: "{{`{{ .Resources.Limits.CPU }}`}}"
  memory: "{{`{{ .Resources.Limits.Memory }}`}}"
{{- else }}
{{ toYaml .resources | trim }}
{{- end }}
{{- end -}}

{{/*
Node Agent Environment Variables
Parameters:
  - Values: .Values
  - components: $components
  - no_proxy_envar_list: the no_proxy list
  - autoscalerMode: boolean
  - testingMode: boolean - for MULTIPLY env var
*/}}
{{- define "node-agent.env" -}}
{{- if .autoscalerMode }}
- name: GOMEMLIMIT
  value: "{{`{{ .GoMemLimit }}`}}"
{{- else }}
{{- $memory := .Values.nodeAgent.resources.limits.memory -}}
{{- if .resources -}}
{{- if .resources.limits -}}
{{- if .resources.limits.memory -}}
{{- $memory = .resources.limits.memory -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $memory }}
- name: GOMEMLIMIT
  value: {{ include "kubescape-operator.gomemlimit" (dict "memory" $memory "percentage" .Values.nodeAgent.gomemlimitPercentage) | quote }}
{{- end }}
{{- end }}
- name: HOST_ROOT
  value: "/host"
- name: KS_LOGGER_LEVEL
  value: "{{ .Values.logger.level }}"
- name: KS_LOGGER_NAME
  value: "{{ .Values.logger.name }}"
{{- if .Values.configurations.otelUrl }}
- name: OTEL_COLLECTOR_SVC
  value: {{ .Values.configurations.otelUrl }}
{{- end }}
{{- if eq .Values.nodeAgent.config.prometheusExporter "enable" }}
- name: OTEL_METRICS_EXPORTER
  value: "prometheus"
{{- end }}
{{- if .components.sbomScanner.enabled }}
- name: SBOM_SCANNER_SOCKET
  value: "/sbom-comm/scanner.sock"
- name: SCANNER_MEMORY_LIMIT
  value: "{{ .Values.nodeAgent.sbomScanner.resources.limits.memory }}"
{{- end }}
{{- if ne .Values.global.overrideRuntimePath "" }}
- name: RUNTIME_PATH
  value: "{{ .Values.global.overrideRuntimePath }}"
{{- end }}
{{- if ne .Values.global.httpsProxy "" }}
- name: HTTPS_PROXY
  value: "{{ .Values.global.httpsProxy }}"
- name: no_proxy
  value: "{{ .no_proxy_envar_list }}"
{{- end }}
{{- if .Values.nodeAgent.config.skipKernelVersionCheck }}
- name: SKIP_KERNEL_VERSION_CHECK
  value: "true"
{{- end }}
{{- if .Values.nodeAgent.config.malwareScanAllFiles }}
- name: MALWARE_SCAN_ALL_FILES
  value: "true"
{{- end }}
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: NAMESPACE_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: KUBELET_ROOT
  value: "/var/lib/kubelet"
{{- if and .testingMode .Values.capabilities.testing.nodeAgentMultiplication.enabled }}
- name: MULTIPLY
  value: "true"
{{- end }}
- name: AGENT_VERSION
  value: "{{ .Values.nodeAgent.image.tag }}"
{{- if .Values.server }}
- name: API_URL
  value: "https://{{ .Values.server }}"
{{- end }}
{{- range .Values.nodeAgent.env }}
{{- if .autoscalerMode }}
- {{ toYaml . | nindent 2 | trim }}
{{- else }}
- name: {{ .name }}
{{- if .value }}
  value: "{{ .value }}"
{{- end }}
{{- if .valueFrom }}
  valueFrom:
{{ toYaml .valueFrom | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Node Agent Volume Mounts
Parameters:
  - Values: .Values
  - components: $components
*/}}
{{- define "node-agent.volumeMounts" -}}
{{- include "apiauth.callerVolumeMount" . }}
{{- if .Values.nodeAgent.gVisorStart.enabled }}
- name: gvisor-start
  mountPath: {{ .Values.nodeAgent.gVisorStart.socketDirectory | quote }}
  readOnly: false
{{- end }}
{{- if .Values.namespaceFilters.enabled }}
- name: namespace-filters
  mountPath: /etc/namespace-filters
  readOnly: true
{{- end }}
{{- if .Values.volumeMounts }}
{{ toYaml .Values.volumeMounts | trim }}
{{- end }}
{{- if .Values.nodeAgent.volumeMounts }}
{{ toYaml .Values.nodeAgent.volumeMounts | trim }}
{{- end }}
{{- if .components.sbomScanner.enabled }}
- name: sbom-comm
  mountPath: /sbom-comm
{{- end }}
- name: {{ .components.cloudSecret.name }}
  mountPath: /etc/credentials
  readOnly: true
- name: {{ .Values.global.cloudConfig }}
  mountPath: /etc/config/clusterData.json
  readOnly: true
  subPath: "clusterData.json"
- name: config
  mountPath: /etc/config/config.json
  readOnly: true
  subPath: "config.json"
{{- if ne .Values.global.proxySecretFile "" }}
- name: proxy-secret
  mountPath: /etc/ssl/certs/proxy.crt
  subPath: proxy.crt
  readOnly: true
{{- end }}
{{- if .Values.global.overrideDefaultCaCertificates.enabled }}
- name: custom-ca-certificates
  mountPath: /etc/ssl/certs/ca-certificates.crt
  subPath: ca-certificates.crt
  readOnly: true
{{- end }}
{{- if .Values.global.extraCaCertificates.enabled }}
{{- range $key, $value := (lookup "v1" "Secret" .Values.ksNamespace .Values.global.extraCaCertificates.secretName).data }}
- name: extra-ca-certificates
  mountPath: /etc/ssl/certs/{{ $key }}
  subPath: {{ $key }}
  readOnly: true
{{- end }}
{{- end }}
{{- end -}}

{{/*
Node Agent Container
Parameters:
  - Values: .Values
  - components: $components
  - no_proxy_envar_list: the no_proxy list
  - autoscalerMode: boolean
  - testingMode: boolean
  - resources: resources object (when autoscalerMode is false)
  - indent: base indentation level
*/}}
{{- define "node-agent.container" -}}
- name: {{ .Values.nodeAgent.name }}
  image: "{{ .Values.nodeAgent.image.repository }}:{{ .Values.nodeAgent.image.tag }}"
  imagePullPolicy: {{ .Values.nodeAgent.image.pullPolicy }}
  livenessProbe:
    httpGet:
      path: /livez
      port: 7888
    periodSeconds: 3
  readinessProbe:
    httpGet:
      path: /readyz
      port: 7888
    periodSeconds: 3
  startupProbe:
    httpGet:
      path: /readyz
      port: 7888
    periodSeconds: 10
    failureThreshold: 30
    timeoutSeconds: 1
  resources:
    {{- include "node-agent.resources" (dict "autoscalerMode" .autoscalerMode "resources" .resources) | nindent 4 }}
  env:
    {{- include "node-agent.env" (dict "Values" .Values "components" .components "no_proxy_envar_list" .no_proxy_envar_list "autoscalerMode" .autoscalerMode "testingMode" .testingMode "resources" .resources) | nindent 4 }}
  securityContext:
    runAsUser: 0
    privileged: {{ .Values.nodeAgent.privileged }}
    capabilities:
      add:
        - SYS_ADMIN
        - SYS_PTRACE
        - NET_ADMIN
        - SYSLOG
        - SYS_RESOURCE
        - IPC_LOCK
        - NET_RAW
    seLinuxOptions:
      {{- if .autoscalerMode }}
      type: "{{`{{ .SELinuxType }}`}}"
      {{- else }}
      type: {{ .Values.nodeAgent.seLinuxType }}
      {{- end }}
  volumeMounts:
    {{- include "node-agent.volumeMounts" (dict "Values" .Values "components" .components) | nindent 4 }}
{{- end -}}

{{/*
SBOM Scanner Sidecar Container (optional)
Parameters:
  - Values: .Values
  - components: $components
  - no_proxy_envar_list: the no_proxy list
*/}}
{{- define "node-agent.sbomScannerContainer" -}}
{{- if .components.sbomScanner.enabled }}
- name: {{ .Values.nodeAgent.sbomScanner.name }}
  image: "{{ .Values.nodeAgent.sbomScanner.image.repository }}:{{ .Values.nodeAgent.sbomScanner.image.tag | default .Values.nodeAgent.image.tag }}"
  imagePullPolicy: {{ .Values.nodeAgent.sbomScanner.image.pullPolicy }}
  {{- if .Values.nodeAgent.sbomScanner.command }}
  command: {{ toYaml .Values.nodeAgent.sbomScanner.command | nindent 4 }}
  {{- end }}
  securityContext:
    runAsUser: 0
    runAsGroup: 0
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop: ["ALL"]
  resources:
{{ toYaml .Values.nodeAgent.sbomScanner.resources | indent 4 }}
  env:
    {{- if .Values.nodeAgent.sbomScanner.resources.limits.memory }}
    - name: GOMEMLIMIT
      value: {{ include "kubescape-operator.gomemlimit" (dict "memory" .Values.nodeAgent.sbomScanner.resources.limits.memory "percentage" .Values.nodeAgent.gomemlimitPercentage) | quote }}
    {{- end }}
    - name: SOCKET_PATH
      value: "/sbom-comm/scanner.sock"
    - name: HOST_ROOT
      value: "/host"
    {{- if .Values.configurations.otelUrl }}
    - name: OTEL_COLLECTOR_SVC
      value: {{ .Values.configurations.otelUrl }}
    {{- end }}
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: CLUSTER_NAME
      value: "{{ .Values.clusterName }}"
    {{- if ne .Values.global.httpsProxy "" }}
    - name: HTTPS_PROXY
      value: "{{ .Values.global.httpsProxy }}"
    - name: no_proxy
      value: "{{ .no_proxy_envar_list }}"
    {{- end }}
  volumeMounts:
  {{- if .Values.nodeAgent.sbomScanner.volumeMounts }}
    {{- toYaml .Values.nodeAgent.sbomScanner.volumeMounts | nindent 4 }}
  {{- end }}
  {{- if ne .Values.global.proxySecretFile "" }}
    - name: proxy-secret
      mountPath: /etc/ssl/certs/proxy.crt
      subPath: proxy.crt
      readOnly: true
  {{- end }}
  {{- if .Values.global.overrideDefaultCaCertificates.enabled }}
    - name: custom-ca-certificates
      mountPath: /etc/ssl/certs/ca-certificates.crt
      subPath: ca-certificates.crt
      readOnly: true
  {{- end }}
  {{- if .Values.global.extraCaCertificates.enabled }}
  {{- range $key, $value := (lookup "v1" "Secret" .Values.ksNamespace .Values.global.extraCaCertificates.secretName).data }}
    - name: extra-ca-certificates
      mountPath: /etc/ssl/certs/{{ $key }}
      subPath: {{ $key }}
      readOnly: true
  {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Node Agent Init Containers
Parameters:
  - Values: .Values
  - components: $components
  - no_proxy_envar_list: the no_proxy list
*/}}
{{- define "node-agent.initContainers" -}}
{{- if .Values.nodeAgent.startupJitterContainer.enabled }}
- name: startup-jitter
  image: {{ .Values.nodeAgent.startupJitterContainer.image.repository | default "busybox" }}:{{ .Values.nodeAgent.startupJitterContainer.image.tag | default "latest" }}
  command:
  - /bin/sh
  - -c
  - |
    SLEEP_TIME=$(( $RANDOM % {{ .Values.nodeAgent.startupJitterContainer.maxStartupJitter }} ))
    echo "Pod $(hostname) will sleep for $SLEEP_TIME seconds"
    sleep $SLEEP_TIME
    echo "Pod $(hostname) finished sleeping after $SLEEP_TIME seconds"
{{- end }}
{{- end -}}

{{/*
Node Agent Volumes
Parameters:
  - Values: .Values
  - components: $components
*/}}
{{- define "node-agent.volumes" -}}
{{- $filters := fromYaml (include "namespaceFilters.config" .) -}}
{{- include "apiauth.callerVolume" . }}
{{- if .Values.nodeAgent.gVisorStart.enabled }}
- name: gvisor-start
  hostPath:
    path: {{ .Values.nodeAgent.gVisorStart.socketDirectory | quote }}
    type: Directory
{{- end }}
{{- if $filters.enabled }}
- name: namespace-filters
  configMap:
    name: {{ $filters.name | quote }}
    optional: false
    items:
    - key: namespaceFilters.json
      path: namespaceFilters.json
{{- end }}
{{- if .Values.nodeAgent.volumes }}
{{ toYaml .Values.nodeAgent.volumes | trim }}
{{- end }}
{{- if .Values.volumes }}
{{ toYaml .Values.volumes | trim }}
{{- end }}
{{- if .components.sbomScanner.enabled }}
{{- if .Values.nodeAgent.sbomScanner.volumes }}
{{ toYaml .Values.nodeAgent.sbomScanner.volumes | trim }}
{{- end }}
{{- end }}
- name: {{ .components.cloudSecret.name }}
  secret:
    secretName: {{ .components.cloudSecret.name }}
- name: {{ .Values.global.cloudConfig }}
  configMap:
    name: {{ .Values.global.cloudConfig }}
    items:
      - key: "clusterData"
        path: "clusterData.json"
- name: config
  configMap:
    name: {{ .Values.nodeAgent.name }}
    items:
      - key: "config.json"
        path: "config.json"
{{- if ne .Values.global.proxySecretFile "" }}
- name: proxy-secret
  secret:
    secretName: {{ .Values.global.proxySecretName }}
{{- end }}
{{- if .Values.global.overrideDefaultCaCertificates.enabled }}
- name: custom-ca-certificates
  secret:
    secretName: {{ .components.customCaCertificates.name }}
{{- end }}
{{- if .Values.global.extraCaCertificates.enabled }}
- name: extra-ca-certificates
  secret:
    secretName: {{ .Values.global.extraCaCertificates.secretName }}
{{- end }}
{{- end -}}

{{/*
Node Agent Pod Template Metadata Annotations
Parameters:
  - Values: .Values
  - checksums: $checksums
  - Capabilities: .Capabilities
  - autoscalerMode: boolean
  - nodeGroupLabel: string (for autoscaler mode)
*/}}
{{- define "node-agent.podAnnotations" -}}
{{- include "kubescape-operator.annotations" (dict "Values" .Values) }}
{{- with .Values.nodeAgent.podAnnotations }}
{{ toYaml . }}
{{- end }}
checksum/node-agent-config: {{ .checksums.nodeAgentConfig }}
checksum/cloud-secret: {{ .checksums.cloudSecret }}
checksum/cloud-config: {{ .checksums.cloudConfig }}
{{- if ne .Values.global.proxySecretFile "" }}
checksum/proxy-config: {{ .checksums.proxySecret }}
{{- end }}
{{- if lt (.Capabilities.KubeVersion.Minor | int) 30 }}
container.apparmor.security.beta.kubernetes.io/{{ .Values.nodeAgent.name }}: unconfined
{{- end }}
{{- if eq .Values.configurations.prometheusAnnotations "enable" }}
prometheus.io/path: /metrics
prometheus.io/port: "8080"
prometheus.io/scrape: "true"
{{- end }}
{{- end -}}

{{/*
Node Agent Pod Template Metadata Labels
Parameters:
  - Chart: .Chart
  - Release: .Release
  - Values: .Values
  - components: $components
  - autoscalerMode: boolean
  - nodeGroupLabel: string (for autoscaler mode)
*/}}
{{- define "node-agent.podLabels" -}}
{{- include "kubescape-operator.labels" (dict "Chart" .Chart "Release" .Release "Values" .Values "app" .Values.nodeAgent.name "tier" .Values.global.namespaceTier) }}
{{- with .Values.nodeAgent.podLabels }}
{{ toYaml . }}
{{- end }}
{{- if .Values.nodeAgent.gke.allowlist.enabled }}
cloud.google.com/matching-allowlist: {{ .Values.nodeAgent.gke.allowlist.name }}
{{- end }}
kubescape.io/tier: "core"
{{- if .autoscalerMode }}
kubescape.io/node-group: "{{`{{ .NodeGroupLabel }}`}}"
{{- end }}
{{- if .Values.configurations.otelUrl }}
otel: enabled
{{- end }}
{{- end -}}

{{/*
Node Agent Pod Spec
Parameters:
  - Values: .Values
  - Chart: .Chart
  - Release: .Release
  - Capabilities: .Capabilities
  - components: $components
  - checksums: $checksums
  - no_proxy_envar_list: the no_proxy list
  - autoscalerMode: boolean
  - testingMode: boolean (for MULTIPLY env var and testing features)
  - resources: resources object (when autoscalerMode is false)
  - nodeSelector: optional custom nodeSelector
  - includeSbomScanner: boolean - whether to include SBOM scanner sidecar container
*/}}
{{- define "node-agent.podSpec" -}}
securityContext:
  {{- if ge (.Capabilities.KubeVersion.Minor | int) 30 }}
  appArmorProfile:
    type: Unconfined
  {{- end }}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
{{- if kindIs "string" .Values.imagePullSecrets }}
- name: {{ .Values.imagePullSecrets }}
{{- else }}
{{- range .Values.imagePullSecrets }}
- name: {{ . }}
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.nodeAgent.priorityClassName }}
priorityClassName: {{ .Values.nodeAgent.priorityClassName }}
{{- else if .Values.configurations.priorityClass.enabled }}
priorityClassName: kubescape-critical
{{- else if .Values.customScheduling.priorityClassName }}
priorityClassName: {{ .Values.customScheduling.priorityClassName }}
{{- end }}
serviceAccountName: {{ .Values.nodeAgent.name }}
automountServiceAccountToken: true
hostPID: true
{{- $initContainers := include "node-agent.initContainers" (dict "Values" .Values "components" .components "no_proxy_envar_list" .no_proxy_envar_list) | trim }}
{{- if $initContainers }}
initContainers:
{{ $initContainers | nindent 0 }}
{{- end }}
volumes:
{{ include "node-agent.volumes" (dict "Values" .Values "components" .components) | trim | nindent 0 }}
containers:
{{- if .includeSbomScanner }}
{{ include "node-agent.sbomScannerContainer" (dict "Values" .Values "components" .components "no_proxy_envar_list" .no_proxy_envar_list) | trim | nindent 0 }}
{{- end }}
{{ include "node-agent.container" (dict "Values" .Values "components" .components "no_proxy_envar_list" .no_proxy_envar_list "autoscalerMode" .autoscalerMode "testingMode" .testingMode "resources" .resources) | trim | nindent 0 }}
nodeSelector:
{{- if .autoscalerMode }}
  kubernetes.io/os: linux
{{`{{- if not .IsDefaultGroup }}`}}
  {{`{{ .NodeGroupLabelKey }}`}}: "{{`{{ .NodeGroupLabel }}`}}"
{{`{{- end }}`}}
{{- else if .nodeSelector }}
{{ toYaml .nodeSelector | nindent 2 }}
{{- else if .Values.nodeAgent.nodeSelector }}
{{ toYaml .Values.nodeAgent.nodeSelector | nindent 2 }}
{{- else if .Values.customScheduling.nodeSelector }}
{{ toYaml .Values.customScheduling.nodeSelector | nindent 2 }}
{{- end }}
affinity:
{{- if .autoscalerMode }}
{{- /* In autoscaler mode the default group (nodes missing the grouping label) must
       be targeted with a "DoesNotExist" node affinity, since a nodeSelector cannot
       match an absent label. Every other group's OS requirement is already enforced
       by the nodeSelector, so non-default groups keep honouring any user-provided
       affinity instead of being overridden. */}}
{{`{{- if .IsDefaultGroup }}`}}
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: {{`{{ .NodeGroupLabelKey }}`}}
          operator: DoesNotExist
{{`{{- else }}`}}
{{- if .Values.nodeAgent.affinity }}
{{ toYaml .Values.nodeAgent.affinity | nindent 2 }}
{{- else if .Values.customScheduling.affinity }}
{{ toYaml .Values.customScheduling.affinity | nindent 2 }}
{{- end }}
{{`{{- end }}`}}
{{- else if .Values.nodeAgent.affinity }}
{{ toYaml .Values.nodeAgent.affinity | nindent 2 }}
{{- else if .Values.customScheduling.affinity }}
{{ toYaml .Values.customScheduling.affinity | nindent 2 }}
{{- end }}
tolerations:
{{- if .Values.nodeAgent.tolerations }}
{{ toYaml .Values.nodeAgent.tolerations | nindent 2 }}
{{- else if .Values.customScheduling.tolerations }}
{{ toYaml .Values.customScheduling.tolerations | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Full Node Agent DaemonSet Spec (selector + template)
Parameters:
  - all parameters from node-agent.podSpec plus:
  - selectorLabels: additional selector labels (for autoscaler mode)
*/}}
{{- define "node-agent.daemonsetSpec" -}}
selector:
  matchLabels:
    {{- include "kubescape-operator.selectorLabels" (dict "Chart" .Chart "Release" .Release "Values" .Values "app" .Values.nodeAgent.name) | nindent 4 }}
    {{- if .autoscalerMode }}
    kubescape.io/node-group: "{{`{{ .NodeGroupLabel }}`}}"
    {{- end }}
template:
  metadata:
    annotations:
      {{- include "node-agent.podAnnotations" (dict "Values" .Values "checksums" .checksums "Capabilities" .Capabilities "autoscalerMode" .autoscalerMode) | nindent 6 }}
    labels:
      {{- include "node-agent.podLabels" (dict "Chart" .Chart "Release" .Release "Values" .Values "components" .components "autoscalerMode" .autoscalerMode) | nindent 6 }}
  spec:
    {{- include "node-agent.podSpec" (dict "Values" .Values "Chart" .Chart "Release" .Release "Capabilities" .Capabilities "components" .components "checksums" .checksums "no_proxy_envar_list" .no_proxy_envar_list "autoscalerMode" .autoscalerMode "testingMode" .testingMode "resources" .resources "nodeSelector" .nodeSelector "includeSbomScanner" .includeSbomScanner) | nindent 4 }}
{{- end -}}

