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
