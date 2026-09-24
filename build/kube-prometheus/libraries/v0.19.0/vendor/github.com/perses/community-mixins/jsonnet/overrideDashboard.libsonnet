local overrideDashboard(dashboard, namespace, commonLabels, newDatasource) =
  dashboard {
    metadata+: {
      namespace: namespace,
      labels: dashboard.metadata.labels + commonLabels,
    },

    spec+: {
      config+: {
        panels: {
          [panelKey]: dashboard.spec.config.panels[panelKey] {
            spec+: if std.objectHas(dashboard.spec.config.panels[panelKey].spec, 'queries') then {
              queries: [
                query {
                  spec+: {
                    plugin+: {
                      spec+: {
                        datasource+: {
                          name: newDatasource,
                        },
                      },
                    },
                  },
                }
                for query in dashboard.spec.config.panels[panelKey].spec.queries
              ],
            } else {},
          }
          for panelKey in std.objectFields(dashboard.spec.config.panels)
        },

        variables: if std.objectHas(dashboard.spec.config, 'variables') then [
          variable {
            spec+: {
              plugin+: {
                spec+: {
                  datasource+: {
                    name: newDatasource,
                  },
                },
              },
            },
          }
          for variable in dashboard.spec.config.variables
        ] else [],
      },
    },
  };
{
  overrideDashboard: overrideDashboard,
}
