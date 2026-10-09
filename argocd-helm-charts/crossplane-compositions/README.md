# Crossplane Compositions

Obmondo-authored chart (no vendored upstream `charts/` - the compositions are KubeAid's own) that installs
Crossplane `CompositeResourceDefinition`s (XRDs) and `Composition`s defining KubeAid's Azure infrastructure
APIs, plus the `ProviderConfig` those compositions authenticate through. It is also the home of the
provider-specific configuration and managed resources that need a provider's CRDs to exist first - today the
Scaleway `ClusterProviderConfig` and Object Storage `Bucket`s (`scaleway` sub-chart).

## Why it's in KubeAid

CAPZ-provisioned (self-managed) Azure clusters need supporting Azure infrastructure that ClusterAPI does not
provision itself: a storage account for the OIDC/workload-identity issuer, managed identities and role
assignments for CAPZ and Azure Service Operator, and (optionally) a Velero backup identity and blob
containers for disaster recovery. This chart turns those into two composite APIs cluster operators apply as
plain Kubernetes claims. See [Azure hosting](../../docs/hosting/cloud-providers.md#azure).

## Prerequisites

- [`crossplane`](../crossplane) core and [`crossplane-providers-and-functions`](../crossplane-providers-and-functions)
  (with the matching `azure.enable` / `scaleway.enable`) installed first. The Provider must be Installed and
  Healthy before this chart syncs, otherwise the `ProviderConfig` / `ClusterProviderConfig` and the managed
  resources fail with "no matches for kind".
- A credentials Secret in the release namespace: `azure-credentials` for the Azure `ProviderConfig`,
  `scaleway-credentials` (key `credentials`) for the Scaleway `ClusterProviderConfig`.

## Key values / KubeAid-specific configuration

| Value | Description | Default |
|---|---|---|
| `azure.enable` | Install the `azure` sub-chart (XRDs + Compositions) | `false` |
| `azure.compositions.workloadIdentityInfrastructure.enable` | Install the `WorkloadIdentityInfrastructure` composition | `true` |
| `azure.compositions.disasterRecoveryInfrastructure.enable` | Install the `DisasterRecoveryInfrastructure` composition | `false` |
| `scaleway.enable` | Install the `scaleway` sub-chart (`ClusterProviderConfig` + buckets) | `false` |
| `scaleway.projectId` | Scaleway project the buckets live in (required) | `""` |
| `scaleway.region` | Scaleway region | `fr-par` |
| `scaleway.bucketNameSuffix` | Appended as `<name>.<suffix>` to form the Scaleway bucket name; usually the cluster name | `""` |
| `scaleway.tags` | Tags applied to every bucket (per-bucket `tags` merge on top) | `{}` |
| `scaleway.managementPolicies` | Default management policies for every bucket | `[Observe, Create, Update, LateInitialize]` |
| `scaleway.credentials.secretName` / `.secretKey` | Secret the `ClusterProviderConfig` reads | `scaleway-credentials` / `credentials` |
| `scaleway.objectStorage.buckets[]` | Buckets to manage, see below | `[]` |

### `WorkloadIdentityInfrastructure` claim (`azure.kubeaid.org/v1alpha1`)

Given `subscriptionID`, `clusterName`, `location`, `aadApplicationPrincipalID`, and `storageAccountName`,
provisions: a `ResourceGroup`, a Blob storage `Account` + `oidc-provider` `Container` (the OIDC issuer for
workload identity), a `capi` `UserAssignedIdentity` with a `Contributor` role assignment, and federated
identity credentials for both CAPZ (`capz-manager`) and Azure Service Operator
(`azureserviceoperator-default`).

### `DisasterRecoveryInfrastructure` claim (`azure.kubeaid.org/v1alpha1`)

Given `subscriptionID`, `clusterName`, `location`, and `storageAccountName`, provisions: `velero-backups` and
`sealed-secrets-backups` blob `Container`s, a `velero` `UserAssignedIdentity` with a `Storage Blob Data
Owner` role assignment, and a federated identity credential for the `velero` ServiceAccount.

### `scaleway` sub-chart (`charts/scaleway`)

Renders the `default` `ClusterProviderConfig` (`scaleway.m.upbound.io/v1beta1`, credentials from the Secret
above) and one namespaced `Bucket` (`object.scaleway.m.upbound.io/v1alpha1`) per entry in
`scaleway.objectStorage.buckets[]`:

```yaml
scaleway:
  enable: true
  projectId: 00000000-0000-0000-0000-000000000000
  bucketNameSuffix: my-cluster          # Scaleway bucket names are global per region
  tags:
    environment: production
  objectStorage:
    buckets:
      - name: backups                   # Bucket resource name; Scaleway name = backups.my-cluster
        versioning: true
        objectLock:                     # also renders a LockConfiguration for the bucket
          enabled: true
          retention: { mode: GOVERNANCE, days: 30 }
        lifecycleRules:                 # passed through verbatim as forProvider.lifecycleRule
          - id: default
            enabled: true
            expiration: [{ days: 30 }]
            abortIncompleteMultipartUploadDays: 1
      - name: harbor-oci-artifacts
      - name: legacy                    # adopt a bucket that already exists in Scaleway
        bucketName: some-older-name
        externalName: fr-par/some-older-name
```

Per-bucket keys: `name` (required), `bucketName`, `externalName` (sets `crossplane.io/external-name`, needed
to adopt a pre-existing bucket instead of failing with `BucketAlreadyOwnedByYou`), `versioning`, `objectLock`,
`lifecycleRules`, `tags`, `managementPolicies`.

The sub-chart has helm-unittest coverage in `charts/scaleway/tests/`.

## Operational notes

- Both compositions use `mode: Pipeline` with the `go-templating`, `patch-and-transform`, and `auto-ready`
  functions from `crossplane-providers-and-functions`.
- `defaultCompositionUpdatePolicy: Manual` on both XRDs - composition changes require an explicit revision
  bump on existing claims, they are not applied automatically.
- Deletion policy on the `ResourceGroup` and storage `Account`/`Container` resources is `Orphan`.
- Scaleway `Bucket`s default to `managementPolicies: [Observe, Create, Update, LateInitialize]` - no
  `Delete`. Removing a bucket from values (or deleting the `Bucket` object) leaves the data in Scaleway;
  deleting the bucket is a deliberate manual step. This needs `--enable-management-policies` on the provider,
  which the `scaleway` sub-chart of `crossplane-providers-and-functions` sets.
- `LockConfiguration` requires the API key to have object-lock permission; without it the resource stays
  `Synced=False` with `AccessDenied` while the `Bucket` itself is fine.

## Docs links

- [Crossplane compositions](https://docs.crossplane.io/latest/concepts/compositions/)
- [Crossplane management policies](https://docs.crossplane.io/latest/concepts/managed-resources/#managementpolicies)
- [provider-scaleway `Bucket` reference](https://marketplace.upbound.io/providers/scaleway/provider-scaleway/latest/resources/object.scaleway.upbound.io/Bucket)
- [Azure hosting (CAPZ + Crossplane)](../../docs/hosting/cloud-providers.md)
- Related: [`crossplane`](../crossplane), [`crossplane-providers-and-functions`](../crossplane-providers-and-functions)
