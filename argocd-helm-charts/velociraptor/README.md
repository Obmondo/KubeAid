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
(`ghcr.io/maximewewer/velociraptor`). For production, build your own image from the official
binary and override `image.registry` / `image.repository`.

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

With `apiClient.enabled` two init containers run before the server: `api-client` runs
`velociraptor config api_client --name <apiClient.name> --role <apiClient.role>` against the
merged config and the datastore (that registers the API user), and `api-client-publish`
(`siem-reconciler publish-api-client`) writes the file into Secret `apiClient.secretName`
(key `apiClient.secretKey`). Only the publisher mounts a ServiceAccount token (projected
volume); the server container keeps none. Grant the ServiceAccount `get`, `update` and
`patch` on that Secret and `create` on Secrets; this chart does not (the security-operations
chart does). The api_client file names `localhost:8001`, so clients must dial
`<fullname>-api:8001` themselves (the reconciler's `address`); the server certificate is
checked against the pinned name `VelociraptorServer`, not the host name.

## Local patches to the vendored subchart

`charts/velociraptor` is upstream 0.77.1-24-06-2026 with these KubeAid changes (marked
"KubeAid patch" in the templates where they are not obvious). Re-apply them when updating the
subchart:

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
- `apiClient` (section 5): the `velociraptor.apiClientInitContainers` and
  `velociraptor.apiClientVolumes` helpers in `templates/_helpers.tpl`, appended to the init
  containers and volumes in `templates/statefulset.yaml`, and `apiClient.imagePullSecrets`
  appended to the pod's `imagePullSecrets`.
- Values and `values.schema.json` entries for the four above. Nothing renders differently
  while they keep their defaults.
