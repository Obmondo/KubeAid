local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local custom = variable.custom;
local datasource = variable.datasource;
local query = variable.query;

local extractJobName(selector) =
  local cleaned = std.strReplace(selector, 'job="', '');
  std.strReplace(cleaned, '"', '');

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,

    opencostJob: 'job="$opencost_job"',
    ksmJob: 'job="$ksm_job"',

    namespace: '%(namespaceLabel)s="$namespace"' % config,
    workloadType: 'workload_type=~"$workload_type"',
    workload: 'workload=~"$workload"',
    clusterLabel: config.clusterLabel,
    namespaceLabel: config.namespaceLabel,
    podLabel: config.podLabel,
    containerLabel: config.containerLabel,
    instanceLabel: config.instanceLabel,

    opencostDefault: |||
      %(cluster)s,
      %(opencostJob)s
    ||| % this,

    opencostWithNamespace: |||
      %(opencostDefault)s,
      %(namespace)s
    ||| % this,

    ksmDefault: |||
      %(cluster)s,
      %(ksmJob)s
    ||| % this,

    ksmWithNamespace: |||
      %(ksmDefault)s,
      %(namespace)s
    ||| % this,

    withNamespaceWorkload: |||
      %(cluster)s,
      %(namespace)s,
      %(workloadType)s,
      %(workload)s
    ||| % this,
  },

  variables(config):: {
    local this = self,

    local defaultFilters = $.filters(config),

    datasource:
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      query.new('cluster') +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        config.clusterLabel,
        'opencost_build_info{}',
      ) +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      query.withSort() +
      (
        if config.showMultiCluster
        then
          query.generalOptions.showOnDashboard.withLabelAndValue() +
          query.selectionOptions.withMulti(value=config.multiClusterAllowsMultipleSelection) +
          query.selectionOptions.withIncludeAll(value=config.multiClusterIncludeAllValue)
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    opencostJob:
      if config.dashboardDynamicJobDiscovery then
        query.new('opencost_job') +
        query.withDatasourceFromVariable(this.datasource) +
        query.queryTypes.withLabelValues(
          'job',
          'opencost_build_info{%(clusterLabel)s="$cluster"}' % config,
        ) +
        query.withSort() +
        query.generalOptions.withLabel('OpenCost Job') +
        query.selectionOptions.withMulti(false) +
        query.selectionOptions.withIncludeAll(false) +
        query.refresh.onLoad() +
        query.refresh.onTime()
      else
        custom.new(
          'opencost_job',
          [extractJobName(config.openCostSelector)]
        ) +
        custom.generalOptions.withLabel('OpenCost Job'),

    ksmJob:
      if config.dashboardDynamicJobDiscovery then
        query.new('ksm_job') +
        query.withDatasourceFromVariable(this.datasource) +
        query.queryTypes.withLabelValues(
          'job',
          'kube_node_status_capacity{%(clusterLabel)s="$cluster"}' % config,
        ) +
        query.withSort() +
        query.generalOptions.withLabel('KSM Job') +
        query.selectionOptions.withMulti(false) +
        query.selectionOptions.withIncludeAll(false) +
        query.refresh.onLoad() +
        query.refresh.onTime()
      else
        custom.new(
          'ksm_job',
          [extractJobName(config.kubeStateMetricsSelector)]
        ) +
        custom.generalOptions.withLabel('KSM Job'),

    namespace:
      query.new('namespace') +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        config.namespaceLabel,
        'kube_namespace_status_phase{%(cluster)s, %(ksmJob)s}' % defaultFilters,
      ) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    workloadType:
      query.new('workload_type') +
      query.selectionOptions.withIncludeAll() +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        'workload_type',
        'namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}' % config,
      ) +
      query.generalOptions.withLabel('Workload Type') +
      query.refresh.onTime() +
      query.generalOptions.showOnDashboard.withLabelAndValue() +
      query.withSort(type='alphabetical'),

    workload:
      query.new('workload') +
      query.selectionOptions.withIncludeAll() +
      query.withDatasourceFromVariable(this.datasource) +
      query.queryTypes.withLabelValues(
        'workload',
        'namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload_type=~"$workload_type"}' % config,
      ) +
      query.generalOptions.withLabel('Workload') +
      query.refresh.onTime() +
      query.generalOptions.showOnDashboard.withLabelAndValue() +
      query.withSort(type='alphabetical'),
  },
}
