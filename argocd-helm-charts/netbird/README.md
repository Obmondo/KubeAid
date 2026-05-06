# Netbird Installation

## Installing Netbird Server

This Helm chart is for self hosting [Netbird](https://netbird.io).

This document outlines the steps to customize the Helm installation for Coturn and Netbird services with KeyCloak IdP.

Refer the example [values.yaml](./examples/values.yaml) for additional configurations.
You can simply copy-paste the values file in your kubeaid-config, and replace the necessary values to get Netbird working.

### Keycloak realm prerequisites

NetBird Mgmt and the cluster's `kube-apiserver` both authenticate users against
the same Keycloak realm via OIDC. The realm needs a specific set of clients,
one client scope, an audience mapper, and one service-account role grant
before NetBird Mgmt and `kubelogin` will work.

When `kubeaid-cli` is run with `cluster.keycloak.mode: managed`, it creates
all of this automatically through the Keycloak admin API. **In `mode: external`
(or when not using `kubeaid-cli` at all) the realm has to be configured by
hand** — replicate the resources below in your existing Keycloak.

NetBird's own [Keycloak IdP guide](https://docs.netbird.io/selfhosted/identity-providers#keycloak)
covers the upstream UI flow; the list here is the kubeaid-specific overlay
(audience scope, kubelogin redirect URIs, `view-users` grant) that NetBird's
docs don't include.

#### Clients

| Client ID | Access Type | Standard flow | Service Accounts | Used for |
|---|---|---|---|---|
| `netbird-client`              | public (PKCE)              | enabled  | — | NetBird Mgmt UI browser SSO |
| `netbird-backend`             | confidential (with secret) | disabled | enabled | NetBird Mgmt → Keycloak admin API for user lookup |
| `kubernetes-<cluster-name>`   | public (PKCE)              | enabled  | — | `kubelogin` (kube-apiserver `--oidc-client-id`) |

For `netbird-client`:

- **Valid Redirect URIs**: `https://<netbird-mgmt-host>/*` (e.g. `https://vpn.example.com/*`)
- **Web Origins**: `https://<netbird-mgmt-host>`

For `netbird-backend`:

- **Standard Flow Enabled**: off
- **Direct Access Grants Enabled**: off
- **Service Accounts Enabled**: on (required — its auto-created
  service-account user is what gets the `view-users` role below)
- Copy the generated **Client Secret** into the NetBird Mgmt values
  (`netbird.management.idpManagerConfig.clientSecret`).

For `kubernetes-<cluster-name>`:

- **Valid Redirect URIs**: `http://localhost:8000`, `http://localhost:18000`
  (kubelogin's default callback ports). Add more if your operators use
  different `--listen-port` values.

#### Client scope: `api`

Create a single client scope shared by all three clients above:

- **Name**: `api`
- **Protocol**: `openid-connect`
- **Description**: `NetBird Management API audience`

Attach it as a **Default Client Scope** to `netbird-client`,
`netbird-backend`, and `kubernetes-<cluster-name>`.

#### Protocol mapper on the `api` scope

On the `api` client scope, add one mapper:

- **Name**: `Audience for NetBird Management API`
- **Mapper Type**: `Audience`
- **Included Custom Audience**: `https://<netbird-mgmt-host>` (matches the
  `netbird-client` Web Origins entry)
- **Add to ID token**: on
- **Add to access token**: on

This is what asserts the `aud` claim on tokens NetBird Mgmt receives.

#### Service-account role grant

`netbird-backend` needs `view-users` on the realm-management client so it
can resolve user identities through Keycloak's admin API:

1. Open the `netbird-backend` client → **Service Account Roles** tab.
2. Set **Client Roles** to `realm-management`.
3. Add the `view-users` role from **Available Roles** to **Assigned Roles**.

Without this grant NetBird Mgmt logs `unable to get keycloak token,
statusCode 401` (see Troubleshooting below).

### Set Up Ingress for Netbird Services

This will use gRPC protocol.

```yaml
netbird:
  <service-name>:
    service:
      port: <service-port>
    ingress:
      enabled: true
      annotations:
        traefik.ingress.kubernetes.io/service.serversscheme: h2c
      className: traefik-cert-manager
      tls:
        - hosts:
            - vpn.example.com
          secretName: vpn.example.com
      hosts:
        - host: vpn.example.com
          paths:
            - path: <ingress-path>
              pathType: ImplementationSpecific
```

## Setup Netbird Client

Install netbird cli and connect to netbird vpn.

> Always ensure the netbird server and client version ALWAYS match to avoid any conflicts/inconsistencies.

```sh
$ netbird up --management-url https://vpn.example.com:443 --admin-url https://vpn.example.com
Connected
```

Check peers connected and connect to them

```sh
$ netbird status -d                                                                          
Peers detail:
 thinkpad.netbird.selfhosted:
  NetBird IP: <sensitive>
  Public key: <sensitive>
  Status: Idle
  -- detail --
  Connection type: P2P
  ICE candidate (Local/Remote): -/-
  ICE candidate endpoints (Local/Remote): -/-
  Relay server address: 
  Last connection update: 3 seconds ago
  Last WireGuard handshake: -
  Transfer status (received/sent) 0 B/0 B
  Quantum resistance: false
  Networks: -
  Latency: 0s

 precision.netbird.selfhosted:
  NetBird IP: <sensitive>
  Public key: <sensitive>
  Status: Connected
  -- detail --
  Connection type: P2P
  ICE candidate (Local/Remote): host/host
  ICE candidate endpoints (Local/Remote): <sensitive>/<sensitive>
  Relay server address: 
  Last connection update: 1 second ago
  Last WireGuard handshake: 1 second ago
  Transfer status (received/sent) 124 B/180 B
  Quantum resistance: false
  Networks: -
  Latency: 146.790093ms

Events:
  [INFO] SYSTEM (0a22a9fe-e3ea-499e-8912-a59cbb211e62)
    Message: Network map updated
    Time: 3 seconds ago
OS: linux/amd64
Daemon version: 0.55.1
CLI version: 0.55.1
Profile: default
Management: Connected to https://vpn.example.com:443
Signal: Connected to https://vpn.example.com:443
Relays: 
  [stun:stun.vpn.example.com:3478] is Available
  [turn:turn.vpn.example.com:3478?transport=udp] is Unavailable, reason: allocate: Allocate error response (error 401: Unauthorized)
  [rels://vpn.example.com:443/relay] is Available
Nameservers: 
FQDN: viljkid.netbird.selfhosted
NetBird IP: <sensitive>
Interface type: Kernel
Quantum resistance: false
Lazy connection: false
Networks: 10.96.0.0/16
Forwarding rules: 0
Peers count: 1/2 Connected
```

### Troubleshooting

#### GET /api/users status 401

Netbird caches the Keycloak users locally. If it is not able to fetch the users from Keycloak, it throws an error with

```log
unable to get keycloak token, statusCode 401
```

**Solution:**

- Set the log level to Debug for the netbird-management pod with `--log-level=debug` as the container arg
- Check the pod logs about token not found
- Check if the service account `netbird-backend` has the permission to `view-users` in Keycloak
- Check if the `AdminEndpoint` in the IdPManagerConfig is correct `https://keycloak.example.com/auth/admin/realms/netbird`

Once this is correct, Netbird pod should be able to warm up the cache and fetch user IDs.

#### Find the netbird routing

Show routing network with only netbird interface.

> To show all routing table for all interfaces, instead of `netbird` interface, provide `all`.

```sh
$ ip route show table netbird   
10.230.56.31 dev enableit-in 
10.230.56.33 dev enableit-in 
10.230.56.43 dev enableit-in 
10.230.56.45 dev enableit-in 
10.230.56.60 dev enableit-in 
10.230.56.62 dev enableit-in 
```

#### Check which IP will route to which interface

```sh
$ ip route get 10.230.56.60
10.230.56.60 dev enableit-in table netbird src 100.108.22.129 uid 1000 
    cache 
```

#### Capture the packet details across peers

1. On one peer, do `tcpdump` to get package traffic info.

    ```sh
    $ tcpdump -i wt0
    tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
    listening on wt0, link-type RAW (Raw IP), snapshot length 262144 bytes
    09:25:55.471331 IP sidharth-jawale.netbird.example.52214 > 10.230.56.60.25: Flags [S], seq 4130107208, win 64480, options [mss 1240,sackOK,TS val 1588962935 ecr 0,nop,wscale 7], length 0
    09:25:55.477104 IP 10.230.56.60.25 > sidharth-jawale.netbird.example.52214: Flags [S.], seq 1275207684, ack 4130107209, win 8192, options [mss 1240,nop,wscale 8,sackOK,TS val 942730381 ecr 1588962935], length 0
    09:25:55.705020 IP sidharth-jawale.netbird.example.52214 > 10.230.56.60.25: Flags [.], ack 1, win 504, options [nop,nop,TS val 1588963212 ecr 942730381], length 0
    09:25:55.710578 IP 10.230.56.60.25 > sidharth-jawale.netbird.example.52214: Flags [P.], seq 1:118, ack 1, win 1026, options [nop,nop,TS val 942730613 ecr 1588963212], length 117: SMTP: 220 example-web01 Microsoft ESMTP MAIL Service, Version: 10.0.14393.4169 ready at  Mon, 22 Dec 2025 09:25:55 +0100 
    09:25:55.964251 IP sidharth-jawale.netbird.example.52214 > 10.230.56.60.25: Flags [.], ack 118, win 504, options [nop,nop,TS val 1588963463 ecr 942730613], length 0
    09:26:04.354941 IP sidharth-jawale.netbird.example.52214 > 10.230.56.60.25: Flags [P.], seq 1:7, ack 118, win 504, options [nop,nop,TS val 1588971809 ecr 942730613], length 6: SMTP: quit
    09:26:04.360327 IP 10.230.56.60.25 > sidharth-jawale.netbird.example.52214: Flags [P.], seq 118:180, ack 7, win 1026, options [nop,nop,TS val 942739253 ecr 1588971809], length 62: SMTP: 221 2.0.0 example-web01 Service closing transmission channel
    09:26:04.360341 IP 10.230.56.60.25 > sidharth-jawale.netbird.example.52214: Flags [F.], seq 180, ack 7, win 1026, options [nop,nop,TS val 942739253 ecr 1588971809], length 0
    09:26:04.674374 IP sidharth-jawale.netbird.example.52214 > 10.230.56.60.25: Flags [.], ack 180, win 504, options [nop,nop,TS val 1588972168 ecr 942739253], length 0
    09:26:04.675017 IP sidharth-jawale.netbird.example.52214 > 10.230.56.60.25: Flags [F.], seq 7, ack 181, win 504, options [nop,nop,TS val 1588972168 ecr 942739253], length 0
    09:26:04.680312 IP 10.230.56.60.25 > sidharth-jawale.netbird.example.52214: Flags [.], ack 8, win 1026, options [nop,nop,TS val 942739584 ecr 1588972168], length 0
    ^C
    11 packets captured
    11 packets received by filter
    0 packets dropped by kernel
    ```

2. On another peer, telnet to the internal IP of the above peer.

    > Ensure the masquerade toggle is enabled to allow netbird to update the nftables accordingly.

    ```sh
    $ telnet 10.230.56.60 25
    Trying 10.230.56.60...
    Connected to 10.230.56.60.
    Escape character is '^]'.
    220 example-web01 Microsoft ESMTP MAIL Service, Version: 10.0.14393.4169 ready at  Mon, 22 Dec 2025 09:25:55 +0100 
    quit
    221 2.0.0 example-web01 Service closing transmission channel
    Connection closed by foreign host.
    ```

#### Check the network forwarding rules via nftables

> Ensure the forwarding filter is present.

```sh
$ nft list table netbird
table ip netbird {
 set nb0000722 {
  type ipv4_addr
  flags dynamic
  elements = { 100.108.22.129, 100.108.200.32 }
 }

 set nb0000757 {
  type ipv4_addr
  flags dynamic
  elements = { 100.108.22.129, 100.108.200.32 }
 }

 set nb0000886 {
  type ipv4_addr
  flags dynamic
  elements = { 100.108.22.129, 100.108.200.32 }
 }

 set nb-dccc54ad {
  type ipv4_addr
  flags interval
  elements = { 100.108.22.129, 100.108.200.32 }
 }

 chain netbird-rt-fwd {
  ct state established,related counter packets 0 bytes 0 accept
  ip saddr @nb-dccc54ad ip daddr 192.168.4.0/24 tcp dport 25 counter packets 0 bytes 0 accept
  ip saddr @nb-dccc54ad ip daddr 192.168.4.0/24 tcp dport 8089 counter packets 0 bytes 0 accept
  ip saddr @nb-dccc54ad ip daddr 192.168.4.0/24 tcp dport 53 counter packets 0 bytes 0 accept
  ip saddr @nb-dccc54ad ip daddr 10.230.56.33 tcp dport 25 counter packets 7 bytes 420 accept
  ip saddr @nb-dccc54ad ip daddr 10.230.56.33 tcp dport 8089 counter packets 0 bytes 0 accept
  ip saddr @nb-dccc54ad ip daddr 10.230.56.33 tcp dport 53 counter packets 0 bytes 0 accept
 }

 chain netbird-rt-postrouting {
  type nat hook postrouting priority srcnat - 1; policy accept;
  meta mark 0x0001bd21 oifname != "lo" counter packets 0 bytes 0 masquerade
  meta mark 0x0001bd22 oifname "wt0" counter packets 0 bytes 0 masquerade
 }

 chain netbird-rt-redirect {
  type nat hook prerouting priority dstnat; policy accept;
 }

 chain netbird-mangle-postrouting {
  type filter hook postrouting priority mangle; policy accept;
  oifname "wt0" ct state new ct mark set 0x0001bd11
 }

 chain netbird-mangle-prerouting {
  type filter hook prerouting priority mangle; policy accept;
  iifname != "wt0" ct state new ip saddr 10.230.56.33 meta mark set 0x0001bd22
  iifname "wt0" ct state new ip daddr 10.230.56.33 meta mark set 0x0001bd21
  iifname != "wt0" ct state new ip saddr 192.168.4.0/24 meta mark set 0x0001bd22
  iifname "wt0" ct state new ip daddr 192.168.4.0/24 meta mark set 0x0001bd21
  iifname "wt0" ct state new ct mark set 0x0001bd10
  iifname "wt0" ip saddr @nb0000722 tcp dport 25 fib daddr type local meta mark set 0x0001bd20
  iifname "wt0" ip saddr @nb0000757 tcp dport 8089 fib daddr type local meta mark set 0x0001bd20
  iifname "wt0" ip saddr @nb0000886 tcp dport 53 fib daddr type local meta mark set 0x0001bd20
 }

 chain netbird-acl-input-rules {
  ct state established,related counter packets 1821 bytes 150618 accept
  ip saddr @nb0000722 tcp dport 25 accept
  ip saddr @nb0000757 tcp dport 8089 accept
  ip saddr @nb0000886 tcp dport 53 accept
 }

 chain netbird-acl-input-filter {
  type filter hook input priority filter; policy accept;
  iifname "wt0" jump netbird-acl-input-rules
  iifname "wt0" drop
 }

 chain netbird-acl-forward-filter {
  type filter hook forward priority filter; policy accept;
  meta mark 0x0001bd20 accept
  iifname "wt0" jump netbird-rt-fwd
  iifname "wt0" drop
 }
}
```

### References and External Links

- https://docs.netbird.io/about-netbird/how-netbird-works
- https://docs.netbird.io/selfhosted/identity-providers#keycloak
- https://docs.netbird.io/selfhosted/troubleshooting
