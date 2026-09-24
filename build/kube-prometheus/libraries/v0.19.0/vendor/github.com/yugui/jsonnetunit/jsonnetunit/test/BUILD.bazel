package(default_visibility = ["//visibility:private"])

licenses(["notice"])  # Apache 2.0

load("@io_bazel_rules_jsonnet//jsonnet:jsonnet.bzl", "jsonnet_to_json_test")
load("@com_github_yugui_jsonnetunit//jsonnetunit:jsonnetunit.bzl", "jsonnet_test")

# Tests jsonnet_test rule
jsonnet_test(
    name = "test_test",
    src = "test_test.jsonnet",
)

# Tests :jsonnetunit
jsonnet_to_json_test(
    name = "test_golden_test",
    src = "test_test.jsonnet",
    golden = "golden/test_test.golden",
    deps = ["@com_github_yugui_jsonnetunit//jsonnetunit"],
)

jsonnet_to_json_test(
    name = "failure_golden_test",
    src = "failure_test.jsonnet",
    error = 1,
    golden = "golden/failure_test.golden",
    regex = 1,
    deps = ["@com_github_yugui_jsonnetunit//jsonnetunit"],
)

jsonnet_test(
    name = "std_matchers_test",
    src = "std_matchers_test.jsonnet",
)

jsonnet_to_json_test(
    name = "std_matchers_failure_test",
    src = "std_matchers_failure_test.jsonnet",
    error = 1,
    golden = "golden/std_matchers_failure_test.golden",
    regex = 1,
    deps = ["@com_github_yugui_jsonnetunit//jsonnetunit"],
)
