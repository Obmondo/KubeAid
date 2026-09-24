# kubeaid kube-prometheus build

Use `build.sh` to compile kube-prometheus manifests for a Kubernetes cluster from a jsonnet vars file.

> **NOTE:** v0.16.0 is a special release. The upstream kube-prometheus v0.16.0 had an issue which was resolved by pointing to this patch commit: [prometheus-operator/kube-prometheus#2733](https://github.com/prometheus-operator/kube-prometheus/pull/2733)

## Compatibility

The following Kubernetes versions are supported and work as we test against these versions in their respective branches. Other versions might work too!

> **Note:** In CI we test only the last two releases on a regular basis.

| kube-prometheus | Kubernetes 1.26 | Kubernetes 1.27 | Kubernetes 1.28 | Kubernetes 1.32 | Kubernetes 1.33 | Kubernetes 1.34 | Kubernetes 1.35 | Kubernetes 1.36 | Kubernetes 1.37 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| v0.13.0 | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| v0.16.0 | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| v0.17.0 | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ |
| v0.18.0 | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ |
| **v0.19.0** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | **✓** | **✓** | **✓** |

You can refer the upstream kube-prometheus x kubernetes [Compatibility Matrix](https://github.com/prometheus-operator/kube-prometheus#compatibility) to find latest updates.

You can also run `./build/kube-prometheus/build.sh --versions` to see this table in the terminal.

## Prerequisites

### Install Go and jsonnet tooling

```sh
snap install go
export PATH=$PATH:$(go env GOPATH)/bin

go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/brancz/gojsontoyaml@latest
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
```

### Mac OS

```sh
brew install bash
brew install jsonnet
```

## Cluster vars file

Each cluster needs a `<cluster-name>-vars.jsonnet` file. See the [examples folder](./examples) for reference.

## Running the build script

Run from the root of this repo, with your kubeaid-config repo cloned next to it:

```sh
./build/kube-prometheus/build.sh ../<your-kubeaid-config>/k8s/<cluster-name>
```

Example output:

```log
Successfully built for <cluster-name> (kube-prometheus v0.16.0) in 3s → ../<your-kubeaid-config>/k8s/<cluster-name>/kube-prometheus
```

## Committing manifests with --commit

To automatically commit the generated manifests into your kubeaid-config repo:

```sh
./build/kube-prometheus/build.sh --commit ../<your-kubeaid-config>/k8s/<cluster-name>
```

This creates a timestamped branch, commits only the `kube-prometheus/` changes, then asks whether to push the branch (for a PR) or rebase it into the current branch:

```log
Successfully built for <cluster-name> (kube-prometheus v0.16.0) in 3s → ../<your-kubeaid-config>/k8s/<cluster-name>/kube-prometheus

 2 files changed, 12 insertions(+), 25 deletions(-)

  >>> Touch your YubiKey to sign the commit <<<

Push branch 'kube-prometheus-<cluster-name>-v0.16.0-20260328143022' or rebase into 'master'? [push/rebase]
```

## Available flags

| Flag | Description |
|------|-------------|
| `--commit` | Commit generated manifests in a new branch in the kubeaid-config repo |
| `-d` / `--debug` | Leave temporary output folder on exit |

---

## Further reading

- [Mixins](docs/mixins.md) — adding new mixins, custom Prometheus rules
- [Prometheus Operator Options](docs/prometheus.md) — component options, deleting metrics
- [Grafana](docs/grafana.md) — custom dashboards, alertmanager secret, Keycloak, password reset, air-gapped deployment
- [Upgrading](docs/upgrading.md) — upgrading versions, updating vendor deps, adding new versions, cleaning up
- [Debugging & Testing](docs/debugging.md) — jsonnet debugging, lint, unit tests, e2e tests, CI
