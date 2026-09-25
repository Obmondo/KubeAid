# wazuh

Wazuh (SIEM/XDR) manager cluster, indexer and dashboard, wrapped from
[morgoved/wazuh-helm](https://github.com/morgoved/wazuh-helm) 2.0.7, which ships Wazuh
4.14.3. Upstream vendors cert-manager 1.19.3 as a subchart, already disabled by default
(`cert-manager.enabled: false`). Leave it off: KubeAid installs cert-manager as its own
Application.

## 1. How to setup

The defaults bring up one master, one worker, one indexer, a dashboard and a DaemonSet of
agents. Size the storage per node and keep the rest:

```yaml
wazuh:
  indexer:
    replicas: 1
    storageSize: 5Gi
  wazuh:
    master:
      storageSize: 5Gi
    worker:
      replicas: 1
      storageSize: 5Gi
```

## 2. NetworkPolicies are deny-by-default

Every component ships a NetworkPolicy with `policyTypes: [Ingress, Egress]`, enabled by
default. The managers may egress **only** to:

| Destination | Port |
|---|---|
| anywhere (Wazuh CTI) | 443/TCP |
| the indexer | 9200/TCP |
| CoreDNS in kube-system | 53/UDP |

plus 1516/TCP between worker and master.

Anything else is dropped, and the failure is easy to misread: DNS still resolves, so a
blocked integration looks like the remote service being down. It surfaces as a connection
timeout with nothing in any log.

Integrations are therefore opt-in. Add them through the chart's own hooks rather than
disabling the policy — `networkPolicy.extraIngresses` and `networkPolicy.extraEgresses`
exist on `wazuh.master`, `wazuh.worker`, `indexer` and `dashboard`, all defaulting to `[]`,
and each takes standard NetworkPolicy rules:

```yaml
wazuh:
  wazuh:
    master:
      networkPolicy:
        extraEgresses: &integrations
          # MISP's Service listens on 80, so the blanket 443 rule does not cover it.
          - ports:
              - protocol: TCP
                port: 80
            to:
              - namespaceSelector:
                  matchLabels:
                    kubernetes.io/metadata.name: misp
          # Shuffle backend webhook, the target of an <integration> block in ossec.conf.
          - ports:
              - protocol: TCP
                port: 5001
            to:
              - namespaceSelector:
                  matchLabels:
                    kubernetes.io/metadata.name: shuffle
    worker:
      networkPolicy:
        extraEgresses: *integrations
```

Apply integration rules to **both** master and worker. Agents connect to the worker, so
their events are analysed there and `wazuh-integratord` fires from the worker; the master
needs the same rules for agents attached directly to it and for API-driven work.

Pushing content to the manager — a CDB list through the API's
`PUT /lists/files/{filename}` on 55000, for example — needs an `extraIngresses` rule
instead. By default only the dashboard and agent
pods may reach the master's API port.

## 3. Where state lives

The master is the source of truth for rules, decoders and CDB lists; the cluster
synchronises `/var/ossec/etc` from master to workers. Write to the master, never to a
worker.

Wazuh 4.13+ hot-reloads the *content* of rules, decoders and CDB lists. Registering a new
list file in the `<ruleset>` block of `ossec.conf` is still a restart.

## 4. Single master

Wazuh's manager cluster has one master by design; `wazuh.worker.replicas` scales the
workers that agents connect to. Plan failover for the master separately — it is a
singleton.

## 5. Config changes roll the managers

`ossec.conf`, `local_rules.xml`, `local_decoder.xml` and the agent group confs reach
`/var/ossec/etc` by being copied out of the manager ConfigMap at container start, so a
synced ConfigMap alone changes nothing. Both manager StatefulSets carry a
`checksum/config` pod annotation over that ConfigMap, so any change to
`wazuh.localRules`, `wazuh.localDecoder`, `wazuh.{master,worker}.extraConf` or
`wazuh.agentGroupConf` rolls master and worker on the next sync. Unrelated values leave the
hash alone.

Upstream's `autoreload.enabled` is left off on purpose: it also hashes the generated
Secrets, whose `randAlphaNum` defaults change on every render and would roll the managers
on every sync.

The wrapper's IRIS ConfigMap (`templates/iris-integration.yaml`) is not covered: a subchart
cannot hash a parent template. Its content changes only with this chart, but after such an
upgrade restart the managers once by hand, since the files are `subPath` mounts.

## 6. Reload the worker's ruleset after a sync

Workers take `etc/rules`, `etc/decoders` and `etc/lists` from the master by cluster
integrity sync. After a pod start that sync arrives tens of seconds *after* the worker's
`wazuh-analysisd` has loaded the stale copy on its PVC, and nothing reloads it: a new rule
stays inactive on the node that analyses agent events, without any error.

```yaml
wazuh:
  wazuh:
    worker:
      rulesetReloader:
        enabled: true
        settleSeconds: 90   # ruleset must be unchanged this long before the reload
```

This adds a `ruleset-reloader` sidecar to the worker (`charts/wazuh/files/ruleset-reloader.sh`).
It watches those directories on the worker's PVC (read-only) and, once they have settled,
calls `PUT /cluster/analysisd/reload?nodes_list=<this worker>` on the worker's own API on
`localhost:55000` with the credentials from the API Secret: once after every start, and
again after any later sync that changes them. Compiled `*.cdb` files are ignored, as
analysisd rewrites them on each reload.

A sidecar rather than an Argo CD `PostSync` hook Job, because the problem follows every pod
start, not every sync: a node drain, an OOM kill or a manual `rollout restart` never runs a
hook. Talking to localhost also needs no NetworkPolicy change - the worker forwards the
login and the reload to the master over the cluster port it already uses.

## 7. Agent group configuration (`agent.conf`)

`wazuh.agentGroupConf` writes `etc/shared/<name>/agent.conf` on the managers for each
entry; the master pushes it to every agent in that group. Use `name: default` for the group
agents enrol into. The list replaces upstream's `example` entry, and a change rolls the
managers (section 5). The file is overwritten at every start, so edits made in the
dashboard's group editor do not survive a restart - keep it in values.

```yaml
wazuh:
  wazuh:
    agentGroupConf:
      - name: default
        agent: |
          <agent_config os="Darwin">
            <syscheck>
              <frequency>900</frequency>
              <directories check_all="yes">/private/etc</directories>
            </syscheck>
          </agent_config>
```

The group itself needs no API call: at start wazuh-db registers every directory under
`etc/shared/` as a group, so a new entry here is a group after the next manager start (the
upstream `example` group appeared this way, with no `agent_groups -a`). Removing an entry
does not delete the group - the directory stays on the master's PVC. Assigning agents to a
group is still an API call (`PUT /agents/{id}/group/{group}`) or `-G` at enrolment.

Groups whose names are only known elsewhere (one per tenant, for example) can come from a
ConfigMap this chart does not render: set `wazuh.agentGroupConfConfigMap` to its name and
each key `<group>.conf` becomes `etc/shared/<group>/agent.conf` on both managers, copied by
an init container at start. This chart cannot hash that ConfigMap, so a change needs a
manager restart (or a Reloader annotation in `wazuh.{master,worker}.annotations`). A group
listed in both places keeps the `agentGroupConf` content.

On macOS `/etc` is a symlink to `/private/etc` and FIM does not follow it, so the stock
agent config monitors nothing there; realtime FIM is also unsupported on macOS, so the scan
`frequency` is the detection latency.

## 8. Single sign-on (OpenID Connect)

The subchart already carries the plumbing under `wazuh.dashboard.sso.oidc`: an
`openid_auth_domain` in the indexer's `config.yml`, the `openid` settings in
`opensearch_dashboards.yml`, and the client id/secret as env vars on both the indexer
and the dashboard, read from `existingSecret`. Roles come from one flat claim
(`config.rolesKey`, default `roles`) and become backend roles, which
`roleMappings.{allAccess,readall,kibanaUser,kibanaServer}.backendRoles` and
`extraRoleMappings` map onto OpenSearch roles.

```yaml
wazuh:
  dashboard:
    sso:
      oidc:
        enabled: true
        url: https://idp.example.com/realms/example/.well-known/openid-configuration
        logoutUrl: https://idp.example.com/realms/example/protocol/openid-connect/logout
        issuer: https://idp.example.com/realms/example
        scope: "openid profile email"
        existingSecret: wazuh-dashboard-oidc  # keys OPENSEARCH_OIDC_CLIENT_ID / _SECRET
        roleMappings:
          allAccess:
            backendRoles: [administrator]
          readall:
            backendRoles: [analyst]
          kibanaUser:
            backendRoles: [analyst]
    # Keep the internal users as break-glass: the dashboard then offers both an
    # SSO button and the username/password form.
    basicAuth:
      enabled: true
      order: 0
      challenge: false
```

The IdP client's redirect URI is `<dashboard URL>/auth/openid/login`. The claim named by
`rolesKey` must be in the **ID token**: the dashboard forwards the ID token to the
indexer as the bearer credential.

Things that are easy to miss:

- **Security config is applied by the `wazuh-indexer` Job**, a `post-install,post-upgrade`
  Helm hook that runs `securityadmin.sh` over the rendered files. Argo CD runs it as a
  PostSync hook on every sync, so a values change reaches the security index without a
  manual `securityadmin.sh` run. It uploads *every* file, so changes made through the
  security REST API or the dashboard's Security UI are overwritten on the next sync.
- **Both the indexer and the dashboard call the IdP**: the indexer fetches the JWKS to
  validate tokens, the dashboard exchanges the authorization code. Both NetworkPolicies
  are deny-by-default, so each needs an `extraEgresses` rule to the IdP (or to the
  ingress controller in front of it), and the IdP hostname must resolve to something
  that routes from inside the cluster. `extraSpec.pod.hostAliases` on `indexer` and
  `dashboard` covers the case where it only resolves correctly outside.
- **The Wazuh app has its own RBAC.** With `run_as: true` (the image's default) the
  dashboard calls the Wazuh API on behalf of the logged-in user, and the API grants
  roles through its own rules matched against that user's backend roles, for example
  `{"FIND": {"backend_roles": "administrator"}}` on the `administrator` role. Those rules
  live in the manager's RBAC database, not in this chart: create them through the API
  (`POST /security/rules`, then `POST /security/roles/{id}/rules`) or the dashboard's
  Server management > Security > Roles mapping. Without one, an SSO user logs in to
  OpenSearch Dashboards but the Wazuh app reports it has no permissions.
- The dashboard only rolls on a ConfigMap change when `autoreload.enabled` is true. The
  OIDC env vars change the pod spec, so turning SSO on rolls it anyway; later
  changes to the `openid` settings alone need a restart.

## 9. Per-tenant separation

For one Wazuh serving several tenants whose staff must not see each other's data, while a
central team sees everything. Three layers, each in a different place:

1. **Tenant label, per agent group.** Put the agents of a tenant in their own group and give
   the group a label in its `agent.conf` (section 7). Labels set centrally override the
   agent's local ones. They show up in every alert as `agent.labels.<key>`.

   ```yaml
   wazuh:
     wazuh:
       agentGroupConf:
         - name: tenant-acme
           agent: |
             <agent_config>
               <labels>
                 <label key="tenant">acme</label>
               </labels>
             </agent_config>
   ```

2. **One alerts index per tenant.** `wazuh.filebeat.indexRouting` mounts a patched copy of
   the wazuh module's alerts pipeline on both managers: an alert whose label matches
   `valuePattern` goes to `wazuh-alerts-4.x-<label>-<date>`, everything else to the stock
   `wazuh-alerts-4.x-<date>`. The names stay under the `wazuh` index template
   (`wazuh-alerts-4.x-*`) and the dashboard's `wazuh-alerts-*` index pattern, and
   per-tenant retention can be an ISM policy on `wazuh-alerts-4.x-<label>-*`.

   ```yaml
   wazuh:
     wazuh:
       filebeat:
         indexRouting:
           enabled: true
           labelKey: tenant
           valuePattern: "^[a-z0-9]{1,32}$"
           dateRounding: M          # monthly tenant indices; empty keeps daily
           indexNameFormat: yyyy.MM
   ```

   `files/filebeat/alerts-pipeline.json` is a verbatim copy from the manager image
   (`/usr/share/filebeat/module/wazuh/alerts/ingest/pipeline.json`); refresh it when the
   image tag moves. Existing alerts are not moved. The label comes from the agent, so an
   agent that is not under your control can claim another tenant's label and write into its
   index (it still cannot read it).

3. **Index permissions per tenant.** `indexer.config.extraRoles` appends roles to
   `roles.yml`; map them with `dashboard.sso.oidc.extraRoleMappings`. Set
   `indexer.config.doNotFailOnForbidden: true`, or every search over `wazuh-alerts-*` by a
   tenant user fails with 403 as soon as it touches another tenant's index. Indices the
   manager writes for all agents at once (`wazuh-monitoring-*`, `wazuh-states-*`) cannot be
   split by index; give tenant roles document-level security on them or leave them out.

   ```yaml
   wazuh:
     indexer:
       config:
         doNotFailOnForbidden: true
         extraRoles:
           tenant-acme-reader:
             cluster_permissions: [cluster_composite_ops_ro]
             index_permissions:
               - index_patterns: ["wazuh-alerts-4.x-acme-*"]
                 allowed_actions: [read]
               - index_patterns: ["wazuh-monitoring-*"]
                 dls: '{"term": {"group.keyword": "tenant-acme"}}'
                 allowed_actions: [read]
     dashboard:
       sso:
         oidc:
           roleMappings:
             kibanaUser:
               backendRoles: [tenant-acme]
           extraRoleMappings:
             tenant-acme-reader:
               backend_roles: [tenant-acme]
   ```

   The Wazuh app's own views (agents, inventory, SCA, FIM) go through the Wazuh API, which
   has a separate RBAC (section 8): give the tenant's backend role an API role whose
   policies use the resource `agent:group:tenant-acme` (and `group:id:tenant-acme` for
   `group:read`), so the agent list shows only that group.

## 10. DFIR-IRIS integration (`irisIntegration`)

`irisIntegration.enabled` renders the `<fullname>-iris-integration` ConfigMap with
`custom-iris` and `custom-iris.py`. Mount both files into `/var/ossec/integrations` on
master and worker (`subPath`, one file each) and declare the `<integration>` block in
`wazuh.{master,worker}.extraConf`, with the IRIS API key read from a mounted Secret:

```yaml
<integration>
  <name>custom-iris</name>
  <hook_url>http://dfir-iris-app.dfir-iris.svc.cluster.local:8000</hook_url>
  <api_key>file:/var/ossec/integrations/.iris_key</api_key>
  <level>10</level>
  <alert_format>json</alert_format>
  <options>{"min_level": 10, "default_customer_id": 1, "tenant_field": "tenant"}</options>
</integration>
```

The tenant comes from the agent label named by `tenant_field` and picks the IRIS customer:

- `customer_map`: `{"<label>": <IRIS customer id>}`, inline.
- `customer_names`: `{"<label>": "<IRIS customer name>"}` for labels not in
  `customer_map`; the id is looked up with `GET /manage/customers/list`, since IRIS assigns
  ids itself.
- `options_file`: path to a JSON object merged under the inline options (inline keys win),
  read for every alert. With a mounted ConfigMap (not `subPath`) the per-tenant part stays
  out of `ossec.conf` and changes without a manager restart.

Alerts without a matching label go to `default_customer_id`.

## 11. One Wazuh per tenant

The alternative to section 9 when tenants must be separated completely: every tenant gets
its own release (manager, indexer, dashboard) in its own namespace, and a central team
searches all of them from a central indexer with OpenSearch cross-cluster search. An agent
can then only enrol with, and send to, its own tenant's manager, and an indexer only ever
holds one tenant's data. `tests/values-tenant.yaml` is a complete example, checked by
`tests/tenant_render_test.sh`.

- **Master only.** `wazuh.worker.enabled: false` and `agents-events` (1514) added to
  `wazuh.master.service.ports`; the agent routes then point at the master Service
  (`agentTcpRoutes.events.serviceName: <fullname>`). One manager takes a few thousand
  agents; add workers when a tenant outgrows it.
- **One port pair per tenant.** Agent traffic is not TLS on 1514, so Traefik cannot route
  it by host name: give each tenant its own entry points (`agentTcpRoutes.*.entryPoint`)
  or its own address.
- **Shared CA.** `certificates.issuer` names one CA ClusterIssuer for all releases, so the
  indexers trust each other (the node certificate follows it, see the patches below).
  `certificates.subject.organization` differs per tenant, which makes each indexer's node
  DN unique; `indexer.config.nodesDn` adds the central indexer's DN so it may connect.
- **No generated passwords.** Set `existingSecret` for `indexer.cred`, `dashboard.cred`,
  `wazuh.apiCred` and `wazuh.authd`, plus `passwordHash` for the indexer and dashboard
  users (the chart's `lookup` of the Secret does not run under Argo CD). The chart
  defaults are public. Also set `wazuh.key`.
- **Fixed IRIS customer.** The IRIS integration's `customer_name` option sends every alert
  of the manager to one IRIS customer (section 10).
- **Network policies** stay deny-by-default; open indexer 9300 to the central namespace,
  manager 55000 to whoever manages the API, and egress to IRIS, with the `extraIngresses`
  / `extraEgresses` values.
- **`agent.enabled: false`**: the cluster's own nodes are not a tenant's endpoints.

The central instance is the same chart with `wazuh.enabled: false` (no manager), an indexer
and a dashboard whose Wazuh app lists every tenant manager (`dashboard.wazuhAppConfigSecret`).
The remote clusters are set with `PUT _cluster/settings` (`cluster.remote.<alias>.seeds`);
index patterns such as `*:wazuh-alerts-*` then search every tenant.

## Local patches to the vendored subchart

`charts/wazuh` is upstream 2.0.7 with KubeAid changes that sections 5 to 9 describe (the
`checksum/config` annotation, the ruleset reloader, `agentGroupConf` ownership, index
routing, extra roles and role mappings). Re-apply them when updating the subchart. Added
with the security-operations umbrella chart:

- `wazuh.agentGroupConfConfigMap` (section 7): an optional ConfigMap volume, the
  `agent-group-conf` init container and a second ownership loop in the `postStart` hook,
  in `templates/manager/{master,worker}/statefulset.yaml`, plus the value in `values.yaml`.
  Nothing renders while it is empty.
- `certificates.issuer` for the indexer node certificate (section 11):
  `templates/certs/node/certificate.yaml` and `templates/certs/node.crp.yaml` use
  `certificates.issuer.name` when set, instead of the release's own `<fullname>-ca-issuer`,
  so `ca.crt` is the shared CA.
- `dashboard.wazuhAppConfigSecret` (section 11): a Secret volume mounted over
  `data/wazuh/config/wazuh.yml` in `templates/dashboard/deployment.yaml`, plus the value.
  Nothing renders while it is empty.
