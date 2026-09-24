local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;
local annotation = g.dashboard.annotation;

local variable = dashboard.variable;
local prometheus = g.query.prometheus;
local loki = g.query.loki;

local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local table = g.panel.table;
local pieChart = g.panel.pieChart;
local heatmap = g.panel.heatmap;
local gauge = g.panel.gauge;
local text = g.panel.text;
local logs = g.panel.logs;
local stateTimeline = g.panel.stateTimeline;

// Stat
local stOptions = stat.options;
local stStandardOptions = stat.standardOptions;
local stQueryOptions = stat.queryOptions;
local stPanelOptions = stat.panelOptions;

// PieChart
local pcOptions = pieChart.options;
local pcStandardOptions = pieChart.standardOptions;
local pcPanelOptions = pieChart.panelOptions;
local pcQueryOptions = pieChart.queryOptions;
local pcLegend = pcOptions.legend;

// TimeSeries
local tsOptions = timeSeries.options;
local tsStandardOptions = timeSeries.standardOptions;
local tsPanelOptions = timeSeries.panelOptions;
local tsQueryOptions = timeSeries.queryOptions;
local tsFieldConfig = timeSeries.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

// Table
local tbOptions = table.options;
local tbStandardOptions = table.standardOptions;
local tbQueryOptions = table.queryOptions;

// Heatmap
local hmOptions = heatmap.options;
local hmPanelOptions = heatmap.panelOptions;
local hmQueryOptions = heatmap.queryOptions;

// gauge
local gaStandardOptions = gauge.standardOptions;
local gaPanelOptions = gauge.panelOptions;
local gaQueryOptions = gauge.queryOptions;

// Textpanel
local textOptions = text.options;
local textPanelOptions = text.panelOptions;

// Logs panel
local lgOptions = logs.options;
local lgQueryOptions = logs.queryOptions;
local lgPanelOptions = logs.panelOptions;

// State Timeline panel
local slStandardOptions = stateTimeline.standardOptions;
local slQueryOptions = stateTimeline.queryOptions;
local slPanelOptions = stateTimeline.panelOptions;

{
  // Bypasses grafana.com/dashboards validator
  bypassDashboardValidation: {
    __inputs: [],
    __requires: [],
  },

  dashboardDescriptionLink(name, link): 'The dashboards were generated using [%s](%s). Open issues and create feature requests in the repository.' % [name, link],

  colorOverrides: {
    pieChartByName(name, color)::
      pcStandardOptions.override.byName.new(name) +
      pcStandardOptions.override.byName.withPropertiesFromOptions(
        pcStandardOptions.color.withMode('fixed') +
        pcStandardOptions.color.withFixedColor(color)
      ),

    pieChartByNames(colors):: [
      $.colorOverrides.pieChartByName(name, colors[name])
      for name in std.objectFields(colors)
    ],

    timeSeriesByRegexp(regexp, color)::
      tsStandardOptions.override.byRegexp.new(regexp) +
      tsStandardOptions.override.byRegexp.withPropertiesFromOptions(
        tsStandardOptions.color.withMode('fixed') +
        tsStandardOptions.color.withFixedColor(color)
      ),

    timeSeriesBySuffix(suffix, color)::
      self.timeSeriesByRegexp('.*%s$' % suffix, color),

    timeSeriesBySuffixes(colors, prefix=''):: [
      $.colorOverrides.timeSeriesBySuffix('%s%s' % [prefix, name], colors[name])
      for name in std.objectFields(colors)
    ],
  },

  statPanel(
    title,
    unit,
    query,
    instant=false,
    description=null,
    graphMode='area',
    showPercentChange=false,
    decimals=null,
    percentChangeColorMode='standard',
    steps=[
      stStandardOptions.threshold.step.withValue(0) +
      stStandardOptions.threshold.step.withColor('green'),
    ],
    mappings=[],
    overrides=[],
  )::
    stat.new(title) +
    (
      if description != null then
        stPanelOptions.withDescription(description)
      else {}
    ) +
    stQueryOptions.withTargets(
      if std.isArray(query) then
        [
          prometheus.new(
            '$datasource',
            q.expr,
          ) +
          prometheus.withLegendFormat(q.legend) +
          prometheus.withInstant(std.get(q, 'instant', default=instant))
          for q in query
        ] else
        prometheus.new(
          '$datasource',
          query,
        ) +
        prometheus.withInstant(instant),
    ) +
    variable.query.withDatasource('prometheus', '$datasource') +
    stOptions.withGraphMode(graphMode) +
    stOptions.withShowPercentChange(showPercentChange) +
    stOptions.withPercentChangeColorMode(percentChangeColorMode) +
    (
      if decimals != null then
        stStandardOptions.withDecimals(decimals)
      else {}
    ) +
    stStandardOptions.withUnit(unit) +
    stStandardOptions.thresholds.withSteps(steps) +
    stStandardOptions.withMappings(
      mappings
    ) +
    stStandardOptions.withOverrides(overrides),


  pieChartPanel(title, unit, query, legend='', description='', labels=['percent'], values=['percent'], overrides=[])::
    pieChart.new(
      title,
    ) +
    pieChart.new(title) +
    (
      if description != '' then
        pcPanelOptions.withDescription(description)
      else {}
    ) +
    variable.query.withDatasource('prometheus', '$datasource') +
    pcQueryOptions.withTargets(
      if std.isArray(query) then
        [
          prometheus.new(
            '$datasource',
            q.expr,
          ) +
          prometheus.withLegendFormat(
            q.legend
          ) +
          prometheus.withInstant(true)
          for q in query
        ] else
        prometheus.new(
          '$datasource',
          query,
        ) +
        prometheus.withLegendFormat(
          legend
        ) +
        prometheus.withInstant(true)
    ) +
    pcStandardOptions.withUnit(unit) +
    pcOptions.tooltip.withMode('multi') +
    pcOptions.tooltip.withSort('desc') +
    pcOptions.withDisplayLabels(labels) +
    pcLegend.withShowLegend(true) +
    pcLegend.withDisplayMode('table') +
    pcLegend.withPlacement('right') +
    pcLegend.withValues(values) +
    pcStandardOptions.withOverrides(overrides),

  timeSeriesPanel(title, unit, query, legend='', calcs=['mean', 'max'], stack=null, description=null, fillOpacity=10, overrides=[], exemplar=false, decimals=null, min=null, max=null)::
    timeSeries.new(title) +
    (
      if description != null then
        tsPanelOptions.withDescription(description)
      else {}
    ) +
    variable.query.withDatasource('prometheus', '$datasource') +
    tsQueryOptions.withTargets(
      if std.isArray(query) then
        [
          prometheus.new(
            '$datasource',
            q.expr,
          ) +
          prometheus.withLegendFormat(
            q.legend
          ) +
          prometheus.withExemplar(
            // allows us to override exemplar per query if needed
            std.get(q, 'exemplar', default=exemplar)
          ) +
          (
            if std.get(q, 'interval', default='') != '' then
              prometheus.withInterval(q.interval)
            else {}
          )
          for q in query
        ] else
        prometheus.new(
          '$datasource',
          query,
        ) +
        prometheus.withLegendFormat(
          legend
        ) +
        prometheus.withExemplar(exemplar)
    ) +
    tsStandardOptions.withUnit(unit) +
    tsStandardOptions.withOverrides(overrides) +
    tsOptions.tooltip.withMode('multi') +
    tsOptions.tooltip.withSort('desc') +
    (
      if decimals != null then
        tsStandardOptions.withDecimals(decimals)
      else {}
    ) +
    tsLegend.withShowLegend() +
    tsLegend.withDisplayMode('table') +
    tsLegend.withPlacement('right') +
    tsLegend.withCalcs(calcs) +
    (
      if std.length(calcs) > 0 then
        tsLegend.withSortBy(
          std.asciiUpper(std.substr(calcs[0], 0, 1)) + std.substr(calcs[0], 1, std.length(calcs[0]) - 1)
        )
      else {}
    ) +
    tsLegend.withSortDesc(true) +
    tsCustom.withFillOpacity(fillOpacity) +
    (
      if stack == 'normal' then
        tsCustom.withAxisSoftMin(0) +
        tsCustom.withFillOpacity(100) +
        tsCustom.stacking.withMode(stack) +
        tsCustom.withLineWidth(1)
      else if stack == 'percent' then
        tsCustom.withFillOpacity(100) +
        tsCustom.stacking.withMode(stack) +
        tsCustom.withLineWidth(1)
      else {}
    ) +
    (
      if min != null then
        tsCustom.withAxisSoftMin(min)
      else {}
    ) +
    (
      if max != null then
        tsCustom.withAxisSoftMax(max)
      else {}
    ),

  tablePanel(title, unit, query, description=null, sortBy=null, transformations=[], overrides=[], steps=[], links=[])::
    table.new(title) +
    (
      if description != null then
        tsPanelOptions.withDescription(description)
      else {}
    ) +
    tbStandardOptions.withUnit(unit) +
    tbOptions.footer.withEnablePagination(true) +
    variable.query.withDatasource('prometheus', '$datasource') +
    tsQueryOptions.withTargets(
      if std.isArray(query) then
        [
          prometheus.new(
            '$datasource',
            q.expr,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true) +
          (
            if std.get(q, 'refId', null) != null then
              prometheus.withRefId(q.refId)
            else {}
          )
          for q in query
        ] else
        prometheus.new(
          '$datasource',
          query,
        ) +
        prometheus.withFormat('table') +
        prometheus.withInstant(true)
    ) +
    (
      if sortBy != null then
        tbOptions.withSortBy(
          tbOptions.sortBy.withDisplayName(sortBy.name) +
          tbOptions.sortBy.withDesc(sortBy.desc)
        ) else {}
    ) +
    tbQueryOptions.withTransformations(transformations) +
    tbStandardOptions.withOverrides(overrides) +
    tbStandardOptions.withLinks(links) +
    tbStandardOptions.thresholds.withSteps(steps),

  heatmapPanel(title, unit, query, description=null)::
    heatmap.new(title) +
    (
      if description != null then
        hmPanelOptions.withDescription(description)
      else {}
    ) +
    variable.query.withDatasource('prometheus', '$datasource') +
    hmQueryOptions.withTargets(
      if std.isArray(query) then
        [
          prometheus.new(
            '$datasource',
            q.expr,
          ) +
          prometheus.withLegendFormat(
            q.legend
          )
          for q in query
        ] else
        prometheus.new(
          '$datasource',
          query,
        )
    ) +
    hmOptions.withCalculate(true) +
    hmOptions.yAxis.withUnit(unit),

  gaugePanel(title, unit, query, description=null, min=0, max=100, steps=[])::
    gauge.new(title) +
    (
      if description != null then
        gaPanelOptions.withDescription(description)
      else {}
    ) +
    variable.query.withDatasource('prometheus', '$datasource') +
    gaQueryOptions.withTargets(
      if std.isArray(query) then
        [
          prometheus.new(
            '$datasource',
            q.expr,
          )
          for q in query
        ] else
        prometheus.new(
          '$datasource',
          query,
        )
    ) +
    gaStandardOptions.withUnit(unit) +
    gaStandardOptions.withMin(min) +
    gaStandardOptions.withMax(max) +
    gaStandardOptions.thresholds.withSteps(steps),

  textPanel(title, content, description=null, mode='markdown')::
    text.new(title) +
    (
      if description != null then
        textPanelOptions.withDescription(description)
      else {}
    ) +
    textOptions.withMode(mode) +
    textOptions.withContent(content),

  // Loki Logs Panel
  logsPanel(title, query, description=null, maxLines=100, showTime=true, wrapLogMessage=true, enableLogDetails=true, detailsMode='sidebar', fontSize='default', showControls=true)::
    logs.new(title) +
    (
      if description != null then
        lgPanelOptions.withDescription(description)
      else {}
    ) +
    variable.query.withDatasource('loki', '$datasource') +
    lgQueryOptions.withTargets(
      if std.isArray(query) then
        [
          loki.new(
            '$datasource',
            q.expr,
          ) +
          loki.withMaxLines(std.get(q, 'maxLines', default=maxLines))
          for q in query
        ] else
        loki.new(
          '$datasource',
          query,
        ) +
        loki.withMaxLines(maxLines)
    ) +
    lgOptions.withShowTime(showTime) +
    lgOptions.withWrapLogMessage(wrapLogMessage) +
    lgOptions.withEnableLogDetails(enableLogDetails) + {
      // These are not yet available in grafonnet, so we add them via custom options.
      options+: {
        detailsMode: detailsMode,
        fontSize: fontSize,
        showControls: showControls,
      },
    },

  // Loki State Timeline Panel
  // insertNulls: Controls gap display - value in milliseconds or boolean
  //   - number (e.g., 300000 = 5 min): Insert null after this gap duration
  //   - true: Use automatic threshold
  //   - false/null: Connect all points regardless of gaps
  stateTimelinePanel(title, query, description=null, maxLines=50, transformations=[], mappings=[], overrides=[], insertNulls=300000)::
    stateTimeline.new(title) +
    (
      if description != null then
        slPanelOptions.withDescription(description)
      else {}
    ) +
    variable.query.withDatasource('loki', '$datasource') +
    slQueryOptions.withTargets(
      if std.isArray(query) then
        [
          loki.new(
            '$datasource',
            q.expr,
          ) +
          loki.withMaxLines(std.get(q, 'maxLines', default=maxLines))
          for q in query
        ] else
        loki.new(
          '$datasource',
          query,
        ) +
        loki.withMaxLines(maxLines)
    ) +
    slQueryOptions.withTransformations(transformations) +
    slStandardOptions.withMappings(mappings) +
    slStandardOptions.withOverrides(overrides) +
    (
      if insertNulls != null then
        {
          fieldConfig+: {
            defaults+: {
              custom+: {
                insertNulls: insertNulls,
              },
            },
          },
        }
      else {}
    ),

  annotations(config, filters)::
    local customAnnotation =
      annotation.withName(config.annotation.name) +
      annotation.withIconColor(config.annotation.iconColor) +
      annotation.withEnable(true) +
      annotation.withHide(false) +
      annotation.datasource.withUid(config.annotation.datasource) +
      annotation.withType(config.annotation.type) +
      (
        if config.annotation.type == 'tags' then
          annotation.withTargetMixin({ matchAny: true }) +
          if std.length(config.annotation.tags) > 0 then
            annotation.withTargetMixin({ tags: config.annotation.tags })
          else {}
        else {}
      );

    std.prune([
      if config.annotation.enabled then customAnnotation,
    ]),

  dashboardLinks(title, config, dropdown=false, includeVars=false):: [
    dashboard.link.dashboards.new(title, config.tags) +
    dashboard.link.link.options.withTargetBlank(true) +
    dashboard.link.link.options.withAsDropdown(dropdown) +
    dashboard.link.link.options.withIncludeVars(includeVars) +
    dashboard.link.link.options.withKeepTime(true),
  ],
}
