# SOGo Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/sogo&style=flat-square)](https://artifacthub.io/packages/search?repo=sogo)
[![GitHub License](https://img.shields.io/github/license/sonroyaalmerol/docker-sogo?style=flat-square)](https://github.com/sonroyaalmerol/docker-sogo/blob/main/LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/sonroyaalmerol/docker-sogo?style=flat-square)](https://github.com/sonroyaalmerol/docker-sogo/releases)
[![GitHub Downloads](https://img.shields.io/github/downloads/sonroyaalmerol/docker-sogo/total?style=flat-square)](https://github.com/sonroyaalmerol/docker-sogo/releases)
[![OCI security profiles](https://img.shields.io/badge/oci%3A%2F%2F-sogo-blue?logo=kubernetes&logoColor=white&style=flat-square)](https://github.com/sonroyaalmerol/docker-sogo/packages)


A helm chart for the docker-sogo docker image

> [!IMPORTANT]
> This chart is still in its beta stage. Do not use in production.

## Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

Once Helm is set up properly, add the repository as follows:

```console
helm repo add sogo https://helm.snry.xyz/docker-sogo/
```

Running `helm search repo sogo` should now display the chart and it's versions

To install the helm chart, use
```console
helm install sogo sogo/sogo --create-namespace --namespace sogo
```

## Values

You can find the `values.yaml` summary in [the charts directory](https://github.com/sonroyaalmerol/docker-sogo/blob/main/charts/sogo/values.yaml)