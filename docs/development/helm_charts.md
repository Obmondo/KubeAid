# Adding/Updating new charts to argocd-helm-charts

## Usage

### Add a new chart

```sh
./bin/helm-repo-update.sh --add-new-chart <chart-name> <chart-url> <version> 
```

### Update a specific chart

```sh
./bin/helm-repo-update.sh --update-helm-chart <name-of-chart>
```

### Update a specific chart to a specific version

```sh
./bin/helm-repo-update.sh --update-helm-chart <name-of-chart> --chart-version <version>
```

### Update all charts

```sh
./bin/helm-repo-update.sh --update-all
```

### Update all charts except certain ones

```sh
./bin/helm-repo-update.sh --update-all --skip-charts 'chart1,chart2,chart3'
```

**Note**: `--skip-charts` must be used with `--update-all` or `--update-helm-chart`

### Get help

```sh
./bin/helm-repo-update.sh --help
```

Note:

- Remove the database dependency charts coming with upstream chart.
- We use `db-operators` to manage the databases.
For example `postgres-operator` for postgres for postgresql database and so on.
<!-- markdownlint-disable -->
- Check
[doc](https://github.com/Obmondo/KubeAid/tree/main/argocd-helm-charts/postgres-operator/README.md) about postgres operator and how that works.
<!-- markdownlint-enable -->
