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
- The `/login` readiness probe expects local authentication. When switching
  `IRIS_AUTHENTICATION_TYPE` to OIDC, adjust the probe path.

## 4. SSO

IRIS supports OIDC (`IRIS_AUTHENTICATION_TYPE=oidc` plus `OIDC_*` variables). It maps only
username and email, not roles; assign customers and roles in IRIS by hand. Add the variables
through an extra Secret and `envFrom` once needed.
