# Helm Chart core-cacheservice
This Helm Chart deploys Cache service core in a kubernetes cluster.

## Introduction
This Chart includes the following components:

* Cache service application container to deploy in a kubernetes cluster.

## Requirements
Requires Kubernetes v1.19+

## Dependencies
This section will provide details about specific requirements in addition to this Helm Chart.
## Pushing to registry
From wihtin ${PROJECT_DIR}/helm/core-cacheservice directory:

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
helm install --dry-run --debug --generate-name --version [VERSION] ox-documents-registry/core-cacheservice
```

## Installing the chart
Install the Chart with the release name 'alice':

```shell
helm repo add ox-documents-registry https://registry.open-xchange.com/chartrepo/documents
helm repo update
helm install alice --version [VERSION] ox-documents-registry/core-cacheservice [-f path/to/values_with_credentials.yaml]
```

## Configuration
| Parameter                                                      | Description                                                                                                                                                                                     | Default                     |
|----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------|
| `defaultRegistry`                                              | The image registry                                                                                                                                                                              | `registry.open-xchange.com` |
| `image.repository`                                             | The image repository                                                                                                                                                                            | `core-cacheservice`         |
| `image.tag`                                                    | The image tag                                                                                                                                                                                   | ``                          |
| `image.pullPolicy`                                             | The imagePullPolicy for the deployment                                                                                                                                                          | `IfNotPresent`              |
| `imagePullSecrets`                                             | List of references to secrets for image registries                                                                                                                                              | `[]`                        |
| `serviceAccount.create`                                        | Whether to create a `ServiceAccount` for the service pods. Only needed to associate the pods with an AWS IAM role, see [Using AWS IAM for S3 object stores](#using-aws-iam-for-s3-object-stores)| unset                       |
| `serviceAccount.name`                                          | The name of the `ServiceAccount` to create or, with `serviceAccount.create` set to `false`, of an already existing one to use                                                                   | release fullname / `default`|
| `serviceAccount.annotations`                                   | Annotations for the `ServiceAccount`, e.g. `eks.amazonaws.com/role-arn` for EKS IRSA                                                                                                            | `{}`                        |
| `existingPropertiesSecret`                                     | The name of an already existing secret within the deployment namespace, containing lean<br/>config values (e.g. user names and passwords for BasicAuth as well as database, S3 access etc.)     | ``                          |
| `basicAuth.user`                                               | The user name for BasicAuth login, required for protected HTTP API calls                                                                                                                        | ``                          |
| `basicAuth.password`                                           | The password for BasicAuth login, required for protected HTTP API calls                                                                                                                         | ``                          |
| `cacheService.cacheDefaults.maxEntries`                        | The maximum number of cache subgroup entries. Use -1 for unlimited.                                                                                                                             | `100000`                    |
| `cacheService.cacheDefaults.maxSizeMegaBytes`                  | The maximum size of all cache subgroup file entries combined. Use -1 for unlimited.                                                                                                             | `-1`                        |
| `cacheService.cacheDefaults.maxLifetimeSeconds`                | The maximum age in seconds of a cache key entry before it gets removed. Use -1 for unlimited.                                                                                                   | `2592000`                   |
| `cacheService.cacheDefaults.cleanupPeriodSeconds`              | The period in seconds after which the next cache cleanup will be performed                                                                                                                      | `300`                       |
| `cacheService.mysql.host`                                      | The CacheService database connection host                                                                                                                                                       | ``                          |
| `cacheService.mysql.port`                                      | The CacheService database connection port                                                                                                                                                       | `3306`                      |
| `cacheService.mysql.database`                                  | The CacheService database connection schema                                                                                                                                                     | `cacheservicedb`            |
| `cacheService.mysql.auth.user`                                 | The CacheService database connection user                                                                                                                                                       | ``                          |
| `cacheService.mysql.auth.password`                             | The CacheService database connection password                                                                                                                                                   | ``                          |
| `cacheService.mysql.auth.rootPassword`                         | The CacheService database connection root password to create e.g. a new database                                                                                                                | ``                          |
| `cacheService.mysql.properties`                                | The optional CacheService database connection properties to pass to the database drivers.                                                                                                       | `[]`                        |
| `cacheService.mysql.connectionPool.connectTimeoutMilliseconds` | The timeout value in milliseconds to get a connection from the connection pool                                                                                                                  | `2000`                      |
| `cacheService.mysql.connectionPool.maxLifetimeMilliseconds`    | The maximum lifetime value in milliseconds for a connection from the connection pool                                                                                                            | `600000`                    |
| `cacheService.mysql.connectionPool.idleTimeoutMilliseconds`    | The timeout value in milliseconds to release an idle connection from the connection pool                                                                                                        | `300000`                    |
| `cacheService.mysql.connectionPool.maxPoolSize`                | The maximum value of connections to be held within the connection pool                                                                                                                          | `20`                        |
| `cacheService.mysql.connectionPool.minPoolIdleSize`            | The minimum value of idle connections to be held within the connection pool.                                                                                                                    | `5`                         |
| `cacheService.s3ObjectStores`                                  | The list of S3 object stores to use                                                                                                                                                             | `[]`                        |
| `cacheService.s3ObjectStores.id`                               | The numeric id of the current S3 based object store that shouldn't be changed once assigned                                                                                                     | ``                          |
| `cacheService.s3ObjectStores.endpoint`                         | The endpoint URL of the current S3 object store                                                                                                                                                 | ``                          |
| `cacheService.s3ObjectStores.region`                           | The region of the current S3 object store                                                                                                                                                       | `eu-central-1`              |
| `cacheService.s3ObjectStores.bucketName`                       | The bucket name of the current S3 object store                                                                                                                                                  | `cacheservice`              |
| `cacheService.s3ObjectStores.credentialsSource`                | The source of the credentials of the current S3 object store, either `standard` (use `accessKey`/`secretKey`) or `iam` (use the AWS default credentials chain)                                  | `standard`                  |
| `cacheService.s3ObjectStores.accessKey`                        | The access key of the current S3 object store, required unless `credentialsSource` is `iam`                                                                                                     | ``                          |
| `cacheService.s3ObjectStores.secretKey`                        | The secret key of the current S3 object store, required unless `credentialsSource` is `iam`                                                                                                     | ``                          |
| `cacheService.s3ObjectStores.pathStyleAccess`                  | How the bucket is addressed in the request URLs: `auto` (virtual host style for AWS S3 endpoints, path style otherwise), `true` (always path style) or `false` (always virtual host style)      | `auto`                      |
| `cacheService.s3ObjectStores.trace`                            | Enables/Disables trace logging output for the internally used S3 client library                                                                                                                 | `false`                     |
| `cacheService.sproxydObjectStores`                             | The list of SproxyD object stores to use                                                                                                                                                        | `[]`                        |
| `cacheService.sproxydObjectStores.id`                          | The numeric id of the current SproxyD based object store that shouldn't be changed once assigned                                                                                                | ``                          |
| `cacheService.sproxydObjectStores.endpoint`                    | The endpoint URL of the current SproxyD based object store                                                                                                                                      | ``                          |
| `cacheService.sproxydObjectStores.path`                        | The path where to store objects in the current SproxyD based object store                                                                                                                       | `proxyd/cacheservice`       |
| `cacheService.maxParallelRequests`                             | Specifies the maximum number of parallel requests than can be processed by the Web server.                                                                                                      | `50`                        |
| `cacheService.cleanupBatchSize`                                | The number of cache subgroups to be removed within one database cleanup operation at once within one batch                                                                                      | `1000`                      |
| `cacheService.jvmHeapSizeMB`                                   | The maximum JVM heap size of the image Java process to use in MegaBytes                                                                                                                         | `768`                       |
| `persistence.enabled`                                          | Specifies if cluster volumes are mounted by container. Using emptyDir Volumes when false.                                                                                                       | `false`                     |
| `logging.*`                                                    | Specifies logging configuration values.<br/>All file size related values are specified either in Bytes (no Postfix), KiloBytes (KB postfix), MegaBytes (MB postfix) or GigaBytes (GB postfix).  | ``                          |
| `env`                                                          | Configuration properties passed to the service via environment variables                                                                                                                        | `[]`                        |

## Using AWS IAM for S3 object stores

By default an S3 object store authenticates with the statically configured `accessKey` and `secretKey`. Setting
`credentialsSource` to `iam` instead makes the service resolve credentials through the AWS default credentials chain at
runtime, in which case `accessKey` and `secretKey` are not needed and may be omitted:

```yaml
cacheService:
  s3ObjectStores:
    - id: 1
      endpoint: "https://s3.eu-central-1.amazonaws.com"
      region: "eu-central-1"
      bucketName: "cacheservice"
      credentialsSource: "iam"
```

The credentials chain is evaluated in this order: JVM system properties, the `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`
environment variables, a web identity token file (EKS IRSA), the AWS profile file, container credentials (ECS task roles
and EKS Pod Identity) and finally the EC2 instance profile. Which of these applies depends on where the service runs, so
nothing beyond `credentialsSource: "iam"` has to be configured in the chart for plain EC2 deployments.

On Kubernetes the pods have to be associated with an AWS IAM role, which requires a `ServiceAccount`. If the deployment
does not already provide one, this chart can create it:

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/core-cacheservice
```

To use an already existing `ServiceAccount` instead, set `serviceAccount.create` to `false` and `serviceAccount.name` to
its name. While the `serviceAccount` value is left unset entirely, the pods keep using the namespace default
`ServiceAccount` and no `ServiceAccount` is created.

The IAM role needs `s3:ListBucket` on the bucket itself plus `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on its
contents. Add `s3:CreateBucket` as well if the bucket should be created automatically on service startup, otherwise
create it beforehand. Note that `s3:ListBucket` is mandatory even for an existing bucket, since the service verifies the
bucket on startup and a missing permission makes that check fail rather than fall through.

## Configuration of service properties via existing secret

In most cases, like with this service, the Helm stack chart provided values for a service are transformed into a ConfigMap properties file
created during the Helm stackchart update/install step for a deployment. These config values are then used by the service container/pod during startup.
Although this approach covers all relevant config properties for the service, it is often desirable for the admin to specify all or just some
of the service config properties via a kubernetes secret for e.g. security reasons.

**Note:** Any credentials set directly via Helm values (e.g. `cacheService.mysql.auth.password`, `basicAuth.password`,
`cacheService.s3ObjectStores[].secretKey`) end up in the plaintext `ConfigMap` described above, which is readable by anyone
with `get configmaps` access in the namespace. For production deployments, use `existingPropertiesSecret` below to keep
credentials in a `Secret` instead.

To provide a way to use service config values from an existing secret within the current deployment namespace, the service Helm chart contains
a property to specify the name of an existing secret within the deployment namespace: `.Values.existingPropertiesSecret`.
Service properties (key/value pairs) set within this secret always have precedence over service properties contained within the Helm chart
created ConfigMap property values.

Documentation for the service-specific configuration values can be found at this [configuration values](https://documentation.open-xchange.com/components/cacheservice/8/config/properties.html)
location.

Since authorization data is most prone to security attacks, the following example will concentrate on these properties only, although all other
service properties can be set via a deployed secret this way as well:

- HTTP API BasicAuth properties (com.openexchange.cacheservice.basicAuth.user, com.openexchange.cacheservice.basicAuth.password)
- DB authorization properties (com.openexchange.cacheservice.database.user, com.openexchange.cacheservice.database.password, com.openexchange.cacheservice.database.rootPassword)
- S3 authorization properties (com.openexchange.cacheservice.objectstore.s3.1.accessKey, com.openexchange.cacheservice.objectstore.s3.1.secretKey)

### Example steps to provide a service config properties/values secret to be used by the deployed service
#### Step 1
First of all, a secret containing all required service config property keys and values needs to be created (current filename is ./myCacheServiceSecret.yaml)
Please note that all config values need to be set as Base64 encoded values.
All my* names and values need to be adjusted according to the admins' requirements.

```
apiVersion: v1
kind: Secret
metadata:
  name: my-cacheservice-secret
type: Opaque
data:
  com.openexchange.cacheservice.basicAuth.user: bXlCYXNpY0F1dGhVc2VyCg==  # Base64 encoded value of `myBasicAuthUser`
  com.openexchange.cacheservice.basicAuth.password: bXlCYXNpY0F1dGhQYXNzd29yZAo=  # Base64 encoded value of `myBasicAuthPassword`
  com.openexchange.cacheservice.database.user: bXlEQlVzZXIK  # Base64 encoded value of `myDBUser`
  com.openexchange.cacheservice.database.password: bXlEQlBhc3N3b3JkCg==  # Base64 encoded value of `myDBPassword`
  com.openexchange.cacheservice.database.rootPassword: bXlEQlJvb3RQYXNzd29yZAo=  # Base64 encoded value of `myDBRootPassword`
  com.openexchange.cacheservice.objectstore.s3.1.accessKey: bXlTM0FjY2Vzc0tleQo=  # Base64 encoded value of `myS3AccessKey`
  com.openexchange.cacheservice.objectstore.s3.1.secretKey: bXlTM1NlY3JldEtleQo=  # Base64 encoded value of `myS3SecretKey`
```
#### Step 2
After preparing all config values within the secret definition, the secret itself needs to be deployed or updated to the deployment namespace.
```
kubectl replace --force=true --namespace=myNamespace --filename=./myCacheServiceSecret.yaml
```
#### Step 3
After the property secret has been deployed to the cluster namespace the admin needs to adjust the service `.Values.existingPropertiesSecret`
stackchart value for the service.
```
core-cacheservice:
  existingPropertiesSecret: my-cacheservice-secret
```
#### Step 4
The stackchart with the set Helm chart service value `.Values.existingPropertiesSecret` name needs to be installed or updated via usual deployment mechanisms.
After the deployment has been finished, the service itself preferably uses the service key/value properties from the secret.
If a secret has already been deployed and secret values need changes, the secret itself needs to be redeployed to be effective. Afterward the
service itself needs to be restarted as well to acknowledge the new secret properties key/value pairs.
