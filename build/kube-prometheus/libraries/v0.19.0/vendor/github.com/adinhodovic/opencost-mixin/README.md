# Prometheus Monitoring Mixin for OpenCost

A set of Grafana dashboards and Prometheus alerts for OpenCost.

## How to use

This mixin is designed to be vendored into the repo with your infrastructure config. To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

You then have three options for deploying your dashboards

1. Generate the config files and deploy them yourself
2. Use jsonnet to deploy this mixin along with Prometheus and Grafana
3. Use prometheus-operator to deploy this mixin

Or import the dashboard using json in `./dashboards_out`, alternatively import them from the `Grafana.com` dashboard page.

## Generate config files

You can manually generate the alerts, dashboards and rules files, but first you must install some tools:

```sh
go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
brew install jsonnet
```

Then, grab the mixin and its dependencies:

```sh
git clone https://github.com/adinhodovic/opencost-mixin
cd opencost
jb install
```

Finally, build the mixin:

```sh
make prometheus_alerts.yaml
make dashboards_out
```

The `prometheus_alerts.yaml` file then need to passed to your Prometheus server, and the files in `dashboards_out` need to be imported into you Grafana server. The exact details will depending on how you deploy your monitoring stack.

### Configuration

This mixin has its configuration in the `config.libsonnet` file. You can disable the alerts for cost alerts and anomalies by setting the `enabled` field to `false`.

```jsonnet
{
  _config+:: {
    alerts: {
      budget: {
        // Alerts if the cost is 200 USD (example).
        // You need to configure this alert.
        enabled: true,
        monthlyCostThreshold: 200,
      },
      anomaly: {
        // Alerts if the cost spiked by 20% or more
        enabled: true,
        anomalyPercentageThreshold: 20,
      },
    },
  },
}
```

The mixin has all components enabled by default and all the dashboards are generated in the `dashboards_out` directory. You can import them into Grafana.

## Alerts

The mixin follows the [monitoring-mixins guidelines](https://github.com/monitoring-mixins/docs#guidelines-for-alert-names-labels-and-annotations) for alerts.
