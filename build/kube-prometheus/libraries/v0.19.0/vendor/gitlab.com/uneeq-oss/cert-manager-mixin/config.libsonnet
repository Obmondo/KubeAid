// Prometheus Mixin Config
{
  _config+:: {
    certManagerCertExpiryDays: '21',
    certManagerJobLabel: 'cert-manager',
    certManagerRunbookURLPattern: 'https://gitlab.com/uneeq-oss/cert-manager-mixin/-/blob/master/RUNBOOK.md#%s',
    grafanaExternalUrl: 'https://grafana.example.com',
  },
}
