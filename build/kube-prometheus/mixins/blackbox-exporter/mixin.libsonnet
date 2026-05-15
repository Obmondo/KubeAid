{
  _config+:: {
    selector: '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'blackbox-exporter.rules',
        rules: [
          // =========================
          // HTTP AVAILABILITY
          // =========================
          {
            alert: 'BlackboxHttpEndpointDown',
            expr: 'probe_success == 0',
            'for': '5m',
            labels: {
              severity: 'critical',
              alert_id: 'blackbox_http_endpoint_down',
            },
            annotations: {
              summary: 'HTTP endpoint is down.',
              description: 'Probe to **{{ .Labels.instance }}** is failing.',
            },
          },
          {
            alert: 'BlackboxHttp5xxErrors',
            expr: 'probe_http_status_code >= 500',
            'for': '10m',
            labels: {
              severity: 'critical',
              alert_id: 'blackbox_http_5xx',
            },
            annotations: {
              summary: 'HTTP 5xx responses detected.',
              description: '**{{ .Labels.instance }}** is returning server errors with HTTP status code: {{ .Value }}',
            },
          },
          // =========================
          // TLS ALERTS
          // =========================
          {
            alert: 'BlackboxTlsCertificateExpiring',
            expr: 'probe_ssl_earliest_cert_expiry - time() < 15 * 24 * 3600',
            'for': '10m',
            labels: {
              severity: 'warning',
              alert_id: 'blackbox_tls_expiring',
            },
            annotations: {
              summary: 'TLS certificate nearing expiry.',
              description: 'TLS cert for **{{ .Labels.instance }}** expires in less than 15 days.',
            },
          },

          {
            alert: 'BlackboxTlsCertificateExpiringSoon',
            expr: 'probe_ssl_earliest_cert_expiry - time() < 7 * 24 * 3600',
            'for': '10m',
            labels: {
              severity: 'critical',
              alert_id: 'blackbox_tls_expiring_soon',
            },
            annotations: {
              summary: 'TLS certificate expiring soon.',
              description: 'TLS cert for **{{ .Labels.instance }}** expires in less than 7 days.',
            },
          },

          // =========================
          // LATENCY
          // =========================
          {
            alert: 'BlackboxHighLatency',
            expr: 'probe_duration_seconds > 2',
            'for': '10m',
            labels: {
              severity: 'warning',
              alert_id: 'blackbox_high_latency',
            },
            annotations: {
              summary: 'High response latency detected.',
              description: '**{{ .Labels.instance }}** is responding slowly (~{{ .Value }} seconds).',
            },
          },

          {
            alert: 'BlackboxVeryHighLatency',
            expr: 'probe_duration_seconds > 5',
            'for': '5m',
            labels: {
              severity: 'critical',
              alert_id: 'blackbox_very_high_latency',
            },
            annotations: {
              summary: 'Very high latency detected.',
              description: '**{{ .Labels.instance }}** latency is critically high (~{{ .Value}} seconds).',
            },
          },

          // =========================
          // REDIRECT ISSUES
          // =========================
          {
            alert: 'BlackboxTooManyRedirects',
            expr: 'probe_http_redirects > 5',
            'for': '10m',
            labels: {
              severity: 'warning',
              alert_id: 'blackbox_redirect_loop',
            },
            annotations: {
              summary: 'Too many HTTP redirects.',
              description: '**{{ .Labels.instance }}** may have a redirect loop.',
            },
          },

          // =========================
          // DNS
          // =========================
          {
            alert: 'BlackboxDnsResolutionFailure',
            expr: 'probe_dns_lookup_time_seconds == 0 and probe_success == 0',
            'for': '5m',
            labels: {
              severity: 'critical',
              alert_id: 'blackbox_dns_failure',
            },
            annotations: {
              summary: 'DNS resolution failed.',
              description: 'DNS lookup failed for **{{ .Labels.instance }}**.',
            },
          },

          {
            alert: 'BlackboxSlowDnsResolution',
            expr: 'probe_dns_lookup_time_seconds > 1',
            'for': '10m',
            labels: {
              severity: 'warning',
              alert_id: 'blackbox_dns_slow',
            },
            annotations: {
              summary: 'Slow DNS resolution.',
              description: '**{{ .Labels.instance }}** DNS lookup is slow (~{{ .Value }} seconds).',
            },
          },
        ],
      },
    ],
  },
}
