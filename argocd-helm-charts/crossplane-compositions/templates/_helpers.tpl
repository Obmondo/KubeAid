{{/*
ArgoCD sync-wave annotations. The CRDs these objects need come from the Crossplane core, which is
a different Application, so everything here skips the ArgoCD dry run and this Application syncs
after the crossplane chart:

  0  Provider, DeploymentRuntimeConfig and Function packages
  1  ProviderConfig / ClusterProviderConfig and CompositeResourceDefinition
  2  Composition

ArgoCD ships a health check for pkg.crossplane.io/Provider which reports Progressing until the
package is Installed and Healthy, so wave 1 waits for the provider CRDs.
*/}}
{{- define "crossplane-compositions.wave0" -}}
argocd.argoproj.io/sync-wave: "0"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{- define "crossplane-compositions.wave1" -}}
argocd.argoproj.io/sync-wave: "1"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{- define "crossplane-compositions.wave2" -}}
argocd.argoproj.io/sync-wave: "2"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}
