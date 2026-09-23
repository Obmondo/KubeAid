# OpenAPI app definitions for Shuffle

Shuffle's own app library is split. `github.com/shuffle/python-apps` holds 52
directories, of which 34 load on 2.2.1 — the rest fail validation with
`yaml: unmarshal errors`. Everything else, including every app this stack
needs, lives only in the cloud app store on shuffler.io and is not in any
public git repository.

These three were fetched from that store's public config endpoint and decoded
out of the base64 wrapper it returns:

| File | App | Paths | Operations | Store id |
| --- | --- | --- | --- | --- |
| `wazuh.json` | Wazuh 1.1.0 | 131 | 162 | `fb715a176a192687e95e9d162186c97f` |
| `misp.json` | MISP 1.1.0 | 128 | 133 | `c69ea55c02913030b1cd546f86187878` |
| `iris-v2.json` | IRIS v2 1.1.0 | 55 | 55 | `f5a4c255d4fab6b4ec6dece7d7e8dfb9` |

They are vendored here so the stack does not depend on shuffler.io being
reachable, or on those ids still resolving. That matters twice over: the bid
claims an air-gap-capable platform, and a runtime dependency on a US-linked
app store is the kind of thing an evaluator asks about.

To refetch or add another app, take its id from the store URL:

```bash
curl -s https://shuffler.io/api/v1/apps/<id>/config \
  | python3 -c 'import json,sys,base64; d=json.load(sys.stdin); \
      o=json.loads(base64.b64decode(d["openapi"])); print(o["body"])' \
  > <name>.json
```

## Importing them

`POST /api/v1/verify_openapi` takes the spec object itself with `editing` and
`id` merged in as top-level keys — not wrapped in `{"body": ...}`, which is how
the store returns it and which fails with `Info not parsed`.

The spec parses, then Shuffle builds the app into a container image. On
Kubernetes that runs as a `shuffle-app-builder` Job, and without a registry to
push to it fails with:

```
Job.batch "shuffle-app-builder" is invalid:
  spec.template.spec.volumes[1].secret.secretName: Required value
```

The backend only carries `REGISTRY_URL=docker.io` with no credentials. So
native OpenAPI apps need a container registry and a push secret before they
will build — which is the same registry an air-gapped deployment needs anyway,
so it is worth doing once rather than working around.

Until that exists, the built-in `http` app reaches all three products: they are
plain REST APIs, and the calls are already proven against the live instances
(MISP `/attributes/restSearch`, IRIS `/alerts/add`, Wazuh `/lists/files` and
`/cluster/analysisd/reload`).
