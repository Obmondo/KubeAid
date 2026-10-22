# Crossplane Provider

Obmondo-authored chart (the only vendored upstream chart is the optional [Crossview](#crossview) UI) that installs every Crossplane provider KubeAid
supports, together with the provider configuration and the managed resources KubeAid models for it. Each
provider is a sub-chart switched on from values, the way `capi-cluster` enables its infrastructure
providers:

```yaml
azure:
  enabled: true
scaleway:
  enabled: true
  buckets:
    - name: backups
      versioning: true
keycloak:
  enabled: true
```

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
  the cluster's sealed-secrets app): `azure-credentials`, `scaleway-credentials`. The Keycloak credentials
  Secret belongs to the `keycloakx` chart, see below.
- The ArgoCD Application must track resources by annotation
  (`configs.cm.application.resourceTrackingMethod: annotation` in [`argo-cd`](../argo-cd), KubeAid's
  default) and should carry a sync `retry` block, see [How ordering works](#how-ordering-works).

## Key values / KubeAid-specific configuration

### Common

| Value | Description | Default |
|---|---|---|
| `<provider>.enabled` | Install that provider sub-chart | `false` |
| `<provider>.extraResources` | List of raw Kubernetes objects (usually managed resources this chart does not model yet) rendered verbatim in sync wave 2 | `[]` |

### `azure`

| Value | Description | Default |
|---|---|---|
| `azure.compositions.workloadIdentityInfrastructure.enabled` | Install the `WorkloadIdentityInfrastructure` XRD + Composition | `true` |
| `azure.compositions.disasterRecoveryInfrastructure.enabled` | Install the `DisasterRecoveryInfrastructure` XRD + Composition | `false` |
| `azure.credentials.secretName` / `.secretKey` | Secret (release namespace) and key with the Service Principal credentials | `azure-credentials` / `credentials` |

The sub-chart installs the five Azure providers (`azure-network`, `azure-storage`, `azure-managed-identity`,
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
| `scaleway.provider.package` / `.version` | `provider-scaleway` package and version | `xpkg.upbound.io/scaleway/provider-scaleway` / `v0.6.0` |
| `scaleway.credentials.secretName` / `.secretKey` | Secret (release namespace) and key with the Scaleway API key | `scaleway-credentials` / `credentials` |
| `scaleway.projectId` | Scaleway project every resource is created in (required once buckets are configured) | `""` |
| `scaleway.region` | Scaleway region | `fr-par` |
| `scaleway.bucketNameSuffix` | When set, a bucket's Scaleway name is `<name>.<suffix>` unless the bucket sets `bucketName` | `""` |
| `scaleway.tags` | Tags applied to every bucket (per-bucket `tags` merged on top) | `{}` |
| `scaleway.managementPolicies` | Management policies for every bucket; no `Delete` by default | `[Observe, Create, Update, LateInitialize]` |
| `scaleway.buckets[]` | Object Storage buckets, see below | `[]` |

The provider runs with `--enable-management-policies` (a `DeploymentRuntimeConfig`), and every bucket
authenticates through the `default` `ClusterProviderConfig` this sub-chart renders.

#### Creating a Scaleway bucket

Append an entry to `scaleway.buckets` in the cluster's `values-crossplane-provider.yaml`, merge, and sync
the `crossplane-provider` Application. Nothing else changes.

```yaml
scaleway:
  enabled: true
  projectId: 11111111-2222-3333-4444-555555555555
  region: fr-par
  bucketNameSuffix: my-cluster          # bucket names are global per region
  tags:
    environment: production
  buckets:
    - name: backups                       # Bucket resource name; Scaleway name backups.my-cluster
      versioning: true
      objectLock:
        enabled: true                     # also renders a LockConfiguration
        retention:
          mode: GOVERNANCE
          days: 30
      lifecycleRules:                     # passed through verbatim as forProvider.lifecycleRule
        - id: default
          enabled: true
          expiration:
            - days: 30
          abortIncompleteMultipartUploadDays: 1
    - name: harbor-oci-artifacts
      externalName: fr-par/harbor-oci-artifacts.my-cluster   # adopt an existing bucket: <region>/<bucket name>
    - name: legacy
      bucketName: some-old-name           # opt out of the suffix rule
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
  `scaleway.extraResources` as the raw managed resource.

### `keycloak`

| Value | Description | Default |
|---|---|---|
| `keycloak.provider.package` / `.version` | `provider-keycloak` package and version | `xpkg.upbound.io/crossplane-contrib/provider-keycloak` / `v2.18.0` |

This sub-chart installs the provider package (with `--enable-management-policies`) and nothing else. The
`ClusterProviderConfig` and the `Realm`, `User`, `Client`, ... resources for a Keycloak that KubeAid
deploys are rendered by the [`keycloakx`](../keycloakx) chart from its own values file, because Crossplane
v2 managed resources are namespaced and resolve the Secrets they reference (client secrets, initial
passwords) in their own namespace, which is where the apps consuming those Secrets live. The rule
generalises: a provider that targets an external cloud renders its resources here; a provider that
configures an application KubeAid deploys renders them from that application's chart.

### Crossview

[Crossview](https://github.com/crossplane-contrib/crossview) is a web UI for browsing Crossplane resources. It
ships as the upstream `crossview` sub-chart and is off by default. Its objects carry no sync wave, so they
sync in wave `0`.

| Value | Description | Default |
|---|---|---|
| `crossview.enabled` | Deploy Crossview | `false` |
| `global.postgresql.enabled` | Create a CloudNativePG cluster `crossview-pgsql` via `kubeaid-addons` | `false` |
| `crossview.config.database.{host,database,username}` | Database connection | `crossview-pgsql-rw`, `crossview`, `crossview` |
| `crossview.secrets.dbPassword` | Database password Secret reference | `crossview-pgsql-app` / `password` |
| `crossview.secrets.adminPassword`, `crossview.secrets.sessionSecret` | Secret references for the local admin password and session signing key | `crossview-auth` / `admin-password`, `session-secret` |
| `crossview.ingress` | Ingress, `traefik-cert-manager` class | disabled |
| `crossview.config.server.cors.origin` | Public URL of Crossview, also the post-SSO redirect | `https://crossview.example.com` |
| `crossview.config.sso.oidc` | OIDC login (Keycloak etc.); client secret in `crossview.secrets.OIDCClientSecret` | disabled |

The upstream bundled `postgres:latest` Deployment (`crossview.database.enabled`) is turned off. Crossview
either uses the `kubeaid-addons` CNPG cluster, or an existing CNPG cluster in the release namespace:

```yaml
crossview:
  enabled: true
  config:
    database:
      host: crossview-db-rw
      database: app
      username: app
  secrets:
    dbPassword:
      secretKeyRef:
        name: crossview-db-app
        key: password
```

Crossview falls back to `admin`/`password` and a hard-coded session secret when these are unset, so create
the `crossview-auth` Secret (e.g. as a SealedSecret) before enabling it.

## How ordering works

The chart is synced as ONE ArgoCD Application. Every object carries an `argocd.argoproj.io/sync-wave`:

| Wave | Objects |
|---|---|
| `0` | `Provider`, `DeploymentRuntimeConfig`, `Function` packages |
| `1` | `ProviderConfig` / `ClusterProviderConfig`, `CompositeResourceDefinition` |
| `2` | `Composition`, managed resources (`Bucket`, `LockConfiguration`, ...), `extraResources` |

ArgoCD only starts a wave once the previous one is healthy. ArgoCD ships a health check for
`pkg.crossplane.io/Provider` that reports `Progressing` until the package is `Installed` and `Healthy`, so
wave 1 waits for the CRDs. Objects in waves 1 and 2 also carry
`argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`, because ArgoCD dry-runs the whole
manifest set before wave 0 has run and those kinds are unknown to the API server at that point.

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
   `azure.enable` → `azure.enabled`, `azure.compositions.*.enable` → `.enabled`, `scaleway.enable` →
   `scaleway.enabled`, `scaleway.objectStorage.buckets` → `scaleway.buckets`.
2. Remove the `crossplane-providers-and-functions` and `crossplane-compositions` Applications **without
   cascading**: delete the Application objects with `--cascade=false`, or remove their
   `resources-finalizer.argocd.argoproj.io` finalizer first. A normal (cascading) delete removes the
   Providers and every managed resource with them.
3. Sync `crossplane-provider`; it takes ownership of the orphaned objects.

## Docs links

- [Crossplane providers](https://docs.crossplane.io/latest/concepts/providers/),
  [managed resources](https://docs.crossplane.io/latest/concepts/managed-resources/),
  [management policies](https://docs.crossplane.io/latest/concepts/managed-resources/#managementpolicies)
- [ArgoCD sync waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) and
  [sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#skip-dry-run-for-new-custom-resources-types)
- [provider-scaleway](https://github.com/scaleway/crossplane-provider-scaleway),
  [provider-keycloak](https://github.com/crossplane-contrib/provider-keycloak)
- [Azure hosting (CAPZ + Crossplane)](../../docs/hosting/cloud-providers.md)
- Related: [`crossplane`](../crossplane), [`keycloakx`](../keycloakx)
