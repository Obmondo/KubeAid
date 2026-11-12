# Prometheus LinuxAid

Obmondo-authored chart (no vendored `charts/` - built from local `templates/`, `rules/`, `records/`, and
`tests/`) that deploys a self-contained Prometheus + Alertmanager + Grafana stack for monitoring
Obmondo-subscribed Linux servers and VMs, independent of the in-cluster `kube-prometheus` stack.

## Why it's in KubeAid

Already included as part of KubeAid's standard monitoring setup (`kube-prometheus`) when a cluster is
managed by KubeAid - it monitors LinuxAid-subscribed hosts (bare-metal/VM servers), not the Kubernetes
cluster itself. Alerts and Grafana dashboards are pre-built for host-level failure modes: disk, RAID, NTP
drift, systemd services, HAProxy, Docker, backups, and more (see `rules/` and `templates/dashboard_*.yaml`).

## Prerequisites

- `prometheus-operator` and `grafana-operator` running in-cluster.

## Key values / KubeAid-specific configuration

| Value | Description | Default |
|---|---|---|
| `prometheus.connect_obmondo` | Feed alerts into Opsmondo | `false` |
| `prometheus.subscribed-certname` | Puppet certname this Prometheus instance is subscribed under | `""` |
| `prometheus.customerid` | Obmondo customer ID | `""` |
| `prometheus.remoteWrite` | Prometheus Operator `remoteWrite` entries, passed through as is | `[]` |
| `prometheus.storage.size` / `.className` | Prometheus PVC size/class | `30Gi` / `rook-ceph-block` |
| `prometheusRule.<name>` | Per-alert-group toggle (`disk`, `dns`, `haproxy`, `zfs`, `smartmon`, ~25 more) | mostly `true` |
| `alertmanager.enabled` | Deploy Alertmanager | `true` |
| `middleware.jwt.enabled` | Traefik JWT middleware in front of Grafana | `false` |

## Operational notes

- Grafana dashboards (node-exporter, HAProxy, Docker, Postgres, MySQL) are vendored from upstream sources and
  embedded as gzip+base64 JSON (`grafana-operator` cannot template raw dashboard JSON directly — `helm template`
  treats some dashboard functions as templatable and fails to parse them, and a YAML block/folded string
  (`| or >`) doesn't work around it). Sources for the vendored dashboards:

  - node exporter: <https://github.com/rfmoz/grafana-dashboards/blob/master/prometheus/node-exporter-full.json>
  - haproxy: <https://github.com/rfmoz/grafana-dashboards/blob/master/prometheus/haproxy-2-full.json>
  - docker: <https://gitea.obmondo.com/EnableIT/puppet/src/commit/e7f4b744f150345eebc2335929bfc6d6344276f9/envs/production/modules/include/customers/files/enableit/monitoring-stack/grafana/dashboards/obmondo_docker_dashboard.json>
  - postgres: <https://grafana.com/oss/prometheus/exporters/postgres-exporter/?tab=dashboards>
  - mysql: <https://github.com/percona/grafana-dashboards/blob/main/dashboards/MySQL/MySQL_Query_Response_Time_Details.json>

  Re-encode an updated dashboard JSON with:

  ```sh
  cat /tmp/dashboard.json | gzip | base64 -w0
  ```

- To connect this Prometheus instance to Opsmondo, set `connect_obmondo: true` and configure
  `subscribed-certname` (the full certname) and `customerid`:

  ```yaml
  prometheus:
    connect_obmondo: true
    subscribed-certname: <your-subscribed-certname> # e.g., "puppetserver-gn.7e..."
    customerid: <your-customer-id> # e.g., "7e..."
  ```

- New host-level alerts follow a fixed pattern:
  - add the rule + test files under `rules/`/`tests/`;
  - test the new rule: `docker run -ti --rm -v $(pwd):/etc/prometheus/:ro --entrypoint /bin/promtool prom/prometheus test rules /etc/prometheus/tests/${NEW_RULE}.yaml` (run from `argocd-helm-charts/prometheus-linuxaid`);
  - add a `PrometheusRule` template under `templates/`;
  - enable the corresponding LinuxAid Puppet module in
    [`modules/enableit/monitor/manifests/system`](https://gitea.obmondo.com/EnableIT/LinuxAid/src/branch/master/modules/enableit/monitor/manifests/system)
    (create a new manifest there if one doesn't already exist for the check);
  - flip its `prometheusRule.<name>` value to `true`.
- Take regular Velero backups of Prometheus data; there is no other backup path for this instance.

## Docs links

- [Prometheus Configuration](../../docs/kubeaid/prometheus-configuration.md)
