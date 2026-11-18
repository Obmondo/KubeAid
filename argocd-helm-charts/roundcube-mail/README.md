# Roundcube

[Roundcube](https://roundcube.net/) is a browser-based IMAP webmail client: a straightforward inbox
UI, not a groupware suite. This wrapper vendors the
[helm-charts.mlohr.com](https://helm-charts.mlohr.com/) `roundcube` chart, dependency name
`roundcube`, version `1.16.0`.

Like SOGo (also in this repo), Roundcube is a client, not a mail server. It needs an existing
IMAP/SMTP server to point at. Pair it with the `stalwart-mail` chart here, or any IMAP/SMTP server
you already operate.

## Prerequisites

- An IMAP/SMTP server reachable from the cluster, with a hostname and port for both.
- A database for Roundcube's own state (contacts, preferences). `database.source: external` is the
  default in this wrapper's values; `zalando-postgres` is also supported if the Zalando Postgres
  operator is already installed on the cluster.

## Configuring the mail server connection

`imap.host`/`imap.port`/`imap.encryption` and `smtp.host`/`smtp.port`/`smtp.encryption` are set to
Gmail's defaults out of the box and need to be pointed at your actual server. Match `encryption` to
the port: `ssltls` for implicit-TLS ports (993, 465), `starttls` for STARTTLS ports (143, 587),
`none` for plaintext. Pointing at the wrong pair, e.g. `ssltls` against a STARTTLS-only port, fails
outright rather than falling back, so confirm which ports the server actually has listeners on
before assuming a config typo.

`smtp.username`/`smtp.password` default to `"%u"`/`"%p"`. These are Roundcube's own template
placeholders meaning "reuse the IMAP username/password just entered at login," not literal
credentials. Leave them as-is unless the mail server genuinely needs separate SMTP auth.

## Secret scanning false positive

Those same `"%u"`/`"%p"` placeholders, at `charts/roundcube/values.yaml` lines 191 and 194 in the
vendored dependency, get flagged by GitGuardian as an exposed SMTP credential. They aren't one.
They're the upstream chart's own template placeholders (meaning "reuse the IMAP username/password"),
not real credentials, and that directory is unpacked third-party dependency output this repo doesn't
author. A `.gitguardian.yaml` exclusion for `argocd-helm-charts/*/charts/**` was tried and then
removed, so this check is expected to fail on this PR. Noting it here so it isn't mistaken for a
real leak when it comes up.

## Logging in

Roundcube has no separate admin console. Every login is a regular IMAP account login. Point
`imap.host`/`smtp.host` at the mail server (see above), then go to the ingress hostname and log in
with any account's real email/password on that server directly; there's no self-service or
first-time-setup step on Roundcube's side. If the account needs an app password instead of its main
password (two-factor-protected accounts, or a mail server that restricts direct password login),
generate that on the mail server's own side first. See the `stalwart-mail` chart's README for how,
if that's what's backing this instance.

## Uploads

`config.uploadMaxFilesize` caps attachment size in the app itself (default `25M`), but PHP-FPM and
any ingress in front of it also need raising to match. A mismatch there truncates or rejects
uploads at a layer Roundcube's own setting doesn't control. If using an ingress-nginx controller,
that means also setting `nginx.ingress.kubernetes.io/proxy-body-size` to the same value.
