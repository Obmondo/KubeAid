# Why one scanner per layer, and what actually produces compliance evidence

Security tooling for Kubernetes is easy to buy and hard to run. Every vendor demonstrates well: point it at a
cluster, watch a number appear, feel safer. Six months later you have four agents on every node, three
overlapping findings databases, and a Critical count nobody has looked at since the second week.

KubeAid ships one tool per security layer, and each one has to earn its place by answering a question no other
tool in the stack answers. This document records which tools we chose, why, and — just as importantly — what we
deliberately do not do.

## The failure mode we design against

The obvious risk is missing a vulnerability. That is not the risk that actually hurts.

Two things go wrong far more often. The first is alert fatigue: a scanner reports 3,000 Critical findings, nobody
can act on 3,000 of anything, so the report gets ignored — and the twelve findings that mattered are ignored with
it. The second is worse, because it is invisible: **an alert that silently never fires**. A PromQL join whose
label sets do not match produces no series. No series means no alert. No alert looks exactly like "nothing is
wrong."

A scanner that reports too much and a scanner that reports nothing both end in the same place: an operator who
does not trust the tool. Every decision below is made to avoid that.

## The three layers

Kubernetes security splits cleanly into three layers, each answering a different question at a different moment.
Running two tools in the same layer is not defence in depth — it is two findings databases that will disagree,
and an operator who has to reconcile them.

| Layer | Question | When | KubeAid standard |
| ----- | -------- | ---- | ---------------- |
| Admission | Should this be allowed to exist? | At API-server write time | Kyverno (mutate/generate) + in-tree ValidatingAdmissionPolicy (validate) |
| Detection | What is wrong with what is running? | Continuously | trivy-operator + version-checker |
| Runtime | What is it doing right now? | At execution | Tetragon |

Anything else in `argocd-helm-charts/` that touches these layers is available but off by default.

## Detection: Trivy, not Kubescape

Both `trivy-operator` and `kubescape-operator` scan container images for CVEs. Trivy uses its own database;
Kubescape uses Grype. They find substantially the same vulnerabilities. Running both means maintaining two
databases that disagree at the margins, and answering the support question "why does one say 40 Criticals and the
other say 12" — which costs real time and buys no security.

We chose Trivy for a reason that has nothing to do with detection quality: **it is the one wired into an alerting
path.** Trivy's ServiceMonitor is enabled and the chart ships its own `PrometheusRule`. Kubescape ships
`prometheusExporter: disable` with `serviceMonitor.enabled: false`, and KubeAid does not override either — so as
packaged it emits nothing to Prometheus at all. Its findings live in CRDs.

Findings that never reach Alertmanager are not security posture. They are a dashboard nobody opens.

The secondary reason is cost. Trivy adds two workloads to a cluster: the operator Deployment and the built-in
Trivy server StatefulSet. Kubescape adds seven Deployments, four CronJobs, and a privileged eBPF DaemonSet on
every node — the last of which is also the most common thing customers refuse to approve.

### What we give up

Kubescape's genuine differentiator is **relevancy**: an eBPF node-agent observes which libraries are actually
loaded into memory, then filters the CVE list to packages in use. Nothing else in KubeAid does this, and it is a
real capability we are declining.

We accept that because our Trivy configuration reaches a similarly short list by a different route:

```yaml
trivy:
  ignoreUnfixed: true            # a CVE with no fix is not a work item
  severity: "CRITICAL,HIGH"
```

Relevancy answers "is this reachable?". Our filter answers "is this actionable?". They are not the same guarantee
— relevancy can tell you a Critical is unreachable and safe to defer, and our filter cannot. If a customer needs
that, `kubescape-operator` is in the repo and can be enabled for that cluster. It must not be enabled as a second
CVE source feeding alerts.

## Why version-checker is part of the standard

`version-checker` is not a security scanner and does not compete with Trivy. It answers one question Trivy cannot:
**is there a newer image upstream?**

That question is what makes a CVE report actionable. A Critical vulnerability in an image with no newer tag is a
ticket nobody can close — you can escalate it, document it, accept the risk, but you cannot fix it this afternoon.
A Critical in an image where upstream has already shipped a fix is a pull request.

So the alert we ship fires on the intersection, not on Trivy alone:

```
ImageOutdatedAndVulnerable = fixable Critical/High CVEs  AND  newer tag exists upstream
```

This is the whole design philosophy in one expression. We do not alert on vulnerabilities. We alert on
**vulnerabilities somebody can act on today**, and we accept that this means staying quiet about the rest.

The cost of that choice is a dependency: version-checker is load-bearing for the flagship alert while shipping no
alerts of its own. See "Known gaps" below.

## Admission: Kyverno stays, Gatekeeper goes

We previously ran both Kyverno and Gatekeeper. Two admission webhooks is not redundancy — it is two failure points
in the API-server write path, and a wedged webhook does not page you, it stops the cluster accepting writes.

The split turned out to be unusually clean. Every rule Kyverno runs in KubeAid is `generate` or `mutate` — five
generate rules and six mutate rules, and **zero validate rules**:

| Policy | Rule type | What it does |
| ------ | --------- | ------------ |
| `resourcequota-limitrange-generator` | generate | Creates the default ResourceQuota and LimitRange in every namespace |
| `harbor-proxy-cache-mutate` | mutate | Rewrites `docker.io` / `ghcr.io` / `registry.k8s.io` refs to the Harbor pull-through cache |
| `cluster-wide-secret-duplication` | generate | Clones a source secret into matching namespaces |

Both Gatekeeper constraints, by contrast, were pure validation: `K8sRequiredResources` and
`CronJobForbidConcurrency`.

Kubernetes has had **ValidatingAdmissionPolicy** in-tree and generally available since 1.30 — CEL expressions
evaluated inside kube-apiserver, with no webhook, no TLS certificate rotation, and no extra pods. Every cluster
KubeAid manages is well past 1.30.

So the two Gatekeeper constraints move to `ValidatingAdmissionPolicy`, and Gatekeeper is removed. This is the
important nuance: **porting them to Kyverno would have relocated a webhook; porting them in-tree removes one.**
Same enforcement, one less thing in the write path that can wedge an API server.

Kyverno stays because `ValidatingAdmissionPolicy` only validates. Generation and mutation have no in-tree
equivalent — `MutatingAdmissionPolicy` is far less mature — so Kyverno survives on precisely the capability the
built-in mechanism does not have.

Worth naming plainly: with `synchronize: true` on every generate rule, Kyverno in KubeAid behaves as a
reconciling controller, not an admission gate. Delete a generated ResourceQuota and it comes back. That is a
GitOps-shaped job running outside ArgoCD, justified because ArgoCD cannot react to "a namespace just appeared."

## Runtime: Tetragon, not KubeArmor

Both are eBPF node agents. KubeArmor's genuine advantage is *inline* enforcement through Linux Security Modules —
it denies an operation at the LSM hook before it runs, where Tetragon observes the syscall and then SIGKILLs,
which is a race rather than a block.

That advantage is switched off in practice. Our KubeArmor configuration sets every posture to audit:

```yaml
defaultFilePosture: audit
defaultNetworkPosture: audit
defaultCapabilitiesPosture: audit
```

With enforcement off, KubeArmor and Tetragon do the same job — observe and log to the same OpenObserve pipeline —
and KubeArmor does it with fewer event types and shallower process ancestry. Setting every posture to audit is an
honest admission that block mode is not operationally ready, because it is not: an allow-list that blocks means
any new code path becomes an outage.

Two further reasons:

**KubeArmor's model does not scale to a managed fleet.** Per-workload process/file/network allow-lists require
policy authored and maintained per application, per customer. That is a consulting engagement per app. Tetragon's
shape — a small set of generic TracingPolicies for reverse shells, container exec, writes to `/etc`, privilege
escalation — ships identically to every cluster with no per-customer authoring.

**We already run Cilium.** Tetragon is the same project and the same eBPF datapath. One fewer foreign agent, and
one fewer subsystem the team must be independently expert in. Tetragon's kernel requirement is also milder (BTF,
≥ 5.4) than KubeArmor's BPF-LSM path (≥ 5.7 with `lsm=bpf`).

If a customer contractually requires true blocking enforcement, `kubearmor` remains in the repo and can be enabled
for that cluster. That is the one case where its LSM model genuinely beats kill-after-detect.

## Compliance coverage

A control framework does not ask "do you run a scanner". It asks whether you can produce evidence, on demand,
that vulnerabilities are identified, prioritised, remediated, and that the process is monitored. This is what the
stack produces, and against which control families it maps.

**This is a mapping, not a certification.** It shows where evidence comes from. An auditor still decides whether
the evidence is sufficient.

### Kubernetes-specific benchmarks

`trivy-operator` ships these compliance specs and reports against them as `ClusterComplianceReport` resources:

| Spec | Framework |
| ---- | --------- |
| `k8s-cis` | CIS Kubernetes Benchmark |
| `k8s-nsa` | NSA / CISA Kubernetes Hardening Guidance |
| `k8s-pss-baseline` | Pod Security Standards — baseline |
| `k8s-pss-restricted` | Pod Security Standards — restricted |
| `eks-cis`, `rke2-cis` | Distribution-specific CIS benchmarks |

Pod Security Standards are additionally enforced, not just reported, by the in-tree Pod Security Admission
controller.

### Control families

| Framework | Control | Covered by | Evidence produced |
| --------- | ------- | ---------- | ----------------- |
| ISO 27001:2022 | A.8.8 Management of technical vulnerabilities | trivy-operator + version-checker | `VulnerabilityReport` CRs, `ImageOutdatedAndVulnerable` alert history |
| ISO 27001:2022 | A.8.16 Monitoring activities | Tetragon → OpenObserve | Process, network and file event stream with retention |
| ISO 27001:2022 | A.8.9 Configuration management | Kyverno + VAP + ArgoCD | Policy definitions in Git, admission decisions, drift reconciliation |
| SOC 2 | CC7.1 — vulnerability identification | trivy-operator | Continuous scan reports, compliance reports |
| SOC 2 | CC7.2 — anomaly monitoring | Tetragon | Runtime event stream |
| SOC 2 | CC6.6 / CC6.8 — boundary and malicious-software controls | Cilium network policy, Kyverno admission | Enforced policy in Git |
| PCI DSS v4.0 | 6.3.1 — identify security vulnerabilities | trivy-operator | Severity-ranked findings with CVE IDs |
| PCI DSS v4.0 | 6.3.3 — patch within defined windows | version-checker join | Fires only when a fix is available, so the clock is meaningful |
| PCI DSS v4.0 | 11.3.1 — internal vulnerability scanning | trivy-operator | Continuous, not quarterly |
| PCI DSS v4.0 | 10.2 — audit logging | Tetragon → OpenObserve | Runtime audit trail |
| NIS2 Art. 21(2)(b) | Incident handling | Tetragon + Alertmanager | Detection events and alert history |
| NIS2 Art. 21(2)(d) | Supply chain security | trivy-operator SBOM, Harbor | SBOM per image, registry provenance |
| NIS2 Art. 21(2)(e) | Vulnerability handling and disclosure | trivy-operator + version-checker | The full identify → fix-available → remediate chain |

Higher-level GRC framing — mapping these to a customer's own control set, tracking exceptions and evidence over
time — belongs in `ciso-assistant`, not in the scanners.

### Where the mapping is weak, honestly

- **Unfixed vulnerabilities are invisible.** `ignoreUnfixed: true` means a Critical with no upstream patch is
  never reported. That is deliberate — it keeps the alert actionable — but if an auditor asks "are you exposed to
  CVE-X" and X has no fix, this stack answers no. A periodic unfiltered scan is the compensating control, and it
  is not currently automated.
- **No malware scanning.** Nothing in the standard scans nodes for malware. Kubescape offers ClamAV-based
  scanning if a framework requires it explicitly.
- **Runtime enforcement is detection-only.** Tetragon is deployed without TracingPolicies, so today it observes
  and does not block. Frameworks asking for preventive runtime controls are not satisfied by the default.

## Known gaps

These are verified defects in the current implementation, recorded so they are not rediscovered.

**`TrivyOperatorScannerStuck` cannot fire.** The alert queries
`trivy_resource_last_scan_timestamp_seconds`. That metric does not exist — trivy-operator exposes no last-scan
timestamp metric of any kind. The alert must be rebuilt on a different signal (report freshness via
kube-state-metrics custom resource state, or `absent()` on a metric that does exist).

**The `ImageOutdatedAndVulnerable` join fails for short-form image references.** The recording rule builds its
join key as `image_registry + "/" + image_repository`, so a Docker Hub image becomes
`index.docker.io/library/nginx`. version-checker derives its `image` label by pure string splitting on
`container.Image` with no registry normalisation, so the same image is labelled `nginx`. The join matches only
where the pod spec already carries a fully-qualified reference. It is a partial, silent failure — the alert works
for some images and quietly cannot fire for others.

**`version-checker` is load-bearing but unmonitored.** It ships no PrometheusRule. If it stops reporting, the
flagship CVE alert goes quiet with no signal — a fail-open, and the same trap already worked through on
`backup-exporter`. It needs an `absent()`-style watchdog.

**`+` is used as a join operator.** The expression works only because
`version_checker_is_latest_version == 0` filters to zero, making `count + 0 = count`.
`and on (image, current_version)` states the intent and does not depend on the right-hand value. Separately,
`group_left(latest_version)` against a `sum by (…, latest_version)` errors many-to-many if one image ever reports
two `latest_version` values.

**`NOTES.txt` advertises a metric that does not exist.** It tells users to query
`trivy_image_vulnerabilities_id`. The real metric is `trivy_vulnerability_id`.

**Enabling `harbor-proxy-cache` would fail the CVE alerting open.** The policy rewrites image references to the
Harbor pull-through cache. A pull-through cache only holds tags somebody already pulled, so version-checker would
report the newest tag *in the cache* rather than upstream — under-reporting available upgrades, and going quiet
precisely when a cluster is behind. Resolve this before enabling the policy anywhere.

## What we deliberately do not do

- **We do not run two tools in the same layer by default.** Kubescape and KubeArmor stay in the repo as opt-ins
  for specific customer requirements, never as a second source of the same finding.
- **We do not alert on unfixable vulnerabilities.** See the trade-off above.
- **We do not scan for the sake of a number.** Every scanner in the standard either drives an alert or produces
  compliance evidence. A tool doing neither is removed.
- **We do not accept an alert we have not seen fire.** Given the gaps above, an untested alert rule is treated as
  broken until a test proves otherwise.

## Summary

| Decision | Chosen | Removed / opt-in |
| -------- | ------ | ---------------- |
| CVE scanning | `trivy-operator` | `kubescape-operator` → opt-in |
| Upgrade availability | `version-checker` | — |
| Admission — mutate/generate | `kyverno` | — |
| Admission — validate | in-tree `ValidatingAdmissionPolicy` | `gatekeeper` → removed |
| Runtime | `tetragon` | `kubearmor` → opt-in |
