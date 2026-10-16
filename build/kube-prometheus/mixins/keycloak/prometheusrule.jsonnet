// Renders the alerts as a PrometheusRule (prometheus-operator CRD).
local mixin = import 'mixin.libsonnet';
std.manifestYamlDoc({
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    name: 'keycloak-alerts',
    labels: { release: 'prometheus' },  // must match your Prometheus ruleSelector
  },
  spec: mixin.prometheusAlerts,
}, quote_keys=false)
