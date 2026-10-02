# velociraptor

Velociraptor (Velocidex/Rapid7, AGPL-3.0) endpoint visibility and DFIR server, wrapped from
[MaximeWewer/velociraptor-helm](https://github.com/MaximeWewer/velociraptor-helm).

## 1. How to setup

The chart never generates the server config. Do that out of band, once, with the final
frontend hostname, because every client pins the server certificate that lives in it:

```bash
velociraptor config generate -i     # answer: self-signed, frontend host, GUI host
```

Store the result as a sealed Secret named `velociraptor-server-config` with the key
`server.config.yaml` in the release namespace. Minimal values:

```yaml
velociraptor:
  gui:
    ingress:
      enabled: true
      hosts:
        - host: velociraptor.example.com
  frontend:
    service:
      type: LoadBalancer   # clients need raw TLS to port 8000
```

## 2. Single replica

Velociraptor has no HA. `frontend.minions` only spreads client load and needs a
ReadWriteMany datastore, so keep `replicaCount: 1` unless you have RWX storage.

## 3. SSO

`gui.oidc` overlays an OIDC block into the config through an init container. Point it at a
Keycloak client with `clientId: velociraptor` and the client secret in `gui.oidc.existingSecret`.

## 4. Image

The upstream chart ships the author's hardened, rootless rebuild of Velociraptor
(`ghcr.io/maximewewer/velociraptor`). For production, build your own image from the official
binary and override `image.registry` / `image.repository`.
