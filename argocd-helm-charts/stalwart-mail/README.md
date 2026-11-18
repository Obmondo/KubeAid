# Stalwart Mail Server

[Stalwart](https://stalw.art/) is an all-in-one mail server: IMAP4, JMAP, POP3, SMTP (submission +
relay), CalDAV/CardDAV, and Sieve filtering, in one binary with no external database required for
core mail storage. This wrapper vendors `wrenix`'s chart, `oci://codeberg.org/wrenix/helm-charts`,
version `2.0.8`.

This is the mail *server*, the thing IMAP/SMTP clients connect to. It has no webmail UI of its own
enabled by default, but the vendored chart does bundle an optional one (Twake, see below) as an
alternative to running the separate `sogo` or `roundcube-mail` charts in this repo.

## Core components, briefly

- **Protocol listeners.** IMAP4 (implicit TLS on 993, STARTTLS on 143), SMTP submission (implicit
  TLS on 465, STARTTLS on 587), and an SMTP relay listener for inbound mail (25). A chart's `ports`
  list declaring a port doesn't guarantee something's actually listening on it. Verify with a raw
  connection test rather than assuming from config alone.
- **JMAP.** Stalwart's own modern mail protocol, and also the transport for essentially all of its
  *administration*: accounts, domains, DKIM, abuse-detection allow/block lists, and most runtime
  settings are managed via `POST /jmap/` with `urn:stalwart:jmap` admin methods (`x:Account/*`,
  `x:Domain/*`, `x:BlockedIp/*`, `x:AllowedIp/*`, etc.), not a REST API or a config file. `stalwart
  --help` on the server binary confirms this: it only takes `--config`, `--export`, `--import`,
  `--console`, with no separate settings-query subcommand.
- **WebUI / Account Manager.** A browser UI over the same JMAP API, at `/` for admin and `/account`
  for end-user self-service (password changes, app passwords, see below).
- **Abuse detection.** Flags and can *permanently* block IPs showing scan-like traffic patterns
  (`x:BlockedIp`, persisted, not just an in-memory rate limit). This has a sharp edge in Kubernetes,
  covered next.

## Logging in

**Admin**, first time / recovery: the chart's `env` can set `STALWART_RECOVERY_MODE`/
`STALWART_RECOVERY_ADMIN` (e.g. `admin:$(FALLBACK_ADMIN_SECRET)`, pulling the password from a
Secret via `envFrom`/`secretRef`. See `secrets.create: false` if you're supplying your own Secret
instead of the chart's generated one. With recovery mode on, go to `https://<host>/`, log in with
`admin` and that password, and use the WebUI to configure the real domain/DKIM/directory setup.
Turn recovery mode back off (`STALWART_RECOVERY_MODE: "0"`) once done, it's meant to be temporary.

**Regular users**: `https://<host>/account` is the self-service login and account manager, separate
from the admin UI at `/`. Enter the account's email address; if OIDC is configured (see below), this
redirects to the external IdP automatically. From there, users can change their own password and
create app passwords for mail clients that need one (Thunderbird, etc.). See "Admin cannot set a
non-admin account's password" above for why this self-service step is the *only* way a non-admin
account gets a working credential at all.

**IMAP/SMTP clients** (Thunderbird and similar): point them at the same hostname on ports 993
(IMAPS) and 465 (submission), both implicit TLS. See the ports note above for why 143/587 won't
work unless STARTTLS is genuinely enabled. The password is whatever the account holder set via
`/account` self-service, or an app password if their mail client needs one for a
two-factor-protected account.

## Optional bundled components

The vendored chart ships two disabled-by-default subsystems worth knowing about before assuming
they're missing entirely — both are just `enabled: false` in `values.yaml`, not absent from the
chart.

### NATS (`nats.*`) — multi-node coordination

```yaml
nats:
  enabled: false        # deploy NATS and configure Stalwart to use it as coordinator
  config: {}
  promExporter:
    enabled: false       # NATS' own Prometheus exporter
    podMonitor:
      enabled: false
```

Only relevant once Stalwart runs as more than one replica. A single-instance deployment (this
wrapper's default) has nothing to coordinate and doesn't need it. Turning it on deploys a NATS
instance alongside Stalwart and wires it in as the backend that keeps multiple Stalwart nodes in
sync with each other.

### Twake (`webclients.twake.*`) — bundled webmail client

```yaml
webclients:
  twake:
    enabled: false
    image:
      repository: linagora/tmail-web   # Linagora's "TMail" web client
      tag: "v0.35.1"
    config:
      env:
        SERVER_URL: "https://{{ (.Values.ingress.hosts | first).host }}/"
        WEB_OIDC_CLIENT_ID: "teammail-web"
        OIDC_SCOPES: [openid, profile, email, offline_access]
    ingress:
      enabled: false
      hosts:
        - host: chart-example.local   # set this before enabling
```

This is a full webmail client (Linagora's TMail), built OIDC-first: `WEB_OIDC_CLIENT_ID` and
`OIDC_SCOPES` are baked into its own env config, so unlike SOGo it doesn't need a separate LDAP
directory bolted on for post-login user lookup. Enabling this is a real alternative to standing up
`sogo`/`roundcube-mail` as separate charts, worth evaluating before doing that extra work: fewer
moving parts, and it's already sitting in the same chart as the mail server itself. Needs
`ingress.hosts`/`webclients.twake.ingress.hosts` set to real hostnames and a registered OIDC client
(`teammail-web` by default, override `WEB_OIDC_CLIENT_ID` to change it) before it does anything
useful.

## The self-inflicted crash-loop trap

Kubernetes' own liveness/readiness probes can trigger Stalwart's abuse detection and get
**permanently blocked**, which then crash-loops the pod forever, because the block is what's
causing the need to restart, and every replacement pod hits the same block immediately.

Why it happens: kubelet's HTTP probe to the pod can appear to Stalwart as originating from a pod-CIDR
address rather than the node's real IP (depends on the cluster's CNI). Hit twice every ~10s (liveness
+ readiness), that rapid regular pattern reads as port scanning to the abuse heuristic.

Symptom fingerprint: the pod restarts every ~30s with `exitCode: 0, reason: "Completed"` (a graceful
shutdown after kubelet's SIGTERM, not an app crash), and liveness/readiness events show
`Get "http://<podIP>:8080/": EOF`. A plain restart does not fix it — the persisted block survives.

Fix: allowlist the pod CIDR so this traffic is never evaluated for abuse in the first place, then
clear any existing block:

```bash
curl -sk https://<host>/jmap/ -u "admin:$ADMIN_PW" -H 'Content-Type: application/json' -d '{
  "using": ["urn:ietf:params:jmap:core", "urn:stalwart:jmap"],
  "methodCalls": [["x:AllowedIp/set", {"accountId": "admin", "create": {"new1": {"address": "<pod-cidr>"}}}]]
}'
```

then `x:BlockedIp/get` to find the stale block and `x:BlockedIp/set` with `destroy` to clear it,
plus give Stalwart's own probe `timeoutSeconds`/`failureThreshold` more headroom. If the JMAP API
itself is unreachable because the pod is mid-crash-loop, hit the pod directly by IP
(`http://<podIP>:8080/jmap/` from a debug pod in the same namespace). The Service/ingress won't
route to a not-Ready pod, but the pod itself still answers.

The same abuse-detection mechanism can also collaterally block an ingress controller's own pod IP,
since all external traffic then arrives from that IP rather than real client IPs. The symptom is
intermittent 502s across everything behind that ingress, not just mail.

## Admin cannot set a non-admin account's password

Confirmed via the JMAP admin API: every attempt to set a `Password` credential on a `User`-role
account fails with `forbidden: "Cannot set credentials for accounts in an external directory"`.
This happens whether creating it fresh or updating an existing one, on any credential slot, and
**even with no external directory configured at all** (reproduces on a plain local domain with
`directoryId: null`). So the error text is misleading; what's actually going on matches Stalwart's
own documented behavior for
app passwords almost exactly: *"Administrators have limited control over Application Passwords.
They can view and revoke a user's Application Passwords but cannot create new ones on a user's
behalf."* The same restriction evidently applies to the primary password too, for any non-`Admin`
role.

Practical effect: there is no admin-side way to hand a regular user a working password. Either the
user sets it themselves through self-service (`/account`, needs an existing credential to log in
with in the first place), or the account authenticates externally via OIDC (`oidc.issuer` in this
chart's values) instead of a Stalwart-native password at all.

## OIDC

`oidc.issuer` plus an `existingOidcSecret` wires Stalwart's own admin/account login to an external
OIDC provider (e.g. Keycloak). This is runtime config on the Stalwart side (via its admin API/WebUI)
as much as it is a chart value — setting the value here configures the client registration Stalwart
uses, but the actual client (redirect URIs, secret) has to exist on the IdP side first.
