# openobserve-collector helm chart

OpenObserve collector is an opinionated helm chart for deploying the OpenObserve collector that allows to you to:

- Deploy the OpenObserve collector to a Kubernetes cluster
- Capture logs and metrics from the cluster and send it to OpenObserve cloud or a self hosted installation
- Configure auto-instrumentation in your cluster to capture traces from your applications written in following languages (Java, .Net, nodejs, python and Go; Go is deprecated in favour of eBPF tracing)
- Optionally trace selected workloads with eBPF, with no code changes (see [eBPF tracing](#ebpf-tracing))

## Prerequisites

### cert-manager

cert-manager is required to be installed in the cluster. If you already have cert-manager installed then you can skip this step. You can install cert-manager using the following command:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
```

Official documentation can be found at https://cert-manager.io/docs/installation/

Wait for 2 minutes after installing cert-manger for the webhook to be ready before installing OpenTelemetry operator.

### OpenTelemetry operator

If you already have OpenTelemetry operator installed then you can skip this step. eBPF tracing needs operator v0.142.0 or later.

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.161.0/opentelemetry-operator.yaml
```

Go auto-instrumentation (deprecated) also needs the operator's `--enable-go-instrumentation` flag, which the upstream manifest leaves off; [opentelemetry-operator.yaml](../../opentelemetry-operator.yaml) in this repository is the same manifest with it added.

Official documentation can be found at https://opentelemetry.io/docs/kubernetes/operator/

## Installing the Chart

```bash
kubectl create ns openobserve-collector
helm --namespace openobserve-collector -f values.yaml install o2c openobserve/openobserve-collector
```

## AKS Workload Identity

The chart already supports service account annotations through `serviceAccount.annotations`.
For collector pods managed by the OpenTelemetry operator, use `agent.labels` and/or `gateway.labels`
to add labels that the generated pods must inherit, and `agent.podAnnotations` / `gateway.podAnnotations`
for pod-level annotations.

Example:

```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "<managed-identity-client-id>"

gateway:
  labels:
    azure.workload.identity/use: "true"

agent:
  labels:
    azure.workload.identity/use: "true"
```

## eBPF tracing

`ebpf.enabled: true` adds a separate DaemonSet, `<fullname>-ebpf`, that traces selected
processes with the collector's `obi` receiver (OpenTelemetry eBPF Instrumentation). Choose
what to trace by port, executable path or command line; at least one is required unless
`ebpf.network.enabled` is true:

```yaml
ebpf:
  enabled: true
  trace:
    ports: [8080, "9000-9100"]
    exePaths: ["/app/checkout*"]
    cmdLines: ["*reports.py*"]
```

It needs OpenTelemetry operator v0.142.0 or later. On older operators `spec.hostPID` is
rejected or silently dropped, and then nothing is traced. The eBPF pods are privileged and
share the host PID namespace, so the release namespace must allow privileged pods. See
[docs/traces.md](docs/traces.md#ebpf-tracing) for details and limits.

`ebpf.network.enabled: true` also sends network flow metrics from the same DaemonSet:
`obi.network.flow.bytes`, the bytes sent between workloads over any TCP or UDP protocol,
labelled with the source and destination owner (Deployment, StatefulSet, Node, ...),
namespace and node. Use it to map which workloads talk to each other. It works with or without
trace selectors, and runs the eBPF pods on the host network. The collector's own metrics
then listen on `127.0.0.1:8888` of each node, so that port must be free there, and the
operator's `<fullname>-ebpf-collector-monitoring` Service can't be scraped:

```yaml
ebpf:
  enabled: true
  network:
    enabled: true
```

See [docs/metrics.md](docs/metrics.md#13-ebpf-network-flows) for the labels and how the
same bytes can be reported more than once.

## Development

If you are developing this chart then you should clone the repo and make any modifications.

You can generate output of the chart using below command to verify:

```shell
helm -n openobserve-collector template o2c . > o2c1.yaml
```

You can install using:

```shell
helm -n openobserve-collector install o2c .
```

or
  
```shell
helm --namespace openobserve-collector \
  install o2c . \
  --set k8sCluster=cluster1  \
  --set exporters."otlphttp/openobserve".endpoint=URL  \
  --set exporters."otlphttp/openobserve".headers.Authorization="Basic base64 encoded auth"  \
  --set exporters."otlphttp/openobserve_k8s_events".endpoint=URL  \
  --set exporters."otlphttp/openobserve_k8s_events".headers.Authorization="Basic base64 encoded auth"
```

### Keeping the Authorization header in a Secret

The header above ends up in the `OpenTelemetryCollector` resources and in the Helm release. To keep it only in a Secret, put it in one, expose it to the collectors with `extraEnv` and reference it with `${env:...}`:

```shell
kubectl -n openobserve-collector create secret generic openobserve-collector-auth \
  --from-literal=authorization="Basic base64 encoded auth"
```

```yaml
exporters:
  otlphttp/openobserve:
    endpoint: URL
    headers:
      Authorization: ${env:OO_AUTH}
  otlphttp/openobserve_k8s_events:
    endpoint: URL
    headers:
      Authorization: ${env:OO_AUTH}
      stream-name: k8s_events
agent:
  extraEnv: &ooAuth
    - name: OO_AUTH
      valueFrom:
        secretKeyRef:
          name: openobserve-collector-auth
          key: authorization
gateway:
  extraEnv: *ooAuth
ebpf:
  extraEnv: *ooAuth  # only needed with ebpf.enabled and gateway.enabled=false
```

After rotating the Secret, restart the collector pods to pick up the new value.

To upgrade

```shell
helm -n openobserve-collector upgrade o2c .
```

To uninstall

```shell
helm -n openobserve-collector uninstall o2c .
```
