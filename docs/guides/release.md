# KubeAid Release Process

This guide outlines the steps to update managed charts and publish a new release of KubeAid.

## 1. Update Managed Helm Charts

The first step is to synchronize all managed Helm charts with their upstream sources. This script will update the charts and automatically switch you to a new branch for your Pull Request.

### Option A: Standard (Linux/Native)
If you have `yq` (Go version), `helm`, and `git` installed locally:

```bash
./bin/manage-helm-chart.sh --update-all

Branch 'Helm_Update_20260119_MjA5NDkK' set up to track remote branch 'master' from 'origin'.
Switched to a new branch 'Helm_Update_20260119_MjA5NDkK'
Current KubeAid version: 23.0.0
Helm chart argo-cd is cached and on latest version 9.2.4...
```
### Option B: Docker Environment (macOS)
For macOS users or to ensure a clean environment, use the provided Docker workflow.
1. Start the Builder Container Run this from the root of the repo to mount your current directory into an Ubuntu container:
   ```bash
   docker run --rm -it -v $(pwd):/build -w /build ubuntu:24.04 bash
   ```
2. Configure Environment Inside the running container, execute the following block to install dependencies and trigger the update:
   ```bash
   apt-get update && apt-get install -y git curl
   curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq
   curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
   chmod 700 get_helm.sh && ./get_helm.sh
   ./bin/manage-helm-chart.sh --update-all
   ```

## 2. Publish a New Release of KubeAid
once the Pull Request from Step 1 is merged into `master`, generate the release notes and tag the release.
    
    ```sh
    ./bin/release.sh
    Generating release notes since 22.0.0..23.0.0
    Release notes generated: CHANGELOG.md
    [master 22bed5336] chore(doc): Update changelog
    2 files changed, 178 insertions(+), 115 deletions(-)
    rewrite .release-notes.md (97%)
    ```

## 2A. Manual Minor/Patch Release (Without Chart Updates)
Use this process when you need to publish a minor or patch release without running `manage-helm-chart.sh` (for example: feature changes, bug fixes, documentation updates, or internal improvements).

### Steps

1. Pull latest master
   ```bash
   git checkout master
   git pull origin master
   ```

2. Update the VERSION file

3. Stage the version change
   ```bash
   git add VERSION
   ```

4. Run release script
   ```bash
   ./bin/release.sh
   ```
