{{/* Supported experimental path: a single DaemonSet on explicitly selected nodes. */}}
{{- define "gvisorStart.validate" -}}
{{- $cfg := .Values.nodeAgent.gVisorStart -}}
{{- if $cfg.enabled -}}
{{- $components := fromYaml (include "components" .) -}}
{{- if not $components.nodeAgent.enabled -}}
{{- fail "nodeAgent.gVisorStart requires a capability that enables node-agent" -}}
{{- end -}}
{{- if or .Values.nodeAgent.autoscaler.enabled .Values.nodeAgent.multipleDaemonSets.enabled .Values.capabilities.testing.nodeAgentMultiplication.enabled -}}
{{- fail "nodeAgent.gVisorStart currently supports only the single DaemonSet deployment" -}}
{{- end -}}
{{- if not .Values.nodeAgent.nodeSelector -}}
{{- fail "nodeAgent.gVisorStart requires nodeAgent.nodeSelector to select prepared Linux nodes" -}}
{{- end -}}
{{- if ne (index .Values.nodeAgent.nodeSelector "kubernetes.io/os" | default "") "linux" -}}
{{- fail "nodeAgent.gVisorStart requires nodeAgent.nodeSelector kubernetes.io/os=linux" -}}
{{- end -}}
{{- if lt (len .Values.nodeAgent.nodeSelector) 2 -}}
{{- fail "nodeAgent.gVisorStart requires a nodeAgent.nodeSelector label for prepared nodes in addition to kubernetes.io/os" -}}
{{- end -}}
{{- if not .Values.configurations.otelUrl -}}
{{- fail "nodeAgent.gVisorStart requires configurations.otelUrl for OTLP log export" -}}
{{- end -}}
{{- if hasKey (default dict .Values.nodeAgent.config.extra) "gVisorStart" -}}
{{- fail "configure gVisorStart through nodeAgent.gVisorStart, not nodeAgent.config.extra.gVisorStart" -}}
{{- end -}}
{{- $dir := $cfg.socketDirectory -}}
{{- if or (not (isAbs $dir)) (ne (clean $dir) $dir) (lt (len (splitList "/" $dir)) 3) -}}
{{- fail "nodeAgent.gVisorStart.socketDirectory must be a clean absolute dedicated host directory" -}}
{{- end -}}
{{- if or (not $cfg.runtimeHandler) (regexMatch "[[:space:]]" $cfg.runtimeHandler) -}}
{{- fail "nodeAgent.gVisorStart.runtimeHandler must be a nonempty runtime handler name without whitespace" -}}
{{- end -}}
{{- if and $cfg.runtimeEndpoint (not (isAbs $cfg.runtimeEndpoint)) -}}
{{- fail "nodeAgent.gVisorStart.runtimeEndpoint must be empty or an absolute local CRI socket path" -}}
{{- end -}}
{{- range concat .Values.volumes .Values.nodeAgent.volumes .Values.volumeMounts .Values.nodeAgent.volumeMounts -}}
{{- if or (eq (.name | default "") "gvisor-start") (eq (.mountPath | default "") $dir) -}}
{{- fail "gvisor-start volume name and socketDirectory mountPath are reserved while nodeAgent.gVisorStart is enabled" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
