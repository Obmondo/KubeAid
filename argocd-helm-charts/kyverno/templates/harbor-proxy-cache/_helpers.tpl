{{- /*
Builds the chained replace_all(...) JMESPath call that strips every prefix in
a registry's `prefixes` list from an image expression, e.g. for
["index.docker.io/", "registry-1.docker.io/"] and "element.image":
  replace_all(replace_all(element.image, 'index.docker.io/', ''), 'registry-1.docker.io/', '')
Takes a 2-element list: [imageExpr, prefixes].
*/}}
{{- define "harborProxyCache.stripPrefixes" -}}
{{- $expr := index . 0 -}}
{{- range index . 1 -}}
{{- $expr = printf "replace_all(%s, '%s', '')" $expr . -}}
{{- end -}}
{{- $expr -}}
{{- end -}}
