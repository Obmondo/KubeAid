# security-operations

The central side of a multi-tenant security operations stack, as one Helm release in one
namespace, configured for several tenants from one list:

| Component | Chart | Role |
|---|---|---|
| Wazuh (central search) | `../wazuh` | Indexer without events + dashboard, no manager: searches every tenant's Wazuh with cross-cluster search |
| Velociraptor | `../velociraptor` | Endpoint forensics and response, one org per tenant |
| DFIR-IRIS | `../dfir-iris` | Case management, one customer per tenant; PostgreSQL and RabbitMQ through kubeaid-addons |
| MISP | `../misp` | Threat intelligence, fed into every tenant's Wazuh as CDB lists |
| Ollama | `../ollama` | Local model for advisory alert triage in IRIS |

**Every tenant has its own Wazuh** (manager, indexer, dashboard): a separate release of the
`wazuh` chart in the tenant's namespace, see the wazuh chart README, section 11. An agent can
only enrol with and send to its own tenant's manager, and an indexer only holds one tenant's
data. This chart creates the tenant namespaces and all the central wiring to them; the
tenant releases are deployed next to it (kubeaid-cli renders one Argo CD Application per
tenant).

The components are the KubeAid wrapper charts next to this one, symlinked into `charts/`.
They stay usable on their own. Each can be switched off with `<component>.enabled: false`.

Deploy it as one Argo CD Application with destination namespace `security-operations` and
`CreateNamespace=true`. cert-manager must be installed (shared CA, section 5).

## 1. Minimal values

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

Ingress hosts, SSO settings, storage and the Secrets each component expects are set in the
component blocks exactly as for the standalone charts (see their READMEs), one level down:
`wazuh.wazuh...`, `velociraptor.velociraptor...`, `dfir-iris...`, `misp.misp...`,
`ollama.ollama...`.

## 2. Values reference

| Key | Default | Meaning |
|---|---|---|
| `domain` | `example.com` | Base domain; hostnames default to `<component>.<domain>` |
| `hosts.{wazuh,iris,misp,velociraptor}` | `""` | Override one hostname (`wazuh` = central search). Used for OIDC redirect URIs and alert links, not for the ingresses |
| `keycloak.url`, `keycloak.realm` | | Realm every component logs in through, as the reconciler reaches it |
| `keycloak.adminUsername`, `keycloak.adminSecretRef` | `admin`, `keycloakx/keycloak-admin/KEYCLOAK_PASSWORD` | Admin login the reconciler reads (the KubeAid keycloakx default) |
| `keycloak.bruteForceProtected`, `.otpPolicy`, `.requireTOTP`, `.mfaFlow` | on, TOTP, on, `browser-mfa` | Realm policy the reconciler enforces; remove a key to leave it alone |
| `keycloak.clients` | `[]` | OIDC clients for the reconciler; empty derives one per enabled component, one per tenant dashboard, plus `iris-sync` |
| `operators.adminRole`, `.analystRole` | `administrator`, `analyst` | Realm roles of the central team; they see every tenant |
| `operators.analystGroup` | `soc-analysts` | Group that grants the analyst role (reconciler) |
| `toolRoles.iris.{admin,analyst,tenant}` | `Administrators`, `Analysts`, `Analysts` | IRIS groups each kind of user gets |
| `toolRoles.velociraptor.{admin,analyst,tenant}` | `administrator`, `investigator`, `investigator` | Velociraptor roles |
| `tenants` | `[]` | `code`, `name`, optional `retentionDays`, `idp`, `agentPorts` |
| `tenantGroupPrefix` | `tenant-` | Keycloak group and realm role of a tenant: `<prefix><code>` |
| `tenantWazuh.namespacePrefix` | `wazuh-` | Tenant namespace `<prefix><code>`, created here |
| `tenantWazuh.namespaceLabel` | `security-operations.kubeaid.io/tenant` | Label (value: code) on tenant namespaces, for network policies |
| `tenantWazuh.hostPrefix` | `wazuh-` | Tenant dashboard host `<prefix><code>.<domain>` |
| `tenantWazuh.agentHost` | `""` | Public host the agents dial, for the enrolment bundles |
| `tenantWazuh.agentVersion` | `4.14.3-1` | Agent package in the bundles' install commands; not newer than the managers |
| `tenantWazuh.{apiCredSecret,authdSecret}` | `wazuh-api-cred`, `wazuh-authd-pass` | Secrets in each tenant namespace the reconciler reads |
| `tenantWazuh.{managerService,indexerNodesService}` | `wazuh`, `wazuh-indexer-nodes` | Service names of a tenant release (`fullnameOverride: wazuh`) |
| `socCA.*` | enabled, `soc-ca` in `cert-manager` | CA ClusterIssuer every Wazuh instance uses |
| `defaultRetentionDays` | `365` | Alert retention when a tenant sets none |
| `checks.mispTargets` | `true` | Fail the render when the MISP export lacks a tenant's manager |
| `ai.irisLogin`, `ai.irisGroups`, `ai.irisKeySecret` | `svc_ai`, `[Analysts]`, `iris-ai-triage` | IRIS service account of the triage job; the reconciler creates it, gives it these groups and every tenant as customer, and keeps its API key in that Secret (key `IRIS_API_KEY`, read by `dfir-iris.aiTriage.existingSecret`). Turn the job on with `dfir-iris.aiTriage.enabled` |
| `publicIngress.velociraptorHost` | `""` | Hostname Velociraptor clients dial |
| `reconciler.*` | disabled | Section 6; `reconciler.secrets` and `reconciler.components` override what goes into `siem-tenants` |
| `reconciler.imagePullSecrets` | `[]` | Pull secrets (`[{name: ...}]`) for a private registry, in the release namespace |
| `reconciler.hostAliases` | `[]` | Host name pins for the reconciler pod (e.g. an internal-only Keycloak) |
| `velociraptorArtifacts.extraFiles` | `{}` | More Velociraptor artifact files (name -> YAML); `null` drops a shipped one (section 6) |
| `velociraptorArtifacts.monitoring` | IrisCollector, KeycloakSync | Server event artifacts the reconciler keeps running, with the parameters it enforces |
| `wazuh`, `velociraptor`, `dfir-iris`, `misp`, `ollama` | see values.yaml | Passed to the component charts |

`tenants[].code` must match `^[a-z0-9]{1,32}$` and be unique; `name` must be unique. The code
is the suffix of the tenant's namespace, dashboard host and cross-cluster search alias
(`<code>:wazuh-alerts-*`). `values.schema.json` checks the format, the templates check
uniqueness, namespace length and that no agent port is used twice.

## 3. Onboarding a tenant

1. Add an entry to `tenants` (with `agentPorts` for an enrolment bundle).
2. Deploy the tenant's Wazuh release into `<namespacePrefix><code>` (wazuh chart README,
   section 11): its own credentials Secrets, `certificates.issuer` = the SOC CA, the central
   indexer DN in `indexer.config.extraNodesDn`, the fixed IRIS customer. kubeaid-cli renders it.
3. Add the tenant's manager to `misp.wazuhCdbExport.targets` when the export is on.
4. Sync. With the reconciler, the Keycloak group, role and dashboard client, the IRIS
   customer, the Velociraptor org, the manager's API role mappings, the cross-cluster search
   remote, the central dashboard's API list and the enrolment bundle follow on the PostSync
   run. Without it, do the same by hand with the names in the `siem-tenants` ConfigMap.
5. Install agents with the tenant's enrolment bundle (Secret `enrolment-bundle` in the tenant
   namespace) and give them the tenant's Velociraptor client config.

## 4. What is rendered from `tenants`

| Object | Consumer |
|---|---|
| Namespace `<namespacePrefix><code>`, labelled, never pruned | the tenant's Wazuh release |
| Role/RoleBinding in each tenant namespace (with the reconciler) | the reconciler: Secrets there |
| ConfigMap `dfir-iris-tenants` (`mapping.json`) | IRIS `keycloakSync`: operators see every customer, a tenant group its own |
| ConfigMap `velociraptor-tenants` (`group-map.json`, `role-map.json`, `org-map.json`) | Velociraptor server artifacts, `/etc/siem` |
| ConfigMap `siem-tenants` (`tenants.json`) | the reconciler, in the schema of kubeaid-cli `pkg/siem/config` (unknown fields are rejected there): per-tenant manager APIs, cross-cluster search remotes, dashboard clients, enrolment bundles, Secret copies |

Removing a tenant from the list does not delete its namespace or data; delete the namespace
by hand when the data may go.

## 5. Central Wazuh search

The `wazuh` component runs without a manager (`wazuh.wazuh.wazuh.{enabled,master.enabled,worker.enabled}: false`):

- **Indexer** holds no events. The reconciler registers every tenant indexer as a remote
  cluster (`PUT _cluster/settings`, `cluster.remote.<code>.seeds`); index patterns
  `*:wazuh-alerts-*`, `*:wazuh-states-vulnerabilities-*` and `*:wazuh-states-inventory-*` then
  search every tenant, `<code>:wazuh-alerts-*` one.
- **Trust**: all Wazuh instances get their certificates from the ClusterIssuer `socCA.name`
  (`certificates.issuer`). The central node DN is `CN=wazuh-indexer,O=central,...`; each tenant
  indexer admits it in `indexer.config.extraNodesDn`, and its NetworkPolicy admits 9300 from this
  namespace.
- **Permissions** of a central user are checked on every tenant cluster, so the operator roles
  need role mappings on the tenant indexers as well as here.
- **Index patterns**: the reconciler keeps `centralSearch.indexPatterns` (default
  `*:wazuh-alerts-*`, the default index) in the dashboard's saved objects; the Wazuh app
  does not create cross-cluster patterns itself.
- **Dashboard**: the Wazuh app lists every tenant manager API from Secret `wazuh-app-config`
  (`dashboard.wazuhAppConfigSecret`), which the reconciler writes from the tenants' API
  logins. The dashboard waits for it on first start.
- **Credentials**: set `wazuh.wazuh.indexer.cred` and `.dashboard.cred` (`existingSecret` +
  `passwordHash`); the chart defaults are public.

## 6. Reconciler

`reconciler.enabled` adds a CronJob (every 10 minutes), an Argo CD Sync hook Job that runs
before the components (sync wave -1, after the reconciler's RBAC and input at -2, so the
Secrets and Keycloak clients the components need exist when they start), and a PostSync Job, all running
`ghcr.io/obmondo/siem-reconciler` with `--config /etc/siem/tenants.json --dry-run=<reconciler.dryRun>`,
a ServiceAccount that manages Secrets in the release namespace and in each tenant namespace,
and a Role in Keycloak's namespace that can read only `keycloak.adminSecretRef`. It sets up
what has only an API: Keycloak roles, groups, clients and flows; IRIS customers; Velociraptor
orgs; each tenant manager's API role mappings; the central search's remote clusters and
dashboard API list. It creates missing Secrets and never changes their values (OIDC client
secrets with the client id beside them, API keys; the MISP client Secret `oidc-credentials`
still needs its `username` key set by hand), keeps copies in step (the IRIS API key into
every tenant namespace, every tenant's API login here as `wazuh-api-cred-<code>` for the MISP
export) and writes the per-tenant enrolment bundles. It never changes users; the IRIS and
Velociraptor Keycloak syncs own those. Start with `dryRun: true` and read the job log. It is
off by default until the image is published; `siem-tenants` renders either way. The hook Jobs
pass `--exit-zero`: objects that cannot be reconciled yet (a component still starting) are
reported without failing the sync; the CronJob stays strict.

### Velociraptor API and server artifacts

The reconciler creates one Velociraptor org per tenant (named after the tenant) and keeps the
server monitoring table through Velociraptor's gRPC API:

- **API**: `velociraptor.velociraptor.config.overlayExtra` binds the API to `0.0.0.0`, the
  `velociraptor-api` Service exposes port 8001 and `networkPolicy.apiAllowedFrom` admits the
  reconciler pods. The reconciler dials `velociraptor-api:8001` (`components.velociraptor.address`
  in `siem-tenants`; the api_client file itself names `localhost`) and checks the server
  certificate against its pinned name, so the Service name is not in the certificate.
- **API client**: with `velociraptor.velociraptor.apiClient.enabled`, two init containers in the
  Velociraptor pod mint the reconciler's api_client (user `siem-reconciler`, role
  `administrator`) with the server's own config and datastore, and store it in Secret
  `velociraptor-api-client` with `siem-reconciler publish-api-client`. This chart grants the
  `velociraptor` ServiceAccount `get`/`update`/`patch` on that Secret and `create` on Secrets
  (`create` cannot be limited by name); only the publisher container mounts a token, and a
  CiliumNetworkPolicy (`velociraptor.apiServerEgress`) lets it reach the Kubernetes API. It is
  off by default like the reconciler: set `apiClient.publisherImage` to `reconciler.image` and
  `apiClient.imagePullSecrets` to its pull secrets (the render fails while both are enabled
  with different images). Every Velociraptor restart mints a new certificate.
- **Artifacts**: `files/velociraptor/*.yaml` are rendered into ConfigMap
  `velociraptor-artifacts`, which the server loads at start (`customArtifacts.existingConfigMap`).
  They are chart files rather than inline values so they stay plain artifact YAML that
  `velociraptor artifacts verify` can check, without a copy in `values.yaml`. Velociraptor reads
  artifacts only when it starts and the subchart cannot hash a ConfigMap it does not render,
  so the pod annotation `checksum/server-artifacts` in `velociraptor.velociraptor.podAnnotations`
  carries their checksum; `templates/checks.yaml` fails the render with the new value when an
  artifact (or `velociraptorArtifacts.extraFiles`) changes.
  - `Custom.Server.IrisCollector`: an IRIS asset tagged `velociraptor:collect[:Artifact]` runs
    that client artifact on the endpoint of the same host name, in the org of the case's
    customer only, and the results land on the case timeline; New alerts whose rule is in
    `AutoRules` are escalated and answered the same way. Reads the IRIS API key from
    `/etc/iris/API_KEY` (Secret `iris-api-key`) and the customer to org map from
    `/etc/siem/org-map.json`. `AllowedArtifacts` limits what a tag may run.
  - `Custom.Server.KeycloakSync`: Keycloak users become Velociraptor users with the grants
    of `/etc/siem/role-map.json` (operators, every org) and `/etc/siem/group-map.json` (a
    tenant group, its own org); users that lose them are removed from the orgs. It logs in
    with the `iris-sync` client (`/etc/keycloak/client_secret` from Secret
    `iris-keycloak-sync`) at `keycloak.url` (override `KcUrl` in
    `velociraptorArtifacts.monitoring` when Velociraptor reaches Keycloak by another URL, and
    allow that egress). A cycle changes nothing unless every Keycloak read and both maps
    succeeded. Users matching `Protected` (local accounts and the reconciler's API user
    `siem-reconciler`, which has no Keycloak user) are never touched.
  - `Custom.MacOS.Remediation.RemoveByHash`: client artifact the collector runs for the
    stock Wazuh rule 99901 (a file hash from the MISP list) on macOS.

  `velociraptorArtifacts.monitoring` lists the server event artifacts the reconciler keeps in
  the monitoring table and the parameters it sets (KeycloakSync runs with `DryRun: "N"`);
  unlisted parameters keep their value in the table or the artifact default.

## 7. Wiring

The defaults in `values.yaml` connect the components through Service names and pod
selectors: Velociraptor to IRIS, IRIS triage to Ollama (`http://ollama:11434`), the central
indexer to the tenant indexers (9300) and the central dashboard to the tenant managers
(55000) in namespaces carrying `tenantWazuh.namespaceLabel`. The tenant managers reach IRIS
(`http://dfir-iris-app.<release namespace>.svc:8000`) and MISP across namespaces; their
NetworkPolicies are in the tenant releases. Every `fullnameOverride` keeps the names a
standalone install has, and `misp.kubeaid-addons` is off so `iris-pgsql` and
`iris-rabbitmq` render once.

Helm replaces lists instead of merging them. When you set one of the lists in
`values.yaml` (volumes, mounts, NetworkPolicy rules), copy the default entries you want to
keep. The central NetworkPolicies repeat the tenant namespace label key; change both
together.

## 8. What is not derived from `tenants`

A parent chart cannot compute its subcharts' values, so these need one entry per tenant:

- **MISP export targets**: `misp.wazuhCdbExport.targets` (checked by `checks.mispTargets`).
- **The tenant Wazuh releases** themselves (section 3).
- **Velociraptor artifacts** of your own (`velociraptorArtifacts.extraFiles`). The shipped
  ones read the tenant maps from `/etc/siem` on every cycle (section 6), so they need nothing
  per tenant. To do the same, give each map parameter a file parameter and read the file when
  it is set:

  ```yaml
  - name: GroupMapFile
    default: /etc/siem/group-map.json
  ```
  ```sql
  LET GMAP = parse_json(data=if(condition=GroupMapFile,
                                then=read_file(filename=GroupMapFile), else=GroupMap))
  ```

## 9. Limitations and TODO

- The Velociraptor API client bootstrap needs the reconciler image with `publish-api-client`,
  and its image is set twice (`reconciler.image`, `velociraptor.velociraptor.apiClient.publisherImage`).
- The Kubernetes API egress of the Velociraptor pod is a CiliumNetworkPolicy; on another CNI
  add an equivalent rule to `velociraptor.velociraptor.networkPolicy.extraEgress`.
- The MISP to Wazuh CDB export stays off (`misp.wazuhCdbExport.enabled`) until the list
  registration and rules are in the tenant releases (misp README, section 5).
- kubeaid-addons' Cilium policies for RabbitMQ and Celery select on
  `app.kubernetes.io/instance` alone; in one release that matches every component, so keep
  `dfir-iris.global.netpol` off here.
- Wazuh correlation rules see one tenant at a time; correlation across tenants is a search on
  the central dashboard or work in IRIS.

## 10. Tests

`tests/render_test.sh` (helm, yq, jq, python3; no cluster) renders the chart with a generic
2-tenant and 3-tenant fixture and checks object uniqueness, namespaces, names, that no
manager runs centrally, selectors, that tenant `003` adds only its own entries, the
reconciler input, input validation, the reconciler objects, and the Velociraptor API, API
client bootstrap and shipped artifacts. The tenant side is covered by
`../wazuh/tests/tenant_render_test.sh`.
