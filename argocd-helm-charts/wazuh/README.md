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
