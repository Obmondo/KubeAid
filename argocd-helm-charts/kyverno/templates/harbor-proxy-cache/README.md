# Harbor Proxy-Cache Policy Notes

See the chart-level `README.md` for install/test instructions and `values.example.yaml`
(this folder) for every available key. This file covers the policy's internal
structure and a known limitation worth knowing before relying on it.

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
Adding a registry (e.g. `quay.io`) becomes one list entry instead of 6
hand-written blocks. It's gated behind its own `harborProxyCache.v2Enabled`
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
