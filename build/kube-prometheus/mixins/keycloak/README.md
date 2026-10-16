# Keycloak mixin

A Prometheus/Grafana mixin for Keycloak using its **native** metrics (no Keycloak Metrics SPI).

- **Dashboards**: the upstream [keycloak-grafana-dashboard](https://github.com/keycloak/keycloak-grafana-dashboard)
  troubleshooting and capacity planning dashboards (commit `f819507`, Apache-2.0, see `dashboards/LICENSE`),
  wrapped so they use a `datasource` template variable instead of the import-time prompt, and so the
  container label, tags, refresh and UIDs are configurable.
- **Alerts**: availability, HTTP, logins, database pool and JVM (16 alerts).
- No recording rules, so no extra series are stored.

## Build

```bash
make            # needs `jsonnet` (go-jsonnet or C++); no dependencies to vendor
```

| Output | Use |
|---|---|
| `build/dashboards/*.json` | Import into Grafana, or provision via ConfigMap/sidecar |
| `build/prometheus_alerts.yaml` | Plain Prometheus rule file (`groups:`) |
| `build/prometheusrule.yaml` | prometheus-operator `PrometheusRule` |
| `build/helm-values.yaml` | Flat `prometheusRule.rules` list for the codecentric `keycloakx` chart |

Prebuilt outputs are included in `build/`.

## Configure

Override anything in `config.libsonnet` from your own jsonnet:

```jsonnet
(import 'mixin.libsonnet') + {
  _config+:: {
    keycloakSelector: 'job=~"keycloak-staging.*"',
    keycloakStatefulSetSelector: 'namespace="keycloak-staging", statefulset=~".*keycloak.*"',
    minLoginAttempts: 50,
  },
}
```

## Requirements

- `KC_METRICS_ENABLED=true`, scraped on the management port (9000).
- `KC_EVENT_METRICS_USER_ENABLED=true` (Keycloak 26+) for login alerts and the event panels.
- `KC_HTTP_METRICS_HISTOGRAMS_ENABLED=true` for latency alerts and SLO panels.
- kube-state-metrics for `KeycloakReplicasNotReady`.

## Alertmanager

The login warning also matches when the critical alert fires. Inhibit it:

```yaml
inhibit_rules:
  - source_matchers: [alertname = KeycloakLoginFailureRatioCritical]
    target_matchers: [alertname = KeycloakLoginFailureRatioHigh]
    equal: [realm, client_id]
```

## Known upstream assumptions

The upstream dashboards expect Kubernetes-style labels (`namespace`, `container`, `pod`). One panel pair also
uses a hardcoded job regex of the form `${namespace}/keycloak-metrics|keycloak-service`; if your job is named
differently (e.g. `keycloak-staging-keycloakx-http`) those panels will be empty and the regex needs adjusting
in `dashboards/*.json`.
