# Velociraptor Helm

Helm chart for [Velociraptor](https://github.com/Velocidex/velociraptor) (DFIR server).

## Architecture

- **StatefulSet master, 1 replica**: the master owns the metadata datastore (single-writer). To scale the number of clients → **multi-frontend (master/minion)**, not `replicaCount` (see below).
- **Frontend** (port 8000, gRPC/mTLS): endpoint client communications. Often exposed externally (`LoadBalancer`). The only external surface.
- **GUI** (port 8889): admin interface. Keep internal / VPN / authenticated Ingress.
- **Config**: generated out-of-band (embeds the CA + private keys), mounted read-only from a Secret. Never in cleartext in the values in production.
- **Datastore**: `ReadWriteOnce` PVC mounted at `/datastore` (or an external `ReadWriteMany` PVC via `persistence.existingClaim` for NFS/EFS / multi-frontend).

## Prerequisites

- A Kubernetes cluster, Helm **3+**.
- A **server config** (`server.config.yaml`, embeds the CA + private keys) generated out-of-band — the chart does not template it. Provide it either via `config.existingSecret` (a Secret you manage), or via `config.inline` when you have **no secret manager** (the chart renders the Secret for you). See [velociraptor-docker](https://github.com/MaximeWewer/velociraptor-docker).
- Optional, only if you enable the matching feature:
  - A `ReadWriteMany` StorageClass (NFS/EFS) — for `frontend.minions` (shared master+minions datastore).
  - **Prometheus Operator** CRDs — for `serviceMonitor.enabled`.

## Install

```sh
# 1. Generate the server config (CA + keys) out-of-cluster, store it in a Secret
velociraptor config generate > server.config.yaml   # edit ports/URLs (see velociraptor-docker README)
kubectl create secret generic velo-config \
  --from-file=server.config.yaml=./server.config.yaml -n dfir

# 2. Install
helm install velo . -n dfir \
  --set config.existingSecret=velo-config
```

### No secret manager (inline)

No ESO/Vault/SealedSecrets? Let the chart render the config Secret from `config.inline`.
Keep the config (CA + private keys) **out of git** — put it in a gitignored overrides
file, or feed the file directly:

```sh
velociraptor config generate > server.config.yaml   # gitignore this file

# Option A — gitignored overrides file (config.inline: | <yaml>)
helm install velo . -n dfir -f secrets.yaml

# Option B — feed the file straight into config.inline
helm install velo . -n dfir --set-file config.inline=server.config.yaml
```

The same applies to the OIDC client secret: set `gui.oidc.clientSecret` (gitignored
overrides) instead of `gui.oidc.existingSecret`.

## Server config checklist (production)

The config (Secret) carries the advanced cases; the chart does not template into it. Things to set in `server.config.yaml` as needed:

- **TLS / Let's Encrypt**: `GUI.use_plain_http: false` + `Frontend.use_plain_http: false`; autocert via `autocert_domain` + `autocert_cert_cache` (frontend + GUI on :443). Otherwise a self-signed CA (default) or an external cert: `Frontend.tls_certificate_filename` / `tls_private_key_filename`. To terminate TLS at the k8s level: GUI Ingress + cert-manager, and the **frontend as TCP passthrough** (mTLS, no L7 termination).
- **GUI auth**: `GUI.authenticator.type: Basic` (create a user: `velociraptor --config … user add <u> <pwd> --role administrator`) or **OIDC** — see the dedicated section below.
- **public_url / base_path**: `GUI.public_url` must match the served host (OAuth redirects); `GUI.base_path` if served on a sub-path behind a reverse-proxy.
- **server_urls**: `Client.server_urls` = the public URL(s) of the frontend(s) as seen by the endpoints.
- **Metrics**: `Monitoring.bind_address: 0.0.0.0` (default `127.0.0.1`, not scrapable) for `serviceMonitor.enabled=true`.

## Multi-frontend (master/minion)

Horizontal client scaling: `frontend.minions.enabled=true` adds a `…-minion-N` StatefulSet (RemoteFileDataStore) that RPCs to the master's API. Prerequisites:

- `persistence.existingClaim` = a **ReadWriteMany** PVC (NFS/EFS) shared by master+minions (the chart fails the render otherwise).
- Config Secret: `Datastore.master_implementation: MemcacheFileDataStore`, `Datastore.minion_implementation: RemoteFileDataStore`, `API.bind_address: 0.0.0.0`, `API.hostname: <release>-api.<ns>.svc`, **`API.pinned_gw_name: GRPC_GW`**, and `ExtraFrontends` (one per minion, `hostname: <release>-minion-0..N`, `bind_port: 8000`). The chart starts each minion with `--node <hostname>-<bind_port>` (dash).
- Velociraptor 0.76.6: upstream nil panic in the minion (`datastore/remote.go` `ListChildren`, cf. Velocidex/velociraptor#4816). Topology validated (the minion connects and the ReplicationService binds to the master), but minion bring-up may crash until upstream is fixed. Single-frontend is not affected.

## OIDC auth (Keycloak, Google, Azure…)

`gui.oidc.enabled=true` injects `GUI.public_url` + `GUI.authenticator` (type `oidc`) into the config **without the chart owning the base config**: a (pinned) `yq` init-container deep-merges a chart-rendered overlay onto the base config (Secret), with the `oauth_client_secret` injected from a Secret. The merged config is written to an emptyDir read by the main container.

```sh
# client_secret preferably in a Secret (not in the values)
kubectl create secret generic velo-oidc --from-literal=oauth_client_secret='<secret>' -n dfir

helm upgrade velo . -n dfir \
  --set config.existingSecret=velo-config \
  --set gui.oidc.enabled=true \
  --set gui.publicUrl=https://velociraptor.example.com/app/index.html \
  --set gui.oidc.issuer=https://keycloak.example.com/realms/dfir \
  --set gui.oidc.name=keycloak \
  --set gui.oidc.clientId=velociraptor \
  --set gui.oidc.existingSecret=velo-oidc
```

## Main values

| Key | Default | Description |
|-----|---------|-------------|
| `image.registry` / `image.repository` | `ghcr.io` / `maximewewer/velociraptor` | Hardened distroless rebuild ([velociraptor-docker](https://github.com/MaximeWewer/velociraptor-docker)) |
| `image.tag` | `0.77.1-distroless` | Tag; prefer `image.digest` in production |
| `replicaCount` | `1` | **master** pods — **must stay 1** (single-writer datastore); scale via `frontend.minions` |
| `config.existingSecret` | `""` | Secret containing `server.config.yaml` (preferred with a secret manager) |
| `config.inline` | `""` | Inline config rendered into a chart-managed Secret — use without a secret manager; keep out of git |
| `config.initializeServer` | `false` | Build downloadable client installers (MSI/DEB/RPM) on first boot (`Container.InitializeServer`) |
| `customArtifacts.enabled` | `false` | Mount custom VQL artifacts (ConfigMap) at `customArtifacts.path` and load them |
| `customArtifacts.files` / `customArtifacts.existingConfigMap` | `{}` / `""` | Inline artifacts (filename → YAML) or an existing ConfigMap |
| `frontend.minions.enabled` | `false` | Multi-frontend (master/minion); requires a RWX `persistence.existingClaim` |
| `frontend.minions.replicas` | `2` | Number of minions |
| `frontend.apiPort` | `8001` | master gRPC API port (minion RPC) |
| `frontend.service.type` | `LoadBalancer` | Frontend exposure (endpoint clients) |
| `frontend.service.loadBalancerSourceRanges` | `[]` | Restrict the LB source IPs |
| `frontend.ingress.enabled` | `false` | SSL-passthrough Ingress for agent comms (L4 TLS by SNI; needs nginx `--enable-ssl-passthrough`) |
| `frontend.ingress.host` | `""` | Agent SNI host — must match `Client.server_urls` / `Frontend.hostname`; distinct from the GUI host |
| `gui.service.type` | `ClusterIP` | Internal GUI |
| `gui.ingress.enabled` | `false` | GUI Ingress (authenticated/VPN) |
| `gui.oidc.enabled` | `false` | OIDC auth (merge via yq init-container) |
| `gui.publicUrl` | `""` | `GUI.public_url` (must end with `/app/index.html`); required for OIDC |
| `gui.oidc.existingSecret` | `""` | Secret of the `oauth_client_secret` (otherwise `gui.oidc.clientSecret`) |
| `config.overlay.image` | `mikefarah/yq` | Merge init image (pinned by digest) |
| `persistence.size` | `20Gi` | Datastore size (chart-managed PVC) |
| `persistence.existingClaim` | `""` | External PVC (NFS/EFS RWX); required for multi-frontend |
| `persistence.storageClass` | `""` | PVC StorageClass |
| `networkPolicy.enabled` | `true` | NetworkPolicy |
| `networkPolicy.frontendAllowedCIDRs` | `[0.0.0.0/0]` | CIDRs allowed to the frontend — **restrict** |
| `networkPolicy.guiAllowedFrom` | `[]` | Peers allowed to the GUI |
| `podDisruptionBudget.enabled` | `false` | Off (1 replica → would block drains) |
| `serviceMonitor.enabled` | `false` | Prometheus scrape |
| `resources` | 250m/512Mi → 2/2Gi | Requests/limits |

## Notes

- `velociraptor config generate` must set `Client.server_urls` = the public frontend URL (as seen by the endpoints), otherwise clients cannot connect.
- `config.initializeServer` / `customArtifacts` inject into the config via the same yq overlay-merge init-container as OIDC (the base config in your Secret stays untouched). They are composable with `gui.oidc`.
- Version bump: bump `image.tag` + `Chart.yaml appVersion`, rebuild the image (pinned sha256) — see [velociraptor-docker](https://github.com/MaximeWewer/velociraptor-docker).

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| config.existingSecret | string | `""` |  |
| config.initializeServer | bool | `false` |  |
| config.inline | string | `""` |  |
| config.mountPath | string | `"/etc/velociraptor/server.config.yaml"` |  |
| config.overlay.image.digest | string | `"sha256:b1d117c609ba990436ad1649299e2f6c378f62cb562caf30b6f2fb6144713422"` |  |
| config.overlay.image.pullPolicy | string | `"IfNotPresent"` |  |
| config.overlay.image.repository | string | `"mikefarah/yq"` |  |
| config.overlay.image.tag | string | `"4.44.6"` |  |
| config.secretKey | string | `"server.config.yaml"` |  |
| customArtifacts.enabled | bool | `false` |  |
| customArtifacts.existingConfigMap | string | `""` |  |
| customArtifacts.files | object | `{}` |  |
| customArtifacts.path | string | `"/custom_artifacts"` |  |
| extraArgs | list | `[]` |  |
| extraEnv | list | `[]` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| frontend.apiPort | int | `8001` |  |
| frontend.containerPort | int | `8000` |  |
| frontend.ingress.annotations."nginx.ingress.kubernetes.io/backend-protocol" | string | `"HTTPS"` |  |
| frontend.ingress.annotations."nginx.ingress.kubernetes.io/ssl-passthrough" | string | `"true"` |  |
| frontend.ingress.className | string | `""` |  |
| frontend.ingress.enabled | bool | `false` |  |
| frontend.ingress.host | string | `""` |  |
| frontend.ingress.path | string | `"/"` |  |
| frontend.ingress.pathType | string | `"ImplementationSpecific"` |  |
| frontend.ingress.tls | list | `[]` |  |
| frontend.minions.affinity | object | `{}` |  |
| frontend.minions.enabled | bool | `false` |  |
| frontend.minions.nodeSelector | object | `{}` |  |
| frontend.minions.podAnnotations | object | `{}` |  |
| frontend.minions.replicas | int | `2` |  |
| frontend.minions.resources | object | `{}` |  |
| frontend.minions.tolerations | list | `[]` |  |
| frontend.service.annotations | object | `{}` |  |
| frontend.service.externalTrafficPolicy | string | `"Local"` |  |
| frontend.service.loadBalancerIP | string | `""` |  |
| frontend.service.loadBalancerSourceRanges | list | `[]` |  |
| frontend.service.port | int | `8000` |  |
| frontend.service.type | string | `"LoadBalancer"` |  |
| fullnameOverride | string | `""` |  |
| gui.containerPort | int | `8889` |  |
| gui.ingress.annotations | object | `{}` |  |
| gui.ingress.className | string | `""` |  |
| gui.ingress.enabled | bool | `false` |  |
| gui.ingress.hosts[0].host | string | `"velociraptor.example.com"` |  |
| gui.ingress.hosts[0].paths[0].path | string | `"/"` |  |
| gui.ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| gui.ingress.tls | list | `[]` |  |
| gui.oidc.avatar | string | `""` |  |
| gui.oidc.clientId | string | `"velociraptor"` |  |
| gui.oidc.clientSecret | string | `""` |  |
| gui.oidc.enabled | bool | `false` |  |
| gui.oidc.existingSecret | string | `""` |  |
| gui.oidc.existingSecretKey | string | `"oauth_client_secret"` |  |
| gui.oidc.issuer | string | `""` |  |
| gui.oidc.name | string | `"keycloak"` |  |
| gui.publicUrl | string | `""` |  |
| gui.service.annotations | object | `{}` |  |
| gui.service.port | int | `8889` |  |
| gui.service.type | string | `"ClusterIP"` |  |
| image.digest | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.registry | string | `"ghcr.io"` |  |
| image.repository | string | `"maximewewer/velociraptor"` |  |
| image.tag | string | `"0.77.1-distroless"` |  |
| imagePullSecrets | list | `[]` |  |
| livenessProbe.failureThreshold | int | `6` |  |
| livenessProbe.httpGet.path | string | `"/healthz"` |  |
| livenessProbe.httpGet.port | string | `"frontend"` |  |
| livenessProbe.httpGet.scheme | string | `"HTTPS"` |  |
| livenessProbe.initialDelaySeconds | int | `15` |  |
| livenessProbe.periodSeconds | int | `20` |  |
| livenessProbe.timeoutSeconds | int | `5` |  |
| monitoring.containerPort | int | `8003` |  |
| nameOverride | string | `""` |  |
| networkPolicy.enabled | bool | `true` |  |
| networkPolicy.extraEgress | list | `[]` |  |
| networkPolicy.frontendAllowedCIDRs[0] | string | `"0.0.0.0/0"` |  |
| networkPolicy.guiAllowedFrom | list | `[]` |  |
| networkPolicy.metricsAllowedFrom | list | `[]` |  |
| networkPolicy.oidcEgressCIDRs[0] | string | `"0.0.0.0/0"` |  |
| networkPolicy.oidcEgressPort | int | `443` |  |
| nodeSelector | object | `{}` |  |
| persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| persistence.annotations | object | `{}` |  |
| persistence.enabled | bool | `true` |  |
| persistence.existingClaim | string | `""` |  |
| persistence.mountPath | string | `"/datastore"` |  |
| persistence.size | string | `"20Gi"` |  |
| persistence.storageClass | string | `""` |  |
| podAnnotations | object | `{}` |  |
| podDisruptionBudget.enabled | bool | `false` |  |
| podDisruptionBudget.maxUnavailable | string | `""` |  |
| podDisruptionBudget.minAvailable | string | `""` |  |
| podLabels | object | `{}` |  |
| podSecurityContext.fsGroup | int | `65532` |  |
| podSecurityContext.fsGroupChangePolicy | string | `"OnRootMismatch"` |  |
| podSecurityContext.runAsGroup | int | `65532` |  |
| podSecurityContext.runAsNonRoot | bool | `true` |  |
| podSecurityContext.runAsUser | int | `65532` |  |
| podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| priorityClassName | string | `""` |  |
| readinessProbe.failureThreshold | int | `6` |  |
| readinessProbe.httpGet.path | string | `"/healthz"` |  |
| readinessProbe.httpGet.port | string | `"frontend"` |  |
| readinessProbe.httpGet.scheme | string | `"HTTPS"` |  |
| readinessProbe.initialDelaySeconds | int | `10` |  |
| readinessProbe.periodSeconds | int | `10` |  |
| readinessProbe.timeoutSeconds | int | `5` |  |
| replicaCount | int | `1` |  |
| resources.limits.cpu | string | `"2"` |  |
| resources.limits.memory | string | `"2Gi"` |  |
| resources.requests.cpu | string | `"250m"` |  |
| resources.requests.memory | string | `"512Mi"` |  |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.privileged | bool | `false` |  |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| securityContext.runAsGroup | int | `65532` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `65532` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automountServiceAccountToken | bool | `false` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| serviceMonitor.enabled | bool | `false` |  |
| serviceMonitor.interval | string | `"30s"` |  |
| serviceMonitor.labels | object | `{}` |  |
| serviceMonitor.namespace | string | `""` |  |
| serviceMonitor.path | string | `"/metrics"` |  |
| serviceMonitor.port | string | `"metrics"` |  |
| serviceMonitor.scheme | string | `"http"` |  |
| serviceMonitor.scrapeTimeout | string | `"10s"` |  |
| terminationGracePeriodSeconds | int | `60` |  |
| tmpDir.enabled | bool | `true` |  |
| tmpDir.sizeLimit | string | `"1Gi"` |  |
| tolerations | list | `[]` |  |
| topologySpreadConstraints | list | `[]` |  |
