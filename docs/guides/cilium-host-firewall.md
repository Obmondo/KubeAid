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
- Allows DHCP replies (68/UDP) only from the listed DHCP servers
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
  dhcpServerCIDRs: []           # DHCP servers whose replies (68/UDP) are allowed; empty = no DHCP rule emitted
  privateCIDRs: []              # Subnets of the nodes' private L2 (vSwitch), trusted on all ports; empty = no rule emitted
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

## Nodes on a Private L2 (vSwitch)

Cilium trusts a node's addresses only once the cloud controller manager publishes them on the Node object.
A node that uses its private-network address earlier, for the VXLAN tunnel or for kubelet traffic, is
"world" to its peers until then, and the policy drops that traffic on every port except the public ones.
On a bare-metal cluster with a vSwitch this leaves a freshly joined control plane unreachable for CAPH and
KCP although the node is Ready. List the private subnet in `privateCIDRs`; the rule allows all ports from
it, the same trust the identity rule gives node traffic:

```yaml
hostNetworkPolicy:
  enabled: true
  privateCIDRs:
    - "10.0.1.0/24"             # The vSwitch subnet shared by all nodes
```

## Nodes That Get Their Address by DHCP

The policy applies to every node, so it also filters DHCP. A DHCP client renews its lease by unicast, and
the reply matches conntrack and passes. When `systemd-networkd` restarts (for example needrestart after
unattended-upgrades), the client starts over with a broadcast. The server's unicast reply then matches
no conntrack entry and is dropped. The node keeps its old address only until the lease runs out (24 hours
on Hetzner Cloud), then loses it: kubelet, etcd and SSH all stop at once. Nodes created together run
their first unattended-upgrade in the same window, so a whole control plane can lose its addresses within
minutes of each other.

If any node gets its address by DHCP, list the DHCP servers in `dhcpServerCIDRs`. On a Hetzner Cloud
network this is the network gateway, the first IP of the network's IP range:

```yaml
hostNetworkPolicy:
  enabled: true
  dhcpServerCIDRs:
    - "10.0.0.1"                # Gateway of the 10.0.0.0/16 Hetzner Cloud network
```

`kubeaid-cli` does not set this value; add it to your per-cluster Cilium values overlay. To confirm the
rule works, restart `systemd-networkd` on one node and check that the journal logs
`DHCPv4 address ... acquired` within seconds. Without the rule, Hubble shows the replies as
`POLICY_DENIED` ingress drops from the DHCP server's port 67 to UDP port 68 on the node.

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
