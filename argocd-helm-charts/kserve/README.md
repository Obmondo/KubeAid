# KServe

Wrapper around the upstream [KServe](https://kserve.github.io/website/) charts from
`oci://ghcr.io/kserve/charts`, for LLM serving with `LLMInferenceService` (llm-d) and the local model cache.
`values.yaml` is empty, so every default is upstream's.

## What it installs

| Subchart | Renders with default values |
|---|---|
| `kserve-crd` | CRDs `InferenceService`, `ServingRuntime`, `ClusterServingRuntime`, `InferenceGraph`, `TrainedModel`, `ClusterStorageContainer` |
| `kserve-llmisvc-crd` | CRDs `LLMInferenceService`, `LLMInferenceServiceConfig` |
| `kserve-llmisvc-resources` | `llmisvc-controller-manager` and its webhooks, the Gateway API Inference Extension CRDs (`InferencePool`, `InferenceObjective`, `InferenceModelRewrite`), and the shared `inferenceservice-config` ConfigMap, `selfsigned-issuer` Issuer and `default` ClusterStorageContainer |
| `kserve-localmodel-crd` | CRDs `LocalModelCache`, `LocalModelNamespaceCache`, `LocalModelNodeGroup`, `LocalModelNode` |
| `kserve-localmodel-resources` | The local model cache controller, and its node agent DaemonSet on nodes labelled `kserve/localmodel=worker` |
| `kserve-runtime-configs` | Nothing until `kserve.llmisvcConfigs.enabled` or `kserve.servingruntime.enabled` is set |

The classic `InferenceService` controller (`kserve-resources`) is left out. Its default deployment mode is `Knative`,
which needs Knative Serving with Istio as the default network layer, and it would render the shared objects above a
second time.

Both CRD charts ship `clusterstoragecontainers.serving.kserve.io`. `.helm-prune` drops the `kserve-llmisvc-crd` copy.

## Prerequisites

- cert-manager. The admission and CRD conversion webhooks get their certificates and CA from it.
- Namespace `kserve`. The CRD conversion webhooks point at `kserve/llmisvc-webhook-server-service`, untemplated.
- For routed `LLMInferenceService`s: the Gateway API CRDs and a Gateway that accepts `InferencePool` backends. KServe's
  default Gateway is `kserve/kserve-ingress-gateway` (`kserveIngressGateway` in `inferenceservice-config`), which no
  subchart here creates.
- Optional: LeaderWorkerSet for multi-node serving, KEDA for autoscaling.
- Not needed: Knative, Istio.

## Argo CD Application

Three CRDs, `llminferenceservices`, `llminferenceserviceconfigs` and `inferenceservices`, are well over the 256 KiB
last-applied annotation limit of client-side apply. The upstream CRD charts have no setting for extra annotations, so the Application sets `ServerSideApply=true` in `spec.syncPolicy.syncOptions` and
deploys to namespace `kserve`.

## Cluster values for LLM serving

`LLMInferenceService` builds its workloads from the well-known `LLMInferenceServiceConfig`s, which are off by
default. `deploymentMode: Standard` only matters to the classic controller, but keeps the shared config off Knative.
The storage initializer's default 1Gi memory limit gets OOMKilled downloading large model weights.
`localmodel.enabled` switches on the local model cache.

```yaml
kserve-runtime-configs:
  kserve:
    llmisvcConfigs:
      enabled: true
kserve-llmisvc-resources:
  kserve:
    controller:
      deploymentMode: Standard
    storage:
      resources:
        requests:
          memory: 2Gi
        limits:
          memory: 32Gi
    localmodel:
      enabled: true
```

The local model cache also needs the `kserve-localmodel-jobs` namespace, a StorageClass for the cache volumes, and
the `kserve/localmodel=worker` label on the cache nodes.

## Updating

KServe tags its charts with a `v` prefix, which `helm show chart` skips, so the weekly Helm update leaves this chart
on its pinned version. To bump it, set all six versions in `Chart.yaml`, then run:

```sh
bin/manage-helm-chart.sh --update-helm-chart kserve
```
