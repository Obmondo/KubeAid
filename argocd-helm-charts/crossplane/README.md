# Crossplane

Crossplane extends the Kubernetes API with CRDs that represent external infrastructure, and reconciles
them the way Kubernetes reconciles Pods and Deployments. This chart installs the Crossplane core (from the
upstream chart it vendors), every provider KubeAid supports, the provider configs and composition
functions they need, and the composite APIs KubeAid models on top of them — as ONE ArgoCD Application.

Providers are entries under `providers`, switched on from values the way `capi-cluster` enables its
infrastructure providers. The composite APIs live in the `compositions` sub-chart, behind
`compositions.enabled`:

```yaml
providers:
  azure:
    enabled: true

  scaleway:
    enabled: true

  keycloak:
    enabled: true

compositions:
  enabled: true
  keycloak:
    obmondoKeycloakGroupsPropagation:
      enabled: true
    argocdClient:
      enabled: true
  netbird:
    keycloakIntegration:
      enabled: true
```

Managed resources which are not part of a composition — Scaleway buckets, the `groups` client scope, and
anything passed through as raw YAML — are in [`crossplane-provider`](../crossplane-provider), a second
Application which syncs after this one.

## Why it's in KubeAid

On Azure, KubeAid provisions self-managed (CAPZ) clusters with ClusterAPI. CAPZ and its supporting
services (Velero for disaster recovery, workload identity for federated credentials) need Azure
infrastructure — resource groups, storage accounts, managed identities, role assignments — that ClusterAPI
does not provision. Crossplane fills that gap declaratively, inside the same GitOps flow as the rest of
the cluster. The same machinery then models Keycloak clients, identity brokering and the NetBird
integration, so an application's identity config is reviewed and rolled out like any other manifest.

## Prerequisites

- A credentials Secret per enabled provider in the release namespace, created out of band (typically by
  the cluster's sealed-secrets app): `azure-credentials`, `scaleway-credentials`, `keycloak-credentials`.
  The Secrets the Keycloak objects *read* (client secrets, initial passwords) are different ones, and live
  in the namespace those objects are created in.
- The ArgoCD Application must track resources by annotation
  (`configs.cm.application.resourceTrackingMethod: annotation` in [`argo-cd`](../argo-cd), KubeAid's
  default) and should carry a sync `retry` block, see [How ordering works](#how-ordering-works).

## Key values / KubeAid-specific configuration

### Common

| Value | Description | Default |
|---|---|---|
| `crossplane.*` | Passed to the vendored upstream Crossplane chart. KubeAid unsets the CPU limits on both containers; only memory stays capped | see `values.yaml` |
| `providers.<provider>.enabled` | Install that provider's package and provider config | `false` |
| `compositions.enabled` | Install the `compositions` sub-chart: the composition functions, and whichever composite APIs are switched on below | `false` |
| `compositions.<provider>.<api>.enabled` | Install that XRD + Composition. Needs the matching provider; the chart refuses to render when they disagree | `false` |

### `azure`

| Value | Description | Default |
|---|---|---|
| `compositions.azure.workloadIdentityInfrastructure.enabled` | Install the `WorkloadIdentityInfrastructure` XRD + Composition | `false` |
| `compositions.azure.disasterRecoveryInfrastructure.enabled` | Install the `DisasterRecoveryInfrastructure` XRD + Composition | `false` |
| `providers.azure.credentials.secretName` / `.secretKey` | Secret (release namespace) and key with the Service Principal credentials | `azure-credentials` / `credentials` |

The chart installs the five Azure providers (`azure-network`, `azure-storage`, `azure-managed-identity`,
`azure-ad`, `azure-authorization`; `azure-network` also pulls in `crossplane-contrib-provider-family-azure`
which handles authentication for the whole family), the three composition functions (`patch-and-transform`,
`go-templating`, `auto-ready`), the `default` `ProviderConfig`, and the two KubeAid composite APIs:

- `WorkloadIdentityInfrastructure` (`azure.kubeaid.org/v1alpha1`): given `subscriptionID`, `clusterName`,
  `location`, `aadApplicationPrincipalID` and `storageAccountName`, provisions a `ResourceGroup`, a Blob
  storage `Account` + `oidc-provider` `Container` (the OIDC issuer for workload identity), a `capi`
  `UserAssignedIdentity` with a `Contributor` role assignment, and federated identity credentials for CAPZ
  and Azure Service Operator.
- `DisasterRecoveryInfrastructure` (`azure.kubeaid.org/v1alpha1`): given `subscriptionID`, `clusterName`,
  `location` and `storageAccountName`, provisions `velero-backups` and `sealed-secrets-backups`
  `Container`s, a `velero` `UserAssignedIdentity` with a `Storage Blob Data Owner` role assignment, and a
  federated identity credential for the `velero` ServiceAccount.

Both compositions run `mode: Pipeline`, both XRDs use `defaultCompositionUpdatePolicy: Manual` (composition
changes need an explicit revision bump on existing claims), and the `ResourceGroup`, `Account` and
`Container` resources use the `Orphan` deletion policy. Unlike the old `crossplane-compositions` chart, the
`compositions.azure.*` switches actually work: the old chart's nested sub-chart conditions were resolved
against the wrong values path and always installed both APIs.

### `scaleway`

| Value | Description | Default |
|---|---|---|
| `providers.scaleway.provider.version` | Version `provider-scaleway` is pinned to; the package (`xpkg.upbound.io/scaleway/provider-scaleway`) is fixed in the chart | `v0.6.0` |
| `providers.scaleway.credentials.secretName` / `.secretKey` | Secret (release namespace) and key with the Scaleway API key | `scaleway-credentials` / `credentials` |

The provider runs with `--enable-management-policies` (a `DeploymentRuntimeConfig`), and every Scaleway
managed resource authenticates through the `default` `ClusterProviderConfig` this chart renders next to
the package. The buckets themselves live in [`crossplane-provider`](../crossplane-provider).

### `keycloak`

| Value | Description | Default |
|---|---|---|
| `providers.keycloak.credentials.secretName` / `.secretKey` | Secret (release namespace) and key with the Keycloak admin credentials | `keycloak-credentials` / `credentials` |
| `providers.keycloak.provider.version` | Version `provider-keycloak` is pinned to; the package (`xpkg.upbound.io/crossplane-contrib/provider-keycloak`) is fixed in the chart | `v2.18.0` |
| `providers.keycloak.realm` | Realm every Keycloak object this chart renders is created in. Required as soon as one of them is enabled | `""` |
| `providers.keycloak.namespace` | Namespace they are created in; has to be the namespace holding the Secrets they read | release namespace |
| `compositions.keycloak.obmondoKeycloakGroupsPropagation.enabled` | Obmondo's Keycloak as an upstream identity provider, propagating group membership into this realm | `false` |
| `compositions.keycloak.argocdClient.enabled` | `ArgoCDClient` XRD + Composition | `false` |
| `compositions.keycloak.grafanaClient.enabled` | `GrafanaClient` XRD + Composition | `false` |
| `compositions.keycloak.openobserveClient.enabled` | `OpenObserveClient` XRD + Composition | `false` |

The chart renders the provider package, the `DeploymentRuntimeConfig` that turns on management
policies, and the `default` `ClusterProviderConfig` reading the credentials Secret from the release
namespace. Namespaced managed resources use that `ClusterProviderConfig` unless they say otherwise, so
nothing in the compositions sets `providerConfigRef` — if a realm ever needs a second config, that is the
point to add it back.

The `Realm` itself is rendered by the [`keycloakx`](../keycloakx) chart. Crossplane v2 managed resources
are namespaced and resolve the Secrets they reference (client secrets, initial passwords) in their own
namespace, which is where the apps consuming those Secrets live. That is why the Keycloak objects go into
`providers.keycloak.namespace` — typically `keycloakx` — and not into the release namespace.

What this chart adds on top of the provider package are the composite APIs for the applications KubeAid
deploys. The `groups` client scope, and any other Keycloak managed resource which is not part of a
composition, live in [`crossplane-provider`](../crossplane-provider).

#### Group scopes

Consumers that authorize on group membership (the ArgoCD RBAC policy, NetBird's `jwt_groups_enabled`) read
a `groups` claim. Where the groups come from decides which switch you want — both can be on at once, and
they emit the same claim name:

| Switch | Groups it exposes |
|---|---|
| `providers.keycloak.groupsClientScope` (in [`crossplane-provider`](../crossplane-provider)) | Groups created in this Keycloak itself, through an `oidc-group-membership-mapper`. Renders a `ClientScope` plus its `ProtocolMapper` |
| `compositions.keycloak.obmondoKeycloakGroupsPropagation` | Groups a user belongs to in **Obmondo's** Keycloak |

Add a scope's name to the default scopes of the clients that need it. The `KeycloakIntegration` and
`ArgoCDClient` composite APIs take the brokered ones in `propagatedGroupScopes` and carry the realm's own
`groups` scope in their Composition already.

Keycloak has no built-in scope for group membership. Its only built-in `groups` claim is on the optional
`microprofile-jwt` scope, and that one carries realm **roles** (`oidc-usermodel-realm-role-mapper`), so it
is not a substitute.

#### Application clients

One composite API per application KubeAid deploys, all in `keycloak.kubeaid.org/v1alpha1`. The client ID,
access type, flows, default scopes, protocol mappers and roles are fixed in the Composition; the XR
carries only what differs per cluster — the realm, the callback URLs and the Secret with the client
secret:

| Composite API | Switch | What the Composition creates |
|---|---|---|
| `ArgoCDClient` | `compositions.keycloak.argocdClient.enabled` | `argocd` confidential `Client` (`webOrigins: ["*"]`) and its `ClientDefaultScopes`. ArgoCD's RBAC matches on the `groups` claim, so the scopes carry the realm's `groups` scope plus the XR's `propagatedGroupScopes` |
| `GrafanaClient` | `compositions.keycloak.grafanaClient.enabled` | `grafana` confidential `Client`, its `ClientDefaultScopes`, a `oidc-usermodel-client-role-mapper` emitting `resource_access.${client_id}.roles`, and the `Admin` / `Editor` / `Viewer` `Role`s. Grafana's `role_attribute_path` reads that claim, so it authorizes on client roles rather than groups |
| `OpenObserveClient` | `compositions.keycloak.openobserveClient.enabled` | `openobserve-dex` confidential `Client` (Authorization Code only — Dex sits in front of OpenObserve), its `ClientDefaultScopes`, `ClientOptionalScopes` with `offline_access` so Dex can get a refresh token, and a mapper emitting client roles as a `role` claim |

Assigning roles or group membership to users stays outside Crossplane, like realm users themselves.

A cluster's XRs live next to its other Keycloak manifests, in `providers.keycloak.namespace`. One client
usually backs the same app on every cluster in a fleet, hence the URI lists:

```yaml
apiVersion: keycloak.kubeaid.org/v1alpha1
kind: ArgoCDClient
metadata:
  name: argocd
  namespace: keycloakx
spec:
  realm: Kilroy
  validRedirectUris:
    - https://argocd.vpn.kilroy.eu/auth/callback
    - https://argocd.private.production.htz1.kilroy.eu/auth/callback
  validPostLogoutRedirectUris:
    - https://argocd.vpn.kilroy.eu
    - https://argocd.private.production.htz1.kilroy.eu
  clientSecret:
    name: argocd-client-credentials
    key: clientSecret
    version: 1
  propagatedGroupScopes:
    - obmondo-keycloak-groups
```

The client secret is **read** from that Secret, never generated by Keycloak, so the same Secret can be
handed to the application. It is a write-only field in Keycloak: after rotating the Secret, bump
`clientSecret.version` or the provider will not push the new value.

#### Obmondo group propagation

With `compositions.keycloak.obmondoKeycloakGroupsPropagation.enabled`, the realm delegates login to Obmondo's Keycloak
(`https://keycloak.vpn.obmondo.com/auth/realms/obmondo` by default) as an identity broker, so Obmondo's SREs
keep their group membership on Obmondo's side and the customer's clients see it as an ordinary `groups`
claim. It is the `ObmondoKeycloakGroupsPropagation` composite API (`keycloak.kubeaid.org/v1alpha1`), rendering
three objects through `patch-and-transform` (every upstream endpoint is formatted from `issuerURL`
rather than listed in values):

- an `IdentityProvider` with `providerId: keycloak-oidc` (not `oidc` — the upstream is another Keycloak),
  every endpoint derived from `issuerURL`, `syncMode: FORCE` so the brokered user is refreshed on every
  login, and the client credentials read from `credentialsSecret` (`obmondo-keycloak-credentials`, holding
  `clientId` and `clientSecret`, created out of band — typically by the cluster's sealed-secrets app);
- an `IdentityProviderMapper` (`oidc-user-attribute-idp-mapper`) storing the `groups` claim Obmondo sends
  on the brokered user, as the `idp-groups` user attribute;
- a `ClientScope` (`obmondo-keycloak-groups`) and its `ProtocolMapper`
  (`oidc-usermodel-attribute-mapper`), reading that attribute back out as a multivalued `groups` claim.

```yaml
providers:
  keycloak:
    enabled: true
    realm: Kilroy
    namespace: keycloakx
    obmondoKeycloakGroupsPropagation:
      enabled: true
      # Defaults worth knowing: issuerURL Obmondo's own realm URL, credentialsSecret
      # obmondo-keycloak-credentials.
```

The identity provider's alias (`Obmondo`), the `idp-groups` user attribute and the
`obmondo-keycloak-groups` client scope name are fixed in the Composition. The alias is part of the broker login URL
(`/realms/<realm>/broker/Obmondo/endpoint`) that Obmondo whitelists as a redirect URI on its side, so it
is a convention rather than a per-realm choice; renaming it recreates the identity provider and its
mapper, and needs Obmondo to update that redirect URI. The user attribute is internal to this
composition — the identity provider mapper writes it, the client scope's protocol mapper reads it, and
nothing on Obmondo's side knows the name.

### `compositions.netbird`

NetBird is not a Crossplane provider of its own. What it brings is the Keycloak side of a NetBird
installation, modelled as a Composition on top of `providers.keycloak` — so it needs
`providers.keycloak.enabled` (the chart refuses to render otherwise) and the realm to exist already.

| Value | Description | Default |
|---|---|---|
| `compositions.netbird.keycloakIntegration.enabled` | Install the `KeycloakIntegration` XRD + Composition | `false` |

The composite resource is written by the cluster operator, in the namespace which holds the Secrets it
names. Its spec:

| Field | Description |
|---|---|
| `realm` | Keycloak realm which holds the objects. Required |
| `dashboardURL` | Public URL of the NetBird dashboard. Required. Becomes the public client's root and base URL, and `<dashboardURL>/*` its redirect URIs |
| `initialNetBirdUser.*` | Account NetBird's management service authenticates as over the Keycloak Admin API (`IDP_SERVICE_ACCOUNT_USER` / `_PASSWORD`), and the admin logs into the dashboard as — the owner of the NetBird account. Username, optional profile fields, and the Secret with its initial password |
| `netbirdBackendClient.clientSecret.*` | Secret (`name` / `key`) with the confidential client's client secret, and the `version` to bump after rotating it. Its client ID and its `view-users` role on `realm-management` are fixed in the Composition |
| `netbirdClientClient.propagatedGroupScopes` | Client scopes carrying groups brokered from another IdP, appended to the public client's default scopes. Its client ID (`netbird-client`) and the `api` scope are fixed in the Composition |

The `KeycloakIntegration` composite API (`netbird.kubeaid.org/v1alpha1`) renders nine managed resources
through `patch-and-transform`. Each one is a static base manifest: the object names, the client IDs, the
flows and the client-secret Secret are written out in the Composition, and only what genuinely varies per
cluster — the realm, the namespace, the dashboard URL, the service account's profile and its password
Secret — is patched in from the XR:

- the `User` NetBird's management service authenticates as over the Keycloak Admin API — also the
  identity the admin logs into the dashboard with, which makes it the owner of the NetBird account. It
  carries `emailVerified: true` and `requiredActions: []` so Keycloak never attaches a VERIFY_EMAIL
  action or a profile-update step to it, and its initial password comes from
  `idpServiceAccount.initialPasswordSecret`;
- the confidential `Client` (`accessType: CONFIDENTIAL`, service accounts on), its `ClientDefaultScopes`,
  an **observe-only** `Client` for the realm's built-in `realm-management`, and a
  `ClientServiceAccountRole` granting its service account `view-users` on it — that is what lets NetBird
  list the realm's users;
- the public `Client` (`accessType: PUBLIC`, device-authorization and PKCE flows) with
  `<dashboardURL>/*` as its valid redirect and post-logout redirect URIs, its `ClientDefaultScopes`, the
  `api` `ClientScope` and the `oidc-audience-mapper` `ProtocolMapper` adding the NetBird client ID as an
  audience — NetBird rejects tokens that are not issued for it.

The client secret and the service account's initial password are **read** from Secrets in
`providers.keycloak.namespace`, never generated by Keycloak, so the same Secrets can be mounted into
NetBird itself (`IDP_CLIENT_MGMT_SECRET`, `IDP_SERVICE_ACCOUNT_PASSWORD`). The client secret is a
write-only field in Keycloak: after rotating that Secret, bump
`backendClient.clientSecret.version` or the provider will not push the new value.

Both `ClientDefaultScopes` list their scopes in the Composition itself: `email`, `profile` and Keycloak's
built-ins (`acr`, `basic`, `web-origins`, `roles`) for the confidential client, the same plus the `api`
and `groups` scopes for the public one.

Scopes carrying groups **propagated from another IdP** are the exception, because Keycloak rejects a
default scope that does not exist in the realm and which ones exist differs per cluster. They are named in
the XR's `dashboardClient.propagatedGroupScopes` and **appended** to the public client's list — a patch
with `policy.mergeOptions.appendSlice: true`, so the base list stays the same everywhere:

```yaml
spec:
  dashboardClient:
    propagatedGroupScopes:              # must name scopes the realm actually has
      - obmondo-keycloak-groups         # from providers.keycloak.obmondoKeycloakGroupsPropagation
```

A scope from any other brokered IdP goes in the same list. NetBird only acts on the claim they emit once
`groups_propagation_enabled`, `jwt_groups_enabled` and `jwt_groups_claim_name: groups` are set on the
NetBird account.

```yaml
providers:
  keycloak:
    enabled: true
    realm: Kilroy
    namespace: keycloakx

  netbird:
    enabled: true
    keycloakIntegration:
      enabled: true
      dashboardURL: https://netbird.vpn.kilroy.eu
      idpServiceAccount:
        email: sre@example.com
        firstName: NetBird
        lastName: Service
```

Check the result with `kubectl get keycloakintegration -n keycloakx`; `Ready=True` means every composed
resource exists in Keycloak. The composition update policy is the default (automatic), so a values change
reaches the existing XR on the next sync.

## How ordering works

The chart is synced as ONE ArgoCD Application. Every object this chart adds on top of the core carries an
`argocd.argoproj.io/sync-wave`:

| Wave | Objects |
|---|---|
| `0` | The Crossplane core, from the vendored upstream chart (unannotated) |
| `1` | `Provider` and `DeploymentRuntimeConfig` from this chart, `Function` packages from the sub-chart |
| `2` | `ProviderConfig` / `ClusterProviderConfig`, `CompositeResourceDefinition` |
| `3` | `Composition` |

ArgoCD only starts a wave once the previous one is healthy, so wave 1 waits for the core Deployments. It
ships a health check for `pkg.crossplane.io/Provider` that reports `Progressing` until the package is
`Installed` and `Healthy`, so wave 2 waits for the provider CRDs.

Every object in waves 1 and up also carries
`argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`, because ArgoCD dry-runs the whole
manifest set before wave 0 has run, and on a fresh cluster neither `pkg.crossplane.io/Provider` nor any
provider CRD exists at that point.

ArgoCD has no health check for an XRD, so wave 2 → 3 orders the apply but does not wait for Crossplane to
establish the CRD. The first sync of a newly enabled composite API can fail on the Composition and succeed
on the retry, so give the Application a retry block:

```yaml
syncPolicy:
  retry:
    limit: 5
    backoff:
      duration: 30s
      factor: 2
      maxDuration: 5m
  syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
```

Composite resources (XRs) are written by the cluster operator in the config repo, next to the application
manifests which need them — this chart does not create any.

## Migration

### From `crossplane-provider` 1.x

The providers, provider configs, composition functions, XRDs and Compositions moved here from
[`crossplane-provider`](../crossplane-provider), which now holds only the managed resources that are not
part of a composition. Object names and specs are unchanged, so ArgoCD adopts the existing objects; only
the sync waves and the owning Application differ.

1. Move the provider values into this chart's values file. Keys keep their paths
   (`providers.<provider>.*`); what stays behind in `crossplane-provider` is
   `providers.scaleway.{projectId,region,bucketNameSuffix,tags,managementPolicies,buckets}`,
   `providers.keycloak.{realm,namespace,groupsClientScope}` and every
   `providers.<provider>.extraResources`.
2. Sync `crossplane`. It adopts the `Provider`, `Function`, `ProviderConfig`, XRD and `Composition`
   objects the other Application created.
3. Keep the `crossplane-provider` Application if you use buckets, the `groups` client scope or
   `extraResources`; otherwise remove it **without cascading** — delete the Application with
   `--cascade=false`, or strip its `resources-finalizer.argocd.argoproj.io` first. A normal delete would
   take the managed resources, and the external objects behind them, with it.

### Earlier charts

`crossplane-providers-and-functions` and `crossplane-compositions` were replaced by `crossplane-provider`
and have been removed from KubeAid. Values moved as `azure.enable` → `providers.azure.enabled`,
`azure.compositions.*.enable` → `.enabled`, `scaleway.enable` → `providers.scaleway.enabled`,
`scaleway.objectStorage.buckets` → `providers.scaleway.buckets`.

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
