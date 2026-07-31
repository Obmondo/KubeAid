{{/* vim: set filetype=mustache: */}}

{{/*
Name of the PVC holding the Puppet code tree. Single source of truth — the
operator consumes it via openvox-stack.config.code.claimName, gfetch and
puppet-agent-exporter mount it directly.
*/}}
{{- define "openvox.codeClaimName" -}}
{{- index .Values "openvox-stack" "config" "code" "claimName" -}}
{{- end -}}

{{/*
Service the operator creates for a Pool. The Pool CR is named
<release>-<pool>, and the Pool controller names the Service after the CR
(svcName := pool.Name). Port is always named "https".
*/}}
{{- define "openvox.poolServiceName" -}}
{{- printf "%s-%s" .root.Release.Name .pool -}}
{{- end -}}

{{/*
Service the operator creates for the Database CR (svcName := db.Name).
*/}}
{{- define "openvox.databaseServiceName" -}}
{{- index .Values "openvox-stack" "database" "name" -}}
{{- end -}}
