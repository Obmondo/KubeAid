# Self-host your IAM with KubeAid

Every SaaS identity vendor sells you the same story. Login is hard, MFA is hard, SSO is hard, so hand it all to us and pay per user per month. It's a good pitch, right up until you count the users. At Obmondo we run identity for our own staff, for every managed cluster, and for a stack of internal apps, and the identity bill is zero. Not "cheap." Zero. The whole thing runs on Keycloak, which is open source, and it's wired into the platform by KubeAid so we don't spend our days clicking around an admin console.

This post is about how that actually works, what we gave up to get there, and where the paid vendors still make sense.

## The thing the perimeter used to do

The old model was a VPN and a flat network. You got onto the corporate network, and once you were in, you were trusted. Every internal dashboard, every admin panel, every cluster API sat behind that one wall. Breach the wall once and you had the run of the place.

We don't do that. Access at Obmondo is identity first: who you are decides what you can reach, and there is no "inside the network" that grants trust on its own. That model needs an identity provider that can front everything, speak OIDC and SAML, do group-based authorization, and enforce hardware MFA. Keycloak does all of it. The interesting part is not Keycloak itself, which has been around for years. It's the wiring.

## One Keycloak, authenticating everything

Here is where a KubeAid cluster's identity actually lands.

**kubectl.** Nobody at Obmondo has a static admin kubeconfig with a baked-in token. You authenticate to the cluster with your Keycloak login through `kubelogin` (the `oidc-login` kubectl plugin). The kube-apiserver is configured with `--oidc-issuer-url` pointing at the realm and `--oidc-client-id` set to the cluster's client, so the API server validates the token Keycloak minted. Your kubeconfig has no secret in it, just an exec block that shells out to `kubectl oidc-login get-token`. When you run `kubectl get nodes`, a browser window opens, you log in once, and the token is cached until it expires.

**RBAC by group, not by person.** The Keycloak client emits a `groups` claim in the token. On the cluster side, a `ClusterRoleBinding` binds a Kubernetes group straight to a `ClusterRole`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sre-admin
subjects:
- kind: Group
  name: <Keycloak group name>
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

Add someone to the `SRE` group in Keycloak and they get cluster-admin on the next token refresh. Remove them and it's gone. There is no per-user binding to chase, no offboarding checklist that leaves a stale kubeconfig alive somewhere on a laptop. Access is a group membership, and group membership lives in one place.

**Zero-trust mesh instead of a public API.** For clusters set up with `cluster.type: vpn`, the story goes further. After bootstrap, KubeAid disables the public kube-apiserver load balancer entirely and moves API access onto a [NetBird](https://netbird.io) mesh. NetBird is a self-hosted WireGuard overlay, and it authenticates peers against the same Keycloak realm the cluster uses. So the API server isn't just protected by a password, it isn't reachable at all unless you're a mesh peer, and you only become a peer by logging into Keycloak. Your identity gates the network and the API in one motion.

Getting NetBird and the kube-apiserver to agree on the same realm takes a precise set of Keycloak objects: a public PKCE client for the NetBird UI, a confidential backend client with a `view-users` grant on `realm-management` so NetBird can resolve user identities, a per-cluster `kubernetes-<name>` client for kubelogin, a shared `api` client scope, and an audience mapper that stamps the right `aud` claim on tokens. Miss the `view-users` grant and NetBird logs `unable to get keycloak token, statusCode 401`. This is exactly the kind of fiddly setup that people get wrong by hand, which is the whole reason KubeAid automates it.

**Apps that already speak OIDC.** Harbor, Argo CD, SonarQube, and others in the KubeAid catalog point their OIDC login straight at Keycloak. One set of credentials, one MFA prompt, one place to revoke.

**Apps that don't.** Plenty of internal tools have no real auth of their own: a dashboard here, an admin UI there. For those, KubeAid ships a `traefik-forward-auth` chart. Traefik forwards each incoming request to the forward-auth service via a middleware, it checks the user against Keycloak, and it returns allow or deny before the request ever reaches the app. You put OIDC login and optional RBAC in front of an app that was never designed for either, and you don't touch the app. Reference the middleware with a single ingress annotation:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: traefik-traefik-forward-auth@kubernetescrd
```

That covers the awkward long tail that identity projects usually leave exposed.
