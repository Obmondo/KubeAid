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

On macOS `/etc` is a symlink to `/private/etc` and FIM does not follow it, so the stock
agent config monitors nothing there; realtime FIM is also unsupported on macOS, so the scan
`frequency` is the detection latency.
