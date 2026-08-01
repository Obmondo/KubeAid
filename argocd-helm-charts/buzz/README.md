# Buzz

[Buzz](https://github.com/block/buzz) is a Nostr-based messaging platform for human–agent
collaboration: one relay binary serving WebSocket + REST + web UI, backed by PostgreSQL, Redis and
S3-compatible object storage.

This wrapper runs the upstream chart in its production profile and supplies the backing services the
KubeAid way: PostgreSQL from the CloudNativePG operator via `kubeaid-addons`, Redis from the Redis
operator, and object storage from an external S3-compatible endpoint.

Upstream's bundled `postgres` and `redis` subcharts are stripped from the vendored copy, so the
evaluation profile is gone and `buzz.postgresql.enabled` / `buzz.redis.enabled` have to stay false.
Re-vendoring with `bin/manage-helm-chart.sh --update-helm-chart buzz` pulls them back in, so the
removal has to be repeated on every chart bump.

## Prerequisites

- `cloudnative-pg` and `redis-operator` installed on the cluster.
- `sealed-secrets` (or another out-of-band secret mechanism) for the two Secrets below.
- An S3-compatible bucket plus its access key and secret key. The chart does **not** provision one —
  request the bucket and credentials, then set `buzz.s3.endpoint` and `buzz.s3.bucket`.

## Secrets

Two Secrets have to exist before the first sync. Both are referenced by name only, so seal them and
commit the SealedSecrets to your `kubeaid-config` repo.

### 1. `buzz-pgsql-credentials` — the database owner

CloudNativePG normally invents the owner's password and writes it to `buzz-pgsql-app`. Buzz cannot
consume that, so this chart pins the credentials instead: `global.postgresql.existingSecret` hands
the Secret to CNPG's `initdb`, which makes the password known ahead of time and therefore safe to
embed in `DATABASE_URL` below.

```sh
kubectl create secret generic buzz-pgsql-credentials \
  --namespace buzz \
  --type kubernetes.io/basic-auth \
  --from-literal=username=buzz \
  --from-literal=password='<password>' \
  --dry-run=client -o yaml | kubeseal -o yaml > buzz-pgsql-credentials.yaml
```

Changing the password afterwards does not reset an already-bootstrapped database — `initdb` runs
once. Rotate it in PostgreSQL and in `buzz-secrets` together.

### 2. `buzz-secrets` — the relay environment

The relay reads **every** secret environment variable from this single Secret, and `DATABASE_URL` is
mandatory — a missing key leaves the pod in `CreateContainerConfigError`. The upstream chart can
generate its own Secret, but that path relies on Helm's `lookup` and regenerates on every render, so
it is unusable under ArgoCD.

| Key | Required | Value |
|---|---|---|
| `DATABASE_URL` | yes | `postgres://buzz:<password>@buzz-pgsql-rw:5432/buzz` |
| `REDIS_URL` | at `replicaCount > 1` | `redis://buzz-redis:6379` |
| `BUZZ_S3_ACCESS_KEY` | yes in practice | Access key for the bucket |
| `BUZZ_S3_SECRET_KEY` | yes in practice | Secret key for the bucket |
| `BUZZ_RELAY_PRIVATE_KEY` | in practice yes | 64-char hex relay identity — see below |
| `BUZZ_GIT_HOOK_HMAC_SECRET` | at `replicaCount > 1` | 32+ random characters |

`<password>` is the same one sealed into `buzz-pgsql-credentials`.

`BUZZ_RELAY_PRIVATE_KEY` is optional to the relay but should always be set here. Upstream generates
one on first install, but only into the Secret the chart manages itself; with `existingSecret` set
that Secret is never rendered, so nothing generates the key and **the relay takes a new identity on
every restart**. Seal one and treat it as a backup — changing it changes who the relay is, and
federation peers will not recognise it.

```sh
openssl rand -hex 32    # BUZZ_RELAY_PRIVATE_KEY
openssl rand -hex 24    # BUZZ_GIT_HOOK_HMAC_SECRET
```

```sh
kubectl create secret generic buzz-secrets \
  --namespace buzz \
  --from-literal=DATABASE_URL='postgres://buzz:<password>@buzz-pgsql-rw:5432/buzz' \
  --from-literal=REDIS_URL='redis://buzz-redis:6379' \
  --from-literal=BUZZ_S3_ACCESS_KEY='<access-key>' \
  --from-literal=BUZZ_S3_SECRET_KEY='<secret-key>' \
  --from-literal=BUZZ_RELAY_PRIVATE_KEY='<64-hex>' \
  --dry-run=client -o yaml | kubeseal -o yaml > buzz-secrets.yaml
```

## Object storage

The relay runs an S3 conformance probe at startup and **exits** if the bucket is unreachable or the
credentials are wrong, so readiness never opens. A relay stuck in `CrashLoopBackOff` on a fresh
install is almost always the bucket, not the database.

Chart 0.1.7 always addresses objects as `<endpoint>/<bucket>/<key>`; it has no region or
addressing-style setting, so the endpoint has to serve path-style requests. Upstream's `main` adds
`s3.region` and `s3.addressingStyle`, but the published 0.1.7 artifact rejects both — its
`values.schema.json` sets `additionalProperties: false` — so they cannot be set until this wrapper
tracks a newer chart version.

The bucket must not be folded into `buzz.s3.endpoint`; the two are passed separately.

### Conformance probe (A3 gate)

Before serving git traffic the relay races `BUZZ_GIT_PROBE_WRITERS` (default **32**) concurrent
compare-and-swap writers against one key, `BUZZ_GIT_PROBE_ROUNDS` (default 3) times, to prove the
backend gives linearizable conditional writes. Git-on-object-storage stores refs as CAS'd pointer
objects, so a backend without that silently loses concurrent pushes — hence the gate is fatal.

Backends that support `If-Match` but throttle under contention — Ceph RGW among them — fail this with
`503 ServiceUnavailable` partway through, which looks like a capability gap but is not. The tell is
*where* it fails: an unsupported `If-Match` fails deterministically in an early phase, whereas
throttling fails intermittently, after earlier phases and the first round have passed.

Narrow the race rather than removing the gate:

```yaml
buzz:
  relay:
    extraEnv:
      - name: BUZZ_GIT_PROBE_WRITERS
        value: "8"
```

`BUZZ_GIT_CONFORMANCE_PROBE: "false"` skips the gate entirely. That is a last resort — the relay has
no retry or backoff for `503`, so a backend that throttles the probe will also throttle real
concurrent pushes, and skipping only moves the failure to runtime.

## Ingress

`buzz.ingress.className` and `buzz.ingress.annotations` are deliberately empty. Helm merges annotation
maps, so a default here would appear on every install and could not be removed downstream — set both
per cluster.

Relay traffic is long-lived WebSockets. On NGINX raise the timeouts, or connections drop after the
60s default:

```yaml
buzz:
  ingress:
    className: nginx
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

Traefik proxies WebSockets without extra configuration.

## Relay membership

`buzz.relay.requireRelayMembership` is `false` here, which runs an open relay and needs no operator
identity. To gate access on relay membership, set it to `true` and set `buzz.ownerPubkey` to the
operator's 64-char lowercase hex Nostr pubkey; the chart refuses to render without it.

## Scaling

`replicaCount > 1` requires `REDIS_URL` and `BUZZ_GIT_HOOK_HMAC_SECRET` in `buzz-secrets`; the chart
fails rendering otherwise. Git state lives in object storage, so `ReadWriteOnce` volumes stay correct
at any replica count — no ReadWriteMany storage is needed.

## Relay image

`image.tag` is pinned instead of inheriting `.Chart.AppVersion`. Chart 0.1.7 still declares
`appVersion: 0.1.0`, and that relay predates the startup migration step: it never creates the schema,
`_sqlx_migrations` is never written, and the relay then serves traffic while every query fails on a
missing relation — it looks healthy and answers WebSockets, so the cause is not obvious.

A relay that runs migrations logs either `Database migrations complete` or `Skipping database
migrations because BUZZ_AUTO_MIGRATE is not enabled` right after `Postgres connected`. Neither line
means the image is too old, whatever `BUZZ_AUTO_MIGRATE` is set to.

Re-check the pin when bumping the chart — upstream may have realigned `appVersion` by then.

Verify any new tag actually exists before pinning it. GHCR's `tags/list` for this repository returns
incomplete and inconsistent pages, and upstream's GitHub releases run ahead of the published relay
images — `v0.5.2` is tagged in git with no image behind it. Ask the registry about a specific tag
instead:

```sh
crane manifest ghcr.io/block/buzz:<tag> >/dev/null && echo exists
```

`0.2.0` is the newest published *release* image, and `latest` still resolves to it — so `latest` is
not current code. Upstream also publishes a per-commit `sha-<short>` image for every merge to main,
and `main` shares a digest with the newest of those, so tracking upstream means pinning a `sha-` tag.

Pair a main-head image with this chart deliberately: chart 0.1.7 renders the environment for a much
older relay, so a relay far ahead of it may expect configuration the chart cannot express. A startup
failure that complains about configuration rather than a backend is the sign of that drift.

## Init containers

`buzz.extraInitContainers` ships two, both `postgres:16-alpine`:

- **`wait-for-db`** — CNPG is usually still bootstrapping when the relay first rolls out, and the
  relay exits rather than retries. It polls with `psql` rather than `pg_isready` so it proves auth
  and the database, not just an open socket.
- **`reconcile-legacy-schema`** — repairs installs that passed through relay 0.1.0. That image
  created `audit_log` at runtime but shipped no migration runner, so sqlx recorded nothing; migration
  1 then aborts on `relation "audit_log" already exists` and rolls the whole schema back. The result
  is a relay that starts, serves WebSockets and fails every query on a missing relation. It is
  guarded on `_sqlx_migrations` being absent, so it is a no-op on a fresh install and after the first
  successful migrate, and can be dropped once no install predates 0.2.0.

Both assume the chart defaults — host `buzz-pgsql-rw` from `global.postgresql.instanceName`, and the
`DATABASE_URL` key from `secrets.existingSecret`. Change either and change these to match.
`extraInitContainers` is a list, so overriding it downstream replaces rather than merges.

## Git storage

`persistence.git.enabled` is `false`, so git working space is an emptyDir. That is deliberate.

The upstream Deployment hardcodes `strategy.rollingUpdate.maxUnavailable: 0` and exposes no value to
change it, so a rollout requires the replacement pod to be running before the old one exits. A
ReadWriteOnce volume — which is what most block storage classes give you, rook-ceph-block included —
cannot attach to two nodes at once, so **every rollout deadlocks on `Multi-Attach`** and the
Deployment never converges.

Nothing durable is lost. Git objects are rehydrated from object storage on each request and
repo-name uniqueness lives in Postgres, which is why upstream dropped its ReadWriteMany requirement.
The only cost is a cold cache after a restart.

Enable the PVC only with a ReadWriteMany storage class, where both pods can hold the volume during a
rollout.

## Backups

Losing any of these is data loss: `BUZZ_RELAY_PRIVATE_KEY`, the PostgreSQL database, and the S3
bucket. Enable `global.postgresql.backups` / `logicalbackup` for the database. Git state lives in the
bucket, not on disk, so the relay's local storage needs no backup.
