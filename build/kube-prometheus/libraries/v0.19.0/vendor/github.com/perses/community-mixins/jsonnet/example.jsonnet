local dashboards = import 'dashboards.libsonnet';

local config = {
  datasource: 'custom-datasource',
  components: ['aisix', 'kubernetes', 'thanos', 'etcd', 'blackbox-exporter', 'node-exporter', 'alertmanager', 'prometheus', 'perses'],
};

local result = dashboards(config);

{
  [dashboard.metadata.name]: dashboard
  for dashboard in result.dashboards
}
