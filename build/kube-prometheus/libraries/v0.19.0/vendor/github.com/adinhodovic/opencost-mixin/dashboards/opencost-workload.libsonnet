local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboards = mixinUtils.dashboards;
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbQueryOptions = tablePanel.queryOptions;

{
  local dashboardName = 'opencost-workload',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);
      local dashboardLinks = [
        link + dashboard.link.link.options.withAsDropdown(true)
        for link in mixinUtils.dashboards.dashboardLinks('OpenCost', $._config)
      ];

      local variables = std.prune([
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.opencostJob,
        defaultVariables.ksmJob,
        defaultVariables.namespace,
        defaultVariables.workloadType,
        defaultVariables.workload,
      ]);

      local defaultFilters = util.filters($._config);
      local workloadFilters = defaultFilters.withNamespaceWorkload;

      local queries = {
        hourlyRamCostByWorkload: |||
          sum by (%(clusterLabel)s, %(namespaceLabel)s, workload_type, workload) (
            avg_over_time(workload:opencost_ram_cost:sum{%(workloadFilters)s}[1h:5m])
          )
        ||| % ($._config { workloadFilters: workloadFilters }),

        hourlyCpuCostByWorkload: |||
          sum by (%(clusterLabel)s, %(namespaceLabel)s, workload_type, workload) (
            avg_over_time(workload:opencost_cpu_cost:sum{%(workloadFilters)s}[1h:5m])
          )
        ||| % ($._config { workloadFilters: workloadFilters }),

        hourlyPvcCostByWorkload: |||
          sum by (%(clusterLabel)s, %(namespaceLabel)s, workload_type, workload) (
            avg_over_time(workload:opencost_pvc_cost:sum{%(workloadFilters)s}[1h:5m])
          )
        ||| % ($._config { workloadFilters: workloadFilters }),

        pvcMonthlyCostByClaim: |||
          sum by (persistentvolumeclaim, workload_type, workload) (
            avg_over_time(
              workload:opencost_pvc_cost:sum{%(workloadFilters)s}[1h:5m]
            )
          ) * 730
        ||| % ($._config { workloadFilters: workloadFilters }),

        hourlyGpuCostByWorkload: |||
          sum by (%(clusterLabel)s, %(namespaceLabel)s, workload_type, workload) (
            avg_over_time(workload:opencost_gpu_cost:sum{%(workloadFilters)s}[1h:5m])
          )
        ||| % ($._config { workloadFilters: workloadFilters }),

        hourlyCostByWorkload: |||
          (
            %s
            +
            %s
          )
          +
          (
            %s
            or (%s * 0)
          )
          +
          (
            %s
            or (%s * 0)
          )
        ||| % [
          queries.hourlyRamCostByWorkload,
          queries.hourlyCpuCostByWorkload,
          queries.hourlyPvcCostByWorkload,
          queries.hourlyRamCostByWorkload,
          queries.hourlyGpuCostByWorkload,
          queries.hourlyRamCostByWorkload,
        ],

        hourlyCost: 'sum(%s) or vector(0)' % queries.hourlyCostByWorkload,
        dailyCost: 'sum((%s) * 24) or vector(0)' % queries.hourlyCostByWorkload,
        monthlyCost: 'sum((%s) * 730) or vector(0)' % queries.hourlyCostByWorkload,

        monthlyRamCost: 'sum((%s) * 730) or vector(0)' % queries.hourlyRamCostByWorkload,
        monthlyCpuCost: 'sum((%s) * 730) or vector(0)' % queries.hourlyCpuCostByWorkload,
        monthlyPVCost: 'sum((%s) * 730) or vector(0)' % queries.hourlyPvcCostByWorkload,
        monthlyGPUCost: 'sum((%s) * 730) or vector(0)' % queries.hourlyGpuCostByWorkload,

        dailyCostByWorkload: 'topk(10, (%s) * 24)' % queries.hourlyCostByWorkload,
        monthlyCostByWorkload: '(%s) * 730' % queries.hourlyCostByWorkload,
        monthlyCostByWorkloadType: |||
          sum by (workload_type) (
            (%s) * 730
          )
        ||| % queries.hourlyCostByWorkload,
        monthlyRamCostByWorkload: '(%s) * 730' % queries.hourlyRamCostByWorkload,
        monthlyCpuCostByWorkload: '(%s) * 730' % queries.hourlyCpuCostByWorkload,
        monthlyPVCostByWorkload: '(%s) * 730' % queries.hourlyPvcCostByWorkload,
        monthlyGPUCostByWorkload: '(%s) * 730' % queries.hourlyGpuCostByWorkload,

        podMonthlyCost: |||
          topk(10,
            sum(
              (
                sum(
                  container_memory_allocation_bytes{
                    %(opencostWithNamespace)s
                  }
                ) by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, %(instanceLabel)s)
                * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                (
                  avg(
                    node_ram_hourly_cost{
                      %(opencostDefault)s
                    }
                  ) by (%(clusterLabel)s, %(instanceLabel)s) / (1024 * 1024 * 1024) * 730
                )
              )
              +
              (
                sum(
                  container_cpu_allocation{
                    %(opencostWithNamespace)s
                  }
                ) by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, %(instanceLabel)s)
                * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                (
                  avg(
                    node_cpu_hourly_cost{
                      %(opencostDefault)s
                    }
                  ) by (%(clusterLabel)s, %(instanceLabel)s) * 730
                )
              )
              +
              (
                sum(
                  container_gpu_allocation{
                    %(opencostWithNamespace)s
                  }
                ) by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, %(instanceLabel)s)
                * on(%(clusterLabel)s, %(instanceLabel)s) group_left()
                (
                  avg(
                    node_gpu_hourly_cost{
                      %(opencostDefault)s
                    }
                  ) by (%(clusterLabel)s, %(instanceLabel)s) * 730
                )
              )
            )
            * on(%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s) group_left(workload_type, workload)
            max by (%(clusterLabel)s, %(namespaceLabel)s, %(podLabel)s, workload_type, workload) (
                namespace_workload_pod:kube_pod_owner:relabel{%(withNamespaceWorkload)s}
              )
          ) by (%(podLabel)s)
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
            description='Smoothed current hourly cost rate for the selected workload scope. The query averages the workload recording rules over the last hour using a 5-minute step (`[1h:5m]`) and combines RAM, CPU, persistent volume, and GPU costs for the selected `workload_type / workload` pairs.',
          ),

        dailyCostStat:
          dashboards.statPanel(
            'Daily Cost',
            $._config.dashboardCurrencyUnit,
            queries.dailyCost,
            graphMode='none',
            decimals=2,
            description='Projected daily cost for the selected workload scope. This takes the smoothed hourly rate from the workload recording rules and multiplies it by 24, so it is best read as a forecast rather than exact end-of-day billing.',
          ),

        monthlyCostStat:
          dashboards.statPanel(
            'Monthly Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyCost,
            graphMode='none',
            decimals=2,
            description='Projected monthly cost for the selected workload scope using the smoothed hourly rate multiplied across a 730-hour month. This is useful for estimating steady-state spend for the selected workloads.',
          ),

        monthlyRamCostStat:
          dashboards.statPanel(
            'Monthly Ram Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyRamCost,
            graphMode='none',
            decimals=2,
            description='Projected monthly memory cost for the selected `workload_type / workload` selection, derived from the workload RAM cost recording rule and scaled to a 730-hour month.',
          ),

        monthlyCpuCostStat:
          dashboards.statPanel(
            'Monthly CPU Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyCpuCost,
            graphMode='none',
            decimals=2,
            description='Projected monthly CPU cost for the selected `workload_type / workload` selection, derived from the workload CPU cost recording rule and scaled to a 730-hour month.',
          ),

        monthlyPVCostStat:
          dashboards.statPanel(
            'Monthly PV Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyPVCost,
            graphMode='none',
            decimals=2,
            description='Projected monthly persistent volume cost for the selected workload scope. PVC attribution is inferred from workload-owned pods that mount each claim, so shared claims can contribute cost to more than one workload.',
          ),

        monthlyGPUCostStat:
          dashboards.statPanel(
            'Monthly GPU Cost',
            $._config.dashboardCurrencyUnit,
            queries.monthlyGPUCost,
            graphMode='none',
            decimals=2,
            description='Projected monthly GPU cost for the selected `workload_type / workload` selection, derived from the workload GPU cost recording rule and scaled to a 730-hour month.',
          ),

        monthlyCostByWorkloadTimeSeries:
          dashboards.timeSeriesPanel(
            'Monthly Cost by Workload',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: 'topk(10, %s)' % queries.monthlyCostByWorkload,
                legend: '{{ workload_type }} / {{ workload }}',
                interval: '5m',
              },
            ],
            stack='normal',
            description='Top workloads in the selected namespace by projected monthly cost. Each series represents a `workload_type / workload` pair, which is helpful when the dashboard is scoped to all workloads or all workloads of a given type.',
          ),

        monthlyCostByResourceTimeSeries:
          dashboards.timeSeriesPanel(
            'Monthly Cost by Resource',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: 'sum((%s) * 730) or vector(0)' % queries.hourlyRamCostByWorkload,
                legend: 'RAM',
                interval: '5m',
              },
              {
                expr: 'sum((%s) * 730) or vector(0)' % queries.hourlyCpuCostByWorkload,
                legend: 'CPU',
                interval: '5m',
              },
              {
                expr: 'sum((%s) * 730) or vector(0)' % queries.hourlyPvcCostByWorkload,
                legend: 'PV',
                interval: '5m',
              },
              {
                expr: 'sum((%s) * 730) or vector(0)' % queries.hourlyGpuCostByWorkload,
                legend: 'GPU',
                interval: '5m',
              },
            ],
            stack='normal',
            description='Monthly cost trend for the selected workload scope split into RAM, CPU, persistent volume, and GPU components. These values are based on the smoothed hourly workload cost rules and then projected to a 730-hour month.',
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
            values=['percent', 'value'],
            description='Monthly cost distribution for the selected workload scope across compute, memory, storage, and GPU. Use this to see which resource category is driving the projected monthly spend.',
          ),

        workloadCostPieChart:
          dashboards.pieChartPanel(
            'Cost by Workload',
            $._config.dashboardCurrencyUnit,
            'topk(10, %s)' % queries.monthlyCostByWorkload,
            '{{ workload_type }} / {{ workload }}',
            values=['percent', 'value'],
            description='Top workloads by projected monthly cost in the current namespace and filter scope. Each slice is a `workload_type / workload` pair.',
          ),

        workloadTypeCostPieChart:
          dashboards.pieChartPanel(
            'Cost by Workload Type',
            $._config.dashboardCurrencyUnit,
            queries.monthlyCostByWorkloadType,
            '{{ workload_type }}',
            values=['percent', 'value'],
            description='Projected monthly cost grouped by workload type for the current namespace and filter scope.',
          ),

        workloadTable:
          dashboards.tablePanel(
            'Workload Monthly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.monthlyRamCostByWorkload,
              },
              {
                expr: queries.monthlyCpuCostByWorkload,
              },
              {
                expr: queries.monthlyPVCostByWorkload,
              },
              {
                expr: queries.monthlyGPUCostByWorkload,
              },
              {
                expr: queries.monthlyCostByWorkload,
              },
            ],
            description='Monthly cost breakdown by workload, where each row is a `workload_type / workload` pair. The table shows RAM, CPU, persistent volume, GPU, and total projected monthly cost so you can compare the main cost drivers for each workload.',
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
                    workload_type: 'Workload Type',
                    workload: 'Workload',
                    'Value #A': 'RAM Cost',
                    'Value #B': 'CPU Cost',
                    'Value #C': 'PV Cost',
                    'Value #D': 'GPU Cost',
                    'Value #E': 'Total Cost',
                  },
                  indexByName: {
                    workload_type: 0,
                    workload: 1,
                    'Value #A': 2,
                    'Value #B': 3,
                    'Value #C': 4,
                    'Value #D': 5,
                    'Value #E': 6,
                  },
                  excludeByName: {
                    Time: true,
                    [$._config.namespaceLabel]: true,
                    [$._config.clusterLabel]: true,
                  },
                }
              ),
            ]
          ),

        pvcTable:
          dashboards.tablePanel(
            'Persistent Volume Claims Monthly Cost',
            $._config.dashboardCurrencyUnit,
            [
              {
                expr: queries.pvcMonthlyCostByClaim,
              },
            ],
            description='Projected monthly storage cost by persistent volume claim for the selected workload scope.',
            sortBy={
              name: 'Total Cost',
              desc: true,
            },
            transformations=[
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    workload_type: 'Workload Type',
                    workload: 'Workload',
                    persistentvolumeclaim: 'Persistent Volume Claim',
                    Value: 'Total Cost',
                  },
                  indexByName: {
                    workload_type: 0,
                    workload: 1,
                    persistentvolumeclaim: 2,
                    Value: 3,
                  },
                  excludeByName: {
                    Time: true,
                    [$._config.namespaceLabel]: true,
                    [$._config.clusterLabel]: true,
                  },
                }
              ),
            ]
          ),
      };

      local rows =
        [
          row.new('Workload Summary') +
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
            panels.workloadCostPieChart,
            panels.workloadTypeCostPieChart,
            panels.resourceCostPieChart,
          ],
          panelWidth=8,
          panelHeight=5,
          startY=4
        ) +
        grid.wrapPanels(
          [
            panels.monthlyCostByWorkloadTimeSeries,
            panels.monthlyCostByResourceTimeSeries,
          ],
          panelWidth=24,
          panelHeight=8,
          startY=10
        ) +
        [
          row.new('Workload Breakdown') +
          row.gridPos.withX(0) +
          row.gridPos.withY(25) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.workloadTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(26) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(10),
          row.new('Persistent Volume Claims') +
          row.gridPos.withX(0) +
          row.gridPos.withY(36) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          panels.pvcTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(37) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(8),
        ];

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'OpenCost / Workload',
      ) +
      dashboard.withDescription('A workload-focused OpenCost dashboard that breaks down cost inside a namespace using workload ownership labels. It mirrors the existing mixin style while adding workload_type and workload selectors so teams can inspect workload-level monthly, daily, and hourly cost drivers across RAM, CPU, persistent volume, and GPU usage. This dashboard depends on the workload recording rules shipped with the mixin on GitHub. Time-based workload cost views are smoothed with 1-hour averages sampled every 5 minutes (`[1h:5m]`). %s' % mixinUtils.dashboards.dashboardDescriptionLink('opencost-mixin', 'https://github.com/adinhodovic/opencost-mixin')) +
      dashboard.withUid($._config.dashboardIds[dashboardName]) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(false) +
      dashboard.time.withFrom('now-2d') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        dashboardLinks
      ) +
      dashboard.withPanels(
        rows
      ) +
      dashboard.withAnnotations(
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
