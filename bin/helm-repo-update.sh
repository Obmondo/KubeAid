#!/bin/bash

set -eou pipefail

# This script requires Linux and bash to run
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: This script must be run on Linux"
  echo "Current OS: $(uname -s)"
  echo "This script uses GNU sed which is not compatible with BSD sed (macOS)"
  exit 1
fi

# Ensure we're running in bash
if [[ -z "$BASH_VERSION" ]]; then
  echo "Error: This script must be run in bash"
  echo "Current shell: $SHELL"
  echo "This script uses bash-specific features and syntax"
  exit 1
fi

for program in helm tar yq git; do
  if ! command -v "$program" >/dev/null; then
    echo "Error: Required program '$program' is not installed or not in PATH"
    echo "Please install $program and try again"
    exit 1
  fi
done

helm_version_full=$(helm version --template="{{.Version}}" | sed 's/^v//')
helm_version=$(echo "$helm_version_full" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')

if [ "$helm_version" -lt "30800" ] ; then
  echo "Error: Helm version must be >= 3.8.0 (found: $helm_version_full)"
  exit 1
fi

function ARGFAIL() {
  echo -n "
Usage $0 [OPTIONS]:
  --update-helm-chart       Update specific helm chart      [Need path to specific helm chart]
  --update-all              Update all the helm chart       [Default: false]
  --pull-request            Raise Pull request              [Default: false] (Only in CI)
  --actions                 Run inside a GitHub or Gitea Action   [Default: false] (Only in CI)
  --skip-charts             Skip updating certain charts    [Default: none]
  --chart-version           Helm chart version              [Default: latest]
  --add-commits             Add commits since last tag in changelog   [Default: false]
  -h|--help

Example:
# $0 --update-helm-chart traefik
# $0 --update-all --skip-charts 'aws-efs-csi-driver,capi-cluster,grafana-operator,strimzi-kafka-operator'
"
}

declare UPDATE_ALL=false
declare PULL_REQUEST=false
declare ACTIONS=false
declare UPDATE_HELM_CHART=
declare SKIP_CHARTS=
declare ARGOCD_CHART_PATH="argocd-helm-charts"
declare CHART_VERSION=
declare ADD_COMMITS=false

[ $# -eq 0 ] && { ARGFAIL; exit 1; }

while [[ $# -gt 0 ]]; do
  arg="$1"
  shift

  case "$arg" in
    --update-all)
      UPDATE_ALL=true
      ;;
    --update-helm-chart)
      if [[ $# -eq 0 || "$1" =~ ^-- ]]; then
        echo "Error: --update-helm-chart requires a chart name"
        ARGFAIL
        exit 1
      fi

      UPDATE_HELM_CHART=$1

      if ! test -d "$ARGOCD_CHART_PATH/$UPDATE_HELM_CHART"; then
        echo "Chart ${UPDATE_HELM_CHART} under $ARGOCD_CHART_PATH dir does not exist, please make sure directory exists."
        exit 1
      fi

      shift
      ;;
    --pull-request)
      PULL_REQUEST=true
      ;;
    --actions)
      ACTIONS=true
      ;;
    --skip-charts)
      if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
        SKIP_CHARTS=$1
        shift
      else
        echo "Warning: --skip-charts provided without value, skipping no charts"
      fi
      ;;
    --chart-version)
      if [[ $# -eq 0 || "$1" =~ ^-- ]]; then
        echo "Error: --chart-version requires a version number"
        ARGFAIL
        exit 1
      fi

      CHART_VERSION=$1

      shift
      ;;
    --add-commits)
      ADD_COMMITS=true
      ;;
    -h|--help)
      ARGFAIL
      exit
      ;;
    *)
      echo "Error: wrong argument given"
      ARGFAIL
      exit 1
      ;;
  esac
done

# Build an array based on the input (safe for empty values)
if [ -n "$SKIP_CHARTS" ]; then
  IFS=',' read -ra SKIP_HELM_CHARTS <<< "$SKIP_CHARTS"
else
  SKIP_HELM_CHARTS=()
fi

# Function to get the current version from CHANGELOG.md
get_current_version() {
  local changelog_file="CHANGELOG.md"
  local version
  if [ -f "$changelog_file" ]; then
    version=$(grep -oP '^## \K[0-9]+\.[0-9]+\.[0-9]+' "$changelog_file" | head -n1)
    if [ -z "$version" ]; then
      echo "1.0.0"
    else
      echo "$version"
    fi
  else
    echo "1.0.0"
  fi
}

# Function to bump version
bump_version() {
  local current_version=$1
  local bump_type=$2

  IFS='.' read -r major minor patch <<< "$current_version"

  case "$bump_type" in
    major)
      echo "$((major + 1)).0.0"
      ;;
    minor)
      echo "${major}.$((minor + 1)).0"
      ;;
    patch)
      echo "${major}.${minor}.$((patch + 1))"
      ;;
  esac
}

# Global variables to track change types
major_change_detected=false
minor_change_detected=false

# Function to determine change type and store change
determine_change_type() {
  local action=$1
  local chart_name=$2
  local old_version=$3
  local new_version=$4

  IFS='.' read -r old_major old_minor _ <<< "$old_version"
  IFS='.' read -r new_major new_minor _ <<< "$new_version"

  if [ "$new_major" -ne "$old_major" ]; then
    major_change_detected=true
  elif [ "$new_minor" -ne "$old_minor" ]; then
    minor_change_detected=true
  fi
}

function update_helm_chart {
  HELM_CHART_PATH="$1"
  HELM_CHART_YAML="$1/Chart.yaml"
  CHART_VERSION=$2

  # Exit if no chart.yaml is present
  if ! test -f "$HELM_CHART_YAML"; then
    echo "No $HELM_CHART_YAML present, please fix it"
    exit 1
  fi

  HELM_REPO_NAME=$(yq eval '.name' "$HELM_CHART_YAML")
  HELM_CHART_DEP_PRESENT=$(yq eval '.dependencies | length' "$HELM_CHART_YAML")
  HELM_CHART_DEP_PATH="$HELM_CHART_PATH/charts"

  if [ ${#SKIP_HELM_CHARTS[@]} -gt 0 ]; then
    for SKIP_HELM_CHART in "${SKIP_HELM_CHARTS[@]}"; do
        if [ "$HELM_REPO_NAME" == "$SKIP_HELM_CHART" ]; then
            echo "Skipping $SKIP_HELM_CHART"
            return
        fi
    done
  fi

  # This chart does not have any dependencies, so lets not do helm dep up
  if [ "$HELM_CHART_DEP_PRESENT" -ne 0 ]; then
    # It support helm chart updation for multiple dependencies
    # Iterate over each dependency and extract the desired values
    for ((i = 0; i < "$HELM_CHART_DEP_PRESENT"; i++)); do
        HELM_CHART_NAME=$(yq eval ".dependencies[$i].name" "$HELM_CHART_YAML")
        HELM_CHART_VERSION=$(yq eval ".dependencies[$i].version" "$HELM_CHART_YAML")
        HELM_REPOSITORY_URL=$(yq eval ".dependencies[$i].repository" "$HELM_CHART_YAML")

        # Add the repo
        if ! helm repo list -o yaml | yq eval -e ".[].name == \"$HELM_CHART_NAME\"" >/dev/null 2>/dev/null; then
          echo "ADD HELM CHARTS $HELM_REPO_NAME"
          helm repo add "$HELM_CHART_NAME" "$HELM_REPOSITORY_URL" >/dev/null || {
            echo "Failed to add repository $HELM_REPOSITORY_URL for chart $HELM_CHART_NAME. Skipping."
            continue
          }
        fi

        # Check if we have an upstream chart already present or not
        if test -f "$HELM_CHART_DEP_PATH/$HELM_CHART_NAME/Chart.yaml"; then
          if [ -z "$CHART_VERSION" ]; then
            HELM_UPSTREAM_CHART_VERSION=$(helm search repo --regexp "${HELM_CHART_NAME}/${HELM_CHART_NAME}[^-]" --version ">=$HELM_CHART_VERSION" --output yaml | yq eval '.[].version' -) || {
              echo "Failed to search for $HELM_CHART_NAME. Skipping."
              continue
            }
          else
            HELM_UPSTREAM_CHART_VERSION=$CHART_VERSION
          fi

          # Compare the version of upstream chart and our local chart
          # if there is difference, run helm dep up or else skip
          if [ "$HELM_UPSTREAM_CHART_VERSION" != "$HELM_CHART_VERSION" ]; then
            echo "HELMING $HELM_CHART_NAME"

            # Update the chart.yaml file
            yq eval -i ".dependencies[$i].version = \"$HELM_UPSTREAM_CHART_VERSION\"" "$HELM_CHART_YAML"

            # Go to helm chart, 1st layer
            helm dependencies update "$HELM_CHART_PATH"

            # Deleting old helm before untar
            echo "Deleting old $HELM_CHART_NAME before untar"
            rm -rf "${HELM_CHART_DEP_PATH:?}/${HELM_CHART_NAME}" || {
              echo "Failed to update dependencies for $HELM_CHART_NAME. Skipping."
              continue
            }

            # rename the downloaded tar file so that it matches what we want during untar.
            # For example for strimzi kafka operator downloaded tar file has name strimzi-kafka-operator-helm-3-chart-0.38.0.tgz
            # while we look for strimzi-kafka-operator-0.38.0.tgz
            tar_file=$(find "$HELM_CHART_DEP_PATH" -maxdepth 1 -type f -name "*${HELM_CHART_NAME}*.tgz" -print -quit)
            expected_tar_file="$HELM_CHART_DEP_PATH/$HELM_CHART_NAME-$HELM_UPSTREAM_CHART_VERSION.tgz"

            # Check if the downloaded tar file matches the expected name
            if [ "$tar_file" != "$expected_tar_file" ]; then
                echo "Renaming $tar_file to $expected_tar_file"
                mv "$tar_file" "$expected_tar_file"
            else
                echo "The tar file is already named correctly: $tar_file"
            fi

            # Untar the tgz file
            tar -C "$HELM_CHART_DEP_PATH" -xvf "$expected_tar_file" || {
              echo "Failed to extract $expected_tar_file. Skipping."
              continue
            }

            update_changelog "Updated" "$HELM_CHART_NAME" "$HELM_CHART_VERSION" "$HELM_UPSTREAM_CHART_VERSION"
            determine_change_type "Updated" "$HELM_CHART_NAME" "$HELM_CHART_VERSION" "$HELM_UPSTREAM_CHART_VERSION"
          else
            echo "Helm chart $HELM_REPO_NAME is already on latest version $HELM_CHART_VERSION"
          fi
        else
          echo "asdadadadadadadasdadadad"
          echo "HELMING $HELM_CHART_NAME"
          # Go to helm chart, 1st layer
          helm dependencies update "$HELM_CHART_PATH" || {
            echo "Failed to update dependencies for $HELM_CHART_NAME. Skipping."
            continue
          }

          # Deleting old helm before untar
          echo "Deleting old $HELM_CHART_NAME before untar"
          rm -rf "${HELM_CHART_DEP_PATH:?}/${HELM_CHART_NAME}"

          # rename the downloaded tar file so that it matches what we want during untar.
          # For example for strimzi kafka operator downloaded tar file has name strimzi-kafka-operator-helm-3-chart-0.38.0.tgz
          # while we look for strimzi-kafka-operator-0.38.0.tgz
          tar_file=$(find "$HELM_CHART_DEP_PATH" -maxdepth 1 -type f -name "*${HELM_CHART_NAME}*.tgz" -print -quit)
          expected_tar_file="$HELM_CHART_DEP_PATH/$HELM_CHART_NAME-$HELM_CHART_VERSION.tgz"

          # Check if the downloaded tar file matches the expected name
          if [ "$tar_file" != "$expected_tar_file" ]; then
              echo "Renaming $tar_file to $expected_tar_file"
              mv "$tar_file" "$expected_tar_file"
          else
              echo "The tar file is already named correctly: $tar_file"
          fi

          # Untar the tgz file
          tar -C "$HELM_CHART_DEP_PATH" -xvf "$expected_tar_file" || {
            echo "Failed to extract $expected_tar_file. Skipping."
            continue
          }

          # since there is no upstream chart already present passing HELM_CHART_VERSION in update_changelog
          # and determine_change_type instead of HELM_UPSTREAM_CHART_VERSION otherwise we get unbound variable
          # error for HELM_UPSTREAM_CHART_VERSION
          update_changelog "Added" "$HELM_CHART_NAME" "$HELM_CHART_VERSION" "$HELM_CHART_VERSION"
          determine_change_type "Added" "$HELM_CHART_NAME" "$HELM_CHART_VERSION" "$HELM_CHART_VERSION"
        fi
    done
  fi
}

# Function to update CHANGELOG.md
function update_changelog() {
  local action=$1
  local chart_name=$2
  local old_version=$3
  local new_version=$4
  local changelog_file="CHANGELOG.md"
  local message="$action $chart_name from version $old_version to $new_version"

  # Create CHANGELOG.md if it doesn't exist
  if [ ! -f "$changelog_file" ]; then
    cat << EOF > "$changelog_file"
# Changelog

All releases and the changes included in them (pulled from git commits added since last release) will be detailed in this file.

EOF
  fi

  # Extract version components
  IFS='.' read -r old_major old_minor _ <<< "$old_version"
  IFS='.' read -r new_major new_minor _ <<< "$new_version"

  # Determine the change type
  local change_type=""
  if [ "$new_major" -ne "$old_major" ]; then
    change_type="major"
  elif [ "$new_minor" -ne "$old_minor" ]; then
    change_type="minor"
  else
    change_type="patch"
  fi

  # Check if the Unreleased Changes section exists
  if ! grep -q "^## Unreleased Changes" "$changelog_file"; then
    sed -i "/All releases and the changes included in them (pulled from git commits added since last release) will be detailed in this file./a\\\n## Unreleased Changes" CHANGELOG.md
    sed -i "/Unreleased Changes/a\\### Patch Version Upgrades %%^^" CHANGELOG.md
    sed -i "/Unreleased Changes/a\\### Minor Version Upgrades %%^^\n" CHANGELOG.md
    sed -i "/Unreleased Changes/a\\### Major Version Upgrades %%^^\n" CHANGELOG.md
  fi

  # Add the new entry under the appropriate section under the Unreleased Changes
  case "$change_type" in
    major)
      sed -i "/### Major Version Upgrades %%^^/a\\- $message" "$changelog_file"
      ;;
    minor)
      sed -i "/### Minor Version Upgrades %%^^/a\\- $message" "$changelog_file"
      ;;
    patch)
      sed -i "/### Patch Version Upgrades %%^^/a\\- $message" "$changelog_file"
      ;;
    *)
      echo "Invalid change type: $change_type"
      return 1
      ;;
  esac
}

function pull_request() {
  chart_name=$1

  config_repo_path=$(pwd)

  # Check if we have modifications to commit
  CHANGES=$(git -C "${config_repo_path}" status --porcelain | wc -l)

  if (( CHANGES > 0 )); then
    title="[CI] Helm Chart Update ${chart_name}"

    git add "$ARGOCD_CHART_PATH/${chart_name}"
    git add CHANGELOG.md

    git -C "${config_repo_path}" commit -m "${title}"
  fi
}

# Generate a unique branch name
branch_name="Helm_Update"_$(date +"%Y%m%d")_$(echo $RANDOM | base64)

if [ -n "$UPDATE_HELM_CHART" ]; then
  if [ "$ACTIONS" = false ]; then
    git switch -c "$branch_name" --track "$(git branch --show-current)"
  fi
  update_helm_chart "$ARGOCD_CHART_PATH/$UPDATE_HELM_CHART" "$CHART_VERSION"
fi

if "$UPDATE_ALL"; then
  if [ "$ACTIONS" = false ]; then
    git switch -c "$branch_name" --track origin/master
  fi

  if $ADD_COMMITS; then
    bash ./bin/add-commits.sh
  fi

  while read -r path; do
  # find ./"$ARGOCD_CHART_PATH" -maxdepth 1 -mindepth 1 -type d | sort | while read -r path; do
    chart_name=$(basename "$path")

    update_helm_chart "$path" "$CHART_VERSION"

  done < <(find ./"$ARGOCD_CHART_PATH" -maxdepth 1 -mindepth 1 -type d | sort)

  # Check if the current date entry exists in the file
  if grep -q "Unreleased Changes" CHANGELOG.md; then
    bump_type="patch"
    current_ver="$(get_current_version)"

    # Determine the most significant change type
    if [ "$major_change_detected" = true ]; then
      bump_type="major"
    elif [ "$minor_change_detected" = true ]; then
      bump_type="minor"
    fi

    new_ver="$(bump_version "$current_ver" "$bump_type")"

    sed -i "s/Unreleased Changes/$new_ver/" CHANGELOG.md
    echo "Updated the changelog entry from 'Unreleased Changes' to '$new_ver'"

    # Remove Chnages heading markers
    sed -i 's/ %%\^\^//g' CHANGELOG.md
    # Remove empty sections
    sed -i '/### Major Version Upgrades/{N;/### Major Version Upgrades\n\n###$/d;}' CHANGELOG.md
    sed -i '/### Minor Version Upgrades/{N;/### Minor Version Upgrades\n\n###$/d;}' CHANGELOG.md
    sed -i '/### Patch Version Upgrades/{N;/### Patch Version Upgrades\n\n###$/d;}' CHANGELOG.md

  else
    bump_type="patch"
    current_ver="$(get_current_version)"

    new_ver="$(bump_version "$current_ver" "$bump_type")"
    sed -i "0,/### Improvements/{s/### Improvements/## $new_ver\n### Improvements/}" CHANGELOG.md
  fi
fi

if $PULL_REQUEST; then
  current_ver="$(get_current_version)"
  git add .
  git commit -S -m "KubeAid release '$current_ver'"
  git push origin "$branch_name"
fi

find . -name '*.tgz' -delete
