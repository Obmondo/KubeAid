# linuxaid-agents

Runs [LinuxAid](https://github.com/Obmondo/linuxaid), Obmondo's OpenVox (Puppet) code for Linux
servers, on every node of a KubeAid cluster. You describe what the nodes should have (admin users,
SSH keys, sudo rules, files, systemd services) as hiera data in this chart's values, and each node is
checked against it on a schedule: report-only at first, enforced once you switch it on.

## Why it's in KubeAid

KubeAid creates and upgrades the nodes, but nothing manages their operating system after that: who
can log in, with which keys and with which rights. LinuxAid already does this for ordinary servers,
so this chart runs the same code on the nodes instead of adding another tool. There is no
puppetserver: each node compiles and applies its own catalog with `puppet apply` ("masterless").

## Terms used here

- **OpenVox**: the open-source fork of Puppet. A run compares the node with the desired state (the
  catalog) and reports or fixes the differences.
- **Control repo**: the git repository with the Puppet code and its default data, here LinuxAid.
- **Hiera**: Puppet's key-value data. A key such as `common::system::users` sets a parameter of a
  LinuxAid class.
- **Role**: the class that decides what a node gets. KubeAid nodes use `role::kubeaid`.
- **Report-only and enforce**: `puppet apply --noop` only reports what it would change; without
  `--noop` it changes the node.

## How it works

```text
operator Deployment                     one Job per node                  on the node
(unprivileged)                          (privileged, short-lived)
      |                                 |                                 |
      | at start, then every interval:  |                                 |
      |   list the nodes                |                                 |
      |   create one Job per node ----->| copy the binaries ------------->| /opt/obmondo/bin
      |     201: created, run starts    | install the client cert ------->| /etc/puppetlabs/puppet/ssl
      |     409: Job still exists,      | linuxaid-install --masterless ->| openvox-agent if missing,
      |          skip this node         |                                 |   server-less puppet.conf
      |                                 | clone the control repo -------->| /opt/obmondo/openvox/code
      |                                 | write the hiera values -------->| /opt/obmondo/openvox/data
      |                                 | linuxaid-cli run-openvox ------>| puppet apply
```

1. **The operator** is a small, unprivileged Deployment. When it starts, and then every `interval`
   (default `4h`), it lists the nodes and creates one Job per node, named `<release>-<node>`.
2. **One Job per node at a time.** While a node's Job exists (running, or finished less than
   `agentJob.ttlSecondsAfterFinished` ago, 10 minutes by default), creating it again returns 409
   and the operator skips that node until the next cycle. That is the only lock, which is why the
   operator is only allowed to `create` Jobs.
3. **The Job works on the host.** Its pod is privileged, sees the host's processes (`hostPID`) and
   uses `nsenter` to run commands on the node itself, because users and packages live on the host,
   not in a container. It tolerates every taint and is bound straight to its node, so it also runs
   on control-plane and cordoned nodes.
4. **The run.** The Job clones the control repo at `controlRepo.ref`, writes your `hiera` values
   next to it and runs `puppet apply`. With `enforce: false`, the default, Puppet only reports what
   it would change.
5. **Cleanup.** Kubernetes deletes the finished Job, and its logs, after
   `agentJob.ttlSecondsAfterFinished`.

## What gets managed

The default `hiera` values give every node one role and switch one thing off:

```yaml
hiera:
  classes:
    - role::kubeaid
  monitor::enable: false
```

- **`role::kubeaid`** is LinuxAid's role for KubeAid nodes. It applies what you add under `hiera`:
  users with their SSH keys, groups, files and systemd services (`common::system::*`), and, in
  LinuxAid releases after v1.8.8, sudo rules (`common::user_management::authentication`). It also
  applies some LinuxAid defaults, such as masking `smartd` and a few other services (the list
  depends on the OS), so read the first report-only runs before you enforce.
- **`monitor::enable: false`** turns off LinuxAid's host monitoring and, with it, the rest of
  LinuxAid's `common` class (the Obmondo package repository, ZFS, backups). KubeAid's own Prometheus
  already monitors the nodes.

Your `hiera` values are merged into these defaults, except `classes`, which replaces the role. They
are the highest-precedence hiera layer, so they win over the control repo's own data. Every node
gets the same values.

## Prerequisites

- **The `obmondo-clientcert` Secret** in the namespace you install into, with `tls.crt` and
  `tls.key` (`ca.crt` is optional). It is the client certificate Obmondo issues for the cluster;
  `kubeaid-cli` seals it into the `obmondo` namespace on clusters with `obmondo.monitoring` enabled
  (see [kubeaid-agent](../kubeaid-agent)). Set `certname` to its CN, for example
  `<cluster>.<customer-id>`. Every node uses that name, and the Jobs cannot start without the
  Secret.
- **Privileged pods allowed** in that namespace. The Jobs need `privileged`, `hostPID` and a
  `hostPath` volume, so Pod Security Admission must allow the `privileged` level there, and no
  Kyverno or Gatekeeper policy may block them.
- **A supported node OS**: Ubuntu 22.04, 24.04 or 26.04; RHEL, CentOS, Rocky or Oracle Linux; or
  SLES; on amd64 or arm64.
- **Network access**: the Job pods clone the control repo (github.com by default), a node without
  `openvox-agent` downloads it from `repos.obmondo.com`, and both images come from
  `ghcr.io/obmondo`, where they are public.

## Before you install: report-only still changes the node

`enforce: false` stops Puppet from changing what LinuxAid manages, but every run still prepares the
node:

- copies `linuxaid-cli` and `linuxaid-install` to `/opt/obmondo/bin`;
- installs the client certificate under `/etc/puppetlabs/puppet/ssl`;
- installs `openvox-agent` if it is missing, and overwrites `/etc/puppetlabs/puppet/puppet.conf`
  with a server-less one;
- writes `/etc/obmondo/opensource-mode`, so `linuxaid-cli` makes no calls to the Obmondo API;
- clones the control repo afresh and writes the hiera data under `/opt/obmondo/openvox`.

A few LinuxAid resources also apply in report-only runs, for example
`/etc/puppetlabs/facter/facts.d/obmondo_system.yaml` and, once sudo management is on, parts of the
sudo setup.

Do not install this chart on nodes that already run a LinuxAid agent against a puppetserver: every
run rewrites `puppet.conf` without the server.

## Install

Add an Argo CD Application to your kubeaid-config repository, at
`k8s/<cluster>/argocd-apps/templates/linuxaid-agents.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: linuxaid-agents
  namespace: argocd
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: obmondo
  project: kubeaid
  sources:
    - repoURL: https://github.com/Obmondo/KubeAid.git
      path: argocd-helm-charts/linuxaid-agents
      targetRevision: HEAD
      helm:
        valueFiles:
          - $values/k8s/<cluster>/argocd-apps/values-linuxaid-agents.yaml
    - repoURL: <your-config-repo>
      targetRevision: HEAD
      ref: values
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
```

and its values file, `k8s/<cluster>/argocd-apps/values-linuxaid-agents.yaml`:

```yaml
certname: <cluster>.<customer-id>
```

Commit, sync, and let the first runs finish in report-only mode.

## Check a run

```sh
kubectl -n obmondo get jobs -l app.kubernetes.io/name=linuxaid-agents
kubectl -n obmondo logs job/<job-name>
```

The log ends with Puppet's output. In a report-only run, lines ending in `(noop)` show what
`enforce: true` would change. A failed run leaves its Job `Failed`, and the node is tried again at
the next `interval`. Once the reports show only changes you want, set `enforce: true`.

When Argo CD syncs a values change, the operator restarts and starts a run straight away. Nodes
whose previous Job still exists are skipped, though, and wait for the next `interval`. To reach
them sooner, wait until their old Jobs are gone, then restart the operator:

```sh
kubectl -n obmondo rollout restart deploy/linuxaid-agents-operator
```

## Examples

### An admin user with SSH keys

```yaml
hiera:
  common::system::users:
    demo-admin:
      ssh_authorized_keys:
        - "ssh-ed25519 AAAAC3Nza… demo@example.com"
```

Every key needs its comment, the text after the key. LinuxAid removes keys that are not in this list
from the user's `authorized_keys`, so manage a dedicated user rather than an existing one such as
`ubuntu`.

### Passwordless sudo for that user

This needs a LinuxAid release after v1.8.8: set `controlRepo.ref` to one, or to `master` to try it.

```yaml
hiera:
  common::user_management::authentication::manage: true
  common::user_management::authentication::manage_sudo: true
  common::system::users:
    demo-admin:
      sudoroot: nopasswd
      ssh_authorized_keys:
        - "ssh-ed25519 AAAAC3Nza… demo@example.com"
```

With sudo management on, LinuxAid also manages `/etc/sudoers` itself.

### Skip the control-plane nodes

```yaml
nodeSelector: "!node-role.kubernetes.io/control-plane"
```

## Values

| Key | Default | Purpose |
| --- | --- | --- |
| `certname` | `""` | CN of the client certificate; every node uses it as its Puppet name. **Required**: the operator exits without it. |
| `enforce` | `false` | `false` = report-only (`puppet apply --noop`); `true` = apply changes. |
| `interval` | `4h` | How often the operator creates a Job per node, as a Go duration such as `30m`. |
| `controlRepo.url` | `https://github.com/Obmondo/linuxaid.git` | Control repo each node clones. |
| `controlRepo.ref` | the newest LinuxAid release | Tag or branch to check out. `bin/manage-helm-chart.sh` moves the default to each new release. Empty = the repo's newest tag on every run, so nodes move forward on their own. |
| `controlRepo.secretName` | `""` | Secret for a private control repo: key `ssh-privatekey` for SSH URLs, or `token` (a Gitea access token) for https URLs. |
| `openvoxEnvironment` | `""` | Name of the environment directory on the node. Empty = `controlRepo.ref` with dots as underscores (`v1.8.8` → `v1_8_8`), or `master` without a ref. It only names the directory: `controlRepo.ref` decides which code runs. With a ref, the name is also added to the hiera data as `common::system::openvox::environment`. |
| `hiera` | `classes: [role::kubeaid]`, `monitor::enable: false` | Hiera data for every node; see [What gets managed](#what-gets-managed). |
| `nodeSelector` | `""` | Label selector for the nodes to manage; empty = all nodes. |
| `obmondoClientCert.secretName` | `obmondo-clientcert` | Secret with the client certificate. |
| `agentJob.ttlSecondsAfterFinished` | `600` | Seconds a finished Job and its logs are kept; the node is skipped while it exists. |
| `agentJob.activeDeadlineSeconds` | `1200` | A run is stopped after this many seconds. |
| `agentJob.backoffLimit` | `0` | Retries within a cycle; a failed run is tried again at the next `interval`. |
| `operator.image.repository`, `operator.image.tag` | `ghcr.io/obmondo/linuxaid-agent`, the linuxaid-cli version the `controlRepo.ref` release names | Operator image. |
| `agentImage.repository`, `agentImage.tag` | `ghcr.io/obmondo/linuxaid-cli`, the same version | Image the Jobs run. Keep both tags on the same linuxaid-cli release. |
| `operator.image.pullPolicy`, `agentImage.pullPolicy` | `IfNotPresent` | Image pull policies. |
| `operator.resources` | 10m CPU and 32Mi memory requested, 64Mi memory limit | Operator resources. |

## Good to know

- **One identity for all nodes.** All nodes share `certname` and the same hiera data, so this chart
  cannot give one node different settings.
- **No central reporting.** Results are only in the Job logs, which are deleted with the Job.
- **Uninstalling only stops future runs.** Changes already applied to the nodes stay.
