{
  local clusterVariableQueryString = if $._config.showMultiCluster then '?var-%(clusterLabel)s={{ $labels.%(clusterLabel)s }}' % $._config else '',
  prometheusAlerts+:: {
    groups+: std.prune([
      if $._config.alerts.budget.enabled then {
        name: 'opencost',
        rules: [
          {
            alert: 'OpenCostMonthlyBudgetExceeded',
            expr: |||
              (
                sum(
                  node_total_hourly_cost{
                    %(openCostSelector)s
                  }
                ) by (%(clusterLabel)s) * 730
                or vector(0)
                +
                sum(
                  sum(
                    kube_persistentvolume_capacity_bytes{
                      %(openCostSelector)s
                    }
                    / 1024 / 1024 / 1024
                  ) by (%(clusterLabel)s, persistentvolume)
                  *
                  sum(
                    pv_hourly_cost{
                      %(openCostSelector)s
                    }
                  ) by (%(clusterLabel)s, persistentvolume)
                ) * 730
                or vector(0)
              )
              > %(monthlyCostThreshold)s
            ||| % ($._config { monthlyCostThreshold: $._config.alerts.budget.monthlyCostThreshold }),
            labels: {
              severity: 'warning',
            },
            'for': '30m',
            annotations: {
              summary: 'OpenCost Monthly Budget Exceeded',
              description: 'The monthly budget for the cluster has been exceeded. Consider scaling down resources or increasing the budget.',
              dashboard_url: $._config.dashboardUrls['opencost-overview'] + clusterVariableQueryString,
            },
          },
          {
            alert: 'OpenCostAnomalyDetected',
            expr: |||
              (
                (
                  (
                    avg_over_time(
                      sum(
                        node_total_hourly_cost{
                          %(openCostSelector)s
                        }
                      ) by (%(clusterLabel)s) [3h:30m]
                    )
                    or vector(0)
                  )
                  +
                  (
                    avg_over_time(
                      sum(
                        (
                          kube_persistentvolume_capacity_bytes{
                            %(openCostSelector)s
                          } / 1024 / 1024 / 1024
                        )
                        * on (%(clusterLabel)s, persistentvolume)
                        group_left()
                        pv_hourly_cost{
                          %(openCostSelector)s
                        }
                      ) by (%(clusterLabel)s) [3h:30m]
                    )
                    or vector(0)
                  )
                )
                -
                (
                  (
                    avg_over_time(
                      sum(
                        node_total_hourly_cost{
                          %(openCostSelector)s
                        }
                      ) by (%(clusterLabel)s) [7d:30m]
                    )
                    or vector(0)
                  )
                  +
                  (
                    avg_over_time(
                      sum(
                        (
                          kube_persistentvolume_capacity_bytes{
                            %(openCostSelector)s
                          } / 1024 / 1024 / 1024
                        )
                        * on (%(clusterLabel)s, persistentvolume)
                        group_left()
                        pv_hourly_cost{
                          %(openCostSelector)s
                        }
                      ) by (%(clusterLabel)s) [7d:30m]
                    )
                    or vector(0)
                  )
                )
              )
              /
              (
                (
                  (
                    avg_over_time(
                      sum(
                        node_total_hourly_cost{
                          %(openCostSelector)s
                        }
                      ) by (%(clusterLabel)s) [7d:30m]
                    )
                    or vector(0)
                  )
                  +
                  (
                    avg_over_time(
                      sum(
                        (
                          kube_persistentvolume_capacity_bytes{
                            %(openCostSelector)s
                          } / 1024 / 1024 / 1024
                        )
                        * on (%(clusterLabel)s, persistentvolume)
                        group_left()
                        pv_hourly_cost{
                          %(openCostSelector)s
                        }
                      ) by (%(clusterLabel)s) [7d:30m]
                    )
                    or vector(0)
                  )
                )
              )
              > (%(anomalyPercentageThreshold)s / 100)
            ||| % ($._config { anomalyPercentageThreshold: $._config.alerts.anomaly.anomalyPercentageThreshold }),
            labels: {
              severity: 'warning',
            },
            'for': '10m',
            annotations: {
              summary: 'OpenCost Cost Anomaly Detected',
              description: 'A significant increase in cluster costs has been detected. The average hourly cost over the 3 hours exceeds the 7-day average by more than %s%%. This could indicate unexpected resource usage or cost-related changes in the cluster.' % $._config.alerts.anomaly.anomalyPercentageThreshold,
              dashboard_url: $._config.dashboardUrls['opencost-overview'] + clusterVariableQueryString,
            },
          },
        ],
      },
    ]),
  },
}
