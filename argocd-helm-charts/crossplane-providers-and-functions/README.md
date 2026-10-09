# Crossplane Providers and Functions

Obmondo-authored chart (no vendored `charts/` subchart from upstream - only local `templates/`) that
installs Crossplane `Provider` and `Function` packages on top of the [`crossplane`](../crossplane) core.

## Why it's in KubeAid

`crossplane-compositions` defines the composite resources KubeAid uses to provision Azure infrastructure for
self-managed (CAPZ) clusters, and the Scaleway managed resources (Object Storage buckets) clusters hosted
elsewhere use for backups and artifact storage. Neither can run until the matching providers and pipeline
functions are installed. This chart is the install step for those packages; one sub-chart per cloud, each
behind an `<cloud>.enable` switch.

## Prerequisites

- [`crossplane`](../crossplane) core installed in the cluster.
- A credentials Secret in the release namespace for every enabled cloud - `azure-credentials` (Service
  Principal) or `scaleway-credentials` (API key) - referenced by the `ProviderConfig` /
  `ClusterProviderConfig` shipped in `crossplane-compositions`.

## Key values / KubeAid-specific configuration

| Value | Description | Default |
|---|---|---|
| `azure.enable` | Install the `azure` sub-chart (Azure `Provider` packages) | `false` |
| `scaleway.enable` | Install the `scaleway` sub-chart (Scaleway `Provider` + runtime config) | `false` |
| `scaleway.provider.package` | Scaleway provider package (without tag) | `xpkg.upbound.io/scaleway/provider-scaleway` |
| `scaleway.provider.version` | Scaleway provider package tag | `v0.6.0` |

Cluster-agnostic `Function` packages (`templates/functions.yaml`) are always installed, independent of
`azure.enable`:

| Function | Package |
|---|---|
| `patch-and-transform` | `xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.9.0` |
| `go-templating` | `xpkg.crossplane.io/crossplane-contrib/function-go-templating:v0.10.0` |
| `auto-ready` | `xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.5.0` |

### `azure` sub-chart (`charts/azure`)

Installs five Azure `Provider` packages: `azure-network`, `azure-storage`, `azure-managed-identity`,
`azure-ad`, `azure-authorization` (all `crossplane-contrib` upbound-family providers). The network provider
also pulls in `crossplane-contrib-provider-family-azure`, which handles Azure authentication for the whole
provider family.

### `scaleway` sub-chart (`charts/scaleway`)

Installs the `provider-scaleway` `Provider` (Upbound marketplace package, version pinned by
`scaleway.provider.version`) together with a `DeploymentRuntimeConfig` of the same name that starts the
provider with `--enable-management-policies`. Management policies are what let the Scaleway `Bucket`
resources in `crossplane-compositions` leave out `Delete`, so a bucket removed from git never deletes data.
The `ClusterProviderConfig` carrying the credentials is not here but in `crossplane-compositions`: its CRD
only exists once this Provider is installed and healthy, so it has to be applied in a later sync.

The sub-chart has helm-unittest coverage in `charts/scaleway/tests/`.

## Docs links

- [Crossplane providers](https://docs.crossplane.io/latest/concepts/providers/)
- [Crossplane functions](https://docs.crossplane.io/latest/concepts/composition-functions/)
- [Crossplane management policies](https://docs.crossplane.io/latest/concepts/managed-resources/#managementpolicies)
- [provider-scaleway on the Upbound marketplace](https://marketplace.upbound.io/providers/scaleway/provider-scaleway)
- [Azure hosting (CAPZ + Crossplane)](../../docs/hosting/cloud-providers.md)
- Related: [`crossplane`](../crossplane), [`crossplane-compositions`](../crossplane-compositions)
