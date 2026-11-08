# Gitea Actions Helm Chart

This helm chart serves as the way to deploy the Gitea [act-runners](https://gitea.com/gitea/act_runner) alongside a running Gitea instance.  
It serves as a standalone chart and does not rely on Gitea to be present in the same environment, however it needs to be able to reach a Gitea instance to function.  
The parameters which can be used to customize the deployment are described below, check those out if you want to see if something is supported.  

If you want to propose a new feature or mechanism, submit an [issue here](https://gitea.com/gitea/helm-actions/issues).

## Quick-start

[Documentation](./docs/README.md)

To get started, add the Helm repo, assuming you have not already:

```sh
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update
```

Then pull the values.yaml file and fill it accordingly.

```sh
helm show values gitea-charts/actions > values.yaml
```

Deploy with your values, make sure the path is correct:

```sh
helm upgrade --install gitea-actions gitea-charts/actions -f values.yaml
```

Alternatively:

```sh
helm upgrade --install gitea-actions gitea-charts/actions \
  --set enabled=true \
  --set giteaRootURL=https://gitea.com \
  --set existingSecret=foo \
  --set existingSecretKey=bar
```

You should be good to go!

### Runner Token Secret Template

For reference, a template for the secret is given below:  

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: runner-secret
  namespace: "my-gitea-namespace"
type: Opaque
stringData:
    runner-token: "my-cool-runner-token-given-by-gitea"
```

### Rootless Options

If `.Values.statefulset.dind.rootless: true` is set, then the following will be required:  
`.Values.statefulset.dind.tag` must be a rootless image such as: `29.3.1-dind-rootless`

## Parameters

### Gitea Actions

For resource limit examples (runner vs DinD), see [docs/resources.md](./docs/resources.md).

| Name                                   | Description                                                                                                                                            | Value                          |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------ |
| `enabled`                              | Create a Gitea Runner StatefulSet.                                                                                                                     | `false`                        |
| `statefulset.replicas`                 | the amount of (replica) runner pods deployed                                                                                                           | `1`                            |
| `statefulset.timezone`                 | is the timezone that will be set in the runner image                                                                                                   | `Etc/UTC`                      |
| `statefulset.annotations`              | Gitea Runner annotations                                                                                                                               | `{}`                           |
| `statefulset.labels`                   | Gitea Runner labels                                                                                                                                    | `{}`                           |
| `statefulset.resources`                | Shared resource requests/limits for both containers. Overridden by statefulset.runner.resources and statefulset.dind.resources. See docs/resources.md. | `{}`                           |
| `statefulset.nodeSelector`             | NodeSelector for the statefulset                                                                                                                       | `{}`                           |
| `statefulset.tolerations`              | Tolerations for the statefulset                                                                                                                        | `[]`                           |
| `statefulset.affinity`                 | Affinity for the statefulset                                                                                                                           | `{}`                           |
| `statefulset.extraVolumes`             | Extra volumes for the statefulset                                                                                                                      | `[]`                           |
| `statefulset.persistence.size`         | Size for persistence to store Gitea Runner data                                                                                                        | `1Gi`                          |
| `statefulset.securityContext`          | Customize the SecurityContext                                                                                                                          | `{}`                           |
| `statefulset.serviceAccountName`       | Customize the service account name                                                                                                                     | `""`                           |
| `statefulset.runtimeClassName`         | Select a different RuntimeClass for pods                                                                                                               | `""`                           |
| `statefulset.hostAliases`              | Inject entries into the /etc/hosts file                                                                                                                | `[]`                           |
| `statefulset.persistence.size`         | Size for persistence to store Gitea Runner data                                                                                                        | `1Gi`                          |
| `statefulset.runner.registry`          | image registry, e.g. gcr.io,docker.io                                                                                                                  | `docker.gitea.com`             |
| `statefulset.runner.repository`        | The Gitea Runner image                                                                                                                                 | `runner`                       |
| `statefulset.runner.tag`               | The Gitea Runner tag                                                                                                                                   | `3.0.2`                        |
| `statefulset.runner.digest`            | Image digest. Allows to pin the given image tag. Useful for having control over mutable tags like `latest`                                             | `""`                           |
| `statefulset.runner.pullPolicy`        | The Gitea Runner pullPolicy                                                                                                                            | `IfNotPresent`                 |
| `statefulset.runner.fullOverride`      | Completely overrides the image registry, path/image, tag and digest.                                                                                   | `""`                           |
| `statefulset.runner.resources`         | Resource requests/limits for the runner container. Takes precedence over statefulset.resources when set.                                               | `{}`                           |
| `statefulset.runner.extraVolumeMounts` | Allows mounting extra volumes in the Gitea Runner container                                                                                            | `[]`                           |
| `statefulset.runner.extraEnvs`         | Allows adding custom environment variables                                                                                                             | `[]`                           |
| `statefulset.runner.flushCache`        | whether to clear the .runner (cache) file by creating an extra init container, can slightly increase boot-up time                                      | `false`                        |
| `statefulset.runner.config`            | Gitea Runner custom configuration. See [Gitea Runner documentation](https://docs.gitea.com/usage/actions/act-runner#configuration) for details.        | `Too complex. See values.yaml` |
| `statefulset.dind.rootless`            | a simple flag to let helm know we are dealing with a rootless dind container                                                                           | `false`                        |
| `statefulset.dind.uid`                 | a field to set the running user id for the rootless dind container, so it knows where to look for the socket                                           | `""`                           |
| `statefulset.dind.registry`            | image registry, e.g. gcr.io,docker.io                                                                                                                  | `docker.io`                    |
| `statefulset.dind.repository`          | The Docker-in-Docker image                                                                                                                             | `docker`                       |
| `statefulset.dind.tag`                 | The Docker-in-Docker image tag                                                                                                                         | `29.7.1-dind`                  |
| `statefulset.dind.digest`              | Image digest. Allows to pin the given image tag. Useful for having control over mutable tags like `latest`                                             | `""`                           |
| `statefulset.dind.fullOverride`        | Completely overrides the image registry, path/image, tag and digest.                                                                                   | `""`                           |
| `statefulset.dind.pullPolicy`          | The Docker-in-Docker pullPolicy                                                                                                                        | `IfNotPresent`                 |
| `statefulset.dind.resources`           | Resource requests/limits for the DinD sidecar container. Takes precedence over statefulset.resources when set.                                         | `{}`                           |
| `statefulset.dind.extraVolumeMounts`   | Allows mounting extra volumes in the Docker-in-Docker container                                                                                        | `[]`                           |
| `statefulset.dind.extraEnvs`           | Allows adding custom environment variables, such as `DOCKER_IPTABLES_LEGACY`                                                                           | `[]`                           |
| `statefulset.dind.extraArgs`           | Allows adding custom arguments to the Docker Daemon                                                                                                    | `[]`                           |

### Gitea Actions Init

| Name                                | Description                                                                                                | Value          |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------- |
| `init.image.registry`               | Image registry, e.g. gcr.io,docker.io                                                                      | `""`           |
| `init.image.repository`             | The init image (default: busyboxy but can be changed to alpine e.g.)                                       | `busybox`      |
| `init.image.tag`                    | The init image tag                                                                                         | `1.38.0`       |
| `init.image.digest`                 | Image digest. Allows to pin the given image tag. Useful for having control over mutable tags like `latest` | `""`           |
| `init.image.pullPolicy`             | The init image pullPolicy                                                                                  | `IfNotPresent` |
| `init.image.fullOverride`           | Completely overrides the image registry, path/image, tag and digest                                        | `""`           |
| `init.connectionCommandOverride`    | Possiblity to change the command with which the container tests its connection to the Gitea server         | `""`           |
| `init.preConnectionCommandOverride` | Possibility to add commands that happen before the connection test loop                                    | `""`           |

### Runner Token Secret Configuration

| Name                | Description                    | Value |
| ------------------- | ------------------------------ | ----- |
| `existingSecret`    | Secret that contains the token | `""`  |
| `existingSecretKey` | Secret key                     | `""`  |

### Gitea URL Setting

| Name           | Description                                      | Value |
| -------------- | ------------------------------------------------ | ----- |
| `giteaRootURL` | URL the Gitea Runner registers and connects with | `""`  |

### Extra Init Containers

| Name                      | Description                                                                                     | Value |
| ------------------------- | ----------------------------------------------------------------------------------------------- | ----- |
| `preExtraInitContainers`  | Additional init containers to run in the pod before Gitea-actions runs it owns init containers. | `[]`  |
| `postExtraInitContainers` | Additional init containers to run in the pod after Gitea-actions runs it owns init containers.  | `[]`  |

### Global

| Name                      | Description                        | Value |
| ------------------------- | ---------------------------------- | ----- |
| `global.imageRegistry`    | global image registry override     | `""`  |
| `global.imagePullSecrets` | global image registry pull secrets | `[]`  |
| `global.storageClass`     | global storage class override      | `""`  |
