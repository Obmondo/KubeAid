# stalwart

[Stalwart](https://stalw.art) is an open-source (AGPL-3.0) mail and collaboration server: SMTP,
IMAP, POP3, JMAP, CalDAV/CardDAV and ManageSieve, with built-in spam filtering and DKIM/SPF/DMARC.
It ships as a single binary.

Stalwart publishes no chart repository; its Helm chart exists only as
[documentation](https://stalw.art/docs/cluster/orchestration/kubernetes-chart). These templates are
derived from it and adapted to KubeAid.

## Layout

| Concern | Backend | Configured in |
| --- | --- | --- |
| Data store (accounts, mailboxes, settings) | CNPG PostgreSQL (`global.postgresql`, via kubeaid-addons) | `config.json` (ConfigMap) |
| Full-text search | Same PostgreSQL (`SearchStore: Default`) | plan |
| Message blobs | S3, e.g. RustFS at `bucket.obmondo.com` | plan |
| In-memory store + cluster coordinator | Redis (opstree `Redis` CR) | plan |
| Login | Keycloak through an OIDC directory | plan |
| TLS for SMTP/IMAP | cert-manager `Certificate`, mounted at `/etc/stalwart/tls` | plan |

Stalwart reads **only the data store** from `config.json`. Every other setting lives in the
database. The chart therefore renders an NDJSON
[plan](https://stalw.art/docs/management/cli/plan-format) from the values. An Argo CD **PostSync
Job** applies it with `stalwart-cli apply` on every sync.

Every operation in the plan is an `upsert` or an `update`, so re-applying it converges to the same
state.

Because all state is in PostgreSQL, S3 and Redis, the pods are stateless. Run 2+ replicas once the
shared stores are set (step 4 below).

Network exposure:

- **Mail** (25, 465, 993, 4190) goes through the `<release>-mail` Service, a `LoadBalancer` with
  `externalTrafficPolicy: Local` by default.
- **HTTP** (WebUI `/admin` and `/account`, JMAP, CalDAV/CardDAV, autoconfig) goes through the
  Ingress to Stalwart's plain-HTTP listener on 8080. TLS terminates at the ingress.

Port 587 and plain IMAP 143 have no listener in Stalwart's default configuration and are not
exposed. Mail clients use 465 (implicit TLS) and 993.

## Prerequisites

- Operators: cloudnative-pg, redis-operator (opstree), cert-manager, and stakater/reloader.
  Reloader restarts the pods when the certificate renews, because Stalwart reads certificate files
  at load time.
- An S3 bucket and a user for it. On RustFS, follow the user == bucket layout.
- Secrets in the namespace. Use SealedSecrets in kubeaid-config:

  | Secret | Keys |
  | --- | --- |
  | `s3.existingSecret` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
  | `recoveryAdmin.existingSecret` | `STALWART_RECOVERY_ADMIN` = `admin:<password>` |
  | `plan.existingSecret` | `STALWART_USER` + `STALWART_PASSWORD`, or `STALWART_TOKEN` (API key) |

  One Secret can hold all three admin keys, and both settings can point at it.
- Egress from the pods to:
  - `github.com`: the WebUI bundle is downloaded at startup.
  - The Keycloak issuer.
  - The S3 endpoint.
  - Outbound SMTP on port 25.

## Keycloak

Create a **public** client for the WebUI. Keycloak has no Client ID Metadata Document support, so
Stalwart uses a static client id.

1. Create a client with Client ID `stalwart-webui` (`oidc.webuiClientId`):
   - Set **Client authentication** to off.
   - Under **Standard flow**, turn it on.
2. Set **Valid redirect URIs** to:
   - `https://<hostname>/admin/oauth/callback`
   - `https://<hostname>/account/oauth/callback`
3. Under Advanced, set **Proof Key for Code Exchange Code Challenge Method** to `S256`.
4. Add an audience mapper. In client scopes, open `stalwart-webui-dedicated` → Add mapper → By
   configuration → **Audience**:
   - Set Included Client Audience to `stalwart-webui`.
   - Turn **Add to access token** on.

   Stalwart rejects tokens whose `aud` does not match `acceptedAudiences`.
5. Create the client scope that the WebUI requests. Without it, Keycloak rejects the login with
   `Invalid scopes: openid email urn:stalwart:oauth:scope:full`.
   - In Client scopes → Create client scope, set Name to `urn:stalwart:oauth:scope:full` (exactly),
     Type to None, Protocol to OpenID Connect, and turn **Include in token scope** on.
   - On the `stalwart-webui` client, add it as an **Optional** client scope.

   Keep this scope on `stalwart-webui` only. Never make it a realm default: a token carrying it gets
   the account's full permissions, which for an administrator includes managing the server.
6. Optional: add a **Group Membership** mapper with token claim `groups` and Full group path off.
   Then set `oidc.claimGroups: groups`.

Accounts are created on the first Keycloak login. Mail for an address that has never logged in is
rejected until the account exists. Pre-create mailboxes with `plan.extra`, using `Account` upserts.

Mail apps such as Thunderbird and phones cannot obtain Keycloak tokens themselves. Users sign in to
`https://<hostname>/account` through Keycloak and create an **app password** for IMAP and SMTP.

## Rollout

1. Prepare the secrets and the bucket, and set the values. Example for kcm:

   ```yaml
   hostname: mail.obmondo.com
   domains: [obmondo.com]
   recoveryAdmin: {existingSecret: stalwart-admin}
   plan: {existingSecret: stalwart-admin}
   s3:
     bucket: stalwart-kcm
     endpoint: https://bucket.obmondo.com
     existingSecret: stalwart-s3
   oidc:
     enabled: true
     issuerUrl: https://<keycloak>/realms/<realm>
     usernameDomain: obmondo.com
   ingress: {className: traefik}
   ```

2. Sync with `replicaCount: 1`. The PostSync Job applies the plan. Check it with
   `kubectl logs job/stalwart-plan`.
3. Restart once so that the new in-memory store, coordinator and blob store take effect:
   `kubectl rollout restart sts/stalwart`.
4. Set `replicaCount: 2` and sync. Every pod reads the same configuration from PostgreSQL. Check
   that they coordinate: `redis-cli PUBSUB NUMSUB stwt.agora` should equal the replica count.
5. Publish DNS: MX, SPF, DKIM (the WebUI shows the records per domain), DMARC, and the PTR of the
   LoadBalancer IP.
6. Create a permanent admin, or an API key for `plan.existingSecret`. Then drop
   `STALWART_RECOVERY_ADMIN` from the secret, because Stalwart discourages keeping it on
   production.

Do not raise `replicaCount` above 1 before step 3. Pods that start before the shared stores exist
would each run with local in-memory state.

## Client IP behind the LoadBalancer

SPF checks, DNSBLs and rate limiting need the real client IP. `externalTrafficPolicy: Local`
preserves it with MetalLB, and with any LoadBalancer that forwards packets without proxying them.

Behind a proxying load balancer, such as the Hetzner Cloud LB, enable PROXY protocol on the load
balancer. Also enable it on Stalwart's listeners through a `Listener` upsert in `plan.extra`.

## Verified

The plan this chart renders was tested against Stalwart v1.1.1 with stalwart-cli 2.0.0. The test
used two nodes on PostgreSQL 17, Redis 7.2 and RustFS 1.0.0. Results:

- **Apply:** the plan applies cleanly, and re-applying creates no duplicates.
- **Coordination:** both nodes subscribe to the coordination channel.
- **Delivery:** mail received on one node is stored, with its blob in S3.
- **Reload:** a TLS reload issued on one node takes effect on the other.

The OIDC directory was **not** tested against a live Keycloak. The first real login is the
remaining check.
