// KubeHpaMaxedOut alert that skips HPAs which cannot scale: min == max replicas
// (a fixed size, e.g. min=1, max=1) or max == 1 (e.g. KEDA scaling between 0 and 1).
{
  _config+:: {
    selector: '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-apps',
        rules: [
          {
            alert: 'KubeHpaMaxedOut',
            expr: |||
              kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}
                ==
              kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"}
                and
              kube_horizontalpodautoscaler_spec_min_replicas{job="kube-state-metrics"}
                !=
              kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"}
                and
              kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"} > 1
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler  }} has been running at max replicas for longer than 15 minutes on cluster {{ $labels.cluster }}.',
              runbook_url: 'https://runbooks.prometheus-operator.dev/runbooks/kubernetes/kubehpamaxedout',
              summary: 'HPA is running at max replicas.',
            },
          },
        ],
      },
    ],
  },
}
