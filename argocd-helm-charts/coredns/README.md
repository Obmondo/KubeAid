# CoreDNS

[CoreDNS](https://coredns.io) is the DNS server running in every Kubernetes cluster, resolving Service names and
forwarding external queries upstream.

Unlike most charts in this repo, this is **not** a wrapper around an upstream chart — it deploys no CoreDNS of
its own. It is a small KubeAid-authored chart that manages the `coredns-custom` ConfigMap, the extension point
that managed CoreDNS deployments (notably **Azure AKS**) import for custom server blocks.

## Why it's in KubeAid

On AKS the CoreDNS deployment is managed by the platform and cannot be edited directly; custom DNS forwarding has
to go through the `coredns-custom` ConfigMap. This chart lets you declare those conditional forwarders in Git and
roll them out via Argo CD like everything else, instead of hand-editing a ConfigMap — the typical use case being
private/internal zones that must resolve through specific resolvers (e.g. an Azure DNS Private Resolver).

## Key values / KubeAid-specific configuration

Everything lives under the `customDNS` key (disabled by default):

```yaml
customDNS:
  enabled: true
  cache: 30              # optional: cache duration in seconds
  dnsServers: >-         # ordered, one per line — the forward targets
    1.1.1.1
    8.8.8.8
  domainList:            # zones whose queries go to the servers above
    - example.com
    - example.io
```

For each domain in `domainList`, the chart renders a CoreDNS server block using the `forward` plugin (with
`errors`, `log`, and optional `cache`) into the `coredns-custom` ConfigMap in the release namespace.

## Name rewrites (`rewrites`)

A `rewrite` answers a query for one name as if it were for another, so a pod that resolves a
**public** host name gets the ClusterIP of a **Service inside the cluster**:

```yaml
rewrites:
  - from: keycloak.example.com
    to: traefik-internal.traefik.svc.cluster.local
```

The point is that no IP address is written down. The alternative people reach for is pod
`hostAliases` with the ingress Service's ClusterIP, and that IP changes the moment the
Service is deleted and recreated — after which every pod that pinned it fails to resolve the
name, silently and everywhere at once. A Service DNS name survives that.

`to` has to be a name CoreDNS can answer itself, so a Service. Each entry renders
`rewrite name exact <from> <to> answer auto` into the `kubeaid.override` key of
`coredns-custom`; `answer auto` rewrites the reply back, so the client sees the name it
asked for and TLS verification still works against the public certificate.

Rewrites go in the **default** server block, not a new one, which is why they are an
`.override` key rather than a `.server` key.

## Operational notes

- The ConfigMap only takes effect on CoreDNS setups that import `coredns-custom` (AKS does this out of the box).
  On self-managed clusters this chart renders the ConfigMap but nothing consumes it unless you wire that up:
  add the two import lines to the `coredns` ConfigMap in `kube-system` once, and mount this ConfigMap into
  the CoreDNS Deployment at `/etc/coredns/custom`:

  ```
  .:53 {
      import /etc/coredns/custom/*.override
      ...
  }
  import /etc/coredns/custom/*.server
  ```

  CoreDNS reloads it on its own (the `reload` plugin) within about two minutes. Check a rewrite with
  `kubectl -n kube-system logs deploy/coredns` and a lookup from any pod.

## Docs links

- CoreDNS `forward` plugin: <https://coredns.io/plugins/forward/>
- AKS custom CoreDNS config: <https://learn.microsoft.com/en-us/azure/aks/coredns-custom>
- Azure DNS Private Resolver: <https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview>
- [KubeAid: Helm umbrella pattern](../../docs/kubeaid/helm-umbrella-pattern.md)
