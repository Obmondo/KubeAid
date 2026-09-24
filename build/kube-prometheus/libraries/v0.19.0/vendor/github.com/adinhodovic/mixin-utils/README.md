# Mixin-utils

[![CI](https://github.com/adinhodovic/mixin-utils/actions/workflows/ci.yml/badge.svg)](https://github.com/adinhodovic/mixin-utils/actions/workflows/ci.yml)

Utils for mixins. Generic utilities for building Grafana dashboards and Prometheus alerts using Jsonnet and Grafonnet.

## Overview

mixin-utils is a Jsonnet library that provides reusable helper functions for creating Grafana dashboards. It simplifies the creation of common panel types (stats, time series, pie charts, tables, heatmaps, gauges, logs, and more) with sensible defaults while still allowing customization.

## Installation

### Using jsonnet-bundler

Install mixin-utils with:

```bash
jb install github.com/adinhodovic/mixin-utils@main
```

## Usage

### Basic Example

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashUtils = (import 'github.com/adinhodovic/mixin-utils/utils.libsonnet').dashboards;

local dashboard = g.dashboard;

dashboard.new('My Dashboard')
+ dashboard.withPanels([
  dashUtils.statPanel(
    title='Total Requests',
    unit='short',
    query='sum(http_requests_total)',
    description='Total number of HTTP requests',
  ),
  
  dashUtils.timeSeriesPanel(
    title='Request Rate',
    unit='reqps',
    query=[
      { expr: 'sum(rate(http_requests_total[5m]))', legend: '{{status}}' },
    ],
    calcs=['mean', 'max'],
  ),
])
```

## Available Functions

### Panel Functions

- **`statPanel()`** - Create stat panels with optional graph mode and sparklines
- **`timeSeriesPanel()`** - Create time series panels with support for stacking and multiple queries
- **`pieChartPanel()`** - Create pie charts for distribution visualization
- **`tablePanel()`** - Create table panels with custom transformations and sorting
- **`heatmapPanel()`** - Create heatmap panels for distribution over time
- **`gaugePanel()`** - Create gauge panels with thresholds
- **`textPanel()`** - Create text/markdown panels for documentation
- **`logsPanel()`** - Create Loki logs panels
- **`stateTimelinePanel()`** - Create state timeline panels

### Helper Functions

- **`bypassDashboardValidation`** - Add required fields for grafana.com/dashboards validator
- **`dashboardDescriptionLink(name, link)`** - Generate standard dashboard description with link
- **`dashboardLinks(title, config, dropdown, includeVars)`** - Create dashboard links
- **`annotations(config, filters)`** - Create dashboard annotations

## Examples

See the [examples/](examples/) directory for comprehensive examples:

- [panel_examples.jsonnet](examples/panel_examples.jsonnet) - Individual examples of each panel type
- [basic_dashboard.jsonnet](examples/basic_dashboard.jsonnet) - Complete dashboard example

## Development

### Prerequisites

- Go 1.21+ (for building tools)
- Make

### Setup

Install dependencies:

```bash
make tmp/bin/jb
tmp/bin/jb install
```

### Available Make Targets

- `make all` - Run formatting, linting, and tests
- `make fmt` - Format Jsonnet and Markdown files
- `make lint` - Lint Jsonnet and Markdown files
- `make test` - Run unit tests and validate examples
- `make clean` - Remove generated files

### Running Tests

```bash
make test
```

Tests are located in the [tests/](tests/) directory and validate:
- Library imports work correctly
- Panel functions return expected structures
- All panel types can be created without errors

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `make all` to ensure tests pass and code is formatted
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Related Projects

This library is used by several monitoring mixins:

- [envoy-mixin](https://github.com/adinhodovic/envoy-mixin)
- [django-mixin](https://github.com/adinhodovic/django-mixin)
- [kubernetes-autoscaling-mixin](https://github.com/adinhodovic/kubernetes-autoscaling-mixin)
- [ingress-nginx-mixin](https://github.com/adinhodovic/ingress-nginx-mixin)

And many more!
