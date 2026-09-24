{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'perses-operator',
        rules: [
          {
            alert: 'PersesOperatorDown',
            expr: |||
              absent(up{%(persesOperatorSelector)s} == 1)
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              summary: 'Perses Operator is down.',
              description: 'Perses Operator has disappeared from Prometheus target discovery.',
            },
          },
          {
            alert: 'PersesOperatorNotReady',
            expr: |||
              min by (%(groupLabels)s) (max_over_time(perses_operator_ready{%(persesOperatorSelector)s}[5m]) == 0)
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Perses operator not ready',
              description: "Perses operator in {{ $labels.namespace }} namespace isn't ready to reconcile {{ $labels.controller }} resources.",
            },
          },
          {
            alert: 'PersesOperatorReconcileErrors',
            expr: |||
              sum by (%(groupLabels)s, reason) (rate(perses_operator_reconcile_errors_total{%(persesOperatorSelector)s}[5m]))
              / on(%(groupLabels)s) group_left()
              (sum by (%(groupLabels)s) (rate(perses_operator_reconcile_operations_total{%(persesOperatorSelector)s}[5m])) > 0)
              > 0.1
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Errors while reconciling objects.',
              description: '{{ $value | humanizePercentage }} of reconciling operations failed for {{ $labels.controller }} controller in {{ $labels.namespace }} namespace (reason: {{ $labels.reason }}).',
            },
          },
          {
            alert: 'PersesOperatorSyncFailed',
            expr: |||
              min_over_time(perses_operator_syncs{status="failed",%(persesOperatorSelector)s}[5m]) > 0
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Last controller reconciliation failed',
              description: 'Controller in {{ $labels.namespace }} namespace fails to reconcile {{ printf "%.0f" $value }} objects.',
            },
          },
          {
            alert: 'PersesOperatorValidationFailures',
            expr: |||
              sum by (%(groupLabels)s) (increase(perses_operator_reconcile_errors_total{reason="ValidationFailed",%(persesOperatorSelector)s}[15m])) > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Resources failing server-side validation.',
              description: '{{ $labels.controller }} controller in {{ $labels.namespace }} namespace has resources failing Perses server-side validation. Check resource status conditions for details.',
            },
          },
          {
            alert: 'PersesOperatorResourceSyncFailures',
            expr: |||
              min_over_time(perses_operator_managed_resources{state="failed",%(persesOperatorSelector)s}[5m]) > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Resources failing to sync by Perses operator',
              description: 'Perses operator in {{ $labels.namespace }} namespace has {{ printf "%.0f" $value }} {{ $labels.resource }} resources in failed state (resource namespace {{ $labels.resource_namespace }}).',
            },
          },
        ],
      },
    ],
  },
}
