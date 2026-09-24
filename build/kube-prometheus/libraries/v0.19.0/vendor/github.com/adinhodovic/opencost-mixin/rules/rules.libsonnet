{
  prometheusRules+:: {
    groups+: [
      {
        name: 'opencost.rules.workload',
        interval: '5m',
        rules: [
          {
            record: 'workload:opencost_ram_cost:sum',
            expr: |||
              sum by (%(clusterLabel)s, %(namespaceLabel)s, workload_type, workload) (
                (
                  sum by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, %(instanceLabel)s) (container_memory_allocation_bytes)
                  * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                  (avg by (%(clusterLabel)s, %(instanceLabel)s) (node_ram_hourly_cost) / 1024 / 1024 / 1024)
                )
                * on(%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s) group_left(workload_type, workload)
                max by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, workload_type, workload) (namespace_workload_pod:kube_pod_owner:relabel)
              )
            ||| % $._config,
          },
          {
            record: 'workload:opencost_cpu_cost:sum',
            expr: |||
              sum by (%(clusterLabel)s, %(namespaceLabel)s, workload_type, workload) (
                (
                  sum by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, %(instanceLabel)s) (container_cpu_allocation)
                  * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                  avg by (%(clusterLabel)s, %(instanceLabel)s) (node_cpu_hourly_cost)
                )
                * on(%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s) group_left(workload_type, workload)
                max by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, workload_type, workload) (namespace_workload_pod:kube_pod_owner:relabel)
              )
            ||| % $._config,
          },
          {
            record: 'workload:opencost_pvc_cost:sum',
            expr: |||
              sum by (%(clusterLabel)s, %(namespaceLabel)s, persistentvolumeclaim, workload_type, workload) (
                max by (%(clusterLabel)s, %(namespaceLabel)s, persistentvolumeclaim, workload_type, workload) (
                  max by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, persistentvolumeclaim) (kube_pod_spec_volumes_persistentvolumeclaims_info{%(kubeStateMetricsSelector)s})
                  * on(%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s) group_left(workload_type, workload)
                  max by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, workload_type, workload) (namespace_workload_pod:kube_pod_owner:relabel)
                )
                * on(%(clusterLabel)s, %(namespaceLabel)s, persistentvolumeclaim) group_left()
                sum by (%(clusterLabel)s, %(namespaceLabel)s, persistentvolumeclaim) (
                  (
                    sum by (%(clusterLabel)s, persistentvolume) (kube_persistentvolume_capacity_bytes{%(kubeStateMetricsSelector)s} / 1024 / 1024 / 1024)
                    * sum by (%(clusterLabel)s, persistentvolume) (pv_hourly_cost)
                  )
                  * on(%(clusterLabel)s, persistentvolume) group_left(persistentvolumeclaim, %(namespaceLabel)s)
                  max by (%(clusterLabel)s, persistentvolume, persistentvolumeclaim, %(namespaceLabel)s) (
                    label_replace(kube_persistentvolumeclaim_info{%(kubeStateMetricsSelector)s}, "persistentvolume", "$1", "volumename", "(.*)")
                  )
                )
              )
            ||| % $._config,
          },
          {
            record: 'workload:opencost_gpu_cost:sum',
            expr: |||
              sum by (%(clusterLabel)s, %(namespaceLabel)s, workload_type, workload) (
                (
                  sum by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, %(instanceLabel)s) (container_gpu_allocation)
                  * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                  avg by (%(clusterLabel)s, %(instanceLabel)s) (node_gpu_hourly_cost)
                )
                * on(%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s) group_left(workload_type, workload)
                max by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, workload_type, workload) (namespace_workload_pod:kube_pod_owner:relabel)
              )
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
