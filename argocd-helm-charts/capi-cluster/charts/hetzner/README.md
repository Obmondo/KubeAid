# Hetzner Cluster API Helm Chart

This Helm chart provides templates for creating a Kubernetes cluster using the Cluster API Provider for Hetzner (CAPH).

## Prerequisites

- Kubernetes cluster with Cluster API installed
- Helm 3
- Hetzner cloud account with API token
- For baremetal machines, a Hetzner Robot account with SSH keys configured

## Installation

```bash
# Create a secret with your Hetzner credentials
kubectl create secret generic hetzner \
  --from-literal=hcloud=<YOUR_HCLOUD_TOKEN> \
  --from-literal=robot-user=<YOUR_ROBOT_USER> \
  --from-literal=robot-password=<YOUR_ROBOT_PASSWORD>

# For baremetal machines, create an SSH key secret
kubectl create secret generic robot-ssh \
  --from-literal=sshkey-name=<SSH_KEY_NAME> \
  --from-literal=ssh-publickey="$(cat ~/.ssh/id_rsa.pub)" \
  --from-literal=ssh-privatekey="$(cat ~/.ssh/id_rsa)"

# Install the chart
helm install my-cluster ./hetzner-cluster-helm --values values.yaml
```

## Configuration

The following table lists the configurable parameters of the chart and their default values.

| Parameter                                            | Description                                              | Default                                                         |
| ---------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------- |
| `clusterName`                                        | Name of the Kubernetes cluster                           | `kubeaid-demo-hetzner-robot`                                    |
| `imageName`                                          | OS image name to use for nodes                           | `ubuntu-24.04`                                                  |
| `controlPlaneType`                                   | Type of control plane machines (`baremetal` or `hcloud`) | `baremetal`                                                     |
| `controlPlaneMachineCount`                           | Number of control plane nodes                            | `3`                                                             |
| `controlPlaneMachineType`                            | Machine type for control plane nodes                     | `cax41`                                                         |
| `workerMachineType`                                  | Machine type for worker nodes                            | `cax41`                                                         |
| `workerMachineCount.baremetal`                       | Number of baremetal worker nodes                         | `0`                                                             |
| `workerMachineCount.hcloud`                          | Number of Hetzner Cloud worker nodes                     | `0`                                                             |
| `includeWorker.hcloud`                               | Enable Hetzner Cloud worker nodes                        | `false`                                                         |
| `includeWorker.baremetal`                            | Enable baremetal worker nodes                            | `true`                                                          |
| `remediation.enabled.hcloud`                         | Enable remediation for Hetzner Cloud machines            | `true`                                                          |
| `remediation.enabled.baremetal`                      | Enable remediation for baremetal machines                | `true`                                                          |
| `remediation.hcloud.controlPlane.retryLimit`         | Retry limit for Hetzner Cloud control plane remediation  | `1`                                                             |
| `remediation.hcloud.controlPlane.timeout`            | Timeout for Hetzner Cloud control plane remediation      | `180s`                                                          |
| `remediation.hcloud.controlPlane.type`               | Type of remediation for Hetzner Cloud control plane      | `Reboot`                                                        |
| `remediation.hcloud.controlPlane.maxUnhealthy`       | Maximum percentage of unhealthy nodes allowed            | `100%`                                                          |
| `remediation.hcloud.controlPlane.nodeStartupTimeout` | Timeout for node startup after remediation               | `15m`                                                           |
| `remediation.hcloud.worker`                          | Remediation settings for Hetzner Cloud worker nodes      | See values.yaml                                                 |
| `remediation.baremetal.controlPlane`                 | Remediation settings for baremetal control plane nodes   | See values.yaml                                                 |
| `remediation.baremetal.worker`                       | Remediation settings for baremetal worker nodes          | See values.yaml                                                 |
| `baremetalHosts.WithRaid`                            | List of baremetal servers with RAID configuration        | See values.yaml                                                 |
| `baremetalHosts.WithRaid[].serverID`                 | Hetzner Robot server ID                                  |                                                                 |
| `baremetalHosts.WithRaid[].role`                     | Role of the server (control-plane/worker)                |                                                                 |
| `baremetalHosts.WithRaid[].description`              | Description of the server                                |                                                                 |
| `baremetalHosts.WithRaid[].wwn`                      | World Wide Names of the server's disks                   |                                                                 |
| `installImage.controlPlane.imagePath`                | Path to OS installation image for control plane          | `/root/.oldroot/nfs/images/Ubuntu-2204-jammy-amd64-base.tar.gz` |
| `installImage.controlPlane.rootPartitionSize`        | Root partition size for control plane                    | `all`                                                           |
| `installImage.controlPlane.swRaid`                   | Software RAID level for control plane                    | `1`                                                             |
| `installImage.worker`                                | Installation settings for worker nodes                   | See values.yaml                                                 |
| `ssh.keyName`                                        | Name of SSH key in Hetzner Cloud console                 | `cluster`                                                       |
| `ssh.robotRescueSecretKey.name`                      | Key name in the secret for SSH key name                  | `sshkey-name`                                                   |
| `ssh.robotRescueSecretKey.privateKey`                | Key name in the secret for SSH private key               | `ssh-privatekey`                                                |
| `ssh.robotRescueSecretKey.publicKey`                 | Key name in the secret for SSH public key                | `ssh-publickey`                                                 |
| `ssh.robotRescueSecretName`                          | Name of the secret containing SSH keys                   | `robot-ssh`                                                     |
| `hcloudRegion`                                       | Hetzner Cloud region                                     | `hel1`                                                          |
| `hetznerSecretName`                                  | Name of the secret containing Hetzner credentials        | `hetzner`                                                       |
| `hetznerSecretKey.hcloudToken`                       | Key name in the secret for Hetzner Cloud token           | `hcloud`                                                        |
| `hetznerSecretKey.hetznerRobotPassword`              | Key name in the secret for Hetzner Robot password        | `robot-password`                                                |
| `hetznerSecretKey.hetznerRobotUser`                  | Key name in the secret for Hetzner Robot username        | `robot-user`                                                    |

## Usage

This chart supports deploying clusters with both Hetzner Cloud (HCloud) and Hetzner Baremetal (Robot) servers. You can configure control plane and worker nodes separately for each provider.

### Baremetal Nodes

For baremetal nodes, you need to specify the server IDs, roles, and hardware information in the `baremetalHosts` section. The chart supports servers with and without RAID configuration.

### Hetzner Cloud Nodes

To use Hetzner Cloud nodes, set `controlPlaneType: hcloud` and/or `includeWorker.hcloud: true` and configure the appropriate machine types and counts.

### Node Remediation

The chart includes configuration for automatic remediation of unhealthy nodes. You can enable or disable remediation for each provider and node type, and configure parameters like retry limits, timeouts, and remediation types.

### Server type fallback

When Hetzner cannot create the configured server type in a region (the type is not offered there, is past its `unavailable_after` date, or is out of capacity), CAPH marks the HCloudMachine as failed for good, and the MachineHealthCheck replaces it with another Machine of the same type, which fails again. A control-plane node that dies at that moment is never replaced, and the cluster runs one failure away from losing etcd quorum.

With `machineTypeFallback.enabled: true`, new HCloud machines switch to the next server type you list when the configured one cannot be created:

```yaml
controlPlane:
  hcloud:
    machineType: cax21
    fallbackMachineTypes: [cax31, cax41]
nodeGroups:
  hcloud:
    - name: workers
      machineType: cpx32
      fallbackMachineTypes: [cpx42]
      # ...
machineTypeFallback:
  enabled: true
```

How it works:

- **Picker** (`files/machine-type-picker.sh`, a Deployment on a stock kubectl image): every minute it reads `GET /v1/server_types` with the HCloud token CAPH uses, and picks for each template the first listed type that is available in every region a Machine from it can land in. That is all `controlPlane.regions` for the control plane, because KCP creates the HCloudMachine before it picks a region; for a node group it is its `failureDomain`, or all regions. The picks go to the `<cluster>-machine-type-overrides` ConfigMap. A server that really failed to be created marks that type unusable in that region for `failureCooldownSeconds`, because the API's availability is only an indicator. Machines whose server was never created are deleted at once, so they are recreated on the new type without waiting for the MachineHealthCheck node startup timeout.
- **Kyverno MutatingPolicy**: when an HCloudMachine is created, it sets `spec.type` from the overrides ConfigMap and records the configured type in the `kubeaid.io/machine-type-requested` annotation. Existing machines are never changed, so nothing rolls. With `failurePolicy: Ignore`, a Kyverno outage only means the configured type is used.

Rules for the lists:

- A fallback must have the same CPU architecture as `machineType` (set `allowArchitectureChange: true` only if `hcloud.imageName` exists for both) and at least its cores, memory and disk. The node group's cluster-autoscaler capacity annotations are based on `machineType`.
- When the configured type can be created again, new machines go back to it. Machines already on a fallback type stay until they are replaced.
- A single control-plane node is not covered: KCP never replaces the only control-plane node.

Requirements: Kyverno with `policies.kyverno.io/v1` (KubeAid's `kyverno` app). The chart refuses to render with the feature on and no Kyverno. The picker records events on the `Cluster` object: `MachineTypeFallbackActive`, `MachineTypeFallbackCleared`, `MachineTypeFallbackNoCandidate` and `MachineTypeFallbackRetry`. Decision logic tests: `sh tests/machine-type-picker/run.sh`.

## Examples

### Baremetal-only Cluster

```yaml
controlPlaneType: baremetal
controlPlaneMachineCount: 3
includeWorker:
  hcloud: false
  baremetal: true
workerMachineCount:
  baremetal: 2
```

### Hybrid Cluster (Baremetal Control Plane, HCloud Workers)

```yaml
controlPlaneType: baremetal
controlPlaneMachineCount: 3
includeWorker:
  hcloud: true
  baremetal: false
workerMachineCount:
  hcloud: 3
```
