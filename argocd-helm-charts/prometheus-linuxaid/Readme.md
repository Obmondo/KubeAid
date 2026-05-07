# Self Hosted LinuxAid Monitoring (servers + vms) on Kubernetes

## Requirements

NOTE: This is already present - if your cluster is managed by KubeAid, as its part of the KubeAid monitoring setup (kube-prometheus).

* Need prometheus-operator and grafana-operator to be installed and running

## Deployments

* The value file only needs the customer-id and rest everything is fine, unless we want to change anything
  and all the settings are for all the customer, we can fix this easily with helm logics

## Dashboards

* The dashboard are copied over from upstream from these sources and are on latest master/main

node exporter: https://github.com/rfmoz/grafana-dashboards/blob/master/prometheus/node-exporter-full.json
haproxy: https://github.com/rfmoz/grafana-dashboards/blob/master/prometheus/haproxy-2-full.json
docker: https://gitea.obmondo.com/EnableIT/puppet/src/commit/e7f4b744f150345eebc2335929bfc6d6344276f9/envs/production/modules/include/customers/files/enableit/monitoring-stack/grafana/dashboards/obmondo_docker_dashboard.json
postgres: https://grafana.com/oss/prometheus/exporters/postgres-exporter/?tab=dashboards
mysql: https://github.com/percona/grafana-dashboards/blob/main/dashboards/MySQL/MySQL_Query_Response_Time_Details.json

* The dashboard are added as (gzipJson](https://grafana.github.io/grafana-operator/docs/examples/dashboard_gzipped/readme/)

  * WHY ? helm template consider some dashboard function as templateble
    and tries to parse it and fails, and yaml string `| or >` didn't worked for me.

  ```sh
  # cat /tmp/dashboard.json | gzip | base64 -w0
  # cat /tmp/posgres.json | gzip | base64 -w0 | xclip -selection clipboard -i
  ```

## Alert Validation Requirement

If you want to connect this Prometheus instance to `Opsmondo`, set `connect_obmondo: true` and configure the subscribed `subscribed-certname` (the full certname) and `customerid` in `values.yaml`:

```yaml
prometheus:
  connect_obmondo: true
  subscribed-certname: <your-subscribed-certname> # e.g., "puppetserver-gn.7e..."
  customerid: <your-customer-id> # e.g., "7e..."
```


## TODO

* validate dashboard maybe ?
* allow customer to add their own dashboard (this is should be top prio)
* promtool rule validate
* grafana pvc is not supported https://github.com/grafana/grafana-operator/issues/296
* grafana resource as well, the crd seems to be little broken when grafana guys migrated from v4 to v5

## How to test new rule

```sh
cd argocd-helm-charts/prometheus-linuxaid

docker run -ti --rm -v $(pwd):/etc/prometheus/:ro --entrypoint /bin/promtool prom/prometheus test rules /etc/prometheus/tests/${NEW_RULE}.yaml
```

## Steps to create new alert for servers

* add alert rule and test files in `rules` and `tests` directory in [`argocd-helm-charts/prometheus-linuxaid`](../prometheus-linuxaid/)
* add `PrometheusRule` template in [`argocd-helm-charts/prometheus-linuxaid/templates`](./templates/)
* enable the monitoring in LinuxAid in
[`modules/enableit/monitor/manifests/system`](https://gitea.obmondo.com/EnableIT/LinuxAid/src/branch/master/modules/enableit/monitor/manifests/system) by creating a
new file f.ex [dns.pp](https://gitea.obmondo.com/EnableIT/LinuxAid/src/branch/master/modules/enableit/monitor/manifests/system/dns.pp)(if it doesn't exist)
* set prometheusRule value to true in value file, f.ex [for dns alerts](https://gitea.obmondo.com/EnableIT/KubeAid/src/branch/master/argocd-helm-charts/prometheus-linuxaid/values.yaml#L28)

## Backing up prometheus data

We highly encourage creating regular backups of your Prometheus data to protect against data loss in the event of an unrecoverable failure in your monitoring deployment. 
Without proper backups, there is always a risk of losing valuable metrics and historical data.

For backup and restore operations, we support and recommend using Velero, a reliable solution for backing up Kubernetes resources and persistent volumes.
