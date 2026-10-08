# Matomo

[Matomo](https://matomo.org) is open-source web analytics that you host yourself. This chart runs the
[official `matomo` image](https://hub.docker.com/_/matomo) (Apache variant). By default it also creates a
MariaDB database through [mariadb-operator](../mariadb-operator), but any MySQL or MariaDB server works.

## Why it's in KubeAid

Chart 2.x wrapped the Bitnami chart. Bitnami stopped publishing Matomo in August 2025 and
`bitnamilegacy/matomo` ends at 5.3.2, so since 3.0.0 the templates are our own: a Deployment, Service,
Ingress, PVC and archive CronJob. With `mariadb.enabled` it adds the `MariaDB` and `Database`
resources and an optional logical-backup CronJob.

## How it works

Matomo's code is not kept on the volume. Each pod copies it from the image into an `emptyDir`, and the PVC
only holds `config/`, `misc/` (uploaded logos and the GeoIP database) and the plugins from `plugins`. To
upgrade Matomo, change `image.tag`.

The `setup` init container runs before Apache starts. It downloads each plugin in `plugins` if that version
is not on the PVC yet, then runs `core:update` twice. The second run is needed because an update can activate
a plugin whose database columns are only added on the next run; 5.9 does this with AIAgents and
`log_visit.ai_agent_name`. After that it activates the plugins and writes `trusted_hosts`, the proxy
settings and the OIDC settings to `config.ini.php`. It also sets `enable_auto_update = 0` and
`enable_update_communication = 0`, because the version comes from `image.tag` and the one-click updater and
update emails would only get in the way. The pod has a checksum of the setup ConfigMap as an annotation, so
it restarts when these values change.

The `matomo-archive` CronJob runs `core:archive` every 5 minutes, which also runs the scheduled tasks. It
mounts the same PVC, so the PVC has to be `ReadWriteMany` (for example `ceph-filesystem`) unless the cluster
has a single node. Set "Archive reports when viewed from the browser" to No under Administration > System >
General settings. That setting is stored in the database and overrides the config file, so the chart can't
set it.

Matomo sends email for password resets, scheduled reports and a few scheduled tasks. The image has no local
mail server, so set up SMTP under Administration > System > General settings if you need any of that.
Without it those tasks log an error, and the archive job that ran them exits with an error once.

## Prerequisites

- A `ReadWriteMany` storage class for `persistence.storageClassName`.
- A database: either mariadb-operator on the cluster (the default), or your own MySQL or MariaDB server.

## Database

With `mariadb.enabled: true` the chart creates a MariaDB through mariadb-operator, with a database and a
`matomo` user. Its volume uses the cluster's default storage class unless you set
`mariadb.storage.storageClassName`. On our clusters rook-ceph once made the MariaDB probes fail because the
root password did not get set, and `zfs-localpv` was used instead.

Daily dumps are off by default. To turn them on, set `mariadb.logicalbackup.enabled: true` and
`mariadb.logicalbackup.provider` to `s3` (with `s3bucket`, `s3endpoint` and a `matomo-mariadb-pod-env` Secret
holding `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) or `az`. The chart refuses to render with backups on
and no valid provider.

To use a database you already have, such as Amazon RDS, Cloud SQL or a MariaDB outside the cluster, set
`mariadb.enabled: false`. The chart then creates no database resources and you enter the host, database
name, user and password in the web installer. Backups of that database are up to you.

## Values

| Value | Default | Meaning |
|---|---|---|
| `image.tag` | `5.14.0-apache` | Matomo version. Use an `-apache` tag. |
| `host` | `matomo.example.com` | Ingress host, `trusted_hosts` entry and the `--url` for `core:archive`. |
| `extraHosts` | `[]` | More hosts to serve and trust, for example a test hostname during a migration. |
| `ingress.className`, `ingress.annotations`, `ingress.tls` | `""`, `{}`, `true` | The TLS secret is `matomo-tls`. `tls` also sets `assume_secure_protocol`. |
| `persistence.storageClassName`, `persistence.accessMode`, `persistence.size` | `""`, `ReadWriteMany`, `1Gi` | The `matomo` PVC. |
| `plugins` | `[]` | List of `{name, version}` from plugins.matomo.org. A new version replaces the old one. |
| `archive.schedule` | `*/5 * * * *` | Schedule of the `core:archive` CronJob. |
| `oidc.*` | disabled | Keycloak login, see below. |
| `mariadb.enabled` | `true` | Create the database with mariadb-operator. Set `false` to use your own. |
| `mariadb.image` | `mariadb:latest` | Pin a version such as `mariadb:12.3` so the server is not upgraded unexpectedly. |
| `mariadb.passwordSecretKeyRef` | `matomo-user` / `db-password`, generated | Password of the Matomo database user. The backup CronJob uses it too. |
| `mariadb.rootPasswordSecretKeyRef` | `matomo-secrets` / `MARIADB_ROOT_PASSWORD`, generated | Needed with zfs-localpv, otherwise the PVC stays Pending. |
| `mariadb.storage.storageClassName` | `""` | Empty uses the cluster's default storage class. |
| `mariadb.storage.size` | `1Gi` | Can be resized while in use. |
| `mariadb.imagePullSecrets` | `[]` | Pull secrets for the MariaDB image, e.g. `[{name: registry}]`. |
| `mariadb.logicalbackup.enabled` | `false` | Daily dump CronJob, at `30 00 * * *` by default. Needs `provider`. |

## Fresh install

Sync the app and open `https://<host>`. There is no `config.ini.php` yet, so Matomo shows its web installer.
With `mariadb.enabled` the database host, name and user are filled in, and the password is filled in from
the secret but masked. With your own database, enter its details there.
Anyone who can reach the host can use the installer until it is finished, so finish it right away. Then
restart the deployment so the setup container activates the plugins and writes the settings.

## Keycloak login (OIDC)

Matomo has no OIDC support of its own. The [LoginOIDC plugin](https://plugins.matomo.org/LoginOIDC) adds it.

1. In Keycloak, create a client in your realm: client ID `matomo`, access type confidential, standard flow
   enabled, valid redirect URIs `https://<matomo>/index.php?module=LoginOIDC&action=callback&provider=oidc`
   and `https://<matomo>`, web origins `+`. Copy the client secret from the Credentials tab.
2. Put the client secret in a Secret under the key `MATOMO_OIDC_CLIENT_SECRET` and set:

```yaml
plugins:
  - name: LoginOIDC
    version: 5.0.0
oidc:
  enabled: true
  existingSecret: matomo-oidc                   # default
  keycloakUrl: https://your-keycloak.com/auth   # include the context path if any
  realm: your-realm
  allowedSignupDomains: example.com             # empty allows all domains
  # optional: clientId (matomo), buttonName (Login with Keycloak),
  # userinfoId (email), scope (openid email), allowSignup (true)
```

The settings are written to `config.ini.php`, which takes precedence over the database, so they are
read-only in the UI. The login page then has a "Login with Keycloak" button. Users logging in through OIDC
for the first time have no access to any site; give it to them under System > Users.

## Migrating from chart 2.x

The database stays as it is. Only the config file and the plugin list move.

1. Add the plugins you installed from the Marketplace to `plugins`, with their versions. The plugins page
   under Administration lists them. They were on the Bitnami volume and don't carry over by themselves.
2. Copy the config out of the old pod:
   `kubectl -n matomo cp <old-pod>:/bitnami/matomo/config/config.ini.php ./config.ini.php`
3. Delete the old `matomo` Deployment, because its selector is different and a sync can't change it, and
   the `matomo-scheduled-tasks` CronJob, which would keep running the old code. Then sync 3.x. The new pod
   starts with the web installer. Don't run it.
4. Copy the config in and restart. The setup container upgrades the database.

```sh
kubectl -n matomo cp ./config.ini.php <new-pod>:/var/www/html/config/config.ini.php -c matomo
kubectl -n matomo exec <new-pod> -c matomo -- chown 33:33 /var/www/html/config/config.ini.php
kubectl -n matomo rollout restart deploy/matomo
kubectl -n matomo logs deploy/matomo -c setup
```

5. When everything works, delete the old Bitnami PVC `matomo-matomo`.

## Superusers

By default Matomo allows only [one superuser](https://matomo.org/faq/general/faq_69/) through the UI. To give
more users superuser access, set it in the database from the MariaDB pod:

```sql
mariadb -u root -p$MARIADB_ROOT_PASSWORD    -- no space after -p
use <db_name>;
UPDATE `matomo_user` SET superuser_access = 1 WHERE `login` = 'username-here';
```

## Links

- Matomo: <https://matomo.org>
- LoginOIDC plugin: <https://plugins.matomo.org/LoginOIDC>
- Official image: <https://github.com/matomo-org/docker>
- mariadb-operator: <https://github.com/mariadb-operator/mariadb-operator>
