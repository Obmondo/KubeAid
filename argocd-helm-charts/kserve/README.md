# KServe

Wrapper around the upstream [KServe](https://kserve.github.io/website/) charts from
`oci://ghcr.io/kserve/charts`, for LLM serving with `LLMInferenceService` (llm-d) and the local model cache.
The subcharts keep every upstream default. The chart's own addition is `llmInferenceServices`, which renders the
models to serve (see [LLMInferenceServices from values](#llminferenceservices-from-values)).

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

## LLMInferenceServices from values

Each entry in `llmInferenceServices` renders one `LLMInferenceService`, with `spec` passed through as is. It lands in
the release namespace unless `namespace` is set, and gets the Argo CD sync wave `1` (override it in `annotations`), so
it is applied after the KServe controller whose webhook validates it. `serviceAccount.create: true` adds a
ServiceAccount of the same name and sets `spec.template.serviceAccountName` to it, unless the spec already names
one. KServe's storage initializer reads `HF_TOKEN` from the secrets listed on that ServiceAccount, which is how a
gated Hugging Face model gets its token.

vLLM serving Gemma 4 12B on one GPU, with no router:

```yaml
llmInferenceServices:
  - name: gemma-4-12b
    serviceAccount:
      create: true
      secrets:
        - hf-token # a Secret with key HF_TOKEN, in the same namespace
    spec:
      model:
        uri: hf://google/gemma-4-12B-it-qat-w4a16-ct
        name: google/gemma-4-12B-it-qat-w4a16-ct
      replicas: 1
      # One GPU: the old pod has to release it before the new one can start.
      rolloutStrategy:
        maxSurge: 0
        maxUnavailable: 1
      template:
        containers:
          - name: main
            image: vllm/vllm-openai:v0.33.0
            # KServe runs the args through a shell eval, so quote JSON inside the string.
            args:
              - --max-model-len
              - "262144"
              - --kv-cache-dtype
              - fp8
              - --limit-mm-per-prompt
              - "'{\"image\":0,\"video\":0,\"audio\":0}'"
            # KServe requires a non-root user; 2000:0 is the vLLM image's own user.
            securityContext:
              runAsUser: 2000
              runAsGroup: 0
            resources:
              limits:
                nvidia.com/gpu: "1"
```

Without a router, the model is served by the Service `<name>-kserve-workload-svc` on port 8000.

### Ingress

`ingress.enabled: true` adds an Ingress of the same name for `ingress.host`, pointing at that Service. It gets sync
wave `2`, after the `LLMInferenceService`. `tlsSecretName` adds TLS for the host, and `serviceName`, `servicePort` and
`path` change the backend. For example, behind an internal Traefik with a cert-manager certificate:

```yaml
llmInferenceServices:
  - name: gemma-4-12b
    ingress:
      enabled: true
      className: traefik-internal
      host: llm.example.com
      tlsSecretName: llm-example-com-tls
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
    spec: {} # as above
```

vLLM has no API key by default, so anyone who can reach the host can use the model.

## Updating

KServe tags its charts with a `v` prefix, which `helm show chart` skips, so the weekly Helm update leaves this chart
on its pinned version. To bump it, set all six versions in `Chart.yaml`, then run:

```sh
bin/manage-helm-chart.sh --update-helm-chart kserve
```
