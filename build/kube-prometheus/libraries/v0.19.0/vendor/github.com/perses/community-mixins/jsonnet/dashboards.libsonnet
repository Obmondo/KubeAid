local overrides = import 'overrideDashboard.libsonnet';

local defaults = {
  local defaults = self,
  namespace: 'perses-dev',
  commonLabels:: {
    'app.kubernetes.io/component': 'dashboard',
    'app.kubernetes.io/name': 'perses-dashboard',
    'app.kubernetes.io/part-of': 'perses-operator',
  },
  datasource: 'prometheus-datasource',
  components: ['aisix', 'kubernetes', 'thanos', 'etcd', 'blackbox-exporter', 'node-exporter', 'alertmanager', 'prometheus', 'perses'],
};

function(params) {
  local cd = self,
  config:: defaults + params,

  local aisixOverview = if std.member(cd.config.components, 'aisix') then overrides.overrideDashboard(
    import 'dashboards/operator/aisix/aisix-ai-gateway-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local alertmanagerOverview = if std.member(cd.config.components, 'alertmanager') then overrides.overrideDashboard(
    import 'dashboards/operator/alertmanager/alertmanager-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local blackboxExporter = if std.member(cd.config.components, 'blackbox-exporter') then overrides.overrideDashboard(
    import 'dashboards/operator/blackbox-exporter/blackbox-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local etcdOverview = if std.member(cd.config.components, 'etcd') then overrides.overrideDashboard(
    import 'dashboards/operator/etcd/etcd-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local apiServerOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/api-server-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local kubeControllerManagerOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/controller-manager-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local kubeSchedulerOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/scheduler-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local kubeProxyOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/proxy-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local kubeletOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubelet-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local clusterNetworkingOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-cluster-networking-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local clusterResourceOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-cluster-resources-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local multiClusterOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-multi-cluster-resources-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local namespaceNetworkingOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-namespace-networking-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local namespaceResourceOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-namespace-resources-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local nodeOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-node-resources-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local persistentVolumeOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-persistent-volume-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local podNetworkingOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-pod-networking-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local podOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-pod-resources-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local workloadOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-workload-resources-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local workloadNetworkingOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-workload-networking-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local workloadNSResourceOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-workload-ns-resources-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local workloadNSNetworkingOverview = if std.member(cd.config.components, 'kubernetes') then overrides.overrideDashboard(
    import 'dashboards/operator/kubernetes/kubernetes-workload-ns-networking-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local nodeExporterClusterUSE = if std.member(cd.config.components, 'node-exporter') then overrides.overrideDashboard(
    import 'dashboards/operator/node-exporter/node-exporter-cluster-use-method.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local nodeExporterNodes = if std.member(cd.config.components, 'node-exporter') then overrides.overrideDashboard(
    import 'dashboards/operator/node-exporter/node-exporter-nodes.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local persesOverview = if std.member(cd.config.components, 'perses') then overrides.overrideDashboard(
    import 'dashboards/operator/perses/perses-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local prometheusOverview = if std.member(cd.config.components, 'prometheus') then overrides.overrideDashboard(
    import 'dashboards/operator/prometheus/prometheus-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local prometheusRemoteWrite = if std.member(cd.config.components, 'prometheus') then overrides.overrideDashboard(
    import 'dashboards/operator/prometheus/prometheus-remote-write.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local thanosCompactOverview = if std.member(cd.config.components, 'thanos') then overrides.overrideDashboard(
    import 'dashboards/operator/thanos/thanos-compact-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local thanosRulerOverview = if std.member(cd.config.components, 'thanos') then overrides.overrideDashboard(
    import 'dashboards/operator/thanos/thanos-ruler-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local thanosStoreOverview = if std.member(cd.config.components, 'thanos') then overrides.overrideDashboard(
    import 'dashboards/operator/thanos/thanos-store-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local thanosQueryOverview = if std.member(cd.config.components, 'thanos') then overrides.overrideDashboard(
    import 'dashboards/operator/thanos/thanos-query-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local thanosReceiveOverview = if std.member(cd.config.components, 'thanos') then overrides.overrideDashboard(
    import 'dashboards/operator/thanos/thanos-receive-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local thanosQueryFrontendOverview = if std.member(cd.config.components, 'thanos') then overrides.overrideDashboard(
    import 'dashboards/operator/thanos/thanos-query-frontend-overview.json',
    cd.config.namespace,
    cd.config.commonLabels,
    cd.config.datasource
  ) else {},

  local dashboardList = [
    aisixOverview,
    alertmanagerOverview,
    blackboxExporter,
    etcdOverview,
    apiServerOverview,
    kubeControllerManagerOverview,
    kubeSchedulerOverview,
    kubeProxyOverview,
    kubeletOverview,
    clusterNetworkingOverview,
    clusterResourceOverview,
    multiClusterOverview,
    namespaceNetworkingOverview,
    namespaceResourceOverview,
    nodeOverview,
    persistentVolumeOverview,
    podNetworkingOverview,
    podOverview,
    workloadOverview,
    workloadNetworkingOverview,
    workloadNSResourceOverview,
    workloadNSNetworkingOverview,
    nodeExporterClusterUSE,
    nodeExporterNodes,
    persesOverview,
    prometheusOverview,
    prometheusRemoteWrite,
    thanosCompactOverview,
    thanosRulerOverview,
    thanosStoreOverview,
    thanosQueryOverview,
    thanosReceiveOverview,
    thanosQueryFrontendOverview,
  ],

  // Return only non-empty dashboards
  dashboards: std.filter(function(d) std.length(d) > 0, dashboardList),
}
