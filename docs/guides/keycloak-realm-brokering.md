# One login realm for many tenant realms

A Keycloak that keeps one realm per tenant is easy to reason about: every tenant has
its own users, password policy, MFA and clients, and nothing leaks between them. The
price shows up the moment a shared application (a support chat, a ticket system, a
status page) has to accept logins from all of those tenants. The application takes
one OIDC issuer, so it cannot be pointed at twenty realms.

Keycloak's answer is identity brokering: one realm, the *hub*, owns the
application's client and treats every tenant realm as an external identity provider.
A user types an email on the hub's login page, Keycloak looks up which tenant owns
that email domain, sends the user to that tenant realm to authenticate, and brings
them back with a linked account in the hub. The application only ever sees the hub.

Tenant realms stay the source of truth. Nobody gets a second password, and a tenant
created tomorrow needs only a broker entry in the hub, not a change to the
application.

This guide uses the `keycloakx` chart in KubeAid and Keycloak 26.8 or newer, which is
where per-domain routing for Organizations landed. Older 26.x releases put the same
toggle on the identity provider link instead of on the domain.

If you're new to KubeAid, check out our [README](../../README.md).

## How a login flows

```
browser            app (Mattermost)      hub realm            tenant realm
  |  open app            |                   |                     |
  |--------------------->|                   |                     |
  |  302 to hub /auth    |                   |                     |
  |<---------------------|                   |                     |
  |  type email          |                   |                     |
  |----------------------------------------->|                     |
  |                      |   domain -> organization -> identity provider
  |  302 to tenant /auth |                   |                     |
  |<-----------------------------------------|                     |
  |  password + MFA at the tenant            |                     |
  |--------------------------------------------------------------->|
  |  302 back to hub /broker/<alias>/endpoint with a code          |
  |<---------------------------------------------------------------|
  |----------------------------------------->|  code -> tokens     |
  |                      |                   |-------------------->|
  |                      |                   |  link or create hub user
  |  302 to app callback with a code         |                     |
  |<-----------------------------------------|                     |
  |--------------------->|  code -> tokens -> userinfo             |
  |                      |------------------>|                     |
```

Three Keycloak features do the work:

- **Identity provider of type `Keycloak OpenID Connect`** in the hub, one per tenant
  realm. Keycloak treats a realm on the same server exactly like a remote Keycloak;
  there is no shortcut for "another realm here".
- **Organizations** in the hub, one per tenant, each owning the tenant's email
  domains and linked to that tenant's identity provider. With domain routing and
  *Auto redirect* on, the identity-first login page sends a matching email straight
  to the tenant realm without showing a password form.
- **Identity provider mappers** that copy the attributes the application needs from
  the tenant's token onto the hub user.

All `kcadm.sh` calls below assume you have already logged in:

```sh
kcadm.sh config credentials --server https://auth.example.com/auth --realm master --user admin
```

Drop `/auth` from every URL in this guide if the chart runs without
`KC_HTTP_RELATIVE_PATH`.

## Step 1: prepare the hub realm

Most of the time the hub already exists: it is the realm the application logs in
against today, usually with the application's client already in it. Then all it
needs is Organizations switched on.

```sh
HOST=https://auth.example.com/auth
HUB=customers

kcadm.sh update "realms/$HUB" -s organizationsEnabled=true
```

The realm can also be created from scratch with the chart's `realmImports`, which
Keycloak reads at startup with `--import-realm`. The import is create-only: once the
realm exists, edits to the file do nothing, so put only what the realm needs on day
one in here and do the per-tenant work with `kcadm` (step 2 onward).

```yaml
keycloakx:
  args:
    - --import-realm
  # The client secret is a ${ENV} placeholder, resolved from the container's
  # environment. Keep it in a Secret (sealed in the config repo) with one key,
  # HUB_APP_CLIENT_SECRET.
  extraEnvFrom: |
    - secretRef:
        name: hub-app-client
  extraVolumes: |
    - name: realm-imports
      configMap:
        name: keycloakx-realm-imports
  extraVolumeMounts: |
    - name: realm-imports
      mountPath: /opt/keycloak/data/import
      readOnly: true

realmImports:
  customers: |
    {
      "realm": "customers",
      "displayName": "Customers",
      "enabled": true,
      "sslRequired": "external",
      "organizationsEnabled": true,
      "registrationAllowed": false,
      "resetPasswordAllowed": false,
      "loginWithEmailAllowed": true,
      "duplicateEmailsAllowed": false,
      "bruteForceProtected": true,
      "clientScopes": [
        {
          "name": "openid",
          "protocol": "openid-connect",
          "attributes": {
            "include.in.token.scope": "true",
            "display.on.consent.screen": "false"
          }
        }
      ],
      "clients": [
        {
          "clientId": "mattermost",
          "name": "Mattermost",
          "enabled": true,
          "protocol": "openid-connect",
          "publicClient": false,
          "clientAuthenticatorType": "client-secret",
          "secret": "${HUB_APP_CLIENT_SECRET}",
          "standardFlowEnabled": true,
          "directAccessGrantsEnabled": false,
          "implicitFlowEnabled": false,
          "serviceAccountsEnabled": false,
          "rootUrl": "https://chat.example.com",
          "redirectUris": [
            "https://chat.example.com/signup/gitlab/complete",
            "https://chat.example.com/login/gitlab/complete"
          ],
          "webOrigins": [
            "https://chat.example.com"
          ],
          "defaultClientScopes": [
            "openid",
            "profile",
            "email",
            "roles",
            "web-origins",
            "acr",
            "basic"
          ],
          "protocolMappers": [
            {
              "name": "mattermost id",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-attribute-mapper",
              "config": {
                "user.attribute": "obmondo_user_id",
                "claim.name": "id",
                "jsonType.label": "long",
                "id.token.claim": "false",
                "access.token.claim": "false",
                "userinfo.token.claim": "true"
              }
            },
            {
              "name": "username",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-property-mapper",
              "config": {
                "user.attribute": "username",
                "claim.name": "username",
                "jsonType.label": "String",
                "userinfo.token.claim": "true"
              }
            }
          ]
        }
      ]
    }
```

The realm does not list `requiredActions`: a partial list replaces Keycloak's
defaults and silently drops things like `UPDATE_PASSWORD`. Leave the key out.

The examples below carry one user attribute from tenant to hub, `obmondo_user_id`:
the user's id in the system that provisions the tenant realms. Any attribute your
provisioning already writes works the same way; what matters is that it is a
positive integer, unique across all tenants, and never changes. Keycloak 24 and
later only store user attributes that the realm's user profile declares, or any
attribute when unmanaged attributes are allowed. The tenant realms get it from the
provisioner; the hub needs it too, since the broker writes it onto the shadow user:
*Realm settings* -> *General* -> *Unmanaged attributes* -> *Enabled*, or declare
the attribute under *Realm settings* -> *User profile*.

Nobody has local credentials in the hub once every tenant is brokered, so leave
`registrationAllowed` and `resetPasswordAllowed` off. The only users here are the
shadow accounts Keycloak creates on first brokered login, plus whatever local
accounts predate the move.

## Step 2: a broker client in each tenant realm

The hub authenticates to a tenant realm like any OIDC relying party, so the tenant
needs a confidential client whose redirect URI is the hub's broker endpoint. The
alias in that URI is whatever you will call the identity provider in step 3; using
the tenant realm's own name keeps it obvious.

```sh
TENANT=acme
SECRET=$(openssl rand -base64 32)

kcadm.sh create clients -r "$TENANT" \
  -s clientId=hub-broker \
  -s name="Login via $HUB" \
  -s publicClient=false \
  -s clientAuthenticatorType=client-secret \
  -s secret="$SECRET" \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=false \
  -s implicitFlowEnabled=false \
  -s "redirectUris=[\"$HOST/realms/$HUB/broker/$TENANT/endpoint\"]"
```

If the application needs an attribute that lives on the tenant user (step 5 has the
Mattermost case), add a protocol mapper to this client so the attribute travels in
the token the hub receives:

```sh
CLIENT_ID=$(kcadm.sh get clients -r "$TENANT" -q clientId=hub-broker --fields id --format csv --noquotes)

kcadm.sh create "clients/$CLIENT_ID/protocol-mappers/models" -r "$TENANT" \
  -s name="mattermost id" \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-usermodel-attribute-mapper \
  -s 'config."user.attribute"=obmondo_user_id' \
  -s 'config."claim.name"=mattermost_id' \
  -s 'config."jsonType.label"=String' \
  -s 'config."id.token.claim"=true' \
  -s 'config."access.token.claim"=true' \
  -s 'config."userinfo.token.claim"=true'
```

## Step 3: the tenant as an identity provider in the hub

In the admin console this is *Identity providers* -> *Add provider* -> *Keycloak
OpenID Connect*, with the tenant's discovery document
(`$HOST/realms/$TENANT/.well-known/openid-configuration`) as the import source.
With `kcadm` it is one create call. The provider is hidden on the login page because
Organizations will route to it; a visible button per tenant would list every
customer to every visitor.

```sh
ISSUER=$HOST/realms/$TENANT

kcadm.sh create identity-provider/instances -r "$HUB" \
  -s alias="$TENANT" \
  -s displayName="$TENANT" \
  -s providerId=keycloak-oidc \
  -s enabled=true \
  -s trustEmail=true \
  -s hideOnLogin=true \
  -s storeToken=false \
  -s 'config.clientId=hub-broker' \
  -s "config.clientSecret=$SECRET" \
  -s "config.issuer=$ISSUER" \
  -s "config.authorizationUrl=$ISSUER/protocol/openid-connect/auth" \
  -s "config.tokenUrl=$ISSUER/protocol/openid-connect/token" \
  -s "config.userInfoUrl=$ISSUER/protocol/openid-connect/userinfo" \
  -s "config.logoutUrl=$ISSUER/protocol/openid-connect/logout" \
  -s "config.jwksUrl=$ISSUER/protocol/openid-connect/certs" \
  -s 'config.useJwksUrl=true' \
  -s 'config.validateSignature=true' \
  -s 'config.defaultScope=openid email profile' \
  -s 'config.syncMode=FORCE'
```

What the settings mean:

- **Trust Email** marks the brokered email as verified when the tenant's token
  carries `email_verified`, or by default when it does not. Without it the hub
  asks every new user to verify their email again, which is pointless for a login
  that just happened against the tenant's own directory.
- **Sync mode `FORCE`** re-applies the mappers on every login, so a name or
  attribute changed in the tenant realm shows up in the hub next time. `IMPORT`
  would freeze whatever the first login brought.
- **Hide on login page** removes the provider button. Routing happens through
  Organizations (step 4) or an explicit `kc_idp_hint=<alias>` query parameter on
  the authorization URL, which is handy for a per-tenant deep link.

Then copy the attributes the application reads onto the hub user with an
*Attribute Importer* mapper on the identity provider:

```sh
kcadm.sh create "identity-provider/instances/$TENANT/mappers" -r "$HUB" \
  -s name="mattermost id" \
  -s identityProviderAlias="$TENANT" \
  -s identityProviderMapper=oidc-user-attribute-idp-mapper \
  -s 'config.syncMode=IMPORT' \
  -s 'config.claim=mattermost_id' \
  -s 'config."user.attribute"=obmondo_user_id'
```

This mapper overrides the provider's sync mode with `IMPORT` on purpose: it runs
only when the hub creates the shadow user, never on a later login. A hub user who
already carried the attribute before brokering (a local account that gets linked)
keeps it, so the application never sees the id change.

The hub's first-login flow (*first broker login*) keeps its defaults. *Create User
If Unique* creates the shadow account when the email is new to the hub. When the
email already belongs to a local hub account, the flow falls through to *Confirm
Link Existing Account*, and the user proves ownership once (by email, or by
re-authenticating with the old local password) before the two are linked. That is
the path every pre-existing user takes on the first login after the move.

## Step 4: one organization per tenant, routed by email domain

Organizations give the hub a lookup table from email domain to identity provider.
Each tenant gets one organization with its domains; a domain can belong to only one
organization in a realm. The identity provider is linked first, because the domain's
routing target has to be one of the organization's linked providers.

```sh
ORG_ID=$(kcadm.sh create organizations -r "$HUB" -i \
  -s name="$TENANT" \
  -s alias="$TENANT" \
  -s enabled=true \
  -s 'domains=[{"name":"acme.example","verified":true}]')

# link the tenant's identity provider; the request body is the bare alias
kcadm.sh create "organizations/$ORG_ID/identity-providers" -r "$HUB" -b "\"$TENANT\""

# route the domain to it and skip the login form for matching emails
kcadm.sh update "organizations/$ORG_ID" -r "$HUB" \
  -s "domains=[{\"name\":\"acme.example\",\"verified\":true,\"identityProviderAlias\":\"$TENANT\",\"autoRedirect\":true}]"
```

In the console the same thing is *Organizations* -> the tenant -> *Domains* tab ->
edit `acme.example` -> *Identity provider* = the tenant's alias and *Auto redirect*
on. With that, a user who types `anyone@acme.example` on the hub's login page is
sent to the tenant realm without seeing a password form. Leave *Auto redirect* off
and the user instead gets the provider offered as a choice, which is only useful
while the tenant still has local hub accounts.

After a brokered login the user is added to the organization automatically, but
only when the email domain the tenant returned matches one of the organization's
domains (Keycloak calls this the domain gate). Shared mailbox domains such as
`gmail.com` therefore cannot be routed: a tenant whose staff use personal
addresses needs a vanity login link with `kc_idp_hint=<alias>` instead of a domain.

The identity-first login page tells a visitor whether a domain is known to the
realm. That is inherent to the feature and was reported as CVE-2026-4633; keep the
chart's Keycloak current and do not put secret tenant names in organization
aliases that end up in redirect URLs.

## Step 5: the application side

If the hub is the realm the application already used, nothing changes in the
application at all: client id, secret, callback URLs and endpoints all stay. If the
hub is new, the realm in the issuer URL is the only thing to swap.

### Mattermost Team Edition

Team Edition has no generic OIDC login; its free SSO is the GitLab connector, which
is plain OAuth 2 with three endpoints and a userinfo call. Keycloak serves that fine:

```yaml
mattermostEnv:
  - name: MM_GITLABSETTINGS_ENABLE
    value: "true"
  - name: MM_GITLABSETTINGS_ID
    value: "mattermost"
  - name: MM_GITLABSETTINGS_SECRET
    valueFrom:
      secretKeyRef:
        name: mattermost-gitlab-secret
        key: gitlab-secret
  - name: MM_GITLABSETTINGS_AUTHENDPOINT
    value: "https://auth.example.com/auth/realms/customers/protocol/openid-connect/auth"
  - name: MM_GITLABSETTINGS_TOKENENDPOINT
    value: "https://auth.example.com/auth/realms/customers/protocol/openid-connect/token"
  - name: MM_GITLABSETTINGS_USERAPIENDPOINT
    value: "https://auth.example.com/auth/realms/customers/protocol/openid-connect/userinfo"
```

There is no `MM_GITLABSETTINGS_SCOPE` line, and that is deliberate. The GitLab
connector sends no `scope` parameter unless one is configured, so Keycloak issues a
token without `openid`, and its userinfo endpoint refuses that token with a
bodiless 403 (Mattermost logs "Received invalid response from OAuth service
provider" with an empty `response_body`). Setting the scope does not help: Team
Edition reroutes any GitLab scope containing `openid` to the OpenID provider it
does not ship, and the login fails with "Gitlab SSO through OAuth 2.0 not
available on this server". The way out is to let Keycloak put `openid` on the
token by itself: a client scope named exactly `openid`, with "Include in token
scope" on and no mappers, attached to the Mattermost client as a default client
scope. Keycloak builds the token's scope claim from client scope names, so
userinfo then passes without the connector asking for anything.

```sh
CLIENT_ID=$(kcadm.sh get clients -r "$HUB" -q clientId=mattermost --fields id --format csv --noquotes)
SCOPE_ID=$(kcadm.sh create client-scopes -r "$HUB" -i \
  -s name=openid \
  -s protocol=openid-connect \
  -s 'attributes."include.in.token.scope"=true' \
  -s 'attributes."display.on.consent.screen"=false')
kcadm.sh update "clients/$CLIENT_ID/default-client-scopes/$SCOPE_ID" -r "$HUB"
```

Two things about the GitLab connector shape what the hub must emit:

- **`id` must be a non-zero integer.** Mattermost decodes the userinfo document
  into a struct whose `id` is an `int64`, rejects `0`, and stores the decimal string
  as the user's `AuthData`. Keycloak's own subject is a UUID, so a plain `sub` will
  not do; the client needs a mapper from a user attribute to a claim named `id`
  with JSON type `long`, and steps 2 and 3 carry that attribute from the tenant
  realm into the hub. Do not invent a number for this. The system that provisions
  tenant users already has a stable integer id for each of them, and writing it
  onto the Keycloak user at creation (`obmondo_user_id` here) gives every tenant's
  users a Mattermost id with no per-user work and no collisions across tenants.
  A user created by hand in a tenant realm has no such id and cannot log in to
  Mattermost, which is a reasonable guard. Nothing may ever change the value once
  a user has logged in.
- **Accounts are matched on that id, not on email.** Every Mattermost user who has
  logged in through the hub before already has an `AuthData`. The hub must keep
  returning the same number for the same person, or the next login fails with
  "an account with that email already exists". For users who move from a local hub
  account to a brokered one (step 3's link flow), set the tenant-side attribute to
  the value the hub already gave them.

Before adding an `id` mapper to a client that already serves Mattermost, look at
what it has; a working login means some mapper already produces the claim, and a
second one would shadow it:

```sh
CLIENT_ID=$(kcadm.sh get clients -r "$HUB" -q clientId=mattermost --fields id --format csv --noquotes)
kcadm.sh get "clients/$CLIENT_ID/protocol-mappers/models" -r "$HUB" --fields name,protocolMapper,config
```

If there is none, add it:

```sh
kcadm.sh create "clients/$CLIENT_ID/protocol-mappers/models" -r "$HUB" \
  -s name="mattermost id" \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-usermodel-attribute-mapper \
  -s 'config."user.attribute"=obmondo_user_id' \
  -s 'config."claim.name"=id' \
  -s 'config."jsonType.label"=long' \
  -s 'config."userinfo.token.claim"=true'
```

`username` in userinfo becomes the Mattermost username, `email` the email, and
`name` is split on the first space into first and last name.

## Adding a tenant later

Steps 2, 3 and 4 are the per-tenant recipe: a broker client in the tenant realm, an
identity provider plus mapper in the hub, an organization with its domains and
routing. Nothing on the application side changes. Because `realmImports` is
create-only, these steps belong in whatever reconciles tenant realms, not in the
chart values.

## Sources

- Keycloak Server Administration Guide, [identity brokering](https://www.keycloak.org/docs/latest/server_admin/#_identity_broker)
  and [managing organizations](https://www.keycloak.org/docs/latest/server_admin/#_managing_organizations)
  (26.8: domain routing replaces the per-provider email-domain setting).
- Keycloak Admin REST API, [OrganizationDomainRepresentation and identity-provider link endpoints](https://www.keycloak.org/docs-api/latest/rest-api/index.html).
- Keycloak source for the mapper ids and config keys:
  [broker UserAttributeMapper](https://github.com/keycloak/keycloak/blob/main/services/src/main/java/org/keycloak/broker/oidc/mappers/UserAttributeMapper.java),
  [OIDCAttributeMapperHelper](https://github.com/keycloak/keycloak/blob/main/services/src/main/java/org/keycloak/protocol/oidc/mappers/OIDCAttributeMapperHelper.java),
  [OIDCIdentityProviderConfig](https://github.com/keycloak/keycloak/blob/main/services/src/main/java/org/keycloak/broker/oidc/OIDCIdentityProviderConfig.java).
- Keycloak forum, [federated identity from another realm of the same server](https://forum.keycloak.org/t/federated-identity-from-another-realm-of-the-same-server/5660).
- Mattermost server, [GitLab OAuth provider source](https://github.com/mattermost/mattermost/blob/master/server/channels/app/oauthproviders/gitlab/gitlab.go)
  and [GitLab SSO docs](https://docs.mattermost.com/administration-guide/onboard/sso-gitlab.html).
- Ashish Jaiswal, [How to make Mattermost Team Edition work with Keycloak 20 and above](https://ashish1099.me/posts/mattermost-team-edition-keycloak-openid-scope-catch22/)
  (the `openid` client scope workaround and the five userinfo mappers).
- Big Bang, [Mattermost with Keycloak via the GitLab connector](https://docs-bigbang.dso.mil/latest/packages/mattermost/docs/keycloak/)
  (a user attribute to `id` long claim mapping).
- Keycloak issue [#52676](https://github.com/keycloak/keycloak/issues/52676), CVE-2026-4633, identity-first login domain enumeration.
