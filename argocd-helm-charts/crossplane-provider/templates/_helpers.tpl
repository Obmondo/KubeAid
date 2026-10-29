{{/*
ArgoCD sync-wave annotations. The managed resources in this chart need the CRDs which the
crossplane chart installs with the Provider packages, so they go in a late wave and skip the
ArgoCD dry run.
*/}}
{{- define "crossplane-provider.wave3" -}}
argocd.argoproj.io/sync-wave: "3"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{/*
Namespace every Keycloak resource this chart renders is created in: the namespace holding the
Secrets those resources read, because Crossplane v2 managed resources resolve Secret references
in their own namespace. Defaults to the release namespace.
*/}}
{{- define "crossplane-provider.keycloak.namespace" -}}
{{- .Values.providers.keycloak.namespace | default .Release.Namespace -}}
{{- end }}

{{/*
The Keycloak realm every Keycloak resource this chart renders belongs to.
*/}}
{{- define "crossplane-provider.keycloak.realm" -}}
{{- required "providers.keycloak.realm is required by the Keycloak resources this chart renders" .Values.providers.keycloak.realm -}}
{{- end }}
