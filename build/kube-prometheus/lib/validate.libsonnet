// Validates a vars object before the template is compiled.
// Returns an array of error strings. Empty array means valid.
//
// Usage in common-template.jsonnet:
//   local validate = import 'lib/validate.libsonnet';
//   local errors = validate(vars);
//   assert std.length(errors) == 0 :
//     '\n\nVars validation failed:\n' + std.join('\n', ['  - ' + e for e in errors]);

function(vars)
  local check(condition, msg) = if !condition then msg else null;

  local errors = std.filter(
    function(e) e != null,
    [
      // ── always required ────────────────────────────────────────────────

      check(
        std.objectHas(vars, 'platform'),
        'platform is required (one of: kops, kubeadm, gke, eks, aks)',
      ),

      if std.objectHas(vars, 'platform') then
        check(
          std.member(['kops', 'kubeadm', 'gke', 'eks', 'aks'], vars.platform),
          'platform must be one of: kops, kubeadm, gke, eks, aks (got: "%s")' % vars.platform,
        ),

      // ── grafana_keycloak_enable: true requires related fields ─────────

      if std.get(vars, 'grafana_keycloak_enable', false) then
        check(
          std.objectHas(vars, 'grafana_keycloak_url') && vars.grafana_keycloak_url != '',
          'grafana_keycloak_url is required when grafana_keycloak_enable is true',
        ),

      if std.get(vars, 'grafana_keycloak_enable', false) then
        check(
          std.objectHas(vars, 'grafana_keycloak_realm') && vars.grafana_keycloak_realm != '',
          'grafana_keycloak_realm is required when grafana_keycloak_enable is true',
        ),

      if std.get(vars, 'grafana_keycloak_enable', false) then
        check(
          std.objectHas(vars, 'grafana_root_url') && vars.grafana_root_url != '',
          'grafana_root_url is required when grafana_keycloak_enable is true',
        ),

      // ── type checks ───────────────────────────────────────────────────

      if std.objectHas(vars, 'addMixins') then
        check(
          std.type(vars.addMixins) == 'object',
          'addMixins must be an object (got: %s)' % std.type(vars.addMixins),
        ),

      if std.objectHas(vars, 'prometheus_scrape_namespaces') then
        check(
          std.type(vars.prometheus_scrape_namespaces) == 'array',
          'prometheus_scrape_namespaces must be an array',
        ),

      if std.objectHas(vars, 'prometheus_scrape_default_namespaces') then
        check(
          std.type(vars.prometheus_scrape_default_namespaces) == 'array',
          'prometheus_scrape_default_namespaces must be an array',
        ),

      if std.objectHas(vars, 'etcd_metrics') then
        check(
          std.type(vars.etcd_metrics) == 'object',
          'etcd_metrics must be an object',
        ),

      if std.objectHas(vars, 'etcd_metrics') && std.objectHas(vars.etcd_metrics, 'endpoints') then
        check(
          std.type(vars.etcd_metrics.endpoints) == 'array',
          'etcd_metrics.endpoints must be an array',
        ),

      if std.objectHas(vars, 'loki') then
        check(
          std.type(vars.loki) == 'object',
          'loki must be an object (got: %s)' % std.type(vars.loki),
        ),

      if std.objectHas(vars, 'loki') && std.type(vars.loki) == 'object' && std.objectHas(vars.loki, 'enable') then
        check(
          std.type(vars.loki.enable) == 'boolean',
          'loki.enable must be true or false',
        ),

      if std.objectHas(vars, 'loki') && std.type(vars.loki) == 'object' && std.objectHas(vars.loki, 'tenants') then
        check(
          std.type(vars.loki.tenants) == 'array',
          'loki.tenants must be an array of tenant names',
        ),

      if std.objectHas(vars, 'loki') && std.type(vars.loki) == 'object' && std.objectHas(vars.loki, 'tenants') && std.type(vars.loki.tenants) == 'array' then
        local names = std.filter(function(t) std.type(t) == 'string' && t != '', vars.loki.tenants);
        if std.length(names) != std.length(vars.loki.tenants) then
          'loki.tenants must only contain tenant names (non-empty strings)'
        else
          check(
            std.length(std.set(names)) == std.length(names),
            'loki.tenants has duplicate names',
          ),

      if std.objectHas(vars, 'loki') && std.type(vars.loki) == 'object' && std.objectHas(vars.loki, 'settings') then
        check(
          std.type(vars.loki.settings) == 'object',
          'loki.settings must be an object',
        ),

      // ── Alertmanager config rendered from vars ────────────────────────

      if std.get(vars, 'alertmanager_render_config', false) then
        check(
          std.get(vars, 'connect_obmondo', false),
          'alertmanager_render_config needs connect_obmondo: true',
        ),

      if std.objectHas(vars, 'alertmanager_extra_routes') then
        check(
          std.type(vars.alertmanager_extra_routes) == 'array',
          'alertmanager_extra_routes must be an array of routes',
        ),

      if std.type(std.get(vars, 'alertmanager_extra_routes', [])) == 'array' &&
         std.length(std.get(vars, 'alertmanager_extra_routes', [])) > 0 then
        check(
          std.get(vars, 'alertmanager_render_config', false),
          'alertmanager_extra_routes needs alertmanager_render_config: true',
        ),

    ]
  );

  errors
