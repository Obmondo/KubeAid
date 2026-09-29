# kubeSoc

A multi-tenant security operations centre for KubeAid clusters: one central stack that several
tenants are watched from, and one Wazuh per tenant that only ever sees its own data.

Everything in this directory belongs to that stack. The charts stay usable on their own, but
they are written to be deployed together through `security-operations`.

## The charts

| Chart | Role |
|---|---|
| [`security-operations`](security-operations/README.md) | **The umbrella.** The central side as one release in one namespace, configured for every tenant from one `tenants` list. Pulls in the six charts below as subcharts. |
| [`wazuh`](wazuh/README.md) | SIEM. Deployed twice over: once inside the umbrella as the *central search* (indexer + dashboard, no manager), and once **per tenant** as a full manager + indexer + dashboard in `wazuh-<code>`. |
| [`velociraptor`](velociraptor/README.md) | Endpoint forensics and response, one org per tenant. |
| [`dfir-iris`](dfir-iris/README.md) | Case management, one customer per tenant. PostgreSQL and RabbitMQ come from `kubeaid-addons`. |
| [`misp`](misp/README.md) | Threat intelligence. Feeds every tenant's Wazuh as CDB lists. |
| [`ollama`](ollama/README.md) | Local model (default `mistral:7b`) behind the advisory AI assistant in IRIS. |
| [`kubesoc-content`](kubesoc-content/README.md) | Detection content as code — Wazuh rules, decoders and lists, Velociraptor artifacts, AI prompts — rolled out by the reconciler. Off by default. |
| [`kubesoc-portal`](kubesoc-portal/README.md) | Optional SSO landing page with per-tenant links. Off by default. |

The six component charts are symlinked into `security-operations/charts/`, so the umbrella
renders them from this directory rather than from a registry. `misp` and `dfir-iris` also
symlink `../../../kubeaid-addons`, which lives outside this group.

Each component can be switched off with `<component>.enabled: false`.

## Tenancy model

**Every tenant has its own Wazuh.** An agent can only enrol with and send to its own tenant's
manager, and a tenant's indexer only holds that tenant's data. The central Wazuh in the
umbrella runs no manager at all — it is a search head that reaches every tenant indexer over
cross-cluster search.

So a cluster ends up with:

```
security-operations/          the umbrella release: central search, IRIS, MISP,
                              Velociraptor, Ollama, reconciler, portal
wazuh-001/                    tenant 001: manager + indexer + dashboard
wazuh-002/                    tenant 002: manager + indexer + dashboard
...
```

The umbrella creates the tenant namespaces and all the central wiring into them. The tenant
releases themselves are separate Argo CD Applications deployed next to it.

## Before you deploy

- **cert-manager**, for the shared SOC CA that fronts cross-cluster search.
- **Keycloak**, with a realm every component logs in through. The default is the KubeAid
  `keycloakx` release.
- **A sealed-secrets controller**, because every credential reaches the cluster as a
  SealedSecret.
- **`agentAddress` routed to a node** (a failover or floating IP), and **`agentHost`
  resolving to it**. This is the address agents dial; nothing else can arrange it.
- For the `ha` profile only: a **ReadWriteMany** storage class, and at least as many failure
  domains as replicas.

## Deploying it

### With kubeaid-cli (the supported path)

One block in `general.yaml` drives the whole stack — the umbrella, one Wazuh release per
tenant, and the sealed credentials for all of them:

```yaml
cluster:
  securityOperations:
    enabled: true
    domain: example.com
    keycloak:
      url: https://keycloak.example.com/auth
      realm: soc
    agentHost: agents.example.com
    agentAddress: 192.0.2.10
    profile: standard          # single | standard | ha
    tenants:
      - code: "001"
        name: Tenant A
      - code: "002"
        name: Tenant B
```

Then render the Applications, values and sealed Secrets into a kubeaid-config checkout:

```sh
kubeaid-cli siem render \
  --cluster-dir ~/src/kubeaid-config/k8s/<cluster> \
  --sealed-secrets-cert ./sealed-secrets.pem
```

It writes only the SIEM files and prints them; it runs no git operation, so review the diff,
commit and push yourself. Argo CD does the rest.

Passwords live only inside the sealed Secrets — the rendered values carry their bcrypt hashes.
A release that is already rendered is left exactly as it is, and nothing is rotated silently:
if a sealed file or hash is missing the render stops and tells you what, rather than quietly
issuing new credentials. Rotate on purpose with `--rotate=wazuh-001` (a bare `--rotate` does
every release).

The full config reference — every key, the deployment profiles, backups, and the sealed-secret
migration — is `docs/security-operations.md` in the kubeaid-cli repository.

### By hand

Deploy `security-operations` as one Argo CD Application with destination namespace
`security-operations` and `CreateNamespace=true`, then one `wazuh` release per tenant in
`wazuh-<code>` (see the wazuh chart README, section 11). Minimal central values:

```yaml
domain: example.com
keycloak:
  url: https://keycloak.example.com/auth
  realm: soc
tenantWazuh:
  agentHost: agents.example.com
tenants:
  - code: "001"
    name: Tenant A
    agentPorts: {registration: 20015, events: 20014}
  - code: "002"
    name: Tenant B
    retentionDays: 90
    agentPorts: {registration: 20025, events: 20024}
```

Ingress hosts, SSO, storage and each component's Secrets are set in the component blocks
exactly as for the standalone charts, one level down: `wazuh.wazuh...`,
`velociraptor.velociraptor...`, `dfir-iris...`, `misp.misp...`, `ollama.ollama...`.

### Order

The Applications carry `argocd.argoproj.io/sync-wave` **60** for `security-operations` and
**61** for each `wazuh-<code>`, under the root Application. Argo CD only waits for a wave's
health if the Application health check is enabled in `argocd-cm`
(`resource.customizations.health.argoproj.io_Application`); without it the waves order the
applies but do not gate on readiness.

Sync stays manual unless you ask for automation:

```yaml
sync:
  automated: false
  prune: false
```

SealedSecrets and tenant namespaces are never pruned regardless.

## What stays manual

- **OIDC client Secrets.** The siem-reconciler creates the Keycloak clients and their Secrets
  (`wazuh-dashboard-oidc` in every Wazuh namespace, `dfir-iris-oidc`, `velociraptor-oidc`,
  `oidc-credentials`). With the reconciler off, create them by hand — the Wazuh indexer and
  dashboard pods block until `wazuh-dashboard-oidc` exists. MISP's `oidc-credentials` needs
  its `username` key set by hand either way.
- **Keycloak reachability.** Indexers and dashboards are allowed TCP 443/8443 into the
  `traefik` namespace, which covers a Keycloak behind the ingress controller in the same
  cluster. A Keycloak anywhere else needs its own egress rules; Velociraptor has
  `oidcEgressCIDRs`.
- **MISP → Wazuh CDB export** ships off (`misp.wazuhCdbExport.enabled`); its targets are
  rendered for you.
- **Backups** stay off until a bucket exists.

## Tests

Each chart carries its own tests; CI runs them from
[`.github/workflows/kubesoc-content.yml`](../../.github/workflows/kubesoc-content.yml).

```sh
# render tests (helm only)
argocd-helm-charts/kubesoc/security-operations/tests/render_test.sh
argocd-helm-charts/kubesoc/wazuh/tests/tenant_render_test.sh
argocd-helm-charts/kubesoc/wazuh/tests/hardening_render_test.sh
argocd-helm-charts/kubesoc/kubesoc-content/tests/render_test.sh

# content: XML, lists and fixture shape
argocd-helm-charts/kubesoc/kubesoc-content/tests/lint.sh

# detection rules replayed through a real Wazuh manager (needs docker)
argocd-helm-charts/kubesoc/kubesoc-content/tests/logtest.sh

# Velociraptor artifacts parsed by a real Velociraptor (needs docker)
argocd-helm-charts/kubesoc/kubesoc-content/tests/velociraptor_verify.sh

# the Python helpers
pytest argocd-helm-charts/kubesoc/{misp,wazuh,dfir-iris}/tests
```

None of these talk to a cluster — they render and parse only.
