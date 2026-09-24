// Examples of using each panel type from mixin-utils
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashUtils = (import '../utils.libsonnet').dashboards;

{
  // Example 1: Simple stat panel
  statPanelExample: dashUtils.statPanel(
    title='Total Requests',
    unit='short',
    query='sum(http_requests_total)',
    description='Total number of HTTP requests',
    graphMode='area',
  ),

  // Example 2: Stat panel with multiple queries
  statPanelMultiQuery: dashUtils.statPanel(
    title='Request Rate',
    unit='reqps',
    query=[
      { expr: 'sum(rate(http_requests_total[5m]))', legend: 'Total' },
      { expr: 'sum(rate(http_requests_total{status="200"}[5m]))', legend: '2xx' },
    ],
  ),

  // Example 3: Time series panel
  timeSeriesPanelExample: dashUtils.timeSeriesPanel(
    title='Request Rate Over Time',
    unit='reqps',
    query=[
      { expr: 'sum(rate(http_requests_total[5m]))', legend: '{{status}}' },
    ],
    description='HTTP request rate by status code',
    calcs=['mean', 'max', 'last'],
  ),

  // Example 4: Time series with stacking
  timeSeriesPanelStacked: dashUtils.timeSeriesPanel(
    title='Request Rate Stacked',
    unit='reqps',
    query=[
      { expr: 'sum by(status) (rate(http_requests_total[5m]))', legend: '{{status}}' },
    ],
    stack='normal',
    fillOpacity=10,
  ),

  // Example 5: Pie chart panel
  pieChartPanelExample: dashUtils.pieChartPanel(
    title='Requests by Status Code',
    unit='short',
    query=[
      { expr: 'sum by(status) (http_requests_total)', legend: '{{status}}' },
    ],
    description='Distribution of HTTP status codes',
  ),

  // Example 6: Table panel
  tablePanelExample: dashUtils.tablePanel(
    title='Service Status',
    unit='short',
    query='up{job="my-service"}',
    description='Current status of all service instances',
  ),

  // Example 7: Heatmap panel
  heatmapPanelExample: dashUtils.heatmapPanel(
    title='Request Duration Distribution',
    unit='s',
    query='sum(rate(http_request_duration_seconds_bucket[5m])) by (le)',
    description='Distribution of HTTP request durations',
  ),

  // Example 8: Gauge panel
  gaugePanelExample: dashUtils.gaugePanel(
    title='CPU Usage',
    unit='percent',
    query='100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)',
    description='Current CPU usage percentage',
    min=0,
    max=100,
    steps=[
      g.panel.gauge.standardOptions.threshold.step.withValue(0) +
      g.panel.gauge.standardOptions.threshold.step.withColor('green'),
      g.panel.gauge.standardOptions.threshold.step.withValue(70) +
      g.panel.gauge.standardOptions.threshold.step.withColor('yellow'),
      g.panel.gauge.standardOptions.threshold.step.withValue(90) +
      g.panel.gauge.standardOptions.threshold.step.withColor('red'),
    ],
  ),

  // Example 9: Text panel
  textPanelExample: dashUtils.textPanel(
    title='Dashboard Instructions',
    content=|||
      # Welcome to the Dashboard

      This dashboard shows various metrics for the service.

      ## Key Metrics
      - **Total Requests**: Overall request count
      - **Request Rate**: Requests per second
      - **Error Rate**: Percentage of failed requests
    |||,
    description='Instructions for using this dashboard',
    mode='markdown',
  ),

  // Example 10: Logs panel (for Loki)
  logsPanelExample: dashUtils.logsPanel(
    title='Application Logs',
    query='{job="my-service"} |= "error"',
    description='Error logs from the application',
    maxLines=100,
  ),

  // Example 11: State timeline panel
  stateTimelinePanelExample: dashUtils.stateTimelinePanel(
    title='Service State Timeline',
    query='{job="my-service"} | json | line_format "{{.level}}"',
    description='Timeline of service states',
  ),
}
