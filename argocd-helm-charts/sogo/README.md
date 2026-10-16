# SOGo

[SOGo](https://www.sogo.nu/) is a groupware server: webmail, calendaring and contacts in one app,
speaking CalDAV/CardDAV/ActiveSync alongside its own web UI. This wrapper vendors
`sonroyaalmerol/docker-sogo` 0.3.5, which bundles its own MariaDB/memcached/PostgreSQL subcharts for
SOGo's session and cache storage.

SOGo is a second webmail client, not a mail server. It needs an existing IMAP/SMTP server to point
at — this chart does not run one. Pair it with the `stalwart-mail` chart in this repo, or any other
IMAP/SMTP server you already operate.

## Prerequisites

- An IMAP/SMTP server SOGo can reach — hostname and port for both, known up front.
- A MariaDB instance (the bundled subchart works for a small/single-cluster deployment; point
  `mariadb.enabled: false` and set `sogo.SOGoProfileURL`/friends at an external instance for
  anything bigger).

## Values nesting — read this first

The dependency here is also named `sogo`, and the vendored chart itself uses `sogo:` as its own
top-level app-config key. That means every app setting needs **two** levels of nesting:

```yaml
sogo:
  sogo:
    SOGoIMAPServer: "imaps://mail.example.com:993/?tlsVerifyMode=none"
```

A value placed at `sogo.SOGoIMAPServer` (one level) renders silently as the chart's own default —
no error, just the wrong value. Check the rendered `sogo-config` ConfigMap if a setting doesn't seem
to be taking effect; that's almost always why.

## Connecting to the mail server

- Match the connection scheme to what the server actually listens on. Implicit TLS
  (`imaps://…:993`, `smtps://…:465`) and STARTTLS (`imap://…:143/?tls=YES`,
  `smtp://…:587/?tls=YES`) are not interchangeable — pointing at the wrong port/scheme pair gets a
  bare `ConnectionRefusedError` if nothing listens there, or a confusing hang if something does but
  speaks the other protocol. Verify with a raw socket connection before assuming a config mistake.
- For a self-signed certificate not issued for the connection hostname (e.g. an in-cluster
  `.svc.cluster.local` name), the working bypass is `tlsVerifyMode=none` in the connection URL:
  `imaps://host:993/?tlsVerifyMode=none`. `tlsVerifyMode=allowInsecureLocalhost` looks like the
  general-purpose option but isn't — it only relaxes verification when the connection host is
  literally `localhost`, and still enforces full verification against anything else.
  `ImapSSLPeerVerification`/`SmtpSSLPeerVerification` are not real SOGo config keys; they're
  silently ignored.
- **Sending mail needs one more setting SOGo won't warn you about:**
  `sogo.sogo.SOGoSMTPAuthenticationType: PLAIN`. Without it, SOGo never sends `AUTH` on the SMTP
  connection at all — it does the `EHLO`, gets a capability list, and goes straight to `MAIL FROM`,
  which most servers reject with something like `5.5.1 You must authenticate first`. `PLAIN` is the
  only value SOGo's SMTP mailer actually supports.

## Login: SOGo has no IMAP-bind auth mode

`SOGoUserSources` only supports `type: ldap` or `type: sql` for the actual login step. IMAP
(`SOGoIMAPServer`) is used purely to fetch mail *after* a successful login — never to authenticate
the login itself. Leave `SOGoUserSources` unset and this chart defaults to a SQL source against a
`sogo_view` table, which is **not created automatically** — SOGo's other tables self-create on
first use, this one doesn't:

```sql
CREATE TABLE sogo_view (
  c_uid VARCHAR(255) NOT NULL PRIMARY KEY,
  c_name VARCHAR(255),
  c_password VARCHAR(255),
  c_cn VARCHAR(255),
  mail VARCHAR(255)
);
```

Passwords in `c_password` need a `{PLAIN}` prefix for literal comparison (`{PLAIN}<password>`).
This password is checked independently of whatever the mail server thinks that account's password
is — nothing keeps the two in sync automatically. If they diverge, login succeeds (SOGo's own check
passes) but mail fetching then fails with `Could not connect IMAP4`, which looks like a server
problem but is really a stale `sogo_view` row.

For anything beyond a handful of accounts, a real `SOGoUserSources` LDAP entry (pointed at whatever
directory already backs the mail server) is the maintainable answer — avoids hand-populating
`sogo_view` per account, and keeps one password per person instead of two.

## Bitnami subchart images

The bundled `mariadb`/`memcached` subcharts pin Bitnami image tags that Docker Hub's free tier no
longer serves (Bitnami stopped publishing versioned tags there in 2025 — only opaque `sha256-`
digests remain). Override to `bitnamilegacy`, Broadcom's frozen mirror of the exact pre-retirement
tags:

```yaml
sogo:
  mariadb:
    image:
      registry: docker.io
      repository: bitnamilegacy/mariadb
      tag: "11.3.2-debian-12-r5"
```

A plain official `mariadb`/`memcached` image doesn't work as a substitute — Bitnami's own init
containers shell out to `/opt/bitnami/scripts/*` helpers that only exist in their image.

Also pin `mariadb.auth.rootPassword` explicitly. Left unset, the Bitnami chart generates a fresh
random one on every Helm render; under GitOps that means every sync regenerates the Secret without
touching the already-initialized database, so the "current" secret stops matching what's actually
on disk.

## MariaDB probe tolerance

The subchart's default `livenessProbe`/`readinessProbe` `initialDelaySeconds: 120` can be too tight
under real disk I/O contention — a probe firing mid-`mysql_install_db` kills the container before
first-boot initialization (including app-user creation) finishes. Because Bitnami's entrypoint
treats any non-empty datadir as already-initialized, that failure doesn't retry on the next boot —
it just boots into a half-initialized database missing its app user. Raise the tolerance if that
happens:

```yaml
sogo:
  mariadb:
    primary:
      livenessProbe:
        initialDelaySeconds: 300
        failureThreshold: 10
      readinessProbe:
        initialDelaySeconds: 300
        failureThreshold: 10
```

If it's already happened, either wipe (`kubectl delete pod <name>-mariadb-0 && kubectl delete pvc
data-<name>-mariadb-0`) or manually create the missing user via `mariadb -uroot` (socket auth, no
password needed until one is explicitly set).

## Logging in

Go to the ingress hostname and enter the account's email address and password. Same login screen
either way, but what that password actually checks against depends on `SOGoUserSources` (point 9
above): the SQL default checks it against `sogo_view.c_password`, not the mail server directly.

If the mail server itself requires an app password rather than the account's main password (Stalwart
does, for example, since two-factor or restricted accounts can't log in with the primary password
over plain IMAP), generate that app password on the mail server's own side first (see the
`stalwart-mail` chart's README for how, if that's what backs this instance), then put the *same*
value into `sogo_view.c_password` with the `{PLAIN}` prefix (point 5). SOGo's own login check and
the mail server's actual IMAP/SMTP check are two separate credential checks against two separate
stores. An app password fixed at one and not the other passes SOGo's login screen and then fails at
"Could not connect IMAP4" fetching mail, same symptom as the tlsVerifyMode bug in point 8 but a
different cause. Both values need to match.
