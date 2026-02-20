# Harbor Proxy Cache Kyverno Policies

This directory contains Kyverno ClusterPolicy resources that enable automatic Docker Hub proxy caching through Harbor.

## Policies

### 1. `harbor-proxy-cache-mutate.yaml`
**Purpose**: Automatically redirects `docker.io` and `registry-1.docker.io` images to Harbor proxy cache.

**What it does**:
- Mutates container images at admission time
- Transforms `docker.io/library/nginx:latest` → `<harbor-registry>/<harbor-project>/library/nginx:latest`
- Works for Pods, Deployments, StatefulSets, DaemonSets, Jobs, and CronJobs
- Handles both regular containers and init containers

### 2. `harbor-imagepullsecrets-inject.yaml`
**Purpose**: Automatically injects Harbor imagePullSecrets for pods pulling from Harbor.

**What it does**:
- Adds `imagePullSecrets` to pods using Harbor images
- Ensures authentication works for private/cached images
- Works automatically without manual configuration

**Prerequisites**: 
- A Secret named `harbor-proxy-cache` (or custom name) must exist in each namespace
- The secret should contain Harbor robot account credentials

### 3. `validate-approved-registries.yaml`
**Purpose**: Enforces that only approved registries can be used.

**What it does**:
- Blocks direct Docker Hub pulls (`docker.io`, `registry-1.docker.io`)
- Allows only approved registries (configurable via values)
- Can be set to `audit` or `enforce` mode

## Configuration

These policies are controlled via Helm values. Add the following to your Kyverno values file:

```yaml
harborProxyCache:
  enabled: true
  registry: "harbor.shared.az1.kilroy.eu"
  project: "dockerhub-cache"
  imagePullSecretName: "harbor-proxy-cache"
  mutateExistingOnPolicyUpdate: true
  
  validateApprovedRegistries:
    enabled: true
    action: "audit"  # or "enforce" to block violations
    approvedRegistries:
      - "acrkilroy.azurecr.io"
      - "ghcr.io"
      - "quay.io"
      - "registry.k8s.io"
```

### Configuration Options

- `harborProxyCache.enabled`: Enable/disable all Harbor proxy cache policies (default: `false`)
- `harborProxyCache.registry`: Harbor registry URL (required if enabled)
- `harborProxyCache.project`: Harbor project name for proxy cache (default: `dockerhub-cache`)
- `harborProxyCache.imagePullSecretName`: Name of the imagePullSecret to inject (default: `harbor-proxy-cache`)
- `harborProxyCache.mutateExistingOnPolicyUpdate`: Update existing resources when policy changes (default: `true` for imagePullSecrets, `false` for mutation)
- `harborProxyCache.validateApprovedRegistries.enabled`: Enable registry validation policy (default: `false`)
- `harborProxyCache.validateApprovedRegistries.action`: Validation action - `audit` or `enforce` (default: `audit`)
- `harborProxyCache.validateApprovedRegistries.approvedRegistries`: List of approved registries (required if validation enabled)

## Setup Instructions

1. **Create Harbor proxy cache project**:
   - Log into Harbor UI
   - Create a new Project → Type: "Proxy Cache"
   - Name: `dockerhub-cache` (or your custom name)
   - Upstream registry: `https://registry-1.docker.io`

2. **Create Harbor robot account**:
   - In Harbor, create a robot account with pull permissions for the proxy cache project
   - Download the robot account credentials

3. **Create imagePullSecret**:
   ```bash
   # Create secret in each namespace (or use a cluster-wide approach)
   kubectl create secret docker-registry harbor-proxy-cache \
     --docker-server=<harbor-registry> \
     --docker-username=<robot-account-name> \
     --docker-password=<robot-account-token> \
     -n <namespace>
   ```
   
   Or create a sealed secret and apply it via GitOps.

4. **Configure Kyverno values**:
   - Add the Harbor proxy cache configuration to your Kyverno values file
   - Ensure `harborProxyCache.enabled: true`
   - Set the appropriate registry, project, and approved registries

5. **Deploy via Argo CD**:
   - The policies will be automatically deployed when Kyverno is synced
   - Verify policies are created: `kubectl get clusterpolicies | grep harbor`

6. **Test the setup**:
   - Try deploying a pod with `image: docker.io/library/nginx:latest`
   - Kyverno should automatically mutate it to `<harbor-registry>/<harbor-project>/library/nginx:latest`
   - The pod should pull successfully from Harbor

## Policy Behavior

- **Mutation policies** (`harbor-proxy-cache-mutate`, `harbor-imagepullsecrets-inject`):
  - Run in `background: false` mode (immediate mutation)
  - `mutateExistingOnPolicyUpdate` is configurable per policy

- **Validation policy** (`validate-approved-registries`):
  - Uses configurable `validationFailureAction` (`audit` or `enforce`)
  - Set to `audit` for testing, then change to `enforce` for production

## Troubleshooting

- **Images not being mutated**: Check Kyverno logs and PolicyReport resources
- **Pull errors**: Verify Harbor proxy cache project exists and robot account has correct permissions
- **Policy not applying**: Ensure `harborProxyCache.enabled: true` in values and Kyverno is synced via Argo CD

## Customization

To customize the policies, modify the Helm values in your cluster-specific values file. The policies support:
- Custom Harbor registry URLs
- Custom project names
- Custom imagePullSecret names
- Configurable approved registries list
- Configurable validation enforcement mode

