{{/*
Return the proper image name. Constructs the image name out of a registry, repository and tag. 
The registry can be set globally as global.imageRegistry. Tag defaults to the Charts AppVersion 
{{ include "common.images.image" ( dict "imageRoot" .Values.path.to.the.image "global" $) }}
{{ include "common.images.image" ( dict "imageRoot" .Values.image "global" $) }}
*/}}
{{- define "ox-common.images.image" -}}
{{- $registryName := .imageRoot.registry | default .global.Values.defaultRegistry -}}
{{- $repositoryName := .imageRoot.repository -}}
{{- /* `default ""` so an absent tag key becomes "" rather than the string "<nil>", which would defeat the AppVersion fallback below */ -}}
{{- $tag := .imageRoot.tag | default "" | toString -}}
{{- if and .context (eq $tag "") -}}
    {{- $tag = .context.Chart.AppVersion -}}
{{ end }}
{{- if .global -}}
{{- if .global.Values.global }}
    {{- if .global.Values.global.imageRegistry }}
     {{- $registryName = .global.Values.global.imageRegistry -}}
    {{- end -}}
{{- end -}}
{{- end -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else -}}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}
{{- end -}}