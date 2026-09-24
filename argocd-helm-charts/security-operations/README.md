# security-operations

A security operations stack as one Helm release in one namespace, configured for several
tenants from one list:

| Component | Chart | Role |
|---|---|---|
| Wazuh | `../wazuh` | SIEM: agents, manager cluster, indexer, dashboard |
| Velociraptor | `../velociraptor` | Endpoint forensics and response |
| DFIR-IRIS | `../dfir-iris` | Case management; PostgreSQL and RabbitMQ through kubeaid-addons |
| MISP | `../misp` | Threat intelligence, fed into Wazuh as CDB lists |
| Ollama | `../ollama` | Local model for advisory alert triage in IRIS |

The components are the KubeAid wrapper charts next to this one, symlinked into `charts/`.
They stay usable on their own; this chart only adds what one release and a tenant list need.
Each can be switched off with `<component>.enabled: false`.

Deploy it as one Argo CD Application with destination namespace `security-operations` (any
name works; every object lands in the release namespace) and `CreateNamespace=true`.

## 1. Minimal values

```yaml
domain: example.com
keycloak:
  url: https://keycloak.example.com/auth
  realm: soc
tenants:
  - code: "001"
    name: Tenant A
  - code: "002"
    name: Tenant B
    retentionDays: 90
wazuh:
  wazuh:
    # per-tenant OpenSearch roles, see section 5
    indexer: {config: {extraRoles: {...}}}
    dashboard: {sso: {oidc: {extraRoleMappings: {...}}}}
```

Ingress hosts, SSO clients, storage and the Secrets each component expects are set in the
component blocks exactly as for the standalone charts (see their READMEs), one level down:
`wazuh.wazuh...`, `velociraptor.velociraptor...`, `dfir-iris...`, `misp.misp...`,
`ollama.ollama...`.

## 2. Values reference

| Key | Default | Meaning |
|---|---|---|
| `domain` | `example.com` | Base domain; hostnames default to `<component>.<domain>` |
| `hosts.{wazuh,iris,misp,velociraptor}` | `""` | Override one hostname. Used for OIDC redirect URIs and alert links, not for the ingresses |
| `keycloak.url`, `keycloak.realm` | | Realm every component logs in through, as the reconciler reaches it |
| `keycloak.adminUsername`, `keycloak.adminSecretRef` | `admin`, `keycloakx/keycloak-admin/KEYCLOAK_PASSWORD` | Admin login the reconciler reads (the KubeAid keycloakx default) |
| `keycloak.bruteForceProtected`, `.otpPolicy`, `.requireTOTP`, `.mfaFlow` | on, TOTP, on, `browser-mfa` | Realm policy the reconciler enforces; remove a key to leave it alone |
| `keycloak.clients` | `[]` | OIDC clients for the reconciler; empty derives one per enabled component plus `iris-sync` |
| `operators.adminRole`, `.analystRole` | `administrator`, `analyst` | Realm roles of the central team; they see every tenant |
| `operators.analystGroup` | `soc-analysts` | Group that grants the analyst role (reconciler) |
| `toolRoles.iris.{admin,analyst,tenant}` | `Administrators`, `Analysts`, `Analysts` | IRIS groups each kind of user gets |
| `toolRoles.velociraptor.{admin,analyst,tenant}` | `administrator`, `investigator`, `investigator` | Velociraptor roles |
| `tenants` | `[]` | `code`, `name`, optional `retentionDays`, optional `idp` |
| `tenantGroupPrefix` | `tenant-` | Keycloak group and realm role of a tenant: `<prefix><code>` |
| `tenantLabelKey` | `tenant` | Wazuh agent label carrying the code; must equal `wazuh.wazuh.wazuh.filebeat.indexRouting.labelKey` |
| `defaultRetentionDays` | `365` | Alert retention when a tenant sets none |
| `checks.wazuhTenantRoles` | `true` | Fail the render when a tenant has no OpenSearch reader role (section 5) |
| `ai.irisLogin`, `ai.irisGroups` | `svc_ai`, `[Automation]` | IRIS login of the triage job; the reconciler gives it these groups and every tenant as customer |
| `publicIngress.{wazuhAgentHost,velociraptorHost}` | `""` | Hostnames agents dial, for the enrolment bundles |
| `reconciler.*` | disabled | Section 6; `reconciler.secrets` and `reconciler.components` override what goes into `siem-tenants` |
| `wazuh`, `velociraptor`, `dfir-iris`, `misp`, `ollama` | see values.yaml | Passed to the component charts |

`tenants[].code` must match `^[a-z0-9]{1,32}$` and be unique; `name` must be unique. No
dashes: a code is the infix of the tenant's alerts indices (`wazuh-alerts-4.x-<code>-*`), and
with dashes the pattern of tenant `a` would also match the indices of tenant `a-b`.
`values.schema.json` checks the format, the templates check uniqueness.

## 3. Onboarding a tenant

1. Add an entry to `tenants`.
2. Add its OpenSearch reader role and mapping (section 5). The render fails until you do.
3. Sync. The managers need a restart to register the new Wazuh agent group; with Reloader
   installed the `configmap.reloader.stakater.com/reload` annotation does it.
4. With the reconciler enabled, the Keycloak group and role, the IRIS customer, the
   Velociraptor org and the Wazuh RBAC follow on the PostSync run. Without it, create them
   by hand with the names in the `siem-tenants` ConfigMap.
5. Enrol the tenant's agents into group `<prefix><code>` (Wazuh `-G`, or
   `PUT /agents/{id}/group/<group>`) and give them the tenant's Velociraptor client config.

## 4. What is rendered from `tenants`

This chart cannot compute its subcharts' values, so everything tenant-shaped is rendered
by its own templates as ConfigMaps the components mount (wired by the defaults in
`values.yaml`):

| ConfigMap | Key | Consumer | Picks up a change |
|---|---|---|---|
| `wazuh-tenants` | `<group>.conf` | Wazuh managers, `wazuh.agentGroupConfConfigMap`: agent group setting the tenant label | manager restart |
| `wazuh-tenants` | `iris-options.json` | `custom-iris` integration (`options_file`): label to IRIS customer name, dashboard link | next alert |
| `dfir-iris-tenants` | `mapping.json` | IRIS `keycloakSync` (`mappingConfigMap`): operators see every customer, a tenant group its own | next run |
| `velociraptor-tenants` | `group-map.json`, `role-map.json`, `org-map.json` | Velociraptor server artifacts, `/etc/siem` | next cycle |
| `siem-tenants` | `tenants.json` | the reconciler, in the schema of kubeaid-cli `pkg/siem/config` (unknown fields are rejected there) | next run |

The agent label also routes each alert to `wazuh-alerts-4.x-<code>-YYYY.MM`
(`wazuh.wazuh.wazuh.filebeat.indexRouting`, on by default).

## 5. What is not derived from `tenants`

These still need one entry per tenant in the values; the render checks the first two.

- **OpenSearch reader role**: `wazuh.wazuh.indexer.config.extraRoles.<prefix><code>-reader`
  and `wazuh.wazuh.dashboard.sso.oidc.extraRoleMappings.<prefix><code>-reader`, plus the
  tenant's group in `wazuh.wazuh.dashboard.sso.oidc.roleMappings.kibanaUser.backendRoles`.
  They end up in the security config Secret the Wazuh chart renders and applies with
  `securityadmin.sh` on every sync, which overwrites anything set through the API, so they
  cannot come from a ConfigMap or the reconciler. Example for tenant `001`:

  ```yaml
  wazuh:
    wazuh:
      indexer:
        config:
          doNotFailOnForbidden: true
          extraRoles:
            tenant-001-reader:
              cluster_permissions: [cluster_composite_ops_ro]
              index_permissions:
                - index_patterns: ["wazuh-alerts-4.x-001-*"]
                  allowed_actions: [read]
                - index_patterns: ["wazuh-monitoring-*"]
                  dls: '{"term": {"group.keyword": "tenant-001"}}'
                  allowed_actions: [read]
      dashboard:
        sso:
          oidc:
            roleMappings:
              kibanaUser:
                backendRoles: [analyst, tenant-001]
            extraRoleMappings:
              tenant-001-reader:
                backend_roles: [tenant-001]
  ```

- **Velociraptor artifacts** are the operator's (`velociraptor.velociraptor.customArtifacts`).
  To use the tenant maps, give each map parameter a file parameter and read the file when it
  is set, for example in a Keycloak sync artifact:

  ```yaml
  - name: GroupMapFile
    default: /etc/siem/group-map.json
  ```
  ```sql
  LET GMAP = parse_json(data=if(condition=GroupMapFile,
                                then=read_file(filename=GroupMapFile), else=GroupMap))
  ```

- **Inventory indices** (`wazuh-states-*`) carry only agent ids. A reader role that should see
  them needs a `dls` on the tenant's agent ids, maintained by hand.

## 6. Reconciler

`reconciler.enabled` adds a CronJob (every 10 minutes) and an Argo CD PostSync Job running
`ghcr.io/obmondo/siem-reconciler` with `--config /etc/siem/tenants.json --dry-run=<reconciler.dryRun>`,
a ServiceAccount that may create (never update) Secrets in the release namespace, and a
Role in Keycloak's namespace that can read only `keycloak.adminSecretRef`. It sets up what
has only an API: Keycloak roles, groups, clients and flows, IRIS customers, Velociraptor
orgs and Wazuh RBAC, and creates missing Secrets (OIDC client secrets, API keys, per-tenant
enrolment bundles; by default one per OIDC client `secretRef`, and the MISP client Secret
`oidc-credentials` still needs its `username` key set by hand). It never changes users;
the IRIS and Velociraptor Keycloak syncs own those. Start with `dryRun: true` and read the job log. It is off by default until the image
is published; `siem-tenants` renders either way.

## 7. Wiring inside the namespace

The defaults in `values.yaml` connect the components through same-namespace Service names
and pod selectors: Wazuh to IRIS (`http://dfir-iris-app:8000`) and MISP, Velociraptor to
IRIS, IRIS triage to Ollama (`http://ollama:11434`), the MISP CDB export to the Wazuh API
(`https://wazuh:55000`, with the Wazuh chart's own `wazuh-api-cred`). Every
`fullnameOverride` keeps the names a standalone install has, and `misp.kubeaid-addons` is off
so `iris-pgsql` and `iris-rabbitmq` render once.

Helm replaces lists instead of merging them. When you set one of the lists in
`values.yaml` (volumes, mounts, NetworkPolicy rules, `extraConf`), copy the default entries
you want to keep.

## 8. Moving from separate releases

Existing installs of the five charts in their own namespaces keep working. Moving them into
this chart is a namespace move: SealedSecrets must be sealed again for the new namespace,
PersistentVolumes can be rebound (set `Retain`, delete the old claim, clear `claimRef`,
pre-create the claim in the new namespace with `volumeName`), the CNPG cluster bootstraps
from the old one with `pg_basebackup`, and MariaDB moves by dump and restore. Delete the old
Applications without cascading. Cross-namespace rules in the old values
(`namespaceSelector: kubernetes.io/metadata.name: <component>`) become pod selectors.

## 9. Limitations and TODO

- The OpenSearch reader roles are values, not rendered (section 5).
- Velociraptor artifacts must be changed to read `/etc/siem` (section 5).
- The reconciler reaches the Velociraptor API only once the velociraptor chart exposes it to
  the reconciler pod (API Service and NetworkPolicy); today it does so only for minions.
- The MISP to Wazuh CDB export stays off (`misp.wazuhCdbExport.enabled`) because it needs the
  list registration and rules in `wazuh.wazuh.wazuh.{master,worker}.extraConf` and
  `localRules` (misp README, section 5).
- kubeaid-addons' Cilium policies for RabbitMQ and Celery select on
  `app.kubernetes.io/instance` alone; in one release that matches every component, so keep
  `dfir-iris.global.netpol` off here.
- A new Wazuh agent group needs a manager restart (Reloader or by hand).

## 10. Tests

`tests/render_test.sh` (helm, yq, jq, python3; no cluster) renders the chart with a generic
2-tenant and 3-tenant fixture and checks object uniqueness, namespace, names, selectors,
that tenant `003` adds only its own entries, input validation and the reconciler objects.
