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
toggle on the identity provider link instead of on the domain. Every step is done in
the admin console; the field names below are the ones it shows.

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

The examples carry one user attribute from tenant to hub, `obmondo_user_id`: the
user's id in the system that provisions the tenant realms. Any attribute your
provisioning already writes works the same way; what matters is that it is a
positive integer, unique across all tenants, and never changes.

Throughout, `<host>` is the Keycloak base URL, for example
`https://auth.example.com/auth`. Drop `/auth` if the chart runs without
`KC_HTTP_RELATIVE_PATH`.

## Step 1: prepare the hub realm

The hub is usually the realm the application already logs in against. It needs two
realm settings and nothing else.

1. *Realm settings* -> *General*: switch **Organizations** on.
2. Same tab, **Unmanaged Attributes**: set to *Enabled*. Keycloak 24 and later only
   store attributes that the realm's user profile declares, and the broker writes
   `obmondo_user_id` onto the shadow user it creates here. Declaring the attribute
   under *Realm settings* -> *User profile* is the tidier alternative; either works.
3. *Realm settings* -> *Login*: **User registration** and **Forgot password** off.
   Nobody should get a local password in the hub; the only users here are the
   shadow accounts Keycloak creates on first brokered login.

Save.

## Step 2: a broker client in each tenant realm

The hub authenticates to a tenant realm like any OIDC relying party, so the tenant
needs a confidential client whose redirect URI is the hub's broker endpoint. The
alias in that URI is whatever the identity provider will be called in step 3; using
the tenant realm's own name keeps it obvious.

In the tenant realm:

1. *Clients* -> **Create client**.
   - **Client ID**: `hub-broker`
   - **Name**: `Login via <hub realm>`
   - Next. **Client authentication** on, **Standard flow** on, **Direct access
     grants** off, **Implicit flow** off.
   - Next. **Valid redirect URIs**:
     `<host>/realms/<hub realm>/broker/<tenant realm>/endpoint`
   - Save.
2. **Credentials** tab: copy the **Client secret**; step 3 needs it.
3. **Client scopes** tab -> `hub-broker-dedicated` -> **Add mapper** -> **By
   configuration** -> **User Attribute**:
   - **Name**: `mattermost id`
   - **User Attribute**: `obmondo_user_id`
   - **Token Claim Name**: `mattermost_id`
   - **Claim JSON Type**: String
   - **Add to ID token** on, **Add to access token** on, **Add to userinfo** on
   - Save.

The mapper is what carries the attribute to the hub. Username, email and name need
no mapper; they travel in Keycloak's standard claims from the built-in `profile`
and `email` scopes.

## Step 3: the tenant as an identity provider in the hub

In the hub realm:

1. *Identity providers* -> **Add provider** -> **Keycloak OpenID Connect**.
   - **Alias**: the tenant realm name
   - **Display name**: the tenant realm name
   - **Discovery endpoint**:
     `<host>/realms/<tenant realm>/.well-known/openid-configuration`
     The endpoint fields fill themselves in.
   - **Client ID**: `hub-broker`
   - **Client Secret**: the one copied in step 2
   - Add.
2. On the provider's **Settings** tab, in the **OpenID Connect settings** section,
   expand the collapsed **Advanced** link at its bottom and switch **Pass
   login_hint** on. The email the user typed on the hub's page is then prefilled on
   the tenant's login page instead of being asked twice.
3. Scroll to the **Advanced settings** section:
   - **Trust Email** on. The brokered email counts as verified when the tenant's
     token says so, and by default when it carries no `email_verified` claim.
     Without it the hub asks every new user to verify an address the tenant
     already vouched for.
   - **Hide on login page** on. Routing happens through Organizations; a visible
     button per tenant would list every customer to every visitor.
   - **Sync mode**: *Force*, so a name changed in the tenant realm shows up in the
     hub on the next login.
   - Save.
4. **Mappers** tab -> **Add mapper**:
   - **Name**: `mattermost id`
   - **Sync mode override**: *Import*
   - **Mapper type**: **Attribute Importer**
   - **Claim**: `mattermost_id`
   - **User Attribute Name**: `obmondo_user_id`
   - Save.

The importer overrides the provider's sync mode with *Import* on purpose: it runs
only when the hub creates the shadow user, never on a later login. A hub user who
already carried the attribute before brokering (a local account that gets linked)
keeps it, so the application never sees the id change. It also means a shadow user
created before the importer existed will never be backfilled: delete it and let the
next login recreate it.

The hub's first-login flow keeps its defaults. *Create User If Unique* creates the
shadow account when the email is new to the hub. When the email already belongs to
a local hub account, the flow falls through to *Confirm Link Existing Account*, and
the user proves ownership once (by email, or by re-authenticating with the old
local password) before the two are linked. That is the path every pre-existing
user takes on the first login after the move.

## Step 4: one organization per tenant, routed by email domain

Organizations give the hub a lookup table from email domain to identity provider.
Each tenant gets one organization with its domains; a domain can belong to only one
organization in a realm.

In the hub realm:

1. *Organizations* -> **Create organization**.
   - **Name**: the tenant's name
   - **Alias**: the tenant realm name (lowercase, URL-safe, cannot be changed later)
   - **Domains**: the tenant's email domain, Enter after each one
   - Save.
2. **Identity providers** tab -> **Link identity provider** -> pick the alias from
   step 3. Leave the membership type at its default. Save.
3. **Domains** tab -> click the domain -> **Identity provider**: that alias,
   **Auto redirect** on. Save.

With that, a user who types `anyone@<tenant domain>` on the hub's login page is
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
is plain OAuth 2 with three endpoints and a userinfo call. Keycloak serves that fine
once the hub's client answers userinfo the way the connector expects.

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

**The `openid` scope.** There is no `MM_GITLABSETTINGS_SCOPE` line, and that is
deliberate. The GitLab connector sends no `scope` parameter unless one is
configured, so Keycloak issues a token without `openid`, and its userinfo endpoint
refuses that token with a bodiless 403 (Mattermost logs "Received invalid response
from OAuth service provider" with an empty `response_body`). Setting the scope does
not help: Team Edition reroutes any GitLab scope containing `openid` to the OpenID
provider it does not ship, and the login fails with "Gitlab SSO through OAuth 2.0
not available on this server". The way out is to let Keycloak put `openid` on the
token by itself. In the hub realm:

1. *Client scopes* -> **Create client scope**: **Name** `openid`, **Type**
   *Default*, **Protocol** OpenID Connect, **Include in token scope** on, **Display
   on consent screen** off. Save. No mappers.
2. *Clients* -> the Mattermost client -> **Client scopes** tab -> **Add client
   scope** -> `openid` -> **Add** as *Default*.

Keycloak builds the token's scope claim from client scope names, so userinfo then
passes without the connector asking for anything.

**The userinfo fields.** The connector decodes userinfo into a struct with `id`,
`username`, `login`, `email` and `name`, rejects an `id` of `0` or an empty email,
and stores the decimal `id` as the account's `AuthData`. Keycloak's own subject is
a UUID and its default username claim is `preferred_username`, so the client needs
its own mappers. On the Mattermost client, **Client scopes** tab -> the client's
dedicated scope -> **Add mapper** -> **By configuration**, five times, each with
**Add to userinfo** on:

| Name | Mapper type | Source | Token Claim Name | Claim JSON Type |
|---|---|---|---|---|
| `mattermost-id` | User Attribute | `obmondo_user_id` | `id` | long |
| `mattermost-username` | User Property | `username` | `username` | String |
| `mattermost-login` | User Property | `username` | `login` | String |
| `mattermost-email` | User Property | `email` | `email` | String |
| `mattermost-name` | User's full name | | `name` | |

`long` on the id mapper is what makes it a bare number; as String it arrives in
quotes and the connector fails to unmarshal it.

**Where the id comes from.** Do not invent a number for this. The system that
provisions tenant users already has a stable integer id for each of them, and
writing it onto the Keycloak user at creation (`obmondo_user_id` here) gives every
tenant's users a Mattermost id with no per-user work and no collisions across
tenants. A user created by hand in a tenant realm has no such id and cannot log in
to Mattermost, which is a reasonable guard. Nothing may ever change the value once
a user has logged in: Mattermost matches accounts on that number, not on email,
and a changed number means "an account with that email already exists" at the
next login.

**Checking without logging in.** *Clients* -> the Mattermost client -> **Client
scopes** -> **Evaluate** sub-tab, leave the scope parameter empty, pick a user who
has logged in through the hub, open **Generated user info**. It should show `id` as
a bare number next to `username`, `login`, `email` and `name`. **Generated access
token** should list `openid` in its `scope`.

`username` in userinfo becomes the Mattermost username, `email` the email, and
`name` is split on the first space into first and last name. Tenant realms whose
usernames are email addresses yield Mattermost usernames with the `@` replaced; a
*Username Template Importer* mapper on the identity provider can derive something
nicer from the email's local part.

## Adding a tenant later

Steps 2, 3 and 4 are the per-tenant recipe: a broker client in the tenant realm, an
identity provider plus importer in the hub, an organization with its domains and
routing. Nothing on the application side changes. For many existing tenant realms,
the same steps through `kcadm.sh` or the admin REST API take a few minutes to
script; the JSON field names are the ones the console shows, and the whole recipe
is idempotent when each step first checks whether its object already exists.

## Sources

- Keycloak Server Administration Guide, [identity brokering](https://www.keycloak.org/docs/latest/server_admin/#_identity_broker)
  and [managing organizations](https://www.keycloak.org/docs/latest/server_admin/#_managing_organizations)
  (26.8: domain routing replaces the per-provider email-domain setting).
- Keycloak Admin REST API, [OrganizationDomainRepresentation and identity-provider link endpoints](https://www.keycloak.org/docs-api/latest/rest-api/index.html).
- Keycloak forum, [federated identity from another realm of the same server](https://forum.keycloak.org/t/federated-identity-from-another-realm-of-the-same-server/5660).
- Mattermost server, [GitLab OAuth provider source](https://github.com/mattermost/mattermost/blob/master/server/channels/app/oauthproviders/gitlab/gitlab.go)
  and [GitLab SSO docs](https://docs.mattermost.com/administration-guide/onboard/sso-gitlab.html).
- Ashish Jaiswal, [How to make Mattermost Team Edition work with Keycloak 20 and above](https://ashish1099.me/posts/mattermost-team-edition-keycloak-openid-scope-catch22/)
  (the `openid` client scope workaround and the five userinfo mappers).
- Keycloak issue [#52676](https://github.com/keycloak/keycloak/issues/52676), CVE-2026-4633, identity-first login domain enumeration.
