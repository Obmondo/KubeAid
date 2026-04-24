# Bare-Metal Node Labels Mixin

## Purpose

Validates early that hetzner bare-metal nodes have constant hostnames during cluster setup to prevent future CAPI issues.

**Problem it detects:** When bare-metal nodes use random hashes in their hostnames instead of consistent names (e.g., `node-a3f9d2` instead of `bm-worker-1234567`), CAPI may treat them as ephemeral and restart them later. Node name changes from CAPI restarts break PVC (PersistentVolumeClaim) attachments, causing data access issues.

**What this alert does:** Fires early if bare-metal nodes don't follow the naming pattern `bm-.*-[0-9]{7}`, catching misconfigurations during initial setup before CAPI causes problems down the line.


## Metric Source: kube_node_labels

**Source:** kube-state-metrics from kube prometheus (listens to Kubernetes API, exposes object state as Prometheus metrics)

**Required configuration added to kube-state-metric deployment:**
```bash
--metric-labels-allowlist=nodes=[beta.kubernetes.io/instance-type,kubernetes.io/hostname]
```

Without this flag, kube-state-metrics won't expose these node labels in the metric.

## Alert: BareMetalNodeLabelsMissingOrMismatch

**Fires when:** Node labels are missing OR nodes lack proper instance type labels

**Alert Query:**
```promql
absent(kube_node_labels) 
  or 
(kube_node_labels{label_beta_kubernetes_io_instance_type!~"^(cax|cx|cpx|ccx).*"} 
  unless 
kube_node_labels{label_kubernetes_io_hostname=~"^bm-.*-[0-9]{7}$"})
```

**Logic:**
1. Fires if `kube_node_labels` metric is missing (kube-state-metrics not exposing labels)
2. First part selects nodes where instance_type doesn't match cloud patterns: `kube_node_labels{label_beta_kubernetes_io_instance_type!~"^(cax|cx|cpx|ccx).*"}`
   - This would include bare-metal nodes (they don't have cx21, cpx31, etc.)
3. `unless` operator removes/excludes anything that matches the right side
   - Right side: `kube_node_labels{label_kubernetes_io_hostname=~"^bm-.*-[0-9]{7}$"}`
   - This matches hostnames like `bm-worker-1234567`, `bm-node-9876543`
4. **Result:** Bare-metal nodes matching the `bm-.*-[0-9]{7}` pattern are excluded from the alert
