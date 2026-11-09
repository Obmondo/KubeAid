---
title: "ntfy"

description: "A Helm chart for Kubernetes"

---

# ntfy

![Version: 0.5.25](https://img.shields.io/badge/Version-0.5.25-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.37.1](https://img.shields.io/badge/AppVersion-2.37.1-informational?style=flat-square)

A Helm chart for Kubernetes

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| WrenIX |  | <https://wrenix.eu> |

## Usage

Helm must be installed and setup to your kubernetes cluster to use the charts.
Refer to Helm's [documentation](https://helm.sh/docs) to get started.
Once Helm has been set up correctly, fetch the charts as follows:

```bash
helm pull oci://codeberg.org/wrenix/helm-charts/ntfy
```

You can install a chart release using the following command:

```bash
helm install ntfy-release oci://codeberg.org/wrenix/helm-charts/ntfy --values values.yaml
```

To uninstall a chart release use `helm`'s delete command:

```bash
helm uninstall ntfy-release
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| env | list | `[]` | set env in container for usage Environment variables |
| envFrom | list | `[]` | set envFrom in container for usage of ConfigMaps or Secrets as a bunch of Environment variables |
| fullnameOverride | string | `""` |  |
| grafana.dashboards.annotations | object | `{}` |  |
| grafana.dashboards.enabled | bool | `false` |  |
| grafana.dashboards.labels.grafana_dashboard | string | `"1"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"binwiederhier/ntfy"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| kubectl.image | object | `{"pullPolicy":"IfNotPresent","registry":"docker.io","repository":"alpine/kubectl","tag":"1.37.2"}` | image needed for setup (store generated VAPID / WebPush keys) |
| nameOverride | string | `""` |  |
| networkPolicy.egress.enabled | bool | `true` | activate egress no networkpolicy |
| networkPolicy.egress.extra | list | `[]` | egress rules |
| networkPolicy.enabled | bool | `false` |  |
| networkPolicy.ingress.http | list | `[]` | ingress for http port (e.g. ingress-controller) |
| networkPolicy.ingress.metrics | list | `[]` | ingress for metrics port (e.g. prometheus) |
| networkPolicy.ingress.smtp | list | `[]` | ingress for smtp |
| nodeSelector | object | `{}` |  |
| ntfy.attachment.cacheDir | string | `nil` |  |
| ntfy.attachment.expireDuration | string | `"3h"` |  |
| ntfy.attachment.sizeLimit.file | string | `"15M"` |  |
| ntfy.attachment.sizeLimit.total | string | `"5G"` |  |
| ntfy.auth.defaultAccess | string | `"read-write"` |  |
| ntfy.auth.file | string | `nil` |  |
| ntfy.auth.startupQueries | string | `nil` |  |
| ntfy.baseURL | string | `"https://ntfy.example.org"` |  |
| ntfy.behindProxy | bool | `true` |  |
| ntfy.cache.batch.size | int | `0` |  |
| ntfy.cache.batch.timeout | string | `"0s"` |  |
| ntfy.cache.duration | string | `"12h"` |  |
| ntfy.cache.file | string | `nil` |  |
| ntfy.cache.startupQueries | string | `nil` |  |
| ntfy.enableLogin | bool | `false` |  |
| ntfy.enableReservations | bool | `false` |  |
| ntfy.enableSignup | bool | `false` |  |
| ntfy.firebaseKeyFile | string | `nil` |  |
| ntfy.globalTopicLimit | int | `15000` |  |
| ntfy.keepaliveInterval | string | `"45s"` |  |
| ntfy.listen.certFile | string | `nil` |  |
| ntfy.listen.http | string | `":80"` |  |
| ntfy.listen.https | string | `nil` |  |
| ntfy.listen.keyFile | string | `nil` |  |
| ntfy.listen.unix | string | `nil` |  |
| ntfy.listen.unixMode | string | `nil` |  |
| ntfy.managerInterval | string | `"1m"` |  |
| ntfy.metrics.enable | bool | `true` |  |
| ntfy.metrics.port | int | `9000` |  |
| ntfy.smtp.sender.addr | string | `nil` |  |
| ntfy.smtp.sender.from | string | `nil` |  |
| ntfy.smtp.sender.pass | string | `nil` |  |
| ntfy.smtp.sender.user | string | `nil` |  |
| ntfy.smtp.server.addrPrefix | string | `nil` |  |
| ntfy.smtp.server.domain | string | `nil` |  |
| ntfy.upstreamBaseURL | string | `"https://ntfy.sh"` |  |
| ntfy.visitor.attachment.dailyBandwidthLimit | string | `"500M"` |  |
| ntfy.visitor.attachment.totalSizeLimit | string | `"100M"` |  |
| ntfy.visitor.email.limitBurst | int | `16` |  |
| ntfy.visitor.email.limitReplenish | string | `"1h"` |  |
| ntfy.visitor.request.limitBurst | int | `60` |  |
| ntfy.visitor.request.limitExemptHosts | string | `""` |  |
| ntfy.visitor.request.limitReplenish | string | `"5s"` |  |
| ntfy.visitor.subscriberRateLimiting | bool | `false` |  |
| ntfy.visitor.subscriptionLimit | int | `30` |  |
| ntfy.webPush.emailAddress | string | `""` |  |
| ntfy.webPush.file | string | `"/data/webpush.db"` |  |
| ntfy.webPush.keys.create | bool | `false` |  |
| ntfy.webPush.keys.private | string | `nil` |  |
| ntfy.webPush.keys.public | string | `nil` |  |
| ntfy.webRoot | string | `"app"` |  |
| persistence.accessMode | string | `"ReadWriteOnce"` |  |
| persistence.annotations | object | `{}` |  |
| persistence.enabled | bool | `false` |  |
| persistence.existingClaim | string | `nil` | A manually managed Persistent Volume and Claim Requires persistence.enabled: true If defined, PVC must be created manually before volume will be bound |
| persistence.hostPath | string | `nil` | Create a PV on Node with given hostPath storageClass has to be manual |
| persistence.size | string | `"1Gi"` |  |
| persistence.storageClass | string | `nil` | data Persistent Volume Storage Class If defined, storageClassName: <storageClass> If set to "-", storageClassName: "", which disables dynamic provisioning If undefined (the default) or set to null, no storageClassName spec is   set, choosing the default provisioner.  (gp2 on AWS, standard on   GKE, AWS & OpenStack) |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` | set securityContext on pod level |
| prometheus.rules.additionalRules | list | `[]` |  |
| prometheus.rules.enabled | bool | `false` |  |
| prometheus.rules.labels | object | `{}` |  |
| prometheus.servicemonitor.enabled | bool | `false` |  |
| prometheus.servicemonitor.labels | object | `{}` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` | set securityContext on container level |
| service.http.port | int | `80` |  |
| service.http.type | string | `"ClusterIP"` |  |
| service.smtp.enabled | bool | `false` |  |
| service.smtp.port | int | `25` |  |
| service.smtp.type | string | `"LoadBalancer"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| tolerations | list | `[]` |  |
| updateStrategy.type | string | `"Recreate"` |  |

Autogenerated from chart metadata using [helm-docs](https://github.com/norwoodj/helm-docs)
