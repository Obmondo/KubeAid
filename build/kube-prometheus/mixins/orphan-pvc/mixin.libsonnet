// KubeDetectOrphanPvc fires one alert per cluster when one or more PVCs are Bound
// but not mounted by any running Pod.
{
  _config+:: {
    selector: '',
  },

  // Uses argocd_app_info's dest_namespace directly; kubeaidManagedApps only has the app name,
  // which isn't always the namespace (e.g. netbird-operator -> netbird, or several apps -> kube-system).
  local kubeaidAppsFilter =
    'label_replace(argocd_app_info{project="kubeaid"}, "namespace", "$1", "dest_namespace", "(.*)")',
  local kubeaidAppsFilterEscaped =
    'label_replace(argocd_app_info{project=\\"kubeaid\\"}, \\"namespace\\", \\"$1\\", \\"dest_namespace\\", \\"(.*)\\")',

  local pvcList =
    '{{ range $i, $r := query (printf "group by (cluster, namespace, persistentvolumeclaim) ('
    + 'kube_persistentvolumeclaim_status_phase{phase=\\"Bound\\",cluster=\\"%s\\"} == 1'
    + ' unless on(persistentvolumeclaim, namespace) kube_pod_spec_volumes_persistentvolumeclaims_info'
    + ') and on(namespace) ' + kubeaidAppsFilterEscaped
    + ')" $labels.cluster) | sortByLabel "persistentvolumeclaim" | sortByLabel "namespace" }}'
    + '{{ if $i }}, {{ end }}`{{ $r.Labels.namespace }}/{{ $r.Labels.persistentvolumeclaim }}`'
    + '{{ end }}',

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
                and on(namespace) %s
              ) > 0
            ||| % kubeaidAppsFilter,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'PersistentVolumeClaims are bound but not used by any Pod.',
              description:
                '{{ if eq $value 1.0 }}**1 PVC**{{ else }}**{{ $value }} PVCs**{{ end }}'
                + '{{ if $labels.cluster }} on cluster **{{ $labels.cluster }}**{{ end }}'
                + '{{ if eq $value 1.0 }} has{{ else }} have{{ end }} been Bound but not mounted by any Pod for at least 1 hour.'
                + '{{ if eq $value 1.0 }} It may be an orphaned volume{{ else }} They may be orphaned volumes{{ end }} consuming storage unnecessarily.'
                + ' Orphaned {{ if eq $value 1.0 }}PVC{{ else }}PVCs{{ end }}: ' + pvcList + '.',
            },
          },
        ],
      },
    ],
  },
}
