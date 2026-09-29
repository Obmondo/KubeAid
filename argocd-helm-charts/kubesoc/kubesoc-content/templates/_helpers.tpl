{{/*
  Package files as a dict: ConfigMap key -> content. "/" in a package path is
  "__" in its key (a key cannot hold "/"); the reconciler maps it back.
*/}}
{{- define "kubesoc-content.files" -}}
{{- $out := dict -}}
{{- $globs := list "wazuh/rules/*.xml" "wazuh/decoders/*.xml" "wazuh/lists/*" "wazuh/agent-groups/*/agent.conf" "velociraptor/artifacts/*.yaml" "ai/prompts/*" "tenants/*/wazuh/rules/*.xml" "tenants/*/wazuh/decoders/*.xml" "tenants/*/wazuh/lists/*" "tenants/*/wazuh/agent-groups/*/agent.conf" -}}
{{- range $g := $globs -}}
{{- range $path, $_ := $.Files.Glob $g -}}
{{- $base := base $path -}}
{{- $isList := contains "/wazuh/lists/" (printf "/%s" $path) -}}
{{- if and $isList (not (regexMatch "^[-\\w]+$" $base)) -}}
{{- /* README.md and the like next to the lists; the API only takes [-\w]+ names. */ -}}
{{- else if hasPrefix "." $base -}}
{{- else -}}
{{- $_ := set $out (replace "/" "__" $path) ($.Files.Get $path) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}

{{- define "kubesoc-content.version" -}}
{{- .Files.Get "VERSION" | trim -}}
{{- end -}}
