BIN_DIR ?= $(shell pwd)/tmp/bin

JSONNET_VENDOR=vendor
JB_BIN=$(BIN_DIR)/jb
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETLINT_BIN=$(BIN_DIR)/jsonnet-lint
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
MD_FILES = $(shell find . \( -type d -name '.vale' -o -type d -name 'vendor' \) -prune -o -type f -name "*.md" -print)
MARKDOWNFMT_BIN=$(BIN_DIR)/markdownfmt
VALE_BIN=$(BIN_DIR)/vale
TOOLING=$(JB_BIN) $(JSONNETLINT_BIN) $(JSONNET_BIN) $(JSONNETFMT_BIN) $(MARKDOWNFMT_BIN) $(VALE_BIN)
JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s

.PHONY: all
all: fmt lint test

.PHONY: fmt
fmt: jsonnet-fmt markdownfmt

.PHONY: jsonnet-fmt
jsonnet-fmt: $(JSONNETFMT_BIN)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

.PHONY: markdownfmt
markdownfmt: $(MARKDOWNFMT_BIN)
	@for file in $(MD_FILES); do $(MARKDOWNFMT_BIN) -w -gofmt $$file; done

.PHONY: lint
lint: jsonnet-lint vale

.PHONY: jsonnet-lint
jsonnet-lint: $(JSONNETLINT_BIN) $(JSONNET_VENDOR)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETLINT_BIN) -J vendor

.PHONY: vale
vale: $(VALE_BIN)
	@$(VALE_BIN) sync && \
		$(VALE_BIN) $(MD_FILES)

$(JSONNET_VENDOR): $(JB_BIN) jsonnetfile.json
	$(JB_BIN) install

.PHONY: test
test: $(JSONNET_BIN) $(JSONNET_VENDOR)
	@if [ -d tests ]; then \
		echo "Running unit tests..."; \
		for test_file in tests/*.jsonnet; do \
			if [ -f "$$test_file" ]; then \
				echo "  Running: $$test_file"; \
				$(JSONNET_BIN) -J vendor "$$test_file" > /dev/null || exit 1; \
			fi; \
		done; \
	fi
	@if [ -d examples ]; then \
		echo "Validating examples..."; \
		for example_file in examples/*.jsonnet; do \
			if [ -f "$$example_file" ]; then \
				echo "  Validating: $$example_file"; \
				$(JSONNET_BIN) -J vendor "$$example_file" > /dev/null || exit 1; \
			fi; \
		done; \
	fi
	@echo "All tests passed ✓"

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from scripts/tools.go
	@cd scripts && go list -e -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o $(BIN_DIR) %
