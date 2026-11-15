{{/* Shared live-filter contract. Keep contents out of startup config/checksums. */}}
{{- define "namespaceFilters.config" -}}
{{- $settings := .Values.namespaceFilters -}}
{{- if not (kindIs "map" $settings) -}}
  {{- fail "namespaceFilters: expected a map with enabled and existingConfigMap" -}}
{{- end -}}
{{- if not (kindIs "bool" $settings.enabled) -}}
  {{- fail "namespaceFilters: enabled must be a Boolean" -}}
{{- end -}}
{{- if not (kindIs "string" $settings.existingConfigMap) -}}
  {{- fail "namespaceFilters: existingConfigMap must be a string" -}}
{{- end -}}
{{- $name := "kubescape-namespace-filters" -}}
{{- $lists := dict "includeNamespaces" (list) "excludeNamespaces" (list) -}}
{{- if $settings.enabled -}}
  {{- if ne $settings.existingConfigMap "" -}}
    {{- $name = $settings.existingConfigMap -}}
    {{- if or (gt (len $name) 253) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$" $name)) -}}
      {{- fail "namespaceFilters: existingConfigMap must be a Kubernetes DNS subdomain name (at most 253 characters)" -}}
    {{- end -}}
    {{- if eq $name "kubescape-namespace-filters" -}}
      {{- fail "namespaceFilters: kubescape-namespace-filters is reserved for Helm ownership; copy the live document to a separately named external ConfigMap before setting existingConfigMap" -}}
    {{- end -}}
  {{- end -}}
  {{- range $key := list "includeNamespaces" "excludeNamespaces" -}}
    {{- $value := index $.Values $key -}}
    {{- if not (kindIs "string" $value) -}}
      {{- fail (printf "namespaceFilters: %s must be a comma-separated string" $key) -}}
    {{- end -}}
    {{- range splitList "," $value -}}
      {{- $namespace := trim . -}}
      {{- if ne $namespace "" -}}
        {{- if or (gt (len $namespace) 63) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $namespace)) -}}
          {{- fail (printf "namespaceFilters: %s contains invalid exact namespace %q (expected a DNS label, at most 63 characters)" $key $namespace) -}}
        {{- end -}}
        {{- $_ := set $lists $key (append (index $lists $key) $namespace) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- $components := fromYaml (include "components" .) -}}
  {{- $reservedEnv := dict
      "nodeAgent" (list "NAMESPACEFILTERFILE" "CONFIG_DIR")
      "operator" (list "NAMESPACEFILTERCONFIGMAPNAME" "NAMESPACE")
      "synchronizer" (list "CONFIG" "CLUSTER_CONFIG" "INCLUSTER.NAMESPACEFILTERCONFIGMAPNAME" "INCLUSTER.NAMESPACE")
      "kubescape" (list "KS_NAMESPACE_FILTERS_FILE") -}}
  {{- range $component := list "nodeAgent" "operator" "synchronizer" "kubescape" -}}
    {{- if (index $components $component).enabled -}}
      {{- $values := index $.Values $component -}}
      {{- range $values.env -}}
        {{- if has .name (index $reservedEnv $component) -}}
          {{- fail (printf "namespaceFilters: %s.env entry %s overrides the live filter source or namespace; remove this entry" $component .name) -}}
        {{- end -}}
      {{- end -}}
      {{- if or (eq $component "nodeAgent") (eq $component "kubescape") -}}
        {{- $volumeSources := list (dict "path" "volumes" "items" $.Values.volumes) (dict "path" (printf "%s.volumes" $component) "items" $values.volumes) -}}
        {{- if and (eq $component "nodeAgent") $components.sbomScanner.enabled -}}
          {{- $volumeSources = append $volumeSources (dict "path" "nodeAgent.sbomScanner.volumes" "items" $values.sbomScanner.volumes) -}}
        {{- end -}}
        {{- range $source := $volumeSources -}}
          {{- range $source.items -}}
            {{- if eq .name "namespace-filters" -}}
              {{- fail (printf "namespaceFilters: %s uses reserved volume name namespace-filters; rename the custom volume" $source.path) -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
        {{- range $source := list (dict "path" "volumeMounts" "items" $.Values.volumeMounts) (dict "path" (printf "%s.volumeMounts" $component) "items" $values.volumeMounts) -}}
          {{- range $source.items -}}
            {{- if or (eq .name "namespace-filters") (eq (clean .mountPath) "/etc/namespace-filters") (hasPrefix "/etc/namespace-filters/" (clean .mountPath)) -}}
              {{- fail (printf "namespaceFilters: %s conflicts with reserved volume namespace-filters or mount directory /etc/namespace-filters; remove or relocate the custom mount" $source.path) -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
      {{- if eq $component "nodeAgent" -}}
        {{- range $key, $_ := $values.config.extra -}}
          {{- if eq (lower $key) "namespacefilterfile" -}}
            {{- fail "namespaceFilters: nodeAgent.config.extra.namespaceFilterFile overrides the live filter source; remove this entry" -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
enabled: {{ $settings.enabled }}
name: {{ $name | quote }}
includeNamespaces: {{ $lists.includeNamespaces | toJson }}
excludeNamespaces: {{ $lists.excludeNamespaces | toJson }}
{{- end -}}
