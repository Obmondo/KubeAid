# OpenLDAP

[jp-gouin's openldap-stack-ha](https://github.com/jp-gouin/helm-openldap) chart, version `4.3.3`: a
replicated OpenLDAP directory (multi-master replication via `syncrepl`), with optional bundled
`ltb-passwd` (self-service password change) and `phpldapadmin` (web UI) sidecars.

## Why it's in KubeAid

A real directory service, for apps that need one and shouldn't each invent their own user store.
The immediate driver: SOGo's OIDC login (see the `sogo` chart in this repo) authenticates a person
via an external IdP but still needs a `SOGoUserSources` LDAP lookup afterward to resolve who they
actually are — OIDC alone gives it an authenticated identity with nothing to attach it to. This
chart is what fills that gap, and the same directory can back Keycloak's user federation and
Stalwart's own LDAP directory backend, so all three read from one shared source instead of three
separate credential stores.

## Prerequisites

- Decide the LDAP domain (`global.ldapDomain`) up front — changing it later means re-provisioning
  every entry, not a config edit.
- A Secret (seal it, don't commit plaintext) with `LDAP_ADMIN_PASSWORD` and
  `LDAP_CONFIG_ADMIN_PASSWORD`, referenced via `global.existingSecret`. Left unset, the chart
  defaults both to the literal string `Not@SecurePassw0rd` in `values.yaml` — fine for `helm
  template` smoke-testing, not for anything that will hold real credentials.

## Replica count

Defaults to `replicaCount: 3` (the chart's HA posture, using `syncrepl` multi-master replication).
Drop to `1` for a first deployment or a cluster without spare capacity — replication can be turned
on later without a data migration, it is a running-config change, not a schema one.

## Seeding users

`customLdifFiles` (or `env.LDAP_SEED_INTERNAL_LDIF_PATH` with a ConfigMap/Secret mount, depending on
chart version) is how initial entries get loaded on first boot. LDIF is only applied once, on an
empty database — reseeding an already-initialized instance means either deleting the PVC or writing
entries via `ldapadd`/`ldapmodify` directly against the running service, not by editing the LDIF
source and re-syncing.

## Self-service password changes

`ltb-passwd.enabled: true` gives end users a web UI to change their own LDAP password without admin
involvement — the same self-service principle Stalwart's own account manager uses, worth enabling
for any deployment where people need to manage their own credentials.
