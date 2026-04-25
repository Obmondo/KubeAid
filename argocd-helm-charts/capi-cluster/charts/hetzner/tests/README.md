# Testing the `hetzner` subchart

This directory contains the test suite for the `capi-cluster/charts/hetzner`
Helm chart. Testing is split into three layers that are all runnable locally
and in CI, with no running Kubernetes cluster required:

1. **Schema validation** – `values.schema.json` is generated from `values.yaml`
   and enforced by Helm on every `install` / `upgrade` / `template`. Invalid
   values fail fast with a clear error instead of producing broken manifests.
2. **Unit tests on rendered templates** – `helm-unittest` renders the chart
   against known inputs and asserts on the rendered Kubernetes manifests.
3. **End-to-end `helm template` dry-runs** – render the two example values
   files (`values.example.hcloud.yaml`, `values.example.bare-metal.yaml`,
   and the existing `values.example.yaml` for hybrid) and inspect the output.

## Prerequisites

```bash
# Helm 3
helm version

# helm-unittest plugin (matching Helm 3.15.x locally)
helm plugin install https://github.com/helm-unittest/helm-unittest.git --version v0.5.2

# helm-schema plugin (for regenerating values.schema.json)
helm plugin install https://github.com/dadav/helm-schema
```

Paths below are given relative to the repository root.

## 1. Unit tests (`helm-unittest`)

Run the full suite from the repository root:

```bash
helm unittest argocd-helm-charts/capi-cluster/charts/hetzner
```

Expected output:

```
 PASS  bare-metal mode with private network
 PASS  bare-metal mode with public network
 PASS  cluster naming and labels
 PASS  hcloud mode with private network
 PASS  hcloud mode with public network
 PASS  hybrid mode, private control-plane network
 PASS  hybrid mode, public control-plane load-balancer

Charts:      1 passed, 1 total
Test Suites: 7 passed, 7 total
Tests:       39 passed, 39 total
```

Run a single suite:

```bash
helm unittest -f 'tests/hcloud-public_test.yaml' \
  argocd-helm-charts/capi-cluster/charts/hetzner
```

### Example values files

All fixtures used by this test suite live at the chart root, next to
`values.yaml`, and follow the naming pattern `values.example.*.yaml`. There
is no separate `ci/` directory.

| File                                         | `mode`       | `network.type` | Includes `global:`? | Notes                                                                 |
| -------------------------------------------- | ------------ | -------------- | ------------------- | --------------------------------------------------------------------- |
| `values.example.hcloud.yaml`                 | `hcloud`     | `private`      | No                  | User-facing example to paste under `hetzner:` in the parent chart.    |
| `values.example.bare-metal.yaml`             | `bare-metal` | `public`       | No                  | User-facing example to paste under `hetzner:` in the parent chart.    |
| `values.example.hybrid.private-network.yaml` | `hybrid`     | –              | Yes                 | Self-contained fixture; renders the subchart standalone.              |
| `values.example.hybrid.public-network.yaml`  | `hybrid`     | –              | Yes                 | Self-contained fixture; renders the subchart standalone.              |
| `values.example.yaml`                        | `hybrid`     | –              | Yes                 | Original hybrid example from #1451, kept as a minimal reference.      |

The `values.example.hcloud.yaml` and `values.example.bare-metal.yaml` files
deliberately **omit** the `global:` block because `global.*` is owned by the
parent `capi-cluster` chart and should be authored there, not copied into
every subchart example. Anything that renders these files in isolation
(unit tests, `helm template` dry-runs) has to supply `global.*` on the CLI
or in `set:`.

The `values.example.hybrid.*.yaml` fixtures do include a `global:` block
because they are the fixtures the hybrid unit tests consume — those tests
are intentionally self-contained so they match 1:1 with the hybrid rendering
scenarios without any CLI overrides.

### What each suite covers

Each row shows the values fixture the suite loads via `values:` and any
additional overrides pinned in its `set:` block.

| Suite                              | `mode`       | `network.type` | Values fixture (`values:`)                        | Explicit `set:` overrides           |
| ---------------------------------- | ------------ | -------------- | ------------------------------------------------- | ----------------------------------- |
| `hcloud-private_test.yaml`         | `hcloud`     | `private`      | `../values.example.hcloud.yaml`                   | `mode`, `network.type`, `global.*`  |
| `hcloud-public_test.yaml`          | `hcloud`     | `public`       | `../values.example.hcloud.yaml`                   | `mode`, `network.type`, `global.*`  |
| `bare-metal-private_test.yaml`     | `bare-metal` | `private`      | `../values.example.bare-metal.yaml`               | `mode`, `network.type`, `global.*`  |
| `bare-metal-public_test.yaml`      | `bare-metal` | `public`       | `../values.example.bare-metal.yaml`               | `mode`, `network.type`, `global.*`  |
| `hybrid-private-network_test.yaml` | `hybrid`     | –              | `../values.example.hybrid.private-network.yaml`   | –                                   |
| `hybrid-public-network_test.yaml`  | `hybrid`     | –              | `../values.example.hybrid.public-network.yaml`    | –                                   |
| `cluster-name-label_test.yaml`     | `hybrid`     | –              | `../values.example.hybrid.private-network.yaml`   | –                                   |

Each scenario asserts the specific differences the chart is supposed to make:

- `hcloud` + `private`: `HetznerCluster` has `hcloudNetwork`,
  `HCloudMachineTemplate.spec.template.spec.publicNetwork.enableIPv4/v6=false`,
  `KubeadmControlPlane` and `KubeadmConfigTemplate` include the
  `/connect-nat-gateway.sh` file and invocation, no bare-metal resources.
- `hcloud` + `public`: `hcloudNetwork` is omitted, `publicNetwork.enableIPv4/v6=true`,
  no NAT-gateway script, no bare-metal resources.
- `bare-metal` + `private`: no `hcloudNetwork`, no `HCloudMachineTemplate`,
  6 `HetznerBareMetalHost` documents rendered (3 CP + 2 × 2 workers),
  NAT-gateway script present on the control plane.
- `bare-metal` + `public`: same as above but NAT-gateway script omitted.
- `hybrid` (private/public): control-plane on HCloud, bare-metal workers
  attached via vSwitch. Covered by the suites added in #1451.

## 2. Rendering the example values

`helm template` is the quickest way to eyeball what the chart would produce
for a given input. The chart expects three `global.*` values that normally
come from the parent `capi-cluster` chart, so pass them explicitly when
rendering the subchart in isolation.

The `values.example.hcloud.yaml` and `values.example.bare-metal.yaml` files
omit `global:` (see the section above), so when rendering them standalone
you must pass `global.*` on the CLI. The hybrid fixtures are self-contained
and do not need any overrides.

```bash
# hcloud + private — the default network.type inside values.example.hcloud.yaml
helm template demo argocd-helm-charts/capi-cluster/charts/hetzner \
  -f argocd-helm-charts/capi-cluster/charts/hetzner/values.example.hcloud.yaml \
  --set global.clusterName=demo \
  --set global.kubernetes.version=v1.33.0 \
  --set global.pods.cidrBlock=10.244.0.0/16 \
  --set-json 'global.additionalUsers=[]'

# hcloud + public — flip network.type on the CLI
helm template demo argocd-helm-charts/capi-cluster/charts/hetzner \
  -f argocd-helm-charts/capi-cluster/charts/hetzner/values.example.hcloud.yaml \
  --set network.type=public \
  --set global.clusterName=demo \
  --set global.kubernetes.version=v1.33.0 \
  --set global.pods.cidrBlock=10.244.0.0/16 \
  --set-json 'global.additionalUsers=[]'

# bare-metal + public — the default network.type inside values.example.bare-metal.yaml
helm template demo argocd-helm-charts/capi-cluster/charts/hetzner \
  -f argocd-helm-charts/capi-cluster/charts/hetzner/values.example.bare-metal.yaml \
  --set global.clusterName=demo \
  --set global.kubernetes.version=v1.33.0 \
  --set global.pods.cidrBlock=10.244.0.0/16 \
  --set-json 'global.additionalUsers=[]'

# hybrid — self-contained, no overrides needed
helm template demo argocd-helm-charts/capi-cluster/charts/hetzner \
  -f argocd-helm-charts/capi-cluster/charts/hetzner/values.example.hybrid.private-network.yaml

helm template demo argocd-helm-charts/capi-cluster/charts/hetzner \
  -f argocd-helm-charts/capi-cluster/charts/hetzner/values.example.hybrid.public-network.yaml
```

A quick way to see exactly what `network.type` toggles:

```bash
diff <(helm template demo argocd-helm-charts/capi-cluster/charts/hetzner \
        -f argocd-helm-charts/capi-cluster/charts/hetzner/values.example.hcloud.yaml \
        --set global.clusterName=demo --set global.kubernetes.version=v1.33.0 \
        --set global.pods.cidrBlock=10.244.0.0/16 --set-json 'global.additionalUsers=[]') \
     <(helm template demo argocd-helm-charts/capi-cluster/charts/hetzner \
        -f argocd-helm-charts/capi-cluster/charts/hetzner/values.example.hcloud.yaml \
        --set network.type=public \
        --set global.clusterName=demo --set global.kubernetes.version=v1.33.0 \
        --set global.pods.cidrBlock=10.244.0.0/16 --set-json 'global.additionalUsers=[]')
```

You should see exactly three differences:

- `HetznerCluster.spec.hcloudNetwork` is present on `private`, absent on `public`.
- `HCloudMachineTemplate.spec.template.spec.publicNetwork.enableIPv4/v6` flips
  from `false` → `true`.
- `KubeadmControlPlane.spec.kubeadmConfigSpec` (and `KubeadmConfigTemplate`)
  drops the `/connect-nat-gateway.sh` file and its invocation.

## 3. Schema validation

`values.schema.json` is generated from the `@schema` annotations in
`values.yaml`. Regenerate it after any change to `values.yaml`:

```bash
helm-schema \
  -c argocd-helm-charts/capi-cluster/charts/hetzner \
  -n --append-newline
```

The schema enforces, among other things:

- `mode` ∈ `{hcloud, bare-metal, hybrid}`
- `network.type` ∈ `{private, public}`
- `hcloud.cidrBlock`, `hcloud.subnetCidrBlock` match `^[0-9.]+/[0-9]+$`
- `controlPlane.regions` is a non-empty array of non-empty strings
- `controlPlane.hcloud.replicas` is an integer ≥ 1

A typo such as `--set network.type=publuc` is rejected by `helm` up front:

```
Error: values don't meet the specifications of the schema(s) in the following chart(s):
hetzner:
- network.type: network.type must be one of the following: "private", "public"
```

## 4. Lint the parent chart

```bash
helm lint argocd-helm-charts/capi-cluster
# → 1 chart(s) linted, 0 chart(s) failed
```

## Adding a new scenario

1. Add / extend a `values.example.*.yaml` fixture at the chart root. If the
   scenario is a "user-facing example to paste under `hetzner:` in the
   parent chart", omit `global:` and plan to pass it via `set:` in the
   suite. If the scenario is a pure test fixture, keep `global:` inside
   the file so the suite stays self-contained.
2. Create `tests/<scenario>_test.yaml` following the shape of an existing
   file in this directory – set `mode` / `network.type` / any overrides in
   `set:` and assert on the rendered documents you care about.
3. Run `helm unittest argocd-helm-charts/capi-cluster/charts/hetzner` and
   make sure the new suite is picked up and passes.
4. If you touched `values.yaml`, regenerate `values.schema.json` (see §3).
