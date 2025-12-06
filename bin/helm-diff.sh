#!/usr/bin/env bash

set -eou pipefail

TEMPDIR=$(mktemp -d)

# Set default authentication method
AUTH_METHOD='gitea'

# Override authentication method if GitHub URL is detected
if [[ "$KUBERNETES_CONFIG_REPO_URL" =~ ^https://github\.com/ ]]; then
    AUTH_METHOD='github'
fi

case "${AUTH_METHOD}" in
  'gitea')
    token=${GITEA_TOKEN}
    git clone "https://oauth2:${token}@${KUBERNETES_CONFIG_REPO_URL}" "${TEMPDIR}"
    ;;
  'github')
    git clone "${KUBERNETES_CONFIG_REPO_URL}" "${TEMPDIR}"
    ;;
  *)
    echo "Invalid authentication method: ${AUTH_METHOD}"
    exit 1
    ;;
esac

cd "${TEMPDIR}"

# SKIP diff check part IF MR consist of ONLY commits with word 'lint' in them
COMMIT_MSG=$(git log --oneline --pretty=format:'%s' --abbrev-commit "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}..origin/${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME}" argocd-helm-charts)

COMMIT_COUNT=$(echo "$COMMIT_MSG" | wc -l)
NO_DIFF_COUNT=$(echo "$COMMIT_MSG" | { grep '^no-diff' -c || true; } )

function helm_diff() {
  echo "Checking diff for chart $1"
  chart_path="argocd-helm-charts/${1}"
  chart_name="$1"

  # Move to the master branch
  git checkout "$CI_MERGE_REQUEST_TARGET_BRANCH_NAME"

  # Get helm template for chart on master branch if the chart exists
  if [ -d "$chart_path" ]; then
    helm template "$chart_path" -f "${chart_path}/values.yaml" > "/tmp/${chart_name}_master.yaml" || true
  else
    echo "Chart $1 doesn't exist on master branch"
  fi

  # Move to the local branch
  git checkout "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME"

  # Get helm template for chart on feature branch if the chart exists
  if [ -d "$chart_path" ]; then
    helm template "$chart_path" -f "${chart_path}/values.yaml" > "/tmp/${chart_name}_feature.yaml"
  else
    echo "Chart $1 doesn't exist on feature branch"
  fi

  # Check if chart was added or removed
  any_diff=""
  if [ ! -f "/tmp/${chart_name}_master.yaml" ]; then
    any_diff="New chart added"
  fi
  if [ ! -f "/tmp/${chart_name}_feature.yaml" ]; then
    any_diff="Chart removed"
  fi

  # Get the diff if chart exists in both branches
  if [ -z "$any_diff" ]; then
    any_diff=$(diff -u "/tmp/${chart_name}_master.yaml" "/tmp/${chart_name}_feature.yaml" || true )
  fi

  # Check there is a diff
  if [ -z "$any_diff" ]; then
    echo "There are no changes to the helm template resulting from these code changes"
    echo "Please test with 'helm template $1 $chart_path -f ${chart_path}/values.yaml' that your changes appear, before making an MR"
    exit 1
  else
    echo "Nice, there is a diff between changes"
    echo -e "section_start: See diff :my_diff\r\e[OKHeader of the 1st collapsible section"
    echo "$any_diff"
    echo -e "section_end: See diff :my_diff\r\e[OK"
  fi
}

function helm_compile() {
  echo "Checking that helm template works on ${1}"
  chart_name="argocd-helm-charts/${1}"

  git checkout "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME"

  if [ -d "$chart_name" ]; then
    if helm template "$chart_name" -f "${chart_name}/values.yaml"; then
      echo "Nice, Helm template works with the given values files"
    else
      echo "Ouch!! Helm template fails, please run this command to verify locally first"
      echo "helm template $chart_name -f ${chart_name}/values.yaml"
      exit 1
    fi
  else
    echo "Chart removed: ${1}"
  fi
}

# Only get the directory name of the chart
git diff "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}..origin/${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME}" --name-only | grep argocd-helm-charts | cut -d '/' -f 1,2 | sort | uniq | while read -r diff; do

  chart_name=$(echo "$diff" | cut -d '/' -f2)

  if [ "$NO_DIFF_COUNT" -eq "$COMMIT_COUNT" ]; then
    echo "Skipping diff check due to 'no-diff'  in all commit messages"
    helm_compile "$chart_name"
  elif git diff "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}..origin/${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME}" --name-only | grep -e "argocd-helm-charts/${chart_name}" | grep -v 'Chart'; then
    helm_diff "$chart_name"
  fi
done
