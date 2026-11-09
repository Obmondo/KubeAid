# Helm Chart core-documentconverter

This Helm Chart deploys DocumentConverter service core in a kubernetes cluster.

## Introduction

This Chart includes the following components:

* DocumentConverter application container to deploy in a kubernetes cluster.

## Requirements

Requires Kubernetes v1.19+

## Dependencies

This section will provide details about specific requirements in addition to this Helm Chart.

## Pushing to registry

From wihtin ${PROJECT_DIR}/helm/core-documentconverter directory:

```shell
helm repo add ox-documents-registry https://registry.open-xchange.com/chartrepo/documents
helm repo update
helm push . ox-documents-registry
```

## Test installation

Run a test against a cluster deployment:

```shell
helm repo add ox-documents-registry https://registry.open-xchange.com/chartrepo/documents
helm repo update
helm install --dry-run --debug --generate-name --version [VERSION] ox-documents-registry/core-documentconverter
```

## Installing the chart

Install the Chart with the release name 'alice':

```shell
helm repo add ox-documents-registry https://registry.open-xchange.com/chartrepo/documents
helm repo update
helm install alice --version [VERSION] ox-documents-registry/core-documentconverter [-f path/to/values_with_credentials.yaml]
```

### Configuration

## Global Configuration

| Parameter                                                              | Description                                                                                                                                                                                                                                                        | Default                     |
|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------|
| `defaultRegistry`                                                      | The image registry                                                                                                                                                                                                                                                 | `registry.open-xchange.com` |
| `image.repository`                                                     | The image repository                                                                                                                                                                                                                                               | `core-documentconverter`    |
| `image.tag`                                                            | The image tag                                                                                                                                                                                                                                                      | ``                          |
| `image.pullPolicy`                                                     | The imagePullPolicy for the deployment                                                                                                                                                                                                                             | IfNotPresent                |
| `imagePullSecrets`                                                     | List of references to secrets for image registries                                                                                                                                                                                                                 | []                          |
| `documentConverter.engine`                                             | Specifies the engine used for document conversion: `default` (local ReaderEngine process), `podman` (ReaderEngine in a Podman container) or `cool` (Collabora Online).                                                                                             | `default`                   |
| `documentConverter.engineImage`                                        | The OCI image to run when `documentConverter.engine` is `podman`. Required in that case.                                                                                                                                                                           | -                           |
| `documentConverter.engineTcpPortBase`                                  | The first TCP port considered when handing out ports to `podman` engine instances.                                                                                                                                                                                 | `8132`                      |
| `documentConverter.engineContainerMemoryOverheadMB`                    | Fixed headroom in MB added on top of `maxVMemMB` when sizing each `podman` engine container's memory limit (the container cgroup limit also counts the entrypoint<br/>and the page cache of image files). Only relevant if `documentConverter.engine` is `podman`. | `128`                       |
| `documentConverter.maxVMemMB`                                          | The maximum memory in MB a single conversion engine instance may allocate.                                                                                                                                                                                         | `2048`                      |
| `documentConverter.processorCount`                                     | The number of processing engines to use in parallel                                                                                                                                                                                                                | 3                           |
| `documentConverter.processingTimeoutSeconds`                           | Specifies the maximum time in seconds a document will be processed                                                                                                                                                                                                 | `60`                        |
| `documentConverter.jobQueueCountLimitHigh`                             | The maxmimum number of jobs in queue after further jobs are rejected                                                                                                                                                                                               | 40                          |
| `documentConverter.jobQueueCountLimitLow`                              | The number of jobs in queue when jobs are accepted again after 'jobQueueCountLimitHigh' was reached                                                                                                                                                                | 25                          |
| `documentConverter.jobQueueTimeoutSeconds`                             | The time in seconds after a queued job gets removed from queue and is rejected                                                                                                                                                                                     | 300                         |
| `documentConverter.jobAsyncQueueCountLimitHigh`                        | The maximum number of asynchronous jobs to hold in queue to be processed                                                                                                                                                                                           | 1024                        |
| `documentConverter.urlLinkLimit`                                       | The maximum number of external document URLs that can be resolved per conversion instance. Use -1 for no limit and 0 to disable resolving of URLs.                                                                                                                 | 200                         |
| `documentConverter.urlLinkProxy`                                       | The optional proxy to resolve document internal URLs during conversion. Specification must be done with host:port, protocol must not be set.                                                                                                                       | ``                          |
| `documentConverter.cache.remoteCache`                                  | The settings for the CacheService to use                                                                                                                                                                                                                           | `{}`                        |
| `documentConverter.cache.remoteCache.url`                              | The optional CacheService URL.<br/>If not set, a cluster local CacheService URL is generated if core-cacheservice is enabled.<br/>If a blank ("") string is set, no CacheService is used.                                                                          | ``                          |
| `documentConverter.cache.maxEntries`                                   | The maximum number of cache entries. Use -1 for unlimited.                                                                                                                                                                                                         | 1000000                     |
| `documentConverter.cache.maxSizeMegaBytes`                             | The maximum size of all cache entries combined. Use -1 for unlimited.                                                                                                                                                                                              | -1                          |
| `documentConverter.cache.minFreeSizeMegaBytes`                         | The minimum size of local volume space that should not be used by cache.                                                                                                                                                                                           | 1024                        |
| `documentConverter.cache.maxLifetimeSeconds`                           | The maximum age in seconds of a cache entry before it gets removed. Use -1 for unlimited.                                                                                                                                                                          | 2592000                     |
| `documentConverter.cache.cleanupPeriodSeconds`                         | The period in seconds after which the next cache cleanup will be performed                                                                                                                                                                                         | 300                         |
| `documentConverter.remoteAccess.denyURLRegExp`                         | The optional list of URL regular expressions that will not be resolved.                                                                                                                                                                                            | [.*]                        |
| `documentConverter.remoteAccess.allowURLRegExp`                        | The optional list of URL regular expressions that will be resolved even if listed as denied.                                                                                                                                                                       | []                          |
| `documentConverter.readinessDownAfterUsedServiceUnavailabilitySeconds` | Set readiness down after this period of time if depending service is not available. Use -1 to disable.                                                                                                                                                             | `300`                       |
| `documentConverter.livenessDownAfterReadinessDownSeconds`              | Shutdown service after this period of time after readiness went down. Use -1 to disable.                                                                                                                                                                           | `15`                        |
| `documentConverter.readinessUpUsedServiceRecoveryPeriodSeconds`        | The period of time the remote cache client tries to reestablish a lost server connection.                                                                                                                                                                          | `20`                        |
| `documentConverter.jvmHeapSizeMB`                                      | The maximum JVM heap size of the image Java process to use in MegaBytes                                                                                                                                                                                            | `768`                       |
| `persistence.enabled`                                                  | Specifies if cluster volumes are mounted by container. Using emptyDir Volumes when false.                                                                                                                                                                          | false                       |
| `logging.*`                                                            | Specifies logging configuration values.<br/>All file size related values are specified either in Bytes (no Postfix), KiloBytes (KB postfix), MegaBytes (MB postfix) or GigaBytes (GB postfix).                                                                     | ``                          |
| `env`                                                                  | Configuration properties passed to the service via environment variables                                                                                                                                                                                           | []                          |

## Podman conversion engine

With `documentConverter.engine: podman` the conversion engine runs in one
rootless Podman container per engine instance, inside the service pod, instead
of as a local process in the service container. Additional deployment
requirements in that case:

* `documentConverter.engineImage` is mandatory - the chart refuses to render
  without it. It is either a registry reference (pulled on demand) or a
  `file:///path/to/image.tar(.gz)` tarball loaded from a mounted/baked-in path.
* `resources.requests/limits.memory` must cover
  `jvmHeapSizeMB + processorCount x (maxVMemMB + engineContainerMemoryOverheadMB)`,
  since every engine container runs inside this pod's cgroup.
* `resources.requests/limits.ephemeral-storage` must cover the engine image
  itself: it is stored in the pod's own (emptyDir) spool volume - once for a
  shared image store, or once per engine instance where only the `vfs` storage
  fallback is usable.
* Nodes/pods must support nested rootless Podman: user namespaces, ideally a
  usable unprivileged overlay mechanism (native or fuse-overlayfs; otherwise the
  slower per-instance `vfs` fallback is selected automatically), and cgroups v2
  if the engine memory limits are to be enforced at all.

See `documentation/adr/0001-podman-based-conversion-engine.md` in the service
repository for the design details.
