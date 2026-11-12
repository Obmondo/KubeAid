// Modified version if 'addMixin' ('kube-prometheus/lib/mixin.libsonnet' in
// kube-prometheus) to avoid some unnecessary repetition.
local defaults = {
  namespace: 'monitoring',
  labels: {
    prometheus: 'k8s',
  },
};

// We could do the `import` here, but if there are any errors in the import
// we'll get a stack trace pointing to this generic import statement. For
// debugging purposes it's much easier to have the stack trace to point to the
// place of the import.
function(name, obj, config)
  if std.get(config.addMixins, name, false) then
    {
      _config:: defaults + config { name: name } + std.get(config.mixin_configs, name, {}),

      local m = self,
      local mixin = obj { _config+: m._config },

      local prometheusRules = if std.objectHasAll(mixin, 'prometheusRules') || std.objectHasAll(mixin, 'prometheusAlerts') then {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: name,
          labels: m._config.labels,
          namespace: m._config.namespace,
        },
        spec: {
          local r = if std.objectHasAll(mixin, 'prometheusRules') && std.objectHas(mixin.prometheusRules, 'groups') then mixin.prometheusRules.groups else [],
          local a = if std.objectHasAll(mixin, 'prometheusAlerts') && std.objectHas(mixin.prometheusAlerts, 'groups') then mixin.prometheusAlerts.groups else [],
          groups: a + r,
        },
      },

      // Each dashboard key becomes the name of a ConfigMap and of a Grafana
      // volume ('grafana-dashboard-<key>'), and Kubernetes only accepts
      // lowercase names there. Upstream mixins (e.g. cilium-enterprise-mixin)
      // ship keys like 'cilium-L3-policy.json', so lowercase them here.
      local lowercaseKeys(dashboards) = {
        [std.asciiLower(key)]: dashboards[key]
        for key in std.objectFields(dashboards)
      },

      local grafanaDashboards = if std.objectHasAll(mixin, 'grafanaDashboards') then (
        if std.objectHas(m._config, 'dashboardFolder') then {
          [m._config.dashboardFolder]+: lowercaseKeys(mixin.grafanaDashboards),
        } else lowercaseKeys(mixin.grafanaDashboards)
      ) else null,

      prometheusRules: prometheusRules,
      grafanaDashboards: grafanaDashboards,
      name: name,
    }
