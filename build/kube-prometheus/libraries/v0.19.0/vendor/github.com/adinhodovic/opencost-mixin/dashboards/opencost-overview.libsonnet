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
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;


{
  local dashboardName = 'opencost-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = std.prune([
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.opencostJob,
        defaultVariables.ksmJob,
      ]);

      local defaultFilters = util.filters($._config);
      local queries = {
        hourlyCost: |||
          sum(
            node_total_hourly_cost{
              %(opencostDefault)s
            }
          )
          +
          sum(
            sum(
              kube_persistentvolume_capacity_bytes{
                %(ksmDefault)s
              } / (1024 * 1024 * 1024)
            ) by (persistentvolume)
            * on(persistentvolume) group_left()
            sum(
              pv_hourly_cost{
                %(opencostDefault)s
              }
            ) by (persistentvolume)
          )
        ||| % defaultFilters,
        monthlyCost: '(%s) * 730' % queries.hourlyCost,

        monthlyRamCost: |||
          sum(
            sum(
              kube_node_status_capacity{
                %(ksmDefault)s,
                resource="memory",
                unit="byte"
              }
            ) by (node)
            / (1024 * 1024 * 1024)
            * on(node) group_left()
              sum(
                node_ram_hourly_cost{
                  %(opencostDefault)s
                }
              ) by (node)
            * 730
          )
        ||| % defaultFilters,

        monthlyCpuCost: |||
          sum(
            sum(
              kube_node_status_capacity{
                %(ksmDefault)s,
                resource="cpu",
                unit="core"
              }
            ) by (node)
            * on(node) group_left()
              sum(
                node_cpu_hourly_cost{
                  %(opencostDefault)s
                }
              ) by (node)
            * 730
          )
        ||| % defaultFilters,

        monthlyPVCost: |||
          sum(
            sum(
              kube_persistentvolume_capacity_bytes{
                %(ksmDefault)s
              } / (1024 * 1024 * 1024)
            ) by (persistentvolume)
            * on(persistentvolume) group_left()
              sum(
                pv_hourly_cost{
                  %(opencostDefault)s
                }
              ) by (persistentvolume)
          ) * 730
        ||| % defaultFilters,

        monthlyGPUCost: |||
          sum(
            node_gpu_hourly_cost{
              %(opencostDefault)s
            }
          ) * 730
        ||| % defaultFilters,

        nodeMonthlyCpuCost: |||
          sum(
            kube_node_status_capacity{
              %(ksmDefault)s,
              resource="cpu",
              unit="core"
            }
          ) by (node)
          * on(node) group_left(cluster, instance_type, arch)
            sum(
              node_cpu_hourly_cost{
                %(opencostDefault)s,
              }
            ) by (node, instance_type, arch)
          * 730
        ||| % defaultFilters,

        nodeMonthlyRamCost: |||
          sum(
            kube_node_status_capacity{
              %(ksmDefault)s,
              resource="memory",
              unit="byte"
            }
          ) by (node)
          / (1024 * 1024 * 1024)
          * on(node) group_left(cluster, instance_type, arch)
            sum(
              node_ram_hourly_cost{
                %(opencostDefault)s
              }
            ) by (node, instance_type, arch)
          * 730
        ||| % defaultFilters,

        totalCostVariance7d: |||
          (
            avg_over_time(
              sum(
                node_total_hourly_cost{
                  %(opencostDefault)s
                }
              ) [1d:1h]
            )
            -
            avg_over_time(
              sum(
                node_total_hourly_cost{
                  %(opencostDefault)s
                }
              ) [7d:1h]
            )
          )
          /
          avg_over_time(
            sum(
              node_total_hourly_cost{
                %(opencostDefault)s
              }
            ) [7d:1h]
          )
        ||| % defaultFilters,

        totalCostVariance30d: |||
          (
            avg_over_time(
              sum(
                node_total_hourly_cost{
                  %(opencostDefault)s
                }
              ) [1d:1h]
            )
            -
            avg_over_time(
              sum(
                node_total_hourly_cost{
                  %(opencostDefault)s
                }
              ) [30d:1h]
            )
          )
          /
          avg_over_time(
            sum(
              node_total_hourly_cost{
                %(opencostDefault)s
              }
            ) [30d:1h]
          )
        ||| % defaultFilters,

        cpuCostVariance30d: |||
          (
            avg_over_time(
              %s [1d:1h]
            )
            -
            avg_over_time(
              %s [30d:1h]
            )
          )
          /
          avg_over_time(
            %s [30d:1h]
          )
        ||| % [queries.monthlyCpuCost, queries.monthlyCpuCost, queries.monthlyCpuCost],

        ramCostVariance30d: |||
          (
            avg_over_time(
              %s [1d:1h]
            )
            -
            avg_over_time(
              %s [30d:1h]
            )
          )
          /
          avg_over_time(
            %s [30d:1h]
          )
        ||| % [queries.monthlyRamCost, queries.monthlyRamCost, queries.monthlyRamCost],

        pvCostVariance30d: |||
          (
            avg_over_time(
              (%s) [1d:1h]
            )
            -
            avg_over_time(
              (%s) [30d:1h]
            )
          )
          /
          avg_over_time(
            (%s) [30d:1h]
          )
        ||| % [queries.monthlyPVCost, queries.monthlyPVCost, queries.monthlyPVCost],

        // Keep job label formatting inconsistent due to strReplace
        namespaceMonthlyCost: |||
          topk(10,
            sum(
              sum(
                container_memory_allocation_bytes{
                  %(opencostDefault)s}
              ) by (%(clusterLabel)s, %(namespaceLabel)s, %(instanceLabel)s)
              * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                (
                  node_ram_hourly_cost{
                    %(opencostDefault)s} / (1024 * 1024 * 1024) * 730
                )
              +
              sum(
                container_cpu_allocation{
                  %(opencostDefault)s}
              ) by (%(clusterLabel)s, %(namespaceLabel)s, %(instanceLabel)s)
              * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                (
                  node_cpu_hourly_cost{
                    %(opencostDefault)s} * 730
                )
            ) by (%(clusterLabel)s, %(namespaceLabel)s)
          )
        ||| % defaultFilters,

        monthlyCostOffset7d: std.strReplace(queries.namespaceMonthlyCost, defaultFilters.opencostJob + '\n}', defaultFilters.opencostJob + '\n} offset 7d'),
        monthlyCostOffset30d: std.strReplace(queries.namespaceMonthlyCost, defaultFilters.opencostJob + '\n}', defaultFilters.opencostJob + '\n} offset 30d'),
        costDifference7d: |||
          %s
          /
          %s
          * 100
          - 100
        ||| % [queries.namespaceMonthlyCost, queries.monthlyCostOffset7d],
        costDifference30d: |||
          %s
          /
          %s
          * 100
          - 100
        ||| % [queries.namespaceMonthlyCost, queries.monthlyCostOffset30d],

        instanceTypeCost: |||
          topk(10,
            sum(
              node_total_hourly_cost{
                %(opencostDefault)s
              }
            ) by (instance_type) * 730
          )
        ||| % defaultFilters,

        nodeTotalCost: |||
          sum(
            node_total_hourly_cost{
              %(opencostDefault)s
            }
          ) by (node, instance_type, arch)
          * 730
        ||| % defaultFilters,

        pvTotalGib: |||
          sum(
            kube_persistentvolume_capacity_bytes{
              %(ksmDefault)s
            }
            / 1024 / 1024 / 1024
          ) by (persistentvolume)
        ||| % defaultFilters,

        pvMonthlyCost: |||
          sum(
            kube_persistentvolume_capacity_bytes{
              %(ksmDefault)s
            }
            / 1024 / 1024 / 1024
          ) by (persistentvolume)
          *
          sum(
            pv_hourly_cost{
              %(opencostDefault)s
            }
            * 730
          ) by (persistentvolume)
        ||| % defaultFilters,
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
            description='Current hourly infrastructure cost rate across the cluster. This metric provides real-time cost visibility and can be used to project daily and monthly spending. The percentage change helps track cost fluctuations over time.',
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
            description='Projected monthly infrastructure cost based on current hourly rates (730 hours per month). This projection helps with budget planning and cost forecasting. Compare this value against your budget to ensure spending stays within limits.',
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
            description='Projected monthly cost for RAM (memory) resources across all cluster nodes. This metric helps identify if memory is a significant cost driver and can guide decisions about node sizing and memory allocation strategies.',
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
            description='Projected monthly cost for CPU (compute) resources across all cluster nodes. Compare this with RAM costs to understand your compute vs. memory cost ratio and optimize instance type selection accordingly.',
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
            description='Projected monthly cost for Persistent Volume (storage) resources across the cluster. Monitor this metric to identify unused or oversized volumes that can be optimized to reduce storage costs.',
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
            description='Projected monthly GPU cost across the cluster. Use this to understand whether accelerator usage is a major cost driver and to spot opportunities to right-size GPU-backed workloads.',
          ),

        hourCostTimeSeries:
          dashboards.timeSeriesPanel(
            'Hourly Cost',
            $._config.dashboardCurrencyUnit,
            queries.hourlyCost,
            'Hourly Cost',
            description='Hourly cost trend over time showing how infrastructure spending fluctuates throughout the day. Use this to identify cost spikes, correlate costs with workload patterns, and detect autoscaling behavior impact on spending.',
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
            description='Monthly cost projection trend over time. This visualization helps track how your projected monthly spending evolves and whether you are staying within budget throughout the billing period.',
          ),

        totalCostVarianceTimeSeries:
          dashboards.timeSeriesPanel(
            'Total Cost Variance',
            'percentunit',
            [
              {
                expr: queries.totalCostVariance7d,
                legend: 'Current hourly cost vs. 7-day average',
                interval: $._config.dashboardMinInterval,
              },
              {
                expr: queries.totalCostVariance30d,
                legend: 'Current hourly cost vs. 30-day average',
                interval: $._config.dashboardMinInterval,
              },
            ],
            description='Cost variance comparing current hourly costs against 7-day and 30-day historical averages. Positive values indicate costs are higher than average, negative values indicate lower costs. Use this to detect cost anomalies and unusual spending patterns that may require investigation.',
          ),

        resourceCostVarianceTimeSeries:
          dashboards.timeSeriesPanel(
            'Resource Cost Variance',
            'percentunit',
            [
              {
                expr: queries.cpuCostVariance30d,
                legend: 'CPU Cost vs. 30-day average',
                interval: $._config.dashboardMinInterval,
              },
              {
                expr: queries.ramCostVariance30d,
                legend: 'RAM Cost vs. 30-day average',
                interval: $._config.dashboardMinInterval,
              },
              {
                expr: queries.pvCostVariance30d,
                legend: 'PV Cost vs. 30-day average',
                interval: $._config.dashboardMinInterval,
              },
            ],
            description='Resource-specific cost variance comparing current CPU, RAM, and PV costs against their 30-day historical averages. This breakdown helps identify which resource type is driving cost changes - useful for pinpointing whether cost increases are due to compute scaling, memory usage, or storage growth.',
          ),

        resourceCostPieChartPanel:
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
            description='Monthly cost distribution across resource types (CPU, RAM, Persistent Volumes, and GPU). This breakdown shows which resource category consumes the most budget, helping prioritize optimization efforts.',
            values=['percent', 'value']
          ),

        namespaceCostPieChartPanel:
          dashboards.pieChartPanel(
            'Cost by Namespace',
            $._config.dashboardCurrencyUnit,
            queries.namespaceMonthlyCost,
            '{{ %s }}' % $._config.namespaceLabel,
            description='Top 10 namespaces by monthly cost showing which teams, applications, or environments consume the most resources. Use this to allocate costs to teams, identify expensive applications, and ensure fair resource distribution across the organization.',
            values=['percent', 'value']
          ),

        instanceTypeCostPieChartPanel:
          dashboards.pieChartPanel(
            'Cost by Instance Type',
            $._config.dashboardCurrencyUnit,
            queries.instanceTypeCost,
            '{{ instance_type }}',
            description='Top 10 instance types by monthly cost showing which VM/node types contribute most to infrastructure spending. This helps evaluate whether your instance type selection is cost-effective and identify opportunities to switch to more economical instance families.',
            values=['percent', 'value']
          ),

        nodeTable:
          dashboards.tablePanel(
            'Nodes Monthly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.nodeMonthlyCpuCost,
              },
              {
                expr: queries.nodeMonthlyRamCost,
              },
              {
                expr: queries.nodeTotalCost,
              },
            ],
            description='Detailed breakdown of monthly costs per node, showing CPU cost, RAM cost, and total cost for each node along with instance type and architecture. Sorted by total cost to highlight the most expensive nodes. Use this to identify underutilized expensive nodes that could be downsized or removed.',
            sortBy={
              name: 'Total Cost',
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
                    node: 'Node',
                    instance_type: 'Instance Type',
                    arch: 'Architecture',
                    'Value #A': 'CPU Cost',
                    'Value #B': 'RAM Cost',
                    'Value #C': 'Total Cost',
                  },
                  indexByName: {
                    node: 0,
                    instance_type: 1,
                    arch: 2,
                    'Value #A': 3,
                    'Value #B': 4,
                    'Value #C': 5,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
                  },
                }
              ),
            ],
            overrides=(
              if std.all([$._config.showMultiCluster, !$._config.multiClusterAllowsMultipleSelection])
              then
                [
                  tbOverride.byName.new('cluster') +
                  tbOverride.byName.withProperty('custom.hideFrom.viz', true),
                ]
              else
                []
            )
          ),

        pvTable:
          dashboards.tablePanel(
            'Persistent Volumes Monthly Cost',
            'decgbytes',
            [
              {
                expr: queries.pvTotalGib,
              },
              {
                expr: queries.pvMonthlyCost,
              },
            ],
            description='List of all Persistent Volumes with their capacity (in GiB) and monthly cost, sorted by total cost. Use this to identify large or expensive volumes that may be candidates for cleanup, resizing, or migration to cheaper storage classes.',
            sortBy={
              name: 'Total Cost',
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
                    persistentvolume: 'Persistent Volume',
                    'Value #A': 'Total GiB',
                    'Value #B': 'Total Cost',
                  },
                  indexByName: {
                    persistentvolume: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                  },
                  excludeByName: {
                    Time: true,
                    job: true,
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

        namespaceTable:
          dashboards.tablePanel(
            'Namespace Monthly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.namespaceMonthlyCost,
              },
              {
                expr: queries.costDifference7d,
              },
              {
                expr: queries.costDifference30d,
              },
            ],
            description='Top 10 namespaces by current monthly cost with percentage change compared to 7 days and 30 days ago. Positive percentages indicate cost increases (red), negative percentages indicate cost decreases (green). Click on a namespace name to drill down into detailed pod and container costs. Use this to track namespace-level spending trends and identify teams or applications with growing costs.',
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
                    namespace: 'Namespace',
                    'Value #A': 'Monthly Cost',
                    'Value #B': 'Cost Change vs 7d Ago (%)',
                    'Value #C': 'Cost Change vs 30d Ago (%)',
                  },
                  indexByName: {
                    namespace: 0,
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
              tbOverride.byName.new('Namespace') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withLinks(
                  tbPanelOptions.link.withTitle('Go To Namespace') +
                  tbPanelOptions.link.withType('dashboard') +
                  tbPanelOptions.link.withUrl(
                    (
                      if $._config.dashboardDynamicJobDiscovery then
                        '/d/%s/opencost-namespace?var-cluster=${__data.fields.cluster}&var-opencost_job=$opencost_job&var-ksm_job=$ksm_job&var-namespace=${__data.fields.Namespace}'
                      else
                        '/d/%s/opencost-namespace?var-cluster=${__data.fields.cluster}&var-namespace=${__data.fields.Namespace}'
                    ) % $._config.dashboardIds['opencost-namespace']
                  ) +
                  tbPanelOptions.link.withTargetBlank(true)
                )
              ),
            ] + (
              if std.all([$._config.showMultiCluster, !$._config.multiClusterAllowsMultipleSelection])
              then
                [
                  tbOverride.byName.new('cluster') +
                  tbOverride.byName.withProperty('custom.hideFrom.viz', true),
                ]
              else
                []
            ),
            steps=[
              tbStandardOptions.threshold.step.withValue(0) +
              tbStandardOptions.threshold.step.withColor('green'),
              tbStandardOptions.threshold.step.withValue(5) +
              tbStandardOptions.threshold.step.withColor('yellow'),
              tbStandardOptions.threshold.step.withValue(10) +
              tbStandardOptions.threshold.step.withColor('red'),
            ]
          ),
      };

      local rows =
        [
          row.new('Cluster Summary') +
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
            panels.resourceCostPieChartPanel,
            panels.namespaceCostPieChartPanel,
            panels.instanceTypeCostPieChartPanel,
          ],
          panelWidth=8,
          panelHeight=5,
          startY=5
        ) +
        grid.wrapPanels(
          [
            panels.hourCostTimeSeries,
            panels.monthlyCostTimeSeries,
          ],
          panelWidth=12,
          panelHeight=5,
          startY=10
        ) +
        grid.wrapPanels(
          [
            panels.totalCostVarianceTimeSeries,
            panels.resourceCostVarianceTimeSeries,
          ],
          panelWidth=12,
          panelHeight=5,
          startY=15
        ) +
        [
          row.new('Cloud Resources') +
          row.gridPos.withX(0) +
          row.gridPos.withY(20) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        [
          panels.nodeTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(21) +
          tablePanel.gridPos.withW(16) +
          tablePanel.gridPos.withH(10),
          panels.pvTable +
          tablePanel.gridPos.withX(16) +
          tablePanel.gridPos.withY(21) +
          tablePanel.gridPos.withW(8) +
          tablePanel.gridPos.withH(10),
          row.new('Namespace Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(31) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.namespaceTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(32) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(12),
        ];

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'OpenCost / Overview',
      ) +
      dashboard.withDescription('A comprehensive overview dashboard for OpenCost that displays cluster-wide cost metrics including hourly and monthly costs broken down by resource type (CPU, RAM, PV, GPU), instance type, namespace, and individual nodes. Use this dashboard to monitor overall infrastructure spending, identify cost trends, and detect cost anomalies across your Kubernetes cluster. %s' % mixinUtils.dashboards.dashboardDescriptionLink('opencost-mixin', 'https://github.com/adinhodovic/opencost-mixin')) +
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
