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

The chart renders a MachineHealthCheck for the control plane and one per HCloud node group. When a node stays
NotReady (`Ready` is `False` or `Unknown`) for longer than the timeout, its Machine is marked unhealthy and
replaced.

The control-plane timeout is set with `controlPlane.machineHealthCheck.unhealthyTimeoutSeconds`. Left at `null`,
it is 600 seconds in `mode: bare-metal` and 180 seconds in `hcloud` and `hybrid`. Replacing a bare-metal control
plane reinstalls the server, and a plain reboot of a dedicated server (firmware POST plus OS boot) often takes
longer than 3 minutes, so the bare-metal default is longer. Set a value to override it in any mode:

```yaml
controlPlane:
  machineHealthCheck:
    unhealthyTimeoutSeconds: 900
```

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
