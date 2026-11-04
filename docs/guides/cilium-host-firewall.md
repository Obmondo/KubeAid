# Cilium Host-Firewall Policy

KubeAid ships a `CiliumClusterwideNetworkPolicy` that locks down the host endpoint on every node.
Enable it on **bare-metal clusters** where the public NIC needs an ingress filter; leave it **disabled
on cloud clusters** that rely on cloud-provider security groups instead.

## Overview

When enabled, the policy:

- Allows cluster-internal traffic by Cilium identity (node-to-node etcd/kubelet, pods, apiserver,
  health probes, localhost)
- Allows admin SSH only from specified CIDRs
- Restricts the Kubernetes API server (port 6443) to explicit source CIDRs (the node public IPs -
  never the open internet)
- Allows DHCP replies (68/UDP), from the listed DHCP servers when set, otherwise from any source
- Allows HTTP (80) and HTTPS (443) plus ICMP from the world

The policy is **disabled by default**. There is no standalone `kubeaid-cli cluster lockdown`
subcommand; you enable it by setting `hostNetworkPolicy.enabled: true` in your per-cluster Cilium
values overlay (see Configuration below) and rolling it out via ArgoCD.

## Configuration

Set the following values in your per-cluster Cilium values overlay:

```yaml
hostNetworkPolicy:
  enabled: false                # Set to true to activate the host-firewall
  allowSshFrom: []              # CIDRs or bare IPs (treated as /32); empty = SSH open to world
  publicPorts: [80, 443]        # Service ports allowed from the world
  apiserverSourceCIDRs: []      # CIDRs/IPs allowed to reach 6443/TCP; empty = no 6443 rule emitted
  allowDhcpReplies: true        # Allow DHCP replies (68/UDP); false = no DHCP rule emitted
  dhcpServerCIDRs: []           # Narrow DHCP replies to these servers; empty = from any source
```

### Example: Bare-Metal Production Cluster

```yaml
hostNetworkPolicy:
  enabled: true
  allowSshFrom:
    - "203.0.113.0/24"          # Office VPN
    - "198.51.100.42"           # Jump host (treated as /32)
  publicPorts: [80, 443]
  apiserverSourceCIDRs:
    - "203.0.113.0/24"          # Office VPN
    - "10.0.0.0/8"              # Internal network
```

## When to Enable

| Cluster Type | Enable? | Reason |
| ------------ | ------- | ------ |
| Bare Metal | ✅ Yes | No cloud security group; the NIC is directly exposed |
| Hetzner Hybrid | ✅ Yes | Bare-metal workers have exposed NICs |
| HCloud-only | ❌ No | Hetzner Cloud firewall / security groups handle this |
| AWS / Azure | ❌ No | Cloud-provider security groups handle this |

## Nodes That Get Their Address by DHCP

The policy applies to every node, so it also filters DHCP. A DHCP client renews its lease by unicast, and
the reply matches conntrack and passes. When `systemd-networkd` restarts (for example needrestart after
unattended-upgrades), the client starts over with a broadcast. The server's unicast reply then matches
no conntrack entry and is dropped. The node keeps its old address only until the lease runs out (24 hours
on Hetzner Cloud), then loses it: kubelet, etcd and SSH all stop at once. Nodes created together run
their first unattended-upgrade in the same window, so a whole control plane can lose its addresses within
minutes of each other.

So DHCP replies are allowed by default (`allowDhcpReplies: true`). Cilium policies cannot match a source
port, so without `dhcpServerCIDRs` the rule accepts UDP port 68 from any source. Only a DHCP client
listens on that port, and it ignores replies that do not carry its own transaction ID; on a node with a
static address nothing listens there at all. To accept replies from your DHCP server only, list it in
`dhcpServerCIDRs`. On a Hetzner Cloud network this is the network gateway, the first IP of the network's
IP range:

```yaml
hostNetworkPolicy:
  enabled: true
  dhcpServerCIDRs:
    - "10.0.0.1"                # Gateway of the 10.0.0.0/16 Hetzner Cloud network
```

Set `allowDhcpReplies: false` only when no node gets its address by DHCP. To confirm the rule works,
restart `systemd-networkd` on one node and check that the journal logs `DHCPv4 address ... acquired`
within seconds. Without the rule, Hubble shows the replies as `POLICY_DENIED` ingress drops from the
DHCP server's port 67 to UDP port 68 on the node.

## How It Works

The policy is templated at
[cilium/templates/host-firewall-policy.yaml](../../argocd-helm-charts/cilium/templates/host-firewall-policy.yaml)
and creates a `CiliumClusterwideNetworkPolicy` targeting the host endpoint. Traffic not matching any
allow rule is **dropped** by default (Cilium's host-firewall operates in default-deny mode when a policy
is attached to the host endpoint).

## Enabling After Pivot

After the cluster is bootstrapped and the management cluster has pivoted to the workload cluster,
apply the same `hostNetworkPolicy.enabled: true` values change and let ArgoCD sync it. Note that
`kubeaid-cli`'s interactive config prompt separately exposes a `lockdown` field that gets rendered
into the generated `cluster.lockdown` setting — that's unrelated config plumbing, not a trigger for
this policy.

## See Also

- [Cloud Providers](../hosting/cloud-providers.md) - provider-specific setup
- [Bare Metal](../hosting/bare-metal.md) - SSH-based provisioning
- [Cilium documentation: Host Firewall](https://docs.cilium.io/en/stable/security/host-firewall/)
