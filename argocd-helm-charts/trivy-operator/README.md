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
| `kubeaid.prometheusRule.scoreBands.critical` | CVSS score band of the `critical` backlog alert: `scores` (regex over `vuln_score`) and `text` (the band in the summary) | `9([.][0-9])?\|10`, `of 9 or higher` |
| `kubeaid.prometheusRule.scoreBands.warning` | CVSS score band of the `warning` backlog alert | `7[.][5-9]\|8([.][0-9])?`, `from 7.5 to below 9` |
| `kubeaid.prometheusRule.backlogFor` | How long an image must stay behind before alerting; keep it longer than `scannerReportTTL` | `25h` |
| `kubeaid.prometheusRule.backlogExcludeNamespaces` | Regex of namespaces left out of the backlog, e.g. `dev-.*` | `""` |
| `kubeaid.prometheusRule.additionalLabels` | Extra labels on the PrometheusRule (for Prometheus selector matching) | `{}` |
| `kubeaid.prometheusRule.additionalAnnotations` | Extra annotations on the PrometheusRule | `{}` |

## Alerts

Two alert names, and no recording rules. Prometheus answers **is the scanner working** and **is the backlog
out of hand**. Per-CVE detail is not alerting data.

### `TrivyOperatorMetricsMissing` — critical

`absent(trivy_image_vulnerabilities)` held for `blindFor`.

The scanner is producing nothing, so the cluster is **unscanned, not clean**. This is the one
vulnerability alert worth waking someone for: a silent scanner looks exactly like a healthy one, and
across a fleet nobody spots it by eye.

Fires when the operator is down, the ServiceMonitor is not being scraped, or every report expired
past `scannerReportTTL` without refresh.

### `ClusterVulnerabilityBacklog` — critical and warning

Two alerts with the same name, one per CVSS score band, read from the `vuln_score` label of
`trivy_vulnerability_id` (`operator.metricsVulnIdEnabled`):

| Severity | CVSS score |
|----------|------------|
| `critical` | 9 or higher |
| `warning` | from 7.5 to below 9 |

Each fires while any image has a fixable finding in its band, held for `backlogFor`. It is one alert
per cluster and severity: its value is the number of such images, and its description gives that
number and names the worst ten, so on-call knows what to update. The summary carries no number, so a
ticket titled from it keeps the same title while the count changes.

- **Per image:** Trivy writes a `VulnerabilityReport` per workload container. Counting per image
  means one image shared by a dozen pods counts once, and an image's findings are its distinct CVE
  ids.
- **One band per image:** an image with a finding of 9 or higher is in the `critical` alert only, not also
  in the `warning` one.
- **By score, not Trivy severity:** a finding Trivy labels Critical with a score below 7.5 is in
  neither alert, and a finding without a score is not counted.
- **`backlogExcludeNamespaces`:** namespaces matching this regex are left out, for example developer
  environments.
- **`backlogFor` (25h):** about a day, and it outlasts `scannerReportTTL` (24h). After a rollout the
  superseded ReplicaSet keeps its report, and its older image's CVEs, until the TTL removes it, so a
  shorter hold would alert on images already updated.

Every finding counted has a published fix. On-call updates each listed image to a newer chart or
image tag; `kubectl get vulnerabilityreports -A -o wide --sort-by=.report.summary.criticalCount`
lists every image, worst last.

## Per-CVE detail

Descriptions and links are **not** in the metrics, and the CVSS score is only a text label on
`trivy_vulnerability_id`: the metrics are a lossy projection. The full record is in the
`VulnerabilityReport` CRs:

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
