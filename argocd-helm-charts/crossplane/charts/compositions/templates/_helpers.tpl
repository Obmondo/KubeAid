{{- define "compositions.wave1" -}}
argocd.argoproj.io/sync-wave: "1"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{- define "compositions.wave2" -}}
argocd.argoproj.io/sync-wave: "2"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{- define "compositions.wave3" -}}
argocd.argoproj.io/sync-wave: "3"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}
