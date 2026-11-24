# KubeAid Agent

The KubeAid Agent (`ghcr.io/obmondo/kubeaid-agent`) is Obmondo's in-cluster agent. It authenticates to the
Obmondo API over mTLS and reports cluster state — node counts, Kubernetes version, security posture — and can run
Argo CD syncs during agreed service windows. This chart is authored in KubeAid (not a vendored upstream wrapper).

## What this chart deploys

Three Deployments and a DaemonSet from one Argo CD application. The exporters are **local subcharts**
under `charts/`, resolved from the working tree — no repository, no `Chart.lock`, no
`helm dependency update`:

```
kubeaid-agent/
  templates/                           the agent
  charts/kubeaid-security-exporter/    symlink to ../../kubeaid-security-exporter
  charts/linuxaid-security-exporter/   symlink to ../../linuxaid-security-exporter
  charts/kubeaid-backup-exporter/      symlink to ../../kubeaid-backup-exporter
```

All three exporters are **standalone charts symlinked in**, the way charts here already borrow
`kubeaid-addons`. A cluster switches one on beside the agent, or deploys it as its own Argo CD
application — the node exporter into `monitoring`, say, next to node-exporter.

| Workload | Purpose |
|---|---|
| `kubeaid-agent` | Talks to the Obmondo API over mTLS. Holds the credential; holds no CRD access. |
| `kubeaid-security-exporter` | Collects the cluster's security posture and serves it at `/api/v1/security-posture`. Holds cluster-wide read; talks to nothing outside the cluster. |
| `linuxaid-security-exporter` | A DaemonSet reporting each node's installed packages to a Vuls server for CVE scanning, and serving the findings as metrics. Reads two paths on its node; holds no cluster access. |
| `kubeaid-backup-exporter` | Reports backup health for PostgreSQL, Velero, MongoDB and sealed-secrets, and ships their alerts. |

The two `*-security-exporter` subcharts cover different layers: `kubeaid` looks at the cluster and the
container images it runs, `linuxaid` at the operating system underneath them.

The Deployments have **three ServiceAccounts and are not one pod with sidecars**. A pod carries a single
ServiceAccount, so co-locating them would hand the workload holding the Obmondo credential the exporters'
cluster-wide read — the coupling that separating them removed in the first place. Keeping them apart also
bounds the blast radius: a security collection pass holds every VulnerabilityReport in memory at once, and as
a sidecar an OOM there would take down the agent, and with it the cluster-liveness ping.

Each exporter's switch and settings live under its **chart name**, which is how Helm keys subchart
values; the parent `values.yaml` lists all three. A chart rename therefore moves a cluster's key,
and Helm has no fallback for the old one — a dependency `condition` takes the first path that
exists, and the subchart's own defaults always provide it. Rename a cluster's keys in the same
change that moves it to a release carrying the rename.

Each exporter is independently switchable, and **all three default to `false`**. `kubeaid-backup-exporter.enabled`
because it cannot start without S3 credentials for the backends it reports on;
`kubeaid-security-exporter.enabled` because it holds cluster-wide read across eight API groups, which a chart
must not grant to every cluster that installs the agent; `linuxaid-security-exporter.enabled` because it puts
a pod on every node and reports to a Vuls server. Neither security exporter needs credentials of its own —
the node one reuses the cluster's `obmondo-clientcert` — so turning either on is nothing more than
`enabled: true`.

Each exporter names its objects after its chart, not the release: `kubeaid-security-exporter`,
`kubeaid-backup-exporter` and `linuxaid-security-exporter`. The agent finds the backup exporter at runtime by
its fixed label `app.kubernetes.io/component=backup-exporter` (kubeaid-cli does the same from v0.31.10), and
reaches kubeaid-security-exporter at the Service name in `appConfig.securityPosture.exporterURL`, so renaming
that one without the URL silently stops reporting. linuxaid-security-exporter reports to Vuls itself, and the
agent never contacts it.

Upgrading from a chart before 0.6.0 renames the backup exporter's objects from `backup-exporter`. Sync with
prune: the agent refuses to choose between two exporter Deployments, so backup reporting stalls until the old
one is gone.

## Why it's in KubeAid

It is the link between a KubeAid cluster and the Obmondo platform. On clusters with `obmondo.monitoring` enabled,
`kubeaid-cli` deploys it as the `kubeaid-agent` Argo CD app (namespace `obmondo`), seals the mTLS client cert into
the `obmondo-clientcert` Secret, and creates the Argo CD project-role token the agent uses: a `kubeaid-agent` role
on the `kubeaid` Argo CD project, stored in the `argocd-project-role-kubeaid-agent` Secret (kubeaid-cli ≥ v0.22.4).

## Prerequisites

- `obmondo-clientcert` Secret in the release namespace: the mTLS client certificate (`tls.crt`, `tls.key`,
  `ca.crt`) issued during Obmondo onboarding. Name overridable via `obmondoAPITLSSecretName`.
- `argocd-project-role-kubeaid-agent` Secret in the `argocd` namespace, holding the Argo CD auth token under the
  `token` key (created automatically by `kubeaid-cli`). Name overridable via
  `appConfig.argocd.authTokenSecretName`.
- kube-prometheus, if `serviceMonitor` stays enabled (default `true`), and for
  `kubeaid-security-exporter.prometheusRule` on clusters where the security exporter is turned on.
- A Vuls server to report to, for `linuxaid-security-exporter`. Managed clusters use Obmondo's hosted
  `https://vuls.obmondo.com`, the default, and need nothing further; anyone else hosts it themselves with
  the [vuls-dictionary](../vuls-dictionary) chart — the nightly CVE database is roughly 7 GB on a 25 Gi
  volume — and points `vulsServer.url` at it. Its nodes must run Debian, Ubuntu, RHEL, CentOS, Rocky,
  Oracle Linux or SLES, whose package databases it can read.

The exporter additionally wants, but does not require:

- **A vulnerability scanner** — either **trivy-operator** or **kubescape-operator**. Without one it reports no
  findings, and says so rather than reporting a clean cluster.
- **version-checker**, for upgrade availability. Without it findings still ship, with upgrade availability
  unknown rather than "up to date".

Cilium, Tetragon and KubeArmor are read when present and skipped when not.

## Key values / KubeAid-specific configuration

Each subchart owns its own `values.yaml`; the table below lists what you are most likely to set, and
the parent's values file carries only the agent's own settings.

`appConfig` is rendered verbatim into the agent's config file (a ConfigMap mounted at
`/etc/kubeaid-agent/config.yaml`); a config change triggers a rollout via a checksum annotation.

| Value | Default | Meaning |
|---|---|---|
| `appConfig.obmondoAPI.url` | `https://api.obmondo.com/api` | Obmondo API endpoint (mTLS). |
| `appConfig.kubeaidUpdate.enabled` | `false` | Opt-in: schedule the service-window Argo CD sync cron job. |
| `appConfig.kubeaidUpdate.checkInterval` | `15m` | Poll cadence for an active KubeAid update service window. |
| `appConfig.nodeUpdate.enabled` | `false` | Opt-in: update the nodes' OS packages with `linuxaid-cli`, one node at a time, while the service window is open. Never drains or reboots. See [Node package updates](#node-package-updates). |
| `appConfig.nodeUpdate.jobImage` | `""` | linuxaid-cli image the update Jobs run; must contain `node-update.sh`. Required when enabled: the chart refuses to render without it. |
| `appConfig.nodeUpdate.nodeSelector` | `""` | Extra label selector for the nodes to update; always ANDed with `kubernetes.io/os=linux`. |
| `appConfig.nodeUpdate.capiMachinesOnly` | `true` | Only nodes Cluster API provisioned (not MachinePool nodes such as AKS/EKS pools). `false` on clusters without Cluster API. |
| `appConfig.nodeUpdate.updateTimeout` | `30m` | Deadline of one node's update Job. |
| `appConfig.securityPosture.enabled` | `true` | Poll the exporter and forward its snapshots to the Obmondo API. The agent collects nothing itself. |
| `appConfig.securityPosture.exporterURL` | `http://kubeaid-security-exporter` | In-cluster URL of the exporter. Matches the Service this chart creates — change both or neither. |
| `appConfig.securityPosture.pollInterval` | `1h` | Poll cadence. The submit is skipped when `collectedAt` has not advanced, so end-to-end freshness is bounded by `kubeaid-security-exporter.exporter.interval`, not by this. |
| `appConfig.prometheus.url` | `prometheus-k8s.monitoring:9090` | Prometheus the agent queries and the initContainer waits for. |
| `appConfig.nodeCount.fetchInterval` | `12h` | How often the node count is sent. Each send carries the 24h average up to 00:01 UTC that day. |
| `deployment.waitForPrometheus.enabled` | `true` | Hold the agent pod until Prometheus answers `/-/ready`. Turn off on a cluster without Prometheus. |
| `deployment.waitForPrometheus.timeoutSeconds` | `300` | How long one probe run retries before it fails and the kubelet restarts it. |
| `obmondoAPITLSSecretName` | `obmondo-clientcert` | Secret with the mTLS keypair. |
| `extraSecretReaderNamespaces` | `[]` | Extra namespaces where a secrets-read Role/RoleBinding is created for the agent. |
| `kubeaid-security-exporter.enabled` | `false` | Deploy the security exporter alongside the agent. Off by default: it holds cluster-wide read across eight API groups, so granting it is a per-cluster decision. Needs no credentials. |
| `kubeaid-backup-exporter.enabled` | `false` | Deploy the backup exporter alongside the agent. Off by default: it needs S3 credentials per backend, so enabling it without those deploys a pod that cannot work. See the [Backup Exporter guide](../../docs/guides/backup-exporter.md). |
| `kubeaid-security-exporter.exporter.interval` | `12h` | Collection cadence. Trivy refreshes its reports on a 24h TTL, so polling faster re-reads identical data. |
| `kubeaid-security-exporter.prometheusRule.upgradableThreshold` | `20` | `ImageOutdatedAndVulnerable` fires above this many images having both a fixable Critical/High CVE and a newer tag available. |
| `kubeaid-security-exporter.prometheusRule.upgradableFor` | `24h` | How long the count must hold before the alert fires. |
| `linuxaid-security-exporter.enabled` | `false` | Scan every node's packages for CVEs. Off by default: it runs a pod on each node and reports to a Vuls server. |
| `linuxaid-security-exporter.vulsServer.url` | `https://vuls.obmondo.com` | Where package lists are sent, over mTLS with `obmondo-clientcert`. |
| `linuxaid-security-exporter.scanInterval` | `12h` | How often each node scans; `randomDelay` (`1h`) spreads a cluster's first scans. |
| `linuxaid-security-exporter.hostMounts` | `[{path: /}]` | Node paths mounted read-only under `/host`. Only the package database and `/etc/os-release` are read, so it can be narrowed to those. |

## What the exporter collects

Each source is detected through API discovery and skipped when absent.

- **Vulnerabilities and least-privilege findings** from Trivy Operator's report CRs — full CVE detail
  (CVSS score, installed and fixed version, advisory link), rather than the lossy Prometheus projection.
- **Or the same from Kubescape**, read through its aggregated APIService, with per-CVE relevancy — whether the
  vulnerable code actually loaded. The two scanners are alternatives, never merged.
- **Upgrade availability**, by joining findings against version-checker on canonical image references resolved
  in Go. Rebuilding image references in PromQL fails silently.
- **Network enforcement** from Cilium — whether policy is actually realised on an app's pods, which is a
  different question from whether the app ships a policy.
- **Runtime detection posture** from Tetragon and KubeArmor — which engines are armed, and whether they
  observe or enforce.

### Which scanner is used

Exactly one, chosen by API discovery: **Trivy takes precedence, Kubescape is used where Trivy is absent.**
Merging them would double-count the same CVE from two databases that disagree at the margins, and switching an
existing cluster's scanner rewrites every finding's ID, score and link at once — which reads as mass CVE churn
rather than as a configuration change. The snapshot names the one it used in `scanner`.

Two fields differ by scanner, and both are absent rather than false when unanswerable:

| Field | Trivy | Kubescape |
|---|---|---|
| `relevant` (did the vulnerable code load) | never — Trivy cannot observe runtime | when the eBPF node-agent runs |
| `os.eosl` (base image past end of life) | yes | never — Grype has no end-of-life data |

## Node package updates

With `appConfig.nodeUpdate.enabled: true` the agent updates the OS packages of the cluster's
KubeAid-managed Linux nodes in the service window. For each node, one at a time, it creates a Job in its
own namespace that is pinned to the node, privileged, with `hostPID` and the host's `/opt/obmondo`
mounted. The Job runs `linuxaid-cli system-update --agent-controlled` on the host: packages only, no
service window handling, no reboot. The agent stops at the first failed node.

The agent never cordons, drains or reboots. A node that needs a reboot after its update shows up as
`kubeaid_agent_node_update_reboot_required == 1` and as `KubeAidNodeRebootRequired` after 24 h.

Before enabling:

- Use an agent release with `nodeUpdate` support, and set `jobImage` to a linuxaid-cli release with
  `node-update.sh`.
- The release namespace must allow privileged pods (Pod Security `privileged`). That is the same
  requirement as linuxaid-agents. KubeAid's kyverno chart has no privileged/hostPID policy. A cluster
  with its own such policy needs an exception for the `jobServiceAccount`.
- Remove any `obmondo-system-update` timer from the nodes. Its own run closes the cluster's service
  window, which stops the agent after the first node.
- The kyverno Job quota is 100 per namespace. The agent keeps one Job per node for 24 h, so raise
  `overrides.<ns>.resourceQuota.jobs` on clusters with close to 100 nodes.

The chart then adds a ClusterRole (nodes `get list patch`, events `create patch`), a Role in the release
namespace (jobs `create get`, pods `get list`), the Job service account (no bindings, no token) and the
two alerts below.

## Alerting

`KubeAidNodeUpdateFailed` (critical) fires when the node update stopped at a node, and
`KubeAidNodeRebootRequired` (warning) when a node has needed a reboot for 24 h. Both exist only with
`appConfig.nodeUpdate.enabled: true`.

The security exporter adds one alert, `ImageOutdatedAndVulnerable`. It is a count, so it fires once per cluster rather than once per
image, and the threshold is deliberately high — every real cluster carries a few of these at any moment, so a
low threshold fires everywhere on day one and gets ignored. The signal worth acting on is a pile of easy
upgrades, not the existence of one.

Collection status is exported as `security_exporter_collection` (1 ok, 0 failed, -1 not installed) but is
deliberately not alerted on: a collection failure is a debugging signal, not something worth paging for.

## Operational notes

- RBAC is least-privilege by construction, and **separate per workload**: the agent gets a purpose-built
  ClusterRole granting exactly the verbs its code calls, with secrets access on namespaced Roles and no CRD
  access at all. The exporter gets its own, covering the report CRs it reads. Neither can use the other's.
- No `watch` anywhere — neither workload builds informers.
- The exporter's rules are all consumed through a dynamic client, so no Go source references those resource
  names; removing a rule fails silently and renders the cluster as clean rather than erroring.
- `appConfig.securityPosture.enabled: true` is safe where the exporter is disabled — the poll fails, a metric
  records it, and nothing is submitted. Set it to `false` only where vulnerability detail must not leave the
  cluster.
- Both run unprivileged: non-root, all capabilities dropped, `RuntimeDefault` seccomp; the exporter also runs
  with a read-only root filesystem.
- The agent waits for Prometheus: the `wait-for-prometheus` initContainer polls `/-/ready` at
  `appConfig.prometheus.url` for `deployment.waitForPrometheus.timeoutSeconds`, then fails and is restarted by
  the kubelet, so the agent does not start while Prometheus is down. Set
  `deployment.waitForPrometheus.enabled: false` on a cluster without Prometheus.

## Docs links

- Chart source: `templates/` and [values.yaml](./values.yaml) in this directory (documented inline).
- Security exporter source: <https://gitea.obmondo.com/EnableIT/kubeaid-security-exporter>
- Node package exporter source: <https://github.com/Obmondo/linuxaid-security-exporter>, with chart docs in
  [charts/linuxaid-security-exporter](./charts/linuxaid-security-exporter)
- Backup exporter: [guide](../../docs/guides/backup-exporter.md)
- Obmondo: <https://obmondo.com>
