# Harbor: Acting as Air-Gapped Ops

Routing every image pull through Harbor's proxy-cache (see
[Host your own central registry with KubeAid](harbor-registry.md), and the [kyverno chart's
harbor-proxy-cache docs](../../argocd-helm-charts/kyverno/templates/harbor-proxy-cache/README.md)) gives the whole
cluster one fast, controlled path for every image instead of depending on the public internet and Docker Hub's
rate limits pod by pod. Since every workload's image pull now runs through that one path, we made sure that path
holds up on its own — here's how.

## 1. Harden the Harbor instance itself

The chart already supports the pieces needed for HA — they're opt-in because a fresh, single-replica install
shouldn't pay their cost by default:

- `global.priorityClass.enabled` — a `harbor-critical` PriorityClass (value `900000`) so Harbor's pods aren't the
  ones evicted under node pressure. Referenced per component via `harbor.<component>.priorityClassName`.
- `global.podDisruptionBudget.enabled` — one PDB per component (`portal`, `core`, `jobservice`, `registry`,
  `maxUnavailable: 1`). Only turn this on once that component's `harbor.<component>.replicas` is `>= 2` — at
  replica 1, `maxUnavailable: 1` blocks voluntary node drains entirely.
- `harbor.<component>.replicas` and `harbor.<component>.topologySpreadConstraints` — bump replicas per component
  and spread them across nodes, so a single node loss doesn't take the whole component down.

This buys availability within one cluster, not against the cluster itself being unreachable — that's what the
next section is for.

## 2. Fail over to a second Harbor entirely

For the case Harbor becomes unrecoverable in place — not just a pod restart, but the instance itself — we run a
second Harbor as a live replica on another cluster, and make switching to it a single value change rather than a
namespace-by-namespace secret scramble:

- **One pull secret, both hosts.** A `.dockerconfigjson` supports multiple registries in its `auths` map, so each
  namespace's `harbor-proxy-cache` secret carries credentials for *both* the primary and the replica Harbor from
  day one — sealed once, never touched during an actual incident.
- **The registry host is the only switch.** The `harbor-proxy-cache` Kyverno policy reads its target host from
  `harborProxyCache.registry` (see the [kyverno chart values](../../argocd-helm-charts/kyverno/values.yaml)).
  Failover is: point that value at the replica's hostname and sync. Every image reference the policy mutates from
  then on resolves to the replica; nothing else in the cluster changes.

The mutation happens once, at admission time, on `CREATE` — so it takes effect the moment a pod is (re)created
after the switch, no further action needed. A pod already running when the switch happens keeps working off its
already-pulled, locally cached image, which is the common case during an outage. But any pod that restarts after
the switch — a crash, an eviction, a rollout, a scale-up — is a fresh `CREATE` and picks up the new host
automatically, so most of the fleet self-heals onto the replica without anyone touching it. Only pods that stay
up the whole time and never restart need `mutateExistingOnPolicyUpdate` to be moved over too, which requires each
rule to declare `mutate.targets` — the policy doesn't have that yet.

## Result

Harbor's own HA settings absorb node- and pod-level failures without anyone doing anything. A full instance loss
is a one-value failover to a Harbor replica that every namespace was already provisioned to trust.

## Why not Kyverno's own sample policy?

Kyverno's policy library ships [Replace Image Registry With
Harbor](https://kyverno.io/policies/other/replace-image-registry-with-harbor/replace-image-registry-with-harbor/),
built for this exact use case using Kyverno's native `imageRegistry` context (`imageData.registry` /
`.repository` / `.identifier`) instead of hand-rolled string matching. It's a sample, not something to run as-is:

- Matches only the explicit `index.docker.io` form — misses the implicit short form (`nginx:1.27.1`), which
  normalizes to plain `docker.io` and wouldn't match.
- No coverage for `ghcr.io`, `quay.io`, or `registry.k8s.io`.
- One hardcoded target registry/project, no per-registry mapping.
- **Doesn't attach `imagePullSecrets`.** Harbor's proxy-cache projects are private, so a pull needs a credential
  for whichever project it lands in. The sample only patches `image:` — it rewrites `nginx:1.27.1` to
  `harbor.example.com/k8s/library/nginx:1.27.1` and stops there, leaving the pod pointed at the right URL with no
  way to authenticate against it. That fails as `unauthorized`, not as a bad rewrite. Our policy patches
  `imagePullSecrets` in the same `patchStrategicMerge` as the image, and — since each upstream registry proxies
  through its own Harbor project — picks the secret that matches *which registry pattern matched*: Docker Hub
  traffic gets `harborProxyCache.imagePullSecretName`, `registry.k8s.io` traffic gets
  `harborProxyCache.k8sImagePullSecretName`, and so on. One secret name for every rewrite would be wrong as soon
  as more than one upstream registry is in play.
- `imageRegistry` context needs to reach the source registry to resolve `imageData`, so admission depends on that
  registry being reachable — our `replace_all`-based matching never makes a network call.
