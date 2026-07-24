# goalert

GoAlert - open source on-call scheduling, automated escalations, and notifications. App version `v0.32.0`.

## 1. How to setup

Goalert reads data encryption key from the secret
you provide.

| Key | What it is |
|---|---|
| `GOALERT_DATA_ENCRYPTION_KEY` | Encrypts data at rest. **Back this up** - losing it makes encrypted data unrecoverable, and it must never change once set. |

### Create it (sealed-secrets)

```bash
NS=goalert   # your target namespace
ENC_KEY="$(openssl rand -base64 32)"

kubectl create secret generic goalert -n "$NS" \
  --from-literal=GOALERT_DATA_ENCRYPTION_KEY="$ENC_KEY" \
  --dry-run=client -o yaml \
| kubeseal --format yaml > goalert-sealed-secret.yaml
```

## 2. First admin user

GoAlert has **no default login** - create the first admin with its CLI inside the
pod (it reads the DB URL from the CNPG secret):

```bash
kubectl -n "$NS" exec -it deploy/goalerts -- goalert add-user --admin --user admin
```

Log in at your ingress URL with that account, then create real per-person admin
accounts from the UI and remove this bootstrap one.

## 3. Access

Set `ingress.*` in your values (host, `className`, TLS), or port-forward the
service (`:8081`) to reach the web UI.

## Configuration

| Value | Default | Notes |
|---|---|---|
| `goalert.dbUrlSecret.name` | `<instanceName>-pgsql-app` | CNPG secret the DB URL is read from |
| `goalert.dbUrlSecret.key` | `fqdn-uri` | Key in that secret |
| `goalert.encryptionKeySecret.name` | `goalert` | Secret holding the encryption key |
| `postgresql.enabled` | `false` | Bundled Postgres removed; use CNPG |
| `global.postgresql.enabled` | `true` | Provision the CNPG cluster via kubeaid-addons |
| `global.postgresql.instanceName` | `goalert` | → cluster `goalert-pgsql` |
| `ingress.enabled` | `false` | Set host/class/TLS to expose |
| `resources` | mem-limited | No CPU limit by policy |

Upstream project: https://github.com/target/goalert
