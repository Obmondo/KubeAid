# Traces Collection

**Collector:** Gateway StatefulSet
**Receiver:** `otlp` (gRPC + HTTP)
**OpenObserve stream:** `default` (traces)

---

## OTLP Receiver

The gateway accepts traces from any application instrumented with OpenTelemetry via:

| Protocol | Endpoint | Default Port |
|----------|----------|-------------|
| gRPC | `<gateway-service>:4317` | 4317 |
| HTTP | `<gateway-service>:4318` | 4318 |

Send traces from your application by setting the OTLP exporter endpoint to the gateway service address.

---

## Auto-Instrumentation

The chart includes an OpenTelemetry **auto-instrumentation** resource that injects OpenTelemetry SDKs into pods without code changes.

**Sampling rate:** 100% (configurable via `autoinstrumentation.samplingRate`)

### Supported languages

Enable per pod or namespace by adding the appropriate annotation:

| Language | Annotation |
|----------|-----------|
| Java | `instrumentation.opentelemetry.io/inject-java: "true"` |
| Node.js | `instrumentation.opentelemetry.io/inject-nodejs: "true"` |
| Python | `instrumentation.opentelemetry.io/inject-python: "true"` |
| .NET | `instrumentation.opentelemetry.io/inject-dotnet: "true"` |
| Go (deprecated) | `instrumentation.opentelemetry.io/inject-go: "true"` + `instrumentation.opentelemetry.io/otel-go-auto-target-exe: "/path/to/binary"` |
| SDK env vars only | `instrumentation.opentelemetry.io/inject-sdk: "true"` |

> **Go** is deprecated and will be removed in a later release; use [eBPF tracing](#ebpf-tracing) instead. It injects a privileged eBPF sidecar and only works when the operator has Go instrumentation enabled (`--enable-go-instrumentation` or `ENABLE_GO_AUTO_INSTRUMENTATION=true`; off by default). To migrate a pod, remove the annotation and select the app with `ebpf.trace`. Until then, don't select pods that use it with `ebpf.trace`, or their spans are duplicated.

> **Python logs** auto-instrumentation is disabled by default (`autoinstrumentation.pythonLogsEnabled: false`).

### What auto-instrumentation captures

Depending on the language and framework, auto-instrumentation typically produces spans for:

- Incoming HTTP requests (server spans)
- Outgoing HTTP calls (client spans)
- Database queries (PostgreSQL, MySQL, MongoDB, Redis)
- Message queue operations (Kafka, RabbitMQ)
- gRPC calls
- Framework-specific operations (Spring, Express, Django, Flask, ASP.NET, etc.)

---

## eBPF Tracing

**Collector:** eBPF DaemonSet (`<fullname>-ebpf`), off by default
**Receiver:** `obi` (OpenTelemetry eBPF Instrumentation)

With `ebpf.enabled: true`, a separate DaemonSet traces selected processes with eBPF. Applications need no code changes, SDKs or restarts. It requires OpenTelemetry Operator **v0.142.0 or later**: older operators reject or silently drop `spec.hostPID`, and then nothing is traced.

### Choosing what to trace

```yaml
ebpf:
  enabled: true
  trace:
    ports: [8080, "9000-9100"]    # ports and ranges (1-65535)
    exePaths: ["/app/checkout*"]  # executable path globs
    cmdLines: ["*reports.py*"]    # command-line globs
```

Each non-empty list is one rule; a process matching any of them is traced. At least one list must be set, or the chart fails to render, unless `ebpf.network.enabled` is true (network flow metrics only; see [metrics.md](metrics.md#13-ebpf-network-flows)). Globs may not contain `,`, `{` or `}`.

Selection caveats:

- A port matches any process holding a local socket on it, not only servers. Ranges reaching into the ephemeral range (32768-60999 by default) also match clients, and a common port such as 8080 can match many pods.
- Rules also match processes on the node itself, outside any pod. They are instrumented, but their spans are dropped.
- Child processes are traced with their parent.
- Every matched Java and Node.js process gets an injected agent, so broad selectors are invasive.
- Don't select apps that already send their own traces. Processes seen exporting OTLP in plain text (HTTP `/v1/traces` or gRPC `TraceService/Export`) stop being exported, but spans from before their first export are still sent, and HTTPS exports aren't detected.
- Collectors, OBI itself and system namespaces (`kube-system`, `kube-node-lease`, `cert-manager`, `monitoring`, the GKE system namespaces and a few others) are never traced, even if selected.

### Where spans go

Spans go to the gateway, like SDK spans from the `Instrumentation` resources, so a gateway `servicegraph` connector, if you add one, covers eBPF-traced services too. With `gateway.enabled: false` they go straight to OpenObserve through `otlphttp/openobserve`, bypassing any gateway `servicegraph` connector. Spans without `k8s.pod.uid` (processes outside any pod) are dropped before they leave the node.

OBI sets `service.name` and the `k8s.*` attributes itself. It names a service from, in order: `OTEL_SERVICE_NAME` or `service.name` in `OTEL_RESOURCE_ATTRIBUTES` (process, then pod spec), the pod annotation `resource.opentelemetry.io/service.name`, the pod labels `app.kubernetes.io/instance` then `app.kubernetes.io/name`, then the owner or pod name. Note that the gateway uses `app.kubernetes.io/name` only, so for a Helm-installed app eBPF spans can carry the release name while SDK spans and logs carry the chart name.

### Context propagation

Traced processes add a W3C `traceparent` header to outgoing plain-text HTTP/1 and HTTP/2 requests, and read incoming ones, so traces continue across pods and nodes. Limits:

- No header on TLS traffic, except from Go processes on nodes without kernel lockdown.
- On kernels before 6.4, keep-alive connections opened before OBI started carry no header until they reconnect.
- Only the first 1 KiB of a request is searched for `traceparent`.

### Requirements and failure behaviour

- The pods are privileged, run as root and share the host PID namespace; they mount the host's `/sys/fs/cgroup`, and `/sys/kernel/security` and `/sys/kernel/tracing` read-only. The release namespace must allow privileged pods (`pod-security.kubernetes.io/enforce: privileged`); on OpenShift, grant the service account the `privileged` SCC.
- Anyone who can change the DaemonSet, its image or its configuration effectively has root on every node it runs on. Spans include full URL paths and query strings, so don't select apps that put secrets in URLs.
- The service account needs list and watch on pods, services and nodes (the chart's ClusterRole grants this). Without it, containerised processes are never traced and the pod stays `Running`; the log shows `pods is forbidden` errors and `Kubernetes cache has not been synced after timeout`.
- With an operator older than v0.142.0, Helm 3's `helm install` and `helm upgrade` drop `spec.hostPID` with only a warning, and the pods run without errors but trace nothing. Upgrading the operator doesn't restore the field: run `helm upgrade --force` (`--force-replace` on Helm 4), or delete the eBPF `OpenTelemetryCollector` and upgrade.
- Nodes without BTF, with an unsupported kernel or missing capabilities make that node's eBPF pod crash-loop; other nodes and the agent are unaffected. Failures after start-up leave the pod `Running` and tracing nothing, so check the eBPF pod logs if spans don't arrive. `context propagation is disabled` means traces won't join across services for non-Go processes.
- `ebpf.affinity` keeps the pods off non-Linux nodes and architectures other than amd64 and arm64; use `ebpf.nodeSelector` and `ebpf.tolerations` to restrict them further.
- Memory: each pod watches every pod, service and node in the cluster, so memory use grows with cluster size. On a small cluster each pod used 350-456 MiB, about 130 MiB more than the collector process itself (probably eBPF maps, which are charged to the pod but not seen by `memory_limiter`). If you set a memory limit in `ebpf.resources`, make it at least 768Mi, and raise `ebpf.memoryLimiter.limit_mib` with it.

---

## Span Attributes

The gateway's `k8sattributes` processor enriches every span it receives with Kubernetes metadata (eBPF spans sent straight to OpenObserve with `gateway.enabled: false` carry only OBI's own `k8s.*` attributes):

| Attribute | Description |
|-----------|-------------|
| `k8s.pod.name` | Pod generating the trace |
| `k8s.pod.uid` | Pod UID |
| `k8s.namespace.name` | Namespace |
| `k8s.node.name` | Node name |
| `k8s.deployment.name` | Deployment name |
| `k8s.replicaset.name` | ReplicaSet name |
| `k8s.daemonset.name` | DaemonSet name (if applicable) |
| `k8s.statefulset.name` | StatefulSet name (if applicable) |
| `k8s.job.name` | Job name (if applicable) |
| `k8s.cronjob.name` | CronJob name (if applicable) |
| `k8s.container.name` | Container name |
| `k8s.cluster.uid` | Cluster UID |
| `container.image.name` | Container image name |
| `container.image.tags` | Container image tags (when the span carries `k8s.container.name` or `container.id`) |
| `service.name` | From `app.kubernetes.io/name` label |
| `service.version` | From `app.kubernetes.io/version` label |

---

## Service Graph

OpenObserve Enterprise builds the service graph from ingested traces on the server side (`O2_SERVICE_GRAPH_ENABLED`, on by default from OpenObserve 1.2.0), so the gateway defines the OpenTelemetry `servicegraph` connector but leaves it out of its pipelines.

To turn it on, add `servicegraph` to both the metrics pipeline's receivers and the traces pipeline's exporters. A connector used on only one side stops the collector from starting:

```yaml
gateway:
  service:
    pipelines:
      metrics:
        receivers: [otlp, servicegraph, prometheus]
      traces:
        exporters: [otlphttp/openobserve, servicegraph]
```

Helm replaces lists instead of merging them, so these are the full lists; keep any other receivers or exporters you already use.

The connector is mainly useful when OpenObserve does not build the service graph for that organization (the open-source edition, or `O2_SERVICE_GRAPH_ENABLED: "false"`). When both write `traces_service_graph_*` for the same organization, the service graph page uses only OpenObserve's series (from OpenObserve 1.2.0), but a PromQL query that sums these metrics without a `trace_stream` matcher counts every request twice.

See [metrics.md — Service Graph](metrics.md#12-service-graph) for the generated metrics.

**How the connector works:**
1. Client span and matching server span are paired by trace/span ID
2. Latency is computed from the span duration
3. Metrics are emitted with `client` and `server` service labels
4. Unmatched spans are held for 30s (TTL) then dropped

---

## Operator Installation

The chart does not install the OpenTelemetry Operator; install it separately before the chart (see the [README](../README.md#opentelemetry-operator)). It is required for the collectors and for auto-instrumentation. eBPF tracing needs operator v0.142.0 or later. The operator requires cert-manager for its admission webhook.
