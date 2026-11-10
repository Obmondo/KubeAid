# mail

An in-cluster SMTP relay: Postfix from
[bokysan/docker-postfix](https://github.com/bokysan/docker-postfix), which workloads use to send
mail without each one holding credentials for the outside mail server.

Wrapper around the upstream [`mail` chart](https://bokysan.github.io/docker-postfix/), pulled in
as a dependency so the chart updater follows its releases.

## What KubeAid changes

- **`mail.recreateOnRedeploy: false`.** Upstream defaults to `true`, which stamps
  `date/deploy-date: <now>` into the pod template so every `helm upgrade` restarts the pod. Under
  Argo CD the chart is rendered continuously, so the app never reaches Synced and every sync
  restarts mail. The chart's `checksum/configmap` annotation still restarts the pod when the
  configuration changes.
- **`mail.config.postfix.smtpd_tls_security_level: "none"`.** The image offers STARTTLS on the
  submission port with its self-signed snakeoil certificate, issued to `localhost`. Clients that
  switch to TLS when it is offered and verify the certificate, such as Go's `net/smtp`, then fail
  every send with `x509: certificate is valid for localhost, not mail.system`. The relay is only
  reachable inside the cluster, so it doesn't offer TLS. This doesn't affect TLS from the relay to
  `RELAYHOST`, which `smtp_tls_security_level` controls.

## Key values

Upstream values live under the `mail:` key. The ones a cluster usually sets:

| Parameter | Description |
|-----------|-------------|
| `mail.config.general.RELAYHOST` | Where Postfix forwards mail |
| `mail.config.general.ALLOWED_SENDER_DOMAINS` | Sender domains the relay accepts |
| `mail.config.general.TZ` | Time zone for the logs |

See the [upstream values](charts/mail/values.yaml) for the rest.

## Upgrading from the vendored copy

Before 5.1.0 this directory held a copy of the upstream chart whose `appVersion` was the
placeholder `v1.0.0`, and the chart uses `appVersion` as the image tag. Clusters on that copy run
`boky/postfix:v1.0.0`, released in January 2019. Moving to this chart moves them to
`boky/postfix:v5.1.0`, which also changes the base image from Alpine to Debian slim (upstream v4).
The v5 image also started offering STARTTLS with its self-signed certificate, which broke sending
for clients that verify it; see `smtpd_tls_security_level` above. After syncing, send a test mail
through the relay.
