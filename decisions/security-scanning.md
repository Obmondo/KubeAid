# Security scanning in KubeAid

**One tool per layer. Each has to answer a question no other tool in the stack answers.**

Security tooling for Kubernetes is easy to buy and hard to run. Every vendor demos well: point it at a cluster,
watch a number appear, feel safer. Six months later you have four agents on every node, three overlapping
findings databases, and a Critical count nobody has looked at since week two.

This document records what we run, what we refuse to run, and why.

---

## Quick reference

| # | Layer | Question it answers | When | KubeAid standard | Status |
| - | ----- | ------------------- | ---- | ---------------- | ------ |
| 1 | Admission | Should this be allowed to exist? | API-server write | Kyverno (mutate/generate) + in-tree ValidatingAdmissionPolicy (validate) | shipped |
| 2 | Detection | What is wrong with what is running? | continuously | trivy-operator + version-checker | shipped |
| 3 | Runtime | What is it doing right now? | at execution | Tetragon | shipped, opt-in |
| 4 | Exposure | What can an attacker reach, and what does it look like to them? | scheduled, from outside | OpenVAS / Greenbone | **decided, not yet implemented** |

Layers 1–3 look *inward* from a position of trust — they read the API server. Layer 4 is the only one that looks
at the cluster the way an attacker does, from a position of no access at all.

**Rule:** running two tools in the same layer is not defence in depth. It is two findings databases that will
disagree, and an operator who has to reconcile them.

## Choosing for a cluster

| If you need… | Do this |
| ------------ | ------- |
| The default posture | Nothing. Layers 1–2 are on. |
| Runtime visibility | Enable `tetragon` (kubeaid-cli asks) |
| CVE relevancy — "is this actually loaded?" | Enable `kubescape-operator` for that cluster only. Never as a second alert source. |
| Inline blocking, not just observation | Enable `kubearmor`, accept the LSM blast radius |
| Perimeter / attack-surface evidence | Stand up OpenVAS out-of-cluster — see layer 4 |
| To stop shipping CVE detail off-site | `appConfig.securityPosture.enabled: false` on kubeaid-agent |

---

## The failure mode we design against

The obvious risk is missing a vulnerability. That is not the risk that actually hurts.

Two things go wrong far more often:

1. **Alert fatigue.** A scanner reports 3,000 Criticals. Nobody can act on 3,000 of anything, so the report gets
   ignored — and the twelve findings that mattered are ignored with it.
2. **An alert that silently never fires.** A PromQL join whose label sets do not match produces no series. No
   series means no alert. No alert looks exactly like "nothing is wrong."

The second is worse because it is invisible. A scanner that reports too much and a scanner that reports nothing
both end in the same place: an operator who does not trust the tool.

Every decision below is made to avoid that.

---

## 1. Admission — Kyverno stays, Gatekeeper goes

Kyverno is used for **mutate and generate** only: 5 generate policies, 6 mutate, 0 validate. Validation is done
by in-tree `ValidatingAdmissionPolicy` (CEL, GA since 1.30), which needs no webhook, no controller, and cannot
fail the API server closed.

Gatekeeper was removed: it duplicated validation that the API server now does natively, at the cost of another
webhook in the write path.

## 2. Detection — Trivy, not Kubescape

Both scan images for CVEs and find substantially the same things. We chose Trivy for a reason unrelated to
detection quality: **it is the one wired into an alerting path.**

Kubescape ships `prometheusExporter: disable` and `serviceMonitor.enabled: false`, and KubeAid overrides neither
— as packaged it emits nothing to Prometheus. Its findings live in CRDs.

> Findings that never reach Alertmanager are not security posture. They are a dashboard nobody opens.

Cost is the secondary reason. Trivy adds two workloads. Kubescape adds seven Deployments, four CronJobs, and a
privileged eBPF DaemonSet on every node — the last being the most common thing customers refuse to approve.

**What we give up:** Kubescape's *relevancy* — an eBPF agent observes which libraries are actually loaded and
filters the CVE list to packages in use. Nothing else in KubeAid does this. We accept it because our Trivy config
reaches a similarly short list by another route:

```yaml
trivy:
  ignoreUnfixed: true            # a CVE with no fix is not a work item
  severity: "CRITICAL,HIGH"
```

Relevancy answers *"is this reachable?"*. Our filter answers *"is this actionable?"*. Not the same guarantee —
relevancy can tell you a Critical is unreachable and safe to defer, and our filter cannot.

**version-checker** is part of the standard because a CVE finding without an available upgrade is not a work
item. It turns "this image is vulnerable" into "this image has a newer tag" — the difference between a finding
and a ticket.

## 3. Runtime — Tetragon, not KubeArmor

Tetragon observes (eBPF, no enforcement by default). KubeArmor can block inline via LSM. We default to
observation: an enforcement mistake takes down a workload, and the policies have to be tuned against real traffic
before blocking is safe.

KubeArmor stays in the repo with all postures set to `audit`. kubeaid-agent reports both engines when present, so
enabling KubeArmor later does not create a blind spot.

## 4. Exposure — OpenVAS / Greenbone

> **Status: decided, not yet implemented.** This section records the shape and the reasoning. No chart ships yet.

### Why the first three layers cannot answer this

Trivy knows a package inside an image is vulnerable. It does not know that the container sits behind a
LoadBalancer with a public IP, that a NodePort is open to `0.0.0.0`, or that kubelet's port answers to the
internet. Every existing layer reads the API server — they see the cluster as its administrator. An attacker has
no API access. They have a port scan.

Nothing in the stack currently sees the cluster from outside, and the outer layer is the one most exposed to
attack. On bare metal it is worse: nodes carry services Kubernetes never knew about — SSH, BMC/IPMI, monitoring
agents, leftovers from provisioning — and on a cluster without LinuxAid nothing else scans the host at all.

### Two vantage points, both required

| Vantage | Scans | Answers |
| ------- | ----- | ------- |
| **External** | public IPs — ingress LBs, node public IPs, API-server endpoint | What does the internet see? Ground truth for the perimeter. |
| **Internal** | node IPs and internal service IPs, from inside the segment | What can a compromised pod or a contractor VPN session reach once past the firewall? |

An external-only scan reports a firewall as security. The internal scan is what shows the lateral-movement
surface behind it. Neither substitutes for the other.

### What it finds that nothing else does

- Exposed management ports — kubelet, etcd, the NodePort range
- TLS reality on ingress endpoints: expired or self-signed certs, weak ciphers, downgrade
- Default credentials on exposed admin interfaces
- Host-OS services on nodes, outside Kubernetes entirely

### Deployment shape

**It does not run in the cluster it scans.** A scanner inside the perimeter cannot tell you what the perimeter
looks like, and one sharing a failure domain with its target is useless during the incident that matters. Run it
as a dedicated host per network zone.

Greenbone is heavy — the NVT feed is large, sync is slow, and a scan is minutes to hours per range. That rules
out continuous scanning and it does not matter: this surface changes when someone changes it, not continuously.

**Cadence:** weekly, diffed against the previous run. **Alert on newly-appeared exposure, not on total count** —
consistent with the anti-fatigue rule above. A stable list of known-accepted open ports must not page anyone.

> **Authorisation.** This is the only tool in the stack that touches something outside the cluster boundary.
> Scan only ranges we own or are contracted to test, with written scope. An external scan of a customer's public
> IPs without that is not a technical decision.

---

## Compliance coverage

Trivy's `ClusterComplianceReport` produces evidence for CIS Kubernetes Benchmark, NSA/CISA Kubernetes Hardening,
and Pod Security Standards. ConfigAudit, RBAC assessment and Infra assessment reports cover the
least-privilege and configuration control families.

**Where the mapping is weak, honestly:** these produce evidence for *technical* controls only. Nothing here
speaks to access review, change management, vendor risk, or incident response — the control families auditors
spend most of their time on. A tool that reports 94% CIS compliance is reporting on the 6% of a framework it can
see.

Layer 4 closes part of a real gap here: most frameworks ask for external vulnerability scanning explicitly, and
until OpenVAS exists we have no evidence for it.

## What we deliberately do not do

- **No two tools in the same layer by default.** Kubescape and KubeArmor stay as opt-ins for specific customer
  requirements, never as a second source of the same finding.
- **No alerting on unfixable vulnerabilities.** See the trade-off above.
- **No scanning for the sake of a number.** Every scanner either drives an alert or produces compliance
  evidence. A tool doing neither is removed.
- **No alert we have not seen fire.** An untested alert rule is treated as broken until a test proves otherwise.

## Known gaps

| Gap | Status |
| --- | ------ |
| `TrivyOperatorScannerStuck` queried a metric that does not exist, so it could never fire | fixed in #176 — replaced with `absent()` on a metric that does exist |
| `ImageOutdatedAndVulnerable` join failed for short-form image references — partial, silent | fixed in #176 — the PromQL correlation is deleted, and kubeaid-agent now joins on canonical references in Go |
| `+` used as a join operator, and a many-to-many risk in `group_left` | fixed in #176 — the recording rules are gone |
| `NOTES.txt` advertised a metric that does not exist | fixed in #176 |
| **`version-checker` has no watchdog.** It ships no PrometheusRule, so if it stops reporting there is no signal | **open** — no longer load-bearing for an alert, but still silent on failure |
| **`harbor-proxy-cache` would fail upgrade reporting open.** A pull-through cache only holds tags somebody already pulled, so version-checker would report the newest tag *in the cache* rather than upstream — under-reporting precisely when a cluster is behind | **open** — resolve before enabling the policy anywhere |
| **No external attack-surface scanning.** See layer 4 | **open** |

## Summary

| Decision | Chosen | Removed / opt-in |
| -------- | ------ | ---------------- |
| CVE scanning | `trivy-operator` | `kubescape-operator` → opt-in |
| Upgrade availability | `version-checker` | — |
| Admission — mutate/generate | `kyverno` | — |
| Admission — validate | in-tree `ValidatingAdmissionPolicy` | `gatekeeper` → removed |
| Runtime | `tetragon` | `kubearmor` → opt-in |
| Exposure | `openvas` / Greenbone, out-of-cluster | — (not yet implemented) |
