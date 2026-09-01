# Pre-Configuration

This step covers generating and configuring the `general.yaml` and `secrets.yaml` files required for cluster setup.
The configuration process is **the same across all providers** - only some field values differ.

## Overview

KubeAid uses two configuration files:

| File | Contains | Storage |
| ------ | ---------- | --------- |
| `general.yaml` | Cluster specs, node configs, networking settings | Version-controlled in `kubeaid-config` repo |
| `secrets.yaml` | Credentials for cloud providers and Git | **Store in password manager** (e.g., [pass](https://www.passwordstore.org/)) |

> **Tip:** If you want to be able to recreate this cluster setup after it has been deleted,
> you must save `general.yaml` to your kubeaid-config repository.
> **Important:** Always save your `secrets.yaml` in a secure password store for easy recovery. Never commit secrets to Git.

## Step 1: Generate Configuration Files

Run the config generate command:

```bash
kubeaid-cli config generate
```

There is no provider argument - the command walks you through an **interactive prompt** that asks which provider
you're deploying to (AWS, Azure, Hetzner, bare metal or local) and then collects everything required for it:
cluster basics, provider credentials, Git / KubeAid fork URLs, and so on. It writes the resulting `general.yaml`
and `secrets.yaml` under `~/.config/kubeaid-cli/<cluster>/configs/`.

> **Note:** Follow-up commands use that config automatically while it is your only saved cluster; once you
> manage several, pass `--cluster-name <cluster>` to say which one. To write and read the config somewhere else
> entirely, pass `--configs-directory <path>` to both `config generate` and the follow-up commands.

### Generated Directory Structure

After running the config generate command:

```bash
~/.config/kubeaid-cli/
└── <cluster>/
    └── configs/
        ├── general.yaml  # Cluster configuration (review this)
        └── secrets.yaml  # Credentials (review this, store in password manager)
```

Bootstrap outputs land in the same per-cluster directory:

```bash
~/.config/kubeaid-cli/
└── <cluster>/
    ├── configs/              # general.yaml, secrets.yaml
    ├── kubeconfigs/
    │   └── main.yaml         # Kubeconfig for your cluster (after bootstrap)
    └── logs/                 # One timestamped log file per run
```

(With an explicit `--configs-directory`, everything — config files and outputs alike — lives in that
directory instead; the per-user tree above is only used when you don't pass the flag.)

## Step 2: Review general.yaml

The `general.yaml` file defines your cluster's infrastructure. The interactive prompt fills in everything required -
hand-edit only when you want to override defaults. The authoritative field reference (all providers, all fields) is
the generated [config reference](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/config-reference.md).

### Common Configuration (All Providers)

```yaml
# Git server SSH access.
# Exactly one of privateKeyFilePath / useSSHAgent must be set.
git:
  sshUsername: git
  privateKeyFilePath: /home/you/.ssh/id_ed25519
  # useSSHAgent: true

# Repository fork URLs (SSH URLs; both must be hosted on the same Git server).
forkURLs:
  kubeaid:
    url: git@github.com:<your-org>/KubeAid
    version: <tag / branch / commit>   # optional: pin the KubeAid version
  kubeaidConfig:
    url: git@github.com:<your-org>/kubeaid-config

# Cluster specification
cluster:
  name: my-cluster              # Unique cluster name (no dots allowed)
  k8sVersion: v1.34.0           # Kubernetes version

  # ArgoCD deploy keys (SSH). Each takes privateKeyFilePath or useSSHAgent,
  # exactly like the git section above.
  argoCD:
    deployKeys:
      kubeaid:
        useSSHAgent: true
      kubeaidConfig:
        useSSHAgent: true
```

> **Note on Kubernetes versions:** supported ranges differ per provider. Cluster API clouds (AWS, Azure, Hetzner)
> support v1.30 up to the latest released (non-EOL) version; bare metal (KubeOne) supports **v1.33 - v1.35** only;
> EKS requires >= v1.33.

### Provider-Specific Configuration

The `cloud` section differs by provider - exactly one of `cloud.aws`, `cloud.azure`, `cloud.hetzner`,
`cloud.bare-metal` (note the hyphen; Hetzner's *nested* bare-metal key is spelled `bareMetal`) or `cloud.local`
is set. The interactive prompt generates the correct section for your provider; the samples below only highlight
the key fields. For the full per-provider schema, see the
[config reference](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/config-reference.md).

#### AWS

```yaml
cloud:
  aws:
    region: eu-central-1         # Frankfurt; change to your preferred region
    sshKeyName: kubeaid-demo     # Name of your AWS SSH keypair
    controlPlane:
      instanceType: t3.medium
      replicas: 3
      ami:
        id: <ami-id>
    nodeGroups:
      - name: workers
        instanceType: t3.large
        rootVolumeSize: 35
        cpu: 2
        memory: 8
        minSize: 1
        maxSize: 10
```

#### AWS EKS (managed control plane)

Set `eks: true` to get an AWS managed (EKS) control plane instead of the
self-managed EC2 one. AWS runs the control plane multi-AZ, CAPA resolves the
EKS optimized AL2023 worker AMIs itself, and workers stay keyless — so
`controlPlane`, `sshKeyName` and per-node-group AMIs must be left unset.
Requires Kubernetes >= v1.33.

```yaml
cloud:
  aws:
    region: eu-central-1
    eks: true
    bastionEnabled: true
    nodeGroups:
      - name: default
        minSize: 3
        maxSize: 6
        cpu: 4
        memory: 8
        instanceType: c6i.xlarge
        rootVolumeSize: 35
```

> **Note:** `cluster upgrade` doesn't apply to EKS clusters — bump
> `global.kubernetes.version` in `argocd-apps/values-capi-cluster.yaml` in your
> kubeaid-config repo and let ArgoCD sync; CAPA then upgrades the control plane
> and rolls the node-groups.

#### Azure

The `cloud.azure` section takes `tenantID`, `subscriptionID` and `location`, plus a `controlPlane` and `nodeGroups`
(each node group with `vmSize`, `diskSizeGB`, `cpu`, `memory`, `minSize`, `maxSize`). Self-managed clusters
additionally need the SSH public key and workload-identity settings described in
[Prerequisites](./prerequisites.md) - see the
[config reference](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/config-reference.md) for the full schema.

#### Azure AKS (managed control plane)

Set `aks: true` to get an Azure managed (AKS) control plane instead of the
self-managed VM one. Azure owns the control plane, the node images and the
agent-pool autoscaling, and CAPZ authenticates with your AAD service principal
directly — so `controlPlane`, `sshPublicKey`, `canonicalUbuntuImage`,
`storageAccount`, `workloadIdentity` and `aadApplication` must all be left
unset. Node-groups become AKS agent pools: the first one is the required
`System` pool, and names must be 1-12 lowercase alphanumeric characters
starting with a letter.

```yaml
cloud:
  azure:
    tenantID: <tenant-id>
    subscriptionID: <subscription-id>
    location: westeurope
    aks: true
    nodeGroups:
      - name: default
        minSize: 3
        maxSize: 6
        cpu: 4
        memory: 8
        vmSize: Standard_F4s_v2
        diskSizeGB: 128
```

> **Note:** Register the `KubeProxyConfigurationPreview` feature on your
> subscription before bootstrapping (see [Prerequisites](./prerequisites.md)) —
> KubeAid disables AKS's kube-proxy and runs Cilium with kube-proxy
> replacement. Like EKS, `cluster upgrade` doesn't apply: bump
> `global.kubernetes.version` in `argocd-apps/values-capi-cluster.yaml` and let
> ArgoCD sync.

#### Hetzner

The `cloud.hetzner` section supports three modes via `mode: hcloud | bare-metal | hybrid`. All modes share a
Hetzner `sshKeyPair`; HCloud clusters add `hcloud` (zone, image, control plane machine type, node groups), while
Hetzner bare-metal clusters add the **nested** `bareMetal` key (camelCase - only the *top-level* SSH-only provider
key `cloud.bare-metal` is hyphenated) with per-host settings such as `wipeDisks`. The interactive prompt
collects all of this; see the
[config reference](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/config-reference.md) for the full schema.

> **Note:** HCloud storage only allows a maximum of 16 buckets per physical node. Plan your PV usage accordingly
> to avoid running out of PVs before node resources are exhausted.

#### Bare Metal (SSH-only)

SSH-only bare metal clusters (provisioned via KubeOne) live under the top-level `cloud.bare-metal` key (note the
hyphen). The interactive prompt collects the control-plane and node-group host addresses and SSH settings; see
the [config reference](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/config-reference.md) for the full
schema. KubeOne supports Kubernetes **v1.33 - v1.35** only.

> **Note:** Host addresses should come from a valid private IP range (RFC 1918), e.g. `10.0.0.0/8`,
> `172.16.0.0/12` or `192.168.0.0/16`. These addresses are for **internal cluster communication** and should not
> be publicly routable.

#### Local K3D

```yaml
cloud:
  local: {}
```

## Step 3: Review secrets.yaml

The `secrets.yaml` file contains sensitive credentials. **Do not commit this file to Git.**

The interactive prompt fills this file in for you. Its only top-level keys are `aws`, `azure`, `hetzner`,
`keycloak`, `netbird` and `acme`. There are **no Git credentials** here (Git access is SSH-only, configured in
`general.yaml`) and **no ArgoCD admin password** (that is generated in-cluster - see
[Post-Configuration](./post-configuration.md)).

### Provider-Specific Secrets

#### AWS Secrets

```yaml
aws:
  accessKeyID: <aws-access-key>
  secretAccessKey: <aws-secret-key>
  sessionToken: <session-token>         # Only when using temporary credentials
```

#### Azure Secrets

```yaml
azure:
  clientID: <service-principal-client-id>
  clientSecret: <service-principal-secret>
```

#### Hetzner credentials

```yaml
hetzner:
  apiToken: <hcloud-api-token>
  robot:                                # For bare metal only
    user: <robot-username>
    password: <robot-password>
```

#### Keycloak / NetBird / ACME (VPN-type clusters)

The `keycloak`, `netbird` and `acme` keys hold secrets for VPN-type clusters (`cluster.type: vpn`). Values left
blank are auto-generated on first run where possible. See the
[config reference](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/config-reference.md) for details.

> **Note:** Bare metal (SSH-only) clusters need no `secrets.yaml` entries - node access uses the SSH key or
> SSH agent configured in `general.yaml`.

## Step 4: Validate Configuration

Before proceeding, verify your configuration:

1. **Check file locations:**

   ```bash
   ls -la ~/.config/kubeaid-cli/<cluster>/configs/
   # Should show: general.yaml, secrets.yaml
   # Expected owner: your current user (or root if running as root)
   # Expected file mode: -rw------- (600) for secrets.yaml to protect credentials
   #                     -rw-r--r-- (644) is acceptable for general.yaml
   ```

2. **Validate YAML syntax:**

   ```bash
   yq eval '.' ~/.config/kubeaid-cli/<cluster>/configs/general.yaml > /dev/null && echo "general.yaml is valid"
   yq eval '.' ~/.config/kubeaid-cli/<cluster>/configs/secrets.yaml > /dev/null && echo "secrets.yaml is valid"
   ```

3. **Store secrets securely:**

   ```bash
   # Example using pass
   pass insert kubeaid/my-cluster/secrets.yaml < ~/.config/kubeaid-cli/<cluster>/configs/secrets.yaml
   ```
