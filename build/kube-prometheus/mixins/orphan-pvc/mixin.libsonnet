// KubeDetectOrphanPvc fires one alert per cluster when one or more PVCs are Bound
// but not mounted by any running Pod.
{
  _config+:: {
    selector: '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'orphan-pvc',
        rules: [
          {
            alert: 'KubeDetectOrphanPvc',
            expr: |||
              count by (cluster) (
                group by (cluster, namespace, persistentvolumeclaim) (
                  kube_persistentvolumeclaim_status_phase{phase="Bound"} == 1
                  unless on(persistentvolumeclaim, namespace)
                  kube_pod_spec_volumes_persistentvolumeclaims_info
                )
              ) > 0
            ||| % $._config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'PersistentVolumeClaims are bound but not used by any Pod.',
              description: |||
                One or more PVCs on cluster {{ $labels.cluster }} have been Bound but not mounted by any Pod for at least 1 hour. They may be orphaned volumes consuming storage unnecessarily.

                Orphaned PVCs by namespace:
                {{ $ns := "" }}{{ $pvcs := "" }}{{ range query (printf "group by (cluster, namespace, persistentvolumeclaim) (kube_persistentvolumeclaim_status_phase{phase=\"Bound\",cluster=\"%s\"} == 1 unless on(persistentvolumeclaim, namespace) kube_pod_spec_volumes_persistentvolumeclaims_info)" $labels.cluster) }}{{ if ne .Labels.namespace $ns }}{{ if ne $ns "" }} {namespace: {{ $ns }}, pvc: {{ $pvcs }}} {{ end }}{{ $ns = .Labels.namespace }}{{ $pvcs = .Labels.persistentvolumeclaim }}{{ else }}{{ $pvcs = printf "%s, %s" $pvcs .Labels.persistentvolumeclaim }}{{ end }}{{ end }}{{ if ne $ns "" }} {namespace: {{ $ns }}, pvc: {{ $pvcs }}} {{ end }}
              |||,
            },
          },
        ],
      },
    ],
  },
}
