# kubesoc-portal

Landing page for a kubesoc SOC: one page behind Keycloak single sign-on with a card per
tenant, linking to that tenant's Wazuh dashboard, DFIR-IRIS (alerts filtered by customer),
Velociraptor (the tenant's org), MISP and the central search, plus the shared SOC tools.
KubeAid-authored, no upstream chart.

- **nginx** (`nginxinc/nginx-unprivileged`, non-root, read-only root filesystem, `/tmp` on
  an emptyDir) serves a static page (`files/`) and `/links.json`. Behind oauth2-proxy it
  listens on `127.0.0.1:8080` only, so nothing reaches the page without a login.
- **oauth2-proxy** (`keycloak-oidc` provider, PKCE) in the same pod handles the login and
  is what the Service and Ingress point at (port 4180).
- The page shows a user the tenants whose Keycloak realm role or group is in their
  `/oauth2/userinfo` groups (`role:<name>` for realm roles), and every tenant to
  `operatorRoles`. That is convenience, not access control: every tool checks access
  itself, and the links are not secret.
- The page script builds the DOM from text only (no HTML parsing), drops non-http(s)
  links, and nginx sends a strict Content-Security-Policy (`script-src 'self'`,
  `frame-ancestors 'none'`), `nosniff` and `no-referrer`.

## 1. With the security-operations umbrella

Set `kubesoc-portal.enabled: true` there. The umbrella renders the links from its
`tenants` list into ConfigMap `kubesoc-portal-links` and the reconciler keeps the
Keycloak client `kubesoc-portal` (redirect `https://<portal host>/oauth2/callback`,
audience and group mappers) and Secret `kubesoc-portal-oidc` (`client-secret`,
`cookie-secret`). See the umbrella README, "Landing portal".

## 2. Standalone

```yaml
oauth2Proxy:
  oidcIssuerUrl: https://keycloak.example.com/auth/realms/soc
  existingSecret: kubesoc-portal-oidc   # keys client-secret, cookie-secret (32 chars)
  allowedRoles: []                      # e.g. [analyst, tenant-001]
ingress:
  className: nginx
  host: portal.example.com
  tls:
    - secretName: portal-tls
      hosts: [portal.example.com]
links:
  central:
    - {name: DFIR-IRIS, url: "https://iris.example.com/", description: Cases and alerts}
  tenants:
    - code: "001"
      name: Tenant A
      roles: [tenant-001]
      links:
        - {name: Wazuh dashboard, url: "https://wazuh-001.example.com/app/wz-home"}
  operatorRoles: [administrator, analyst]
```

Keycloak client: confidential, standard flow, redirect URI
`https://portal.example.com/oauth2/callback`, an *Audience* mapper for the client id
(oauth2-proxy checks it) and the `roles` client scope.

## 3. Forward auth at the ingress instead

`oauth2Proxy.enabled: false` drops the sidecar; nginx then listens on `0.0.0.0:8080` and
the Ingress must authenticate, e.g. a Traefik `ForwardAuth` middleware or ingress-nginx
`auth-url`/`auth-signin` annotations pointing at a shared oauth2-proxy. Without
`/oauth2/userinfo` the page shows every tenant (the tools still enforce access).

## 4. Network flows

- Ingress controller -> pod TCP 4180 (8080 with forward auth).
- oauth2-proxy -> Keycloak (the issuer URL, usually TCP 443 through the ingress), plus DNS.
- nginx needs no egress.

## 5. Tests

`tests/render_test.sh` (helm, yq, jq; node for `tests/app_test.js`, which runs the page
script against a fake DOM).
