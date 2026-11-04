# Cilium

[Cilium](https://cilium.io) is an eBPF-based CNI providing pod networking, network policy (L3-L7), service load
balancing, and network observability (via Hubble) for Kubernetes.

## Why it's in KubeAid

Cilium is the platform CNI on KubeAid clusters. `kubeaid-cli` deploys it as one of the first Argo CD Applications,
and the KubeAid defaults run it in **kube-proxy replacement mode** — Cilium's eBPF datapath handles Service load
balancing, so no kube-proxy runs on the nodes. The sibling [`kubeaid-addons`](../kubeaid-addons) chart builds on it,
rendering `CiliumNetworkPolicy` objects (default-deny and per-component) that this chart's CNI enforces.

## Key values / KubeAid-specific configuration

Upstream values live under the `cilium:` key. KubeAid defaults (`values.yaml`):

- `cilium.kubeProxyReplacement: "true"` — kube-proxy-less datapath.
- `cilium.socketLB.hostNamespaceOnly: true` — scopes socket-level Service translation to the host namespace so that
  packets *forwarded* by pods (routers, VPN gateways such as the netbird-operator's `NetworkRouter`) still get
  per-packet Service VIP translation instead of blackholing on the node.
- `cilium.routingMode: tunnel` + `tunnelProtocol: vxlan` — pod traffic is encapsulated, so no pod routes need to be
  programmed into the underlying (cloud) network. `ipam.mode: kubernetes`.
- Hubble relay and UI enabled, with dns/drop/tcp/flow/icmp/http metrics.
- Operator and agent pods run with `priorityClassName: system-node-critical` and roll out on config change.

Two KubeAid-specific top-level keys render extra manifests from this wrapper's `templates/`:

- `hostNetworkPolicy` — a `CiliumClusterwideNetworkPolicy` (`kubeaid-host-firewall`) that locks down the host
  endpoint on every node: cluster-internal traffic by identity, SSH only from `allowSshFrom`, apiserver/etcd ports
  only from `apiserverSourceCIDRs`, DHCP replies (68/UDP) only from `dhcpServerCIDRs`, all ports from the cluster's
  private L2 subnets in `privateCIDRs`, plus `publicPorts` (default 80/443) and ICMP echo from the world. Disabled by default; enable it on bare-metal clusters where the public NIC
  has no cloud security group in front of it. See the [host-firewall guide](../../docs/guides/cilium-host-firewall.md).
- `loadBalancerIPPool` — a list of CIDRs rendered into a `CiliumLoadBalancerIPPool` so Cilium LB-IPAM assigns them
  to `type: LoadBalancer` Services on bare-metal clusters without a cloud load balancer. Empty list = no pool.

Override per cluster from your kubeaid-config values file:

```yaml
hostNetworkPolicy:
  enabled: true
  allowSshFrom: ["203.0.113.0/24"]
  apiserverSourceCIDRs: ["198.51.100.10", "198.51.100.11"]
  dhcpServerCIDRs: ["10.0.0.1"]   # Hetzner Cloud network gateway, for nodes addressed by DHCP
  privateCIDRs: ["10.0.1.0/24"]   # the vSwitch / private network the nodes share

loadBalancerIPPool:
  - 192.0.2.240/29
```

## Operational notes

- Enabling the host firewall on a running cluster is safe-ordered: the identity rule allowing cluster-internal
  traffic comes first to avoid locking out etcd/kubelet. Still, validate `allowSshFrom` before syncing — an empty
  list means SSH stays open to the world.
- Set `dhcpServerCIDRs` on every cluster whose nodes get their address by DHCP (e.g. Hetzner Cloud control planes
  on a private network). Without it, the first `systemd-networkd` restart (needrestart after unattended-upgrades)
  leaves the node unable to renew its lease, and it loses its address when the lease runs out (24h on Hetzner).
- Set `privateCIDRs` to the subnet of the nodes' private L2 (Hetzner vSwitch, cloud private network). Cilium
  trusts a node's addresses only once the CCM publishes them, so a node that already uses its private address for
  the VXLAN tunnel and kubelet traffic is "world" to its peers until then, and a joining control plane can sit
  unreachable for CAPH and KCP although it is Ready.
- Argo CD is configured (in the [`argo-cd`](../argo-cd) chart) to exclude `CiliumIdentity`/`CiliumEndpoint`/
  `CiliumEndpointSlice` from tracking, to cut watched-event noise.

## Docs links

- Upstream chart & docs: <https://helm.cilium.io/> / <https://docs.cilium.io/>
- [KubeAid: Cilium host-firewall policy](../../docs/guides/cilium-host-firewall.md)
- [KubeAid: Helm umbrella pattern](../../docs/kubeaid/helm-umbrella-pattern.md)
