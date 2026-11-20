{
  _config+:: {
    selector: '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'node-count-monthly-status',
        rules: [
          {
            alert: 'ClusterFailedToUpdateNodeCountThisMonth',
            expr: 'days_missing_node_count>0 AND days_missing_node_count<11',
            'for': '15m',
            labels: {
              severity: 'warning',
              alert_id: 'ClusterFailedToUpdateNodeCountThisMonth',
            },
            annotations: {
              description: 'The cluster **{{ .Labels.cluster_certname }}** has failed to update its node count for **{{ .Value }}** days this month. This can impact the process of calculating the average node count for the month.',
              summary: 'The cluster has not added their respective node counts to the DB for fewer than 10 days this month.',
            },
          },
          {
            alert: 'ClusterFailedToUpdateNodeCount',
            expr: 'days_missing_node_count>10',
            'for': '15m',
            labels: {
              severity: 'critical',
              alert_id: 'ClusterFailedToUpdateNodeCount',
            },
            annotations: {
              description: 'The cluster **{{ .Labels.cluster_certname }}** has failed to update its node count for over ten days this month ( **{{ .Value }}** ). This will have an impact on the average node count calculation for the month.',
              summary: 'The cluster has not added their respective node counts to the DB for more than 10 days this month.',
            },
          },
        ],
      },
    ],
  },
}
