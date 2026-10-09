JSONNET ?= jsonnet
BUILD   ?= build

.PHONY: all clean fmt
all: $(BUILD)/prometheus_alerts.yaml $(BUILD)/prometheusrule.yaml $(BUILD)/helm-values.yaml dashboards

$(BUILD):
	mkdir -p $(BUILD)

# Plain Prometheus rule file: groups of alerts
$(BUILD)/prometheus_alerts.yaml: $(BUILD) mixin.libsonnet config.libsonnet alerts/alerts.libsonnet
	$(JSONNET) -J . -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts, quote_keys=false)' > $@

# prometheus-operator CRD
$(BUILD)/prometheusrule.yaml: $(BUILD) prometheusrule.jsonnet mixin.libsonnet config.libsonnet alerts/alerts.libsonnet
	$(JSONNET) -J . -S prometheusrule.jsonnet > $@

# Helm values: flat prometheusRule.rules list
$(BUILD)/helm-values.yaml: $(BUILD) helm-values.jsonnet mixin.libsonnet config.libsonnet alerts/alerts.libsonnet
	$(JSONNET) -J . -S helm-values.jsonnet > $@

# One JSON file per dashboard
.PHONY: dashboards
dashboards: $(BUILD)
	mkdir -p $(BUILD)/dashboards
	$(JSONNET) -J . -m $(BUILD)/dashboards -e '(import "mixin.libsonnet").grafanaDashboards'

fmt:
	find . -name '*.libsonnet' -o -name '*.jsonnet' | xargs -n1 jsonnetfmt -i

clean:
	rm -rf $(BUILD)
