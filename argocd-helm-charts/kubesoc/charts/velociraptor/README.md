# velociraptor

Velociraptor (Velocidex/Rapid7, AGPL-3.0) endpoint visibility and DFIR server, wrapped from
[MaximeWewer/velociraptor-helm](https://github.com/MaximeWewer/velociraptor-helm).

## 1. How to setup

The chart never generates the server config. Do that out of band, once, with the final
frontend hostname, because every client pins the server certificate that lives in it:

```bash
velociraptor config generate -i     # answer: self-signed, frontend host, GUI host
```

Store the result as a sealed Secret named `velociraptor-server-config` with the key
`server.config.yaml` in the release namespace. Minimal values:

```yaml
velociraptor:
  gui:
    ingress:
      enabled: true
      hosts:
        - host: velociraptor.example.com
  frontend:
    service:
      type: LoadBalancer   # clients need raw TLS to port 8000
```

## 2. Single replica

Velociraptor has no HA. `frontend.minions` only spreads client load and needs a
ReadWriteMany datastore, so keep `replicaCount: 1` unless you have RWX storage.

## 3. SSO

`gui.oidc` overlays an OIDC block into the config through an init container. Point it at a
Keycloak client with `clientId: velociraptor` and the client secret in `gui.oidc.existingSecret`.

## 4. Image

The upstream chart ships the author's hardened, rootless rebuild of Velociraptor
(`ghcr.io/maximewewer/velociraptor`), which stays the default until KubeAid publishes its
own.

`build/kubesoc/velociraptor` in this repository builds that own image: the official
Velocidex release binary for the version pinned in `versions.env`, checked against a pinned
SHA-256 *and* the Velocidex release signature (the vendored public key
`velocidex-release-key.asc`, fingerprint `0572 F28B 4EF1 9A04 3F4C BBE0 B22A 7FB1 9CB6 CFA1`),
copied onto `gcr.io/distroless/base-debian12:nonroot` and run as 65532:65532 with the same
entrypoint and arguments. Build it with `./build.sh` (it never pushes) and switch over:

```yaml
velociraptor:
  image:
    registry: ghcr.io
    repository: obmondo/kubesoc-velociraptor
    tag: "0.77.1"           # or pin digest: sha256:...
```

The chart's `securityContext` (non-root 65532, read-only root filesystem, no capabilities)
applies to both images unchanged.

## 5. API clients (siem-reconciler)

The gRPC API listens on `127.0.0.1:8001` unless the server config says otherwise. To let an
in-cluster client such as the `siem-reconciler` (security-operations chart) reach it:

```yaml
velociraptor:
  config:
    overlayExtra:
      API:
        bind_address: 0.0.0.0
  api:
    service:
      enabled: true          # Service <fullname>-api on frontend.apiPort (8001)
  networkPolicy:
    apiAllowedFrom:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: siem-reconciler
  apiClient:
    enabled: true
    publisherImage:          # the siem-reconciler image
      repository: ghcr.io/obmondo/siem-reconciler
      tag: vX.Y.Z
apiServerEgress:
  enabled: true              # Cilium: the publisher reaches the Kubernetes API (only with apiClient)
```

With `apiClient.enabled` three init containers run before the server: `api-client` runs
`velociraptor config api_client --name <apiClient.name> --role <apiClient.role>` against the
merged config and the datastore (that registers the API user), `api-client-acl` runs
`velociraptor acl grant <apiClient.name> <apiClient.policy>` (skipped when `policy` is
empty), and `api-client-publish` (`siem-reconciler publish-api-client`) writes the file into
Secret `apiClient.secretName` (key `apiClient.secretKey`). Only the publisher mounts a
ServiceAccount token (projected volume); the server container keeps none. Grant the
ServiceAccount `get`, `update` and `patch` on that Secret and `create` on Secrets; this
chart does not (the security-operations chart does). The api_client file names
`localhost:8001`, so clients must dial `<fullname>-api:8001` themselves (the reconciler's
`address`); the server certificate is checked against the pinned name `VelociraptorServer`,
not the host name.

### Least privilege

`acl grant` **replaces** the permissions the role gave the user, so `apiClient.policy` is
the whole permission set the reconciler runs with. The default is the six permissions it
actually needs (`any_query`, `read_results`, `org_admin`, `collect_server`,
`server_artifact_writer`, `artifact_writer`) instead of `administrator`, which also carries
`execve`, `filesystem_read`, `filesystem_write`, `network`, `impersonation`,
`delete_results`, `server_admin`, `machine_state`, `collect_client`, `start_hunt` and
`impersonation`. Each permission was checked on a local 0.77.1 server by dropping it from
the set and re-running the reconciler's queries:

| dropped | what breaks |
|---|---|
| `any_query` | every query: `PermissionDenied ... requires permission ANY_QUERY` |
| `read_results` | `get_server_monitoring()` returns null (drift detection blind) |
| `org_admin` | `orgs()` shows only the root org, `org_create()` and `_client_config` return null |
| `collect_server` | `add_server_monitoring()` returns null |
| `server_artifact_writer` | `artifact_set()` refuses SERVER/SERVER_EVENT artifacts |
| `artifact_writer` | `artifact_set()` refuses CLIENT artifacts |

Only the last two are needed by the content package (`artifact_set`); drop them from
`policy` on a server whose artifacts come from the ConfigMap only. To go back to the old
behaviour, set `apiClient.policy: null` (Helm merges maps, so `{}` keeps the defaults) and
`apiClient.role: administrator`; the `api-client-acl` init container then disappears.

## Local patches to the vendored subchart

`charts/velociraptor` is upstream 0.77.1-24-06-2026 with these KubeAid changes (marked
"KubeAid patch" in the templates where they are not obvious). All of them live in
`patches/0001-kubeaid-local-changes.patch`, made against the upstream chart, so they
survive an update (see "Updating the subchart" below):

- `checksum/custom-artifacts` and `checksum/config-overlay` pod annotations in
  `templates/statefulset.yaml`, so a changed artifact or overlay rolls the pod.
- `gui.oidc.claims`, `gui.oidc.debug` and `gui.oidc.sessionExpiryMin` in
  `templates/secret-config-overlay.yaml`; `hostAliases` on both StatefulSets; the OIDC
  `ipBlock` egress rule in `templates/networkpolicy.yaml` is skipped when `oidcEgressCIDRs` is
  empty. Values and schema entries for each.
- `config.overlayExtra` (section 5): the overlay body moved into the
  `velociraptor.overlayGenerated` helper in `templates/_helpers.tpl`, and
  `templates/secret-config-overlay.yaml` merges `overlayExtra` over it when set (the
  rendered overlay is unchanged otherwise); `velociraptor.overlayEnabled` also turns on for
  it.
- `api.service.enabled` (section 5): the `velociraptor.apiExposed` helper; the `api`
  container port in `templates/statefulset.yaml` and `templates/service-api.yaml` use it
  instead of `frontend.minions.enabled` alone.
- `networkPolicy.apiAllowedFrom` (section 5): an ingress rule for `frontend.apiPort` in
  `templates/networkpolicy.yaml`.
- `apiClient.policy` (section 5): the `api-client-acl` init container in the
  `velociraptor.apiClientInitContainers` helper, and the least-privilege default policy
  with `role: api` instead of `role: administrator`.
- `apiClient` (section 5): the `velociraptor.apiClientInitContainers` and
  `velociraptor.apiClientVolumes` helpers in `templates/_helpers.tpl`, appended to the init
  containers and volumes in `templates/statefulset.yaml`, and `apiClient.imagePullSecrets`
  appended to the pod's `imagePullSecrets`.
- Values and `values.schema.json` entries for the four above. Nothing renders differently
  while they keep their defaults.

### Updating the subchart

`.helm-update-skip` keeps this chart out of the weekly `bin/manage-helm-chart.sh --update-all`
run, and the script cannot look up the latest version of an OCI chart anyway. Pick the new
tag from <https://github.com/MaximeWewer/velociraptor-helm/pkgs/container/charts%2Fvelociraptor>
and upgrade by hand, on Linux (the script refuses other systems):

1. Run `bin/manage-helm-chart.sh --update-helm-chart velociraptor --chart-version <new>`. It
   pulls the chart, applies `patches/*.patch` in lexical order (no fuzz) in a scratch
   directory, and replaces `charts/velociraptor` only once every patch applied; then it
   commits on a new `Helm_Update_*` branch. If a patch no longer applies it exits non-zero
   naming the patch, and leaves `charts/velociraptor` and `Chart.yaml` as they were.
2. On such a failure, refresh the patch against the new upstream and run step 1 again:

   ```bash
   repo=$PWD; tmp=$(mktemp -d); cd "$tmp"
   helm pull oci://ghcr.io/maximewewer/charts/velociraptor --version <new> --untar
   mv velociraptor a && cp -R a b
   patch -d b -p1 --fuzz=3 < "$repo/argocd-helm-charts/kubesoc/velociraptor/patches/0001-kubeaid-local-changes.patch"
   # fix every *.rej by hand in b/, then delete the *.rej and *.orig files
   git diff --no-index --src-prefix= --dst-prefix= a b \
     > "$repo/argocd-helm-charts/kubesoc/velociraptor/patches/0001-kubeaid-local-changes.patch"
   ```

3. Check the result: `bin/manage-helm-chart.sh --verify-patches velociraptor` pulls the
   version pinned in `Chart.yaml`, applies the patches and diffs against
   `charts/velociraptor`; it exits non-zero on any difference.

A new KubeAid change to `charts/velociraptor` goes into the patch the same way: pull the
pinned version into `a`, copy `charts/velociraptor` to `b`, regenerate the patch with the
`git diff` line above and run `--verify-patches`. Keep the list above in step with the patch.
