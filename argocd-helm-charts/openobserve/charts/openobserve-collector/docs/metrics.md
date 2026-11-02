# Metrics Collection

All metrics are sent to the `default` organization in OpenObserve (as set in the exporter
endpoint); each metric is stored as its own stream, named after the metric.

---

## Sources Overview

| Source | Collector | Interval | What it measures |
|--------|-----------|----------|-----------------|
| [hostmetrics](#1-host-metrics) | Agent (per node) | 10s | Node CPU, memory, disk, network, processes |
| [kubeletstats](#2-kubelet-stats) | Agent (per node) | 10s | Pod/container/node resource usage |
| [cadvisor](#3-cadvisor) | Gateway | 10s | Container filesystem IOPS |
| [kube-state-metrics](#4-kube-state-metrics) | Gateway | 30s | Kubernetes object state |
| [kubelet](#5-kubelet-own-metrics) | Gateway | 30s | Kubelet internals, volume stats, pod start latency |
| [CoreDNS](#6-coredns) | Gateway | 30s | DNS request rate, errors, cache |
| [kube-apiserver](#7-kube-apiserver) | Gateway | 30s | API request rate, latency, errors |
| [kube-scheduler](#8-kube-scheduler) | Gateway | 30s | Scheduling latency, queue depth |
| [kube-controller-manager](#9-kube-controller-manager) | Gateway | 30s | Reconciliation errors, queue depth |
| [prometheus-autodiscovery](#10-prometheus-autodiscovery) | Gateway | 30s | Any annotated pod's custom metrics |
| [k8s_cluster](#11-k8s-cluster) | Gateway | 10s | Cluster-level resource usage/conditions |
| [servicegraph](#12-service-graph) | Gateway | off by default | Service-to-service call metrics |
| [eBPF network flows](#13-ebpf-network-flows) | eBPF DaemonSet (per node) | off by default | Bytes between workloads, any TCP or UDP protocol |

---

## 1. Host Metrics

**Receiver:** `hostmetrics`
**Interval:** 10s
**Source:** Node host filesystem (`/hostfs`)

| Metric | Description |
|--------|-------------|
| `system.cpu.time` | CPU time by state (user, system, idle, iowait, etc.) |
| `system.cpu.utilization` | CPU utilization ratio per CPU/state |
| `system.memory.usage` | Memory usage by state (used, free, cached, buffered) |
| `system.memory.utilization` | Memory utilization ratio |
| `system.disk.io` | Disk read/write bytes per device |
| `system.disk.io_time` | Time disk was active |
| `system.disk.operations` | Read/write operation count per device |
| `system.disk.operation_time` | Time spent on disk operations |
| `system.filesystem.usage` | Filesystem bytes used/free per mount point |
| `system.filesystem.utilization` | Filesystem utilization ratio |
| `system.network.io` | Network bytes received/transmitted per interface |
| `system.network.packets` | Packets received/transmitted per interface |
| `system.network.errors` | Network errors per interface |
| `system.network.dropped` | Dropped packets per interface |
| `system.network.connections` | Active network connections by state |
| `system.load.1` | 1-minute load average |
| `system.load.5` | 5-minute load average |
| `system.load.15` | 15-minute load average |
| `system.processes.count` | Number of processes by state |
| `system.processes.created` | Processes created over time |

**Excluded mount points:** `/dev/*`, `/proc/*`, `/sys/*`, `/var/lib/docker/*`, `/var/lib/kubelet/*`, `/snap/*`, k3s containerd paths

---

## 2. Kubelet Stats

**Receiver:** `kubeletstats`
**Interval:** 10s
**Endpoint:** `https://<node-ip>:10250`

### Node metrics

| Metric | Description |
|--------|-------------|
| `k8s.node.cpu.usage` | Node CPU usage in cores |
| `k8s.node.cpu.time` | Cumulative CPU time |
| `k8s.node.memory.available` | Available memory bytes |
| `k8s.node.memory.usage` | Memory usage bytes |
| `k8s.node.memory.rss` | RSS memory bytes |
| `k8s.node.memory.working_set` | Working set memory bytes |
| `k8s.node.filesystem.available` | Node filesystem available bytes |
| `k8s.node.filesystem.capacity` | Node filesystem capacity bytes |
| `k8s.node.filesystem.usage` | Node filesystem used bytes |
| `k8s.node.network.io` | Node network bytes in/out |
| `k8s.node.network.errors` | Node network errors |

### Pod metrics

| Metric | Description |
|--------|-------------|
| `k8s.pod.cpu.usage` | Pod CPU usage in cores |
| `k8s.pod.memory.available` | Pod memory available bytes |
| `k8s.pod.memory.usage` | Pod memory usage bytes |
| `k8s.pod.memory.rss` | Pod RSS memory bytes |
| `k8s.pod.memory.working_set` | Pod working set memory bytes |
| `k8s.pod.network.io` | Pod network bytes in/out |
| `k8s.pod.network.errors` | Pod network errors |
| `k8s.pod.cpu_limit_utilization` | CPU usage / CPU limit ratio |
| `k8s.pod.cpu_request_utilization` | CPU usage / CPU request ratio |
| `k8s.pod.memory_limit_utilization` | Memory usage / memory limit ratio |
| `k8s.pod.memory_request_utilization` | Memory usage / memory request ratio |

### Container metrics

| Metric | Description |
|--------|-------------|
| `container.cpu.usage` | Container CPU usage in cores |
| `container.memory.available` | Container memory available bytes |
| `container.memory.usage` | Container memory usage bytes |
| `container.memory.rss` | Container RSS memory bytes |
| `container.memory.working_set` | Container working set memory bytes |

### Volume metrics

| Metric | Description |
|--------|-------------|
| `k8s.volume.available` | Volume available bytes |
| `k8s.volume.capacity` | Volume capacity bytes |
| `k8s.volume.inodes` | Volume inodes total |
| `k8s.volume.inodes_free` | Volume inodes free |
| `k8s.volume.inodes_used` | Volume inodes used |

**Extra labels attached:** `container.id`, `k8s.volume.type`

---

## 3. cAdvisor

**Receiver:** `prometheus` (job: `cadvisor`)
**Interval:** 10s
**Endpoint:** `https://<node>:10250/metrics/cadvisor`

Only filesystem IOPS metrics are kept (all others dropped):

| Metric | Description |
|--------|-------------|
| `container_fs_reads_total` | Cumulative filesystem reads per container |
| `container_fs_writes_total` | Cumulative filesystem writes per container |
| `container_fs_reads_bytes_total` | Cumulative bytes read from filesystem per container |
| `container_fs_writes_bytes_total` | Cumulative bytes written to filesystem per container |

> Metrics with no `pod` label (host-level cgroups) are dropped.

---

## 4. Kube-State-Metrics

**Receiver:** `prometheus` (job: `kube-state-metrics`)
**Interval:** 30s
**Endpoint:** `kube-state-metrics.kube-system.svc.cluster.local:8080`

### Pods

| Metric | Description |
|--------|-------------|
| `kube_pod_info` | Pod metadata (node, IP, owner) |
| `kube_pod_created` | Pod creation timestamp |
| `kube_pod_status_phase` | Pod phase (Running/Pending/Failed/Succeeded) |
| `kube_pod_status_ready` | Whether pod is Ready |
| `kube_pod_status_reason` | Reason pod is not running (Evicted, OOMKilled, etc.) |
| `kube_pod_container_info` | Container image info |
| `kube_pod_container_status_ready` | Container readiness |
| `kube_pod_container_status_restarts_total` | Container restart count |
| `kube_pod_container_resource_requests` | CPU/memory requests |
| `kube_pod_container_resource_limits` | CPU/memory limits |
| `kube_pod_container_status_waiting_*` | Waiting reason (CrashLoopBackOff, ImagePullBackOff, etc.) |
| `kube_pod_container_status_terminated_reason` | Why container terminated |
| `kube_pod_owner` | Owner reference (Deployment, DaemonSet, Job, etc.) |

### Deployments

| Metric | Description |
|--------|-------------|
| `kube_deployment_status_replicas_*` | Ready/available/unavailable replica counts |
| `kube_deployment_spec_replicas` | Desired replica count |
| `kube_deployment_created` | Deployment creation timestamp |

### DaemonSets

| Metric | Description |
|--------|-------------|
| `kube_daemonset_created` | DaemonSet creation timestamp |
| `kube_daemonset_status_*` | Desired/ready/available/unavailable counts |

### StatefulSets

| Metric | Description |
|--------|-------------|
| `kube_statefulset_replicas` | Desired replica count |
| `kube_statefulset_created` | Creation timestamp |
| `kube_statefulset_status_*` | Ready/current/updated replica counts |

### ReplicaSets

| Metric | Description |
|--------|-------------|
| `kube_replicaset_status_*` | Ready/available replica counts |
| `kube_replicaset_spec_replicas` | Desired replica count |
| `kube_replicaset_created` | Creation timestamp |
| `kube_replicaset_owner` | Owner (Deployment) reference |
| `kube_replicaset_annotations` | Annotations (includes `deployment.kubernetes.io/revision`) |

### Nodes

| Metric | Description |
|--------|-------------|
| `kube_node_info` | Node kernel version, OS image, container runtime |
| `kube_node_status_condition` | Node conditions (Ready, MemoryPressure, DiskPressure, etc.) |
| `kube_node_status_allocatable` | Allocatable CPU, memory, storage, pods |
| `kube_node_spec_taint` | Node taints |
| `kube_node_created` | Node creation timestamp |

### Namespaces

| Metric | Description |
|--------|-------------|
| `kube_namespace_status_phase` | Active or Terminating |
| `kube_namespace_created` | Creation timestamp |

### Services

| Metric | Description |
|--------|-------------|
| `kube_service_info` | Service type, cluster IP, external name |
| `kube_service_created` | Creation timestamp |
| `kube_service_spec_type` | ClusterIP, NodePort, LoadBalancer, ExternalName |
| `kube_service_status_load_balancer_ingress` | LoadBalancer IP/hostname |

### Ingresses

| Metric | Description |
|--------|-------------|
| `kube_ingress_info` | Ingress class, host |
| `kube_ingress_created` | Creation timestamp |
| `kube_ingress_path` | Ingress paths and backend services |
| `kube_ingress_tls` | TLS secret names |
| `kube_ingress_labels` | Ingress labels |

### Persistent Volumes & PVCs

| Metric | Description |
|--------|-------------|
| `kube_persistentvolumeclaim_status_phase` | Bound, Pending, Lost |
| `kube_persistentvolumeclaim_info` | StorageClass, volume name |
| `kube_persistentvolumeclaim_access_mode` | ReadWriteOnce, ReadWriteMany, etc. |
| `kube_persistentvolumeclaim_resource_requests_storage_bytes` | Requested storage size |
| `kube_persistentvolumeclaim_created` | Creation timestamp |
| `kube_persistentvolume_info` | StorageClass, reclaim policy |
| `kube_persistentvolume_created` | Creation timestamp |
| `kube_persistentvolume_status_phase` | Available, Bound, Released, Failed |
| `kube_persistentvolume_capacity_bytes` | Volume capacity |
| `kube_persistentvolume_access_mode` | Access modes |
| `kube_persistentvolume_reclaim_policy` | Delete, Retain, Recycle |

### HPA

| Metric | Description |
|--------|-------------|
| `kube_horizontalpodautoscaler_info` | Target reference, metrics |
| `kube_horizontalpodautoscaler_created` | Creation timestamp |
| `kube_horizontalpodautoscaler_status_*` | Current/desired replica counts |
| `kube_horizontalpodautoscaler_spec_*` | Min/max replicas |

### Jobs & CronJobs

| Metric | Description |
|--------|-------------|
| `kube_job_info` | Job labels/annotations |
| `kube_job_created` | Creation timestamp |
| `kube_job_status_*` | Active/succeeded/failed counts |
| `kube_job_spec_*` | Parallelism, completions |
| `kube_job_complete` | Whether job completed |
| `kube_job_failed` | Whether job failed |
| `kube_job_owner` | Owner CronJob reference |
| `kube_cronjob_info` | Schedule, timezone |
| `kube_cronjob_created` | Creation timestamp |
| `kube_cronjob_status_active` | Active job count |
| `kube_cronjob_spec_suspend` | Whether suspended |
| `kube_cronjob_next_schedule_time` | Next scheduled run |

### Network Policies

| Metric | Description |
|--------|-------------|
| `kube_networkpolicy_created` | Creation timestamp |
| `kube_networkpolicy_spec_ingress_rules` | Number of ingress rules |
| `kube_networkpolicy_spec_egress_rules` | Number of egress rules |

### Resource Quotas & Limit Ranges

| Metric | Description |
|--------|-------------|
| `kube_resourcequota` | Used vs hard quota per resource type |
| `kube_limitrange` | Min/max/default limits per resource type |

### Service Accounts

| Metric | Description |
|--------|-------------|
| `kube_serviceaccount_info` | Service account metadata |
| `kube_serviceaccount_created` | Creation timestamp |

---

## 5. Kubelet Own Metrics

**Receiver:** `prometheus` (job: `kubelet`)
**Interval:** 30s
**Endpoint:** `https://<node>:10250/metrics`

| Metric | Description |
|--------|-------------|
| `kubelet_running_pods` | Number of pods currently running on the node |
| `kubelet_running_containers` | Number of containers currently running |
| `kubelet_node_config_error` | Whether the node has a config error (0/1) |
| `kubelet_volume_stats_available_bytes` | Available bytes for each volume |
| `kubelet_volume_stats_capacity_bytes` | Capacity bytes for each volume |
| `kubelet_volume_stats_used_bytes` | Used bytes for each volume |
| `kubelet_pod_start_duration_seconds_count` | Count of pod start duration observations |
| `kubelet_pod_start_duration_seconds_sum` | Sum of pod start durations (for average calculation) |
| `kubelet_pod_worker_duration_seconds_count` | Count of pod worker sync duration observations |
| `kubelet_pod_worker_duration_seconds_sum` | Sum of pod worker sync durations |

---

## 6. CoreDNS

**Receiver:** `prometheus` (job: `coredns`)
**Interval:** 30s
**Discovery:** `kube-dns` service endpoints in `kube-system`

| Metric | Description |
|--------|-------------|
| `coredns_dns_requests_total` | Total DNS requests by type/zone/protocol |
| `coredns_dns_responses_total` | Total DNS responses by rcode |
| `coredns_dns_request_duration_seconds` | DNS request latency histogram |
| `coredns_cache_hits_total` | Cache hits by type |
| `coredns_cache_misses_total` | Cache misses |
| `coredns_cache_entries` | Current cache entries |
| `coredns_forward_requests_total` | Forwarded requests to upstream |
| `coredns_forward_responses_duration_seconds` | Upstream response latency |
| `coredns_panics_total` | Plugin panics |

---

## 7. Kube-APIServer

**Receiver:** `prometheus` (job: `kube-apiserver`)
**Interval:** 30s
**Discovery:** `kubernetes` service endpoints in `default` namespace

| Metric | Description |
|--------|-------------|
| `apiserver_request_total` | Total API requests by verb, resource, code |
| `apiserver_request_duration_seconds_bucket` | Request latency histogram |
| `apiserver_request_duration_seconds_count` | Request count |
| `apiserver_admission_webhook_request_total` | Admission webhook requests |
| `apiserver_current_inflight_requests` | In-flight requests by type |
| `process_resident_memory_bytes` | API server process memory |
| `process_cpu_seconds_total` | API server process CPU |
| `kubernetes_build_info` | Kubernetes version info |

---

## 8. Kube-Scheduler

**Receiver:** `prometheus` (job: `kube-scheduler`)
**Interval:** 30s
**Endpoint:** `<scheduler-pod-ip>:10259`

All metrics emitted by the scheduler are collected. Key ones include:

| Metric | Description |
|--------|-------------|
| `scheduler_scheduling_attempt_duration_seconds` | End-to-end scheduling latency histogram |
| `scheduler_pending_pods` | Pods waiting to be scheduled by queue type |
| `scheduler_pod_scheduling_attempts` | Number of attempts to schedule a pod |
| `scheduler_framework_extension_point_duration_seconds` | Latency per extension point |
| `scheduler_preemption_attempts_total` | Preemption attempts |
| `scheduler_preemption_victims` | Number of victims in a preemption |

---

## 9. Kube-Controller-Manager

**Receiver:** `prometheus` (job: `kube-controller-manager`)
**Interval:** 30s
**Endpoint:** `<controller-pod-ip>:10257`

All metrics emitted by the controller manager are collected. Key ones include:

| Metric | Description |
|--------|-------------|
| `workqueue_depth` | Queue depth per controller |
| `workqueue_adds_total` | Items added to each queue |
| `workqueue_queue_duration_seconds` | Time items spend in queue |
| `workqueue_work_duration_seconds` | Time spent processing items |
| `workqueue_retries_total` | Retry count per queue |
| `controller_runtime_reconcile_total` | Reconciliations by controller/result |
| `controller_runtime_reconcile_errors_total` | Reconciliation errors |
| `node_collector_evictions_total` | Node evictions per zone |

---

## 10. Prometheus Autodiscovery

**Receiver:** `prometheus` (job: `prometheus-autodiscovery`)
**Interval:** 30s
**Discovery:** All pods cluster-wide annotated with `prometheus.io/scrape: "true"`

### Required pod annotations

```yaml
annotations:
  prometheus.io/scrape: "true"   # required — enables scraping
  prometheus.io/port: "8080"     # required — port to scrape
  prometheus.io/path: "/metrics" # optional — defaults to /metrics
  prometheus.io/scheme: "http"   # optional — defaults to http
```

### Labels attached to scraped metrics

| Label | Source |
|-------|--------|
| `namespace` | Pod namespace |
| `pod` | Pod name |
| `service` | `app.kubernetes.io/name` pod label |
| `job` | `prometheus-autodiscovery` |

### Limits

- Max **10,000 samples** per scrape by default (`gateway.prometheus.sampleLimit`, shared with the cadvisor job). A scrape exceeding it is dropped entirely and the target's `up` metric reads 0.

---

## 11. K8s Cluster

**Receiver:** `k8s_cluster`
**Interval:** 10s

Cluster-level resource allocation metrics from the Kubernetes API:

| Metric | Description |
|--------|-------------|
| `k8s.node.condition_ready` | Node Ready condition (1=true, 0=false) |
| `k8s.node.condition_memory_pressure` | Node MemoryPressure condition |
| `k8s.node.condition_disk_pressure` | Node DiskPressure condition |
| `k8s.node.condition_pid_pressure` | Node PIDPressure condition |
| `k8s.node.allocatable_cpu` | Allocatable CPU on the node |
| `k8s.node.allocatable_memory` | Allocatable memory on the node |
| `k8s.node.allocatable_storage` | Allocatable storage on the node |
| `k8s.deployment.available` | Available replicas in a deployment |
| `k8s.deployment.desired` | Desired replicas in a deployment |
| `k8s.replicaset.available` | Available replicas in a replicaset |
| `k8s.replicaset.desired` | Desired replicas in a replicaset |
| `k8s.daemonset.ready_nodes` | Ready nodes for a daemonset |
| `k8s.daemonset.desired_scheduled_nodes` | Desired scheduled nodes |
| `k8s.daemonset.current_scheduled_nodes` | Currently scheduled nodes |
| `k8s.daemonset.misscheduled_nodes` | Misscheduled nodes |
| `k8s.statefulset.ready_replicas` | Ready replicas in a statefulset |
| `k8s.statefulset.desired_replicas` | Desired replicas |
| `k8s.namespace.phase` | Namespace phase (1=active, 0=terminating) |
| `k8s.pod.phase` | Pod phase encoded as numeric value |
| `k8s.container.ready` | Container readiness (1=ready, 0=not) |
| `k8s.container.restarts` | Container restart count |
| `k8s.cronjob.active_jobs` | Active jobs for a CronJob |
| `k8s.hpa.current_replicas` | Current HPA replica count |
| `k8s.hpa.desired_replicas` | Desired HPA replica count |
| `k8s.hpa.max_replicas` | HPA max replica limit |
| `k8s.hpa.min_replicas` | HPA min replica limit |

> Note: `k8s.container.cpu_limit/request` and `k8s.container.memory_limit/request` are **disabled** (redundant with kubeletstats).

---

## 12. Service Graph

**Connector:** `servicegraph` (not in the default pipelines, see [traces.md — Service Graph](traces.md#service-graph))
**Source:** Traces (computed from spans)

When enabled, derived from distributed traces — measures service-to-service call patterns:

| Metric | Description |
|--------|-------------|
| `traces_service_graph_request_total` | Total calls between two services |
| `traces_service_graph_request_failed_total` | Failed calls between two services |
| `traces_service_graph_request_server_seconds` | Server-side latency histogram |
| `traces_service_graph_request_client_seconds` | Client-side latency histogram |
| `traces_service_graph_unpaired_spans_total` | Spans that couldn't be matched |
| `traces_service_graph_dropped_spans_total` | Spans dropped (buffer exceeded) |

**Labels on all service graph metrics:** `client`, `server`, `http.method`

**Latency buckets:** 2ms, 4ms, 6ms, 8ms, 10ms, 50ms, 100ms, 200ms, 400ms, 800ms, 1s, 1.4s, 2s, 5s, 10s, 15s

---

## 13. eBPF Network Flows

**Receiver:** `obi` in the eBPF DaemonSet (`<fullname>-ebpf`), with `ebpf.enabled: true` and `ebpf.network.enabled: true`
**Source:** eBPF on each node's network interfaces; works for any TCP or UDP protocol, not only HTTP

| Metric | Description |
|--------|-------------|
| `obi.network.flow.bytes` | Bytes sent from source to destination (cumulative counter). Queried as `obi_network_flow_bytes` |

**Labels:**

| Label | Values |
|-------|--------|
| `k8s_src_owner_name`, `k8s_dst_owner_name` | Owning workload, e.g. the Deployment name; the node name for host processes and host-network pods; empty for addresses outside the cluster and for node-local traffic such as kubelet probes |
| `k8s_src_owner_type`, `k8s_dst_owner_type` | `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `CronJob`, `Pod`, `Service`, `Node`, `ReplicaSet` (only one whose name has no `-`), or empty. OBI guesses the CronJob from the Job's name: a Job whose name contains a `-` (e.g. `nightly-export`) is reported as a `CronJob` named by the part before the last `-` (`nightly`), so two such Jobs can merge into one owner (Jobs `blob-c` and `blob-d` both show as CronJob `blob`). A ReplicaSet whose name contains a `-` is likewise reported as a Deployment |
| `k8s_src_namespace`, `k8s_dst_namespace` | Namespace; empty for nodes and outside addresses |
| `direction` | `request` (client to server), `response` (server to client), or `unknown`, mostly when OBI didn't see the TCP handshake: UDP, and TCP connections already open when the eBPF pod started (keepalive, database and gRPC pools after an install or upgrade), until they reconnect. Part of a busy new TCP connection can also be `unknown` (about 1-3% of its bytes in one test) |
| `k8s_src_node_name`, `k8s_dst_node_name` | Node running the source or destination pod; empty for Services, nodes and outside addresses. From chart 0.8.2 |
| `host_id` | Machine ID of the node that reported the flow (not the node name) |
| `k8s_cluster` | From `k8sCluster` |

Pod names, IP addresses and ports are not included, which keeps the number of series low.
`k8s_cluster_name` may be empty (OBI fills it only from eksctl, AKS or Cluster API node
labels); use `k8s_cluster`.

**Counting each connection once.** The same bytes are reported more than once:

- traffic between pods on different nodes is reported by both nodes (two `host_id` values);
- on the client's node, a connection to a Service is reported twice: once with the
  Service as the other end (owner type `Service`) and once with the workload behind it.

Which pod workloads talk to each other is exact; byte totals are not. Host processes and
host-network pods on one node all share that node's identity, and outside addresses share
an empty one. Drop the `Service` rows
(or keep only them), and don't sum across `host_id`. A node reports only the flows of its
own pods, and the bytes between a source node and a destination node are reported in full
by both of those nodes and by no other. One edge on one node can have several series (e.g.
`request` and `unknown`), so sum per reporting node first, take the `max` across reporting
nodes for each pair of pod nodes, then add the pairs up. For example, bytes per second sent
from each workload to another:

```promql
sum by (k8s_cluster, k8s_src_namespace, k8s_src_owner_name, k8s_dst_namespace, k8s_dst_owner_name) (
  max by (k8s_cluster, k8s_src_namespace, k8s_src_owner_name, k8s_dst_namespace, k8s_dst_owner_name,
          k8s_src_node_name, k8s_dst_node_name) (
    sum by (k8s_cluster, k8s_src_namespace, k8s_src_owner_name, k8s_dst_namespace, k8s_dst_owner_name,
            k8s_src_node_name, k8s_dst_node_name, host_id) (
      rate(obi_network_flow_bytes{k8s_src_owner_type!="Service", k8s_dst_owner_type!="Service"}[5m])
    )
  )
)
```

Adding `direction="request"` keeps only client-to-server bytes, but drops connections
whose direction is `unknown` entirely: an edge carried only by a connection that was open
before the eBPF pod started is missing until it reconnects, and busy edges lose the part
counted as `unknown`. Without the filter such an edge shows up both ways, as each end
sends bytes to the other.

`max` avoids counting the bytes twice. Each node counts whole packets, headers
included, so the two nodes' counts differ by up to a few percent, depending on the setup
(headers, and receive offload merging packets). When either workload's pods all run on
one node, that node sees nearly the whole total, but the workload rows can still
undercount by several percent (0.93-0.95x of the payload for multi-second, rate-limited
transfers in one test). Without the node labels (charts before 0.8.2) the query reduces
to the `max` across reporting nodes, which undercounts workloads spread over several
nodes, as each node reports only its own pods' share; `sum` across nodes instead counts
traffic between nodes twice (about 2x when both ends are monitored). With two replicas of
each end, one per node, in one test: 498 B/s per pair of nodes, against 364 for the `max`
and 682 for the `sum`. While a chart upgrade rolls out, traffic between an upgraded node
and one not yet upgraded is counted twice.

For traffic sent to a Service, the `Service` rows are reported only by the client's
node, so summing them counts each byte once wherever the clients run, and they were the
most accurate total in testing: within about 1% of the payload, headers included, with
clients on one node or both. They name the Service, not the workload
behind it, and are absent for traffic sent straight to pods (headless Services,
StatefulSet pod DNS names). A Service is never the client, so `k8s_dst_owner_type="Service"`
already selects only the bytes the clients sent, and no `direction` filter is needed:

```promql
sum by (k8s_cluster, k8s_src_namespace, k8s_src_owner_name, k8s_dst_namespace, k8s_dst_owner_name) (
  rate(obi_network_flow_bytes{k8s_dst_owner_type="Service"}[5m])
)
```

Short bursts (0.8 and 6 seconds) were counted fully in testing. The undercount seen is
in the workload rows of slower multi-second transfers (above), likely a race in how OBI
drains its flow map.

A flow series idle for about 6 minutes is dropped and starts again from 0 when traffic
resumes. `rate()` and `increase()` handle this; subtracting two raw readings can go
negative.

When the gateway is enabled, its `k8sattributes` processor adds a `k8s_pod_ip` label to
the flows. It is not an end of the flow: the eBPF pods use the node's network, and the
values seen were the node's pod-network bridge or overlay address (e.g. `cni0` or
`flannel.1`), not a pod's.

