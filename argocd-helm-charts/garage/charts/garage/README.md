# garage

![Version: 0.6.0](https://img.shields.io/badge/Version-0.6.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v2.3.0](https://img.shields.io/badge/AppVersion-v2.3.0-informational?style=flat-square)

S3-compatible object store for small self-hosted geo-distributed deployments.

**Homepage:** <https://garagehq.deuxfleurs.fr/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| alvsanand |  |  |

## Source Code

* <https://git.deuxfleurs.fr/Deuxfleurs/garage.git>
* <https://github.com/datahub-local/garage-helm/garage>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| clusterConfig | object | `{"affinity":{},"buckets":[],"configureImage":{"pullPolicy":"IfNotPresent","repository":"busybox","tag":"latest"},"enabled":false,"extraCommands":[],"image":{"pullPolicy":"IfNotPresent","repository":"","tag":""},"imagePullSecrets":[],"keys":{},"layout":{"capacity":"","enabled":true,"zone":"dc1"},"nodeSelector":{},"podAnnotations":{},"podSecurityContext":{"fsGroup":1000,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000},"resources":{},"securityContext":{"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true},"tolerations":[],"toolsImage":{"pullPolicy":"IfNotPresent","repository":"busybox","tag":"musl"}}` | Garage Cluster configuration |
| clusterConfig.affinity | object | `{}` | Affinity |
| clusterConfig.helmSync | object | `{"asHook":true,"ttlSecondsAfterFinished":300}` | Change sync behaviour with helm (helm install or helm upgrade) |
| clusterConfig.helmSync.asHook | bool | `true` | If true, the configure job runs as a post-install/post-upgrade hook (waits for all resources to be ready first). Set to false to run the job as a regular resource alongside other pods. |
| clusterConfig.helmSync.ttlSecondsAfterFinished | int | `300` | Time in seconds to keep the completed job before automatic cleanup (only applies when asHook is false) |
| clusterConfig.buckets | list | `[]` | List of buckets to create |
| clusterConfig.configureImage.repository | string | `"busybox"` | Image to use for the configure task for the configuration job |
| clusterConfig.enabled | bool | `false` | Enable the cluster configuration job |
| clusterConfig.extraCommands | list | `[]` | Extra commands to run |
| clusterConfig.image.repository | string | `""` | Image to use for the configuration job (defaults to the same as garage) |
| clusterConfig.imagePullSecrets | list | `[]` | Image pull secrets |
| clusterConfig.keys | object | `{}` | Dict of keys to create keyId format: must start with 'GK' followed by 24 hex-encoded characters (12 bytes) secretKey format: must be 64 hex-encoded characters (32 bytes) |
| clusterConfig.layout.capacity | string | `""` | Capacity to assign to nodes. If empty, defaults to persistence.data.size |
| clusterConfig.layout.enabled | bool | `true` | Enable layout configuration |
| clusterConfig.layout.zone | string | `"dc1"` | Zone to assign nodes to |
| clusterConfig.nodeSelector | object | `{}` | Node selector |
| clusterConfig.podAnnotations | object | `{}` | Pod annotations |
| clusterConfig.podSecurityContext | object | `{"fsGroup":1000,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | Pod security context |
| clusterConfig.resources | object | `{}` | Resources for the job |
| clusterConfig.securityContext | object | `{"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container security context |
| clusterConfig.tolerations | list | `[]` | Tolerations |
| clusterConfig.toolsImage.repository | string | `"busybox"` | Image to use for the tools task for the configuration job |
| commonLabels | object | `{}` | Additional labels to add to all resources created by this chart |
| deployment.kind | string | `"StatefulSet"` | Switchable to DaemonSet |
| deployment.podManagementPolicy | string | `"OrderedReady"` | If using statefulset, allow Parallel or OrderedReady (default) |
| deployment.replicaCount | int | `3` | Number of StatefulSet replicas/garage nodes to start |
| environment | object | `{}` |  |
| extraResources | list | `[]` | Extra resources to deploy |
| extraVolumeMounts | object | `{}` |  |
| extraVolumes | object | `{}` |  |
| fullnameOverride | string | `""` |  |
| garage.blockSize | string | `"1048576"` | Defaults is 1MB An increase can result in better performance in certain scenarios https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/#block_size |
| garage.bootstrapPeers | list | `[]` | This is not required if you use the integrated kubernetes discovery |
| garage.compressionLevel | string | `"1"` | zstd compression level of stored blocks https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/#compression_level |
| garage.consistencyMode | string | `"consistent"` | By default, enable read-after-write consistency guarantees, see the consistency_mode section at https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/#consistency_mode |
| garage.dbEngine | string | `"lmdb"` | Can be changed for better performance on certain systems https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/#db_engine |
| garage.existingConfigMap | string | `""` | if not empty string, allow using an existing ConfigMap for the garage.toml, if set, ignores garage.toml |
| garage.garageTomlString | string | `""` | String Template for the garage configuration if set, ignores above values. Values can be templated, see https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/ |
| garage.kubernetesSkipCrd | bool | `false` | Set to true if you want to use k8s discovery but install the CRDs manually outside of the helm chart, for example if you operate at namespace level without cluster ressources |
| garage.metadataAutoSnapshotInterval | string | `""` | If this value is set, Garage will automatically take a snapshot of the metadata DB file at a regular interval and save it in the metadata directory. https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/#metadata_auto_snapshot_interval |
| garage.replicationFactor | string | `"3"` | Default to 3 replicas, see the replication_factor section at https://garagehq.deuxfleurs.fr/documentation/reference-manual/configuration/#replication_factor |
| garage.rpc.bindAddr | string | `"[::]:3901"` |  |
| garage.s3.api.region | string | `"garage"` |  |
| garage.s3.api.rootDomain | string | `".s3.garage.tld"` |  |
| garage.s3.web.index | string | `"index.html"` |  |
| garage.s3.web.rootDomain | string | `".web.garage.tld"` |  |
| garage.secret.adminToken | string | `""` | Must be provided together with garage.secret.rpcSecret. If both are omitted, random values are generated. |
| garage.secret.create | bool | `true` | Flag to control if a kubernetes secret should be created during deployment |
| garage.secret.name | string | `""` | Name of the secret. If you want to use a pre-existing kubernetes secret use the name of an already existing secret and set secret.create to false |
| garage.secret.rpcSecret | string | `""` | Must be provided together with garage.secret.adminToken. If both are omitted, random values are generated. |
| gatewayApi | object | `{"s3":{"api":{"additionalRules":{},"annotations":{},"enabled":false,"filters":[],"hostnames":["s3.garage.ltd","*.s3.garage.ltd"],"labels":{},"matches":[{"path":{"type":"PathPrefix","value":"/"}}],"parentRefs":[]},"web":{"additionalRules":{},"annotations":{},"enabled":false,"filters":[],"hostnames":["*.web.garage.tld"],"labels":{},"matches":[{"path":{"type":"PathPrefix","value":"/"}}],"parentRefs":[]}}}` | Support for gateway api |
| gatewayApi.s3.api | object | `{"additionalRules":{},"annotations":{},"enabled":false,"filters":[],"hostnames":["s3.garage.ltd","*.s3.garage.ltd"],"labels":{},"matches":[{"path":{"type":"PathPrefix","value":"/"}}],"parentRefs":[]}` | Creates route for the S3 api |
| gatewayApi.s3.api.additionalRules | object | `{}` | Any custom rule you want to specify |
| gatewayApi.s3.api.annotations | object | `{}` | Additional annotations for the HTTPRoute |
| gatewayApi.s3.api.enabled | bool | `false` | Flag to control if HTTP route should be created |
| gatewayApi.s3.api.filters | list | `[]` | Filter that should be added to the default rule |
| gatewayApi.s3.api.hostnames | list | `["s3.garage.ltd","*.s3.garage.ltd"]` | Hostnames of the HTTPRoute |
| gatewayApi.s3.api.labels | object | `{}` | Additional labels for the HTTPRoute |
| gatewayApi.s3.api.matches | list | `[{"path":{"type":"PathPrefix","value":"/"}}]` | Matches for the default rule |
| gatewayApi.s3.api.parentRefs | list | `[]` | Gateway reference that the HTTPRoute should bind against |
| gatewayApi.s3.web | object | `{"additionalRules":{},"annotations":{},"enabled":false,"filters":[],"hostnames":["*.web.garage.tld"],"labels":{},"matches":[{"path":{"type":"PathPrefix","value":"/"}}],"parentRefs":[]}` | Route for Web buckets |
| gatewayApi.s3.web.additionalRules | object | `{}` | Any custom rule you want to specify |
| gatewayApi.s3.web.annotations | object | `{}` | Additional annotations for the HTTPRoute |
| gatewayApi.s3.web.enabled | bool | `false` | Flag to control if HTTP route should be created |
| gatewayApi.s3.web.filters | list | `[]` | Filter that should be added to the default rule |
| gatewayApi.s3.web.hostnames | list | `["*.web.garage.tld"]` | Hostnames of the HTTPRoute |
| gatewayApi.s3.web.labels | object | `{}` | Additional labels for the HTTPRoute |
| gatewayApi.s3.web.matches | list | `[{"path":{"type":"PathPrefix","value":"/"}}]` | Matches for the default rule |
| gatewayApi.s3.web.parentRefs | list | `[]` | Gateway reference that the HTTPRoute should bind against |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"dxflrs/garage"` | default to Docker image |
| image.tag | string | `""` | set the image tag, please prefer using the chart version and not this to avoid compatibility issues |
| imagePullSecrets | list | `[]` | set if you need credentials to pull your custom image |
| ingress.s3.api.annotations | object | `{}` |  |
| ingress.s3.api.className | string | `""` | Rely _either_ on the className or the annotation below but not both! If you want to use the className, set className: "nginx" and replace "nginx" by an Ingress controller name, examples [here](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers). |
| ingress.s3.api.enabled | bool | `false` |  |
| ingress.s3.api.hosts[0] | object | `{"host":"s3.garage.tld","paths":[{"path":"/","pathType":"Prefix"}]}` | garage S3 API endpoint, to be used with awscli for example |
| ingress.s3.api.hosts[1] | object | `{"host":"*.s3.garage.tld","paths":[{"path":"/","pathType":"Prefix"}]}` | garage S3 API endpoint, DNS style bucket access |
| ingress.s3.api.labels | object | `{}` |  |
| ingress.s3.api.tls | list | `[]` |  |
| ingress.s3.web.annotations | object | `{}` |  |
| ingress.s3.web.className | string | `""` | Rely _either_ on the className or the annotation below but not both! If you want to use the className, set className: "nginx" and replace "nginx" by an Ingress controller name, examples [here](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers). |
| ingress.s3.web.enabled | bool | `false` |  |
| ingress.s3.web.hosts[0] | object | `{"host":"*.web.garage.tld","paths":[{"path":"/","pathType":"Prefix"}]}` | wildcard website access with bucket name prefix |
| ingress.s3.web.hosts[1] | object | `{"host":"mywebpage.example.com","paths":[{"path":"/","pathType":"Prefix"}]}` | specific bucket access with FQDN bucket |
| ingress.s3.web.labels | object | `{}` |  |
| ingress.s3.web.tls | list | `[]` |  |
| livenessProbe | object | `{}` | Specifies a livenessProbe |
| monitoring | object | `{"grafanaDashboard":{"annotations":{},"enabled":false},"metrics":{"enabled":false,"serviceMonitor":{"enabled":false,"interval":"15s","labels":{},"namespace":"","path":"/metrics","relabelings":[],"scheme":"http","scrapeTimeout":"10s","tlsConfig":{}}},"tracing":{"sink":""}}` | Garage Cluster monmitoring configuration |
| monitoring.grafanaDashboard.enabled | bool | `false` | If enabled deploys the grafana dashboard as configmap |
| monitoring.metrics.enabled | bool | `false` | If true, a service for monitoring is created with a prometheus.io/scrape annotation |
| monitoring.metrics.serviceMonitor.enabled | bool | `false` | If true, a ServiceMonitor CRD is created for a prometheus operator https://github.com/coreos/prometheus-operator |
| monitoring.tracing.sink | string | `""` | specify a sink endpoint for OpenTelemetry Traces, eg. `http://localhost:4317` |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| persistence.data.hostPath | string | `"/var/lib/garage/data"` |  |
| persistence.data.size | string | `"1Gi"` |  |
| persistence.data.storageClass | string | `nil` | This would classically be a "slow" storage type like HDDs |
| persistence.enabled | bool | `true` |  |
| persistence.meta.hostPath | string | `"/var/lib/garage/meta"` |  |
| persistence.meta.size | string | `"100Mi"` |  |
| persistence.meta.storageClass | string | `nil` | Use a storage class with a preferably fast storage type |
| podAnnotations | object | `{}` | additonal pod annotations |
| podSecurityContext.fsGroup | int | `1000` |  |
| podSecurityContext.fsGroupChangePolicy | string | `"OnRootMismatch"` |  |
| podSecurityContext.runAsGroup | int | `1000` |  |
| podSecurityContext.runAsNonRoot | bool | `true` |  |
| podSecurityContext.runAsUser | int | `1000` |  |
| readinessProbe | object | `{}` | Specifies a readinessProbe |
| resources | object | `{}` |  |
| securityContext.capabilities | object | `{"drop":["ALL"]}` | The default security context is heavily restricted, feel free to tune it to your requirements |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| service.ports.admin | int | `3903` |  |
| service.ports.rpc | int | `3901` |  |
| service.ports.s3Api | int | `3900` |  |
| service.ports.s3Web | int | `3902` |  |
| service.type | string | `"ClusterIP"` | You can rely on any service to expose your cluster - ClusterIP (+ Ingress) - NodePort (+ Ingress) - LoadBalancer |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` |  |
| webui.affinity | object | `{}` | affinity for WebUI pods |
| webui.auth.enabled | bool | `false` | Enable authentication for WebUI |
| webui.auth.existingSecret | string | `""` | Use an existing secret for authentication (must contain 'webuiAuthUserPass' key) |
| webui.auth.userPassHash | string | `""` | When the chart manages the auth secret, provide this together with garage.secret.rpcSecret and garage.secret.adminToken. Generate with: htpasswd -nbBC 10 "username" "password" Example: "admin:$2y$10$DSTi9o..." |
| webui.basePath | string | `"/"` | Base path or prefix for Web UI |
| webui.enabled | bool | `false` | Enable the garage-webui deployment |
| webui.extraVolumeMounts | object | `{}` | extra volume mounts for WebUI |
| webui.extraVolumes | object | `{}` | extra volumes for WebUI |
| webui.gatewayApi | object | `{"additionalRules":{},"annotations":{},"enabled":false,"filters":[],"hostnames":["garage-webui.tld"],"labels":{},"matches":[{"path":{"type":"PathPrefix","value":"/"}}],"parentRefs":[]}` | Gateway API configuration for WebUI |
| webui.gatewayApi.additionalRules | object | `{}` | Any custom rule you want to specify |
| webui.gatewayApi.annotations | object | `{}` | Additional annotations for the HTTPRoute |
| webui.gatewayApi.enabled | bool | `false` | Enable gateway API HTTPRoute for WebUI |
| webui.gatewayApi.filters | list | `[]` | Filters that should be added to the default rule |
| webui.gatewayApi.hostnames | list | `["garage-webui.tld"]` | Hostnames of the HTTPRoute |
| webui.gatewayApi.labels | object | `{}` | Additional labels for the HTTPRoute |
| webui.gatewayApi.matches | list | `[{"path":{"type":"PathPrefix","value":"/"}}]` | Matches for the default rule |
| webui.gatewayApi.parentRefs | list | `[]` | Gateway reference that the HTTPRoute should bind against |
| webui.image.pullPolicy | string | `"IfNotPresent"` | image pull policy |
| webui.image.repository | string | `"khairul169/garage-webui"` | garage-webui image repository |
| webui.image.tag | string | `"1.1.0"` | garage-webui image tag |
| webui.imagePullSecrets | list | `[]` | image pull secrets for private registries |
| webui.ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"garage-webui.tld","paths":[{"path":"/","pathType":"Prefix"}]}],"labels":{},"tls":[]}` | Ingress configuration for WebUI |
| webui.ingress.annotations | object | `{}` | Ingress annotations |
| webui.ingress.className | string | `""` | Ingress class name |
| webui.ingress.enabled | bool | `false` | Enable ingress for WebUI |
| webui.ingress.hosts | list | `[{"host":"garage-webui.tld","paths":[{"path":"/","pathType":"Prefix"}]}]` | Ingress hosts configuration |
| webui.ingress.labels | object | `{}` | Additional labels for the ingress |
| webui.ingress.tls | list | `[]` | TLS configuration |
| webui.livenessProbe | object | `{}` | WebUI liveness probe |
| webui.nodeSelector | object | `{}` | node selector for WebUI pods |
| webui.podAnnotations | object | `{}` | pod annotations |
| webui.podSecurityContext | object | `{"fsGroup":1000,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | pod security context |
| webui.readinessProbe | object | `{}` | WebUI readiness probe |
| webui.replicaCount | int | `1` | Number of WebUI replicas |
| webui.resources | object | `{}` | WebUI resources |
| webui.securityContext | object | `{"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | container security context |
| webui.service | object | `{"annotations":{},"port":3909,"type":"ClusterIP"}` | WebUI service configuration |
| webui.service.annotations | object | `{}` | Service annotations |
| webui.service.port | int | `3909` | Service port |
| webui.service.type | string | `"ClusterIP"` | Service type |
| webui.tolerations | list | `[]` | tolerations for WebUI pods |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
