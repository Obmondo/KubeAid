# kubeaid-addons

A Helm chart for managing firewall rules and common operator configurations per namespace - network policies,
database instances, message brokers, and any other shared infrastructure primitive. The idea is
simple: anything that is "common infrastructure" (CNPG, RabbitMQ, MariaDB, MongoDB, etc.) lives
here rather than being scattered across individual application charts.

## What does this chart do?

| Feature | Kind | Guard |
|---|---|---|
| Namespace-wide default-deny network policy | `CiliumNetworkPolicy` | `defaultDeny.enabled` |
| Per-component Cilium network policies | `CiliumNetworkPolicy` | `global.netpol.enabled` + component flag |
| CNPG PostgreSQL cluster + scheduled backup | `Cluster`, `ScheduledBackup` | `global.postgresql.enabled` |
| RabbitMQ cluster (via Cluster Operator) | `RabbitmqCluster` | `global.rabbitmq.enabled` |
| Argo CD baseline policy | `CiliumNetworkPolicy` | `global.netpol.enabled` + `global.argocd.netpol` |
| Harbor network policies | `CiliumNetworkPolicy` | `global.netpol.enabled` + `global.harbor.netpol` |

Everything is **nil-safe** - if a key is missing from values, the template renders nothing rather
than panicking. New operator types (MariaDB, MongoDB, etc.) can be added by dropping a new
template in `templates/`.

> **Private values live in `kubeaid-config` repo.**
> The chart ships with empty/disabled defaults. All environment-specific configuration lives in
> your `kubeaid-config` private repository.

## Setup

### 1. Standalone ArgoCD app (default-deny)

Create one `kubeaid-addons` ArgoCD Application per cluster. This app is responsible for rendering
the **namespace wide default deny policies** across all managed namespaces and for providing shared
FQDN values consumed by other charts.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeaid-addons
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: kubeaid-addons
  project: kubeaid
  sources:
    - repoURL: <your-repo-url>
      path: argocd-helm-charts/kubeaid-addons
      targetRevision: main
      helm:
        valueFiles:
          - <path-to-values-kubeaid-addons.yaml>
    - repoURL: <your-repo-url>
      targetRevision: main
      ref: values
  syncPolicy:
    syncOptions:
      - ApplyOutOfSyncOnly=true
      - CreateNamespace=true
```

The corresponding private values file contains **only the default-deny configuration**:

```yaml
# default-deny - one entry per namespace you want protected
defaultDeny:
  enabled: true
  namespaces:
    my-app-namespace: {}         # full deny, no exclusions
    another-namespace:
      excludedPods:
        - <label-key>: <label-value>   # pods matching this are excluded from the deny
```

### 2. As a subchart dependency (component netpols + infra)

For each application chart that needs network policies or operator resources, add `kubeaid-addons`
as a Helm dependency. This gives the application chart access to all network policy templates and
infrastructure primitives without duplicating logic.

**`Chart.yaml`**:
```yaml
dependencies:
  - name: my-app
    version: x.y.z
    repository: https://charts.example.com

  - name: kubeaid-addons
    version: 0.1.0
    repository: file://../kubeaid-addons
```

**Create a symlink** from the chart's `charts/` directory to the `kubeaid-addons` source:
```bash
ln -s ../../kubeaid-addons argocd-helm-charts/my-app/charts/kubeaid-addons
git add argocd-helm-charts/my-app/charts/kubeaid-addons
```

ArgoCD resolves the symlink directly, so any changes to `kubeaid-addons` templates are picked up without re-packaging.

**`values.yaml`** (chart-level defaults):
```yaml
global:
  netpol:
    enabled: false
  my-component:
    netpol: false
```

**Private values**:
```yaml
global:
  netpol:
    enabled: true
    releaseName: my-app
    traefik:
      namespace: traefik
      labels:
        app.kubernetes.io/name: traefik
        app.kubernetes.io/instance: traefik

  postgresql:
    enabled: true
    instanceName: my-app-pgsql
    size: 10Gi
    netpol: true
    clients:
      - labels:
          app.kubernetes.io/instance: my-app
          app.kubernetes.io/component: backend
```

## Enabling network policies

### Master switch

```yaml
global:
  netpol:
    enabled: true
    releaseName: <helm-release-name>
    traefik:
      namespace: traefik
      labels:
        app.kubernetes.io/name: traefik
        app.kubernetes.io/instance: traefik
```

### Per-component flags

```yaml
global:
  rabbitmq:
    netpol: true
  redis:
    netpol: true
  grafana:
    netpol: true
  engine:
    netpol: true
  celery:
    netpol: true
  whoami:
    netpol: true
  postgresql:
    netpol: true
  argocd:
    netpol: true
  harbor:
    netpol: true  
```

Argo CD baseline policy is configured under **`global.argocd`** plus shared **`global.netpol.traefik`** / **`global.netpol.prometheus`** (same pattern as whoami/oncall). Render it via a parent chart (for example `argo-cd`) that includes `kubeaid-addons` as a dependency; Helm only passes `global` into subcharts.

```yaml
global:
  netpol:
    enabled: true
    traefik:
      namespace: traefik
      labels:
        "k8s:app.kubernetes.io/name": traefik
        "k8s:app.kubernetes.io/instance": traefik
    prometheus:
      namespace: monitoring
      labels:
        "k8s:app.kubernetes.io/name": prometheus
  argocd:
    netpol: true
    namespace: argocd
    endpointSelectorLabels:
      app.kubernetes.io/part-of: argocd
    kubeaidAgent:
      namespace: monitoring
      labels:
        "k8s:app.kubernetes.io/name": kubeaid-agent
    # Optional: allow kube-prometheus blackbox-exporter probes to Argo (off unless you use that).
    blackboxExporter:
      enabled: false
      namespace: monitoring
      labels:
        "k8s:app.kubernetes.io/name": blackbox-exporter
```

## Adding a new operator resource type

1. Add a template in `templates/<resource>.yaml` guarded by `{{- if ((.Values.global).<type>).enabled }}`
2. Document the values keys in `values.yaml` with `# --` comments
3. Because dependent charts use a symlink, no re-packaging is needed - changes are picked up immediately

## Adding a new network policy template

1. Create `charts/network-policies/templates/networkpolicy-<component>.yaml`
2. Use the nil-safe guard:
   ```yaml
   {{- if and ((.Values.global).netpol).enabled ((.Values.global).<component>).netpol }}
   ```
   For Argo CD, the guard is `global.netpol.enabled` plus `global.argocd.netpol` (see `networkpolicy-argocd.yaml`).
3. Add `global.<component>.netpol: false` to the parent chart's `values.yaml` (for Argo CD use `global.argocd.netpol: false`)
4. Because dependent charts use a symlink, no re-packaging is needed - changes are picked up immediately