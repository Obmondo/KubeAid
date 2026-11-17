# egress-node-labeller

Keeps the `kubeaid.io/egress-gateway` label on exactly the HCloud node that currently holds a given Hetzner Cloud
Floating IP. The chart runs Obmondo's
[egress-node-labeller](https://github.com/Obmondo/dockerfiles/tree/main/egress-node-labeller)
(`ghcr.io/obmondo/egress-node-labeller`) as a single-replica Deployment. On every interval it looks up the Floating
IP's server in the Hetzner Cloud API, labels the node whose `spec.providerID` is `hcloud://<server ID>`, and removes
the label from every other node labelled `instance.hetzner.cloud/provided-by=cloud`. This chart is authored in
KubeAid (not a vendored upstream wrapper).

## Why it's in KubeAid

A `CiliumEgressGatewayPolicy` selects its gateway node by label, and Cilium OSS doesn't follow a Floating IP when it
moves. With [hcloud-fip-controller](../hcloud-fip-controller) moving the Floating IP between nodes, this chart moves
the label with it, so the policy's `egressGateway.nodeSelector` always matches the node Hetzner routes the Floating
IP to.

## Prerequisites

- A Secret (default name `cloud-credentials`) in the release namespace with key `hcloud` (a Hetzner Cloud API
  token). KubeAid's cluster bootstrap creates it in `kube-system` — see
  [cluster-api-operator/docs/hetzner.md](../cluster-api-operator/docs/hetzner.md).
- A Hetzner Cloud Floating IP in the same HCloud project.
- HCloud nodes with `spec.providerID` set by the hcloud CCM.

## Key values / KubeAid-specific configuration

| Value | Default | Meaning |
|---|---|---|
| `floatingIPName` | `""` | Name of the Floating IP to follow. Required — rendering fails when empty. |
| `cloudCredentialsSecretName` | `cloud-credentials` | Secret holding the hcloud token. |
| `cloudCredentialsSecretKey` | `hcloud` | Key of the hcloud token in that Secret. |
| `cronInterval` | `1m` | How often the labeller reconciles. |
| `image.repository` / `image.tag` | `ghcr.io/obmondo/egress-node-labeller` / `v1.0.0` | Labeller image. |

## Operational notes

- The ServiceAccount has exactly cluster-wide `list` and `patch` on `nodes`.
- The label is applied with an empty value (`kubeaid.io/egress-gateway: ""`), so the egress gateway policy must
  match that value.
- Failover lag is up to `cronInterval` after hcloud-fip-controller moves the Floating IP.

## Docs links

- Cilium egress gateway: <https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/>
- Hetzner Cloud Floating IPs: <https://docs.hetzner.com/cloud/floating-ips/overview/>
