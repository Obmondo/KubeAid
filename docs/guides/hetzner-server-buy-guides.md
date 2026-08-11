# Hetzner Bare Metal & HCloud Server Purchasing Guide

This document provides guidance for purchasing Hetzner servers for Kubernetes deployments, including recommended hardware,
cluster layouts, and best practices.

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

### Best Practices

* Purchase servers via **Hetzner auctions** to reduce costs.
* Ensure control plane nodes are located **in the same country but across different datacenters** to maintain redundancy.
* Include separate backup servers for critical data.
* We recommend control planes to be VMs (HCloud node) to save resources and cost.

### Hardware Recommendations

#### Backup Server

* Storage: 4 × 10 TB SATA Enterprise HDD
* RAM: 4 × 8192 MB DDR3 ECC
* Network: 1 Gb NIC

#### Control Plane Node

* Storage: 40 GB SSD
* RAM: 4 GB
* Notes: Control plane nodes will not run many workloads.
* If you need to schedule workloads on control plane nodes, you can use the worker node configuration below;
  however, this is **not recommended for security reasons**. The pods running on the control plane node should not run public
  ingress services.

#### Single-Host Cluster / Worker Node

* Storage: 2 × 1 TB SSD M.2 NVMe
* RAM: 4 × 16384 MB DDR4

### Optional Networking Enhancement

* Add a **10 Gb NIC** to bare metal nodes to boost internal connectivity (cost: ~5€ per NIC per node).
* Only required for internal node traffic; a 10 Gb uplink is **not necessary**. A 10 Gb uplink can cost 43+€
  and is only required if high-speed internet connectivity is needed.

---

## 3. HCloud Server Recommendations

* **Control Plane Node**: CAX11 (2 vCPU, 4 GB RAM, 40 GB storage, 5.99€/month)
* **Worker Node**: CAX41 (16 vCPU, 32 GB RAM, 320 GB storage, 40.99€/month)

Add 0.50€/month per node for the IPv4 address. Prices are list, as of the
[15 June 2026 adjustment](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/).
Hetzner changed prices three times in the first half of 2026, so re-check that page before you quote a total.

### Important Notes

* HCloud nodes have a **limit of 16 volumes per node**.
* Volume attachment is subject to **location limitations per country**, so plan accordingly.

### Outbound Traffic

Traffic is usually the largest hidden cost difference against a hyperscaler, so budget it explicitly:

* HCloud servers in **Germany and Finland include 20 TB outbound per server per month**, pooled across the project.
* **US locations include roughly 1 TB**, and **Singapore as little as 0.5 TB**, so the same cluster costs
  materially more outside the EU.
* Overage is **€1/TB** in the EU locations and **€7.40/TB** in Singapore.
* The allowance is fair use, not a contract. It pools across the project rather than guaranteeing headroom
  to one hot node.
* Bare metal servers are sold with unlimited traffic on the standard 1 Gbit uplink.

---

## 4. Hybrid Cluster (Recommended setup)

* **Control Plane**: CAX11 HCloud server (5.99€/month, plus 0.50€ for the IPv4)
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
| HA Bare Metal     | 3 control + 3 worker                                | 2 × 1 TB NVMe | 4 × 16 GB     | Production with redundancy          |
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
