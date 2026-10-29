{{- define "crossplane.wave1" -}}
argocd.argoproj.io/sync-wave: "1"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{- define "crossplane.wave2" -}}
argocd.argoproj.io/sync-wave: "2"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}
