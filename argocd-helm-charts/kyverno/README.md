# Kyverno chart

Wraps the upstream Kyverno chart and ships three KubeAid policies, all written as
`policies.kyverno.io/v1` CEL policies.

| Policy | Kind | Values key | Default |
| --- | --- | --- | --- |
| harbor-proxy-cache-mutate | MutatingPolicy | `harborProxyCache` | off |
| replace-container-image-registries | MutatingPolicy | `pullThroughCache`, `upstreamRegistries` | off |
| sync-secrets-\<item\> (one per item) | GeneratingPolicy | `syncSecrets` | off |
| resourcequota-generator, limitrange-generator | GeneratingPolicy | `resourceQuotaLimitRangeGenerator` | **on** |

## harbor-proxy-cache-mutate

Rewrites container and initContainer images that point at Docker Hub (explicit
`docker.io/`, `index.docker.io/`, `registry-1.docker.io/` and the implicit `org/name` and
`name` forms), and optionally `ghcr.io` and `registry.k8s.io`, to the proxy-cache projects
on your Harbor, and appends the matching imagePullSecret. Applies on CREATE to Pods,
Deployments, StatefulSets, DaemonSets, Jobs and CronJobs. Official images get `library/`
inserted so Harbor can resolve them. Images already on a proxy-cache project keep their
image, but still get the pull secret when it is missing: operators such as rook-ceph start
pods with their own image, which this policy already rewrote, and do not copy the secret.

```yaml
harborProxyCache:
  enabled: true
  registry: harbor.example.com          # required
  dockerHubProject: docker-hub-proxy-cache
  ghcrProject: ghcr-proxy-cache         # omit to leave ghcr.io images untouched
  k8sProject: registry-k8s-proxy-cache  # omit to leave registry.k8s.io images untouched
  imagePullSecretName: harbor-proxy-cache
  ghcrImagePullSecretName: harbor-ghcr-proxy-cache
  k8sImagePullSecretName: harbor-registry-k8s-proxy-cache
  excludeNamespaces: [harbor]
  mutateExistingOnPolicyUpdate: false   # keep off: imagePullSecrets cannot change on a running Pod
```

The pull secrets must exist in every namespace the policy touches; `syncSecrets` below is
one way to get them there.

## replace-container-image-registries

Rewrites container and initContainer images from the listed upstream registries to a
generic pull-through proxy cache (ECR, ACR, a Harbor project), keeping the full upstream
path: `docker.io/velero/velero:v1.16.1` becomes
`<proxyRegistry>/docker.io/velero/velero:v1.16.1`, `nginx:1.27` becomes
`<proxyRegistry>/docker.io/library/nginx:1.27`. Applies on CREATE and UPDATE to Pods,
Deployments, StatefulSets, DaemonSets, Jobs and CronJobs. Images already on the proxy, or
from a registry not in the list, are left alone. Tags and digests are kept exactly as
written; nothing is looked up in the registry. Use `harborProxyCache` instead when the
target is Harbor with one project per upstream and pull secrets to inject.

```yaml
pullThroughCache:
  enabled: true
  proxyRegistry: 123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-prefix   # required
  mutateExistingOnPolicyUpdate: false
  excludeNamespaces: []
upstreamRegistries:            # top level, as before; also accepted under pullThroughCache
  - docker.io
  - ghcr.io
```

The proxy must be configured to serve those upstream paths under its prefix (an ECR
pull-through cache rule, an ACR cache rule, a Harbor proxy project named after the
upstream host).

## sync-secrets

Copies a Secret from one namespace into every matching namespace and keeps the copies in
sync with the source. One GeneratingPolicy per item. `namespaceMatch` accepts `*` and `?`
wildcards. Existing namespaces are covered when the policy is created.

```yaml
syncSecrets:
  enabled: true
  items:
    - name: harbor-proxy-cache
      namespaceMatch: "*"               # default
      excludeNamespaces: [kyverno, argocd]
      sourceSecret: {namespace: harbor, name: harbor-proxy-cache}
      targetSecret: {name: harbor-proxy-cache}
```

Enabling this also creates an aggregated ClusterRole giving the Kyverno background
controller Secret permissions, which it needs to read the source and write the copies.

Behaviour verified on Kyverno 1.19.1:

- A deleted copy is recreated and an edited copy is reverted.
- Replacing or deleting the policy keeps the copies (`orphanDownstreamOnPolicyDelete`).
- **A change to the source Secret is not pushed to the copies automatically.** Kyverno
  1.19 re-reads the source only when a matching namespace is created or updated. After
  rotating the source, touch the namespaces:

  ```bash
  kubectl get ns -o name | xargs -I{} kubectl annotate {} kubeaid.io/sync-secrets="$(date +%s)" --overwrite
  ```

  Deleting the copies is not enough: they come back with the old data.

## resourcequota-generator and limitrange-generator

Generates a `default` ResourceQuota and a `default` LimitRange in every namespace, with
per-namespace overrides and exclusions. Override values win, defaults fill the rest. With
`defaultResourceQuotaRuleEnabled: false` only the override namespaces get a quota. This is
**enabled by default**; set `enabled: false` if a cluster should not get quotas.

```yaml
resourceQuotaLimitRangeGenerator:
  enabled: true
  generateExisting: true
  defaultResourceQuotaRuleEnabled: true
  excludeNamespaces:
    resourceQuota: []
    limitRange: []
  defaults: {...}                       # see values.yaml
  overrides:
    rook-ceph:
      limitRange:
        container: {}                   # falls back to the defaults
```

Deleting these policies deletes the generated quotas and limit ranges (synchronize is on,
and they are data-generated, not cloned). Copied Secrets are retained on policy deletion.

## Testing the mutating policies locally

`templates/harbor-proxy-cache/.kyverno-test/` and
`templates/replace-container-image-registries/.kyverno-test/` are Kyverno CLI (v1.19+) suites. The policy is
rendered from the chart with the suite's `values.yaml`, so what is tested is what Argo CD
would apply.

```bash
# from argocd-helm-charts/kyverno
d=templates/harbor-proxy-cache/.kyverno-test
helm template kyverno . -f $d/values.yaml --show-only templates/harbor-proxy-cache/harbor-proxy-cache-mutate.yaml > $d/policy.yaml
kyverno test $d
d=templates/replace-container-image-registries/.kyverno-test
helm template kyverno . -f $d/values.yaml --show-only templates/replace-container-image-registries/policy.yaml > $d/policy.yaml
kyverno test $d
```

The generate policies can be checked the same way with `kyverno apply ... -o out/`, using a
`--context-file` that carries the source Secret for `resource.Get`.

## Migrating a cluster from the legacy ClusterPolicy versions

Tested on a kind cluster with Kyverno 1.19.1: legacy policies applied, then deleted and
replaced by the new ones in one step, the way Argo CD syncs.

- Kyverno must be v1.19.0 or newer (chart 3.9.0 in this repository).
- `resourcequota-limitrange-generator`: the quotas and limit ranges are deleted together
  with the old policy and recreated by the new one within seconds. Pods admitted in that
  window get no LimitRange defaults. Plan the sync for a quiet window.
- `sync-secrets`: the copies made by the legacy clone rule are deleted with it and
  recreated by the new policy within seconds. Pods starting in that window cannot pull
  through Harbor. Same advice. From then on the copies survive policy replacement.
- Kyverno 1.19 refuses to create the legacy `sync-secrets` ClusterPolicy at all unless the
  admission controller can get and list Secrets, which this chart never granted. A cluster
  that has it running today got that permission from somewhere else.
- The harbor policy patches at admission only, as before. The values keys are unchanged.
- `replace-container-image-registries` was removed from the chart between 26.1.0 and
  32.2.0 and is back as a MutatingPolicy under the same values keys. Two differences from
  the legacy version: image tags are no longer resolved to digests at admission (that was a
  registry lookup on every pod create), and pod controllers are matched explicitly instead
  of through legacy autogen. Note that the keys must sit at the top level of the values
  file, not under `kyverno:`.
- Anything that limits which objects a policy touches (namespaces above all) is a
  `matchConstraints` selector, never a `matchConditions` expression: the mutate-existing
  back-fill selects its targets from `matchConstraints` alone and ignores conditions.
