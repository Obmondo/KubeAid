# KubeAid Release Process

This guide outlines the steps to update managed charts and publish a new release of KubeAid.

## Prerequisites

The following tools are required locally:

- `bash`
- `git`
- `helm` (>= 3.8.0)
- `yq` (Go version)

The repository must have the `github` remote configured for pushing to GitHub.

## 1. Update Managed Helm Charts

The first step is to synchronize all managed Helm charts with their upstream sources. This script will update the charts
and automatically switch you to a new branch for your Pull Request.

### Option A: Standard (Linux/Native)

```bash
./bin/manage-helm-chart.sh --update-all
```

Example output:

```log
Branch 'Helm_Update_20260119_MjA5NDkK' set up to track remote branch 'master' from 'origin'.
Switched to a new branch 'Helm_Update_20260119_MjA5NDkK'
Current KubeAid version: 23.0.0
Helm chart argo-cd is cached and on latest version 9.2.4...
```

### Option B: Docker Environment (macOS)

The script requires Linux (GNU sed). For macOS users, use the provided Docker workflow.

1. Start the Builder Container from the root of the repo:

   ```bash
   docker run --rm -it -v $(pwd):/build -w /build ubuntu:24.04 bash
   ```

2. Inside the container, install dependencies and run the update:

   ```bash
   apt-get update && apt-get install -y git curl
   curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq
   curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
   chmod 700 get_helm.sh && ./get_helm.sh
   ./bin/manage-helm-chart.sh --update-all
   ```

### Script Options

| Option | Description | Default |
| --- | --- | --- |
| `--add-helm-chart NAME REPO_URL VERSION` | Add a new Helm chart | Requires all 3 args |
| `--update-helm-chart CHART` | Update a specific Helm chart | Requires chart name |
| `--update-all` | Update all Helm charts | false |
| `--skip-charts CHARTS` | Comma-separated list of charts to skip | none |
| `--chart-version VERSION` | Set chart version to update to | latest |
| `--actions` | Run in CI/CD mode (GitHub/Gitea Actions) | false |
| `-h, --help` | Show help message | |

### Examples

Update a specific chart:

```bash
./bin/manage-helm-chart.sh --update-helm-chart traefik
```

Update a specific chart to a specific version:

```bash
./bin/manage-helm-chart.sh --update-helm-chart traefik --chart-version 25.0.0
```

Update all charts but skip some:

```bash
./bin/manage-helm-chart.sh --update-all --skip-charts 'aws-efs-csi-driver,capi-cluster,grafana-operator,strimzi-kafka-operator'
```

Add a new chart:

```bash
./bin/manage-helm-chart.sh --add-helm-chart my-chart https://example.com/charts 1.2.3
```

## 2. Merge the Pull Request

Review and merge the Helm chart update PR into `master`.

## 3. Bump the VERSION File

Update the `VERSION` file at the root of the repo with the new release version before running the release script.
The release script reads this file to determine the new tag and will fail if the tag already exists.

## 4. Publish a New Release

Once the PR is merged and `VERSION` is updated, generate the release notes and tag the release:

```bash
./bin/release.sh
```

Example output:

```log
Generating release notes since 22.0.0..23.0.0
Release notes generated: CHANGELOG.md
[master 22bed5336] chore(release): update CHANGELOG and Release Notes for Kubeaid 23.0.0
2 files changed, 178 insertions(+), 115 deletions(-)
rewrite .release-notes.md (97%)
```

The script will:

1. Verify you are on the `master` branch
2. Pull the latest changes from `origin master`
3. Categorize all commits since the last tag (features, bug fixes, chart updates, etc.)
4. Generate `CHANGELOG.md` and `.release-notes.md`
5. Commit the changelog and release notes
6. Create an annotated git tag from the `VERSION` file
7. Push the commit and tag to both **Gitea** (`origin`) and **GitHub** (`github`)

After the tag is pushed, GoReleaser CI workflows run automatically on both Gitea and GitHub to
publish the release using the generated `.release-notes.md`.
