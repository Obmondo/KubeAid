# Mixins

## Overview

Mixins provide Prometheus alerting rules and Grafana dashboards. There are two kinds:

- **Upstream mixins** — installed via `jb` from external repos (e.g. ceph, opensearch, sealed-secrets). These live in `libraries/<version>/vendor/`.
- **Local mixins** — custom rules maintained in `mixins/` (e.g. velero, argo-cd, zfs).

Both types are wired into the build via `addMixin()` calls in `common-template.jsonnet` and toggled per cluster via the `addMixins` field in the cluster vars file.

## Enabling/disabling a mixin

In your cluster vars file (`<cluster-name>-vars.jsonnet`):

```jsonnet
addMixins: {
  ceph: true,
  velero: false,
  opensearch: true,
  'cert-manager': true,
},
```

See `lib/default_vars.libsonnet` for the full list of defaults.

## Skipping alerts per cluster

Two settings in the cluster vars file:

- `alert_namespace_selector` adds a PromQL matcher to the kubernetes-mixin's app, resource and storage alerts (pod, deployment, job, quota and volume alerts). The default `null` alerts on every namespace.
- `excluded_alerts` drops the named alerts from every rule the build renders, kube-prometheus and mixins alike. The default `[]` keeps them all.

```jsonnet
alert_namespace_selector: 'namespace!~"dev-.*"',
excluded_alerts: ['KubeJobNotCompleted'],
```

To skip an alert only in some namespaces or for some labels, use an Alertmanager route instead.

## kube-controller-manager and kube-scheduler on kubeadm

kubeadm binds both to `127.0.0.1`. KubeAid's cluster templates keep that default. Prometheus scrapes the node IP, so the scrape can never succeed. On `platform: 'kubeadm'` the build therefore:

- leaves out both ServiceMonitors and their `*-prometheus-discovery` Services
- replaces the up-based alerts (`KubeControllerManagerDown`, `KubeControllerManagerInstanceUnreachable`, `KubeSchedulerDown`, `KubeSchedulerInstanceUnreachable`) with `KubeControllerManagerNoLeader` and `KubeSchedulerNoLeader`. These fire when nobody has renewed the component's leader lease (`kube_lease_renew_time` from kube-state-metrics) for 2 minutes.

A single instance that keeps failing its liveness probe still shows up as `KubePodCrashLooping`.

On a cluster that binds them to a reachable address, `scrape_controller_manager_and_scheduler: true` keeps the scrape and the upstream alerts.

## Updating an upstream mixin

Use `update-mixin.sh` to pull the latest version of an upstream mixin:

```sh
# Update a single mixin
./build/kube-prometheus/update-mixin.sh ceph-mixin

# Update all direct dependencies
./build/kube-prometheus/update-mixin.sh --all

# List available mixin names
./build/kube-prometheus/update-mixin.sh --list
```

## Adding a new upstream mixin

Three files need a one-line addition each:

### 1. `setup-version.sh` — add the `jb install` line

Add after the existing installs:

```bash
jb install "github.com/<org>/<repo>/<path-to-mixin>@main"
```

### 2. `common-template.jsonnet` — add an `addMixin()` call

Add inside the `mixins` array:

```jsonnet
addMixin(
  '<toggle-name>',
  (import 'github.com/<org>/<repo>/<path-to-mixin>/mixin.libsonnet'),
  vars,
),
```

The import path is the vendor path to `mixin.libsonnet`. The toggle name must match the key you add in step 3.

### 3. `lib/default_vars.libsonnet` — add a default toggle

Add inside the `addMixins` object:

```jsonnet
'<toggle-name>': false,
```

### 4. Install the dependency in existing version directories

For each version that needs the mixin:

```sh
cd build/kube-prometheus/libraries/v0.17.0
jb install "github.com/<org>/<repo>/<path-to-mixin>@main"
```

Or delete the version directory and re-run `setup-version.sh`.

## Adding a custom Prometheus rule as a local mixin

1. Create a folder under `mixins/` with a `mixin.libsonnet` file.
2. Add an `addMixin()` call in `common-template.jsonnet` importing it.
3. Add a default toggle in `lib/default_vars.libsonnet`.

### Validating rules

Generate and check the rule file:

```sh
jsonnet -e '(import "mixin.libsonnet").prometheusAlerts' | gojsontoyaml > prometheus.yaml
promtool check rules prometheus.yaml
```

Run unit tests if you have a test file:

```sh
promtool test rules build/kube-prometheus/mixins/<mixin-name>/test.yaml
```

### Testing on a cluster

The actual rules are generated into your kubeaid-config repo via `build.sh`. To test whether an alert fires, apply the generated YAML:

```sh
kubectl apply -f <path-to-alert-rules>.yaml -n monitoring
```
