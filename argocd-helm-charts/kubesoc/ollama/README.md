# ollama

Self-hosted LLM runtime, wrapped from [otwld/ollama-helm](https://github.com/otwld/ollama-helm).
Use it when a workload must call a model without any data leaving the cluster.

## 1. How to setup

```yaml
ollama:
  ollama:
    models:
      pull:
        - mistral:7b
  persistentVolume:
    size: 50Gi
```

The service listens on port 11434 inside the cluster (`http://ollama:11434`). There is no
authentication in Ollama, so leave `ingress.enabled: false` and add a CiliumNetworkPolicy from
kubeaid-addons that admits only the namespaces that need it. Egress is only needed for the
initial model pull; block it afterwards if the cluster must not talk to the internet.

## 2. GPU

```yaml
ollama:
  ollama:
    gpu:
      enabled: true
      type: nvidia
      number: 1
```

Requires the NVIDIA device plugin (or the hami chart for shared GPUs) on the node.

## 3. Models

The kubesoc AI assistant (dfir-iris `aiTriage`) defaults to `mistral:7b` (Apache-2.0):
about 5 GB of RAM at 4-bit, 30-70 s per answer on a few CPU cores. On a GPU node,
`mistral-small3.1` (24B, Apache-2.0, about 16 GB VRAM at 4-bit, 128k context) writes
noticeably better case summaries and hunting queries; pull it and set
`dfir-iris.aiTriage.model: mistral-small3.1`. Both support the JSON-schema `format`
the assistant relies on.

## Air-gapped model service (`networkPolicy`)

`networkPolicy.enabled: true` restricts the Ollama pod to DNS egress and to
ingress on 11434 from the peers in `networkPolicy.allowedFrom`. Prompts often
carry sensitive data (alerts, user names, IP addresses), so nothing the model
receives can leave the cluster, and nothing outside the listed peers can use
the unauthenticated API.

With egress closed, `ollama.ollama.models.pull` must be empty: the chart pulls
models in a postStart hook, and a failed pull kills the container. Pull the
model once with egress open (or copy it onto the volume, or serve it from an
internal OCI registry), then enable the policy and empty the pull list.

To pull with the policy on, set `networkPolicy.allowModelDownload: true` together
with the pull list: it adds HTTPS egress to the internet (private ranges
excluded). Once the pod is ready with the model on the volume, set it back to
`false` and empty the pull list.
