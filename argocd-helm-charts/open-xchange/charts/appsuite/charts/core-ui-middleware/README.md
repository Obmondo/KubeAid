# UI Service

Provides the collected manifest.json of services in a cluster as well as a list of dependencies
for each source file. This information can be used to dynamically compile all ui components at
runtime in the browser. Besides serving the information about all resources, this service can
also function to provide snapshots of all the resources available at a specific point in time.

## Requirements

* Redis (always required, for version coordination and pub/sub)
* For the S3 storage backend: an S3 compatible storage bucket (e.g. Minio)

## Storage backend

Asset bytes (manifests, JS, CSS, assets) are stored in one of two backends,
selected with `storage.backend` (see ADR 0010). Redis is required either way;
the switch only decides where the *files* live.

* **S3** (the strategic direction): an S3 compatible bucket is the source of
  truth for all UI files. Recommended for scalable, multi-replica, and
  multi-site setups.
* **Redis**: asset bytes are kept in Redis (compatibility mode for operators who
  cannot run S3). Redis memory then scales with total asset volume across
  retained versions.

`storage.backend` defaults to `auto`, which resolves to S3 when S3 is configured
(`s3.endpoint` set, or `minio.enabled: true`) and to Redis otherwise. An
unchanged 2.x values file (no S3 configured) therefore keeps running on the
Redis backend after an upgrade, while a fresh install that supplies S3 gets the
S3 path. Set `storage.backend` to `s3` or `redis` to force the choice.

### Redis default setup

For setups where scaling of the UI middleware is not necessary you can use the default values of the helm chart, which will deploy a redis server as a sidecar container.

### Minio setup

In cases where no external S3 storage is available or desired, you can use a Minio deployment that is part of this
helm chart by setting `minio.enabled: true`. This deploys an in-cluster S3 and makes the storage backend resolve to S3.
We are referencing the [bitnami/minio](https://github.com/bitnami/charts/tree/main/bitnami/minio) chart for this purpose,
so please refer to their documentation for all available options.
We recommend to at least enable persistence for the Minio deployment, as the UI Service will store all files in the
S3 bucket and those should not be lost when the Minio pod is restarted.

So there are three options to run the S3 storage backend for the UI Service:

1. Use an external S3 storage (preferred for production and multi-site setups)
2. Use the Minio deployment with persistence (should also work for simple production environments)
3. Use the Minio deployment without persistence (for development and testing)

Generally we advise to use an external S3 storage for production setups instead of the integrated Minio deployment.

The integrated Bitnami MinIO chart requires a `rootPassword` to be set in your `values.yaml` file.
If this value is not set, MinIO will generate a random password during the initial installation, which can cause future upgrades to fail.
**Due to Minio's password policy, the password must be at least 8 characters long.**

```yaml
minio:
  auth:
    rootPassword: "myrootpassword"
```

#### Minio Resources

In standalone mode, Minio requests 2G memory by default.
Therefore we configure memory limits to match this, by default.
In practice we have seen this working with much less memory (like 256Mi), so you might
want to adjust this value to your needs.

## Configuration Parameters

### Deployment Configuration

Basic Kubernetes deployment settings for the UI middleware service.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `replicaCount` | N/A | Number of pod replicas (typically managed by autoscaling) | `1` |
| `image.repository` | N/A | Container image repository | `appsuite-core-internal/core-ui-middleware` |
| `image.tag` | N/A | Container image tag (defaults to chart appVersion) | `""` |
| `image.pullPolicy` | N/A | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | N/A | Secrets for pulling from private registries | `[]` |

### Pod Configuration

Security and runtime configuration for pods.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `podAnnotations` | Annotations to add to pods | `{"logging.open-xchange.com/format": "appsuite-json"}` |
| `podSecurityContext` | Security context for the pod | `{}` |
| `defaultPodSecurityContext` | Default pod security context (if podSecurityContext is empty) | `{runAsNonRoot: true, runAsUser: 65532, runAsGroup: 65532}` |
| `securityContext` | Security context for the container | `{}` |
| `defaultSecurityContext` | Default container security context | See values.yaml for full configuration |
| `serviceAccount.create` | Create a dedicated ServiceAccount instead of using the namespace default one | `true` |
| `serviceAccount.name` | Name of the created ServiceAccount (defaults to the chart fullname) | `""` |
| `serviceAccount.annotations` | Annotations for the ServiceAccount, e.g. for cloud IAM role binding | `{}` |
| `serviceAccount.automountServiceAccountToken` | ServiceAccount-level default for pods that do not state their own | `false` |
| `serviceAccountName` | Use a ServiceAccount you manage yourself; suppresses the one created here and binds the Role to yours | unset |
| `automountServiceAccountToken` | Pod-level token automount. Unset means the token is mounted only when `k8sAutoDiscovery.enabled` is `true`, the only feature that calls the Kubernetes API | unset |

### Service Configuration

Kubernetes service configuration for network access.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `80` |

### Resource Management

CPU and memory resource limits and requests.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `resources.limits.cpu` | Maximum CPU allocation | `1` |
| `resources.limits.memory` | Maximum memory allocation | `768Mi` |
| `resources.requests.cpu` | Requested CPU allocation | `500m` |
| `resources.requests.memory` | Requested memory allocation | `196Mi` |
| `autoscaling.enabled` | Enable horizontal pod autoscaling | `false` |
| `autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `autoscaling.maxReplicas` | Maximum number of replicas | `100` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization for scaling | `80` |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization for scaling | `80` |

### Scheduling & Placement

Node selection and pod placement controls.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `nodeSelector` | Node labels for pod scheduling | `{}` |
| `tolerations` | Tolerations for pod scheduling | `[]` |
| `affinity` | Affinity rules for pod scheduling | `{}` |

### Disruption Budget

Limits voluntary evictions (node drains, cluster autoscaler consolidation) of the
serving pods. It does not affect rolling updates, autoscaler scale-down or node
failures. The updater is a singleton and is deliberately not covered. Enabling a
budget without setting either bound is an error, so the choice stays explicit.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `pdb.create` | Whether a PodDisruptionBudget should be created | `false` |
| `pdb.minAvailable` | Minimum number or percentage of pods that must be available. Mutually exclusive with `maxUnavailable` | `""` |
| `pdb.maxUnavailable` | Maximum number or percentage of pods that can be unavailable. Mutually exclusive with `minAvailable` | `""` |
| `pdb.unhealthyPodEvictionPolicy` | Rendered as `spec.unhealthyPodEvictionPolicy` (Kubernetes >= 1.31). Empty omits the field. `AlwaysAllow` stops an unhealthy pod blocking a node drain | `""` |

### Workload labels

The chart renders two workloads from one values tree: the serving Deployment and
the single updater Deployment. Both carry the same `app.kubernetes.io/name` and
`app.kubernetes.io/instance`, so their pods additionally carry
`app.kubernetes.io/component` to tell the tiers apart:

| Workload | `app.kubernetes.io/component` |
|----------|-------------------------------|
| serving Deployment | `server` |
| updater Deployment | `updater` |

Use that label in any selector meant to apply to the serving tier alone — the
chart's own PodDisruptionBudget does, and it is what the `labelSelector` of a
topology spread constraint should match. Without it a selector built from the
standard labels also matches the singleton updater pod.

Two caveats:

* Values that feed the pod spec apply to **both** workloads, the updater
  included. A spread constraint supplied this way is rendered onto the updater
  pod as well, where a selector matching only serving pods can make it
  unschedulable if the existing skew is already beyond `maxSkew`.
* Each Deployment's own `spec.selector.matchLabels` is unchanged and remains
  identical between the two. That field is immutable, so narrowing it would
  require both Deployments to be recreated rather than upgraded.

### Health Probes

Kubernetes liveness and readiness probe configuration.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `probe.liveness.enabled` | Enable liveness probe | `true` |
| `probe.liveness.periodSeconds` | Liveness check interval | `10` |
| `probe.liveness.failureThreshold` | Failures before pod restart | `15` |
| `probe.readiness.enabled` | Enable readiness probe | `true` |
| `probe.readiness.initialDelaySeconds` | Delay before first readiness check | `1` |
| `probe.readiness.periodSeconds` | Readiness check interval | `5` |
| `probe.readiness.failureThreshold` | Failures before marking unready | `2` |
| `probe.readiness.timeoutSeconds` | Readiness check timeout | `5` |

The two workloads report ready under different conditions.

A serving pod reports ready once the updater has published a UI version. Before
that it answers no requests.

The updater reports ready only while it reaches every configured UI provider. If
one is down, the updater publishes no new version, `/ready` returns 503, and every
update cycle logs `[Version] UI provider <url> is unavailable` with the missing URL.
The liveness probe ignores this, because restarting the updater won't bring a
provider back. On a fresh install the serving pods stay unready until the last
provider is up. If they hang there, check the updater log first.

### Server Configuration

Network binding and port settings for the Fastify server.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `bindAddr` | `BIND_ADDR` | IP address to bind for connections ("::" = IPv4 and IPv6) | `"::"` |
| `containerPort` | `PORT` | Container port for the UI middleware service | `8080` |
| N/A | `METRICS_PORT` | Prometheus metrics endpoint port | `9090` |
| N/A | `LIGHTSHIP_PORT` | Lightship health check port | `9000` |

### UI Middleware Configuration

Core service behavior and UI serving settings.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `baseUrls` | N/A | List of UI service base URLs to fetch manifests from (required) | `[]` |
| `coreServiceURL` | `CORE_SERVICE_URL` | Core middleware service URL for inter-service communication | `""` |
| `global.appsuite.appRoot` | `APP_ROOT` | Base path for all routes (must start with /) | `"/"` |
| N/A | `EXPOSE_API_DOCS` | Expose OpenAPI documentation at /documentation | `false` |

### Logging Configuration

Structured JSON logging via Pino.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `logLevel` | `LOG_LEVEL` | Log level (trace, debug, info, warn, error, fatal) | `"info"` |

### Caching & Performance

Cache TTL and performance optimization settings.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `cacheTTL` | `CACHE_TTL` | In-memory cache TTL for manifest data (milliseconds) | `30000` |
| `externalCache.enabled` | `ENABLE_EXTERNAL_CACHE` | Enable external cache mode (disables in-memory file caching) | `false` |

### Compression Configuration

Response compression settings for HTTP responses.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `compressFileSize` | `COMPRESS_FILE_SIZE` | Minimum file size (bytes) to enable gzip compression | `600` |
| `compressFileTypes` | `COMPRESS_FILE_TYPES` | MIME types eligible for compression (space-separated) | `application/javascript application/json application/x-javascript application/xml application/xml+rss text/css text/html text/javascript text/plain text/xml image/svg+xml` |

### Performance Monitoring

Request performance tracking and alerting.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `slowRequestThreshold` | `SLOW_REQUEST_THRESHOLD` | Threshold (ms) for logging slow HTTP requests | `4000` |

### Key Prefix Configuration

Namespace isolation for Redis keys and S3 paths.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `keyPrefix` | `KEY_PREFIX` | Prefix for all Redis keys and S3 folder paths | `"ui-service"` |

### Storage Backend Selection

Selects where asset bytes (manifests, JS, CSS, assets) are stored. See ADR 0010.
Redis is required either way for version coordination and pub/sub; this switch
only decides where the *files* live.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `storage.backend` | `STORAGE_BACKEND` | `auto`, `s3`, or `redis`. `auto` derives the backend from whether S3 is configured. | `"auto"` |

In `auto` mode the backend resolves to `s3` when an S3 endpoint or the internal
MinIO is configured (`s3.endpoint` set, or `minio.enabled: true`), and to `redis`
otherwise. This keeps an unchanged 2.x values file (no S3 configured) running on
the Redis storage backend after an upgrade, while a fresh install that supplies
S3 gets the S3 path. Set `s3` or `redis` to force the choice.

> **Note:** With the Redis backend, asset bytes live in Redis, so Redis memory
> scales with total asset volume across retained versions.

### Redis Configuration

Redis connection settings for distributed caching and pub/sub.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `redis.mode` | `REDIS_MODE` | Redis deployment mode (standalone, sentinel, cluster) | `"standalone"` |
| `redis.hosts` | `REDIS_HOSTS` | Redis hosts (comma-separated string in env, list in Helm) | `["localhost:6379"]` |
| `redis.db` | `REDIS_DB` | Redis database number (0-15, only for standalone/sentinel) | `0` |
| `redis.sentinelMasterId` | `REDIS_SENTINEL_MASTER_ID` | Sentinel master ID (only used when mode=sentinel) | `"mymaster"` |
| `redis.auth.enabled` | N/A | Generate Redis auth secret | `false` |
| `redis.auth.username` | `REDIS_USERNAME` | Redis username for authentication | `""` |
| `redis.auth.password` | `REDIS_PASSWORD` | Redis password for authentication | `""` |
| `redis.tls.enabled` | `REDIS_TLS_ENABLED` | Enable TLS for Redis connections | `false` |
| `redis.tls.ca` | `REDIS_TLS_CA` | PEM-encoded CA certificate for Redis TLS | `""` |
| `redis.prefix` | `KEY_PREFIX` | **DEPRECATED:** Use top-level `keyPrefix` instead | `""` |
| `redis.sidecar.image` | N/A | Redis sidecar container image (development only) | `"redis:latest"` |

### S3 Storage Configuration

S3-compatible storage settings (source of truth for UI files).

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `s3.endpoint` | `S3_ENDPOINT` | S3 API endpoint URL | `""` (uses internal MinIO when `minio.enabled`) |
| `s3.bucketName` | `S3_BUCKET_NAME` | S3 bucket name for storing UI files | `"ui-service"` |
| `s3.createBucket` | `S3_CREATE_BUCKET` | Automatically create bucket if it doesn't exist | `false` |
| `s3.auth.user` | `S3_ACCESS_KEY` | S3 access key ID | `""` |
| `s3.auth.password` | `S3_SECRET_KEY` | S3 secret access key | `""` |
| `s3.auth.existingSecret` | N/A | Name of existing Kubernetes secret for S3 credentials | `""` |
| `s3.auth.userSecretKey` | N/A | Key in existing secret for S3 access key | `"access"` |
| `s3.auth.passwordSecretKey` | N/A | Key in existing secret for S3 secret key | `"secret"` |

#### Required S3 Permissions

The UI Service requires the following S3 permissions on the bucket:

* `s3:ListBucket`
* `s3:ListBucketMultipartUploads`
* `s3:ListMultipartUploadParts`
* `s3:PutObject`
* `s3:AbortMultipartUpload`
* `s3:GetBucketLocation`
* `s3:GetObject`

If `s3.createBucket` is enabled, also add: `s3:CreateBucket`

#### Example S3 Policy

```json
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "Action": [
    "s3:ListBucket",
    "s3:ListBucketMultipartUploads",
    "s3:ListMultipartUploadParts",
    "s3:PutObject",
    "s3:AbortMultipartUpload",
    "s3:GetBucketLocation",
    "s3:GetObject"
   ],
   "Resource": [
    "arn:aws:s3:::<BUCKETNAME>/*"
   ]
  }
 ]
}
```

### MinIO Sub-chart Configuration

> **DEPRECATED:** the bundled MinIO sub-chart is deprecated and will be removed in
> a future release. It remains only as a development/testing convenience. For real
> storage, point `s3.endpoint` at an external S3-compatible service (the in-cluster
> Garage operator is recommended for preview/test clusters) or use the Redis
> storage backend (`storage.backend: redis`). See ADR 0010.

Integrated MinIO deployment settings (for development/testing). Opt-in: enabling
it deploys an in-cluster S3 and makes `storage.backend: auto` resolve to S3.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `minio.enabled` | Deploy MinIO sub-chart (bitnami/minio) | `false` |
| `minio.disableWebUI` | Disable MinIO web console | `true` |
| `minio.auth.rootPassword` | MinIO root password (min 8 chars, recommended to set explicitly) | Auto-generated if not set |
| `minio.resources.limits.memory` | MinIO memory limit | `2.5Gi` |
| `minio.resources.requests.cpu` | MinIO CPU request | `500m` |
| `minio.resources.requests.memory` | MinIO memory request | `2Gi` |

For additional MinIO configuration options, see the [bitnami/minio chart documentation](https://github.com/bitnami/charts/tree/main/bitnami/minio).

### Version Updater Configuration

Version update propagation and update job settings.

| Helm Variable | Environment Variable | Description | Default |
|---------------|---------------------|-------------|---------|
| `updater.propagateUpgrades` | `PROPAGATE_UPGRADES` | Enable automatic propagation of UI version updates across replicas | `true` |
| `updater.s3MaxParallelRequests` | `S3_MAX_PARALLEL_REQUESTS` | Maximum parallel S3 requests during version updates | `20` |
| `updater.resources.limits.memory` | N/A | Updater job memory limit | `768Mi` |
| `updater.resources.requests.cpu` | N/A | Updater job CPU request | `100m` |
| `updater.resources.requests.memory` | N/A | Updater job memory request | `196Mi` |

### Kubernetes Auto-Discovery

Automatic discovery of UI services in the same namespace.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `k8sAutoDiscovery.enabled` | Automatically discover UI services with label `appsuite.ox.io/ui-provider: manifest` | `true` |

Services can optionally specify a custom base path using the annotation: `appsuite.ox.io/ui-base-path: "/"`

### Monitoring & Observability

Prometheus metrics and monitoring integration.

| Helm Variable | Description | Default |
|---------------|-------------|---------|
| `extras.monitoring.enabled` | Enable Prometheus ServiceMonitor (requires prometheus-operator) | `false` |
| `global.extras.monitoring.enabled` | Global monitoring enablement flag | `false` |

### CORS Configuration

Cross-Origin Resource Sharing settings.

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `ORIGINS` | Allowed origins for CORS requests (comma-separated or `*` for all) | `"*"` |

**Note:** This configuration is only available via environment variable, not through Helm values.

## Upgrading

### To 4.0.0

The UI Service has been updated to use S3 storage instead of Redis for storing the manifests and assets. Redis is still in use for propagating updates to the UI Service.

#### Migrating from redis storage to S3 storage

Notice that the previous versions stored in redis will be lost when migrating to S3 storage, as the UI Service will not be able to access the redis storage anymore and only use redis to propagate updates after this.
If you are using an external S3 storage, you should either create a new bucket on your S3 storage or use an existing one. You can also let the UI Service create the bucket for you by setting `s3.createBucket` to `true`.
Additionally `redis.prefix` is used for the folder name inside the bucket.

If you want to migrate from redis storage to S3 storage, you can use the following steps:

1. Use at least chart version `4.0.5` and image version `latest` for the UI Service.
2. Set a minio root password in your `values.yaml` file if you use the integrated Minio deployment (like in the example of the previous section).
   Otherwise disable the internal Minio deployment and configure an external S3 storage, e.g.:

    ```yaml
    minio:
      enabled: false
    s3:
      bucketName: "your-bucket-name"
      endpoint: https://your-s3-endpoint
      auth:
        user: example-user
        password: example-password
    ```

2. Deploy the updated helm chart.
3. Wait until everything is up and running.

The UI Service will now use the S3 storage.

## Migration Guide

### Renaming `redis.prefix` to `keyPrefix`

The `redis.prefix` configuration parameter has been renamed to `keyPrefix` and moved to the top level to better reflect that it's used for both Redis keys and S3 folder paths, not just Redis.

**What changed:**
- Helm value: `redis.prefix` → `keyPrefix` (top-level)
- Environment variable: `REDIS_PREFIX` → `KEY_PREFIX`
- The prefix is used for both Redis keys AND S3 folder structure

**Backwards compatibility:**
The old `redis.prefix` parameter is still supported for backwards compatibility. If `redis.prefix` is set, it will be used. Otherwise, the new `keyPrefix` will be used.

**Migration steps:**

1. Update your `values.yaml` or Helm command:

   **Before:**
   ```yaml
   redis:
     prefix: my-custom-prefix
   ```

   **After:**
   ```yaml
   keyPrefix: my-custom-prefix
   ```

2. Deploy the updated chart - no service interruption required since backwards compatibility is maintained.

3. After confirming everything works, remove the old `redis.prefix` from your configuration.

**Note:** If you don't have a custom prefix configured, the default value `"ui-service"` will be used automatically.
