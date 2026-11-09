# core-mw

![Version: 6.25.26](https://img.shields.io/badge/Version-6.25.26-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 8.54.0](https://img.shields.io/badge/AppVersion-8.54.0-informational?style=flat-square)

App Suite Middleware Core Helm Chart

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Open-Xchange GmbH | <info@open-xchange.com> |  |

## Source Code

* <https://github.com/open-xchange/appsuite-middleware>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry.open-xchange.com/appsuite-core-internal/charts/3rdparty | collabora-online | 1.3.0 |
| oci://registry.open-xchange.com/appsuite-core-internal/charts/3rdparty | gotenberg | 1.22.0 |
| oci://registry.open-xchange.com/appsuite-core-internal/charts | ox-common | 1.0.49 |

## Additional informations

### 4.0.0

- This version introduces new `configuration.redis` and `configuration.sessiond` section which **adds support for** Redis. Please refer to the documentation in `values.yaml`.
- Changed the default service type from `NodePort` to `ClusterIP` for `http-api`, `sync` and `admin` service.
- Removed *all* ingress configuration settings.
- Removed `services.documentconverterHost`, `services.imageconverterHost` and `services.spellcheckHost`.
Not necessary anymore but it's possible to override them e.g. via `.Values.global.dc.serviceName`
- Renamed environment variables
  - `OX_IMAGECONVERTER_URL` &rarr; `IC_SERVER_URL`
  - `OX_SPELLCHECK_URL` &rarr; `SPELLCHECK_SERVER_URL`
  - `OX_DOCUMENTCONVERTER_URL` &rarr; `DC_SERVER_URL`
- Partially or fully override `ox-common.names.fullname` via `nameOverride` or `fullnameOverride`.

### 5.10.1

- This version introduces new `configuration.redis.cache` section which **adds support for** a separate cache for volatile data. Please refer to the documentation in `values.yaml`.

### 6.0.1

- Hazelcast is now required for OX Documents only.
- Disabled packages `open-xchange-documents-backend` and `open-xchange-hazelcast` per default.
- Introduced a new role `documents` that enables packages `open-xchange-documents-backend` and `open-xchange-hazelcast` and adds necessary `HZ_*` env variables to containers. The role has been added to the `defaultScaling`.
- Removed `packages.minimalWhitelist` as it was not used anymore
- Removed role `hazelcast-data-holding` and `hazelcast-lite-member`

### 6.4.0

- Whether to use TLS to connect to the Redis endpoint can now be configured using `redis.tls.enabled` and `redis.cache.tls.enabled`.

### 6.19.5

- Added support for `PodDisruptionBudget` (PDB) via the new `pdb` configuration section.
- This version adds a new `middleware.open-xchange.com/type` label to pods. Upgrading to this version will trigger a rolling restart of all pods due to the label change.

### 6.21.0

#### Third-party Java agent support

The chart supports injecting third-party Java agents (e.g. Elastic APM) into the middleware pod via `extraInitContainers`. A typical setup uses an init container to copy the agent JAR into a shared volume, which is then mounted into the middleware container and activated via `javaOpts.other`.

> **Support scope:** OX supports the Helm injection mechanism (`extraInitContainers`, `extraVolumes`, `extraMounts`, `javaOpts.other`). The internal behavior of third-party agents is outside OX support scope.

##### Example: Elastic APM agent

```yaml
extraInitContainers:
  - name: elastic-apm-init
    image: docker.elastic.co/apm/apm-agent-java:1.52.0
    command: ["cp", "/usr/agent/elastic-apm-agent.jar", "/apm-agent/"]
    volumeMounts:
      - name: apm-agent
        mountPath: /apm-agent

extraVolumes:
  - name: apm-agent
    emptyDir: {}

extraMounts:
  - name: apm-agent
    mountPath: /opt/apm-agent
    readOnly: true

javaOpts:
  other: "-javaagent:/opt/apm-agent/elastic-apm-agent.jar"
```

## Upgrading

### To 6.0.1

If you are using custom node definitions (`scaling.nodes`) in your Helm values, please make sure to remove roles `hazelcast-data-holding` and `hazelcast-lite-member`.
Beside of that, a new role called `documents` has been introduced. The role needs to be added to every node definition that contains the `http-api` role and should run OX Documents.
Furthermore, it ensures that a Hazelcast headless service is still deployed for OX Documents.

Please consider the following `scaling.nodes` definition:

```
core-mw:
  scaling:
    nodes:
      groupware:
        replicas: 2
        roles:
          - admin
          - http-api
          - hazelcast-data-holding
      sync:
        replicas: 1
        roles:
          - sync
          - businessmobility
          - hazelcast-lite-member
```

A migrated version could look like this:

```
core-mw:
  scaling:
    nodes:
      groupware:
        replicas: 2
        roles:
          - admin
          - http-api
          - documents
      sync:
        replicas: 1
        roles:
          - sync
          - businessmobility
```

#### Warning

Nodes that do not have the role `documents` will not be deployed as a `StatefulSet` anymore. Instead they will be deployed as a `Deployment`.
Upgrading a `StatefulSet` to a `Deployment` is not easily possible without some preparation.
Simply upgrading via Helm would remove all pods of the `StatefulSet` before starting the first pod of the new `Deployment`.
This would result in a short downtime for endusers.

##### Example

Take a look at the following migrated example:

```
core-mw:
  scaling:
    nodes:
      groupware-without-docs:
        replicas: 2
        roles:
          - admin
          - http-api
      sync:
        replicas: 1
        roles:
          - sync
          - businessmobility
```

Nodes `groupware-without-docs` will not run OX Documents and roles `hazelcast-data-holding` and `hazelcast-lite-member` have been removed, too.
Prior `6.0.1`, those nodes were deployed as a `StatefulSet`. After the upgrade, they will be deployed as `Deployment`.
If downtime is not feasible, you need to do the following before the upgrade:

1. Remove the `StatefulSet` without removing the pods with:

```
kubectl delete statefulset appsuite-core-mw-groupware-without-docs --cascade=orphan
```

2. Upgrade via Helm

If you're low on resources, you should scale replicas to `0` in your `values.yaml`.
Otherwise, you will end up with the two pods from the `StatefulSet` and another two pods for the `Deployment`:

```
core-mw:
  scaling:
    nodes:
      groupware-without-docs:
        replicas: 0
        [...]
```

You can now upgrade the deployment via Helm:

```
helm upgrade [...]
```

After the upgrade, you can manually delete the `StatefulSet` pods and scale up the `Deployment`:

```
kubectl delete pod appsuite-core-mw-groupware-without-docs-1
kubectl scale deployment appsuite-core-mw-groupware-without-docs --replicas=1
kubectl delete pod appsuite-core-mw-groupware-without-docs-0
kubectl scale deployment appsuite-core-mw-groupware-without-docs --replicas=2
```

This process needs to be followed for all node definitions that previously had the `hazelcast-data-holding` role without having the `documents` role after the migration.

Don't forget to scale up the replicas in your `values.yaml` again.

## Using `existing*Secret` values

The `existing*Secret` values let you supply configuration from **Secrets you create and manage yourself**
(for example via Vault, sealed-secrets or external-secrets) instead of placing sensitive data directly in
`values.yaml`. The chart only *references* these Secrets, so each one **must already exist in the release
namespace** before you install or upgrade.

There are two behaviors. Know which one applies to the value you are setting:

- **Additive** &ndash; your Secret is mounted *alongside* the chart-rendered configuration; both apply.
- **Replace** &ndash; your Secret *replaces* the chart-rendered equivalent, and the corresponding plain
  `values.yaml` settings are then ignored.

| Value | Behavior | Combines with / replaces |
|-------|----------|--------------------------|
| `existingPropertiesSecret`   | Additive | `properties`, `secretProperties`, `propertiesFiles`, `secretPropertiesFiles` |
| `existingUISettingsSecret`   | Additive | `uiSettings`, `secretUISettings`, `uiSettingsFiles`, `secretUISettingsFiles` |
| `existingMetaSecret`         | Additive | `meta` |
| `existingContextSetsSecret`  | Additive | `contextSets`, `secretContextSets` |
| `existingETCFilesSecret`     | Additive | `etcFiles`, `secretETCFiles` |
| `existingETCBinariesSecret`  | Additive | `etcBinaries`, `secretETCBinaries` |
| `existingYAMLFilesSecret`    | Additive | `yamlFiles`, `secretYAMLFiles` |
| `existingASConfigSecret`     | **Replace** | `asConfig` |
| `existingEnvSecret`          | Additive (env) | container environment (`envFrom`) |
| `existing*Secrets` (plural)  | Additive | the matching singular value; any number of further Secrets, see below |
| `redis.existingSecret`       | **Replace** | chart-generated Redis properties secret |
| `mysql.existingSecret`       | **Replace** | chart-generated configdb credentials secret |
| `provisioningGateway.tls.existingSecret` | **Required** | nothing &ndash; the chart generates no certificate |

### What each Secret must contain

Every Secret below is one you create and manage yourself, in the release namespace, with the name you put
into the corresponding value. The chart never generates them and never validates them: a missing or
misspelled key is not a template error, it surfaces later as a failed database connection, a missing
configuration file or a wrong password.

Two rules apply throughout:

- Use `stringData` for text and `data` for anything binary. Keys under `stringData` are stored verbatim;
  keys under `data` must be base64-encoded and are decoded before they reach the container.
- **A Secret key becomes a file name.** Kubernetes forbids `/` in Secret keys, so none of these Secrets can
  place a file into a sub-directory. Where a chart value accepts a nested path (`yamlFiles`,
  `secretYAMLFiles`), the `existing*Secret` equivalent does not.

#### Database credentials — `mysql.existingSecret`

Replaces the whole configdb Secret the chart would otherwise render, and is consumed as environment
variables. Because it is a full replacement, supply all sixteen keys the chart's own Secret would define — a
key you leave out is not a template error, it is an unset environment variable that surfaces much later. On a
single-server setup, point the `_WRITE_` and `_READ_` keys at the same host as the plain ones.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-db-creds
type: Opaque
stringData:
  MYSQL_HOST: "mysql-master"
  MYSQL_PORT: "3306"
  MYSQL_DATABASE: "configdb"
  MYSQL_USER: "openexchange"
  MYSQL_PASSWORD: "secret"
  MYSQL_ROOT_PASSWORD: "supersecret"
  MYSQL_WRITE_HOST: "mysql-master"
  MYSQL_WRITE_PORT: "3306"
  MYSQL_WRITE_DATABASE: "configdb"
  MYSQL_WRITE_USER: "openexchange"
  MYSQL_WRITE_PASSWORD: "writePassword"
  MYSQL_READ_HOST: "mysql-replica"
  MYSQL_READ_PORT: "3306"
  MYSQL_READ_DATABASE: "configdb"
  MYSQL_READ_USER: "openexchange"
  MYSQL_READ_PASSWORD: "readPassword"
```

One Secret serves every node type, referenced under exactly the name you give. The exception is a node type
that overrides `mysql` in its own `scaling.nodes.<type>.values` block: the chart then looks for
`<name>-<typeName>` instead, and since it is not generating the Secret either, those pods fail to start with
`CreateContainerConfigError`. Do not combine `mysql.existingSecret` with a per-type `mysql` override.

`global.mysql.existingSecret` does the same thing across sub-charts and takes precedence over
`mysql.existingSecret` when both are set. Note that this Secret is **not** covered by the
`checksums.existingSecrets` annotation, so editing it does not roll the pods — restart the deployment
yourself.

#### Redis credentials — `redis.existingSecret`

This one is easy to get wrong: it is **not** a `redis-password` key. It replaces the chart's generated Redis
*properties file*, so its value must be a middleware configuration document — a YAML file whose top-level
key is a configuration scope (`anywhere` unless you know you need a narrower one) holding
`com.openexchange.redis.*` properties. Give it the same `1000_` prefix the chart's own file uses: it lands in
the same directory as the property files and is applied in file-name order, so an unprefixed name would sort
after — and silently outrank — an `existingPropertiesSecret` file you prefixed `1001_`.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-redis-props
type: Opaque
stringData:
  1000_redis-properties.yaml: |
    anywhere:
      com.openexchange.redis.mode: "sentinel"
      com.openexchange.redis.hosts: "redis-sentinel.example.svc.cluster.local:26379"
      com.openexchange.redis.sentinel.masterId: "mymaster"
      com.openexchange.redis.username: ""
      com.openexchange.redis.password: "redisPassword"
      com.openexchange.redis.ssl: "false"
      com.openexchange.redis.cache.enabled: "true"
      com.openexchange.redis.cache.mode: "cluster"
      com.openexchange.redis.cache.hosts: "redis-cache.example.svc.cluster.local:6379"
      com.openexchange.redis.cache.username: ""
      com.openexchange.redis.cache.password: "cachePassword"
      com.openexchange.redis.cache.ssl: "false"
```

For `standalone` or `cluster` mode drop the `sentinel.masterId` property and list the Redis nodes in
`hosts`. Quote every value — the middleware expects strings, and an unquoted `false` or `6379` is parsed as
a boolean or integer. Setting this value makes the chart ignore `redis.auth` and `redis.mode`, so anything
you leave out of the Secret is simply absent rather than defaulted.

Keep populating `redis.hosts` regardless. That value has a second consumer the Secret does not replace: when
the list is empty the chart deploys its own single-node Redis alongside the middleware, and that decision
does not look at `redis.existingSecret`. Leaving it at the default gets you an in-cluster Redis that nothing
connects to.

#### Environment variables — `existingEnvSecret`

Keys are environment-variable names, added to the containers via `envFrom`. Include only the variables you
actually want to override; unlike the two above, this Secret is additive, so anything you omit keeps the
value the chart generates. These are the credential-bearing variables worth putting here:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-env
type: Opaque
stringData:
  MASTER_ADMIN_USER: "oxadminmaster"
  MASTER_ADMIN_PW: "masterPassword"
  OX_BASIC_AUTH_LOGIN: "basicAuthUser"
  OX_BASIC_AUTH_PASSWORD: "basicAuthPassword"
  JOLOKIA_LOGIN: "jolokiaUser"
  JOLOKIA_PASSWORD: "jolokiaPassword"
  CREDSTORAGE_PASSCRYPT: "credStoragePassphrase"
```

Mind the caveat described under [Override precedence](#override-precedence): this changes the container
environment only, and the chart's own templating still reads the plain `masterAdmin` / `masterPassword`
values.

#### Provisioning gateway certificate — `provisioningGateway.tls.existingSecret`

Required as soon as `provisioningGateway.tls.enabled` is `true`: the chart generates no certificate, and
rendering fails with a `required` error if the value is empty. It is an ordinary `kubernetes.io/tls` Secret,
so the two keys are fixed and cannot be renamed — the gateway reads them from `tls.crt` and `tls.key` under
`provisioningGateway.tls.mountPath`.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-gateway-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded PEM certificate>
  tls.key: <base64-encoded PEM private key>
```

Like `mysql.existingSecret`, this one is not folded into the `checksums.existingSecrets` annotation, so
rotating the certificate does not restart the gateway on its own.

#### Configuration files

The remaining `existing*Secret` values all work the same way — each key becomes a file, and where that
file lands is what differs. The `.yaml`/`.yml`/`.txt` names below are examples except
where called out.

| Value | Key is | Ends up as | Constraint on the key |
|-------|--------|-----------|------------------------|
| `existingPropertiesSecret`  | a properties document | `/configuration/<key>`              | numeric prefix `>= 1001` to win over the chart |
| `existingUISettingsSecret`  | a UI settings document | `/configuration/<key>`             | numeric prefix `>= 2001` to win over the chart |
| `existingMetaSecret`        | a meta document | `/opt/open-xchange/etc/meta/<key>`        | — |
| `existingContextSetsSecret` | a context sets document | `/opt/open-xchange/etc/contextSets/<key>` | — |
| `existingASConfigSecret`    | the as-config document | `/opt/open-xchange/etc/<key>`       | must be named `as-config.yml` |
| `existingETCFilesSecret`    | any text file | `/opt/open-xchange/etc/<key>`               | — |
| `existingETCBinariesSecret` | any binary file | `/opt/open-xchange/etc/<key>`             | put it under `data`, not `stringData` |
| `existingYAMLFilesSecret`   | any YAML file | `/opt/open-xchange/etc/<key>`               | no sub-directories |

`existingPropertiesSecret` and `existingUISettingsSecret` share the single `/configuration/` directory, so
give their keys distinct names — the same key in both means one silently overwrites the other.

### Several Secrets per value

Every additive `existing*Secret` value has a plural twin that takes a list of further Secret names:
`existingPropertiesSecrets`, `existingUISettingsSecrets`, `existingMetaSecrets`, `existingContextSetsSecrets`,
`existingETCFilesSecrets`, `existingETCBinariesSecrets`, `existingYAMLFilesSecrets` and `existingEnvSecrets`.
Use them when the sensitive data comes from several sources, for example one ExternalSecret per credential.
The singular value stays supported and comes first; a name given twice is used once.

For the file-based values all listed Secrets are projected into the same directory as the singular one, so
the rule about distinct keys applies across the whole set. Which value wins on a duplicate property is still
decided by the numeric file-name prefix, not by the order of the list.

For `existingEnvSecrets` each entry becomes one more `envFrom` source after `existingEnvSecret`, so on a
duplicate key a later entry wins over an earlier one, and `extraEnv` still wins over all of them.

The `Replace` values (`existingASConfigSecret`, `redis.existingSecret`, `mysql.existingSecret`) and the
gateway TLS Secret have no plural form: each stands in for exactly one chart-generated resource.

```yaml
existingPropertiesSecret: my-extra-props    # still supported, mounted first
existingPropertiesSecrets:
  - my-ldap-credentials                     # key 1002_ldap.yaml
  - my-smtp-credentials                     # key 1003_smtp.yaml
existingEnvSecrets:
  - my-s3-env
  - my-oauth-env                            # wins over my-s3-env on a duplicate key
```

### Override precedence

For the additive property/UI-settings secrets, configuration is applied in numeric file-name order. To make
your file win over the chart-generated configuration, prefix it with a number higher than the chart's:

- properties: use a prefix `>= 1001` (the chart uses `<= 1000`)
- UI settings: use a prefix `>= 2001` (the chart uses `<= 2000`)

```yaml
# stringData of the secret named by existingPropertiesSecret
1001_existing.yaml: |
  anywhere:
    com.openexchange.foobar: "true"
```

`existingEnvSecret` is added after the common-env and chart-generated env secrets and before any
`existingEnvSecrets` entry, so on a duplicate key it overrides those two but neither a later
`existingEnvSecrets` entry nor `extraEnv`. For example, a `MASTER_ADMIN_USER` key in your secret wins over the
`MASTER_ADMIN_USER` the chart generates from `masterAdmin`.

This override happens **only at the container-environment level**. The chart's own templating still reads the
plain `masterAdmin` / `masterPassword` values (it does *not* look at `existingEnvSecret`) when it generates
other resources. So to change the master admin everywhere, set `masterAdmin` / `masterPassword` rather than
only overriding the env var through `existingEnvSecret`.

### Rolling restarts on content change

With `checksums.existingSecrets: true` (the default), the checksum of each referenced Secret's contents is
folded into a pod annotation, so editing a Secret triggers a rolling restart. `mysql.existingSecret` is
intentionally excluded (connection details rarely change).

### Example

```yaml
existingPropertiesSecret: my-extra-props   # additive; file prefixed 1001_ to override chart props
existingPropertiesSecrets: [my-ldap, my-smtp] # additive; every existing*Secret above has such a plural list
existingASConfigSecret: my-as-config       # replaces asConfig entirely
existingEnvSecret: my-env                  # extra environment variables, last-wins on duplicate keys
```

## Configuration

The following table lists the configurable parameters of the `App Suite Middleware Core` chart and their default values.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity for pod assignment |
| asConfig.default.host | string | `"all"` |  |
| basicAuthLogin | string | `""` | The user name used for HTTP basic auth. |
| basicAuthPassword | string | `""` | The password used for HTTP basic auth. |
| checksums | object | `{"commonEnv":true,"config":true,"existingSecrets":true}` | Configures the checksum annotation used to trigger rolling updates. |
| checksums.commonEnv | bool | `true` | Detect changes in the shared App Suite secret. It does not detect changes in the Secret defined by `existingEnvSecret`. Please use `checksum.existingSecrets` for this. |
| checksums.config | bool | `true` | Detect config changes in ConfigMaps and Secrets that are created by this chart. |
| checksums.existingSecrets | bool | `true` | Detect changes in Secrets defined by `existing*` values (e.g. `existingPropertiesSecret` or `existingContextSetsSecret`). |
| collabora-online.enabled | bool | `false` | Whether `Collabora` should be enabled or not. |
| collabora-online.image.repository | string | `"registry.open-xchange.com/appsuite-core-internal/3rdparty/collabora-online"` |  |
| collabora-online.image.tag | string | `"26.04.2.3.1"` |  |
| configuration | object | `{"businessmobility":{"logging":{"debug":{"enabled":false,"logPath":""}}},"languages":[],"logging":{"debug":true,"file":{"maxFileSize":"2MB","maxIndex":99,"minIndex":0,"name":"/var/log/open-xchange/open-xchange.log.0","pattern":"/var/log/open-xchange/open-xchange.log.%i"},"json":{"prettyPrint":false},"logger":[{"level":"WARN","name":"org.apache.cxf"},{"level":"WARN","name":"com.openexchange.soap.cxf.logger"}],"logstash":{"host":"localhost","port":31337},"queueSize":2048,"root":{"file":false,"json":true,"level":"INFO","logstash":false},"syslog":{"facility":"USER","host":"localhost","port":514}}}` | Configuration |
| configuration.businessmobility.logging.debug.enabled | bool | `false` | Whether debug log is enabled or not |
| configuration.businessmobility.logging.debug.logPath | string | `""` | The path of the log file @default /var/log/open-xchange |
| configuration.languages | list | `[]` | List of languages which should be enabled. The default set of languages is `de_DE`, `en_US`, `es_ES`, `fr_FR` and `it_IT`.<br/> Example for enabling a couple of languages: `[ nl_NL, fi_FI, pl_PL ]` or for all available languages `[ all ]` |
| configuration.logging.debug | bool | `true` | Enables logback's debug mode |
| configuration.logging.json.prettyPrint | bool | `false` | Whether `PrettyPrint` is enabled |
| configuration.logging.logger | list | `[{"level":"WARN","name":"org.apache.cxf"},{"level":"WARN","name":"com.openexchange.soap.cxf.logger"}]` | List of named logger |
| configuration.logging.logstash | object | `{"host":"localhost","port":31337}` | Logstash configuration |
| configuration.logging.queueSize | int | `2048` | The number of logging events to retain for delivery |
| configuration.logging.root.file | bool | `false` | Whether `File` logging is enabled |
| configuration.logging.root.json | bool | `true` | Whether `JSON` logging is enabled |
| configuration.logging.root.level | string | `"INFO"` | Sets the log level of the root logger |
| configuration.logging.root.logstash | bool | `false` | Whether logging to `logstash` is enabled |
| configuration.logging.syslog | object | `{"facility":"USER","host":"localhost","port":514}` | Syslog configuration |
| containerPorts | list | `[{"containerPort":8009,"name":"http"}]` | Container ports |
| contextSets | object | `{}` | Context sets |
| createCommonEnv | bool | `true` | Whether to create a shared secret containing common properties as environment variables (e.g. SESSIOND_ENCRYPTION_KEY) |
| credstoragePasscrypt | string | `""` | Key to encrypt/decrypt the password held in credential storage. |
| defaultRegistry | string | `"registry.open-xchange.com"` | The default registry |
| defaultScaling.nodes.default.roles[0] | string | `"http-api"` |  |
| defaultScaling.nodes.default.roles[1] | string | `"sync"` |  |
| defaultScaling.nodes.default.roles[2] | string | `"admin"` |  |
| defaultScaling.nodes.default.roles[3] | string | `"businessmobility"` |  |
| defaultScaling.nodes.default.roles[4] | string | `"request-analyzer"` |  |
| defaultScaling.nodes.default.roles[5] | string | `"documents"` |  |
| documentConverterClient.cache.remoteCache | object | `{}` |  |
| enableDBConnectionCheck | bool | `true` | Whether to wait for configdb. |
| enableInitialization | bool | `false` | Whether initial bootstraping is enabled or not. |
| etcBinaries | list | `[]` | etc files |
| etcFiles | object | `{}` | etc files |
| existingASConfigSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding `as-config.yml`. When set, this *replaces* the chart-rendered `asConfig` entirely (the `asConfig` value is then ignored). Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingContextSetsSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding additional context sets. Mounted *in addition to* `contextSets`/`secretContextSets`. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingContextSetsSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) holding additional context sets. Same content format and mount location as `existingContextSetsSecret`, which stays supported and is mounted first. All listed secrets share one directory, so their keys must be distinct. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingETCBinariesSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding additional binary etc files. Mounted *in addition to* `etcBinaries`/`secretETCBinaries`. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingETCBinariesSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) holding additional binary etc files. Same content format and mount location as `existingETCBinariesSecret`, which stays supported and is mounted first. All listed secrets share one directory, so their keys must be distinct. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingETCFilesSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding additional etc files. Mounted *in addition to* `etcFiles`/`secretETCFiles`. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingETCFilesSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) holding additional etc files. Same content format and mount location as `existingETCFilesSecret`, which stays supported and is mounted first. All listed secrets share one directory, so their keys must be distinct. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingEnvSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) whose keys are added as environment variables to the containers (via `envFrom`). It is mounted after the common-env and chart-generated env secrets and before any `existingEnvSecrets` entry, so on a duplicate key it takes precedence over those two, but neither over a later `existingEnvSecrets` entry nor over `extraEnv`. Note: this only affects the container environment; values the chart reads internally (e.g. `masterAdmin`) are not changed by it. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingEnvSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) whose keys are added as environment variables, after `existingEnvSecret`, which stays supported. Later entries win on duplicate keys, and `extraEnv` still wins over all of them. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingMetaSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding additional meta settings. Mounted *in addition to* `meta`. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingMetaSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) holding additional meta settings. Same content format and mount location as `existingMetaSecret`, which stays supported and is mounted first. All listed secrets share one directory, so their keys must be distinct. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingPropertiesSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding additional properties. Mounted *in addition to* `properties`/`secretProperties`/`propertiesFiles`/`secretPropertiesFiles`. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingPropertiesSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) holding additional properties. Same content format and mount location as `existingPropertiesSecret`, which stays supported and is mounted first. All listed secrets share one directory, so their keys must be distinct; precedence is decided by the numeric file-name prefix, not by list order. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingUISettingsSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding additional UI settings. Mounted *in addition to* `uiSettings`/`secretUISettings`/`uiSettingsFiles`/`secretUISettingsFiles`. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingUISettingsSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) holding additional UI settings. Same content format and mount location as `existingUISettingsSecret`, which stays supported and is mounted first. All listed secrets share one directory, so their keys must be distinct; precedence is decided by the numeric file-name prefix, not by list order. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingYAMLFilesSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding additional YAML files. Mounted *in addition to* `yamlFiles`/`secretYAMLFiles`. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| existingYAMLFilesSecrets | list | `[]` | Names of further existing, self-managed secrets (in the release namespace) holding additional YAML files. Same content format and mount location as `existingYAMLFilesSecret`, which stays supported and is mounted first. All listed secrets share one directory, so their keys must be distinct. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| extraContainers | list | `[]` | List of extra sidecar containers |
| extraEnv | list | `[]` | List of extra environment variables |
| extraInitContainers | list | `[]` | List of extra init containers injected into `spec.initContainers`. Use this to prepare volumes or run setup tasks before the middleware starts (e.g. copying a Java agent JAR). OX supports the Helm injection mechanism; the behavior of third-party agents is outside OX support scope. |
| extraMounts | list | `[]` | List of extra mounts |
| extraPodSpec | object | `{}` | Extra PodSpec definitions |
| extraStatefulSetProperties | object | `{}` | List of extra StatefulSet properties |
| extraVolumes | list | `[]` | List of extra volumes |
| extras.monitoring.alerts.enabled | bool | `false` | Whether to create a `PrometheusRule` with alerts, e.g. on refused live change streams. Needs monitoring enabled and the Prometheus Operator. |
| extras.monitoring.alerts.labels | object | `{}` | Additional labels of the `PrometheusRule`, e.g. the one the Prometheus instance selects rules by. |
| extras.monitoring.enabled | bool | `false` | Whether monitoring resources should be created, e.g. a `ConfigMap` containing the Grafana dashboards. |
| features | object | `{"definitions":{"admin":["open-xchange-admin","open-xchange-admin-contextrestore","open-xchange-admin-soap","open-xchange-admin-soap-usercopy","open-xchange-admin-user-copy"],"documents":["open-xchange-documents-backend","open-xchange-hazelcast"],"guard":["open-xchange-guard","open-xchange-guard-backend-plugin","open-xchange-guard-file-storage","open-xchange-guard-s3-storage"],"guard-admin":["open-xchange-guard-admin"],"mcp":["open-xchange-mcp"],"mobile-api":["open-xchange-mobile-api"],"omf-source":["open-xchange-omf-source","open-xchange-omf-source-dualprovisioning","open-xchange-omf-source-dualprovisioning-cloudplugins","open-xchange-omf-source-guard","open-xchange-omf-source-mailfilter"],"plugins":["open-xchange-plugins-antiphishing","open-xchange-plugins-antiphishing-vadesecure","open-xchange-plugins-blackwhitelist","open-xchange-plugins-blackwhitelist-sieve","open-xchange-plugins-contact-storage-group","open-xchange-plugins-contact-storage-provider","open-xchange-plugins-contact-whitelist-sync","open-xchange-plugins-mx-checker","open-xchange-plugins-onboarding-maillogin","open-xchange-plugins-trustedidentity","open-xchange-plugins-unsubscribe","open-xchange-plugins-unsubscribe-vadesecure"],"reseller":["open-xchange-admin-reseller","open-xchange-admin-soap-reseller"],"scim":["open-xchange-scim"],"usm-eas":["open-xchange-usm","open-xchange-eas"],"weakforced":["open-xchange-weakforced"]},"status":{"documents":"disabled","mcp":"disabled","mobile-api":"disabled","omf-source":"disabled","plugins":"disabled","reseller":"disabled","scim":"disabled","usm-eas":"disabled","weakforced":"disabled"}}` | Feature definition |
| features.definitions.admin | list | see `values.yaml` | Admin definitions |
| features.definitions.documents | list | see `values.yaml` | Documents definitions |
| features.definitions.guard | list | see `values.yaml` | Guard definitions |
| features.definitions.mcp | list | see `values.yaml` | MCP server definitions. Disabled by default; the endpoint also needs `com.openexchange.mcp.enabled`. |
| features.definitions.mobile-api | list | see `values.yaml` | Mobile API definitions. Disabled by default; the API also needs `com.openexchange.mobile.api.enabled`. |
| features.definitions.omf-source | list | see `values.yaml` | OX2OX Migration Framework Source definitions |
| features.definitions.plugins | list | see `values.yaml` | Plugins definitions |
| features.definitions.reseller | list | see `values.yaml` | Reseller definitions |
| features.definitions.scim | list | see `values.yaml` | SCIM service provider definitions. Enabled on the `admin` role only; see `roles.admin.values`. |
| features.definitions.usm-eas | list | see `values.yaml` | USM EAS sync definitions |
| features.status | object | see `values.yaml` | Choose whether to enable or disable features. |
| fullnameOverride | string | `""` | Fully override of the `ox-common.names.fullname` template |
| global.extras.monitoring.enabled | bool | `false` |  |
| global.imageRegistry | string | `""` | Sets the image registry globally |
| global.mysql.existingSecret | string | `""` |  |
| gotenberg.chromium.disableJavaScript | bool | `true` |  |
| gotenberg.enabled | bool | `false` | Whether `Gotenberg` should be enabled or not. |
| gotenberg.extraEnv[0].name | string | `"XDG_DATA_HOME"` |  |
| gotenberg.extraEnv[0].value | string | `"/tmp/.data"` |  |
| gotenberg.extraEnv[1].name | string | `"XDG_CONFIG_HOME"` |  |
| gotenberg.extraEnv[1].value | string | `"/tmp/.config"` |  |
| gotenberg.extraEnv[2].name | string | `"XDG_CACHE_HOME"` |  |
| gotenberg.extraEnv[2].value | string | `"/tmp/.cache"` |  |
| gotenberg.image.repository | string | `"registry.open-xchange.com/appsuite-core-internal/3rdparty/gotenberg"` |  |
| gotenberg.image.tag | string | `"8.34.0"` |  |
| gotenberg.livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/health","port":"http"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Liveness probe of the `Gotenberg` container. The timing fields spell out the Kubernetes defaults, which cluster policies may require to be set explicitly. |
| gotenberg.readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/health","port":"http"},"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Readiness probe of the `Gotenberg` container. See `gotenberg.livenessProbe`. |
| gotenberg.securityContext.readOnlyRootFilesystem | bool | `true` |  |
| gotenberg.volumeMounts[0].mountPath | string | `"/tmp"` |  |
| gotenberg.volumeMounts[0].name | string | `"tmp-volume"` |  |
| gotenberg.volumes[0].emptyDir.medium | string | `"Memory"` |  |
| gotenberg.volumes[0].emptyDir.sizeLimit | string | `"256Mi"` |  |
| gotenberg.volumes[0].name | string | `"tmp-volume"` |  |
| hooks.beforeApply | object | `{}` |  |
| hooks.beforeAppsuiteStart | object | `{}` |  |
| hooks.start | object | `{}` |  |
| hpa | object | `{"behavior":{},"create":false,"maxReplicas":4,"metrics":[],"minReplicas":1,"targetCPUUtilizationPercentage":80,"targetMemoryUtilizationPercentage":""}` | Horizontal Pod Autoscaler configuration. Rendered per scaling type. When enabled for a type, the Deployment's static `replicas` field is omitted so the HPA owns the replica count. Can be overridden per role/type like any other value. |
| hpa.behavior | object | `{}` | Raw `spec.behavior` block (scale-up/scale-down policies), rendered verbatim. Leave empty to omit. |
| hpa.create | bool | `false` | Whether a HorizontalPodAutoscaler should be created for the type |
| hpa.maxReplicas | int | `4` | Upper bound for the number of replicas |
| hpa.metrics | list | `[]` | Raw list of additional `spec.metrics` entries (verbatim). Use for custom/external metrics. |
| hpa.minReplicas | int | `1` | Lower bound for the number of replicas |
| hpa.targetCPUUtilizationPercentage | int | `80` | Target average CPU utilization (percentage). Leave empty to omit the CPU metric. |
| hpa.targetMemoryUtilizationPercentage | string | `""` | Target average memory utilization (percentage). Leave empty to omit the memory metric. |
| hzGroupName | string | `""` | The [Hazelcast](https://hazelcast.com/) group name. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"appsuite-core/middleware"` | Image repository |
| image.tag | string | `""` | Image tag |
| imagePullSecrets | list | `[]` | Reference to one or more secrets to be used when pulling images |
| initContainer | object | `{}` |  |
| initWait | object | `{"dbTimeout":300,"middlewareTimeout":300}` | Bounded readiness waits performed by the init container. |
| initWait.dbTimeout | int | `300` | How long to wait, in seconds, for the configdb to accept connections before failing the init container. |
| initWait.middlewareTimeout | int | `300` | How long to wait, in seconds, for the middleware to come up during initial bootstrapping before failing the init container. |
| istio.compression.enabled | bool | `false` | Whether to enable HTTP compression (gzip, deflate, etc.). |
| istio.injection.enabled | bool | `false` | Whether to enable sidecar injection or not. |
| istio.virtualServices.destinationPort | int | `80` | The virtual service destination port |
| javaOpts.compactObjectHeaders | bool | `true` | Enables Compact Object Headers (appends `-XX:+UseCompactObjectHeaders`, JEP 519): 8-byte object headers → less live heap and GC pressure. Applied even when `other` is overridden; not appended again if `other` already mentions the flag (e.g. an explicit `-XX:-UseCompactObjectHeaders` opt-out is left untouched). |
| javaOpts.debug.gcLogs.enabled | bool | `false` | Enables Java Garbage Collector logging |
| javaOpts.debug.heapdump.custom | object | `{}` | The definition of a custom volume excluding its name which shall be used instead of a hostpath volume. |
| javaOpts.debug.heapdump.enabled | bool | `false` | Enables Java Heap Dump creation in OOM situations |
| javaOpts.debug.heapdump.hostPath.dir | string | `"/mnt/appsuite-heap-dumps"` | hostPath directory on the k8s worker nodes, which needs to be created manually by the k8s admin. The directory will be mounted inside the core-mw container as '/heapdump'. |
| javaOpts.mallocArenaMax | string | `"2"` | Caps glibc malloc arenas via the `MALLOC_ARENA_MAX` env var to bound native memory. The many-threaded (virtual-thread) middleware otherwise retains ~1.2G in per-thread malloc arenas; "2" cuts that back — bringing ZGC's non-heap native down to G1 level and letting ZGC fit a 6G limit at a 4G heap (vs 8G uncapped). Benefits G1 too. Set to "" for the glibc default. Minor malloc-contention trade-off at very high concurrency. See SCR-1723. |
| javaOpts.memory.maxHeapSize | string | `"2048M"` | Sets -XX:MaxHeapSize. Ignored if maxRAMPercentage is set. |
| javaOpts.memory.maxRAMPercentage | string | `""` | Sets -XX:MaxRAMPercentage instead of maxHeapSize. Takes precedence over maxHeapSize when set. |
| javaOpts.network | string | `""` |  |
| javaOpts.other | string | `""` | Extra JVM options appended verbatim (env `JAVA_OPTS_OTHER`). (For Compact Object Headers or ZGC, prefer the `compactObjectHeaders`/`zgc` toggles below — not this field.) |
| javaOpts.server | string | `""` |  |
| javaOpts.zgc | bool | `false` | Use generational ZGC instead of the default G1 (appends `-XX:+UseZGC`; not appended again if `other` already mentions the flag). Opt-in: ZGC gives sub-ms, near-constant GC pauses, well-suited to the virtual-thread worker pool, but needs substantial native-memory headroom beyond the heap (off-heap generational structures plus socket/NIO direct buffers). Too little does NOT surface as an OOM — it shows up as failures to open IMAP/SMTP connections under load. A ~50% heap ratio alone is not enough at small limits: in CI, 4G heap on a 6G limit and 3G heap on a 6G limit both failed, while 4G heap on an 8G limit (~3-4G free) passed cleanly. Before enabling, size heap ≤ ~50% of resources.limits.memory AND leave several GB free (e.g. a 4G heap wants an ≥8G limit). Validate under load before rollout. |
| javaOpts.zgcUncommitDelay | string | `""` | ZGC only (ignored unless `zgc: true`): seconds of idle before unused heap is uncommitted to the OS (`-XX:ZUncommitDelay`; uncommit is on by default). Lower returns idle memory faster, at a page-fault cost on reload — useful for "pay per used memory" hosting. Empty = JVM default (300). e.g. "60". Note: this returns heap only, not glibc malloc arenas (see mallocArenaMax). See SCR-1723. |
| jolokiaLogin | string | `""` | User used for authentication with HTTP Basic Authentication. |
| jolokiaPassword | string | `""` | Password used for authentification with HTTP Basic Authentication. |
| masterAdmin | string | `""` | The name of the master admin. |
| masterPassword | string | `""` | The password of the master admin. |
| meta | object | `{}` | Meta |
| mysql.auth.password | string | `""` | The database password. *`(read/write connection)`* |
| mysql.auth.readPassword | string | `""` | The database password. *`(read connection)`* |
| mysql.auth.readUser | string | `""` | The database user name. *`(read connection)`* |
| mysql.auth.rootPassword | string | `""` | The MySQL `root` password. |
| mysql.auth.user | string | `""` | The database user name. *`(read/write connection)`* |
| mysql.auth.writePassword | string | `""` | The database password. *`(write connection)`* |
| mysql.auth.writeUser | string | `""` | The database user name. *`(write connection)`* |
| mysql.database | string | `""` | The database/schema name. *`(read/write connection)`* |
| mysql.existingSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding the configdb connection credentials. When set, the chart does *not* render its own MySQL secret and references this one instead. Unlike the other `existing*` secrets, this is not tracked by the `checksums.existingSecrets` annotation. |
| mysql.host | string | `""` | The database host. *`(read/write connection)`* |
| mysql.port | string | `""` | The database port. *`(read/write connection)`* |
| mysql.readDatabase | string | `""` | The database/schema name. *`(read connection)`* |
| mysql.readHost | string | `""` | The database host. *`(read connection)`* |
| mysql.readPort | string | `""` | The database port. *`(read connection)`* |
| mysql.writeDatabase | string | `""` | The database/schema name. *`(write connection)`* |
| mysql.writeHost | string | `""` | The database host. *`(write connection)`* |
| mysql.writePort | string | `""` | The database port. *`(write connection)`* |
| nameOverride | string | `""` | Partially override of the `ox-common.names.fullname` template<br/> *NOTE: Preserves the release name.* |
| nodeSelector | object | `{}` | Tolerations for pod assignment |
| packages | object | `{"status":{"open-xchange-admin-autocontextid":"disabled","open-xchange-authentication-imap":"disabled","open-xchange-authentication-ldap":"disabled","open-xchange-authentication-masterpassword":"disabled","open-xchange-authentication-oauth":"disabled","open-xchange-cassandra":"disabled","open-xchange-dataretention-csv":"disabled","open-xchange-drive-client-windows":"disabled","open-xchange-eas-provisioning":"disabled","open-xchange-eas-provisioning-mail":"disabled","open-xchange-eas-provisioning-sms":"disabled","open-xchange-hostname-config-cascade":"disabled","open-xchange-hostname-ldap":"disabled","open-xchange-multifactor":"disabled","open-xchange-parallels":"disabled","open-xchange-passwordchange-script":"disabled","open-xchange-saml-core":"disabled","open-xchange-sms-sipgate":"disabled","open-xchange-sms-twilio":"disabled","open-xchange-spamhandler-parallels":"disabled","open-xchange-sso":"disabled"},"whitelist":[]}` | Packages By default, all packages will be enabled. If a package is defined within a feature and that `feature` is disabled, the package will not be started UNLESS it is explicitly reactivated in this section. All disabled packages will be written into the environment variable OX_BLACKLISTED_PACKAGES. |
| packages.status | object | see `values.yaml` | Choose whether to enable or disable packages. |
| packages.whitelist | list | `[]` | Whitelist The whitelist stands in contrast to the blacklist approach. Packages listed here are added to the OX_WHITELISTED_PACKAGES variable. This variable takes precedence over OX_BLACKLISTED_PACKAGES, causing the blacklist to be ignored. |
| pdb | object | `{"create":false,"maxUnavailable":"","minAvailable":"","unhealthyPodEvictionPolicy":""}` | Pod Disruption Budget configuration |
| pdb.create | bool | `false` | Whether a PodDisruptionBudget should be created |
| pdb.maxUnavailable | string | `""` | Maximum number or percentage of pods that can be unavailable. Mutually exclusive with minAvailable. Examples: 1, "25%" |
| pdb.minAvailable | string | `""` | Minimum number or percentage of pods that must be available. Mutually exclusive with maxUnavailable. Examples: 1, "50%" |
| pdb.unhealthyPodEvictionPolicy | string | `""` | Policy for evicting unhealthy (not yet Ready) pods, rendered as `spec.unhealthyPodEvictionPolicy` (GA since Kubernetes 1.31). Leave empty to omit. Examples: "IfHealthyBudget", "AlwaysAllow" |
| podAnnotations | object | `{"logging.open-xchange.com/format":"appsuite-json"}` | Annotations to add to the pod |
| podSecurityContext | object | `{}` | The pod security context |
| priorityClassName | string | `""` | The priority class for pods |
| probe.liveness.enabled | bool | `true` | Enable the liveness probe |
| probe.liveness.failureThreshold | int | `15` | The liveness probe failure threshold |
| probe.liveness.httpGet | object | `{"path":"/live","port":8016,"scheme":"HTTP"}` | Specifies the HTTP request to perform |
| probe.liveness.httpGet.path | string | `"/live"` | Path to access on the HTTP server |
| probe.liveness.httpGet.port | int | `8016` | Name or number of the port to access on the container. Number must be in the range 1 to 65535. |
| probe.liveness.httpGet.scheme | string | `"HTTP"` | Scheme to use for connecting to the host (HTTP or HTTPS). Defaults to "HTTP". |
| probe.liveness.periodSeconds | int | `10` | The liveness probe period (in seconds) |
| probe.readiness.enabled | bool | `true` | Enable the readiness probe |
| probe.readiness.failureThreshold | int | `2` | The readiness probe failure threshold |
| probe.readiness.httpGet | object | `{"path":"/ready","port":8009,"scheme":"HTTP"}` | Specifies the HTTP request to perform |
| probe.readiness.httpGet.path | string | `"/ready"` | Path to access on the HTTP server |
| probe.readiness.httpGet.port | int | `8009` | Name or number of the port to access on the container. Number must be in the range 1 to 65535. |
| probe.readiness.httpGet.scheme | string | `"HTTP"` | Scheme to use for connecting to the host (HTTP or HTTPS). Defaults to "HTTP". |
| probe.readiness.initialDelaySeconds | int | `30` | The readiness probe initial delay (in seconds) |
| probe.readiness.periodSeconds | int | `5` | The readiness probe period (in seconds) |
| probe.readiness.timeoutSeconds | int | `5` | The readiness probe timeout (in seconds) |
| probe.startup.enabled | bool | `true` | Enable the startup probe |
| probe.startup.failureThreshold | int | `30` | The startup probe failure threshold |
| probe.startup.httpGet | object | `{"path":"/health","port":8009,"scheme":"HTTP"}` | Specifies the HTTP request to perform |
| probe.startup.httpGet.path | string | `"/health"` | Path to access on the HTTP server |
| probe.startup.httpGet.port | int | `8009` | Name or number of the port to access on the container. Number must be in the range 1 to 65535. |
| probe.startup.httpGet.scheme | string | `"HTTP"` | Scheme to use for connecting to the host (HTTP or HTTPS). Defaults to "HTTP". |
| probe.startup.initialDelaySeconds | int | `30` | The startup probe initial delay (in seconds) |
| probe.startup.periodSeconds | int | `10` | The startup probe period (in seconds) |
| probeHeaders | list | `[]` |  |
| properties | object | see `values.yaml` | Properties |
| propertiesFiles | object | `{}` | Properties files |
| provisioningGateway.adminPort | int | `9901` | Port of Envoy's own admin interface. Bound to loopback only. |
| provisioningGateway.descriptorMountPath | string | `"/etc/provisioning"` | Where the descriptor set is mounted into the gateway container. |
| provisioningGateway.enabled | bool | `false` | Whether to run the provisioning HTTP/JSON gateway. |
| provisioningGateway.grpcPort | int | `8066` | Port the middleware's gRPC server listens on, i.e. `com.openexchange.grpc.server.port`. |
| provisioningGateway.image.pullPolicy | string | `"IfNotPresent"` |  |
| provisioningGateway.image.repository | string | `"envoyproxy/envoy"` |  |
| provisioningGateway.image.tag | string | `"v1.31.9"` | A fixed tag on purpose. A floating one (`v1.31-latest`) makes the gateway a different binary from one pod restart to the next, which is not something to discover during an incident. Bump deliberately. |
| provisioningGateway.port | int | `8080` | Port the gateway listens on inside the pod. |
| provisioningGateway.resources.limits.memory | string | `"256Mi"` |  |
| provisioningGateway.resources.requests.cpu | string | `"50m"` |  |
| provisioningGateway.resources.requests.memory | string | `"64Mi"` |  |
| provisioningGateway.role | string | `"admin"` | The role whose pods carry the gateway. It talks to the middleware over the pod's loopback interface, so it has to sit next to a middleware that serves provisioning. |
| provisioningGateway.service.port | int | `80` | Service port. Set this to 443 when the gateway terminates TLS. |
| provisioningGateway.service.type | string | `"ClusterIP"` | Service type for the gateway. |
| provisioningGateway.services | list | `["com.openexchange.grpc.provisioning.ContextService","com.openexchange.grpc.provisioning.UserService","com.openexchange.grpc.provisioning.GroupService","com.openexchange.grpc.provisioning.ResourceService","com.openexchange.grpc.provisioning.SharedAccountService","com.openexchange.grpc.provisioning.SecondaryAccountService","com.openexchange.grpc.provisioning.ResellerService","com.openexchange.grpc.provisioning.DeputyPermissionService","com.openexchange.grpc.provisioning.UtilService","com.openexchange.grpc.provisioning.JobService","com.openexchange.grpc.provisioning.UserCopyService","com.openexchange.grpc.provisioning.SessiondService","com.openexchange.grpc.provisioning.ProvisioningTokenService","com.openexchange.grpc.provisioning.ChronosService"]` | The gRPC services to expose. Only services listed here are reachable over HTTP, so this list is also the gateway's attack surface.  The default is the set the SOAP provisioning interface already offers, so a caller can move off SOAP without losing an operation it had. Everything beyond that stays opt-in - notably the cluster maintenance services (`ExtendedUpdateTaskService`, `DBMigrationService`, `SchemaService`, `ContextRestoreService`, `ConsistencyService` and friends), which are not what a provisioning client needs and which include operations such as starting an update run. |
| provisioningGateway.timeout | string | `"600s"` | How long a call may take before the gateway gives up and answers `504`. Giving up does not stop the call: the middleware completes it anyway, the caller just never learns the outcome. Some calls, deleting a context with much data for instance, run long, hence the generous default. Whatever sits in front of the gateway needs at least the same timeout. `0s` disables it. |
| provisioningGateway.tls.enabled | bool | `false` | Whether the gateway terminates TLS itself. The endpoint carries administrative credentials in an HTTP basic header, so plain text is only defensible on a trusted, non-routable network. |
| provisioningGateway.tls.existingSecret | string | `""` | Name of an existing `kubernetes.io/tls` secret holding `tls.crt` and `tls.key`. Required when TLS is enabled; the chart does not generate a certificate. |
| provisioningGateway.tls.mountPath | string | `"/etc/provisioning-tls"` | Where the certificate and key are mounted into the gateway container. |
| rbac.create | bool | `true` | Whether Role-Based Access Control (RBAC) resources should be created |
| rbac.rules | list | `[]` | Custom RBAC rules |
| redis.affinity | object | `{}` | Affinity for pod assignment |
| redis.auth.password | string | `""` | The `Redis` password. |
| redis.auth.username | string | `""` | The `Redis` username. |
| redis.cache | object | `{"auth":{"password":"","username":""},"enabled":false,"hosts":[],"mode":"","sentinelMasterId":"","tls":{"enabled":false}}` | Configuration for a separate cache for volatile data. |
| redis.cache.auth.password | string | `""` | The `Redis` password. |
| redis.cache.auth.username | string | `""` | The `Redis` username. |
| redis.cache.enabled | bool | `false` | Whether a separate cache for volatile data is enabled or not, which is highly recommended in production. |
| redis.cache.hosts | list | `[]` | List of `Redis` hosts: <br/> Example for `redis`: [ <redis_host>:<redis_port> ] <br/> Example for `redis+sentinel`: [ <sentinel1_host>:<sentinel1_port>,<sentinel2_host>:<sentinel2_port>,<sentinel3_host>:<sentinel3_port> ] <br/> > Note: If `hosts` is empty or null, then an internal `redis`-standalone instance will be deployed. |
| redis.cache.mode | string | `""` | Redis operation mode (`standalone`, `cluster`, `sentinel`). |
| redis.cache.sentinelMasterId | string | `""` | Name of the `sentinel` masterSet, if operation mode is set to `sentinel`. |
| redis.cache.tls | object | `{"enabled":false}` | Redis TLS configuration. |
| redis.cache.tls.enabled | bool | `false` | Whether to use TLS to connect to Redis end-point or not. |
| redis.existingSecret | string | `""` | Name of an existing, self-managed secret (in the release namespace) holding Redis properties. When set, this *replaces* the chart-generated Redis properties secret. Content changes trigger a rolling restart when `checksums.existingSecrets` is enabled. |
| redis.extraEnvVars | list | `[]` | List of extra environment variables |
| redis.hosts | list | `[]` | List of `Redis` hosts: <br/> Example for `redis`: [ <redis_host>:<redis_port> ] <br/> Example for `redis+sentinel`: [ <sentinel1_host>:<sentinel1_port>,<sentinel2_host>:<sentinel2_port>,<sentinel3_host>:<sentinel3_port> ] <br/> > Note: If `hosts` is empty or null, then an internal `redis`-standalone instance will be deployed. |
| redis.image.repository | string | `"redis"` | Redis image repository |
| redis.image.tag | string | `"7-alpine"` | Redis image tag |
| redis.mode | string | `""` | Redis operation mode (`standalone`, `cluster`, `sentinel`) |
| redis.nodeSelector | object | `{}` | Node labels for pod assignment |
| redis.sentinelMasterId | string | `""` | Name of the `sentinel` masterSet, if operation mode is set to `sentinel`. |
| redis.tls | object | `{"enabled":false}` | Redis TLS configuration. |
| redis.tls.enabled | bool | `false` | Whether to use TLS to connect to Redis end-point or not. |
| redis.tolerations | list | `[]` | Tolerations for pod assignment |
| remoteDebug.enabled | bool | `false` | Whether Java Remote Debugging is enabled. |
| remoteDebug.nodePort | string | `nil` | The node port (default range: 30000-32767) |
| remoteDebug.port | int | `8102` | The Java Remote Debug port. |
| replicas | int | `1` | Number of nodes |
| resources | object | `{"limits":{"memory":"4096Mi"},"requests":{"cpu":"1000m","memory":"4096Mi"}}` | CPU/Memory resource requests/limits |
| restricted.drive.enabled | bool | `true` | If enabled tries to mount drive restricted configuration |
| roles.admin.services[0].ports[0].name | string | `"http"` |  |
| roles.admin.services[0].ports[0].port | int | `80` |  |
| roles.admin.services[0].ports[0].protocol | string | `"TCP"` |  |
| roles.admin.services[0].ports[0].targetPort | string | `"http"` |  |
| roles.admin.services[0].type | string | `"ClusterIP"` |  |
| roles.admin.values.features.status.scim | string | `"enabled"` |  |
| roles.businessmobility.services[0].ports[0].name | string | `"http"` |  |
| roles.businessmobility.services[0].ports[0].port | int | `80` |  |
| roles.businessmobility.services[0].ports[0].protocol | string | `"TCP"` |  |
| roles.businessmobility.services[0].ports[0].targetPort | string | `"http"` |  |
| roles.businessmobility.services[0].type | string | `"ClusterIP"` |  |
| roles.businessmobility.values.features.status.usm-eas | string | `"enabled"` |  |
| roles.businessmobility.values.properties."com.openexchange.usm.ox.url" | string | `"http://localhost:8009/appsuite/api/"` |  |
| roles.documents.controller | string | `"StatefulSet"` |  |
| roles.documents.services[0].headless | bool | `true` |  |
| roles.documents.services[0].name | string | `"hazelcast-headless"` |  |
| roles.documents.services[0].ports[0].name | string | `"tcp-hazelcast"` |  |
| roles.documents.services[0].ports[0].port | int | `5701` |  |
| roles.documents.statefulSetServiceName | string | `"hazelcast-headless"` |  |
| roles.documents.values.features.status.documents | string | `"enabled"` |  |
| roles.http-api.services[0].ports[0].name | string | `"http"` |  |
| roles.http-api.services[0].ports[0].port | int | `80` |  |
| roles.http-api.services[0].ports[0].protocol | string | `"TCP"` |  |
| roles.http-api.services[0].ports[0].targetPort | string | `"http"` |  |
| roles.http-api.services[0].type | string | `"ClusterIP"` |  |
| roles.request-analyzer.services[0].ports[0].name | string | `"http"` |  |
| roles.request-analyzer.services[0].ports[0].port | int | `80` |  |
| roles.request-analyzer.services[0].ports[0].protocol | string | `"TCP"` |  |
| roles.request-analyzer.services[0].ports[0].targetPort | string | `"http"` |  |
| roles.request-analyzer.services[0].type | string | `"ClusterIP"` |  |
| roles.sync.services[0].ports[0].name | string | `"http"` |  |
| roles.sync.services[0].ports[0].port | int | `80` |  |
| roles.sync.services[0].ports[0].protocol | string | `"TCP"` |  |
| roles.sync.services[0].ports[0].targetPort | string | `"http"` |  |
| roles.sync.services[0].type | string | `"ClusterIP"` |  |
| secretContextSets | object | `{}` | Secret Context sets |
| secretETCBinaries | list | `[]` | Secret etc files |
| secretETCFiles | object | `{}` | Secret etc files |
| secretProperties | object | `{}` | Secret properties |
| secretPropertiesFiles | object | `{}` | Secret properties files |
| secretUISettings | object | `{}` | Secret UI settings |
| secretUISettingsFiles | object | `{}` | Secret UI settings files |
| secretYAMLFiles | object | `{}` | Secret YAML files |
| securityContext | object | `{"allowPrivilegeEscalation":false}` | The security context |
| serverName | string | `"server"` | The server name. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| terminationGracePeriodSeconds | int | `60` | Duration in seconds the pod waits to terminate gracefully. |
| tolerations | list | `[]` | Tolerations for pod assignment |
| topologySpreadConstraints | list | `[]` | Topology spread constraints for pod assignment, rendered as `spec.topologySpreadConstraints`. Use to guarantee even pod spread across zones/nodes where preferred anti-affinity cannot. Example: topologySpreadConstraints:   - maxSkew: 1     topologyKey: topology.kubernetes.io/zone     whenUnsatisfiable: DoNotSchedule     labelSelector:       matchLabels:         app.kubernetes.io/name: core-mw |
| uiSettings | object | `{}` | UI settings |
| uiSettingsFiles | object | `{}` | UI settings files |
| update.enabled | bool | `false` | Whether an update task job for the specified database schemata is created or not |
| update.job | object | `{"automountServiceAccountToken":false,"ttlSecondsAfterFinished":86400}` | Job object settings |
| update.job.automountServiceAccountToken | bool | `false` | Whether the update job pod mounts the Kubernetes API token. The job does not call the Kubernetes API, so it defaults to false (CIS 5.1.6). Set to true only if a custom container needs API access. |
| update.job.ttlSecondsAfterFinished | int | `86400` | The number of seconds after which a job is deleted automatically |
| update.schemata | string | `""` | Database schemata to update. If empty, all schemata will be updated. |
| update.types | list | `[]` | Filter for which types the update tasks are triggered. Every type with an unique bundle set will create a container in the update job. All containers (except one) are configured as init containers to ensure they run sequentially. |
| update.values | object | `{}` | Override type sepcific update values |
| useLegacyBashScripts | bool | `true` | Whether to use the old bash style init scripts. This is necessary if you want to use bash style hooks instead of go binaries. |
| yamlFiles | object | `{}` | YAML files |