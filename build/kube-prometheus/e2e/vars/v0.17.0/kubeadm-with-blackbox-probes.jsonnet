{
  platform: 'kubeadm',
  certname: 'prod.acmecorp',
  connect_obmondo: true,
  'blackbox-exporter': true,
  kube_prometheus_version: 'v0.17.0',
  prometheus_ingress_host: 'prometheus.example.com',
  grafana_ingress_host: 'grafana.example.com',
  alertmanager_ingress_host: 'alertmanager.example.com',
}
