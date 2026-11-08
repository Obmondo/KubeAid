# Helm Chart core-imageconverter
This Helm Chart deploys ImageConverter service core in a kubernetes cluster.

## Introduction
This Chart includes the following components:

* ImageConverter application container to deploy in a kubernetes cluster.

## Requirements
Requires Kubernetes v1.19+

## Dependencies
This section will provide details about specific requirements in addition to this Helm Chart.

## Pushing to registry
From wihtin ${PROJECT_DIR}/helm/core-imageconverter directory:

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
helm install --dry-run --debug --generate-name --version [VERSION] ox-documents-registry/core-imageconverter
```

## Installing the chart
Install the Chart with the release name 'alice':

### Configuration

## Global Configuration
| Parameter                                        | Description                                                                                                                                                                                    | Default                                                                                                      |
|--------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| `defaultRegistry`                                | The image registry                                                                                                                                                                             | `registry.open-xchange.com`                                                                                  |
| `image.repository`                               | The image repository                                                                                                                                                                           | `core-imageconverter`                                                                                        |
| `image.tag`                                      | The image tag                                                                                                                                                                                  | ``                                                                                                           |
| `image.pullPolicy`                               | The imagePullPolicy for the deployment                                                                                                                                                         | `IfNotPresent`                                                                                               |
| `imagePullSecrets`                               | List of references to secrets for image registries                                                                                                                                             | `[]`                                                                                                         |
| `imageconverter.targetFormats`                   | Specifies the list of target image formats to create for each key                                                                                                                              | `[auto:200x150~cover, auto:400x300~cover, auto:600x400~cover, auto:1920x1080~contain, auto:1920x1080~cover]` |
| `imageconverter.preConvert.enabled`              | Enables pre conversion of all remaining target formats if one convert request is processed.<br/>Note: enabling this feature will require a lot more computing resources.                       | `false`                                                                                                      |
| `imageconverter.imageUserComment`                | Specifies the user comment to write into processed target images                                                                                                                               | `OX_IC`                                                                                                      |
| `imageconverter.processingTimeoutSeconds`        | Specifies the maximum time in seconds an image will be processed                                                                                                                               | `10`                                                                                                         |
| `imageconverter.maxParallelRequests`             | Specifies the maximum number of parallel requests than can be processed by the Web server.                                                                                                     | `512`                                                                                                        |
| `imageconverter.maxQueueLength`                  | Specifies the maximum number of jobs that can be queued for instant processing. Additional instant jobs will be rejected until number is below configured value again.                         | `128`                                                                                                        |
| `imageconverter.maxAsyncQueueLengthPercentage`   | Specifies the maximum number of jobs that can be queued for asynchonous processing in the background. The value is specified as percentage of 'maxQueueLength'.                                | `400`                                                                                                        |
| `imageconverter.cache.remoteCache`               | The settings for the CacheService to use                                                                                                                                                       | `{}`                                                                                                         |
| `imageconverter.cache.remoteCache.url`           | The optional CacheService URL.<br/>If not set, a cluster local CacheService URL is generated if core-cacheservice is enabled.<br/>If a blank ("") string is set, no CacheService is used.      | ``                                                                                                           |
| `imageconverter.cache.maxEntries`                | The maximum number of cache key entries. Use -1 for unlimited.                                                                                                                                 | `100000`                                                                                                     |
| `imageconverter.cache.maxSizeMegaBytes`          | The maximum size of all cache key entries combined. Use -1 for unlimited.                                                                                                                      | `-1`                                                                                                         |
| `imageconverter.cache.maxLifetimeSeconds`        | The maximum age in seconds of a cache key entry before it gets removed. Use -1 for unlimited.                                                                                                  | `2592000`                                                                                                    |
| `imageconverter.cache.cleanupPeriodSeconds`      | The period in seconds after which the next cache cleanup will be performed                                                                                                                     | `300`                                                                                                        |
| `imageconverter.cache.maxLocalEntries`           | The maximum number of local cache key entries. Set to 0 if no local cache should be used.                                                                                                      | `1000`                                                                                                       |
| `imageconverter.cache.maxLocalLifetimeSeconds`   | The maximum age in seconds of a local cache key entry before it gets removed. Set to 0 if no local cache should be used.                                                                       | `3600`                                                                                                       |
| `imageconverter.cache.localCleanupPeriodSeconds` | The period in seconds after which the next local cache cleanup will be performed                                                                                                               | `60`                                                                                                         |
| `imageconverter.jvmHeapSizeMB`                   | The maximum JVM heap size of the image Java process to use in MegaBytes                                                                                                                        | `1024`                                                                                                       |
| `logging.*`                                      | Specifies logging configuration values.<br/>All file size related values are specified either in Bytes (no Postfix), KiloBytes (KB postfix), MegaBytes (MB postfix) or GigaBytes (GB postfix). | ``                                                                                                           |
| `env`                                            | Configuration properties passed to the service via environment variables                                                                                                                       | `[]`                                                                                                         |
