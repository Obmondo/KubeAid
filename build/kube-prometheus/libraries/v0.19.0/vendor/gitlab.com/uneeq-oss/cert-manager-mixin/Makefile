# Prometheus Mixin Makefile
# Heavily copied from upstream project kubenetes-mixin
# How to use:
# With docker -> make
# Without docker (in CI) -> make SKIP_DOCKER=true

# Make defaults
# https://tech.davis-hansson.com/p/make/
# Use commonly available shell
SHELL := bash
# Fail if piped commands fail - critical for CI/etc
.SHELLFLAGS := -eu -o pipefail -c
# Use one shell for a target, rather than shell per line
.ONESHELL:

JSONNET_CMD := jsonnet
JSONNET_FMT_CMD := jsonnetfmt

ifneq ($(SKIP_DOCKER),true)
	PROMETHEUS_DOCKER_IMAGE := prom/prometheus:latest
	# TODO: Find out why official prom images segfaults during `test rules` if not root
    PROMTOOL_CMD := docker pull ${PROMETHEUS_DOCKER_IMAGE} && \
		docker run \
			--user root \
			-v $(PWD):/tmp \
			-w /tmp \
			--entrypoint promtool \
			$(PROMETHEUS_DOCKER_IMAGE)
else
	PROMTOOL_CMD := promtool
endif

all: fmt prometheus_alerts.yaml prometheus_rules.yaml dashboards_out lint-jsonnet test ## Generate files, lint and test

clean: ## Clean up generated files
	rm -rf manifests/

fmt: ## Format Jsonnet
	find . -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNET_FMT_CMD) -i

dashboards_out: mixin.libsonnet lib/dashboards.jsonnet dashboards/*.libsonnet ## Generate Dashboards JSON
	@mkdir -p manifests
	$(JSONNET_CMD) -m manifests lib/dashboards.jsonnet

lint-jsonnet:
	$(JSONNET_FMT_CMD) --version
	export failed=0
	export fs='$(shell find . -name '*.jsonnet' -o -name '*.libsonnet')'
	if [ $${#fs} -gt 0 ]; then
		for f in $${fs}; do
			if [ -e $${f} ]; then $(JSONNET_FMT_CMD) "$$f" | diff -u "$$f" - || export failed=1; fi
		done
	fi
	if [ "$$failed" -eq 1 ]; then
		exit 1
	fi

prometheus_alerts.yaml: mixin.libsonnet lib/alerts.jsonnet alerts/*.libsonnet ## Generate Alerts YAML
	@mkdir -p manifests
	$(JSONNET_CMD) -S lib/alerts.jsonnet > manifests/$@

prometheus_rules.yaml: mixin.libsonnet lib/rules.jsonnet rules/*.libsonnet ## Generate Rules YAML
	@mkdir -p manifests
	$(JSONNET_CMD) -S lib/rules.jsonnet > manifests/$@

test: ## Test generated files
	$(PROMTOOL_CMD) check rules manifests/prometheus_rules.yaml
	$(PROMTOOL_CMD) check rules manifests/prometheus_alerts.yaml
	$(PROMTOOL_CMD) test rules tests.yaml

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
