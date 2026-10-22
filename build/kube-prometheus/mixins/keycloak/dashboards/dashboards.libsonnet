// Wraps the upstream Keycloak dashboards (keycloak/keycloak-grafana-dashboard, Apache-2.0)
// so they are configurable and importable without the manual `__inputs` datasource prompt.
{
  grafanaDashboards+:: {
    local c = $._config,

    // Apply `f` to every string in a JSON document.
    local walk(v, f) =
      if std.isString(v) then f(v)
      else if std.isArray(v) then [walk(x, f) for x in v]
      else if std.isObject(v) then { [k]: walk(v[k], f) for k in std.objectFields(v) }
      else v,

    local dsRef = { type: 'prometheus', uid: '${%s}' % c.datasourceVar },

    local datasourceVariable = {
      name: c.datasourceVar,
      label: 'Data source',
      type: 'datasource',
      query: 'prometheus',
      regex: c.datasourceRegex,
      refresh: 1,
      hide: 0,
      includeAll: false,
      multi: false,
      current: {},
    },

    local transform(dash, uid) =
      local fixed = walk(dash, function(s)
        std.strReplace(
          std.strReplace(s, '${DS_PROMETHEUS}', '${%s}' % c.datasourceVar),
          'container="keycloak"',
          'container="%s"' % c.dashboardContainer
        ));
      fixed {
        uid: uid,
        tags: c.dashboardTags,
        refresh: c.dashboardRefresh,
        // Hidden: drop the import-time datasource prompt, we use a template variable instead.
        __inputs:: [],
        __requires:: [],
        templating+: {
          list: [datasourceVariable] + [
            // Upstream leaves some variable queries without a datasource.
            if v.type == 'query' && std.get(v, 'datasource', null) == null
            then v { datasource: dsRef }
            else v
            for v in super.list
          ],
        },
      },

    'keycloak-troubleshooting.json': transform(import 'keycloak-troubleshooting-dashboard.json', c.dashboardUids.troubleshooting),
    'keycloak-capacity-planning.json': transform(import 'keycloak-capacity-planning-dashboard.json', c.dashboardUids.capacityPlanning),
  },
}
