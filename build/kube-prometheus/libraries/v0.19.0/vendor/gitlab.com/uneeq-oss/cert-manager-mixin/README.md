# cert-manager Mixin

The cert-manager mixin is a collection of reusable and configurable [Prometheus](https://prometheus.io/) alerts, and a [Grafana](https://grafana.com) dashboard to help with operating [cert-manager](https://cert-manager.io/).

## Config Tweaks

There are some configurable options you may want to override in your usage of this mixin, as they will be specific to your deployment of cert-manager. They can be found in [config.libsonnet](config.libsonnet).

## Using the mixin with kube-prometheus

See the [kube-prometheus](https://github.com/coreos/kube-prometheus#kube-prometheus)
project documentation for examples on importing mixins.

## Using the mixin as raw files

If you don't use the jsonnet based `kube-prometheus` project then you will need to
generate the raw yaml files for inclusion in your Prometheus installation.

Install the `jsonnet` dependencies (we use versions v0.16+):

```shell
go get github.com/google/go-jsonnet/cmd/jsonnet
go get github.com/google/go-jsonnet/cmd/jsonnetfmt
```

Generate yaml:

```shell
make
```

To use the dashboard, it can be imported or provisioned for Grafana by grabbig the [cert-manager.json](dashboards/cert-manager.json) file as is.

## Manifests

Pre rendered manifests can also be found at https://monitoring.mixins.dev/cert-manager/
