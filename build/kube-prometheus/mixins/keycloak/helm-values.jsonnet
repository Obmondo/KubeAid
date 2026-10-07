// Renders the alerts as a flat `prometheusRule.rules` list (e.g. codecentric/keycloakx chart).
local mixin = import 'mixin.libsonnet';
std.manifestYamlDoc({
  prometheusRule: {
    enabled: true,
    labels: { release: 'prometheus' },  // must match your Prometheus ruleSelector
    rules: std.flattenArrays([g.rules for g in mixin.prometheusAlerts.groups]),
  },
}, quote_keys=false)
