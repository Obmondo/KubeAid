# ollama

Self-hosted LLM runtime, wrapped from [otwld/ollama-helm](https://github.com/otwld/ollama-helm).
Use it when a workload must call a model without any data leaving the cluster.

## 1. How to setup

```yaml
ollama:
  ollama:
    models:
      pull:
        - llama3.1:8b
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
