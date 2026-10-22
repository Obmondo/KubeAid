// alertmanager.yaml for clusters connected to Obmondo. Alerts that no route
// matches go to Obmondo's alert webhook over mTLS, using the client
// certificate the Alertmanager mounts from the obmondo-clientcert Secret.
// extraRoutes are checked after the built-in routes.
function(extraRoutes) {
  global: {
    resolve_timeout: '5m',
  },
  inhibit_rules: [
    {
      source_matchers: ['severity = critical'],
      target_matchers: ['severity =~ warning|info'],
      equal: ['namespace', 'alertname'],
    },
    {
      source_matchers: ['severity = warning'],
      target_matchers: ['severity = info'],
      equal: ['namespace', 'alertname'],
    },
    {
      source_matchers: ['alertname = InfoInhibitor'],
      target_matchers: ['severity = info'],
      equal: ['namespace'],
    },
  ],
  route: {
    group_by: ['namespace'],
    group_wait: '10s',
    group_interval: '10s',
    repeat_interval: '1h',
    receiver: 'obmondo',
    routes: [
      {
        receiver: 'obmondo',
        matchers: ['alertname = Watchdog'],
        repeat_interval: '5m',
      },
      {
        receiver: 'null',
        matchers: ['alertname = InfoInhibitor'],
      },
      {
        receiver: 'null',
        matchers: ['alertname =~ KubernetesVersionInfoEos|KubernetesVersionInfoEol'],
      },
    ] + extraRoutes,
  },
  receivers: [
    { name: 'null' },
    {
      name: 'obmondo',
      webhook_configs: [{
        url: 'https://alerts.obmondo.com/hooks/alertmanager',
        send_resolved: true,
        max_alerts: 0,
        http_config: {
          tls_config: {
            server_name: 'alerts.obmondo.com',
            cert_file: '/etc/alertmanager/secrets/obmondo-clientcert/tls.crt',
            key_file: '/etc/alertmanager/secrets/obmondo-clientcert/tls.key',
            insecure_skip_verify: false,
          },
        },
      }],
    },
  ],
  templates: ['/etc/alertmanager/config/*.tmpl'],
}
