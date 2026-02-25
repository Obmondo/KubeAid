
# Hetzner Bare Metal & HCloud Server Purchasing Guide

This document provides guidance for purchasing Hetzner servers for Kubernetes deployments, including recommended hardware, cluster layouts, and best practices.

---

## 1. Supported Cluster Layouts

We support three types of cluster layouts:

| Layout             | Description                                                             |
| ------------------ | ----------------------------------------------------------------------- |
| **All HCloud**     | Control plane and worker nodes fully deployed on HCloud servers.        |
| **All Bare Metal** | Control plane and worker nodes fully deployed on bare metal servers.    |
| **Hybrid**         | Control plane on HCloud servers and worker nodes on bare metal servers. |

---

## 2. Bare Metal Server Recommendations

**Note:** Bare metal clusters have no limits on volume creation but do not support automatic node scaling.

For **bare metal clusters**, we recommend:

* **Single server setup**: One node (suitable for testing or small deployments).
* **High-availability setup**: 3 control plane nodes + 3 worker nodes for redundancy.
(we recommend running the control plane on VMs to save on resources and cost).

### Best Practices

* Purchase servers via **Hetzner auctions** to reduce costs.
* Ensure control plane nodes are located **in the same country but across different datacenters** to maintain redundancy.
* Include separate backup servers for critical data.
* we recommend control planes to be vms(hcloud node) to save resources and cost
### Hardware Recommendations

#### Backup Server

* Storage: 4 × 10 TB SATA Enterprise HDD
* RAM: 4 × 8192 MB DDR3 ECC
* Network: 1 Gb NIC

#### Control Plane Node

* Storage: 40 GB SSD
* RAM: 4 GB
* Notes: Control plane nodes will not run many workloads.
* If you need to schedule workloads on control plane nodes, you can use the worker node configuration below; however, this is **not recommended for security reasons**.the pods running on the control plane node should not run public ingress services.
#### Single-Host Cluster / Worker Node

* Storage: 2 × 1 TB SSD M.2 NVMe
* RAM: 4 × 16384 MB DDR4

### Optional Networking Enhancement

* Add a **10 Gb NIC** to bare metal nodes to boost internal connectivity (cost: ~5€ per NIC per node).
* Only required for internal node traffic; a 10 Gb uplink is **not necessary**. A 10 Gb uplink can cost 43+€ and is only required if high-speed internet connectivity is needed.

---

## 3. HCloud Server Recommendations

* **Control Plane Node**: CAX11 (2 vCPU, 4 GB RAM, 40 GB storage, ~4€/month)
* **Worker Node**: CAX41 (16 vCPU, 32 GB RAM, 320 GB storage, ~23€/month)

### Important Notes

* HCloud nodes have a **limit of 16 volumes per node**.
* Volume attachment is subject to **location limitations per country**, so plan accordingly.

---

## 4. Hybrid Cluster  (Recommended setup)

* **Control Plane**: CAX11 HCloud server (~4€/month)
* **Worker Node**: Bare Metal

  * RAM: 4 × 16384 MB DDR4
  * Storage: 2 × 1 TB SSD M.2 NVMe

### Optional Networking

* Add a 10 Gb NIC to bare metal worker nodes to improve internal connectivity (~5€ per NIC).

---

## 5. Cluster Configurations Chart

| Layout            | Nodes                                               | Storage       | RAM           | Notes                               |
| ----------------- | --------------------------------------------------- | ------------- | ------------- | ----------------------------------- |
| Single Bare Metal | 1 node                                              | 2 × 1 TB NVMe | 4 × 16 GB     | Small/test cluster                  |
| HA Bare Metal     | 3 control + 3 worker                                | 2    × 10 TB HDD | 4 × 16 GB      | Production with redundancy          |
| All HCloud        | 3 control (CAX11) + 3 worker (CAX41)                | CAX41 default | CAX41 default | Cloud cluster with scaling          |
| Hybrid            | 1 or 3 control (CAX11) + 1 or 3 worker (bare metal) | 2 × 1 TB NVMe | 4 × 16 GB     | Internal high-performance workloads |

---

## 6. Summary of Best Practices

* Always **distribute control plane nodes across datacenters**.
* Use **Hetzner auctions** for bare metal servers to reduce costs.
* Match node specifications to their role:

  * Control plane: moderate RAM + SSD
  * Worker nodes: large storage + ECC RAM
* For hybrid setups, HCloud provides flexibility and easy scaling, while bare metal delivers high performance.
* Consider optional **10 Gb NICs** to improve intra-cluster communication on bare metal nodes.


