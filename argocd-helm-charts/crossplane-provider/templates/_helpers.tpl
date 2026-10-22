{{/*
ArgoCD sync-wave annotations. The chart is synced as one Application, so ordering between
Provider packages (whose CRDs do not exist before the Provider is Installed and Healthy) and the
resources using those CRDs is expressed with sync waves. Waves 1 and up also skip ArgoCD's dry
run for kinds whose CRD is not on the cluster yet.
*/}}
{{- define "crossplane-provider.wave0" -}}
argocd.argoproj.io/sync-wave: "0"
{{- end }}

{{- define "crossplane-provider.wave1" -}}
argocd.argoproj.io/sync-wave: "1"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{- define "crossplane-provider.wave2" -}}
argocd.argoproj.io/sync-wave: "2"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{/*
Wave 3 is for composite resources (XRs) this chart creates itself: their CRD is created by
Crossplane from the XRD in wave 1, and the Composition they are rendered by lands in wave 2.
*/}}
{{- define "crossplane-provider.wave3" -}}
argocd.argoproj.io/sync-wave: "3"
argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
{{- end }}

{{/*
Non-empty when at least one Composition this chart ships is switched on, i.e. when the
composition pipeline Functions have to be installed.
*/}}
{{- define "crossplane-provider.compositionsEnabled" -}}
{{- $azure := .Values.providers.azure -}}
{{- $keycloak := .Values.providers.keycloak -}}
{{- $netbird := .Values.providers.netbird -}}
{{- if and $azure.enabled (or $azure.compositions.workloadIdentityInfrastructure.enabled $azure.compositions.disasterRecoveryInfrastructure.enabled) -}}
true
{{- else if and $keycloak.enabled (or $keycloak.obmondoKeycloakGroupsPropagation.enabled $keycloak.argocdClient.enabled $keycloak.grafanaClient.enabled $keycloak.openobserveClient.enabled) -}}
true
{{- else if and $netbird.enabled $netbird.keycloakIntegration.enabled -}}
true
{{- end -}}
{{- end }}

{{/*
Namespace every Keycloak resource this chart renders is created in: the namespace holding the
Secrets those resources read (client credentials, initial passwords), because Crossplane v2
managed resources resolve Secret references in their own namespace. Defaults to the release
namespace.
*/}}
{{- define "crossplane-provider.keycloak.namespace" -}}
{{- .Values.providers.keycloak.namespace | default .Release.Namespace -}}
{{- end }}

{{/*
The Keycloak realm every Keycloak resource this chart renders belongs to. The realm itself is not
managed here; KubeAid's keycloakx chart creates it.
*/}}
{{- define "crossplane-provider.keycloak.realm" -}}
{{- required "providers.keycloak.realm is required by the Keycloak resources this chart renders" .Values.providers.keycloak.realm -}}
{{- end }}
