# security-operations

The central side of a multi-tenant security operations stack, as one Helm release in one
namespace, configured for several tenants from one list:

| Component | Chart | Role |
|---|---|---|
| Wazuh (central search) | `../wazuh` | Indexer without events + dashboard, no manager: searches every tenant's Wazuh with cross-cluster search |
| Velociraptor | `../velociraptor` | Endpoint forensics and response, one org per tenant |
| DFIR-IRIS | `../dfir-iris` | Case management, one customer per tenant; PostgreSQL and RabbitMQ through kubeaid-addons |
| MISP | `../misp` | Threat intelligence, fed into every tenant's Wazuh as CDB lists |
| Ollama | `../ollama` | Local model (default `mistral:7b`) for the advisory AI assistant in IRIS: alert triage, case summaries, hunting suggestions |
| kubesoc portal | `../kubesoc-portal` | Optional SSO landing page with per-tenant links (`kubesoc-portal.enabled`) |

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
| `tenantWazuh.managerTlsSecret` | `wazuh-manager-tls` | Secret of a tenant manager's certificate (`wazuh.managerTls`); its `ca.crt` goes into the enrolment bundle |
| `tenantWazuh.{managerService,indexerNodesService}` | `wazuh`, `wazuh-indexer-nodes` | Service names of a tenant release (`fullnameOverride: wazuh`) |
| `socCA.*` | enabled, `soc-ca` in `cert-manager` | CA ClusterIssuer every Wazuh instance uses |
| `socCA.approverPolicy.enabled` | `false` | approver-policy CertificateRequestPolicies restricting `soc-ca` (section 5); needs cluster prerequisites |
| `socCA.approverPolicy.{clusterDomain,maxDuration,certManagerServiceAccount}` | `cluster.local`, `2160h`, `cert-manager/cert-manager` | DNS suffix of the allowed names, longest certificate, the requester the policies are bound to |
| `socCA.trustSecret` | `soc-ca-trust` | Certificate from the CA in this namespace; its `ca.crt` is what the reconciler and the MISP export verify against |
| `tls.caSecret`, `tls.insecureSkipVerify` | `""` (= `socCA.trustSecret`), `false` | CA the reconciler verifies the tenant managers and the central indexer with; the explicit opt-out (section 7) |
| `networkPolicies.*` | enabled, Cilium | Default deny in this namespace and one policy per workload; peers for the ingress controller, Keycloak, Prometheus, operators (section 7) |
| `defaultRetentionDays` | `365` | Alert retention when a tenant sets none |
| `defaultRetentionDays` | `365` | Alert retention when a tenant sets none (section 6, Retention) |
| `retention.*` | enabled, `kubesoc-retention`, central 90 days | ISM policies the reconciler keeps on every indexer (section 6, Retention) |
| `tenantWazuh.{indexerService,indexerCredSecret}` | `wazuh-indexer`, `wazuh-indexer-cred` | Tenant indexer REST Service and admin Secret, for retention and health probes |
| `monitoring.serviceMonitor.*`, `monitoring.prometheusRule.*` | off | ServiceMonitor and PrometheusRule of the platform (section 6, Monitoring) |
| `checks.mispTargets` | `true` | Fail the render when the MISP export lacks a tenant's manager |
| `ai.irisLogin`, `ai.irisGroups`, `ai.irisKeySecret` | `svc_ai`, `[Analysts]`, `iris-ai-triage` | IRIS service account of the triage job; the reconciler creates it, gives it these groups and every tenant as customer, and keeps its API key in that Secret (key `IRIS_API_KEY`, read by `dfir-iris.aiTriage.existingSecret`). Turn the job on with `dfir-iris.aiTriage.enabled` |
| `publicIngress.velociraptorHost` | `""` | Hostname Velociraptor clients dial |
| `reconciler.*` | disabled | Section 6; `reconciler.secrets` and `reconciler.components` override what goes into `siem-tenants` |
| `reconciler.imagePullSecrets` | `[]` | Pull secrets (`[{name: ...}]`) for a private registry, in the release namespace |
| `reconciler.hostAliases` | `[]` | Host name pins for the reconciler pod (e.g. an internal-only Keycloak) |
| `reconciler.mode`, `.interval`, `.metricsPort` | `cronjob`, `5m`, `9090` | `deployment` runs the reconciler long-running with metrics (section 6, Monitoring) |
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
  `passwordHash`); the chart defaults are public. The indexer has no other internal users
  (the upstream demo users are off, wazuh README section 8a), and with SSO on the dashboard
  login is SSO only; `wazuh.wazuh.dashboard.basicAuth.breakGlass: true` adds the
  username/password form for `admin`.

### Restricting soc-ca (`socCA.approverPolicy`)

`soc-ca` is a ClusterIssuer: by default anyone who may create a Certificate in any namespace
can get `CN=admin,O=<any tenant>` (securityadmin on that tenant's indexer) or the central
node DN `CN=wazuh-indexer,O=central,...` (a node every tenant indexer trusts) signed by it.
`socCA.approverPolicy.enabled: true` renders (`templates/soc-ca-policy.yaml`):

- one cert-manager approver-policy `CertificateRequestPolicy` per namespace that uses soc-ca:
  `<name>-central` for this namespace (organization
  `wazuh.wazuh.certificates.subject.organization`) and `<name>-tenant-<code>` for each
  tenant namespace (organization `<tenantGroupPrefix><code>`, as kubeaid-cli renders it).
  Each allows only that namespace, that organization, the common names `admin`,
  `wazuh-indexer`, `wazuh-dashboard` and `wazuh-manager`, the Wazuh Service DNS names in
  that namespace, no CA, RSA >= 2048 and at most `maxDuration`;
- `<name>-root` for the CA certificate itself (`<name>-selfsigned` issuer, `socCA.namespace`);
- a ClusterRole with `use` on those policies, bound by RoleBinding in each of those
  namespaces to the cert-manager controller's ServiceAccount.

Cluster prerequisites, which is why this is off by default:

1. [approver-policy](https://cert-manager.io/docs/policy/approval/approver-policy/) is
   installed (it brings the CRD; the sync fails without it).
2. cert-manager's default approver is disabled
   (`--controllers=*,-certificaterequests-approver` on the controller, and approver-policy
   is given the approve permission for the issuers it handles). Otherwise the default
   approver still approves every request and the policies change nothing.
3. Every other issuer in the cluster (Let's Encrypt for the ingresses, other CAs) has a
   policy of its own before step 2, or its certificates stop being issued.

A tenant release whose `certificates.subject.organization` is not `<tenantGroupPrefix><code>`
is denied; set the organization or the prefix accordingly.

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
still needs its `username` key set by hand), keeps copies in step (every tenant's API login
here as `wazuh-api-cred-<code>` for the MISP export) and writes the per-tenant enrolment
bundles. Service identities are per purpose (section 6.1). It never changes users; the IRIS and
Velociraptor Keycloak syncs own those. Start with `dryRun: true` and read the job log. It is
off by default until the image is published; `siem-tenants` renders either way. The hook Jobs
pass `--exit-zero`: objects that cannot be reconciled yet (a component still starting) are
reported without failing the sync; the CronJob stays strict.

### 6.1 Identities and API keys

Each automated caller gets its own identity with only what it needs:

| Caller | Identity | Rights | Secret |
|---|---|---|---|
| Tenant Wazuh manager, custom-iris integration (`tenantIris`) | IRIS service account `svc_wazuh_<code>` | group `Wazuh alert intake` (`alerts_write`, `customers_read`), customer = its own tenant only | `iris-api-key`/`API_KEY` in the tenant namespace |
| IRIS AI triage (`ai`) | IRIS service account `svc_ai` | `ai.irisGroups`, every tenant | `iris-ai-triage` |
| MISP IOC export (`mispReadOnly`) | MISP user `mispReadOnly.email` | role `Read Only`, admin's organisation | `misp-export-key`/`key` |
| Reconciler in Keycloak (`keycloak.reconcilerClient`) | client `siem-reconciler`, service account | `reconcilerClient.roles` of `realm-management` in the SOC realm only | `siem-reconciler-keycloak`/`KEYCLOAK_CLIENT_SECRET` |

The reconciler creates these accounts, keeps their groups/customers/roles, and keeps a
working key in the Secret: a stored key is kept only while the application accepts it *as
that account* (IRIS `/user/whoami`, MISP `/users/view/me`), otherwise a new one is generated
and stored. A tenant manager's key can add alerts to its own tenant only; it cannot read
cases, and a key taken from one tenant's manager is useless against another tenant.

`tenantIris.enabled: false` restores the old behaviour (the central `iris-api-key` copied
into every tenant namespace). `mispReadOnly.enabled: false` leaves the export on the site
admin key. `keycloak.reconcilerClient` is off by default; see the rollout below.

Rollout on an existing install, in this order:

1. Sync with the new chart and `reconciler.dryRun: true`; the job log lists the IRIS group,
   the `svc_wazuh_<code>` accounts and keys (`create`), the MISP user and key, and no more
   `iris-api-key` copies.
2. Set `dryRun: false`. The next run creates the accounts and overwrites each tenant's
   `iris-api-key` with that tenant's own key (the shared key there fails the
   `/user/whoami` check). The managers read the key file per alert, so no restart is needed.
   Check an alert per tenant arrives in IRIS; then rotate the old shared key (IRIS, Manage
   users, renew the key of its owner) since copies of it sat in every tenant namespace.
3. The MISP export picks up `misp-export-key` on its next run (log line "read-only key").
4. `keycloak.reconcilerClient.enabled: true`: the first run logs in as the admin (reported
   `keycloak login skip ... fallback`) and creates the client; the next one reports
   `keycloak login ok client siem-reconciler`. Then set `keycloak.adminSecretRef: null`,
   which also removes the reconciler's Role in Keycloak's namespace. Keep the admin
   Secret itself for Keycloak; the reconciler only needs it again to create a new realm.
5. IRIS SSO (`dfir-iris.authentication`): this chart sets `localFallback: false` and
   `oidc.mappingUsername: sub`. With `keycloakSync` enabled its next run renames the users
   it created earlier to their Keycloak id (when the IRIS e-mail matches). Set
   `localFallback: true` only for a planned break-glass login.
6. Automatic response (`IrisCollector` `AutoRules`) is now `{}`: nothing is escalated or
   run automatically. To turn it on, set it per cluster in
   `velociraptorArtifacts.monitoring.Custom.Server.IrisCollector.parameters.AutoRules`, e.g.
   `'{"99901": {"darwin": "Custom.MacOS.Remediation.RemoveByHash"}}'`. It then only acts on
   alerts created by the tenant's own `svc_wazuh_<code>` and untouched since (below).
### Retention

With `retention.enabled` (default) the reconciler keeps an index lifecycle (ISM) policy
`retention.policyId` on every tenant indexer: indices matching `retention.indexPatterns`
(default `wazuh-alerts-*`, `wazuh-archives-*`, `wazuh-monitoring-*`, `wazuh-statistics-*`)
are deleted once older than the tenant's `retentionDays` (`defaultRetentionDays` when
unset). The policy's `ism_template` attaches it to new daily indices; the reconciler also
attaches it to existing indices that have no policy and moves the indices it manages to a
changed policy (e.g. after `retentionDays` changed). Indices under another policy are
reported and left alone. `retention.warmAfterDays` adds a read-only warm state (a hook for
a later warm tier). The central indexer holds no events, only the Wazuh app's monitoring
and statistics indices, kept `retention.centralDays`. The reconciler logs in with each
tenant's `tenantWazuh.indexerCredSecret` (keys `INDEXER_USERNAME`/`INDEXER_PASSWORD`) on
`https://<indexerService>.<tenant namespace>.svc:9200`, so the tenant indexer's
NetworkPolicy must admit 9200 from the reconciler pods (wazuh README section 11; kubeaid-cli
renders it). Without that rule the retention and health objects of that tenant fail.

Lowering `retentionDays` deletes older indices on the next ISM cycle; read the dry-run log
first. Retention bounds what is kept, the volume must still hold it: the chart default of
5Gi per tenant indexer holds little. Size `wazuh.indexer.storageSize` in the tenant release
as retention days x GB per day x 1.5 (kubeaid-cli derives it from `expectedGBPerDay`). A
StatefulSet's volume template cannot change in place and a PVC never shrinks. To grow an
existing tenant's indexer volume (StorageClass with `allowVolumeExpansion`):

1. `kubectl -n wazuh-<code> patch pvc wazuh-indexer-wazuh-indexer-0 -p '{"spec":{"resources":{"requests":{"storage":"<size>"}}}}'` (every replica).
2. Set the same `storageSize` in the tenant release values.
3. `kubectl -n wazuh-<code> delete statefulset wazuh-indexer --cascade=orphan`, then sync the
   tenant Application; the new StatefulSet adopts the running pods and volumes.

### Monitoring

The reconciler has two modes. `reconciler.mode: cronjob` (default) runs every `schedule`
and exits. `deployment` runs one long-running pod (`--interval`, default `5m`) that after
each run probes the platform and serves on port `metrics` (Service
`siem-reconciler-metrics`, pods labelled `app.kubernetes.io/name: siem-reconciler`):
`/metrics` (Prometheus), `/status` (JSON: last run, last success, health snapshot, overall
`healthy`) and `/healthz`. A Deployment rather than a Pushgateway: KubeAid ships none, and
gauges such as disk usage must stay current between runs. The Sync and PostSync hook Jobs
run in both modes. Metrics (`kubesoc_` prefix): objects per component and action (`ok`,
`changed`, `skip`, `error`), runs, last run and last successful run time, run duration,
dry-run flag; per indexer (tenant code or `central`) up, cluster status and disk usage of
the fullest node; per tenant manager up, agents by status, analysisd dropped events and
queue usage; and `kubesoc_component_up` for Keycloak, IRIS and the Velociraptor API.

`monitoring.serviceMonitor.enabled` scrapes the Deployment. `monitoring.prometheusRule.enabled`
adds alerts (labels `alert_id`, `severity`): indexer red/yellow/down, disk over
`diskWarningPercent`/`diskCriticalPercent` (reconciler figure and kubelet volume stats of the
`wazuh-indexer-*` PVCs), manager down, dropped events, many disconnected agents, reconciler
errors and no successful run, component unreachable; CronJobs of the MISP CDB export, AI
triage and the reconciler (cronjob mode) failing or without success for `jobStaleSeconds`;
any failed Job and any Deployment/StatefulSet without a ready pod in the release and tenant
namespaces; Keycloak down. The kube-state-metrics and volume alerts work in both modes.
KubeAid's Prometheus only reads ServiceMonitors and rules from its configured namespaces: add
this namespace to `prometheus_scrape_namespaces`, or set `monitoring.prometheusRule.namespace`.

### Velociraptor API and server artifacts

The reconciler creates one Velociraptor org per tenant (named after the tenant) and keeps the
server monitoring table through Velociraptor's gRPC API:

- **API**: `velociraptor.velociraptor.config.overlayExtra` binds the API to `0.0.0.0`, the
  `velociraptor-api` Service exposes port 8001 and `networkPolicy.apiAllowedFrom` admits the
  reconciler pods. The reconciler dials `velociraptor-api:8001` (`components.velociraptor.address`
  in `siem-tenants`; the api_client file itself names `localhost`) and checks the server
  certificate against its pinned name, so the Service name is not in the certificate.
- **API client**: with `velociraptor.velociraptor.apiClient.enabled`, three init containers in
  the Velociraptor pod mint the reconciler's api_client (user `siem-reconciler`, role `api`),
  cut it down to `apiClient.policy` with `velociraptor acl grant` (six permissions instead of
  `administrator`, see the velociraptor chart's README section 5), and store it in Secret
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
    `AutoRules` (empty by default) are escalated and answered the same way, but only when
    every entry of the alert's IRIS `modification_history` names the login that
    `/etc/siem/alert-creators.json` maps the alert's customer to (the tenant's
    `svc_wazuh_<code>`): an alert created or edited by another tenant's key, an analyst or
    the AI account never triggers a response. IRIS 2.4 has no separate creator field
    (`alert_owner_id` is the assignee), and a user with write access to the alert can
    rewrite its history, but IRIS then appends its own entry naming that user, which fails
    the check. Reads the IRIS API key from `/etc/iris/API_KEY` (Secret `iris-api-key`) and
    the customer to org map from `/etc/siem/org-map.json`. `AllowedArtifacts` limits what a
    tag may run.
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
    stock Wazuh rule 99901 (a file hash from the MISP list) on macOS. The Windows and Linux
    twins (`Custom.Windows.Remediation.RemoveByHash`,
    `Custom.Linux.Remediation.RemoveByHash`) additionally quarantine the file (a copy under
    its own hash) before deleting it; `Mode: delete` removes it outright.
  - Response and forensics artifacts the collector runs for an approved action:
    `Custom.Linux.Remediation.Isolate` (nftables) and `Custom.MacOS.Remediation.Isolate`
    (pf) - Windows uses the built-in `Windows.Remediation.Quarantine`;
    `Custom.Generic.Remediation.KillProcess` (by pid, executable regex or executable
    SHA-256); `Custom.{Windows,Linux,MacOS}.Triage.Collect` (KAPE-style target set on
    Windows, plus live process list and connections everywhere);
    `Custom.Linux.Forensics.MemoryImage` (AVML, which must already be on the endpoint) -
    Windows uses the built-in `Windows.Memory.Acquisition`, macOS has none.

#### Response actions with approval

An analyst tags the IRIS asset `velociraptor:contain:<action>` (`respond:` and `collect:`
work too) with one of the `ResponseActions` keys: `isolate`, `unisolate`, `kill`,
`quarantine-file`, `remove-file`, `memory`, `triage`. Then:

1. The collector routes the case to its tenant's org, finds the client and its OS, picks the
   artifact for that OS from `ResponseActions`, opens an **approval task** on the case
   (tagged `velociraptor-approval,action:<action>`) naming requester, host, org and artifact,
   and retags the asset `velociraptor:approval:<task>:<action>`. Nothing has run yet.
2. A member of an `ApproverGroups` IRIS group comments `approve` (or `deny`) on that task.
   With `FourEyes: "Y"` the requester - the analyst the asset belongs to on the case - cannot
   be the approver. Group membership is read from the IRIS API on every cycle.
3. On approval the flow is scheduled and the asset becomes
   `velociraptor:pending:<org>:<flow>:<artifact>`, so the existing writeback puts the results
   on the timeline; the timeline also gets requester, approver, their comment and its time.
   A denial ends as `velociraptor:denied:<action>` with the same record.
4. When the results are written (`velociraptor:done:...`), the evidence pass adds a **chain of
   custody** note - host, org, flow, on whose behalf, and the SHA-256 the *server* recorded
   for every uploaded file - and retags `velociraptor:archived:<org>:<flow>`. With
   `EvidenceS3Bucket` (and `EvidenceS3Secret`, the name of a Velociraptor server secret of
   type *AWS S3 Creds*) the collection zip is also copied once to an S3-compatible bucket;
   use a bucket with object lock. That egress from the Velociraptor pod to the bucket
   endpoint has to be allowed explicitly
   (`velociraptor.velociraptor.networkPolicy.extraEgress`), like every other flow out of the
   namespace.

Operator setup, once: create the IRIS group `velociraptor-approvers` and put the approvers in
it; set `IsolationAllowlist` to the Velociraptor frontend address (the isolation artifacts
refuse to run while it is empty, so an endpoint can never be cut off from the SOC). A tag
naming an action nobody mapped for that OS, or an artifact outside `AllowedArtifacts`, ends
as `velociraptor:error:<reason>` with a red event on the case and never reaches an endpoint.
`files/case-templates` in the `dfir-iris` chart has phishing, ransomware and account takeover
templates whose tasks name these tags.

  `velociraptorArtifacts.monitoring` lists the server event artifacts the reconciler keeps in
  the monitoring table and the parameters it sets (KeycloakSync runs with `DryRun: "N"`);
  unlisted parameters keep their value in the table or the artifact default.

### Detection content

With `kubesoc-content.enabled` the `kubesoc-content` chart (dependency, README there)
renders ConfigMap `kubesoc-content`, the reconciler mounts it at `/etc/kubesoc-content`
(and `velociraptor-artifacts` at `/etc/kubesoc-content-core/velociraptor`) and its
`content` component rolls the rules, decoders, lists and agent group configs out to every
tenant manager, `kubesoc-content.canary` first, validated, hot-reloaded and rolled back on
failure, and sets the Velociraptor artifacts (`files/velociraptor` included) with
`artifact_set`. With `kubesoc-content.velociraptorArtifacts` (default) the render requires
`velociraptor.velociraptor.customArtifacts.enabled: false` and no longer checks
`checksum/server-artifacts`: artifacts reach the server without a restart. Off, everything
renders as before.

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

### Network policies

`networkPolicies` (`templates/networkpolicies.yaml`) denies all ingress and egress of every
pod in this namespace except DNS (`secops-default-deny`) and gives each workload a policy
(`secops-<workload>`) admitting exactly its flows. The component charts' own policies stay;
policies are additive. The tenant namespaces get the same from the wazuh chart
(`networkPolicies.enabled` in each tenant release, which kubeaid-cli renders; wazuh README
section 11). The flows:

| From | To | Port |
|---|---|---|
| `ingressController` (traefik) | IRIS app, MISP, Velociraptor GUI and frontend, central dashboard, HTTP-01 solvers | 8000; 80/443/8080; 8889/8000; 5601; 8089 |
| agents (anywhere) | Velociraptor frontend | 8000 (the chart's `frontendAllowedCIDRs`) |
| reconciler | Keycloak, IRIS app, tenant managers, tenant and central indexers, central dashboard, Velociraptor API, Kubernetes API | `keycloak.ports`; 8000; 55000; 9200; 5601; 8001; 443/6443 |
| IRIS app | Postgres, RabbitMQ, MISP, Keycloak | 5432; 5672; 80/443; `keycloak.ports` |
| IRIS worker | Postgres, RabbitMQ, MISP | 5432; 5672; 80/443 |
| IRIS Keycloak sync | Keycloak, IRIS app | `keycloak.ports`; 8000 |
| IRIS triage | IRIS app, Ollama | 8000; 11434 |
| Velociraptor | IRIS app (artifacts), Keycloak | 8000; `keycloak.ports` |
| tenant managers | IRIS app, MISP | 8000; 80/443 |
| MISP | MariaDB, Valkey, misp-modules, Keycloak, internet (feeds) | 3306; 6379; 6666; `keycloak.ports`; 80/443 |
| misp-modules | Valkey, internet (enrichment) | 6379; 80/443 |
| MISP export | MISP, tenant managers | 80/443; 55000 |
| central indexer | tenant indexers (cross-cluster search) | 9300 |
| central dashboard | tenant managers, Keycloak | 55000; `keycloak.ports` |
| CNPG operator | Postgres | 5432, 8000 |
| RabbitMQ operators | RabbitMQ | 15672 |
| MariaDB operator | MariaDB | 3306 |
| Postgres, RabbitMQ | themselves (replication, clustering), Kubernetes API | 5432/8000; 4369/25672; 443/6443 |
| Prometheus | Postgres, RabbitMQ, Valkey, Velociraptor, reconciler | 9187; 15692; 9121; 8003; `reconcilerMetricsPorts` |

The Kubernetes API and the internet are Cilium entities (`kube-apiserver`, `world`) in
CiliumNetworkPolicies, since on Cilium an ipBlock never matches either; with
`networkPolicies.cilium: false` they become NetworkPolicies to `kubeApiServer.to` (required
then) and to `0.0.0.0/0` minus `privateRanges`. `mispInternet.enabled: false` closes MISP's
internet access (feeds then need a proxy or `extraPolicies`). Anything else a cluster needs
(an object store for backups, a feed on a private address, another UI in front) goes into
`networkPolicies.extraPolicies`.

Rolling it out on a running cluster: the policies apply on sync, and a missing rule shows as
a connection timeout, not an error. After the sync, check `kubectl get cnp,netpol -n
<namespace>`, then watch drops (`hubble observe -n <namespace> --verdict DROPPED`) while the
reconciler, the IRIS syncs, the MISP export and a UI login each run once. Adjust the peers
(`ingressController`, `keycloak`, `prometheus`, `operators`) to the cluster's namespaces and
labels before syncing; `networkPolicies.enabled: false` removes all of them again.

### TLS verification

The reconciler verifies the tenants' manager APIs (`https://wazuh.<tenant namespace>.svc:55000`)
and the central indexer (`https://wazuh-indexer:9200`) against the soc-ca: the chart issues
`socCA.trustSecret` from it here and mounts its `ca.crt` at `/etc/soc-ca/ca.crt` (the
`caFile` of those components in `siem-tenants`). The indexers' node certificates always come
from the soc-ca; the manager API presents a soc-ca certificate once the tenant release sets
`wazuh.managerTls.enabled` (wazuh README section 11; kubeaid-cli renders it with the agent
host as an extra name). The MISP export verifies the same way (`misp.wazuhCdbExport.caSecret`),
and the central dashboard verifies the indexer (`opensearchVerificationMode: full`).
`tls.insecureSkipVerify: true` (or `insecureSkipVerify` per component in
`reconciler.components`, `verifyTls: false` per MISP target) is the explicit opt-out, for
tenant releases that do not have `managerTls` yet.

Not covered: IRIS, MISP and the Wazuh dashboards serve plain HTTP inside the cluster (TLS
ends at the ingress controller); the network policies above limit who can reach those ports.
The managers' authd `ssl_verify_host no` concerns agent certificates, which enrolment does not
use (it is password based); agents verify the manager with the CA in the enrolment bundle.
### AI assistant and MISP sightings

`dfir-iris.aiTriage` runs the local AI assistant (dfir-iris README, "AI assistant"): alert
triage (on when the job is on), case summary and report drafts for cases tagged
`ai:summarize` (`caseSummary.enabled`), and hunting suggestions for case notes titled
`ai:hunt: <question>` (`hunt.enabled`). It only writes notes and tags; nothing is run.
Enable:

```yaml
dfir-iris:
  aiTriage:
    enabled: true
    dryRun: false        # after reading a dry-run job log
    caseSummary: {enabled: true}
    hunt: {enabled: true}
ollama:
  ollama:
    ollama:
      models:
        pull: [mistral:7b]   # once, with networkPolicy.allowModelDownload: true
```

`dfir-iris.mispSightings` adds MISP sightings for the indicators of cases closed as true
positive (dfir-iris README, "MISP sightings"). It needs a MISP key with sighting rights in
Secret `misp-sightings-key` (key `key`), sealed by the operator.

Flows to allow (the namespace is default-deny, so each needs a rule; both jobs also need
DNS): the AI job (`app.kubernetes.io/component: ai-triage`) -> `dfir-iris-app:8000` and
`ollama:11434`; the sightings job (`app.kubernetes.io/component: misp-sightings`) ->
`dfir-iris-app:8000` and `misp:80`. Neither needs the indexer, Keycloak or the internet:
both authenticate to IRIS with an API key, not OIDC, so they are unaffected by the IRIS
OIDC settings. Ollama pulls a model only when `ollama.networkPolicy.allowModelDownload`
is on; keep it off once the model is in the volume.

### Landing portal

`kubesoc-portal.enabled: true` deploys the portal (`../kubesoc-portal`) at
`hosts.portal` (default `portal.<domain>`; `kubesoc-portal.ingress.host` must match, the
render fails otherwise) with `kubesoc-portal.oauth2Proxy.oidcIssuerUrl` set to
`<keycloak.url>/realms/<keycloak.realm>` as reached from the pod. From `tenants` and
`portal` this chart renders ConfigMap `kubesoc-portal-links`: a card per tenant, shown to
its group `<tenantGroupPrefix><code>` and to the `operators` roles, with links built from
`portal.tenantLinks` URL templates. IRIS customer ids and Velociraptor org ids are assigned
by those tools, so the customer-filtered IRIS link and the org link need
`portal.irisCustomerIds` / `portal.velociraptorOrgIds` (tenant code -> id); without them the
link falls back to the tool's start page. The reconciler keeps the Keycloak client
`kubesoc-portal` and Secret `kubesoc-portal-oidc`. Flows to allow (default-deny): ingress
controller -> portal pod 4180, portal -> Keycloak (the issuer, normally out through the
ingress) and DNS. The portal only links to the tools; it never proxies them, so the
dashboards staying SSO-only changes nothing for it.

## 8. What is not derived from `tenants`

A parent chart cannot compute its subcharts' values, so these need one entry per tenant:

- **MISP export targets**: `misp.wazuhCdbExport.targets` (checked by `checks.mispTargets`).
- **The tenant Wazuh releases** themselves (section 3).
- **Portal deep-link ids**: `portal.irisCustomerIds`, `portal.velociraptorOrgIds` (optional).
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
  add an equivalent rule to `velociraptor.velociraptor.networkPolicy.extraEgress`
  (`networkPolicies.cilium: false` covers this chart's own workloads).
- The Wazuh managers read their API and authd certificate (`wazuh.managerTls`) at start
  only: restart them after cert-manager renews it (within `renewBefore`, 90 days).
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
client bootstrap and shipped artifacts, no OpenSearch demo users centrally, and the soc-ca
approver policies. With every workload on (`tests/values-netpol.yaml`) it runs
`../wazuh/tests/netpol_check.py`: a default deny, a policy of its own for every workload, and
no rule open to any address except the Velociraptor frontend (8000) and MISP's internet
egress; plus the reconciler's and the MISP export's CA. The tenant side is covered by
`../wazuh/tests/tenant_render_test.sh` and `../wazuh/tests/hardening_render_test.sh`.
client bootstrap and shipped artifacts, retention input, the Deployment mode and the
monitoring objects (with `promtool check rules` when promtool is on PATH). The tenant side is covered by
client bootstrap and shipped artifacts, the AI assistant and MISP sightings jobs, and the
landing portal (links per tenant, Keycloak client, hardening). The AI scripts have their own
tests (`../dfir-iris/tests`, fake IRIS/Ollama/MISP), so has the portal
(`../kubesoc-portal/tests`). The tenant side is covered by
`../wazuh/tests/tenant_render_test.sh`.
client bootstrap and shipped artifacts, and the content package wiring. The tenant side is
covered by `../wazuh/tests/tenant_render_test.sh`, the content itself by
`../kubesoc-content/tests/`. CI: `.github/workflows/kubesoc-content.yml` runs all three.
