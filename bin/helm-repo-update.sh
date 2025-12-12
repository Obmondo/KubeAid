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

# Generate by claude to make it better readable
function ARGFAIL() {
  cat << 'EOF'
Usage: ./helm-update.sh [OPTIONS]

OPTIONS:
  --update-helm-chart CHART    Update a specific Helm chart
                               Requires: Path or name of the chart

  --update-all                 Update all Helm charts
                               Default: false

  --actions                    Run in CI/CD mode (GitHub/Gitea Actions)
                               Default: false
                               Note: Only use this flag in CI environments
                               [Not Tested]

  --skip-charts CHARTS         Comma-separated list of charts to skip
                               Default: none
                               Example: 'chart1,chart2,chart3'

  --chart-version VERSION      Specify Helm chart version to update to
                               Default: latest

  -h, --help                   Display this help message

EXAMPLES:
  # Update a single chart
  ./helm-update.sh --update-helm-chart traefik

  # Update a specific chart to a specific version
  ./helm-update.sh --update-helm-chart traefik --chart-version 25.0.0

  # Update all charts
  ./helm-update.sh --update-all

  # Update all charts except specific ones
  ./helm-update.sh --update-all --skip-charts 'aws-efs-csi-driver,capi-cluster,grafana-operator,strimzi-kafka-operator'

  # Run in CI/CD mode
  ./helm-update.sh --update-all --actions

EOF
}

declare UPDATE_ALL=false
declare ACTIONS=false
declare UPDATE_HELM_CHART=
declare SKIP_CHARTS=
declare ARGOCD_CHART_PATH="argocd-helm-charts"
declare HELM_VERSION_LAST_UPDATE_FILE="./.helm_version_last_update"
declare CHART_VERSION=

# Arrays to track updates
declare -a MINOR_UPDATES
declare -a PATCH_UPDATES
declare -a MAJOR_UPDATES

# Flags to track highest version bump needed
HAS_MAJOR=false
HAS_MINOR=false
HAS_PATCH=false

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

# Function to determine update type
function get_update_type() {
    local old_version=$1
    local new_version=$2

    local old_major
    local old_minor
    local old_patch

    local new_major
    local new_minor
    local new_patch

    # Remove 'v' prefix if present
    old_version=${old_version#v}
    new_version=${new_version#v}

    # Extract major, minor, patch
    old_major=$(echo "$old_version" | cut -d. -f1)
    old_minor=$(echo "$old_version" | cut -d. -f2)
    old_patch=$(echo "$old_version" | cut -d. -f3)

    new_major=$(echo "$new_version" | cut -d. -f1)
    new_minor=$(echo "$new_version" | cut -d. -f2)
    new_patch=$(echo "$new_version" | cut -d. -f3)

    # Strip any remaining non-numeric characters from patch
    # some charts have 0-develop in patch
    old_patch=$(echo "$old_patch" | grep -o '^[0-9]*' || echo "0")
    new_patch=$(echo "$new_patch" | grep -o '^[0-9]*' || echo "0")

    # Compare versions
    if [[ "$new_major" -gt "$old_major" ]]; then
      echo "major"
    elif [[ "$new_major" -eq "$old_major" ]] && [[ "$new_minor" -gt "$old_minor" ]]; then
      echo "minor"
    elif [[ "$new_major" -eq "$old_major" ]] && [[ "$new_minor" -eq "$old_minor" ]] && [[ "$new_patch" -gt "$old_patch" ]]; then
      echo "patch"
    else
      echo "none"
    fi
}


# Function to bump version based on update type
# Note: semver tool is readily available as a package in linux
# with this we can survive with a small function and not a proud one.
function bump_version() {
    local version=$1
    local bump_type=$2

    # Remove 'v' prefix if present
    version=${version#v}

    IFS='.' read -ra VER <<< "$version"
    local major="${VER[0]}"
    local minor="${VER[1]}"
    local patch="${VER[2]}"

    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Function to get current KubeAid version
function get_current_kubeaid_version() {
  git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0"
}

# Function to compare two dates
function compare_dates() {
  # Convert dates to seconds since epoch for easy comparison
  timestamp1=$(date -d "$HELM_LAST_UPDATE_DATE" +%s)
  timestamp2=$(date -d "$CURRENT_DATE" +%s)

  # Perform comparisons
  [[ "$timestamp1" -ge "$timestamp2" ]]
}

# Function check if helm chart has newer version in cache
function compare_version() {
  [ "$HELM_CHART_NEW_VERSION" != "$HELM_CHART_CURRENT_VERSION" ]
}

# Function to find the date in the .helm_version_last_update file
# so we dont have to helm repo search, since it was update today locally
# on the node, so next re-run is faster
function get_repo_last_update_date() {
  # Note: we only need to check if chart is present or not, if someone add duplicate entry
  # it should not fail
  UPDATE_DATE=$(grep "$HELM_CHART_NAME$" "$HELM_VERSION_LAST_UPDATE_FILE" | uniq | awk '{print $1}' || true)

  if [ -z "$UPDATE_DATE" ]; then
    date -d "1 day ago" '+%Y-%m-%d'
  else
    echo "$UPDATE_DATE"
  fi
}

function get_helm_latest_version_from_cache() {
  # Note: we only need to check if chart is present or not, if someone add duplicate entry
  # it should not fail
  _NEW_VERSION="$CURRENT_DATE $HELM_CHART_CURRENT_VERSION $HELM_CHART_NAME"

  # Check if we have an upstream chart already present or not
  # Note: cut is on purpose, since some chart might end up empty string in place of version
  # in the cache file
  HELM_CHART_NEW_VERSION_FROM_CACHE=$(grep "$_NEW_VERSION" "$HELM_VERSION_LAST_UPDATE_FILE" | uniq | cut -d ' ' -f2 || true )
  if [ -z "$HELM_CHART_NEW_VERSION_FROM_CACHE" ]; then
    if [ "$HELM_REPOSITORY_URL" = "null" ] || [[ "$HELM_REPOSITORY_URL" =~ ^oci:// ]]; then
      # helm4 with OCI support does not support search in helm repo
      # so lets stick to current version, one has to manually change the chart.yaml
      # to get it updated.
      HELM_CHART_NEW_VERSION=$HELM_CHART_CURRENT_VERSION
    else
      if [ -n "$HELM_REPOSITORY_URL" ]; then
        # If no version is found in the cache, ask the helm repo
        HELM_CHART_NEW_VERSION=$(helm search repo --regexp "${HELM_CHART_NAME}/${HELM_CHART_NAME}[^-]" --version ">=$HELM_CHART_CURRENT_VERSION" --output yaml | yq eval '.[].version' -)
      else
        HELM_CHART_NEW_VERSION="$HELM_CHART_DEP_CURRENT_VERSION"
      fi
    fi
  else
    HELM_CHART_NEW_VERSION=$HELM_CHART_NEW_VERSION_FROM_CACHE
  fi
}


function add_last_update_date() {
  HELM_CHART_LINE="$CURRENT_DATE $HELM_CHART_NEW_VERSION $HELM_CHART_NAME"

  if [ "$(grep -c "$HELM_CHART_NAME" "$HELM_VERSION_LAST_UPDATE_FILE")" -eq 0 ]; then
    echo "$HELM_CHART_LINE" >> "$HELM_VERSION_LAST_UPDATE_FILE"
  else
    # Remove duplicate line if its present for any reason
    sed -i "/$HELM_CHART_NAME/d; \$a $CURRENT_DATE $HELM_CHART_LINE/d" "$HELM_VERSION_LAST_UPDATE_FILE"
  fi
}

function update_helm_chart {
  
  HELM_CHART_PATH="$1"
  HELM_CHART_YAML="$HELM_CHART_PATH/Chart.yaml"
  HELM_CHART_NEW_VERSION=$2

  # Exit if no chart.yaml is present
  if ! test -f "$HELM_CHART_YAML"; then
    echo "No $HELM_CHART_YAML present, please fix it"
    return
  fi

  HELM_CHART_DEP_PRESENT=$(yq eval '.dependencies | length' "$HELM_CHART_YAML")
  HELM_CHART_DEP_PATH="$HELM_CHART_PATH/charts"

  # This chart does not have any dependencies, so lets not do helm dep up
  if [ "$HELM_CHART_DEP_PRESENT" -ne 0 ]; then
    # It support helm chart updation for multiple dependencies
    # Iterate over each dependency and extract the desired values
    for ((i = 0; i < "$HELM_CHART_DEP_PRESENT"; i++)); do
      HELM_CHART_NAME=$(yq eval ".dependencies[$i].name" "$HELM_CHART_YAML")
      HELM_REPOSITORY_URL=$(yq eval ".dependencies[$i].repository" "$HELM_CHART_YAML")
      HELM_CHART_CURRENT_VERSION=$(yq eval ".dependencies[$i].version" "$HELM_CHART_YAML")

      # skip if the helm chart is locally available and not on a repo
      if [[ "$HELM_REPOSITORY_URL" =~ ^file:// ]]; then
        continue
      fi

      HELM_CHART_DEP_CHART_YAML="$HELM_CHART_DEP_PATH/$HELM_CHART_NAME/Chart.yaml"
      HELM_CHART_DEP_CURRENT_VERSION="" # default is empty string, i.e, new chart is being added

      # If the dependency chart has already been added
      if test -f "$HELM_CHART_DEP_CHART_YAML"; then
        HELM_CHART_DEP_CURRENT_VERSION=$(yq eval ".version" "$HELM_CHART_DEP_CHART_YAML")
      fi

      

      CURRENT_DATE="$(date '+%Y-%m-%d')"
      HELM_LAST_UPDATE_DATE="$(get_repo_last_update_date "$HELM_CHART_NAME")"

      # OCI support from 3.8 helm, we will default to v4 now
      if [[ ! "$HELM_REPOSITORY_URL" =~ ^oci:// ]]; then
        # Compare the dates first, if date is not matching current date, update the cache file
        # Add the repo
        if ! compare_dates; then
          if ! helm repo list -o yaml | yq eval -e '.[].name'| grep "$HELM_CHART_NAME" >/dev/null 2>&1; then
            echo "Adding Helm repository $HELM_REPOSITORY_URL"
            helm repo add "$HELM_CHART_NAME" "$HELM_REPOSITORY_URL" >/dev/null || {
              echo "Failed to add repository $HELM_REPOSITORY_URL for chart $HELM_CHART_NAME. Skipping."
              continue
            }
          fi
        fi
      fi

      get_helm_latest_version_from_cache
      add_last_update_date

      # Compare the dates first, if date is not matching current date, update the cache file
      # Add the repo

      # Compare the version of upstream chart and our local chart
      # if there is difference, run helm dep up or else skip
      if [ "$HELM_CHART_NEW_VERSION" != "$HELM_CHART_DEP_CURRENT_VERSION" ]; then
        echo "Helming $HELM_CHART_NAME on version $HELM_CHART_NEW_VERSION"

        # Update the chart.yaml file
        yq eval -i ".dependencies[$i].version = \"$HELM_CHART_NEW_VERSION\"" "$HELM_CHART_YAML"

        # Go to helm chart, 1st layer
        helm dependencies update "$HELM_CHART_PATH" >/dev/null 2>&1 || {
          echo "Failed to update dependencies for $HELM_CHART_NAME"
          continue
        }

        # Deleting old helm before untar
        rm -rf "${HELM_CHART_DEP_PATH:?}/${HELM_CHART_NAME}" || {
          echo "Failed to update dependencies for $HELM_CHART_NAME. Skipping."
          continue
        }

        # rename the downloaded tar file so that it matches what we want during untar.
        # For example for strimzi kafka operator downloaded tar file has name strimzi-kafka-operator-helm-3-chart-0.38.0.tgz
        # while we look for strimzi-kafka-operator-0.38.0.tgz
        tar_file=$(find "$HELM_CHART_DEP_PATH" -maxdepth 1 -type f -name "*${HELM_CHART_NAME}*.tgz" -print -quit)
        expected_tar_file="$HELM_CHART_DEP_PATH/$HELM_CHART_NAME-$HELM_CHART_NEW_VERSION.tgz"

        # Check if the downloaded tar file matches the expected name
        if [ "$tar_file" != "$expected_tar_file" ]; then
            echo "Renaming $tar_file to $expected_tar_file"
            mv "$tar_file" "$expected_tar_file"
        fi

        # Untar the tgz file
        tar -C "$HELM_CHART_DEP_PATH" -xvf "$expected_tar_file" >/dev/null || {
          echo "Failed to extract $expected_tar_file. Skipping."
          continue
        }
      else
        echo "Helm chart $HELM_CHART_NAME is cached and on latest version $HELM_CHART_CURRENT_VERSION, locally on the filesystem,"
      fi

      # Incase of updates, i.e, chart is already added
      if [[ "$HELM_CHART_DEP_CURRENT_VERSION" != "" ]]; then
        local update_type
        CURRENT_VERSION=$(get_current_kubeaid_version)
        HELM_CHART_CURRENT_TAG_VERSION=$(git show "$CURRENT_VERSION:$HELM_CHART_YAML" | yq eval ".dependencies[$i].version")
        update_type=$(get_update_type "$HELM_CHART_CURRENT_TAG_VERSION" "$HELM_CHART_NEW_VERSION")

        local update_line="- Updated $HELM_CHART_NAME from version $HELM_CHART_CURRENT_VERSION to $HELM_CHART_NEW_VERSION"

        case $update_type in
          major)
            MAJOR_UPDATES+=("$update_line")
            HAS_MAJOR=true
            ;;
          minor)
            MINOR_UPDATES+=("$update_line")
            if [ "$HAS_MAJOR" = false ]; then
              HAS_MINOR=true
            fi
            ;;
          patch)
            PATCH_UPDATES+=("$update_line")
            if [ "$HAS_MAJOR" = false ] && [ "$HAS_MINOR" = false ]; then
              HAS_PATCH=true
            fi
            ;;
        esac
      fi
      
    done
  fi
}

function main (){
  # Generate a unique branch name
  GIT_BRANCH_NAME="Helm_Update"_$(date +"%Y%m%d")_$(echo $RANDOM | base64)
  COMMIT_MSG_FILE=$(mktemp)


  if [ -n "$UPDATE_HELM_CHART" ]; then
    if [ "$ACTIONS" = false ]; then
      git switch -c "$GIT_BRANCH_NAME" --track "$(git branch --show-current)"
    fi
    update_helm_chart "$ARGOCD_CHART_PATH/$UPDATE_HELM_CHART" "$CHART_VERSION"
  fi

  if "$UPDATE_ALL"; then
    # Determine KubeAid version bump
    CURRENT_VERSION=$(get_current_kubeaid_version)
    echo "Current KubeAid version: $CURRENT_VERSION"

    if [ "$ACTIONS" = false ]; then
      git switch -c "$GIT_BRANCH_NAME" --track origin/master
    fi

    while read -r HELM_CHART_NAME; do
      for SKIP_HELM_CHART in "${SKIP_HELM_CHARTS[@]}"; do
        if [ "$HELM_CHART_NAME" == "$SKIP_HELM_CHART" ]; then
          echo "Skipping $SKIP_HELM_CHART"
          break
        fi
      done

      update_helm_chart "$HELM_CHART_NAME" "$CHART_VERSION"
    done < <(find ./"$ARGOCD_CHART_PATH" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)

    if [ "$HAS_MAJOR" = true ]; then
        BUMP_TYPE="major"
    elif [ "$HAS_MINOR" = true ]; then
        BUMP_TYPE="minor"
    elif [ "$HAS_PATCH" = true ]; then
        BUMP_TYPE="patch"
    else
      rm -f "$COMMIT_MSG_FILE"
    fi

    NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP_TYPE")
    echo "New KubeAid version: v$NEW_VERSION"

    # Generate commit message
    {
      echo "chore: update helm charts to v$NEW_VERSION"
      echo ""

      if [ ${#MAJOR_UPDATES[@]} -gt 0 ]; then
        echo "### Major Version Upgrades"
        printf '%s\n' "${MAJOR_UPDATES[@]}"
        echo ""
      fi

      if [ ${#MINOR_UPDATES[@]} -gt 0 ]; then
        echo "### Minor Version Upgrades"
        printf '%s\n' "${MINOR_UPDATES[@]}"
        echo ""
      fi

      if [ ${#PATCH_UPDATES[@]} -gt 0 ]; then
        echo "### Patch Version Upgrades"
        printf '%s\n' "${PATCH_UPDATES[@]}"
        echo ""
      fi
    } > "$COMMIT_MSG_FILE"

    # Update the version file
    # go release script can update with the correct tag
    echo "$NEW_VERSION" > VERSION
    git add VERSION

    if [[ -n "$(git status --porcelain)" ]]; then
      git add -A "$ARGOCD_CHART_PATH"
      git commit -F "$COMMIT_MSG_FILE"
    fi

    rm -f "$COMMIT_MSG_FILE"
  fi

  find . -name '*.tgz' -delete
}

# Run main function
main "$@"
