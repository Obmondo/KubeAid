<!--
SPDX-FileCopyrightText: 2023 Bundesministerium des Innern und für Heimat, PG ZenDiS "Projektgruppe für Aufbau ZenDiS"

SPDX-License-Identifier: Apache-2.0
-->
# coturn

A Helm chart for running coturn

## Installing the Chart

To install the chart with the release name `my-release`:

```console
helm repo add opendesk-coturn https://gitlab.opencode.de/api/v4/projects/1383/packages/helm/stable
helm install my-release opendesk-coturn/coturn
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | common | ^2.x.x |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity for pod assignment Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity Note: podAffinityPreset, podAntiAffinityPreset, and  nodeAffinityPreset will be ignored when it's set |
| autoscaling.enabled | bool | `false` | Enable Horizontal Pod Autoscaling |
| autoscaling.maxReplicas | int | `100` | Maximum amount of Replicas |
| autoscaling.minReplicas | int | `1` | Minimum amount of Replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | set the CPU Utilization Percentage |
| autoscaling.targetMemoryUtilizationPercentage | int | `80` | set the Memory Utilization Percentage |
| certificate.request.enabled | bool | `true` | enable the request of the certificate |
| certificate.request.issuerRef.kind | string | `"ClusterIssuer"` | We can reference ClusterIssuers by changing the kind here. The default value is Issuer (i.e. a locally namespaced Issuer) |
| certificate.request.issuerRef.name | string | `"letsencrypt-prod"` | name of the isuerRef |
| certificate.secretName | string | `""` |  |
| cleanup.keepCertificateOnDelete | bool | `true` | keep TLS Certificate on delete |
| cleanup.keepServiceOnDelete | bool | `true` | Keep Service on delete (to keep LoadBalancer IP) |
| commonAnnotations | object | `{}` | Additional custom annotations to add to all deployed objects. |
| commonLabels | object | `{}` | Additional custom labels to add to all deployed objects. |
| containerSecurityContext.allowPrivilegeEscalation | bool | `false` | Enable container privileged escalation. |
| containerSecurityContext.capabilities | object | `{"drop":["ALL"]}` | Security capabilities for container. |
| containerSecurityContext.enabled | bool | `true` | Enable security context. |
| containerSecurityContext.readOnlyRootFilesystem | bool | `true` | Mounts the container's root filesystem as read-only. |
| containerSecurityContext.runAsGroup | int | `65534` | Process group id. |
| containerSecurityContext.runAsNonRoot | bool | `true` | Run container as user. |
| containerSecurityContext.runAsUser | int | `65534` | Process user id. |
| containerSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` | Disallow custom Seccomp profile by setting it to RuntimeDefault. |
| coturn.authentication.password | string | `nil` | specify password for user |
| coturn.authentication.secret | string | `nil` | specify static-auth-secret don't use user/password when set! |
| coturn.authentication.user | string | `nil` | specify user and password instead of a secret don't sepcify a secret when user/password is set! |
| coturn.externalIP | string | `nil` |  |
| coturn.listeningPort | int | `3478` | listening Port (TCP & UDP) |
| coturn.maxPort | int | `65535` | upper bound of the UDP relay endpoints |
| coturn.minPort | int | `49152` | lower bound of the UDP relay endpoints |
| coturn.prometheus | bool | `true` | activate prometheus |
| coturn.realm | string | `"turn.develop.souvap-univention.de"` | realm |
| coturn.serverName | string | `nil` | server name, defaults to realm |
| coturn.tls.enabled | bool | `true` | enable TLS |
| coturn.tls.listeningPort | int | `5349` | TLS Port (TCP & UDP) |
| coturn.verbose | bool | `false` | be verbose |
| extraEnvVars | list | `[]` | Array with extra environment variables to add to containers.  extraEnvVars:   - name: FOO     value: "bar"  |
| extraVolumeMounts | list | `[]` | Optionally specify extra list of additional volumeMounts. |
| extraVolumes | list | `[]` | Optionally specify extra list of additional volumes |
| fullnameOverride | string | `""` | Provide a name to substitute for the full names of resources. |
| global.imagePullSecrets | list | `[]` | Credentials to fetch images from private registry Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/  imagePullSecrets:   - "docker-registry"  |
| global.registry | string | `"docker.io"` | Container registry address. |
| image.imagePullPolicy | string | `"IfNotPresent"` | Define an ImagePullPolicy.  Ref.: https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy  "IfNotPresent" => The image is pulled only if it is not already present locally. "Always" => Every time the kubelet launches a container, the kubelet queries the container image registry to             resolve the name to an image digest. If the kubelet has a container image with that exact digest cached             locally, the kubelet uses its cached image; otherwise, the kubelet pulls the image with the resolved             digest, and uses that image to launch the container. "Never" => The kubelet does not try fetching the image. If the image is somehow already present locally, the            kubelet attempts to start the container; otherwise, startup fails  |
| image.registry | string | `"dockeri.io"` | Container registry address. This setting has higher precedence than global.registry. |
| image.repository | string | `"coturn/coturn"` | Container repository string. |
| image.tag | string | `"4.6.2-alpine@sha256:cecbd85f5b27ce5bf00901192c9fe565c4be631f285411e5625427372a3a2f8b"` |  |
| imagePullSecrets | list | `[]` | Credentials to fetch images from private registry Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/  imagePullSecrets:   - "docker-registry"  |
| lifecycleHooks | object | `{}` | Lifecycle to automate configuration before or after startup |
| livenessProbe.enabled | bool | `true` | Enables kubernetes LivenessProbe. |
| livenessProbe.failureThreshold | int | `10` | Number of failed executions until container is terminated. |
| livenessProbe.initialDelaySeconds | int | `15` | Delay after container start until LivenessProbe is executed. |
| livenessProbe.periodSeconds | int | `20` | Time between probe executions. |
| livenessProbe.successThreshold | int | `1` | Number of successful executions after failed ones until container is marked healthy. |
| livenessProbe.timeoutSeconds | int | `5` | Timeout for command return. |
| nameOverride | string | `""` | String to partially override release name. |
| nodeSelector | object | `{}` | Node labels for pod assignment Ref: https://kubernetes.io/docs/user-guide/node-selection/ |
| podAnnotations | object | `{}` | Pod Annotations. Ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podLabels | object | `{}` | Pod Labels. Ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext.enabled | bool | `true` | Enable security context. |
| podSecurityContext.fsGroup | int | `65534` | If specified, all processes of the container are also part of the supplementary group |
| podSecurityContext.fsGroupChangePolicy | string | `"Always"` | Change ownership and permission of the volume before being exposed inside a Pod. |
| readinessProbe.enabled | bool | `true` | Enables kubernetes ReadinessProbe. |
| readinessProbe.failureThreshold | int | `10` | Number of failed executions until container is terminated. |
| readinessProbe.initialDelaySeconds | int | `15` | Delay after container start until ReadinessProbe is executed. |
| readinessProbe.periodSeconds | int | `20` | Time between probe executions. |
| readinessProbe.successThreshold | int | `1` | Number of successful executions after failed ones until container is marked healthy. |
| readinessProbe.timeoutSeconds | int | `5` | Timeout for command return. |
| replicaCount | int | `1` | Set the amount of replicas of deployment. |
| resources.limits.cpu | int | `4` | The max amount of CPUs to consume. |
| resources.limits.memory | string | `"4Gi"` | The max amount of RAM to consume. |
| resources.requests.cpu | string | `"10m"` | The amount of CPUs which has to be available on the scheduled node. |
| resources.requests.memory | string | `"2Gi"` | The amount of RAM which has to be available on the scheduled node. |
| service.annotations | object | `{}` | Additional custom annotations |
| service.enabled | bool | `true` | Enable kubernetes service creation. |
| service.listeningNodePort | int | `3478` | to which NodePort is the external Listening Port fowarded? only needed if type is NodePort |
| service.minNodePort | int | `49152` | starting NodePort of the UDP Relay Endpoints only needed if type is NodePort |
| service.sessionAffinity.enabled | bool | `false` | Wether session affinity should be enabled |
| service.tlsListeningNodePort | int | `5349` | to which Node Port is the external TLS Listening Port forwarded? only needed if type is NodePort |
| service.type | string | `"LoadBalancer"` | How to expose coturn, choices can be LoadBalancer or NodePort |
| serviceAccount.annotations | object | `{}` | Additional custom annotations for the ServiceAccount. |
| serviceAccount.automountServiceAccountToken | bool | `true` | Allows auto mount of ServiceAccountToken on the serviceAccount created. Can be set to false if pods using this serviceAccount do not need to use K8s API. |
| serviceAccount.create | bool | `true` | Enable creation of ServiceAccount for pod. |
| serviceAccount.labels | object | `{}` | Additional custom labels for the ServiceAccount. |
| terminationGracePeriodSeconds | string | `""` | In seconds, time the given to the pod needs to terminate gracefully. Ref: https://kubernetes.io/docs/concepts/workloads/pods/pod/#termination-of-pods |
| tolerations | list | `[]` | Tolerations for pod assignment Ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/ |
| topologySpreadConstraints | list | `[]` | Topology spread constraints rely on node labels to identify the topology domain(s) that each Node is in Ref: https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/  topologySpreadConstraints:   - maxSkew: 1     topologyKey: failure-domain.beta.kubernetes.io/zone     whenUnsatisfiable: DoNotSchedule |
| updateStrategy.type | string | `"RollingUpdate"` | Set to Recreate if you use persistent volume that cannot be mounted by more than one pods to make sure the pods is destroyed first. |

## Making coturn available to the Internet

Currently, there are 2 options supported: `LoadBalanacer` and `NodePort`. Depending on your cluster/network setup, there might be also other options which are not described in this readme.

### Option 1: service of type `LoadBalancer`

This requires a cloud setup that enables a Loadbalancer attachement. This could be enabled via values:

```yaml
service:
  type: "LoadBalancer"

# all ports specified here will be available on the LoadBalancer:
coturn:
  # -- listening Port (TCP & UDP)
  listeningPort: 3478
  tls:
    # -- enable TLS
    enabled: true
    # -- TLS Port (TCP & UDP)
    listeningPort: 5349
  # -- lower bound of the UDP relay endpoints
  minPort: 49152
  # -- upper bound of the UDP relay endpoints
  maxPort: 65535
```

### Option 2: NodePort with NAT (Network Address Translation) and PAT (Port Address Translation)

This setup requires an external firewall or loadbalancer with a public IP and port translation from the specified ports on the external IP to the corresponding NodePorts on the internal Node IPs.

```yaml
service:
  type: "NodePort"
  # -- to which NodePort is the external Listening Port fowarded?
  # only needed if type is NodePort
  listeningNodePort: 31478
  # -- to which Node Port is the external TLS Listening Port forwarded?
  # only needed if type is NodePort
  tlsListeningNodePort: 31549
  # -- starting NodePort of the UDP Relay Endpoints
  # only needed if type is NodePort
  minNodePort: 30500

# all ports specified here will be available on corresponding NodePort:
coturn:
  # -- listening Port (TCP & UDP)
  listeningPort: 3478
  tls:
    # -- enable TLS
    enabled: true
    # -- TLS Port (TCP & UDP)
    listeningPort: 5349
  # -- lower bound of the UDP relay endpoints
  minPort: 30500
  # -- upper bound of the UDP relay endpoints
  maxPort: 30550
```

## Uninstalling the Chart

To install the release with name `my-release`:

```bash
helm uninstall my-release
```

## Signing

Helm charts are signed with helm native signing method.

You can verify the chart against [the public GPG key](../../files/gpg-pubkeys/opendesk.gpg).

## License

This project uses the following license: Apache-2.0

## Copyright

Copyright (C) 2023 Bundesministerium des Innern und für Heimat, PG ZenDiS "Projektgruppe für Aufbau ZenDiS"
