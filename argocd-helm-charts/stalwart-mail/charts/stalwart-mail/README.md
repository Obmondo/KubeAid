---
title: "stalwart-mail"

description: "Helm Chart for Stalwart Mail Server - Secure & Modern All-in-One Mail Server (IMAP, JMAP, SMTP)"

---

# stalwart-mail

![Version: 2.0.8](https://img.shields.io/badge/Version-2.0.8-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.16.18](https://img.shields.io/badge/AppVersion-0.16.18-informational?style=flat-square)

Helm Chart for Stalwart Mail Server - Secure & Modern All-in-One Mail Server (IMAP, JMAP, SMTP)

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| WrenIX |  | <https://wrenix.eu> |

## Alpha
{{< callout type="warning" >}}
Current stalwart is not stable and we are also not stable.

We have current known issues:
* cluster setup is not fully supported (so please keep replicas=1), see more in [issue for cluster](https://codeberg.org/wrenix/helm-charts/issues/294)
* toml interpreter of stalwart and golang (helm) are different, so we remove all `.0` in the rendering to be compatible with stalwart-toml
{{< /callout >}}

## Usage

Helm must be installed and setup to your kubernetes cluster to use the charts.
Refer to Helm's [documentation](https://helm.sh/docs) to get started.
Once Helm has been set up correctly, fetch the charts as follows:

```bash
helm pull oci://codeberg.org/wrenix/helm-charts/stalwart-mail
```

You can install a chart release using the following command:

```bash
helm install stalwart-mail-release oci://codeberg.org/wrenix/helm-charts/stalwart-mail --values values.yaml
```

To uninstall a chart release use `helm`'s delete command:

```bash
helm uninstall stalwart-mail-release
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://nats-io.github.io/k8s/helm/charts/ | nats | 2.14.5 |

## Values

### Observability

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| grafana.dashboards.annotations | object | `{}` | label of configmap |
| grafana.dashboards.enabled | bool | `false` | deploy grafana dashboard in configmap |
| grafana.dashboards.labels | object | `{"grafana_dashboard":"1"}` | label of configmap |
| nats.promExporter.enabled | bool | `false` | deploy prometheus exporter to NATS (in coordinator setup) |
| nats.promExporter.podMonitor.enabled | bool | `false` | deploy pod monitor for NATS prometheus exporter (in coordinator setup) |
| prometheus.servicemonitor.enabled | bool | `false` | deploy servicemonitor |
| prometheus.servicemonitor.labels | object | `{}` | label of servicemonitor |
| secrets.env.METRICS_SECRET | string | `"scrape_metrics_password"` | basic auth metrics password in secret for stalwart-mail |
| secrets.env.METRICS_USERNAME | string | `"scrape_metrics_user"` | basic auth metrics username in secret for stalwart-mail |

### Cluster

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| nats.config | object | `{}` | NATS configure |
| nats.enabled | bool | `false` | deploy a NATS and configure stalwart to use it as coordinator |
| replicaCount | int | `1` | replicas |
| updateStrategy | object | `{}` | updateStrategy |

### Authentification

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| secrets.env.FALLBACK_ADMIN_SECRET | string | `"supersecret"` | password for fallback authentfication (env) |

### Root-FR Webmail Client

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| webclients.rootFr.enabled | bool | `false` | deploy a |
| webclients.rootFr.image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. (could be overwritten by global.image.pullPolicy) |
| webclients.rootFr.image.registry | string | `"ghcr.io"` | image registry (could be overwritten by global.image.registry) |
| webclients.rootFr.image.repository | string | `"root-fr/jmap-webmail"` | image repository |
| webclients.rootFr.image.tag | string | `"1.6.0"` | image tag |
| webclients.rootFr.service.ipFamilyPolicy | string | `"SingleStack"` | other option is RequireDualStack |
| webclients.rootFr.service.type | string | `"ClusterIP"` | service type |
| webclients.rootFr.volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| webclients.rootFr.volumes | list | `[]` | Additional volumes on the output Deployment definition. |

### Twake Webmail Client

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| webclients.twake.enabled | bool | `false` | deploy a |
| webclients.twake.image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. (could be overwritten by global.image.pullPolicy) |
| webclients.twake.image.registry | string | `"ghcr.io"` | image registry (could be overwritten by global.image.registry) |
| webclients.twake.image.repository | string | `"linagora/tmail-web"` | image repository |
| webclients.twake.image.tag | string | `"v0.35.1"` | image tag |
| webclients.twake.service.ipFamilyPolicy | string | `"SingleStack"` | other option is RequireDualStack |
| webclients.twake.service.type | string | `"ClusterIP"` | service type |
| webclients.twake.volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| webclients.twake.volumes | list | `[]` | Additional volumes on the output Deployment definition. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| certificate.certmanager.dnsNames[0] | string | `"chart-example.local"` |  |
| certificate.certmanager.enabled | bool | `true` |  |
| certificate.certmanager.issuerRef.group | string | `"cert-manager.io"` |  |
| certificate.certmanager.issuerRef.kind | string | `"ClusterIssuer"` |  |
| certificate.certmanager.issuerRef.name | string | `"letsencrypt-prod"` |  |
| certificate.secretName | string | `nil` | not needed if certmanager is used |
| config | object | `{"@type":"","authSecret":{"@type":"Value","secret":""},"authUsername":"","database":"","host":""}` | json config for stalwart |
| envFrom | list | `[]` |  |
| env[0].name | string | `"STALWART_RECOVERY_MODE"` |  |
| env[0].value | string | `"1"` |  |
| env[1].name | string | `"STALWART_RECOVERY_ADMIN"` |  |
| env[1].value | string | `"admin:$(FALLBACK_ADMIN_SECRET)"` |  |
| fullnameOverride | string | `""` |  |
| global.image.pullPolicy | string | `nil` | if set it will overwrite all pullPolicy |
| global.image.registry | string | `nil` | if set it will overwrite all registry entries |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. (could be overwritten by global.image.pullPolicy) |
| image.registry | string | `"ghcr.io"` | image registry (could be overwritten by global.image.registry) |
| image.repository | string | `"stalwartlabs/stalwart"` | image repository |
| image.tag | string | `""` | image tag - Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"admin.chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.hosts[1].host | string | `"chart-example.local"` |  |
| ingress.hosts[1].paths[0].path | string | `"/"` |  |
| ingress.hosts[1].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.httpGet.httpHeaders[0] | object | `{"name":"X-Forwarded-For","value":"127.0.0.1"}` | send fake X-Forwarded-For for not generate warnings |
| livenessProbe.httpGet.path | string | `"/healthz/live"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| livenessProbe.initialDelaySeconds | int | `5` |  |
| livenessProbe.periodSeconds | int | `10` |  |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| persistence.accessMode | string | `"ReadWriteOnce"` | accessMode |
| persistence.annotations | object | `{}` |  |
| persistence.enabled | bool | `true` | Enable persistence using Persistent Volume Claims ref: http://kubernetes.io/docs/user-guide/persistent-volumes/ |
| persistence.existingClaim | string | `nil` | A manually managed Persistent Volume and Claim Requires persistence.enabled: true If defined, PVC must be created manually before volume will be bound |
| persistence.hostPath | string | `nil` | Do not create an PVC, direct use hostPath in Pod |
| persistence.size | string | `"10Gi"` | size |
| persistence.storageClass | string | `nil` | Persistent Volume Storage Class If defined, storageClassName: <storageClass> If set to "-", storageClassName: "", which disables dynamic provisioning If undefined (the default) or set to null, no storageClassName spec is   set, choosing the default provisioner.  (gp2 on AWS, standard on   GKE, AWS & OpenStack) |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| readinessProbe.httpGet.httpHeaders[0] | object | `{"name":"X-Forwarded-For","value":"127.0.0.1"}` | send fake X-Forwarded-For for not generate warnings |
| readinessProbe.httpGet.path | string | `"/healthz/ready"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| readinessProbe.initialDelaySeconds | int | `30` |  |
| readinessProbe.periodSeconds | int | `10` |  |
| resources | object | `{}` |  |
| secrets.create | bool | `true` | enables env secret creation from secrets.env values    NOTE: The env variables below should be manually    passed in the pod if disabled. |
| securityContext | object | `{}` |  |
| service.annotations | object | `{}` |  |
| service.externalTrafficPolicy | string | `nil` |  |
| service.ipFamilies[0] | string | `"IPv4"` |  |
| service.ipFamilyPolicy | string | `"SingleStack"` | other option is RequireDualStack |
| service.ports.http | int | `80` |  |
| service.ports.https | int | `443` |  |
| service.ports.imap | int | `143` |  |
| service.ports.imaptls | int | `993` |  |
| service.ports.pop3 | int | `110` |  |
| service.ports.pop3s | int | `995` |  |
| service.ports.sieve | int | `4190` |  |
| service.ports.smtp | int | `25` |  |
| service.ports.submission | int | `587` |  |
| service.ports.submissions | int | `465` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `false` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` |  |
| traefik.enabled | bool | `false` |  |
| traefik.ports.https.entrypoint | string | `"websecure"` |  |
| traefik.ports.https.match | string | `nil` |  |
| traefik.ports.https.passthroughTLS | bool | `true` |  |
| traefik.ports.https.proxyProtocol | bool | `true` |  |
| traefik.ports.imaptls.entrypoint | string | `"imaps"` |  |
| traefik.ports.imaptls.match | string | `nil` |  |
| traefik.ports.imaptls.passthroughTLS | bool | `true` |  |
| traefik.ports.imaptls.proxyProtocol | bool | `true` |  |
| traefik.ports.pop3s.entrypoint | string | `"pop3s"` |  |
| traefik.ports.pop3s.match | string | `nil` |  |
| traefik.ports.pop3s.passthroughTLS | bool | `true` |  |
| traefik.ports.pop3s.proxyProtocol | bool | `true` |  |
| traefik.ports.sieve.entrypoint | string | `"sieve"` |  |
| traefik.ports.sieve.match | string | `nil` |  |
| traefik.ports.sieve.passthroughTLS | bool | `true` |  |
| traefik.ports.sieve.proxyProtocol | bool | `true` |  |
| traefik.ports.smtp.entrypoint | string | `"smtp"` |  |
| traefik.ports.smtp.match | string | `nil` |  |
| traefik.ports.smtp.proxyProtocol | bool | `true` |  |
| traefik.ports.submissions.entrypoint | string | `"smtps"` |  |
| traefik.ports.submissions.match | string | `nil` |  |
| traefik.ports.submissions.passthroughTLS | bool | `true` |  |
| traefik.ports.submissions.proxyProtocol | bool | `true` |  |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |
| webclients.networkPolicy.egress.enabled | bool | `true` |  |
| webclients.networkPolicy.egress.extra | list | `[]` |  |
| webclients.networkPolicy.enabled | bool | `false` |  |
| webclients.networkPolicy.ingress.http | list | `[]` |  |
| webclients.rootFr.affinity | object | `{}` |  |
| webclients.rootFr.config.env.APP_NAME | string | `"My Stalwart Webmail"` |  |
| webclients.rootFr.config.env.JMAP_SERVER_URL | string | `"https://{{ (.Values.ingress.hosts | first).host }}/"` |  |
| webclients.rootFr.config.env.SESSION_SECRET.valueFrom.secretKeyRef.key | string | `"session_secret"` |  |
| webclients.rootFr.config.env.SESSION_SECRET.valueFrom.secretKeyRef.name | string | `"{{ printf \"%s-rootfr\" (include \"stalwart-mail.fullname\" .) }}"` |  |
| webclients.rootFr.create.sessionSecret | bool | `true` |  |
| webclients.rootFr.ingress.annotations | object | `{}` |  |
| webclients.rootFr.ingress.className | string | `""` |  |
| webclients.rootFr.ingress.enabled | bool | `false` |  |
| webclients.rootFr.ingress.hosts[0].host | string | `"chart-example.local"` |  |
| webclients.rootFr.ingress.hosts[0].paths[0].path | string | `"/"` |  |
| webclients.rootFr.ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| webclients.rootFr.ingress.tls | list | `[]` |  |
| webclients.rootFr.livenessProbe.httpGet.path | string | `"/api/health"` |  |
| webclients.rootFr.livenessProbe.httpGet.port | string | `"http"` |  |
| webclients.rootFr.livenessProbe.initialDelaySeconds | int | `5` |  |
| webclients.rootFr.livenessProbe.periodSeconds | int | `10` |  |
| webclients.rootFr.nodeSelector | object | `{}` |  |
| webclients.rootFr.podAnnotations | object | `{}` |  |
| webclients.rootFr.podLabels | object | `{}` |  |
| webclients.rootFr.podSecurityContext | object | `{}` |  |
| webclients.rootFr.readinessProbe.httpGet.path | string | `"/api/health"` |  |
| webclients.rootFr.readinessProbe.httpGet.port | string | `"http"` |  |
| webclients.rootFr.readinessProbe.initialDelaySeconds | int | `30` |  |
| webclients.rootFr.readinessProbe.periodSeconds | int | `10` |  |
| webclients.rootFr.resources | object | `{}` |  |
| webclients.rootFr.securityContext | object | `{}` |  |
| webclients.rootFr.service.annotations | object | `{}` |  |
| webclients.rootFr.service.ipFamilies[0] | string | `"IPv4"` |  |
| webclients.rootFr.tolerations | list | `[]` |  |
| webclients.twake.affinity | object | `{}` |  |
| webclients.twake.config.dashboard.apps[0].appLink | string | `"https://{{ (.Values.ingress.hosts | first).host }}"` |  |
| webclients.twake.config.dashboard.apps[0].name | string | `"Administration"` |  |
| webclients.twake.config.dashboard.apps[0].publicIconUri | string | `"https://{{ (.Values.ingress.hosts | first).host }}/apple-touch-icon.png"` |  |
| webclients.twake.config.env.APP_GRID_AVAILABLE | string | `"supported"` |  |
| webclients.twake.config.env.DOMAIN_REDIRECT_URL | string | `"https://{{ (.Values.webclients.twake.ingress.hosts | first).host }}"` |  |
| webclients.twake.config.env.FORCE_EMAIL_QUERY | bool | `false` |  |
| webclients.twake.config.env.FORWARD_WARNING_MESSAGE | string | `""` |  |
| webclients.twake.config.env.OIDC_SCOPES[0] | string | `"openid"` |  |
| webclients.twake.config.env.OIDC_SCOPES[1] | string | `"profile"` |  |
| webclients.twake.config.env.OIDC_SCOPES[2] | string | `"email"` |  |
| webclients.twake.config.env.OIDC_SCOPES[3] | string | `"offline_access"` |  |
| webclients.twake.config.env.PLATFORM | string | `"other"` |  |
| webclients.twake.config.env.SERVER_URL | string | `"https://{{ (.Values.ingress.hosts | first).host }}/"` |  |
| webclients.twake.config.env.WEB_OIDC_CLIENT_ID | string | `"teammail-web"` |  |
| webclients.twake.config.env.WS_ECHO_PING | bool | `true` |  |
| webclients.twake.ingress.annotations | object | `{}` |  |
| webclients.twake.ingress.className | string | `""` |  |
| webclients.twake.ingress.enabled | bool | `false` |  |
| webclients.twake.ingress.hosts[0].host | string | `"chart-example.local"` |  |
| webclients.twake.ingress.hosts[0].paths[0].path | string | `"/"` |  |
| webclients.twake.ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| webclients.twake.ingress.tls | list | `[]` |  |
| webclients.twake.livenessProbe.httpGet.path | string | `"/"` |  |
| webclients.twake.livenessProbe.httpGet.port | string | `"http"` |  |
| webclients.twake.livenessProbe.initialDelaySeconds | int | `5` |  |
| webclients.twake.livenessProbe.periodSeconds | int | `10` |  |
| webclients.twake.nodeSelector | object | `{}` |  |
| webclients.twake.podAnnotations | object | `{}` |  |
| webclients.twake.podLabels | object | `{}` |  |
| webclients.twake.podSecurityContext | object | `{}` |  |
| webclients.twake.readinessProbe.httpGet.path | string | `"/"` |  |
| webclients.twake.readinessProbe.httpGet.port | string | `"http"` |  |
| webclients.twake.readinessProbe.initialDelaySeconds | int | `30` |  |
| webclients.twake.readinessProbe.periodSeconds | int | `10` |  |
| webclients.twake.resources | object | `{}` |  |
| webclients.twake.securityContext | object | `{}` |  |
| webclients.twake.service.annotations | object | `{}` |  |
| webclients.twake.service.ipFamilies[0] | string | `"IPv4"` |  |
| webclients.twake.tolerations | list | `[]` |  |

Autogenerated from chart metadata using [helm-docs](https://github.com/norwoodj/helm-docs)

