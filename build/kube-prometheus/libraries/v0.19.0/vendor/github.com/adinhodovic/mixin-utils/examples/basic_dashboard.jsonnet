// Example: Complete dashboard using mixin-utils
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashUtils = (import '../utils.libsonnet').dashboards;

local dashboard = g.dashboard;
local row = g.panel.row;

dashboard.new('Example Dashboard')
+ dashboard.withUid('example-mixin-utils')
+ dashboard.withDescription(
  dashUtils.dashboardDescriptionLink('mixin-utils', 'https://github.com/adinhodovic/mixin-utils')
)
+ dashboard.withTags(['example', 'mixin-utils'])
+ dashboard.withTimezone('utc')
+ dashboard.withRefresh('30s')
+ dashboard.time.withFrom('now-6h')
+ dashboard.time.withTo('now')
+ dashboard.withVariables([
  g.dashboard.variable.datasource.new('datasource', 'prometheus')
  + g.dashboard.variable.datasource.withRegex(''),
])
+ dashboard.withPanels(
  g.util.grid.makeGrid([
    row.new('Overview'),

    dashUtils.statPanel(
      title='Total Requests',
      unit='short',
      query='sum(http_requests_total)',
      description='Total number of HTTP requests across all services',
      graphMode='area',
    ),

    dashUtils.statPanel(
      title='Success Rate',
      unit='percentunit',
      query='sum(rate(http_requests_total{status=~"2.."}[5m])) / sum(rate(http_requests_total[5m]))',
      description='Percentage of successful requests',
      decimals=2,
      steps=[
        g.panel.stat.standardOptions.threshold.step.withValue(0) +
        g.panel.stat.standardOptions.threshold.step.withColor('red'),
        g.panel.stat.standardOptions.threshold.step.withValue(0.95) +
        g.panel.stat.standardOptions.threshold.step.withColor('yellow'),
        g.panel.stat.standardOptions.threshold.step.withValue(0.99) +
        g.panel.stat.standardOptions.threshold.step.withColor('green'),
      ],
    ),

    dashUtils.statPanel(
      title='Average Response Time',
      unit='s',
      query='avg(rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]))',
      description='Average response time across all requests',
      decimals=3,
    ),

    row.new('Request Rates'),

    dashUtils.timeSeriesPanel(
      title='Request Rate by Status',
      unit='reqps',
      query=[
        { expr: 'sum by(status) (rate(http_requests_total[5m]))', legend: '{{status}}' },
      ],
      description='HTTP request rate broken down by status code',
      calcs=['mean', 'max'],
      stack='normal',
    ),

    dashUtils.timeSeriesPanel(
      title='Error Rate',
      unit='reqps',
      query=[
        { expr: 'sum(rate(http_requests_total{status=~"5.."}[5m]))', legend: '5xx Errors' },
        { expr: 'sum(rate(http_requests_total{status=~"4.."}[5m]))', legend: '4xx Errors' },
      ],
      description='Rate of error responses',
      calcs=['mean', 'max', 'last'],
    ),

    row.new('Request Distribution'),

    dashUtils.pieChartPanel(
      title='Requests by Endpoint',
      unit='short',
      query=[
        { expr: 'sum by(endpoint) (http_requests_total)', legend: '{{endpoint}}' },
      ],
      description='Distribution of requests across endpoints',
      labels=['name', 'percent'],
      values=['value', 'percent'],
    ),

    dashUtils.heatmapPanel(
      title='Response Time Distribution',
      unit='s',
      query='sum(rate(http_request_duration_seconds_bucket[5m])) by (le)',
      description='Heatmap showing the distribution of response times',
    ),

    row.new('Detailed Metrics'),

    dashUtils.tablePanel(
      title='Service Instance Status',
      unit='short',
      query='up{job=~".*"}',
      description='Status of all monitored service instances',
      sortBy={ name: 'Time', desc: true },
    ),

    dashUtils.gaugePanel(
      title='Memory Usage',
      unit='percent',
      query='(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100',
      description='Current memory usage percentage',
      min=0,
      max=100,
      steps=[
        g.panel.gauge.standardOptions.threshold.step.withValue(0) +
        g.panel.gauge.standardOptions.threshold.step.withColor('green'),
        g.panel.gauge.standardOptions.threshold.step.withValue(80) +
        g.panel.gauge.standardOptions.threshold.step.withColor('yellow'),
        g.panel.gauge.standardOptions.threshold.step.withValue(90) +
        g.panel.gauge.standardOptions.threshold.step.withColor('red'),
      ],
    ),
  ], panelWidth=12, panelHeight=8)
)
+ dashUtils.bypassDashboardValidation
