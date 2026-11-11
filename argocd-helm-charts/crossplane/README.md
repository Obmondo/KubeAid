# Crossplane

Crossplane extends the Kubernetes API with CRDs that represent external infrastructure, and reconciles
them the way Kubernetes reconciles Pods and Deployments. This chart installs the Crossplane core, from the
upstream chart it vendors, and [Crossview](#crossview), the web UI for browsing Crossplane resources.

The providers, their provider configs, the composition functions and the composite APIs KubeAid models on
top of them are in [`crossplane-compositions`](../crossplane-compositions). Managed resources which are
not part of a composition (Scaleway buckets, the `groups` client scope, anything passed through as raw
YAML) are in [`crossplane-provider`](../crossplane-provider). Both sync after this Application.

## Why it's in KubeAid

On Azure, KubeAid provisions self-managed (CAPZ) clusters with ClusterAPI. CAPZ and its supporting
services (Velero for disaster recovery, workload identity for federated credentials) need Azure
infrastructure — resource groups, storage accounts, managed identities, role assignments — that ClusterAPI
does not provision. Crossplane fills that gap declaratively, inside the same GitOps flow as the rest of
the cluster. The same machinery then models Keycloak clients, identity brokering and the NetBird
integration, so an application's identity config is reviewed and rolled out like any other manifest.

## Prerequisites

- The ArgoCD Application must track resources by annotation
  (`configs.cm.application.resourceTrackingMethod: annotation` in [`argo-cd`](../argo-cd), KubeAid's
  default), so the charts which sync after it can adopt objects cleanly.

## Key values / KubeAid-specific configuration

### Common

| Value | Description | Default |
|---|---|---|
| `crossplane.*` | Passed to the vendored upstream Crossplane chart. KubeAid unsets the CPU limits on both containers; only memory stays capped | see `values.yaml` |

### Crossview

[Crossview](https://github.com/crossplane-contrib/crossview) is a web UI for browsing Crossplane
resources. It ships as the upstream `crossview` sub-chart.

| Value | Description | Default |
|---|---|---|
| `crossview.enabled` | Deploy Crossview | `true` |
| `crossview.config.server.auth.mode` | `none` (no login), `header` (identity from a trusted proxy header) or `session` (login, needs Postgres) | `none` |
| `crossview.config.database.enabled`, `crossview.database.enabled` | Use a database / deploy the upstream `postgres:latest` | `false` |
| `crossview.ingress` | Ingress, `traefik-cert-manager` class | disabled |

By default Crossview has no login and no database. Everyone who can reach it gets its read access to the
whole cluster, Secrets included, so expose it only on a private ingress, or use `header` mode behind an
auth proxy.

## Migration

The providers, provider configs, composition functions and composite APIs which this chart used to render
are now in [`crossplane-compositions`](../crossplane-compositions). Object names and specs are unchanged,
so ArgoCD adopts them; only the owning Application and the sync waves differ.

1. Move the `providers.*` values out of this chart's values file and into the
   `crossplane-compositions` one. They keep their paths.
2. Add the `crossplane-compositions` Application with a higher `kubeaid.io/sync-order` than this one, and
   sync it. It adopts the existing `Provider`, `DeploymentRuntimeConfig`, `Function`, `ProviderConfig`,
   XRD and `Composition` objects.
3. Sync `crossplane`, which then renders the core and Crossview only.

Do not delete the old Application cascading at any point: that would take the providers and every managed
resource behind them.

## Docs links

- [Crossplane providers](https://docs.crossplane.io/latest/concepts/providers/),
  [managed resources](https://docs.crossplane.io/latest/concepts/managed-resources/),
  [management policies](https://docs.crossplane.io/latest/concepts/managed-resources/#managementpolicies)
- [ArgoCD sync waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) and
  [sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#skip-dry-run-for-new-custom-resources-types)
- [Crossplane v2 composite resources](https://docs.crossplane.io/latest/concepts/composite-resources/)
  (namespaced XRs, `apiextensions.crossplane.io/v2`),
  [function-patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform)
  and [function-go-templating](https://github.com/crossplane-contrib/function-go-templating)
- [provider-scaleway](https://github.com/scaleway/crossplane-provider-scaleway),
  [provider-keycloak](https://github.com/crossplane-contrib/provider-keycloak)
- [Keycloak identity brokering](https://www.keycloak.org/docs/latest/server_admin/index.html#_identity_broker)
  and [NetBird with Keycloak](https://docs.netbird.io/selfhosted/identity-providers#keycloak)
- [Azure hosting (CAPZ + Crossplane)](../../docs/hosting/cloud-providers.md)
- Related: [`crossplane`](../crossplane), [`keycloakx`](../keycloakx), [`netbird`](../netbird)
