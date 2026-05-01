# trivy-operator

Helm chart wrapper for [Trivy Operator](https://aquasecurity.github.io/trivy-operator/) — continuous in-cluster image and Kubernetes resource vulnerability scanning, with Prometheus metrics and pre-baked alert rules.

## How it works

Trivy Operator watches workloads (Deployment, StatefulSet, DaemonSet, Job, CronJob, Pod) across the cluster and emits per-resource scan results as CRDs:

- `VulnerabilityReport` — image-level CVEs
- `ConfigAuditReport` — workload misconfigurations
- `ExposedSecretReport` — leaked credentials in image layers
- `RbacAssessmentReport` — RBAC anti-patterns

A built-in Trivy server is shared across scanners (no per-scan job pulls), and the operator exposes Prometheus metrics so the existing kube-prometheus-stack picks up CVE counts as time series.

## Why this complements Harbor

Harbor scans images **at push time** to a Harbor registry. Trivy Operator scans **what's actually running in the cluster**, regardless of source registry — covering external-pull images (`docker.io`, `quay.io`, `ghcr.io`, etc.) and reflecting CVEs added to the database after the image was pushed.

## Quick start

```yaml
# values.yaml
trivy-operator:
  excludeNamespaces: "kube-system,trivy-system,argocd"
  serviceMonitor:
    enabled: true
  trivy:
    ignoreUnfixed: true
    severity: "CRITICAL,HIGH"

kubeaid:
  prometheusRule:
    enabled: true
```

> **Note:** `ImageOutdatedAndVulnerable` requires `version_checker_is_latest_version` metric. Deploy the [`version-checker`](../version-checker) chart alongside this one.

## Configuration

### Upstream chart (`trivy-operator.*`)

Forwarded to the [aquasecurity/trivy-operator](https://artifacthub.io/packages/helm/trivy-operator/trivy-operator) Helm chart. See upstream values.yaml for the full surface; the most relevant knobs are mirrored in this chart's `values.yaml` with KubeAid-friendly defaults.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `trivy-operator.excludeNamespaces` | Namespaces to skip scanning | `"kube-system,trivy-system,argocd"` |
| `trivy-operator.serviceMonitor.enabled` | Create ServiceMonitor for Prometheus scraping | `true` |
| `trivy-operator.operator.metricsVulnIdEnabled` | Emit per-CVE-ID metric labels | `true` |
| `trivy-operator.trivy.ignoreUnfixed` | Drop CVEs with no fix available | `true` |
| `trivy-operator.trivy.severity` | Severities to report | `"CRITICAL,HIGH"` |
| `trivy-operator.trivy.builtInTrivyServer` | Use single in-cluster Trivy server | `true` |

### KubeAid additions (`kubeaid.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kubeaid.prometheusRule.enabled` | Generate PrometheusRule (recording rule + `ImageOutdatedAndVulnerable` + `TrivyOperatorScannerStuck`) | `true` |
| `kubeaid.prometheusRule.additionalLabels` | Extra labels added to the PrometheusRule object (for Prometheus selector matching) | `{}` |
| `kubeaid.prometheusRule.additionalAnnotations` | Extra annotations added to the PrometheusRule object | `{}` |

## Alerts shipped

- `ImageOutdatedAndVulnerable` — fires when a running image has `Critical`/`High` CVEs **and** a newer tag is available in the source registry. Built by joining the `record::trivy::vulnerability_count::by_image` recording rule (reshaped from `trivy_vulnerability_id`) with `version_checker_is_latest_version == 0` on `(image, current_version)`. **Requires the [`version-checker`](../version-checker) chart deployed in the cluster** — without it the join produces no series and the alert never fires. Persists for 6h before firing to absorb registry/scanner flaps.
- `TrivyOperatorScannerStuck` — last successful scan older than 24h (operator or trivy-server unhealthy).

## Useful commands

```bash
# All vulnerable workloads
kubectl get vulnerabilityreports -A

# Critical-only summary
kubectl get vulnerabilityreports -A -o json | jq '.items[] | {ns:.metadata.namespace, res:.report.artifact.repository, crit:.report.summary.criticalCount}'

# Force a re-scan of a workload
kubectl annotate deploy/my-app -n my-ns trivy-operator.aquasecurity.github.io/last-scan-checksum-

# Inspect operator logs
kubectl logs -n trivy-system deploy/trivy-operator -f
```

## Notes

- This chart is a wrapper. Bump `trivy-operator` chart version in `Chart.yaml` to pull upstream fixes.
- For air-gapped clusters, mirror the `aquasec/trivy-db` and `aquasec/trivy-java-db` images and override `trivy-operator.trivy.image.repository` and `trivy.dbRepository`.
- Pairs with `vuls-dictionary` (host-level scanning) — host CVEs go to Vuls, container CVEs go to Trivy Operator.
