# Cluster Upgrade & Troubleshooting Guide

This guide covers how to upgrade Kubernetes versions on clusters managed via **Cluster API (CAPI)** and
**Managed Control Planes (EKS/AKS)** in KubeAid, along with troubleshooting steps for common upgrade roadblocks.

---

## 1. Overview & Scope

Cluster upgrades in KubeAid depend on your deployment architecture:

- **Self-Managed CAPI Clusters (Hetzner CAPH, AWS CAPA, Azure CAPZ):** Upgraded via the KubeAid CLI
by updating `cluster.k8sVersion` in `general.yaml`.
- **Managed Control Planes (AWS EKS, Azure AKS):** Upgraded via GitOps (`values-capi-cluster.yaml`) and synced through ArgoCD.

> **Warning:** Local K3D/single-host clusters do **not** support cluster upgrades or disaster recovery.

---

## 2. Pre-Upgrade Checklist

Before initiating any cluster upgrade:

1. **Verify Cluster Health**: Ensure all nodes are ready and system pods are running.

   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

2. **Check Backup Health**: Verify Velero and CloudNativePG backup status directly via Kubernetes:

   ```bash
   kubectl get backups.velero.io -A
   kubectl get clusters.postgresql.cnpg.io -A
   ```

3. **Review Release Notes**: Check the [Kubernetes release notes](https://kubernetes.io/releases/) for breaking changes
between your current and target version.

---

## 3. Step-by-Step Upgrade Workflow

### Method A: GitOps / ArgoCD-Managed CAPI Clusters (Hetzner, AWS CAPA, Azure CAPZ)

When managing your cluster via GitOps and ArgoCD, you do not need `kubeaid-cli` or `general.yaml` changes for routine upgrades:

1. **Update CAPI Values File**: Open your `kubeaid-config` repository and update the Kubernetes version in your
`capi-cluster` values file (`values-capi-cluster.yaml` or equivalent).
2. **Sync via ArgoCD**: Commit the change and sync the `capi-cluster` application in ArgoCD.
The CAPI controller will automatically initiate the rolling upgrade of the control plane and node groups.

### Method B: CLI-Driven Upgrades (`kubeaid-cli`)

If operating outside of pure GitOps sync:

1. Edit `cluster.k8sVersion` in your `general.yaml` file located at `~/.config/kubeaid-cli/<cluster>/configs/general.yaml`.
2. Run:

   ```bash
   kubeaid-cli cluster upgrade --cluster-name <cluster>
   ```

   *(Use `--skip-pr-workflow` to push changes directly without opening a PR).*

### Method C: Managed Control Planes (AWS EKS / Azure AKS)

1. Update `global.kubernetes.version` in `argocd-apps/values-capi-cluster.yaml` in your `kubeaid-config` repository.
2. Commit and sync via ArgoCD. CAPA/CAPZ will automatically upgrade the control plane and roll the node groups.

---

## 4. Monitoring the Rollout

Track the rolling upgrade in real-time:

```bash
# Monitor CAPI machines rolling out
kubectl get machines -n capi-cluster -w

# Monitor Kubernetes node status
kubectl get nodes -w
```

---

## 5. Troubleshooting & Common Pitfalls

### Pitfall 1: Node Drains Stuck on Stateful Workloads (PDBs)

**Symptom:**
CAPI machine controller logs show node drain stuck because stateful workload pods (such as CloudNativePG primary database
podslike `keycloak-pgsql-primary` or `netbird-pgsql-primary`) are protected by a PodDisruptionBudget (PDB) preventing eviction.

**Solution (Recommended - CloudNativePG Maintenance Window):**
Before or during node drain, you can instruct the CloudNativePG operator to safely permit maintenance via `nodeMaintenanceWindow`:

1. Enable maintenance mode on the database clusters:

   ```bash
   kubectl -n netbird patch clusters.postgresql.cnpg.io netbird-pgsql --type merge -p '{"spec":{"nodeMaintenanceWindow":{"inProgress":true,"reusePVC":true}}}'
   kubectl -n keycloakx patch clusters.postgresql.cnpg.io keycloak-pgsql --type merge -p '{"spec":{"nodeMaintenanceWindow":{"inProgress":true,"reusePVC":true}}}'
   ```

2. Once the node successfully drains and the pod switches over, remove the maintenance window:

   ```bash
   kubectl -n netbird patch clusters.postgresql.cnpg.io netbird-pgsql --type json -p '[{"op":"remove","path":"/spec/nodeMaintenanceWindow"}]'
   kubectl -n keycloakx patch clusters.postgresql.cnpg.io keycloak-pgsql --type json -p '[{"op":"remove","path":"/spec/nodeMaintenanceWindow"}]'
   ```

**Alternative (Fallback):**
If non-CNPG workloads or strict PDBs block eviction:

1. Temporarily delete the blocking PDBs:

   ```bash
   kubectl delete pdb -n keycloakx <keycloak-postgres-pdb-name>
   kubectl delete pdb -n netbird <netbird-postgres-pdb-name>
   ```

2. Force-delete the blocking pods so they immediately terminate and reschedule onto surviving nodes:

   ```bash
   kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
   ```

---

### Pitfall 2: CAPI Machine Deletion Timeout / Unreachable Workload API (`FailedDrainNode`)

**Symptom:**
CAPI machine controller reports `FailedDrainNode` errors due to a connection timeout to the workload cluster
API server during node shutdown.

**Solution:**
Bypass the drain requirement by annotating the stuck machine in the management cluster:

```bash
kubectl -n capi-cluster annotate machine <machine-name> cluster.x-k8s.io/skip-drain="" --overwrite
```

This forces CAPI to proceed with terminating the machine and cleaning up the cloud infrastructure
without waiting for a successful node drain.

---

### Pitfall 3: Webhook Rejections on Immutable Infrastructure Fields (`HetznerCluster`)

**Symptom:**
ArgoCD sync fails with a validation webhook error:

```text
admission webhook "validation.hetznercluster.infrastructure.cluster.x-k8s.io" denied the request: HetznerCluster "cluster-name" is invalid: [spec.controlPlaneLoadBalancer.enabled: Invalid value: true: field is immutable, ...]
```

**Cause:**
Cluster API providers (like CAPH) mark foundational infrastructure fields (such as load balancer configuration or region)
as **immutable** post-creation. `kubectl patch` or ArgoCD cannot override webhook-enforced immutability.

**Solution:**
Ensure that your GitOps repository (`values-capi-cluster.yaml`) matches the immutable values established during
cluster bootstrap. If foundational topology changes (like adding a control plane load balancer post-bootstrap)
are strictly required, they require recreating or migrating the cluster infrastructure.
