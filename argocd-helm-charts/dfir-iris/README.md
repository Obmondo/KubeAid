# dfir-iris

[DFIR-IRIS](https://github.com/dfir-iris/iris-web) collaborative incident response platform
(LGPL-3.0). This is a KubeAid-authored chart: the upstream `deploy/kubernetes` chart is an
unmaintained template with placeholder values that bundles PostgreSQL and RabbitMQ as raw
containers, so it is not wrapped. This chart runs the official `iriswebapp_app` image as the
app and the Celery worker, and takes PostgreSQL (CNPG) and RabbitMQ from kubeaid-addons.
The upstream nginx container is not used; TLS terminates at the ingress.

## 1. How to setup

Install cloudnative-pg and rabbitmq-operator first. Create one sealed Secret named
`dfir-iris` with the keys `IRIS_SECRET_KEY`, `IRIS_SECURITY_PASSWORD_SALT` and
`IRIS_ADM_PASSWORD` (random strings). Then:

```yaml
ingress:
  enabled: true
  host: iris.example.com
  tls:
    - secretName: iris-tls
      hosts:
        - iris.example.com
admin:
  email: soc@example.com
```

The first start creates the database schema and the administrator account from
`IRIS_ADM_*`. Database credentials are read from the CNPG-generated
`iris-pgsql-app` Secret and the broker credentials from `iris-rabbitmq-default-user`.

## 2. Storage

Downloads, user templates and server data live on one PVC mounted by both the app and the
worker. With ReadWriteOnce the worker is scheduled onto the app's node; use a ReadWriteMany
class (CephFS) to remove that constraint.

## 3. Known assumptions

- IRIS is given the same role for `POSTGRES_USER` (which it uses to create the database) and
  `POSTGRES_ADMIN_USER` (runtime). CNPG already creates `iris_db` owned by that role, so the
  create step should be skipped. Not yet verified on a cluster; confirm on the first deploy
  and, if the entrypoint insists on a superuser, point `postgres.existingSecret` at the CNPG
  superuser Secret instead.
- The `/login` readiness probe works with every authentication type: with OIDC and
  `localFallback: false` it answers with a redirect, which the probe counts as ready.

## 4. SSO (OIDC)

IRIS 2.4 has one authentication type at a time (`local`, `ldap` or `oidc`). With `oidc`
the login page shows a "Use SSO" button; `localFallback: true` keeps the username/password
form beside it, which is the break-glass path for the local administrator.

```yaml
authentication:
  type: oidc
  localFallback: true
  createUserIfNotExist: false
  oidc:
    issuerUrl: https://keycloak.example.com/auth/realms/myrealm
    clientId: iris
    existingSecret: dfir-iris-oidc   # key OIDC_CLIENT_SECRET
```

On the identity provider, create a confidential client with the standard (authorization
code) flow, redirect URI `https://<ingress.host>/oidc-authorize`, and the `profile` and
`email` scopes so the ID token carries `preferred_username` and `email`. IRIS reads the
discovery document from `issuerUrl` at startup, so the pods must reach that URL; if the
hostname resolves to an address the pods cannot use, add a `hostAliases` entry.

What IRIS does and does not do (checked against the 2.4.20 source):

- Users are matched on the username claim against IRIS logins, including existing local
  and service accounts, so keep IdP usernames distinct from local ones (`administrator`,
  service accounts).
- With `createUserIfNotExist: true` a first login creates the user in the default
  organisation only: no group, no customer, no permissions. With `false` an administrator
  pre-creates the user (login equal to the username claim) and gets a 404 page otherwise.
  `IRIS_NEW_USERS_DEFAULT_GROUP` applies to LDAP only.
- Groups and roles are not mapped from the token; assign groups and customers in
  Manage > Users by hand.
- API keys (`Authorization: Bearer` or `X-IRIS-AUTH`) are checked independently of the
  authentication type, so integrations keep working.
- MFA enforcement is skipped for OIDC logins.
