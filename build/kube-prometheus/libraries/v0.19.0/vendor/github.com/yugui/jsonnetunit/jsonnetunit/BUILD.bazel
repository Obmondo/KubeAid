package(default_visibility = ["//visibility:public"])

licenses(["notice"])  # Apache 2.0

load("@io_bazel_rules_jsonnet//jsonnet:jsonnet.bzl", "jsonnet_library")

exports_files(["jsonnetunit.bzl"])

jsonnet_library(
    name = "jsonnetunit",
    srcs = [
        "matcher.libsonnet",
        "std_matchers.libsonnet",
        "test.libsonnet",
    ],
    visibility = ["//visibility:public"],
)
