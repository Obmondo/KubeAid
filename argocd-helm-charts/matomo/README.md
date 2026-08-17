# Matomo

[Matomo](https://matomo.org) is an open-source, self-hosted web analytics platform — a privacy-respecting
alternative to Google Analytics where visitor data stays on your own infrastructure.

This is a KubeAid wrapper around the [Digitalist matomo chart](https://github.com/Digitalist-Open-Cloud/matomo-kubernetes)
(split dashboard/tracker/cli workloads, core:archive CronJob, php-fpm Prometheus exporter), with the
database managed through the [mariadb-operator](../mariadb-operator). Note the nested values paths:
`matomo.matomo.*` for the app, `matomo.db.*` for the database connection.

## Why it's in KubeAid

Self-hosted analytics with the database run the KubeAid way: the upstream chart brings no database of its
own (bring-your-own by design), so this chart renders `k8s.mariadb.com/v1alpha1` custom resources — a `MariaDB`
instance (`matomo-mariadb`), a `Database`, a `Grant` for the `matomo` user, and an optional logical-backup
CronJob (`ghcr.io/obmondo/mariadb-logical-backup`).

## Prerequisites

- `mariadb-operator` installed on the cluster (reconciles the `MariaDB`/`Database`/`Grant` CRs).
- Storage: `mariadb.storage.storageClassName` defaults to `zfs-localpv`. With rook-ceph the MariaDB liveness and
  readiness probes were failing because the root password did not get set properly — hence the default.

## Key values / KubeAid-specific configuration

| Value | Default | Meaning |
|---|---|---|
| `matomo.matomo.image` | `digitalist/matomo:5.12.0` | App image, published by the chart maintainers. |
| `matomo.db.*` | host `matomo-mariadb` | Points Matomo at the operator-managed database. |
| `matomo.db.password.secretKeyRef` | `matomo-user` / `db-password` | Secret holding the DB password. |
| `matomo.matomo.dashboard.hostname` | `my.host` | Dashboard Ingress hostname (set per cluster; same for `tracker.hostname`). |
| `matomo.matomo.config` | `{}` | Full `install.json` override: `PluginsInstalled` plus `Config` sections written to `config.ini.php` — declarative plugin + settings management. |
| `mariadb.rootPasswordSecretKeyRef` | `matomo-secrets` / `MARIADB_ROOT_PASSWORD`, `generate: true` | Operator generates the root password. Cannot be removed with zfs-localpv (PVC stays Pending otherwise). |
| `mariadb.passwordSecretKeyRef` | `matomo-user` / `db-password`, `generate: true` | Key name must stay `db-password` — it is what `matomo.db.password.secretKeyRef` looks up. |
| `mariadb.storage.size` | `1Gi` | In-use volume resize + wait are enabled. |
| `mariadb.logicalbackup.enabled` | `true` | Daily dump CronJob (default schedule `30 00 * * *`). |

## Single sign-on via Keycloak (OIDC)

Matomo has no built-in OIDC; the [LoginOIDC plugin](https://plugins.matomo.org/LoginOIDC) provides it.

1. In Keycloak, create a client in your realm: Client ID `matomo`, access type *confidential*, standard flow
   enabled, valid redirect URIs `https://<matomo>/index.php?module=LoginOIDC&action=callback&provider=oidc` and
   `https://<matomo>`, web origins `+`. Note the client secret from the Credentials tab.
2. Install and activate **LoginOIDC** — either declaratively by adding it to `PluginsInstalled` in
   `matomo.matomo.config` (its settings then go in that config's `Config.LoginOIDC` section, making step 3
   declarative too), or manually from *Settings → Platform → Marketplace* as a superuser.
3. Under *General Settings → LoginOIDC*, enable **Create new users when users try to log in with unknown OIDC
   accounts**, then fill in the endpoints (from the realm's *OpenID Endpoint Configuration*):
   - Authorize / Token / Userinfo URL: `https://<keycloak>/auth/realms/<realm>/protocol/openid-connect/{auth,token,userinfo}`
   - Logout URL: `.../openid-connect/logout?redirect_uri=https://<matomo>`
   - Userinfo ID: `preferred_username`; Client ID `matomo` + the client secret; OAuth scopes `openid email profile`.
4. A "Keycloak" button appears on the login screen. First-time OIDC users have no site permissions — assign them
   under *System → Users*.

## Operational notes

Matomo allows only [one superuser](https://matomo.org/faq/general/faq_69/) through the UI by default. To grant
superuser to more users, set it directly in the database (exec into the MariaDB pod):

```sql
mariadb -u root -p$MARIADB_ROOT_PASSWORD    -- no space after -p
use <db_name>;
UPDATE `matomo_user` SET superuser_access = 1 WHERE `login` = 'username-here';
```

## Docs links

- Matomo: <https://matomo.org> — LoginOIDC plugin: <https://plugins.matomo.org/LoginOIDC>
- Upstream chart: <https://github.com/Digitalist-Open-Cloud/matomo-kubernetes>
- mariadb-operator: <https://github.com/mariadb-operator/mariadb-operator>
