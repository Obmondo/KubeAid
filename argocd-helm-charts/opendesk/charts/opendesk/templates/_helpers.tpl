{{/*
SPDX-FileCopyrightText: 2024 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-License-Identifier: Apache-2.0
*/}}
{{/*
include "yamlToArgs" (dict "map" . "path" "")
*/}}
{{- define "yamlToArgs" -}}
{{- $it := .map -}}
{{- $path := .path -}}
{{- $knd := kindOf .map -}}
{{- if eq $knd "map" }}
{{-   range (keys .map) }}
{{-   $k := . }}
{{-   $v := get $it . }}
{{-   $vk := kindOf $v }}
{{-   if eq $vk "map" }}
{{-     include "yamlToArgs" (dict "map" $v "path" (printf "%s%s." $path $k))}}
{{-   else }}
{{-     printf "%s%s=%v," $path $k $v }}
{{-   end }}
{{- end }}
{{- else }}
{{   . }}
{{- end }}
{{- end -}}
