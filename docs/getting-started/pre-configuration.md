# Pre-Configuration

This step covers generating and configuring the `general.yaml` and `secrets.yaml` files required for cluster setup. The configuration process is **the same across all providers**-only some field values differ.

## Overview

KubeAid uses two configuration files:

| File | Contains | Storage |
|------|----------|---------|
| `general.yaml` | Cluster specs, node configs, networking settings | Version-controlled in `kubeaid-config` repo |
| `secrets.yaml` | Credentials for cloud providers and Git | **Store in password manager** (e.g., [pass](https://www.passwordstore.org/)) |

> [!TIP]
> If you want to be able to recreate this cluster setup after it has been deleted, you must save `general.yaml` to your kubeaid-config repository.

> [!CAUTION]
> Always save your `secrets.yaml` in a secure password store for easy recovery. Never commit secrets to Git.

## Step 1: Generate Configuration Files

Run the config generate command with your provider type:

```bash
kubeaid-cli config generate <provider>
```

Replace `<provider>` with one of:

| Provider | Command |
|----------|---------|
| AWS | `kubeaid-cli config generate aws` |
| Azure | `kubeaid-cli config generate azure` |
| Hetzner HCloud | `kubeaid-cli config generate hetzner hcloud` |
| Hetzner Bare Metal | `kubeaid-cli config generate hetzner bare-metal` |
| Hetzner Hybrid | `kubeaid-cli config generate hetzner hybrid` |
| Bare Metal (SSH-only) | `kubeaid-cli config generate bare-metal` |
| Local K3D | `kubeaid-cli config generate local` |

The generated templates are saved in `outputs/configs/`.

#### Generated Directory Structure

After running the config generate command, your working directory will look like:

```bash
your-working-directory/
├── outputs/
│   ├── configs/
│   │   ├── general.yaml      # Cluster configuration (edit this)
│   │   └── secrets.yaml      # Credentials (edit this, store in password manager)
│   ├── kubeconfigs/          # Generated after bootstrap
│   │   └── main.yaml         # Kubeconfig for your cluster
│   └── .log                  # Bootstrap logs
└── ...
```

## Step 2: Configure general.yaml

The `general.yaml` file defines your cluster's infrastructure. Most fields are **common across all providers**.

### Common Configuration (All Providers)

```yaml
# Repository URLs
forkURLs:
  kubeaid: https://github.com/<your-org>/KubeAid
  kubeaidConfig: https://github.com/<your-org>/kubeaid-config

# Cluster specification
cluster:
  name: my-cluster              # Unique cluster name
  k8sVersion: v1.31.0           # Kubernetes version
  kubeaidVersion: 18.0.0        # KubeAid version

# Git configuration
git:
  useSSHAgentAuth: false
  useSSHPrivateKeyAuth: false

# ArgoCD configuration
argocd:
  useSSHPrivateKeyAuth: false
  kubeaidURL: https://github.com/<your-org>/KubeAid
  kubeaidConfigURL: https://github.com/<your-org>/kubeaid-config
```

### Provider-Specific Configuration

The `cloud` section differs by provider. Please refer to your provider's configuration guide for details:

- [AWS Configuration](../providers/aws/configuration.md)
- [Azure Configuration](../providers/azure/configuration.md)
- [Hetzner Configuration](../providers/hetzner/configuration.md)
  - Covers HCloud, Bare Metal, and Hybrid
- [Bare Metal (SSH-only) Configuration](../providers/bare-metal/configuration.md)
- [Local K3D Configuration](../providers/local-k3d/configuration.md)

## Step 3: Configure secrets.yaml

The `secrets.yaml` file contains sensitive credentials. **Do not commit this file to Git.**

### Common Secrets (All Providers)

```yaml
# Git credentials for ArgoCD
git:
  username: <git-username>
  password: <personal-access-token>

# Docker registry (optional)
dockerRegistry:
  username: ""
  password: ""

# ArgoCD admin password
argocd:
  admin:
    password: <strong-password>
```

### Provider-Specific Secrets

Refer to the **Configuration** links above for your specific provider's `secrets.yaml` requirements.

## Step 4: Validate Configuration

Before proceeding, verify your configuration:

1. **Check file locations:**
   ```bash
   ls -la outputs/configs/
   # Should show: general.yaml, secrets.yaml
   # Expected owner: your current user (or root if running as root)
   # Expected file mode: -rw------- (600) for secrets.yaml to protect credentials
   #                     -rw-r--r-- (644) is acceptable for general.yaml
   ```

2. **Validate YAML syntax:**
   ```bash
   yq eval '.' outputs/configs/general.yaml > /dev/null && echo "general.yaml is valid"
   yq eval '.' outputs/configs/secrets.yaml > /dev/null && echo "secrets.yaml is valid"
   ```

3. **Store secrets securely:**
   ```bash
   # Example using pass
   pass insert kubeaid/my-cluster/secrets.yaml < outputs/configs/secrets.yaml
   ```
