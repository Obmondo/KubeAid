{
  _config+:: {
    selector: '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'traefik-client-errors',
        rules: [
          {
            alert: 'TraefikImmediateFailure',
            expr: |||
              (
                sum by (service, code) (rate(traefik_service_requests_total{code=~"400|403"}[5m]))
                / ignoring(code) group_left
                sum by (service) (rate(traefik_service_requests_total[5m])) * 100 > 5
              )
              and ignoring(code) (
                sum by (service) (rate(traefik_service_requests_total[5m])) * 60 > 20
              )
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'HTTP rejection spike detected.',
              description: "Service '{{ $labels.service }}' is rejecting requests with a {{ $labels.code }} status code (currently >5% of traffic). Investigate missing headers, bad auth, or WAF rules.",
            },
          },
          {
            alert: 'TraefikHigh4xxErrorRate',
            expr: |||
              (
                sum by (service, code) (rate(traefik_service_requests_total{code=~"4..", code!~"400|401|403"}[5m]))
                / ignoring(code) group_left
                sum by (service) (rate(traefik_service_requests_total[5m])) * 100 > 5
              )
              and ignoring(code) (
                sum by (service) (rate(traefik_service_requests_total[5m])) * 60 > 20
              )
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'High HTTP client error rate (4XX) detected.',
              description: "Service '{{ $labels.service }}' is experiencing a high rate (>5%) of {{ $labels.code }} errors. Investigate routing or client behavior.",
            },
          },
        ],
      },
    ],
  },
}
