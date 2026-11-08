# Gotenberg

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/gotenberg)](https://artifacthub.io/packages/helm/maikumori/gotenberg)
![Version: 1.22.0](https://img.shields.io/badge/Version-1.22.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 8.34.0](https://img.shields.io/badge/AppVersion-8.34.0-informational?style=flat-square)

This is a HELM chart for Gotenberg.

Gotenberg provides a developer-friendly API to interact with powerful tools like Chromium and LibreOffice for converting numerous document formats (HTML, Markdown, Word, Excel, etc.) into PDF files, and more!

Upstream links:

- [Homepage](https://gotenberg.dev/)
- [Documentation](https://gotenberg.dev/docs/about)
- [GitHub](https://github.com/gotenberg/gotenberg)

## Get Repo Info

```console
helm repo add maikumori https://maikumori.github.io/helm-charts
helm repo update
```

## Installing the Chart

To install the chart with the release name `my-release`:

```console
helm install my-release --namespace gotenberg maikumori/gotenberg
```

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Upgrading Chart

```console
helm upgrade my-release maikumori/gotenberg --install
```

### Using a Newer Gotenberg Version

Chart releases are typically published when new features or breaking changes are added to Gotenberg that require chart modifications. However, you can use any version of Gotenberg by overriding the `image.tag` value.

To use a specific version of Gotenberg:

```console
helm upgrade --install my-release maikumori/gotenberg --set image.tag="8.23.0"
```

Or with the `--atomic` flag for automatic rollback on failure:

```console
helm upgrade --install --atomic my-release maikumori/gotenberg --set image.tag="8.23.0"
```

This allows you to stay current with Gotenberg releases without waiting for a new chart version, as there are typically no breaking changes between versions.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| api.basicAuthPassword | string | `nil` | Set the basic authentication password (ignored if existingSecret is set) |
| api.basicAuthUsername | string | `nil` | Set the basic authentication username (ignored if existingSecret is set) |
| api.bodyLimit | string | `""` | Set the request body limit for multipart/form-data (e.g., "100MB") |
| api.correlationIdHeader | string | `""` | Set the header name to use for identifying requests (default "Gotenberg-Trace") |
| api.disableDebugRouteTelemetry | bool | `false` | Disable telemetry on the debug route |
| api.disableDownloadFrom | bool | `false` | Disable the download from feature |
| api.disableHealthCheckLogging | DEPRECATED | `false` | Disable health check route telemetry. Use disableHealthCheckRouteTelemetry instead. |
| api.disableHealthCheckRouteTelemetry | bool | `false` | Disable health check route telemetry. Note: upstream default changed to true in Gotenberg 8.29.0 (health check telemetry is disabled by default even without this flag). |
| api.disableRootRouteTelemetry | bool | `false` | Disable telemetry on the root route |
| api.disableVersionRouteTelemetry | bool | `false` | Disable telemetry on the version route |
| api.downloadFromAllowList | string | `""` | Set the allowed URLs for the download from feature using a regular expression |
| api.downloadFromDenyList | string | `""` | Set the denied URLs for the download from feature using a regular expression |
| api.downloadFromDenyPrivateIps | bool | `false` | Reject `downloadFrom` URLs resolving to a non-public IP (loopback, RFC1918, link-local, IPv6 unique-local). A URL matching `downloadFromAllowList` skips the IP-class check; a URL matching `downloadFromDenyList` is always rejected. Added in Gotenberg 8.32.0. |
| api.downloadFromDenyPublicIps | bool | `false` | Reject `downloadFrom` URLs resolving to a public IP. Setting both `downloadFromDenyPrivateIps` and `downloadFromDenyPublicIps` to true rejects every URL unless the allow-list matches. Added in Gotenberg 8.32.0. |
| api.downloadFromMaxRetry | int | `4` | Set the maximum number of retries for the download from feature (default 4) |
| api.enableBasicAuth | bool | `false` | Enable basic authentication, see also the basicAuthUsername and basicAuthPassword values |
| api.enableDebugRoute | bool | `false` | Enable debug route for debugging purposes |
| api.existingSecret | string | `""` | Name of an existing secret containing basic auth credentials (keys: username, password) |
| api.existingSecretPasswordKey | string | `""` | Key in existingSecret for the password (default: password) |
| api.existingSecretUsernameKey | string | `""` | Key in existingSecret for the username (default: username) |
| api.port | int | `3000` | Set the port on which the API should listen (default 3000) |
| api.rootPath | string | `""` | Set the root path of the API - for service discovery via URL paths (default "/") |
| api.startTimeout | string | `""` | Set the maximum duration to wait for the API to start |
| api.timeout | string | `""` | Set the time limit for requests (default 30s) |
| api.tlsSecretName | string | `""` | Enables TLS on the API server: K8S TLS secret name containing the TLS certificate and key (tls.crt, tls.key) |
| api.traceHeader | DEPRECATED | `""` | Set the header name to use for identifying requests. Use correlationIdHeader instead. |
| autoscaling.behavior | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.extraMetrics | list | `[]` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| chromium.allowFileAccessFromFiles | bool | `false` | Allow file:// URIs to read other file:// URIs |
| chromium.allowInsecureLocalhost | bool | `false` | Ignore TLS/SSL errors on localhost |
| chromium.allowList | string | `""` | Set the allowed URLs for Chromium using a regular expression |
| chromium.autoStart | bool | `false` | Automatically launch Chromium upon initialization if set to true; otherwise, Chromium will start at the time of the first conversion |
| chromium.clearCache | bool | `false` | Clear Chromium cache between each conversion. |
| chromium.clearCookies | bool | `false` | Clear Chromium cookies between each conversion. |
| chromium.denyList | string | `""` | Set the denied URLs for Chromium using a regular expression (default "^file:///[^tmp].*") |
| chromium.denyPrivateIps | bool | `false` | Reject Chromium navigations and sub-resources resolving to a non-public IP (loopback, RFC1918, link-local, IPv6 unique-local). A URL matching `allowList` skips the IP-class check; a URL matching `denyList` is always rejected. Added in Gotenberg 8.32.0. Skipped when `proxyServer` or `hostResolverRules` is set. |
| chromium.denyPublicIps | bool | `false` | Reject Chromium navigations and sub-resources resolving to a public IP. Setting both `denyPrivateIps` and `denyPublicIps` to true rejects every URL unless the allow-list matches. Added in Gotenberg 8.32.0. |
| chromium.disableJavaScript | bool | `false` | Disable JavaScript |
| chromium.disableRoutes | bool | `false` | Disable the routes |
| chromium.disableWebSecurity | bool | `false` | Don't enforce the same-origin policy |
| chromium.hostResolverRules | string | `""` | Set custom mappings to the host resolver |
| chromium.idleShutdownTimeout | string | `""` | Duration after which idle Chromium browser processes are shut down (e.g., "30s"). Set to 0s or leave empty to disable (default 0s, disabled). |
| chromium.ignoreCertificateErrors | bool | `false` | Ignore the certificate errors |
| chromium.incognito | DEPRECATED | `false` | Start Chromium with incognito mode. This flag is deprecated as of Gotenberg 8.25.0 and its value is ignored. |
| chromium.maxConcurrency | int | `0` | Maximum number of concurrent Chromium conversions (default 6) |
| chromium.maxQueueSize | int | `0` | Maximum request queue size for Chromium. Set to 0 to disable this feature. |
| chromium.proxyServer | string | `""` | Set the outbound proxy server; this switch only affects HTTP and HTTPS requests |
| chromium.restartAfter | string | `""` | Number of conversions after which Chromium will automatically restart. Set to 0 to disable this feature (default 100) |
| chromium.startTimeout | string | `""` | Maximum duration to wait for Chromium to start or restart |
| extraEnv | list | `[]` | List of extra environment variables for gotenberg container. Gotenberg 8.29.0+ supports OpenTelemetry via standard OTEL_* environment variables. See https://gotenberg.dev/docs/configuration for details. |
| fullnameOverride | string | `""` |  |
| gateway.annotations | object | `{}` | Annotations to add to the HTTPRoute |
| gateway.enabled | bool | `false` | Set to true to create an HTTPRoute resource |
| gateway.hostnames | list | `[]` | Hostnames to match for routing, see values.yaml for an example. |
| gateway.labels | object | `{}` | Labels to add to the HTTPRoute |
| gateway.parentRefs | list | `[]` | Parent Gateway references, see values.yaml for an example. |
| gotenberg.gracefulShutdownDurationSec | int | `30` | Set the graceful shutdown duration (default 30s) |
| gotenberg.hideBanner | bool | `false` | Hide the Gotenberg banner on startup |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"gotenberg/gotenberg"` |  |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` | Set the annotations of the ingress |
| ingress.className | string | `""` | Set the class name of the ingress |
| ingress.enabled | bool | `false` | Set to true to enable ingress record generation. WARNING: Gotenberg shouldn't be exposed to the internet. |
| ingress.hosts | list | `[]` | Set the hostnames of the ingress, see values.yaml for an example. |
| ingress.labels | object | `{}` | Set the labels of the ingress |
| ingress.tls | list | `[]` | Set the TLS configuration for the ingress, see values.yaml for an example. |
| initContainers | list | `[]` | List of init containers for the gotenberg pod |
| libreOffice.allowList | string | `""` | Set the allowed URLs for LibreOffice outbound fetches (embedded external content in OOXML/RTF/ODF) using a regular expression. Added in Gotenberg 8.32.0. |
| libreOffice.autoStart | bool | `false` | Automatically launch LibreOffce upon initialization if set to true; otherwise, LibreOffice will start at the time of the first conversion (default false) |
| libreOffice.denyList | string | `""` | Set the denied URLs for LibreOffice outbound fetches using a regular expression. Added in Gotenberg 8.32.0. |
| libreOffice.denyPrivateIps | bool | `false` | Reject LibreOffice outbound fetches resolving to a non-public IP (loopback, RFC1918, link-local, IPv6 unique-local). A URL matching `allowList` skips the IP-class check; a URL matching `denyList` is always rejected. Added in Gotenberg 8.32.0. |
| libreOffice.denyPublicIps | bool | `false` | Reject LibreOffice outbound fetches resolving to a public IP. Setting both `denyPrivateIps` and `denyPublicIps` to true rejects every URL unless the allow-list matches. Added in Gotenberg 8.32.0. |
| libreOffice.disableRoutes | bool | `false` | Disable the routes |
| libreOffice.idleShutdownTimeout | string | `""` | Duration after which idle LibreOffice processes are shut down (e.g., "30s"). Set to 0s or leave empty to disable (default 0s, disabled). |
| libreOffice.maxQueueSize | int | `0` | Maximum request queue size for LibreOffice. Set to 0 to disable this feature. |
| libreOffice.restartAfter | string | `""` | Number of conversions after which LibreOffice will automatically restart. Set to 0 to disable this feature (default 10) |
| libreOffice.startTimeout | string | `""` | Maximum duration to wait for LibreOffice to start or restart (default 10s) |
| livenessProbe | object | `{"httpGet":{"path":"/health","port":"http"}}` | Define the liveness probe object for the container. +docs:property livenessProbe: {} |
| logging.enableGcpFields | DEPRECATED | `false` | Enable GCP log field mapping for Cloud Run. Use stdEnableGcpFields instead. |
| logging.enableGcpSeverity | bool | `false` | Enable GCP severity field mapping |
| logging.fieldsPrefix | string | `""` | Prepend a specified prefix to each field in the logs |
| logging.format | DEPRECATED | `""` | Set log format. Use stdFormat instead. |
| logging.level | string | `""` | Set the log level - error, warn, info, or debug (default "info") |
| logging.stdEnableGcpFields | bool | `false` | Enable GCP log standard output field mapping for Cloud Run |
| logging.stdFormat | string | `""` | Set log standard output format - auto, json, or text (default "auto") |
| logging.stdLevelCase | string | `""` | Set the case of the `level` field in standard output - lower or upper (default "lower"). Added in Gotenberg 8.34.0. |
| metrics.serviceMonitor.annotations | object | `{}` | Additional annotations for the service monitor |
| metrics.serviceMonitor.enabled | bool | `false` | Enable ServiceMonitor |
| metrics.serviceMonitor.honorLabels | bool | `false` | HonorLabels chooses the metric’s labels on collisions with target labels |
| metrics.serviceMonitor.interval | string | `nil` | Interval at which metrics should be scraped |
| metrics.serviceMonitor.jobLabel | string | `nil` | Optional job label for the target service in Prometheus |
| metrics.serviceMonitor.labels | object | `{}` | Additional labels for the service monitor |
| metrics.serviceMonitor.metricRelabelings | list | `[]` | List of metric relabel configs to apply to samples before ingestion |
| metrics.serviceMonitor.namespace | string | `nil` | Namespace for ServiceMonitor, defaults to release namespace |
| metrics.serviceMonitor.relabelings | list | `[]` | List of relabel configs to apply to samples before scraping |
| metrics.serviceMonitor.scrapeTimeout | string | `nil` | Timeout after which the scrape is ended |
| nameOverride | string | `""` |  |
| networkPolicy.allowEgress | bool | `true` |  |
| networkPolicy.allowIngress | bool | `true` |  |
| networkPolicy.enabled | bool | `false` |  |
| networkPolicy.extraEgress | list | `[]` |  |
| networkPolicy.extraIngress | list | `[]` |  |
| nodeSelector | object | `{}` |  |
| pdb.create | bool | `false` |  |
| pdb.maxUnavailable | string | `""` |  |
| pdb.minAvailable | int | `1` |  |
| pdb.unhealthyPodEvictionPolicy | string | `nil` | Unhealthy pod eviction policy for the PDB (e.g., AlwaysAllow) |
| pdfEngines.convertEngines | string | `""` | Set the PDF engines and their order for the convert feature (default libreoffice-pdfengine) |
| pdfEngines.disableRoutes | bool | `false` | Disable the routes |
| pdfEngines.embedEngines | string | `""` | Set the PDF engines and their order for the file embedding feature (default pdfcpu) |
| pdfEngines.embedMetadataEngines | string | `""` | Set the PDF engines and their order for the embed metadata feature (default qpdf) |
| pdfEngines.encryptEngines | string | `""` | Set the PDF engines and their order for the password protection feature (default qpdf,pdftk,pdfcpu) |
| pdfEngines.engines | DEPRECATED | `""` | Set the PDF engines and their order. This flag was deprecated in Gotenberg 8.13.0 and its value is ignored. Use the per-feature engine flags instead (mergeEngines, splitEngines, flattenEngines, convertEngines, readMetadataEngines, writeMetadataEngines, encryptEngines, embedEngines). |
| pdfEngines.facturXEngines | string | `""` | Set the PDF engines and their order for the Factur-X XMP metadata feature (default qpdf). Added in Gotenberg 8.34.0. |
| pdfEngines.flattenEngines | string | `""` | Set the PDF engines and their order for the flatten feature (default qpdf) |
| pdfEngines.mergeEngines | string | `""` | Set the PDF engines and their order for the merge feature (default qpdf,pdfcpu,pdftk) |
| pdfEngines.readBookmarksEngines | string | `""` | Set the PDF engines and their order for the read bookmarks feature (default pdfcpu) |
| pdfEngines.readMetadataEngines | string | `""` | Set the PDF engines and their order for the read metadata feature (default exiftool) |
| pdfEngines.rotateEngines | string | `""` | Set the PDF engines and their order for the rotate feature (default pdfcpu,pdftk) |
| pdfEngines.splitEngines | string | `""` | Set the PDF engines and their order for the split feature (default pdfcpu,qpdf,pdftk) |
| pdfEngines.stampEngines | string | `""` | Set the PDF engines and their order for the stamp feature (default pdfcpu,pdftk) |
| pdfEngines.watermarkEngines | string | `""` | Set the PDF engines and their order for the watermark feature (default pdfcpu,pdftk) |
| pdfEngines.writeBookmarksEngines | string | `""` | Set the PDF engines and their order for the write bookmarks feature (default pdfcpu,pdftk) |
| pdfEngines.writeMetadataEngines | string | `""` | Set the PDF engines and their order for the write metadata feature (default exiftool) |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` | List of additional pod labels |
| podSecurityContext | object | `{}` |  |
| progressDeadlineSeconds | int | `120` |  |
| prometheus.collectInterval | string | `""` | Set the interval for collecting modules' metrics (default 1s) |
| prometheus.disableCollect | bool | `false` | Disable the collect of metrics |
| prometheus.disableRouteTelemetry | bool | `false` | Disable route telemetry for the Prometheus metrics endpoint |
| prometheus.disableRouterLogging | DEPRECATED | `false` | Disable the route logging. Use disableRouteTelemetry instead. |
| prometheus.metricsPath | string | `""` | Set the metrics endpoint path (default "/prometheus/metrics") |
| prometheus.namespace | string | `""` | Set the namespace of modules' metrics (default "gotenberg") |
| readinessProbe | object | `{"httpGet":{"path":"/health","port":"http"}}` | Define the readiness probe object for the container. +docs:property readinessProbe: {} |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{ privileged: false, runAsUser: 1001 }`, except in OpenShift where `runAsUser` is not set. | Define the security context for the container. By default will use upstream recommended values. |
| service.annotations | object | `{}` | Annotations to add to the service |
| service.loadBalancerIP | DEPRECATED | `""` | Static IP address for LoadBalancer type service. Deprecated in Kubernetes 1.24, use provider-specific annotations instead. |
| service.port | int | `80` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `false` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. # If not set and create is true, a name is generated using the fullname template |
| startupProbe | object | `{"failureThreshold":30,"httpGet":{"path":"/health","port":"http"},"periodSeconds":10}` | Define the startup probe object for the container. +docs:property startupProbe: {} |
| strategy | object | `{}` |  |
| testImage | object | `{"repository":"busybox","tag":"latest"}` | Image configuration for the helm test pod |
| testImage.repository | string | `"busybox"` | Repository for the test image |
| testImage.tag | string | `"latest"` | Tag for the test image |
| testPodAnnotations | object | `{}` | Set annotations for the helm test pods (for example to disable certain kube-score checks) |
| tolerations | list | `[]` |  |
| topologySpreadConstraints | list | `[]` |  |
| volumeMounts | list | `[]` |  |
| volumes | list | `[]` |  |
| vpa.create | bool | `false` | Create a VerticalPodAutoscaler resource for right-sizing pod resources. Requires the VPA controller to be installed in the cluster. See also: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler |
| vpa.resourcePolicy | object | `{}` | Resource policy for VPA to control which containers and resources are autoscaled, see values.yaml for an example. |
| vpa.updateMode | string | `"Auto"` | Update mode for VPA: Auto (resize in-place or restart), Recreate (restart to resize), Initial (set at creation only), Off (recommendations only) |
| webhook.allowList | string | `""` | Set the allowed URLs for the webhook feature using a regular expression. In Gotenberg 8.31.0+ this applies to both regular and error webhooks. |
| webhook.clientTimeout | string | `""` | Set the time limit for requests to the webhook (default 30s) |
| webhook.denyList | string | `""` | Set the denied URLs for the webhook feature using a regular expression. In Gotenberg 8.31.0+ this applies to both regular and error webhooks. Note: 8.31.0's permissive-by-default revert means this defaults to empty again in 8.32.0+; opt into IP-class filtering via `denyPrivateIps` / `denyPublicIps`. |
| webhook.denyPrivateIps | bool | `false` | Reject webhook URLs (success, error, events) resolving to a non-public IP (loopback, RFC1918, link-local, IPv6 unique-local). A URL matching `allowList` skips the IP-class check; a URL matching `denyList` is always rejected. Added in Gotenberg 8.32.0. |
| webhook.denyPublicIps | bool | `false` | Reject webhook URLs resolving to a public IP. Setting both `denyPrivateIps` and `denyPublicIps` to true rejects every URL unless the allow-list matches. Added in Gotenberg 8.32.0. |
| webhook.disable | bool | `false` | Disable the webhook feature |
| webhook.enableSyncMode | bool | `false` | Enable synchronous mode for the webhook feature |
| webhook.errorAllowList | DEPRECATED | `""` | Set the allowed URLs in case of an error for the webhook feature using a regular expression. Use `allowList` instead in Gotenberg 8.31.0+ — it now covers both regular and error webhooks. |
| webhook.errorDenyList | DEPRECATED | `""` | Set the denied URLs in case of an error for the webhook feature using a regular expression. Use `denyList` instead in Gotenberg 8.31.0+ — it now covers both regular and error webhooks. |
| webhook.maxRetry | string | `""` | Set the maximum number of retries for the webhook feature (default 4) |
| webhook.retryMaxWait | string | `""` | Set the maximum duration to wait before trying to call the webhook again (default 30s) |
| webhook.retryMinWait | string | `""` | Set the minimum duration to wait before trying to call the webhook again (default 1s) |
