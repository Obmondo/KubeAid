# Post-Configuration

After your cluster is bootstrapped, this guide covers verification, accessing services, and initial configuration.
These steps are **the same for all providers**.

## Step 1: Verify Cluster Health

### Check Cluster Status

```bash
export KUBECONFIG=./outputs/kubeconfigs/clusters/main.yaml

# Verify cluster info
kubectl cluster-info

# Check all nodes are ready
kubectl get nodes

# Check all system pods are running
kubectl get pods -A
```

### Expected Output

All nodes should show `Ready` status and all pods should be `Running` or `Completed`.

## Step 2: Access Dashboards

KubeAid deploys several web interfaces for managing and monitoring your cluster.

> **VPN-type clusters** (`cluster.type: vpn`, with NetBird/Keycloak): the public kube-apiserver load balancer is
> disabled after bootstrap and cluster access moves to the NetBird mesh. Follow the
> [post-bootstrap operator guide](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/post-bootstrap.md)
> instead of the generic kubeconfig flow on this page.

### ArgoCD Dashboard

ArgoCD provides GitOps-based application management.

```bash
# Get ArgoCD URL
kubectl get ingress -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Default credentials:**

- Username: `admin`
- Password: retrieved from the `argocd-initial-admin-secret` Kubernetes secret, as shown above

### Grafana Dashboard

Grafana provides monitoring dashboards powered by Prometheus.

```bash
# Get Grafana URL
kubectl get ingress -n monitoring

# Get admin password
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

### Prometheus

Access Prometheus directly for metrics and alerting configuration:

```bash
kubectl get ingress -n monitoring
```

## Step 3: Verify Core Components

### Check ArgoCD Applications

```bash
kubectl get applications -n argocd
```

All applications should show `Healthy` and `Synced` status.

### Check Cilium CNI

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system exec -it ds/cilium -- cilium status
```

### Check Sealed Secrets Controller

```bash
kubectl get pods -n kube-system -l name=sealed-secrets-controller
```

### Check Backup Health

If disaster recovery is configured, verify backup health (CNPG and Velero) as reported by backup-exporter:

```bash
kubeaid-cli backup status
```

See the [backup status guide](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/backup-status.md) for details.

## Step 4: Configure DNS (If Applicable)

If you're using custom domains for your cluster services, configure DNS records to point to your ingress load balancer:

```bash
# Get the external IP/hostname of your ingress (KubeAid deploys Traefik by default)
kubectl get svc -n traefik
```

Create DNS records (A or CNAME) for:

- `argocd.your-domain.com`
- `grafana.your-domain.com`
- `prometheus.your-domain.com`

## Step 5: Secret Management

KubeAid uses Sealed Secrets for secure secret management. Secrets are encrypted client-side and stored in Git.

### Create a Sealed Secret

```bash
# Create a regular secret
kubectl create secret generic my-secret \
  --from-literal=username=myuser \
  --from-literal=password=mypassword \
  --dry-run=client -o yaml > my-secret.yaml

# Seal the secret
kubeseal --format yaml < my-secret.yaml > my-sealed-secret.yaml

# Apply the sealed secret
kubectl apply -f my-sealed-secret.yaml
```

### Where Secrets Are Stored

Sealed secrets should be committed to your `kubeaid-config` repository:

```text
k8s/<cluster-name>/sealed-secrets/<namespace>/<secret-name>.json
```

## Step 6: Configure Updates

Obmondo publishes KubeAid feature and security updates as
[release tags](https://github.com/Obmondo/KubeAid/releases). How they reach you depends on which repository your
ArgoCD Applications point at:

- **The Obmondo repository directly** (the default): nothing to configure - new release tags are available as soon
  as they are published.
- **Your own fork**: pull upstream releases into it yourself:

  ```bash
  cd /path/to/your/kubeaid-fork
  git remote add upstream https://github.com/Obmondo/KubeAid.git
  git fetch upstream --tags
  git merge upstream/master
  git push origin master --tags
  ```

Either way, a new release tag changes nothing on the cluster by itself - your ArgoCD Applications pin the KubeAid
repository to a release tag. To roll an update out, bump that pinned tag; see
[Update KubeAid ArgoCD Apps](../operations/update-kubeaid-argocd-apps.md).

## Provider-Specific Notes

### Hetzner HCloud

> **Storage Limitation:** HCloud storage only allows a maximum of 16 buckets (PersistentVolumes) per physical node.
> Monitor PV usage to avoid exhausting storage before node resources.

### Azure

If using Azure Workload Identity, verify the webhook is functioning:

```bash
kubectl get pods -n azure-workload-identity-system
```

### AWS

Verify Kube2IAM is properly configured for pod IAM credentials:

```bash
kubectl get pods -n kube-system -l app=kube2iam
```

## Troubleshooting

### Common Issues

| Issue | Solution |
| ------- | ---------- |
| Nodes not ready | Check kubelet logs: `kubectl describe node <node-name>` |
| Pods stuck in Pending | Check for resource constraints: `kubectl describe pod <pod-name>` |
| ArgoCD apps not syncing | Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-application-controller` |
| Network issues | Check Cilium status: `kubectl -n kube-system exec -it ds/cilium -- cilium status` |

### Log Locations

- **Bootstrap logs:** `outputs/logs/` (one timestamped file per run)
- **Kubeconfig:** `outputs/kubeconfigs/clusters/main.yaml`
- **Configuration files:** `outputs/configs/<cluster>/` (or `~/.config/kubeaid-cli/<cluster>/configs/`)
