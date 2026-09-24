local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboards = mixinUtils.dashboards;
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbFieldConfig = tablePanel.fieldConfig;
local tbOverride = tbStandardOptions.override;

{
  local dashboardName = 'opencost-namespace',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = std.prune([
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.opencostJob,
        defaultVariables.ksmJob,
        defaultVariables.namespace,
      ]);

      local defaultFilters = util.filters($._config);
      local queries = {
        monthlyRamCost: |||
          sum(
            sum(
              container_memory_allocation_bytes{
                %(opencostWithNamespace)s
              }
            )
            by (%(namespaceLabel)s, %(instanceLabel)s)
            * on(%(instanceLabel)s) group_left()
            (
              avg(
                node_ram_hourly_cost{
                  %(opencostDefault)s
                }
              ) by (%(instanceLabel)s) / (1024 * 1024 * 1024) * 730
            )
          )
        ||| % defaultFilters,

        monthlyCpuCost: |||
          sum(
            sum(
              container_cpu_allocation{
                %(opencostWithNamespace)s
              }
            )
            by (%(namespaceLabel)s, %(instanceLabel)s)
            * on(%(instanceLabel)s) group_left()
            (
              avg(
                node_cpu_hourly_cost{
                  %(opencostDefault)s
                }
              ) by (%(instanceLabel)s) * 730
            )
          )
        ||| % defaultFilters,

        monthlyPVCost: |||
          sum(
            sum(
              kube_persistentvolume_capacity_bytes{
                %(ksmDefault)s
              }
              / (1024 * 1024 * 1024)
            ) by (persistentvolume)
            *
            sum(
              pv_hourly_cost{
                %(opencostDefault)s
              }
            ) by (persistentvolume)
            * on(persistentvolume) group_left(%(clusterLabel)s, %(namespaceLabel)s, persistentvolumeclaim) (
              label_replace(
                kube_persistentvolumeclaim_info{
                  %(ksmWithNamespace)s
                },
                "persistentvolume", "$1",
                "volumename", "(.*)"
              )
            )
          ) * 730
        ||| % defaultFilters,

        monthlyPVNoNilCost: |||
          sum(
            sum(
              kube_persistentvolume_capacity_bytes{
                %(ksmDefault)s
              }
              / (1024 * 1024 * 1024)
            ) by (persistentvolume)
            *
            sum(
              pv_hourly_cost{
                %(opencostDefault)s
              }
            ) by (persistentvolume)
            * on(persistentvolume) group_left(%(clusterLabel)s, %(namespaceLabel)s, persistentvolumeclaim) (
              label_replace(
                kube_persistentvolumeclaim_info{
                  %(ksmWithNamespace)s
                },
                "persistentvolume", "$1",
                "volumename", "(.*)"
              )
            ) or vector(0)
          ) * 730
        ||| % defaultFilters,

        monthlyGPUCost: |||
          sum(
            sum(
              container_gpu_allocation{
                %(opencostWithNamespace)s
              }
            )
            by (%(namespaceLabel)s, %(instanceLabel)s)
            * on(%(instanceLabel)s) group_left()
            (
              avg(
                node_gpu_hourly_cost{
                  %(opencostDefault)s
                }
              ) by (%(instanceLabel)s) * 730
            )
          )
        ||| % defaultFilters,

        monthlyCost: |||
          %s
          +
          %s
          +
          %s
          +
          %s
        ||| % [queries.monthlyRamCost, queries.monthlyCpuCost, queries.monthlyGPUCost, queries.monthlyPVNoNilCost],
        hourlyCost: std.strReplace(queries.monthlyCost, ') * 730', ') * 1'),

        // Keep job label formatting inconsistent due to strReplace
        podMonthlyCost: |||
          topk(10,
            sum(
              (
                sum(
                  container_memory_allocation_bytes{
                    %(opencostWithNamespace)s
                  }
                )
                by (%(instanceLabel)s, %(podLabel)s)
                * on(%(instanceLabel)s) group_left()
                (
                  avg(
                    node_ram_hourly_cost{
                      %(opencostDefault)s
                    }
                  ) by (%(instanceLabel)s) / (1024 * 1024 * 1024) * 730
                )
              )
              +
              (
                sum(
                  container_cpu_allocation{
                    %(opencostWithNamespace)s
                  }
                )
                by (%(instanceLabel)s, %(podLabel)s)
                * on(%(instanceLabel)s) group_left()
                (
                  avg(
                    node_cpu_hourly_cost{
                      %(opencostDefault)s
                    }
                  ) by (%(instanceLabel)s) * 730)
              )
            ) by (%(podLabel)s)
          )
        ||| % defaultFilters,
        podMonthlyCostOffset7d: std.strReplace(queries.podMonthlyCost, '}', '} offset 7d'),
        podMonthlyCostOffset30d: std.strReplace(queries.podMonthlyCost, '}', '} offset 30d'),

        podMonthlyCostDifference7d: |||
          %s
          /
          %s
          * 100
          - 100
        ||| % [
          queries.podMonthlyCost,
          queries.podMonthlyCostOffset7d,
        ],
        podMonthlyCostDifference30d: |||
          %s
          /
          %s
          * 100
          - 100
        ||| % [
          queries.podMonthlyCost,
          queries.podMonthlyCostOffset30d,
        ],

        containerMonthlyCost: |||
          topk(10,
            sum(
              (
                sum(
                  container_memory_allocation_bytes{
                    %(opencostWithNamespace)s
                  }
                )
                by (%(instanceLabel)s, %(containerLabel)s)
                * on(%(instanceLabel)s) group_left()
                (
                  avg(
                    node_ram_hourly_cost{
                      %(opencostDefault)s
                    }
                  ) by (%(instanceLabel)s) / (1024 * 1024 * 1024) * 730
                )
              )
              +
              (
                sum(
                  container_cpu_allocation{
                    %(opencostWithNamespace)s
                  }
                )
                by (%(instanceLabel)s, %(containerLabel)s)
                * on(%(instanceLabel)s) group_left()
                (
                  avg(
                    node_cpu_hourly_cost{
                      %(opencostDefault)s
                    }
                  ) by (%(instanceLabel)s) * 730
                )
              )
            ) by (%(containerLabel)s)
          )
        ||| % defaultFilters,
        containerMonthlyCostOffset7d: std.strReplace(queries.containerMonthlyCost, '}', '} offset 7d'),
        containerMonthlyCostOffset30d: std.strReplace(queries.containerMonthlyCost, '}', '} offset 30d'),
        containerMonthlyCostDifference7d: |||
          %s
          /
          %s
          * 100
          - 100
        ||| % [
          queries.containerMonthlyCost,
          queries.containerMonthlyCostOffset7d,
        ],
        containerMonthlyCostDifference30d: |||
          %s
          /
          %s
          * 100
          - 100
        ||| % [
          queries.containerMonthlyCost,
          queries.containerMonthlyCostOffset30d,
        ],

        pvcTotalGibByClaimQuery: |||
          sum(
            sum(
              kube_persistentvolume_capacity_bytes{
                %(ksmDefault)s
              } / (1024 * 1024 * 1024)
            ) by (persistentvolume)
            * on(persistentvolume) group_left(%(clusterLabel)s, %(namespaceLabel)s, persistentvolumeclaim)
              label_replace(
                kube_persistentvolumeclaim_info{
                  %(ksmWithNamespace)s
                },
                "persistentvolume", "$1",
                "volumename", "(.*)"
              )
          ) by (persistentvolumeclaim)
        ||| % defaultFilters,
        pvMonthlyCostByPv: std.strReplace(queries.monthlyPVCost, '* 730', 'by (persistentvolume) * 730'),
        pvcMonthlyCostByClaim: std.strReplace(queries.monthlyPVCost, '* 730', 'by (persistentvolumeclaim) * 730'),
      };

      local panels = {
        hourlyCostStat:
          dashboards.statPanel(
            'Hourly Cost',
            $._config.dashboardCurrencyUnit,
            queries.hourlyCost,
            graphMode='none',
            decimals=2,
            showPercentChange=true,
            percentChangeColorMode='inverted',
            description='Current hourly cost rate for the selected namespace, including CPU, RAM, and PV costs. This provides real-time visibility into namespace spending and helps track the immediate impact of workload changes on costs.',
          ),

        monthlyCostStat:
          dashboards.statPanel(
            'Monthly Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyCost,
            graphMode='none',
            decimals=2,
            showPercentChange=true,
            percentChangeColorMode='inverted',
            description='Projected monthly cost for the selected namespace based on current hourly rates. This includes CPU, RAM, GPU, and PV costs so application teams can track their overall spend against budget.',
          ),

        monthlyRamCostStat:
          dashboards.statPanel(
            'Monthly Ram Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyRamCost,
            graphMode='none',
            decimals=2,
            showPercentChange=true,
            percentChangeColorMode='inverted',
            description='Projected monthly RAM cost for the selected namespace. High memory costs may indicate opportunities to optimize container memory requests or identify memory-intensive workloads that could benefit from tuning.',
          ),

        monthlyCpuCostStat:
          dashboards.statPanel(
            'Monthly CPU Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyCpuCost,
            graphMode='none',
            decimals=2,
            showPercentChange=true,
            percentChangeColorMode='inverted',
            description='Projected monthly CPU cost for the selected namespace. Compare this with RAM costs to understand your namespace compute profile and identify if CPU requests are appropriately sized for your workloads.',
          ),

        monthlyPVCostStat:
          dashboards.statPanel(
            'Monthly PV Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyPVCost,
            graphMode='none',
            decimals=2,
            showPercentChange=true,
            percentChangeColorMode='inverted',
            description='Projected monthly Persistent Volume cost for the selected namespace. Monitor this to identify unused PVCs or opportunities to migrate to cheaper storage classes without impacting application performance.',
          ),

        monthlyGPUCostStat:
          dashboards.statPanel(
            'Monthly GPU Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyGPUCost,
            graphMode='none',
            decimals=2,
            showPercentChange=true,
            percentChangeColorMode='inverted',
            description='Projected monthly GPU cost for the selected namespace. This helps teams understand accelerator spend and spot namespaces where GPU-backed workloads dominate overall costs.',
          ),

        hourlyCostTimeSeries:
          dashboards.timeSeriesPanel(
            'Hourly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.hourlyCost,
                legend: 'Hourly Cost',
                interval: $._config.dashboardMinInterval,
              },
            ],
            description='Hourly cost trend for the selected namespace. Use this to see short-term cost changes from scaling, deployments, or workload churn without switching to the cluster overview.',
          ),

        monthlyCostTimeSeries:
          dashboards.timeSeriesPanel(
            'Monthly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.monthlyCost,
                legend: 'Monthly Cost',
                interval: $._config.dashboardMinInterval,
              },
            ],
            description='Monthly cost projection trend for the selected namespace. This helps application teams track their projected monthly spending and ensure they remain within their allocated budget throughout the billing period.',
          ),

        resourceCostPieChart:
          dashboards.pieChartPanel(
            'Cost by Resource',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.monthlyCpuCost,
                legend: 'CPU',
              },
              {
                expr: queries.monthlyRamCost,
                legend: 'RAM',
              },
              {
                expr: queries.monthlyPVCost,
                legend: 'PV',
              },
              {
                expr: queries.monthlyGPUCost,
                legend: 'GPU',
              },
            ],
            description='Monthly cost distribution for the selected namespace across resource types (CPU, RAM, Persistent Volumes, and GPU). This shows which resource category is the primary cost driver for this namespace, helping teams prioritize their optimization efforts.',
            values=['percent', 'value']
          ),

        podTable:
          dashboards.tablePanel(
            'Pod Monthly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.podMonthlyCost,
              },
              {
                expr: queries.podMonthlyCostDifference7d,
              },
              {
                expr: queries.podMonthlyCostDifference30d,
              },
            ],
            description='Top 10 pods by projected monthly cost (based on current hourly rates) with percentage change compared to 7 days and 30 days ago. Positive percentages indicate cost increases (red), negative percentages indicate cost decreases (green). Use this to identify the most expensive pods in the namespace and track how pod costs change over time, especially after deployments or configuration changes.',
            sortBy={
              name: 'Total Cost (Today)',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    [$._config.podLabel]: 'Pod',
                    'Value #A': 'Monthly Cost',
                    'Value #B': 'Cost Change vs 7d Ago (%)',
                    'Value #C': 'Cost Change vs 30d Ago (%)',
                  },
                  indexByName: {
                    [$._config.podLabel]: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                    'Value #C': 3,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('Cost Change vs 7d Ago (%)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent') +
                tbFieldConfig.defaults.custom.withCellOptions(
                  { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
                ) +
                tbStandardOptions.color.withMode('thresholds')
              ),
              tbOverride.byName.new('Cost Change vs 30d Ago (%)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent') +
                tbFieldConfig.defaults.custom.withCellOptions(
                  { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
                ) +
                tbStandardOptions.color.withMode('thresholds')
              ),
            ],
            steps=[
              tbStandardOptions.threshold.step.withValue(0) +
              tbStandardOptions.threshold.step.withColor('green'),
              tbStandardOptions.threshold.step.withValue(5) +
              tbStandardOptions.threshold.step.withColor('yellow'),
              tbStandardOptions.threshold.step.withValue(10) +
              tbStandardOptions.threshold.step.withColor('red'),
            ]
          ),

        podCostPieChart:
          dashboards.pieChartPanel(
            'Cost by Pod',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.podMonthlyCost,
                legend: '{{ %s }}' % $._config.podLabel,
              },
            ],
            values=['percent', 'value'],
            description='Top 10 pods by monthly cost showing the distribution of spending across pods in the namespace. This visualization helps identify which pods consume the most resources and whether costs are evenly distributed or concentrated in a few workloads.',
          ),

        containerTable:
          dashboards.tablePanel(
            'Container Monthly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.containerMonthlyCost,
              },
              {
                expr: queries.containerMonthlyCostDifference7d,
              },
              {
                expr: queries.containerMonthlyCostDifference30d,
              },
            ],
            description='Top 10 containers by current monthly cost with percentage change compared to 7 days and 30 days ago. Positive percentages indicate cost increases (red), negative percentages indicate cost decreases (green). This granular view helps identify specific containers within pods that are driving costs, useful for optimizing multi-container pod configurations.',
            sortBy={
              name: 'Monthly Cost',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    [$._config.containerLabel]: 'Container',
                    'Value #A': 'Monthly Cost',
                    'Value #B': 'Cost Change vs 7d Ago (%)',
                    'Value #C': 'Cost Change vs 30d Ago (%)',
                  },
                  indexByName: {
                    [$._config.containerLabel]: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                    'Value #C': 3,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('Cost Change vs 7d Ago (%)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent') +
                tbFieldConfig.defaults.custom.withCellOptions(
                  { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
                ) +
                tbStandardOptions.color.withMode('thresholds')
              ),
              tbOverride.byName.new('Cost Change vs 30d Ago (%)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent') +
                tbFieldConfig.defaults.custom.withCellOptions(
                  { type: 'color-background' }  // TODO(adinhodovic): Use jsonnet lib
                ) +
                tbStandardOptions.color.withMode('thresholds')
              ),
            ],
            steps=[
              tbStandardOptions.threshold.step.withValue(0) +
              tbStandardOptions.threshold.step.withColor('green'),
              tbStandardOptions.threshold.step.withValue(5) +
              tbStandardOptions.threshold.step.withColor('yellow'),
              tbStandardOptions.threshold.step.withValue(10) +
              tbStandardOptions.threshold.step.withColor('red'),
            ]
          ),

        containerCostPieChart:
          dashboards.pieChartPanel(
            'Cost by Container',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.containerMonthlyCost,
                legend: '{{ %s }}' % $._config.containerLabel,
              },
            ],
            values=['percent', 'value'],
            description='Top 10 containers by monthly cost showing the distribution of spending across containers in the namespace. This helps identify which container images or workload types are most expensive and whether sidecar containers are adding significant costs.',
          ),

        pvTable:
          dashboards.tablePanel(
            'Persistent Volume Claims Monthly Cost',
            'decgbytes',
            [
              {
                expr: queries.pvcTotalGibByClaimQuery,
              },
              {
                expr: queries.pvcMonthlyCostByClaim,
              },
            ],
            description='List of Persistent Volume Claims used by the selected namespace with their capacity (in GiB) and monthly cost, sorted by total cost. Use this to identify large or expensive claims that may be candidates for cleanup, resizing, or migration to cheaper storage classes.',
            sortBy={
              name: 'Monthly Cost',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    persistentvolumeclaim: 'Persistent Volume Claim',
                    'Value #A': 'Total GiB',
                    'Value #B': 'Total Cost',
                  },
                  indexByName: {
                    persistentvolumeclaim: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                    [$._config.namespaceLabel]: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('Total Cost') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit($._config.dashboardCurrencyUnit)
              ),
            ]
          ),

        pvCostPieChart:
          dashboards.pieChartPanel(
            'Cost by Persistent Volume Claim',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.pvcMonthlyCostByClaim,
                legend: '{{ persistentvolumeclaim }}',
              },
            ],
            values=['percent', 'value'],
            description='Distribution of monthly storage costs across Persistent Volume Claims in the namespace. This shows which claims consume the most storage budget and helps identify whether storage costs are concentrated in a few large claims or distributed across many smaller ones.',
          ),
      };

      local rows =
        [
          row.new(
            'Summary',
          ) +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.hourlyCostStat,
            panels.monthlyCostStat,
            panels.monthlyCpuCostStat,
            panels.monthlyRamCostStat,
            panels.monthlyGPUCostStat,
            panels.monthlyPVCostStat,
          ],
          panelWidth=4,
          panelHeight=3,
          startY=1
        ) +
        grid.wrapPanels(
          [
            panels.hourlyCostTimeSeries,
            panels.monthlyCostTimeSeries,
          ],
          panelWidth=12,
          panelHeight=5,
          startY=4
        ) +
        grid.wrapPanels(
          [
            panels.resourceCostPieChart,
            panels.podCostPieChart,
            panels.containerCostPieChart,
            panels.pvCostPieChart,
          ],
          panelWidth=12,
          panelHeight=7,
          startY=9
        ) +
        [
          row.new(
            'Pod Summary',
          ) +
          row.gridPos.withX(0) +
          row.gridPos.withY(23) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.podTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(24) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(10),
        ] +
        [
          row.new(
            'Container Summary',
          ) +
          row.gridPos.withX(0) +
          row.gridPos.withY(34) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.containerTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(35) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(10),
        ] +
        [
          row.new(
            'PV Summary',
          ) +
          row.gridPos.withX(0) +
          row.gridPos.withY(45) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.pvTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(46) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(10),
        ];

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'OpenCost / Namespace',
      ) +
      dashboard.withDescription('A detailed namespace-level cost analysis dashboard that breaks down infrastructure spending by pods, containers, persistent volumes, and GPU usage within a selected namespace. Use this dashboard to understand which workloads are driving costs within a namespace, track monthly cost trends over time, and identify optimization opportunities at the pod and container level. This dashboard is ideal for application teams monitoring their own resource consumption and costs. %s' % mixinUtils.dashboards.dashboardDescriptionLink('opencost-mixin', 'https://github.com/adinhodovic/opencost-mixin')) +
      dashboard.withUid($._config.dashboardIds[dashboardName]) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(false) +
      dashboard.time.withFrom('now-2d') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        mixinUtils.dashboards.dashboardLinks('OpenCost', $._config, dropdown=true)
      ) +
      dashboard.withPanels(
        rows
      ) +
      dashboard.withAnnotations(
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
