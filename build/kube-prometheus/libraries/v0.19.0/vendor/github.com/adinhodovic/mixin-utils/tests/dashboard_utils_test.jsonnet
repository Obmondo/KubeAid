// Comprehensive tests for dashboard utility functions
local dashUtils = (import '../utils.libsonnet').dashboards;

local tests = {
  // Test statPanel function
  testStatPanelBasic: {
    local panel = dashUtils.statPanel(
      title='Test Stat',
      unit='short',
      query='up',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'stat' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Stat',
    expected: true,
  },

  testStatPanelWithDescription: {
    local panel = dashUtils.statPanel(
      title='Test Stat',
      unit='short',
      query='up',
      description='Test description',
    ),
    result: std.objectHas(panel, 'description') &&
            panel.description == 'Test description',
    expected: true,
  },

  // Test timeSeriesPanel function
  testTimeSeriesPanelBasic: {
    local panel = dashUtils.timeSeriesPanel(
      title='Test Time Series',
      unit='short',
      query='rate(metric[5m])',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'timeseries' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Time Series',
    expected: true,
  },

  testTimeSeriesPanelWithArrayQuery: {
    local queries = [
      { expr: 'metric1', legend: 'Query 1' },
      { expr: 'metric2', legend: 'Query 2' },
    ],
    local panel = dashUtils.timeSeriesPanel(
      title='Test Multi-Query',
      unit='short',
      query=queries,
    ),
    result: std.isObject(panel) &&
            std.isArray(panel.targets) &&
            std.length(panel.targets) == 2,
    expected: true,
  },

  // Test pieChartPanel function
  testPieChartPanelBasic: {
    local panel = dashUtils.pieChartPanel(
      title='Test Pie Chart',
      unit='short',
      query='sum by(label) (metric)',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'piechart' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Pie Chart',
    expected: true,
  },

  // Test tablePanel function
  testTablePanelBasic: {
    local panel = dashUtils.tablePanel(
      title='Test Table',
      unit='short',
      query='metric',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'table' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Table',
    expected: true,
  },

  // Test heatmapPanel function
  testHeatmapPanelBasic: {
    local panel = dashUtils.heatmapPanel(
      title='Test Heatmap',
      unit='short',
      query='histogram_metric',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'heatmap' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Heatmap',
    expected: true,
  },

  // Test gaugePanel function
  testGaugePanelBasic: {
    local panel = dashUtils.gaugePanel(
      title='Test Gauge',
      unit='percent',
      query='metric',
      min=0,
      max=100,
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'gauge' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Gauge',
    expected: true,
  },

  // Test textPanel function
  testTextPanelBasic: {
    local panel = dashUtils.textPanel(
      title='Test Text',
      content='# Test Content',
      mode='markdown',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'text' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Text',
    expected: true,
  },

  // Test logsPanel function
  testLogsPanelBasic: {
    local panel = dashUtils.logsPanel(
      title='Test Logs',
      query='{job="test"}',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'logs' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test Logs',
    expected: true,
  },

  // Test stateTimelinePanel function
  testStateTimelinePanelBasic: {
    local panel = dashUtils.stateTimelinePanel(
      title='Test State Timeline',
      query='{job="test"}',
    ),
    result: std.isObject(panel) &&
            std.objectHas(panel, 'type') &&
            panel.type == 'state-timeline' &&
            std.objectHas(panel, 'title') &&
            panel.title == 'Test State Timeline',
    expected: true,
  },

  // Test helper functions
  testBypassDashboardValidation: {
    local validation = dashUtils.bypassDashboardValidation,
    result: std.isObject(validation) &&
            std.objectHas(validation, '__inputs') &&
            std.objectHas(validation, '__requires') &&
            std.isArray(validation.__inputs) &&
            std.isArray(validation.__requires),
    expected: true,
  },

  testDashboardDescriptionLink: {
    local description = dashUtils.dashboardDescriptionLink('Test Mixin', 'https://example.com'),
    result: std.isString(description) &&
            std.length(description) > 0 &&
            std.findSubstr('Test Mixin', description) != [] &&
            std.findSubstr('https://example.com', description) != [],
    expected: true,
  },

  // Test dashboardLinks function
  testDashboardLinks: {
    local config = { tags: ['test-tag'] },
    local links = dashUtils.dashboardLinks('Test Links', config),
    result: std.isArray(links) &&
            std.length(links) > 0,
    expected: true,
  },

  testPieChartColorOverride: {
    local override = dashUtils.colorOverrides.pieChartByName('Healthy', 'green'),
    result: override.matcher.id == 'byName' &&
            override.matcher.options == 'Healthy' &&
            override.properties[0].id == 'color' &&
            override.properties[0].value.fixedColor == 'green',
    expected: true,
  },

  testTimeSeriesColorOverride: {
    local override = dashUtils.colorOverrides.timeSeriesBySuffix(' - Healthy', 'green'),
    result: override.matcher.id == 'byRegexp' &&
            override.matcher.options == '.* - Healthy$' &&
            override.properties[0].id == 'color' &&
            override.properties[0].value.fixedColor == 'green',
    expected: true,
  },

  testColorOverrideMap: {
    local overrides = dashUtils.colorOverrides.timeSeriesBySuffixes({ Healthy: 'green', Degraded: 'red' }, prefix=' - '),
    result: std.length(overrides) == 2 &&
            std.set(['.* - Degraded$', '.* - Healthy$']) == std.set([override.matcher.options for override in overrides]),
    expected: true,
  },
};

// Run tests and verify all pass
local allTestsPass = std.all([
  tests[key].result == tests[key].expected
  for key in std.objectFields(tests)
]);

if allTestsPass then
  {
    success: true,
    message: 'All dashboard utils tests passed',
    tests: std.length(std.objectFields(tests)),
  }
else
  error 'Some tests failed: ' + std.toString([
    {
      test: key,
      expected: tests[key].expected,
      result: tests[key].result,
    }
    for key in std.objectFields(tests)
    if tests[key].result != tests[key].expected
  ])
