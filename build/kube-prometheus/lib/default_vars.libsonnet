{
  prometheus_scrape_namespaces+: [],

  // Custom kubeaid or non kubeaid apps that need AutoSync
  kubeaid_users_apps+: [],
  kube_prometheus_version+: 'v0.17.0',
  kubeaid_apps+: [],
  prometheus_operator_resources: {
    limits: { memory: '80Mi' },
    requests: { cpu: '20m', memory: '80Mi' },
  },
  prometheus_operator_kubeRbacProxy_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },
  prometheus_operator_configReloaderResources: {
    limits: { cpu: '0', memory: '' },
    resources: { cpu: '', memory: '' },
  },
  alertmanager_resources: {
    limits: { memory: '50Mi' },
    requests: { cpu: '1m', memory: '50Mi' },
  },
  prometheus_resources: {
    limits: { memory: '3Gi' },
    requests: { cpu: '200m', memory: '2500Mi' },
  },
  prometheus_adapter_resources: {
    limits: { memory: '2Gi' },
    requests: { cpu: '200m', memory: '1500Mi' },
  },
  prometheus_adapter_additional_rules: [],
  grafana_resources: {
    limits: { memory: '250Mi' },
    requests: { cpu: '6m', memory: '200Mi' },
  },
  node_exporter_resources: {
    limits: { memory: '180Mi' },
    requests: { cpu: '3m', memory: '180Mi' },
  },
  node_exporter_kubeRbacProxyMain_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },
  kube_state_metrics_kubeRbacProxyMain_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },
  kube_state_metrics_kubeRbacProxySelf_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '1m', memory: '40Mi' },
  },
  blackbox_exporter_resources: {
    limits: { memory: '40Mi' },
    requests: { cpu: '10m', memory: '20Mi' },
  },
  blackbox_exporter_modules: {},

  grafana_keycloak_enable: false,
  grafana_root_url: '',
  grafana_keycloak_url: '',
  grafana_keycloak_realm: '',
  grafana_keycloak_client_id: 'grafana',
  grafana_keycloak_secretref: {
    name: 'kube-prometheus-stack-grafana',
    key: 'grafana-keycloak-secret',
  },
  prometheus: {
    storage: {
      size: '30Gi',
    },
    retention: '30d',
  },
  grafana_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  prometheus_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  alertmanager_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  addMixins: {
    ceph: false,
    'argo-cd': true,
    'node-pressure': true,
    sealedsecrets: true,
    etcd: true,
    velero: false,
    zfs: false,
    opensearch: false,
    'cert-manager': true,
    'hpa-maxed-out': true,
    'kubernetes-version-info': true,
    // Enable this when we move metrics generation into obmondo-k8s-agent
    // gitea/EnableIT/internal/issues/21
    'node-count-monthly-status': false,
    'argo-cd-sync-state': true,
    rabbitmq: false,
    'monitor-prometheus-stack': false,
    smartmon: false,
    mdraid: true,
    opencost: false,
    'kubelet-cert-expiry': false,
    'orphan-pvc': true,
  },
  mixin_configs: {
    // Example:
    //
    // velero+: {
    //   selector: 'schedule=~"^ops.+"',
    // },
  },
  'blackbox-exporter': true,
  connect_keda: false,
  grafana_plugins+: [],
  grafana_dashboards+: {},
}
