# openvox-operator (pilot)

Evaluation deployment of [slauger/openvox-operator](https://github.com/slauger/openvox-operator),
a Kubernetes operator that manages OpenVox (Puppet) Server, the CA and OpenVoxDB
through CRDs.

**This does not replace `argocd-helm-charts/openvox`.** That chart stays the
shipping path. This one exists to answer: can we drop our hand-maintained
puppetserver chart and let an operator own the stack?

## What it deploys

One ArgoCD app, three subcharts:

| Subchart | Provides |
|---|---|
| `openvox-operator` 0.9.6 | CRDs + the controller Deployment |
| `openvox-stack` 0.9.6 | The CRs: `Config`, `CertificateAuthority`, `Server`, `Pool`, `Database`, `ReportProcessor` |
| `kubeaid-addons` 0.1.0 | CNPG `Cluster` for OpenVoxDB's PostgreSQL |

Plus KubeAid-local templates ported from the `openvox` chart: the code PVC,
`gfetch`, `puppet-agent-exporter`, the Prometheus Role/RoleBinding, the Traefik
`IngressRouteTCP` routes and the blackbox `Probe`.

The operator only creates ClusterIP Services — one per `Pool` (named after the
Pool CR, i.e. `<release>-server`) and one for the `Database` (named after the
Database CR). Both use a port named `https`. The IngressRouteTCP templates
target those names.

The controller is scoped to a single namespace (`scope.mode: namespace`), so it
cannot reconcile anything outside the pilot namespace.

## Install

```sh
kubectl create namespace puppetserver-pilot
helm dependency update
helm template pilot . -n puppetserver-pilot   # sanity check
```

Via ArgoCD: CRDs live in the operator subchart's `crds/` directory. ArgoCD
renders with `--include-crds`, but the CRs in the same sync will fail their
first dry-run because the CRDs do not exist yet. Use `ServerSideApply=true` plus
a retry, or split the CRDs into an earlier sync wave.

Requires the `cloudnative-pg` operator in the cluster (already a KubeAid addon).

## Values mapping from `argocd-helm-charts/openvox`

Every value in the current chart, and where it went.

| Current (`openvox`) | Here | Notes |
|---|---|---|
| `puppetserver.puppetserver.masters.*` | `openvox-stack.servers[0]` | Single `ca: true, server: true` instance; compilers were already unused |
| `OPENVOXSERVER_JAVA_ARGS` | `servers[0].javaArgs` | identical |
| `OPENVOXSERVER_MAX_ACTIVE_INSTANCES: 4` | `servers[0].maxActiveInstances` | identical |
| `OPENVOXSERVER_MAX_REQUESTS_PER_INSTANCE: 10000` | `config.puppetserver.maxRequestsPerInstance` | identical |
| `OPENVOXSERVER_ENVIRONMENT_TIMEOUT: 0` | `config.puppet.environmentTimeout` | identical |
| masters resources 3096Mi / 1 cpu | `servers[0].resources` | rounded to 3Gi |
| `masters.updateStrategy: Recreate` | — | operator owns the Deployment strategy; not exposed |
| `masters.ingress.enabled: false` | `pools[*]` ClusterIP, no route | Traefik IngressRouteTCP still fronts it |
| `persistence.code.size: 8Gi` | `code.persistence.size` | PVC now rendered by this chart, not the subchart |
| `puppeturl: LinuxAid.git` | — | operator has no r10k; gfetch keeps this job (gap #2) |
| `r10k.enabled: false` | — | already unused |
| `hiera.eyaml.existingSecret: eyaml-keys` | `config.puppet.hieraConfig` (partial) | secret mount unresolved (gap #3) |
| `AUTOSIGN: autosign.conf` + entrypoint | `signingPolicies` | now a CR; left empty on purpose (gap #6) |
| `OPENVOXSERVER_ENC_PATH` + entrypoint | `nodeClassifier` (disabled) | exec → HTTP only (gap #4) |
| `configure_puppet_conf.sh` entrypoint | — | operator manages cert paths itself; no longer needed |
| `configure_prometheus_exporter.sh` | — | no entrypoint hook (gap #5) |
| `OPENVOX_REPORTS: puppetdb,prometheus` | `config.puppet.reports: puppetdb` + `reportProcessors` | prometheus half unresolved (gap #5) |
| `puppetdb.*` | `openvox-stack.database.*` | javaArgs and resources carried over; `persistence.size: 1Gi` dropped — OpenVoxDB is stateless here |
| `OPENVOXDB_POSTGRES_*` | `database.postgres.*` | now a secretRef instead of env |
| `global.postgresql.*` (CNPG) | `global.postgresql.*` | unchanged, same kubeaid-addons subchart |
| `metrics.prometheus.puppetdb.serviceMonitor` | — | no ServiceMonitor for the Database CR (gap #10) |
| `metrics.prometheus.jmx.enabled: false` | `config.metrics.jmx.enabled: false` | identical |
| `puppetboard.*` | — | **not provided by the operator at all** (gap #11) |
| `puppetAgentExporter.*`, `gfetch.*`, `blackbox.probe` | same keys | templates ported into this chart |
| `puppetserver.puppetserver.masters.fqdns.alternateServerNames` | `ingressRouteTCP.puppetserver.fqdn` | now explicit, empty by default |
| `puppetserver.puppetdb.fqdns.alternateServerNames` | `ingressRouteTCP.puppetdb.fqdn` | as above |
| `customerid` | `customerid` | only used for the Prometheus RoleBinding namespace |

## Gaps vs the current `openvox` chart

These are the things that must be resolved before any migration. Each is a
verification item for the pilot.

1. **Alpha API.** Everything is `v1alpha1`, single maintainer. Expect breaking
   CRD changes between releases. Images are pinned to `v0.9.6` here; upstream
   defaults to `latest`, which is not acceptable for ArgoCD.

2. **Code delivery.** Upstream wants Puppet code as an OCI image volume
   (needs Kubernetes **1.35+** with the `ImageVolume` feature gate) or an
   externally-managed PVC. There is no r10k/g10k. This chart uses the PVC path
   (`config.code.claimName: openvox-code`) so the existing `gfetch` deployment
   can keep populating it from `LinuxAid.git` unchanged. **Verify:** gfetch can
   write to that PVC while the server pod has `readOnlyRootFilesystem: true`,
   and the server picks up new environments without a restart.

3. **Hiera / eyaml.** Not documented upstream. We depend on the `eyaml-keys`
   secret and a hiera config. **Verify:** whether `config.puppet.hieraConfig`
   plus a mounted secret is enough, or whether eyaml is simply unsupported.
   This is currently the single biggest blocker.

4. **ENC.** We use `external_nodes = exec` with `linuxaid_enc.rb` on disk. The
   operator's `NodeClassifier` CRD only supports an **HTTP** classifier. Left
   disabled. **Verify:** cost of wrapping the ENC script in a small HTTP
   service, or whether exec can be configured through `puppet.extraConfig`.

5. **Prometheus reporting.** Today `OPENVOX_REPORTS: puppetdb,prometheus` plus a
   custom entrypoint that installs the `fugit` gem and writes a textfile
   dropzone read by `puppet-agent-exporter`. The operator has no custom
   entrypoint mechanism. **Verify:** whether a `ReportProcessor` CR can cover
   this, or whether `puppet-agent-exporter` needs a different input.

6. **Autosign.** Currently a custom entrypoint writing `autosign.conf`. Here it
   is a `SigningPolicy` CR — deliberately left empty. Set a preshared key from
   a sealed secret before letting any real agent check in. Do **not** use
   `any: true`.

7. **CA migration.** The operator owns CA state in its own PVC. **Verify:**
   whether the existing CA from `puppetserver-ca-pvc` can be imported (see
   `ca.intermediateCA` / `ca.external`), or whether every agent has to
   re-enrol. If it is a re-enrol, that alone decides the migration timeline.

8. **DB credentials.** `database.postgres.credentialsSecretRef` points at the
   CNPG app secret `openvox-pgsql-app`. **Verify:** the operator reads the
   `username` / `password` keys CNPG writes, and that `sslMode: require`
   negotiates against CNPG.

9. **KubeAid extras.** Ported. `gfetch`, `puppet-agent-exporter`, the
   Prometheus RBAC, the blackbox `Probe` and both `IngressRouteTCP` objects now
   render from this chart. Set `ingressRouteTCP.puppetserver.fqdn` and
   `ingressRouteTCP.puppetdb.fqdn` — both default to empty, which renders
   nothing. **Verify:** the code PVC is `ReadWriteOnce` (same as today), so
   gfetch and the Server pod must land on the same node; switch
   `code.persistence.accessModes` to `ReadWriteMany` if that turns out to be a
   problem with the operator's pod placement.

10. **OpenVoxDB metrics.** The `Database` CR exposes no ServiceMonitor option,
    so `metrics.prometheus.puppetdb.serviceMonitor` has no equivalent.
    **Verify:** whether the DB pod exposes a metrics port we can scrape with a
    hand-written ServiceMonitor.

11. **Puppetboard is gone.** The operator does not ship it and there is no CR
    for it. **Verify:** whether we run puppetboard as a separate plain
    Deployment pointing at the `Database` service, or drop it.

12. **No immutable image tags.** `ghcr.io/slauger/openvox-operator` and
    `openvox-server` publish only `latest` and 7-char git SHAs — no version
    tags, despite the chart's `appVersion: 0.9.6`. The operator chart has an
    `image.digest` field so it can be pinned; `openvox-stack` has none, so the
    server image cannot be pinned at all. `openvox-db` does have semver tags
    (`0.3.0`). **Blocker for production** — we do not ship `latest` to
    customers.

13. **Code volume layout mismatch.** The operator mounts the code PVC at
    `/etc/puppetlabs/code/environments`, read-only — the volume root *is* the
    environments directory. Our gfetch mounted it at `/etc/puppetlabs/code` and
    wrote `environments/<branch>` inside, so the server saw `environments/` and
    `hiera-data/` as environment names and crashed with
    `EnvironmentNotFound: master`. Fixed here via `gfetch.codeMountPath`.
    The unresolved half: **there is nowhere to put hiera-data.** The operator
    mounts nothing at `/etc/puppetlabs/code`, so the `linuxaid-config-*` repos
    have no visible path on the Server pod. Compounds gap #3.

14. **`pg_trgm` is not created.** OpenVoxDB refuses to start without the
    PostgreSQL `pg_trgm` extension. Created by hand for the pilot.
    Not an upstream bug: there is a third published chart,
    `oci://ghcr.io/slauger/charts/openvox-db-postgres` 0.9.6, which renders a
    CNPG `Cluster` with `bootstrap.initdb.postInitApplicationSQL:
    [CREATE EXTENSION IF NOT EXISTS pg_trgm]` plus a `postInitSQL` escape
    hatch. We use `kubeaid-addons` for CNPG instead, to keep the KubeAid
    backup/monitoring conventions. **Decision needed:** add a
    `postInitApplicationSQL` knob to kubeaid-addons (preferred), or switch this
    chart's PostgreSQL to `openvox-db-postgres` and give up those conventions.

## Cluster test, kcm.obmondo.com, 2026-07-31

Deployed to namespace `puppetserver-pilot` (k8s 1.33, so the OCI ImageVolume
path was unavailable as predicted). Findings, in the order they were hit:

| # | Result |
|---|---|
| Chart renders / CRDs apply | OK — 26 objects, CRDs server-side validate |
| `environmentTimeout: "0"` | **Upstream bug.** `openvox-stack` renders it unquoted, the CRD types it `string`, the API server rejects the Config. Worked around with `unlimited`. |
| Image tags | **Blocker.** See gap #12 — `v0.9.6` does not exist; nothing to pin to. |
| CA bring-up | **Blocker.** Operator sets `runAsUser: 1001` with no `fsGroup`, and no CRD exposes a securityContext. Verified on this cluster with a probe pod: `ceph-filesystem` DENIED, `rook-ceph-block` DENIED (`root:root 0755`), `openebs-hostpath` OK. So it fails on any CSI volume, not just CephFS. Pilot works around it with node-local `openebs-hostpath`, which is not viable in production. |
| CA once running | OK — `Ready`, 5y cert, valid to 2031-07-30. Renewal/CRL handled by the controller as advertised. |
| Code delivery | Works after gap #13's mount fix, gfetch needs 2Gi (1Gi OOMKills on a cold clone). |
| hiera-data | **No path exists** on the Server pod — see gap #13. |
| Server bring-up | **OK.** `Server` CR `Running`, 1/1 ready, `/status/v1/simple` returns `running`. Both Pool Services have endpoints, and their names (`<release>-ca`, `<release>-server`) match what the IngressRouteTCP templates target. |
| OpenVoxDB | **OK after creating `pg_trgm` by hand** — see gap #14. `Database` CR `Running`, 1/1. |
| Report processor / agent run | Not yet exercised — no agent has checked in. |

Bottom line: two hard blockers (#12 image pinning, and the missing `fsGroup`)
that cannot be fixed from values and need upstream changes, plus gap #13's
missing hiera-data path which has no obvious answer. Everything else has a
workaround. Worth filing #12, #13, #14 and the `environmentTimeout` quoting bug
upstream once the pilot is fully exercised.

Note on the pilot's code tree: the volume was populated under the old layout,
so `master` currently exists as a symlink at the volume root pointing at
`environments/master`. A clean re-clone with `gfetch.codeMountPath` set
correctly makes that unnecessary.

## Wins if it pans out

- CA lifecycle, renewal and CRL handled by the controller — drops
  `puppetserver-ca-backup-cronjob` and `puppet-crl-updater-cronjob`.
- Rootless, OpenShift-compatible.
- Removes our fork of `puppetserver-helm-chart` and the open upstream PRs we
  are carrying (#221, #239).

## Exit criteria

Recommend a migration only when: the API reaches `v1beta1`, gaps 3, 4 and 7 are
resolved, and the target clusters are on a Kubernetes version that supports the
chosen code-delivery path.
