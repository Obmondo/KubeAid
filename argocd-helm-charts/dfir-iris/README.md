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

## Access from Keycloak roles and groups (`keycloakSync`)

IRIS's OIDC login reads only the username and email claims, so a user who signs
in through SSO lands with no group and no customer. The optional
`keycloakSync` CronJob closes that gap: every few minutes it reads realm roles
and groups from Keycloak and sets each user's IRIS groups and customers to
exactly what `keycloakSync.mapping` yields.

- Missing users are created (login = Keycloak username, random unused password)
  and activated, so they are ready before their first login.
- Access removed in Keycloak is removed in IRIS on the next run. A user whose
  mapping yields no group or no customer, or who is disabled or deleted in
  Keycloak, is deactivated.
- Only the groups the mapping names are managed; other groups a user was given
  by hand stay. Customers are set exactly.
- Service accounts and `protectedLogins` (plus `admin.username`) are never
  touched. A Keycloak user with a protected name is reported and skipped,
  because an SSO login with that name would sign in as the local account.
- `dryRun: true` (the default) only logs what it would change. Read the job log,
  then set it to false.

Prerequisites: a confidential Keycloak client with a service account holding
`realm-management` `view-users`, and the API key of an IRIS user with
`server_administrator`, both in `keycloakSync.existingSecret`. If the Keycloak
hostname does not resolve correctly inside the cluster, set `hostAliases`; the
job uses the same entries as the app.

## AI triage with a self-hosted model (`aiTriage`)

An optional CronJob reads New alerts without an `ai:` tag, sends each (title,
rule, agent, indicators, a size-capped copy of the source event) to an Ollama
model with a JSON schema, and appends the answer to the alert note: severity,
false-positive likelihood, category, a short summary and a suggested next step,
plus tags `ai:triaged`, `ai:sev:<level>`, `ai:fp:<likely|unlikely|unknown>`
(`ai:error` if the model fails, so an alert is not retried forever).

- Advisory only. It never changes severity or status, never escalates and never
  triggers a response: alert content comes from logs an attacker can write, and
  the prompt tells the model to treat it as data, not instructions.
- Outside the detection path: a slow or missing model never delays alerts.
- Unowned alerts stay unowned (IRIS would otherwise make the job their owner).
- The model is told not to retype hashes, IPs or paths; the exact indicators are
  already on the alert, and a retyped value can be wrong.
- Keep the model service without internet egress (a NetworkPolicy on its
  namespace), so no alert content leaves the cluster.
