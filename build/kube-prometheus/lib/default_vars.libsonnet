{
  prometheus_scrape_namespaces+: [],

  // Custom kubeaid or non kubeaid apps that need AutoSync
  kubeaid_users_apps+: [],
  kube_prometheus_version+: 'v0.17.0',
  kubeaid_apps+: [],
  // Names from kubeaid_apps/kubeaid_users_apps to exclude from the
  // ArgoCdAppOutOfSync/ArgoCdAppUnhealthy alerts. Set per-cluster in
  // <cluster>-vars.jsonnet.
  kubeaid_apps_ignore_out_of_sync+: [],
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
  prometheus_adapter_replicas: 2,
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
  blackbox_exporter_oauth_modules: {},
  prometheus_probe_module: 'http_2xx',

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
  etcd_metrics: {
    namespace: 'kube-system',
    serviceName: 'etcd',
    port: 2381,
    scheme: 'http',
    path: '/metrics',
    interval: '30s',
    serviceMonitorNamespace: 'monitoring',
    addressType: 'IPv4',
    endpoints: [],
  },
  grafana_blackbox_probe_enabled: true,
  grafana_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  prometheus_blackbox_probe_enabled: true,
  prometheus_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  alertmanager_blackbox_probe_enabled: true,
  alertmanager_ingress_annotations: {
    'cert-manager.io/cluster-issuer': 'letsencrypt',
  },
  // spec.ingressClassName on the monitoring ingresses. Clusters whose Traefik
  // IngressClass is not named 'traefik' (e.g. traefik-private) must override
  // this, otherwise nothing claims the ingress and requests 404. Set to null
  // to omit the field and fall back to the cluster's default IngressClass.
  grafana_ingress_class_name: 'traefik',
  prometheus_ingress_class_name: 'traefik',
  alertmanager_ingress_class_name: 'traefik',
  // app.kubernetes.io/name carried by the Traefik pods that serve the
  // monitoring ingresses. Clusters running Traefik under a differently-named
  // Helm release (e.g. traefik-private) must override this, otherwise the
  // NetworkPolicies below never match and requests time out with a 504.
  traefik_pod_name: 'traefik',
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
