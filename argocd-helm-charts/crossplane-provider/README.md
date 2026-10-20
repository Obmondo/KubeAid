# Crossplane Provider

Obmondo-authored chart (no vendored upstream `charts/`) that installs every Crossplane provider KubeAid
supports, together with the provider configuration and the managed resources, composite APIs and
integrations KubeAid models for it. Each provider is one entry under `providers`, switched on from values,
the way `capi-cluster` enables its infrastructure providers:

```yaml
providers:
  azure:
    enabled: true

  scaleway:
    enabled: true
    buckets:
      - name: backups
        versioning: true

  keycloak:
    enabled: true
    realm: Kilroy
    namespace: keycloakx
    groupsClientScope:
      enabled: true
    obmondoKeycloakGroupsPropagation:
      enabled: true

  netbird:
    enabled: true
    keycloakIntegration:
      enabled: true
      dashboardURL: https://netbird.vpn.kilroy.eu
```

Everything is rendered by this one chart: there are no sub-charts, because a sub-chart can only read
values under its own name and `providers.<provider>` keeps the values file readable.

It replaces the `crossplane-providers-and-functions` and `crossplane-compositions` charts, which have been
removed from KubeAid. See [Migration](#migration-from-the-two-old-charts).

## Why it's in KubeAid

[`crossplane`](../crossplane) only installs the Crossplane core. Everything cloud-specific used to be split
over two more charts and three ArgoCD Applications, because the CRDs a `ProviderConfig` or a `Bucket` need
do not exist until the matching `Provider` package is installed. That made adding a provider, or a single
bucket, a change across several charts and apps. This chart keeps one Application and expresses the
ordering with ArgoCD sync waves instead (see [How ordering works](#how-ordering-works)), so for a cluster
operator a new Scaleway bucket is one entry in one values file.

## Prerequisites

- [`crossplane`](../crossplane) core installed in the cluster (same namespace, by default `crossplane`).
- A credentials Secret per enabled provider in the release namespace, created out of band (typically by
  the cluster's sealed-secrets app): `azure-credentials`, `scaleway-credentials`. The Keycloak provider's
  own credentials Secret and its `ClusterProviderConfig` belong to the `keycloakx` chart, see below; the
  Secrets the Keycloak objects *read* (client secrets, initial passwords) live in
  `providers.keycloak.namespace`.
- The ArgoCD Application must track resources by annotation
  (`configs.cm.application.resourceTrackingMethod: annotation` in [`argo-cd`](../argo-cd), KubeAid's
  default) and should carry a sync `retry` block, see [How ordering works](#how-ordering-works).

## Key values / KubeAid-specific configuration

### Common

| Value | Description | Default |
|---|---|---|
| `providers.<provider>.enabled` | Render that provider's objects | `false` |
| `providers.<provider>.extraResources` | List of raw Kubernetes objects (usually managed resources this chart does not model yet) rendered verbatim in sync wave 2 | `[]` |

### `azure`

| Value | Description | Default |
|---|---|---|
| `providers.azure.compositions.workloadIdentityInfrastructure.enabled` | Install the `WorkloadIdentityInfrastructure` XRD + Composition | `true` |
| `providers.azure.compositions.disasterRecoveryInfrastructure.enabled` | Install the `DisasterRecoveryInfrastructure` XRD + Composition | `false` |
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
`compositions.*.enabled` switches here actually work: the old chart's nested sub-chart conditions were
resolved against the wrong values path and always installed both APIs.

### `scaleway`

| Value | Description | Default |
|---|---|---|
| `providers.scaleway.provider.package` / `.version` | `provider-scaleway` package and version | `xpkg.upbound.io/scaleway/provider-scaleway` / `v0.6.0` |
| `providers.scaleway.credentials.secretName` / `.secretKey` | Secret (release namespace) and key with the Scaleway API key | `scaleway-credentials` / `credentials` |
| `providers.scaleway.projectId` | Scaleway project every resource is created in (required once buckets are configured) | `""` |
| `providers.scaleway.region` | Scaleway region | `fr-par` |
| `providers.scaleway.bucketNameSuffix` | When set, a bucket's Scaleway name is `<name>.<suffix>` unless the bucket sets `bucketName` | `""` |
| `providers.scaleway.tags` | Tags applied to every bucket (per-bucket `tags` merged on top) | `{}` |
| `providers.scaleway.managementPolicies` | Management policies for every bucket; no `Delete` by default | `[Observe, Create, Update, LateInitialize]` |
| `providers.scaleway.buckets[]` | Object Storage buckets, see below | `[]` |

The provider runs with `--enable-management-policies` (a `DeploymentRuntimeConfig`), and every bucket
authenticates through the `default` `ClusterProviderConfig` this chart renders.

#### Creating a Scaleway bucket

Append an entry to `providers.scaleway.buckets` in the cluster's `values-crossplane-provider.yaml`, merge, and sync
the `crossplane-provider` Application. Nothing else changes.

```yaml
providers:
  scaleway:
    enabled: true
    projectId: 11111111-2222-3333-4444-555555555555
    region: fr-par
    bucketNameSuffix: my-cluster        # bucket names are global per region
    tags:
      environment: production
        - name: backups                   # Bucket resource name; Scaleway name backups.my-cluster
        versioning: true
        objectLock:
          enabled: true                   # also renders a LockConfiguration
          retention:
            mode: GOVERNANCE
            days: 30
        lifecycleRules:                   # passed through verbatim as forProvider.lifecycleRule
          - id: default
            enabled: true
            expiration:
              - days: 30
            abortIncompleteMultipartUploadDays: 1
      - name: harbor-oci-artifacts
        externalName: fr-par/harbor-oci-artifacts.my-cluster   # adopt an existing bucket: <region>/<bucket name>
      - name: legacy
        bucketName: some-old-name         # opt out of the suffix rule
```

Check the result with `kubectl get buckets.object.scaleway.m.upbound.io -n crossplane`; `Ready=True` and
`Synced=True` means the bucket exists.

- A bucket that already exists in Scaleway fails with `BucketAlreadyOwnedByYou` until the entry carries
  `externalName` in the form `<region>/<bucket name>`, after which Crossplane adopts it.
- Removing an entry deletes the `Bucket` object but never the bucket in Scaleway, because the default
  management policies have no `Delete`. To really delete, set `managementPolicies: ["*"]` on that entry
  first, or delete it in the Scaleway console.
- `LockConfiguration` needs an API key with object-lock permissions; otherwise it stays `Synced=False`
  with `AccessDenied` while the `Bucket` itself is fine.
- Anything the chart does not model (bucket policies, databases, instances) goes into
  `providers.scaleway.extraResources` as the raw managed resource.

### `keycloak`

| Value | Description | Default |
|---|---|---|
| `providers.keycloak.provider.package` / `.version` | `provider-keycloak` package and version | `xpkg.upbound.io/crossplane-contrib/provider-keycloak` / `v2.18.0` |
| `providers.keycloak.realm` | Realm every Keycloak object this chart renders is created in. Required as soon as one of them is enabled | `""` |
| `providers.keycloak.namespace` | Namespace they are created in; has to be the namespace holding the Secrets they read | release namespace |
| `providers.keycloak.groupsClientScope.enabled` | `groups` client scope for the groups created in this Keycloak itself | `false` |
| `providers.keycloak.obmondoKeycloakGroupsPropagation.enabled` | Obmondo's Keycloak as an upstream identity provider, propagating group membership into this realm | `false` |
| `providers.keycloak.argocdClient.enabled` | `ArgoCDClient` XRD + Composition | `false` |
| `providers.keycloak.grafanaClient.enabled` | `GrafanaClient` XRD + Composition | `false` |
| `providers.keycloak.openobserveClient.enabled` | `OpenObserveClient` XRD + Composition | `false` |

The `Realm` itself and the `ClusterProviderConfig` the resources below authenticate with are rendered by
the [`keycloakx`](../keycloakx) chart from its own values file, because Crossplane v2 managed resources are
namespaced and resolve the Secrets they reference (client secrets, initial passwords) in their own
namespace, which is where the apps consuming those Secrets live. That is also why everything here goes
into `providers.keycloak.namespace` — typically `keycloakx` — and not into the release namespace.

What this chart adds on top of the provider package are the realm-level pieces every KubeAid Keycloak
tends to need, and the per-application integrations built on them (see
[`netbird`](#netbird) below).

#### Group scopes

Consumers that authorize on group membership (the ArgoCD RBAC policy, NetBird's `jwt_groups_enabled`) read
a `groups` claim. Where the groups come from decides which switch you want — both can be on at once, and
they emit the same claim name:

| Switch | Groups it exposes |
|---|---|
| `providers.keycloak.groupsClientScope` | Groups created in this Keycloak itself, through an `oidc-group-membership-mapper`. Renders a `ClientScope` plus its `ProtocolMapper`; `fullGroupPath: true` emits `/Parent/Child` instead of `Child` |
| `providers.keycloak.obmondoKeycloakGroupsPropagation` | Groups a user belongs to in **Obmondo's** Keycloak |

Add a scope's name to the default scopes of the clients that need it. The `KeycloakIntegration` and
`ArgoCDClient` composite APIs take the brokered ones in `propagatedGroupScopes` and carry the realm's own
`groups` scope in their Composition already.

#### Application clients

One composite API per application KubeAid deploys, all in `keycloak.kubeaid.org/v1alpha1`. The client ID,
access type, flows, default scopes, protocol mappers and roles are fixed in the Composition; the XR
carries only what differs per cluster — the realm, the callback URLs and the Secret with the client
secret:

| Composite API | Switch | What the Composition creates |
|---|---|---|
| `ArgoCDClient` | `providers.keycloak.argocdClient.enabled` | `argocd` confidential `Client` (`webOrigins: ["*"]`) and its `ClientDefaultScopes`. ArgoCD's RBAC matches on the `groups` claim, so the scopes carry the realm's `groups` scope plus the XR's `propagatedGroupScopes` |
| `GrafanaClient` | `providers.keycloak.grafanaClient.enabled` | `grafana` confidential `Client`, its `ClientDefaultScopes`, a `oidc-usermodel-client-role-mapper` emitting `resource_access.${client_id}.roles`, and the `Admin` / `Editor` / `Viewer` `Role`s. Grafana's `role_attribute_path` reads that claim, so it authorizes on client roles rather than groups |
| `OpenObserveClient` | `providers.keycloak.openobserveClient.enabled` | `openobserve-dex` confidential `Client` (Authorization Code only — Dex sits in front of OpenObserve), its `ClientDefaultScopes`, `ClientOptionalScopes` with `offline_access` so Dex can get a refresh token, and a mapper emitting client roles as a `role` claim |

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

With `providers.keycloak.obmondoKeycloakGroupsPropagation.enabled`, the realm delegates login to Obmondo's Keycloak
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

### `netbird`

NetBird is not a Crossplane provider of its own. What it brings is the Keycloak side of a NetBird
installation, modelled as a Composition on top of `providers.keycloak` — so it needs
`providers.keycloak.enabled` (the chart refuses to render otherwise) and the realm to exist already.

| Value | Description | Default |
|---|---|---|
| `providers.netbird.keycloakIntegration.enabled` | Install the `KeycloakIntegration` XRD + Composition and create the XR | `false` |
| `providers.netbird.keycloakIntegration.dashboardURL` | Public URL of the NetBird dashboard. Required | `""` |
| `.realm` / `.namespace` | Override the realm / namespace for the NetBird objects only | `providers.keycloak.realm` / `.namespace` |
| `.idpServiceAccount.*` | Account NetBird's management service authenticates as over the Keycloak Admin API (`IDP_SERVICE_ACCOUNT_USER` / `_PASSWORD`), and the admin logs into the dashboard as — the NetBird account owner. Plus the Secret with its initial password | `netbird` / `netbird-user-init-password` |
| `.backendClient.clientSecret.*` | Secret (`name` / `key`) with the confidential client's client secret, and the `version` to bump after rotating it. Its client ID and its `view-users` role on `realm-management` are fixed in the Composition | `netbird-backend-client-credentials` / `clientSecret` / `1` |
| `.dashboardClient.propagatedGroupScopes` | Client scopes carrying groups brokered from another IdP, appended to the public client's default scopes. Its client ID (`netbird-client`) and the `api` scope are fixed in the Composition | `[]` |

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

The chart is synced as ONE ArgoCD Application. Every object carries an `argocd.argoproj.io/sync-wave`:

| Wave | Objects |
|---|---|
| `0` | `Provider`, `DeploymentRuntimeConfig`, `Function` packages |
| `1` | `ProviderConfig` / `ClusterProviderConfig`, `CompositeResourceDefinition` |
| `2` | `Composition`, managed resources (`Bucket`, `LockConfiguration`, `ClientScope`, ...), `extraResources` |
| `3` | Composite resources (XRs) this chart creates itself (`KeycloakIntegration`, `ObmondoKeycloakGroupsPropagation`) |

ArgoCD only starts a wave once the previous one is healthy. ArgoCD ships a health check for
`pkg.crossplane.io/Provider` that reports `Progressing` until the package is `Installed` and `Healthy`, so
wave 1 waits for the CRDs. Objects in waves 1 and up also carry
`argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`, because ArgoCD dry-runs the whole
manifest set before wave 0 has run and those kinds are unknown to the API server at that point.

ArgoCD has no health check for an XRD, so wave 3 only orders the XRs after their Composition, not after
the CRD Crossplane creates from the XRD. The first sync of a newly enabled composite API can therefore
fail on the XR and succeed on the retry — one more reason for the retry block below.

Give the Application a retry block so a slow provider install is retried instead of failing the sync:

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

## Migration from the two old charts

Object names and specs are unchanged, so ArgoCD adopts the existing `Provider`s, `Function`s,
`ProviderConfig`s, XRDs, Compositions and managed resources; the only diff is the new annotations.

The old chart directories are gone from this KubeAid release on. An Application that still points at
`argocd-helm-charts/crossplane-providers-and-functions` or `argocd-helm-charts/crossplane-compositions` can
no longer be rendered once the cluster moves to it (ArgoCD reports a comparison error); the objects it
created stay in the cluster. Migrate in the same change that bumps the KubeAid version.

1. Add the `crossplane-provider` Application and its values file. Values move as follows:
   `azure.enable` → `providers.azure.enabled`, `azure.compositions.*.enable` → `.enabled`,
   `scaleway.enable` → `providers.scaleway.enabled`, `scaleway.objectStorage.buckets` →
   `providers.scaleway.buckets`.
2. Remove the `crossplane-providers-and-functions` and `crossplane-compositions` Applications **without
   cascading**: delete the Application objects with `--cascade=false`, or remove their
   `resources-finalizer.argocd.argoproj.io` finalizer first. A normal (cascading) delete removes the
   Providers and every managed resource with them.
3. Sync `crossplane-provider`; it takes ownership of the orphaned objects.

### Moving from chart 1.0.0 to 2.0.0

Chart 2.0.0 drops the sub-charts (`charts/azure`, `charts/scaleway`, `charts/keycloak`) and nests every
provider under `providers`, because a sub-chart can only read values under its own name. Object names and
specs are unchanged, so nothing in the cluster is recreated; only the values file moves:

```diff
-azure:
-  enabled: true
+providers:
+  azure:
+    enabled: true
```

Same for `scaleway` and `keycloak`, including their nested keys (`scaleway.buckets` →
`providers.scaleway.buckets`, `<provider>.extraResources` →
`providers.<provider>.extraResources`).

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
