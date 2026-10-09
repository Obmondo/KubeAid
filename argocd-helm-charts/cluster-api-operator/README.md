# Cluster API Operator

The [Cluster API Operator](https://github.com/kubernetes-sigs/cluster-api-operator) manages the lifecycle of
Cluster API (CAPI) providers declaratively: instead of running `clusterctl init` by hand, you declare
`CoreProvider` / `BootstrapProvider` / `ControlPlaneProvider` / `InfrastructureProvider` custom resources and the
operator installs and upgrades the matching CAPI controllers.

This is a KubeAid wrapper around the upstream
[cluster-api-operator chart](https://github.com/kubernetes-sigs/cluster-api-operator/tree/main/hack/charts)
(version 0.28.0).

## Why it's in KubeAid

KubeAid provisions clusters through Cluster API. On the management cluster, `kubeaid-cli` deploys this chart as
the `cluster-api-operator` Argo CD app and syncs it before the [`capi-cluster`](../capi-cluster) app — it installs
the CAPI machinery (core, kubeadm bootstrap and kubeadm control-plane providers) that `capi-cluster`'s Cluster and
Machine resources are reconciled by.

## Key values / KubeAid-specific configuration

Upstream values go under the `cluster-api-operator:` key. The wrapper pins:

```yaml
cluster-api-operator:
  core:
    cluster-api:
      version: v1.11.11
  bootstrap:
    kubeadm:
      version: v1.11.11
  controlPlane:
    kubeadm:
      version: v1.11.11
```

All three set `createNamespace: false` — the namespace is created by the Argo CD Application
(`CreateNamespace=true`), not by the operator.

`kubeaid-cli` overlays per-cluster values from your kubeaid-config repo
(`argocd-apps/values-cluster-api-operator.yaml`): it sets each provider's `namespace` to the cluster's
`capi-cluster-<...>` namespace and, on providers that use static credentials (i.e. not Azure Workload Identity),
points `configSecret` at the `cloud-credentials` Secret there.

Infrastructure providers (Hetzner, AWS, Azure, ...) are not listed here; they are brought in per cluster via the
[`capi-cluster`](../capi-cluster) chart and its provider subcharts.

## Docs links

- Provider-specific setup notes in this chart: [docs/aws.md](./docs/aws.md), [docs/hetzner.md](./docs/hetzner.md)
- Example Argo CD Application: [examples/argocd-application.yaml](./examples/argocd-application.yaml)
- Upstream: <https://github.com/kubernetes-sigs/cluster-api-operator>
- Cluster API book: <https://cluster-api.sigs.k8s.io/>
