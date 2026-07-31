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
| `BUZZ_RELAY_PRIVATE_KEY` | no | 64-char hex relay identity. Generated on first install if absent — **back it up**, rotating it changes the relay's identity |
| `BUZZ_GIT_HOOK_HMAC_SECRET` | at `replicaCount > 1` | 32+ random characters |

`<password>` is the same one sealed into `buzz-pgsql-credentials`.

```sh
kubectl create secret generic buzz-secrets \
  --namespace buzz \
  --from-literal=DATABASE_URL='postgres://buzz:<password>@buzz-pgsql-rw:5432/buzz' \
  --from-literal=REDIS_URL='redis://buzz-redis:6379' \
  --from-literal=BUZZ_S3_ACCESS_KEY='<access-key>' \
  --from-literal=BUZZ_S3_SECRET_KEY='<secret-key>' \
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

## Backups

Losing any of these is data loss: `BUZZ_RELAY_PRIVATE_KEY`, the PostgreSQL database, the S3 bucket,
and the git PVC. Enable `global.postgresql.backups` / `logicalbackup` for the database.
