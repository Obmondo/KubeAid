# shuffle

Shuffle SOAR (AGPL-3.0 backend, MIT apps), wrapped from the chart published by the Shuffle
project at `oci://ghcr.io/shuffle/charts/shuffle`.

## 1. How to setup

Shuffle hardcodes its namespace: install it into a namespace called `shuffle`, one release
per namespace. Provide an OpenSearch cluster first (opensearch-operator chart), then:

```yaml
shuffle:
  shuffle:
    baseUrl: https://shuffle.example.com
  backend:
    openSearch:
      url: https://shuffle-opensearch:9200
      username: admin
```

The OpenSearch password, the first admin user, its API key and the encryption modifier are
read from Kubernetes Secrets, never from values (`SHUFFLE_OPENSEARCH_PASSWORD`,
`SHUFFLE_DEFAULT_USERNAME`, `SHUFFLE_DEFAULT_PASSWORD`, `SHUFFLE_DEFAULT_APIKEY`,
`SHUFFLE_ENCRYPTION_MODIFIER`). See `charts/shuffle/README.md` for the Secret names the
templates expect and create them as sealed Secrets in kubeaid-config.

## 2. What was removed

The upstream tarball bundles a single-node Bitnami OpenSearch subchart. It is pruned by
`.helm-prune` and `opensearch.enabled` stays false: databases come from operators in KubeAid,
and Bitnami no longer ships free images for it.

## 3. Outbound traffic

Shuffle downloads its app catalogue from GitHub (`backend.apps.downloadLocation`) and reports
to shuffler.io. On an air-gapped or sovereignty-constrained cluster, mirror the apps repo
internally and block egress with a CiliumNetworkPolicy from kubeaid-addons.
