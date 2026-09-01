# trivy-operator

Continuous in-cluster vulnerability and misconfiguration scanning, with Prometheus metrics and two
pre-baked alerts.

Wrapper around [Trivy Operator](https://aquasecurity.github.io/trivy-operator/).

## What you get

Trivy Operator watches workloads (Deployment, StatefulSet, DaemonSet, Job, CronJob, Pod) across the
cluster and writes results as CRs:

| Report | Contains |
|--------|----------|
| `VulnerabilityReport` | image CVEs, with CVSS score, installed and fixed versions, links |
| `ConfigAuditReport` | workload misconfigurations |
| `ExposedSecretReport` | credentials leaked into image layers |
| `RbacAssessmentReport` | RBAC anti-patterns |
| `InfraAssessmentReport` | control-plane configuration findings |
| `ClusterComplianceReport` | CIS Benchmark, NSA/CISA Hardening, Pod Security Standards |
| `SBOMReport` | full image bill-of-materials — **disabled by default**, see below |

A single built-in Trivy server is shared across scans, so there is no per-scan job pulling the
database. Metrics are exposed for the existing kube-prometheus-stack to scrape.

**This scans what is running, not what was pushed.** Harbor scans at push time and only for images
pushed to Harbor. Trivy Operator covers every running image regardless of source registry, and
re-evaluates against CVEs published *after* the image was built.

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

Deploy [`version-checker`](../version-checker) alongside this chart. Neither alert here depends on
it, but it answers "does a newer tag exist upstream" — which is what turns a CVE finding into an
upgrade someone can actually apply.

## Configuration

### Upstream (`trivy-operator.*`)

Forwarded to the [upstream chart](https://artifacthub.io/packages/helm/trivy-operator/trivy-operator).
See its `values.yaml` for the full surface; these are the knobs that matter here.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `trivy-operator.excludeNamespaces` | Namespaces to skip | `"kube-system,trivy-system,argocd"` |
| `trivy-operator.serviceMonitor.enabled` | Create a ServiceMonitor | `true` |
| `trivy-operator.operator.metricsVulnIdEnabled` | Emit per-CVE-ID metric labels | `true` |
| `trivy-operator.trivy.ignoreUnfixed` | Drop CVEs with no fix available | `true` |
| `trivy-operator.trivy.severity` | Severities to report | `"CRITICAL,HIGH"` |
| `trivy-operator.trivy.builtInTrivyServer` | Share one in-cluster Trivy server | `true` |
| `trivy-operator.operator.sbomGenerationEnabled` | Write an `SBOMReport` per image | `false` |

`ignoreUnfixed: true` is deliberate — a CVE with no published fix is not a work item, and including
them produces a number nobody can act on.

`sbomGenerationEnabled: false` is also deliberate. An `SBOMReport` is written per container image
and is by far the largest object this operator produces — tens to hundreds of KB each, refreshed
every scan cycle. On a cluster running ~900 distinct images that is roughly 95MB of JSON held in
etcd. etcd charges for that on *every* range request, so the cost is not paid by whoever reads
SBOMs; it is paid by the apiserver's periodic count of every resource type in the cluster, which
degrades into multi-second `listWithCount` latency and, past a point, apiserver handler timeouts
and failed liveness probes. Enable it only if something consumes `ClusterVulnerabilityReports`,
and size etcd for it first.

### KubeAid additions (`kubeaid.*`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kubeaid.prometheusRule.enabled` | Generate the PrometheusRule | `true` |
| `kubeaid.prometheusRule.blindFor` | How long the scanner must report nothing before alerting | `1h` |
| `kubeaid.prometheusRule.backlogThreshold` | Fixable Critical/High count above which the backlog alert fires | `100` |
| `kubeaid.prometheusRule.backlogFor` | How long the backlog must exceed the threshold | `24h` |
| `kubeaid.prometheusRule.additionalLabels` | Extra labels on the PrometheusRule (for Prometheus selector matching) | `{}` |
| `kubeaid.prometheusRule.additionalAnnotations` | Extra annotations on the PrometheusRule | `{}` |

## Alerts

Two, and no recording rules. Prometheus answers **is the scanner working** and **is the backlog
growing**. Per-CVE detail is not alerting data.

### `TrivyOperatorMetricsMissing` — critical

`absent(trivy_image_vulnerabilities)` held for `blindFor`.

The scanner is producing nothing, so the cluster is **unscanned, not clean**. This is the one
vulnerability alert worth waking someone for: a silent scanner looks exactly like a healthy one, and
across a fleet nobody spots it by eye.

Fires when the operator is down, the ServiceMonitor is not being scraped, or every report expired
past `scannerReportTTL` without refresh.

### `ClusterVulnerabilityBacklog` — warning

Fixable Critical/High findings above `backlogThreshold`, held for `backlogFor`.

`warning`, not `critical`. With `ignoreUnfixed` and a CRITICAL,HIGH filter this count is never zero
on a real cluster, so marking it critical would get the receiver muted within a week — and a muted
receiver takes the alert above down with it. What the severity routes to is a decision for your
alerting pipeline, not for this chart.

Every finding counted has a published fix, so the backlog is actionable.

## Per-CVE detail

CVSS scores, installed and fixed versions, descriptions and links are **not** in the metrics — the
metrics are a lossy projection. The full record is in the `VulnerabilityReport` CRs:

```bash
kubectl get vulnerabilityreports -A
```

Correlating CVEs against available upgrades is done outside PromQL, by reading the CRs directly. An
earlier revision of this chart attempted it in a recording rule, joining on an image reference
rebuilt from Trivy's `image_registry` and `image_repository` labels — which meant reimplementing
Docker's reference grammar in chained `label_replace` calls. It failed silently for short-form
Docker Hub references, and the fix for that wrongly rewrote `localhost/…` references. A PromQL join
can only ever *suppress* alerts, never add them, which is the wrong failure direction for security
data.

See [`decisions.md`](../../decisions.md) for the platform's decision records.

## Useful commands

```bash
# All vulnerable workloads
kubectl get vulnerabilityreports -A

# Critical-only summary
kubectl get vulnerabilityreports -A -o json \
  | jq '.items[] | {ns:.metadata.namespace, res:.report.artifact.repository, crit:.report.summary.criticalCount}'

# Force a re-scan of a workload
kubectl annotate deploy/my-app -n my-ns trivy-operator.aquasecurity.github.io/last-scan-checksum-

# Operator logs
kubectl logs -n trivy-system deploy/trivy-operator -f
```

## Notes

- This is a wrapper chart. Bump the `trivy-operator` version in `Chart.yaml` to pull upstream fixes.
- Air-gapped clusters: mirror `aquasec/trivy-db` and `aquasec/trivy-java-db`, then override
  `trivy-operator.trivy.image.repository` and `trivy.dbRepository`.
- Container CVEs go here; host-level CVEs go to [`vuls-dictionary`](../vuls-dictionary).
