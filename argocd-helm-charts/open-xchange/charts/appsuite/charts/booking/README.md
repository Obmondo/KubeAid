# Booking

Booking adds self-service scheduling to OX App Suite: Doodle-style **Appointment Polls** and
Calendly-style **Appointment Booking**, plus an optional agent surface onto the latter's public
flow. Owners work from a plugin in the App Suite side panel; invitees and bookers need no
account, because the public link is the capability. Agreed times become real App Suite Calendar
appointments and reach everyone as calendar invitations by mail.

## Introduction

The chart includes the following components:

* Deployment and Service of `booking`, serving the API on port `8080` and health and metrics
  on `9090`
* ConfigMap carrying the hot-reloaded `config.yaml` (domain settings)
* Job applying pending database migrations, run as a plain managed Job rather than a Helm hook
* Optional chart-owned Secrets for the database and free/busy credentials and an extra CA
  bundle, and a ConfigMap for mail template overrides
* Optional HorizontalPodAutoscaler and PodDisruptionBudget

The `ui-plugin` frontend is served by the service itself at `/booking/plugin/`; `ui-service`
discovers it through the Service label and annotation set by `uiProvider`. No separate static
hosting container is needed.

Requirements:

* **Kubernetes** with **Helm 3**
* **MariaDB** (or MySQL-compatible) - either an existing `bookingdb` or a fresh instance; the
  initial migration creates the schema idempotently either way
* **App Suite middleware** reachable at `appSuiteApi` - the service calls `/user/me`,
  `/capabilities`, `/folders` and `/chronos` against it
* **An SMTP relay** for Appointment Booking (`mail.host`/`mail.from` in `bookingConfig`) -
  confirmations, manage links and the iMIP calendar invitations all go over mail, and booking
  requests are refused with a 503 while it is unconfigured. Appointment Polls work without it.

All configuration values can be listed with `helm show values path/to/chart/booking`.

## Install

```sh
helm install booking oci://registry.open-xchange.com/appsuite-core-internal/charts/booking \
  --version <chart version> \
  -f booking-values.yaml \
  -n production --create-namespace
```

Verify:

```sh
kubectl -n production get pods -l app.kubernetes.io/name=booking
kubectl -n production logs -l app.kubernetes.io/name=booking --tail=50
```

Minimal production values:

```yaml
image:
  tag: "<release tag>"

# credentials for the image registry (registry.open-xchange.com by default)
imagePullSecrets:
  - name: <registry-pull-secret>

database:
  host: mariadb.production.svc.cluster.local
  name: bookingdb
  user: booking
  existingSecret: booking-db
  existingSecretKey: password

appSuiteApi: http://core-mw-http-api/api

env:
  LOG_LEVEL: info
  ORIGINS: "https://appsuite.example.com"

bookingConfig:
  pollBaseURL: https://appsuite.example.com/booking/poll
  bookingBaseURL: https://appsuite.example.com/booking/book
  mail:
    host: postfix.example.com
    from: "Bookings <bookings@example.com>"
```

## Configuration

The service is configured two ways, and the chart sets both: environment variables for service
wiring, read once at startup (`env`), and a hot-reloaded `config.yaml` for domain settings,
watched and re-applied without a restart (`bookingConfig`). Anything omitted from `config.yaml`
falls back to its default, so a removed key resets rather than breaks.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `replicaCount` | Number of application pods; ignored while `hpa.create` | `2` |
| `hpa.create` | Render a HorizontalPodAutoscaler and leave `replicas` out of the Deployment | `false` |
| `hpa.minReplicas` / `maxReplicas` | HPA bounds | `1` / `3` |
| `hpa.targetCPUUtilizationPercentage` | CPU target, against `resources.requests.cpu`; empty omits it | `80` |
| `hpa.targetMemoryUtilizationPercentage` | Memory target, against `resources.requests.memory`; empty omits it | `""` |
| `hpa.metrics` | Additional `spec.metrics` entries, verbatim | `[]` |
| `hpa.behavior` | `spec.behavior` scaling policies, verbatim; empty omits it | `{}` |
| `strategy` | Deployment rollout strategy | `RollingUpdate`, `maxUnavailable: 0`, `maxSurge: 1` |
| `pdb.create` | Render a PodDisruptionBudget | `false` |
| `pdb.minAvailable` | Number or percentage; wins over `maxUnavailable` when set | `""` |
| `pdb.maxUnavailable` | Number or percentage | `1` |
| `pdb.unhealthyPodEvictionPolicy` | e.g. `AlwaysAllow`; empty omits it | `""` |
| `defaultRegistry` | Registry prepended to `image.repository` | `registry.open-xchange.com` |
| `image.registry` | Overrides `defaultRegistry` for this image | `""` |
| `image.repository` | The image to be used for the deployment | `appsuite-core-internal/booking` |
| `image.tag` | The image tag; `""` defaults to the chart's `appVersion` | `""` |
| `image.pullPolicy` | The `imagePullPolicy` for the container | `IfNotPresent` |
| `imagePullSecrets` | Pull secrets, merged with `global.imagePullSecrets` | `[]` |
| `podAnnotations` | Extra pod annotations | log-format annotation |
| `podSecurityContext` | Explicit pod security context; wins over the default block | `{}` |
| `securityContext` | Explicit container security context; wins over the default block | `{}` |
| `global.commitSha` | Deployed commit; a change forces a pod rollout when the image tag is stable | `""` |
| `global.useDefaultSecurityContext` | Apply the hardened `default*SecurityContext` blocks | `true` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `uiProvider.enabled` | Advertise the UI plugin for `ui-service` discovery | `true` |
| `uiProvider.basePath` | Path the plugin is served under | `/booking/plugin` |
| `appSuiteApi` | Base URL of the App Suite middleware HTTP API | `http://core-mw-http-api/api` |
| `database.host` | The database host | `mariadb` |
| `database.port` | The database port | `3306` |
| `database.name` | The database name | `bookingdb` |
| `database.user` | The database user | `booking` |
| `database.password` | Inline password, rendered into a chart-owned Secret; takes precedence over `existingSecret` | `""` |
| `database.existingSecret` | Secret holding the password, used while `database.password` is empty | `booking-db` |
| `database.existingSecretKey` | Key inside that Secret | `password` |
| `freeBusy.user` | Basic-auth login for the free/busy REST API, inline | `""` |
| `freeBusy.password` | Basic-auth password for the same endpoint, inline | `""` |
| `freeBusy.existingSecret` | Secret holding both halves instead | `""` |
| `freeBusy.existingSecretUserKey` | Key holding the login | `login` |
| `freeBusy.existingSecretPasswordKey` | Key holding the password | `password` |
| `extraCaCerts.certificates` | Inline PEM bundle of extra CA certificates to trust for outbound TLS, rendered into a chart-owned Secret | `""` |
| `extraCaCerts.existingSecret` | Secret holding the bundle instead; takes precedence over `certificates` | `""` |
| `extraCaCerts.key` | Key of the bundle inside the Secret | `ca.crt` |
| `migration.enabled` | Deploy the database migration Job | `true` |
| `migration.rotate` | Suffix the Job name so every upgrade creates a fresh Job; set `false` for ArgoCD-managed deployments | `true` |
| `migration.jobId` | Explicit rotation token overriding the release-revision fallback | `""` |
| `migration.ttlSecondsAfterFinished` | Cleanup for rotated Jobs; not applied to a stable-named Job | `60` |
| `migration.resources` | Resource requests and limits for the Job | requests `100m`/`128Mi`, limit `256Mi` |
| `env.LOG_LEVEL` | `trace` \| `debug` \| `info` \| `warn` \| `error` \| `fatal` | `info` |
| `env.ORIGINS` | Comma-separated CORS origins | `*` |
| `env.RATE_LIMIT_PUBLIC_MAX` | Per-IP, per-minute limit on public endpoints | `60` |
| `mailTemplates.files` | Inline Liquid template overrides, rendered into a chart-owned ConfigMap | `{}` |
| `mailTemplates.existingConfigMap` | ConfigMap of overrides managed elsewhere, keys being the file names | `""` |
| `bookingConfig` | Contents of the hot-reloaded `config.yaml` (see below) | `{}` |
| `resources` | Resource requests and limits for the application | requests `100m`/`128Mi`, limit `512Mi` |
| `livenessProbe` / `readinessProbe` | Probes; default to `/live` and `/ready` on port `9090` | see `values.yaml` |
| `nodeSelector`, `tolerations`, `affinity` | Standard scheduling controls | `{}` / `[]` / `{}` |

### Domain settings (`bookingConfig`)

Rendered into `config.yaml` and re-read without a restart. The keys deployments usually set:

```yaml
bookingConfig:
  # base URLs for the links owners share and the per-booking manage links; unset,
  # they are derived from a request host listed in linkOrigins, and without either
  # booking mails carry no manage link
  pollBaseURL: https://appsuite.example.com/booking/poll
  bookingBaseURL: https://appsuite.example.com/booking/book
  # linkOrigins:
  #   - https://appsuite.example.com

  # outbound mail, required for Appointment Booking
  mail:
    host: postfix.example.com
    port: 587
    from: "Bookings <bookings@example.com>"
    authMethod: plain              # none | plain | xoauth2 | oauthbearer
    user: bookings@example.com

  # calendar conflict checking: the middleware's REST base address, without the
  # endpoint path (App Suite 8.52+); credentials come from the freeBusy Secret
  freeBusy:
    baseURL: http://core-mw-http-api

  # the agent surface (MCP), off by default
  mcp:
    enabled: false

  # per-owner limits and retention
  maxPolls: 20
  maxEvents: 20
  maxInvitees: 200
  maxAppointmentTypes: 10
  maxActiveBookingsPerEmail: 5
  autoDeletionIntervalMinutes: 720                 # <= 0 disables the cleanup job
  autoDeletionDelayAfterLastSlotMinutes: 44640
  autoDeletionDelayAfterBookingEndMinutes: 44640

  # per-locale footer links rendered in the UI
  footer:
    en-US:
      - title: Privacy Policy
        url: https://example.com/privacy
```

Booking records hold personal data of people outside the organization, so retention is bounded
by design: they are hard-deleted once the appointment is past plus
`autoDeletionDelayAfterBookingEndMinutes`. That window is also the rebook window of a cancelled
booking, whose manage link dies when the row is purged. Appointment types themselves never
expire.

### Secrets

Never commit secrets to a values file. Both credentials the chart wires support the same two
ways: an inline value is rendered into a chart-owned Secret and takes precedence, while an
externally managed Secret (a MariaDB operator, External Secrets) is referenced through
`existingSecret`. Prefer the latter wherever a secret manager is available, because an inline
value ends up wherever the rendered values go.

The database password reaches the pods as a `secretKeyRef` either way, so the deployment rolls
when it changes. The free/busy credentials are the middleware's
`com.openexchange.rest.services.basic-auth.login`/`.password` and reach the service as
`FREEBUSY_USER`/`FREEBUSY_PASS`; both halves come from one Secret, because the login is generated
on a real deployment and is as much a credential as the password. Neither belongs in
`config.yaml`. With no free/busy source configured, the *Check for availability* setting is hidden
in the plugin and pages that already enabled it fail open.

SMTP secrets (`MAIL_PASS` for `authMethod: plain`, `MAIL_CLIENT_SECRET` for the OIDC methods) are
environment-only and are not wired by this chart; supply them through `env` from your own Secret.

### Internal certificate authorities

When the MTA or another endpoint the service connects to presents a certificate from an internal
CA, add that CA with `extraCaCerts`. The values are the same as ai-service's. Inline, the chart
creates the Secret:

```yaml
extraCaCerts:
  certificates: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
```

Or reference a Secret you manage (cert-manager, External Secrets, `kubectl`):

```yaml
extraCaCerts:
  existingSecret: internal-ca
  key: ca.crt
```

`existingSecret` takes precedence, and the bundle may hold several concatenated certificates. The
chart mounts it read-only into the application pods and the migration Job and sets
`NODE_EXTRA_CA_CERTS` to it, which adds the CAs to Node's trust store for every outbound
connection. Certificate verification stays on; do not reach for
`NODE_TLS_REJECT_UNAUTHORIZED=0`, which turns it off entirely.

Node reads the bundle once at startup. A changed inline bundle rolls the pods by itself; with
`existingSecret` Helm cannot see the change, so roll the deployment after a rotation with
`kubectl rollout restart`.

### Mail templates

Mail templates are Liquid files, three parts per mail type and locale:
`<template>.<locale>.subject.liquid`, `.txt.liquid` and `.html.liquid`. Defaults ship with the
image, and a file set here replaces the shipped one of the same name. Lookup falls back exact
locale → base language → `en`. Overrides are picked up live, and a file that fails to parse is
logged while the previous version keeps serving.

```yaml
mailTemplates:
  files:
    booking-confirmation.en.subject.liquid: |
      Your appointment with {{ ownerName }}
    booking-confirmation.en.txt.liquid: |
      Hello {{ bookerName }}, see you on {{ startsAt }}.
```

### Scaling and rollouts

Booking runs as one deployment sized by load, one pod or several, scaled by hand or by the HPA.
Every configuration change rolls the pods, so the default `strategy` surges first: the new pod
passes readiness before an old one stops, even at a single replica. To switch to
`type: Recreate`, also set `rollingUpdate: null`, because Helm merges the override into the
default.

```yaml
hpa:
  create: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 80

pdb:
  create: true
  maxUnavailable: 1
```

While the HPA is on, `replicaCount` is ignored. Creating it without a CPU or memory target or
extra metrics, or the budget without `minAvailable` or `maxUnavailable`, fails the render. The budget only
covers voluntary evictions such as node drains. On a single replica `maxUnavailable: 1` lets a
drain evict the only pod, while `minAvailable: 1` would block the drain, so keeping a pod
serving through a drain needs at least two replicas.

## Database migrations

Migrations run as a plain managed Job, not a Helm hook. By default the Job name rotates per
upgrade (a suffix derived from `migration.jobId`, falling back to the release revision) so a new
rollout never hits the immutable `Job.spec.template` error, and finished Jobs are cleaned up
after `migration.ttlSecondsAfterFinished`. For ArgoCD-managed deployments set
`migration.rotate: false`: `helm template` pins the revision, so the name would never rotate and
the TTL cleanup would leave the tracked Job `Missing`/`OutOfSync`. The Job then keeps a stable
name and is delete+recreated per sync via `Replace=true,Force=true`.

Migrations are idempotent (only pending ones run), so re-running per sync is safe. The
application also refuses to start against a database with pending migrations; that check is a
safety net, not the mechanism.

Because the Job and the Deployment apply concurrently, new pods can fail their pending-migrations
startup check until the Job completes. This is expected transiently, and old pods keep serving
during the rolling update.

## Upgrade and rollback

```sh
helm upgrade booking oci://registry.open-xchange.com/appsuite-core-internal/charts/booking \
  --version <chart version> -f booking-values.yaml -n production
kubectl -n production rollout status deployment/booking

helm history booking -n production
helm rollback booking -n production        # previous revision
```

A change to `bookingConfig` rolls the pods via `checksum/config`, though in most cases the
hot-reload picks the change up without a restart at all. `global.commitSha` exists to force a
rollout when the image tag itself is stable (e.g. `main`).
