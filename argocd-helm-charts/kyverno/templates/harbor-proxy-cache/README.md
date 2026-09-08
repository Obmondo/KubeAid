# Harbor Proxy-Cache Policy Notes

See the chart-level `README.md` for install/test instructions and `values.example.yaml`
(this folder) for every available key. This file covers what the policy does,
its internal structure, and known limitations worth knowing before relying on it.

## What this policy does

**The problem:** starting a pod means pulling its container image, usually from
Docker Hub. Docker Hub rate-limits pulls, and a busy cluster can hit that limit
fast, causing pods to fail to start.

**The fix:** route those pulls through Harbor (a private registry you run
yourself) instead. Harbor caches each image the first time and serves it
locally after that, so Docker Hub never sees repeat traffic.

**How:** this is a Kyverno *mutating* policy — it watches every pod as it's
created and silently rewrites the image reference before the pod starts, so
no one has to hand-edit every Deployment's YAML. You write a normal image
reference and never mention Harbor:

```yaml
containers:
  - name: nginx
    image: nginx:1.27.1
```

Kyverno intercepts it on the way in and rewrites it to:

```yaml
containers:
  - name: nginx
    image: harbor.example.com/docker-hub-proxy-cache/library/nginx:1.27.1
imagePullSecrets:
  - name: harbor-proxy-cache
```

### What gets rewritten today

| You write | Becomes | Always on? |
|---|---|---|
| `index.docker.io/library/nginx:1.27.1` | `harbor.example.com/docker-hub-proxy-cache/library/nginx:1.27.1` | Yes |
| `registry-1.docker.io/library/nginx:1.27.1` | same as above | Yes |
| `docker.io/library/nginx:1.27.1` | same as above | Yes |
| `graylog/graylog:6.3.1` (implicit org/repo) | `harbor.example.com/docker-hub-proxy-cache/graylog/graylog:6.3.1` | Yes |
| `nginx:1.27.1` (implicit official) | `harbor.example.com/docker-hub-proxy-cache/library/nginx:1.27.1` | Yes |
| `ghcr.io/obmondo/backup-exporter:v1.2.6` | `harbor.example.com/ghcr-proxy-cache/obmondo/backup-exporter:v1.2.6` | Only if `ghcrProject` is set |
| `registry.k8s.io/pause:3.9` | `harbor.example.com/k8s-proxy-cache/pause:3.9` | Only if `k8sProject` is set |
| `quay.io/prometheus/node-exporter:v1.7.0` | `harbor.example.com/quay-proxy-cache/prometheus/node-exporter:v1.7.0` | v2 only, if `quayProject` is set |

Applies to `Pod`, `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob` —
and it's smart enough to skip an image that's already routed through Harbor
(won't double-rewrite), and to leave already-running pods alone (only affects
new pods being created).

### What's NOT covered yet

- Any registry beyond the ones above and not listed in `extraRegistries`
  (see [v2](#v2-values-driven-registries-opt-in-not-yet-the-default) below) —
  untouched, pulled directly.
- Digest-pinned images (`image@sha256:...`) — unverified; not explicitly
  tested against this policy.

## Policy structure

`harbor-proxy-cache-mutate.yaml` looks huge (~1000 lines) but it's the same small
amount of logic repeated along three independent axes, multiplied together:

1. **Resource shape** (3 rules) — Kyverno's `foreach.list` needs an exact JSONPath
   to the container array, and that differs by kind: `Pod` uses
   `spec.containers[]`, `Deployment`/`StatefulSet`/`DaemonSet`/`Job` wrap it in
   `spec.template.spec.containers[]`, and `CronJob` wraps it one level deeper in
   `spec.jobTemplate.spec.template.spec.containers[]`.
2. **Registry pattern** (6 blocks per rule) — one block per way an image
   reference can look: `index.docker.io/`, `registry-1.docker.io/`,
   `docker.io/`, `ghcr.io/` (if `ghcrProject` is set), `registry.k8s.io/` (if
   `k8sProject` is set), implicit `org/repo` (e.g. `graylog/graylog:6.3.1`), and
   implicit official (e.g. `nginx:1.27.1`, rewritten under `library/`).
3. **containers vs initContainers** (×2) — `foreach.list` targets one array
   expression at a time, so every registry-pattern block above is duplicated
   for `initContainers[]`.

3 × 6 × 2 = 36 near-identical blocks. When changing shared behavior (e.g. the
`imagePullSecrets` fallback), grep for the pattern across **all** of them —
nothing in YAML enforces the copies stay in sync, and a partial edit is the
most likely source of a bug here.

## v2: values-driven registries (opt-in, not yet the default)

`harbor-proxy-cache-mutate-v2.yaml` collapses axis 2 above (the registry-pattern
blocks) into a loop over a `$registries` list built from
`harborProxyCache.registry`/`dockerHubProject`/`ghcrProject`/`k8sProject` and
the matching secret-name keys, using a `stripPrefixes` helper in
`_helpers.tpl` to build the chained `replace_all(...)` call per registry.
`quay.io` is a named entry the same way, via `quayProject`. Anything beyond
those four goes in `harborProxyCache.extraRegistries` — a list of
`{prefixes, project, secretName}`, no template change needed. Either way it's
one values entry instead of 6 hand-written blocks. It's gated behind its own
`harborProxyCache.v2Enabled`
(default `false`) rather than reusing `harborProxyCache.enabled`, so both
files can sit in the repo without v2 silently going live in a cluster
alongside v1.

**Why it's still ~600 lines and not ~150** — axes 1 and 3 are deliberately
left hand-written:

- **Axis 1 (3 resource shapes)** stays as-is because `patchStrategicMerge`
  needs a fully different nested YAML shape per kind (`spec.containers` vs
  `spec.template.spec.containers` vs
  `spec.jobTemplate.spec.template.spec.containers`), and generating that
  generically means conditional indentation in Go templates — assessed as too
  fragile to risk without a working `kyverno test` CLI available to verify
  against (correctness here was instead checked by rendering the chart and
  re-implementing Kyverno's precondition/patch evaluation in a throwaway
  Python script, comparing v1 and v2's output image/secret for a battery of
  test image strings across every registry shape).
- **Axis 3 (containers vs initContainers)** stays hand-written for the same
  reason — `foreach.list` targets exactly one array path per entry, so each
  resource shape still needs two near-identical call sites.
- **The 2 "implicit Docker Hub" fallback blocks per call site** (bare
  `org/repo`, bare official image) were deliberately kept out of the
  `$registries` loop — they match via `regex_match` instead of a prefix
  `contains`, and the official case additionally inserts a `library/`
  segment into the rewritten path. Folding them in would mean giving every
  registry entry an `isImplicit`/`insertLibrary` flag for behavior that only
  ever applies to Docker Hub — more template complexity to save two blocks.

Net effect: 36 hand-authored block-equivalents (v1) down to 18 (v2) — the 6
registry-pattern blocks per call site collapsed to 1 loop each, the 12
implicit blocks (2 per call site × 6 call sites) untouched.

## Known limitations

- **No fallback if Harbor is unreachable.** A Pod's `image:` field holds exactly
  one reference — once this policy rewrites it to the Harbor path, that's the
  only registry the kubelet knows about. If Harbor's proxy-cache is down,
  affected pulls fail with no path back to the original upstream registry.
  `failurePolicy: Ignore` only protects against the *Kyverno webhook* being
  unreachable (new pods admit unmutated in that case) — it does nothing once a
  pod has already been mutated and Harbor itself is the thing that's down.
  The structurally correct fix for true fallback is a containerd/CRI-O
  registry mirror (`/etc/containerd/certs.d/<registry>/hosts.toml`) configured
  at node bootstrap, which tries Harbor first and falls through to the real
  upstream automatically — pods keep their original image reference the whole
  time. KubeAid doesn't set this up yet; this Kyverno policy is the only
  mechanism today.

- **Given the above, Harbor's own availability matters a lot — run it HA.**
  `argocd-helm-charts/harbor` already has the support for this, it just needs
  enabling: `global.priorityClass.enabled` (a pre-defined `harbor-critical`
  PriorityClass, whose own comment calls out exactly this pull-through-cache
  use case) and `global.podDisruptionBudget.enabled` (entries for
  portal/core/jobservice/registry) both default to `false`. Turn both on, and
  bump each component's `replicas` to 2+ first — the PDB entries use
  `maxUnavailable: 1`, which blocks voluntary node drains entirely on a
  single replica. Add `topologySpreadConstraints` per component and a
  blackbox probe on top for full coverage.
