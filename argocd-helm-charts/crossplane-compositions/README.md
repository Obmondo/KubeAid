# Crossplane Compositions

The Crossplane providers KubeAid supports with their provider configs, the composition pipeline functions,
and the composite APIs KubeAid models on top of them. A composite API is an XRD plus the Composition
behind it: the cluster operator writes one small composite resource (XR) and Crossplane creates the
managed resources it expands into.

```yaml
providers:
  azure:
    enabled: true
  keycloak:
    enabled: true

azure:
  workloadIdentityInfrastructure:
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

Every provider and every composite API is off by default. The three functions (`patch-and-transform`,
`go-templating`, `auto-ready`) are installed with the chart, because every Composition here runs them.

## Why it's a chart of its own

[`crossplane`](../crossplane) installs the control plane: a cluster-wide component upgraded rarely and
carefully. The providers and the composite APIs on top of them change far more often. Keeping them apart
means a composition or provider-version change is one small sync which cannot disturb the control plane,
and the core's health is not conflated with a provider package's.

## Prerequisites

- [`crossplane`](../crossplane) core installed in the cluster.
- The provider each composite API composes, enabled here: `providers.azure` for the Azure APIs,
  `providers.keycloak` for the Keycloak and NetBird ones. Nothing checks that for you — a composition
  whose provider is missing stays unready.
- The realm the Keycloak composite APIs are created in has to exist already; the
  [`keycloakx`](../keycloakx) chart renders it.
- Sync this Application after `crossplane` (a higher `kubeaid.io/sync-order`), with a sync `retry` block.

## Key values / KubeAid-specific configuration

| Value | Description | Default |
|---|---|---|
| `providers.<provider>.enabled` | Install that provider's package, runtime config and provider config | `false` |
| `azure.workloadIdentityInfrastructure.enabled` | `WorkloadIdentityInfrastructure` XRD + Composition | `false` |
| `azure.disasterRecoveryInfrastructure.enabled` | `DisasterRecoveryInfrastructure` XRD + Composition | `false` |
| `keycloak.obmondoKeycloakGroupsPropagation.enabled` | Obmondo's Keycloak as an upstream identity provider, propagating group membership into the realm | `false` |
| `keycloak.argocdClient.enabled` | `ArgoCDClient` XRD + Composition | `false` |
| `keycloak.grafanaClient.enabled` | `GrafanaClient` XRD + Composition | `false` |
| `keycloak.openobserveClient.enabled` | `OpenObserveClient` XRD + Composition | `false` |
| `netbird.keycloakIntegration.enabled` | `KeycloakIntegration` XRD + Composition | `false` |

## Providers

### `azure`

| Value | Description | Default |
|---|---|---|
| `providers.azure.credentials.secretName` / `.secretKey` | Secret (release namespace) and key with the Service Principal credentials | `azure-credentials` / `credentials` |

The chart installs the five Azure providers (`azure-network`, `azure-storage`, `azure-managed-identity`,
`azure-ad`, `azure-authorization`; `azure-network` also pulls in `crossplane-contrib-provider-family-azure`
which handles authentication for the whole family) and the `default` `ProviderConfig`. The two KubeAid
composite APIs built on them, `WorkloadIdentityInfrastructure` and `DisasterRecoveryInfrastructure`, are in
[`crossplane-compositions`](../crossplane-compositions).

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

The chart renders the provider package, the `DeploymentRuntimeConfig` that turns on management
policies, and the `default` `ClusterProviderConfig` reading the credentials Secret from the release
namespace. Namespaced managed resources use that `ClusterProviderConfig` unless they say otherwise, so
nothing in the compositions sets `providerConfigRef` — if a realm ever needs a second config, that is the
point to add it back. The Keycloak composite APIs themselves are in
[`crossplane-compositions`](../crossplane-compositions).

The `Realm` itself is rendered by the [`keycloakx`](../keycloakx) chart. Crossplane v2 managed resources
are namespaced and resolve the Secrets they reference (client secrets, initial passwords) in their own
namespace, which is where the apps consuming those Secrets live. That is why a Keycloak XR goes into that
namespace — typically `keycloakx` — and not into the release namespace.

What this chart adds on top of the provider package are the composite APIs for the applications KubeAid
deploys. The `groups` client scope, and any other Keycloak managed resource which is not part of a
composition, live in [`crossplane-provider`](../crossplane-provider).

## Composite APIs

### `azure` composite APIs

- `WorkloadIdentityInfrastructure` (`azure.kubeaid.org/v1alpha1`): given `subscriptionID`, `clusterName`,
  `location`, `aadApplicationPrincipalID` and `storageAccountName`, provisions a `ResourceGroup`, a Blob
  storage `Account` + `oidc-provider` `Container` (the OIDC issuer for workload identity), a `capi`
  `UserAssignedIdentity` with a `Contributor` role assignment, and federated identity credentials for CAPZ
  and Azure Service Operator.
- `DisasterRecoveryInfrastructure` (`azure.kubeaid.org/v1alpha1`): given `subscriptionID`, `clusterName`,
  `location` and `storageAccountName`, provisions `velero-backups` and `sealed-secrets-backups`
  `Container`s, a `velero` `UserAssignedIdentity` with a `Storage Blob Data Owner` role assignment, and a
  federated identity credential for the `velero` ServiceAccount.

Both run `mode: Pipeline`, both XRDs use `defaultCompositionUpdatePolicy: Manual` (composition changes need
an explicit revision bump on existing claims), and the `ResourceGroup`, `Account` and `Container`
resources use the `Orphan` deletion policy.

### `keycloak` composite APIs

#### Group scopes

Consumers that authorize on group membership (the ArgoCD RBAC policy, NetBird's `jwt_groups_enabled`) read
a `groups` claim. Where the groups come from decides which switch you want — both can be on at once, and
they emit the same claim name:

| Switch | Groups it exposes |
|---|---|
| `keycloak.groupsClientScope` (in [`crossplane-provider`](../crossplane-provider)) | Groups created in this Keycloak itself, through an `oidc-group-membership-mapper`. Renders a `ClientScope` plus its `ProtocolMapper` |
| `keycloak.obmondoKeycloakGroupsPropagation` | Groups a user belongs to in **Obmondo's** Keycloak |

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
| `ArgoCDClient` | `keycloak.argocdClient.enabled` | `argocd` confidential `Client` (`webOrigins: ["*"]`) and its `ClientDefaultScopes`. ArgoCD's RBAC matches on the `groups` claim, so the scopes carry the realm's `groups` scope plus the XR's `propagatedGroupScopes` |
| `GrafanaClient` | `keycloak.grafanaClient.enabled` | `grafana` confidential `Client`, its `ClientDefaultScopes`, a `oidc-usermodel-client-role-mapper` emitting `resource_access.${client_id}.roles`, and the `Admin` / `Editor` / `Viewer` `Role`s. Grafana's `role_attribute_path` reads that claim, so it authorizes on client roles rather than groups |
| `OpenObserveClient` | `keycloak.openobserveClient.enabled` | `openobserve-dex` confidential `Client` (Authorization Code only — Dex sits in front of OpenObserve), its `ClientDefaultScopes`, `ClientOptionalScopes` with `offline_access` so Dex can get a refresh token, and a mapper emitting client roles as a `role` claim |

Assigning roles or group membership to users stays outside Crossplane, like realm users themselves.

A cluster's XRs live next to its other Keycloak manifests, in the namespace which holds the Secrets they name. One client
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

With `keycloak.obmondoKeycloakGroupsPropagation.enabled`, the realm delegates login to Obmondo's Keycloak
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
installation, modelled as a Composition on top of the Keycloak provider — so it needs
`providers.keycloak.enabled` here, and the realm to exist already.

| Value | Description | Default |
|---|---|---|
| `netbird.keycloakIntegration.enabled` | Install the `KeycloakIntegration` XRD + Composition | `false` |

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
the XR's namespace, never generated by Keycloak, so the same Secrets can be mounted into
NetBird itself (`IDP_CLIENT_MGMT_SECRET`, `IDP_SERVICE_ACCOUNT_PASSWORD`). The client secret is a
write-only field in Keycloak: after rotating that Secret, bump
`backendClient.clientSecret.version` or the provider will not push the new value.

Both `ClientDefaultScopes` list their scopes in the Composition itself: `email`, `profile` and Keycloak's
built-ins (`acr`, `basic`, `web-origins`, `roles`) for the confidential client, the same plus the `api`
and `groups` scopes for the public one.

The confidential client also gets Keycloak's built-in `kc-admin-api` scope. Since Keycloak 26.8.2 the
Admin REST API answers 401 to any token whose audience that scope does not set, however many
`realm-management` roles it carries, and Keycloak only assigns it to `admin-cli` and
`security-admin-console` on its own. Without it NetBird's IdP manager cannot list the realm's users and
the dashboard keeps loading after a successful Keycloak login. The same applies to the client
the Keycloak provider itself logs in with: give it `kc-admin-api` by hand when you create it, or the
provider fails every reconcile with `GET /admin/serverinfo: 401`.

Scopes carrying groups **propagated from another IdP** are the exception, because Keycloak rejects a
default scope that does not exist in the realm and which ones exist differs per cluster. They are named in
the XR's `dashboardClient.propagatedGroupScopes` and **appended** to the public client's list — a patch
with `policy.mergeOptions.appendSlice: true`, so the base list stays the same everywhere:

```yaml
spec:
  dashboardClient:
    propagatedGroupScopes:              # must name scopes the realm actually has
      - obmondo-keycloak-groups         # from keycloak.obmondoKeycloakGroupsPropagation
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

Every object here needs a CRD it does not install itself — `apiextensions.crossplane.io` and
`pkg.crossplane.io` come from the core in the other Application, the provider CRDs come from the
`Provider` packages in wave 0 — so all of them carry
`argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`. ArgoCD ships a health check for
`pkg.crossplane.io/Provider` which reports `Progressing` until a package is `Installed` and `Healthy`, so
wave 1 waits for the provider CRDs.

| Wave | Objects |
|---|---|
| `0` | `Provider`, `DeploymentRuntimeConfig` and `Function` packages |
| `1` | `ProviderConfig` / `ClusterProviderConfig`, `CompositeResourceDefinition` |
| `2` | `Composition` |

ArgoCD has no health check for an XRD, so wave 1 → 2 orders the apply but does not wait for Crossplane to
establish the CRD. The first sync of a newly enabled composite API can fail on the Composition and succeed
on the retry, which is why the Application needs a retry block:

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

## Docs links

- [Composite resources](https://docs.crossplane.io/latest/concepts/composite-resources/) and
  [compositions](https://docs.crossplane.io/latest/concepts/compositions/)
- [function-patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform),
  [function-go-templating](https://github.com/crossplane-contrib/function-go-templating)
- [Azure hosting (CAPZ + Crossplane)](../../docs/hosting/cloud-providers.md)
- Related: [`crossplane`](../crossplane), [`crossplane-provider`](../crossplane-provider),
  [`keycloakx`](../keycloakx), [`netbird`](../netbird)
