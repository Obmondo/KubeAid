#!/usr/bin/env bash

set -x
set -euo pipefail

# Don't run for merge requests that target a branch that is not master/main.
if [[ "${CI_COMMIT_REF_NAME}" != master ]] && [[ "${CI_COMMIT_REF_NAME}" != main ]]; then
  exit
fi

if ! [[ "${KUBERNETES_CONFIG_REPO_URL}" && "${KUBERNETES_CONFIG_REPO_TOKEN}" ]]; then
    >&2 echo "Required variables KUBERNETES_CONFIG_REPO_URL and KUBERNETES_CONFIG_REPO_TOKEN are unset.'."
  exit 42
fi

if ! [[ "${CI}" ]]; then
  >&2 echo "This script should only be run in a CI pipeline. This is not a CI pipeline."
  exit 41
fi

case "${KUBERNETES_CONFIG_REPO_URL}" in
  *gitea*)
    config_repo_username=oauth2
    config_repo_password="${KUBERNETES_CONFIG_REPO_TOKEN}"
    config_repo_auth="${config_repo_username}:${config_repo_password}"
    ;;
  *github*)
    config_repo_username="${KUBERNETES_CONFIG_REPO_TOKEN}"
    config_repo_password=''
    config_repo_auth="${config_repo_username}"
esac

if ! [[ "${config_repo_auth}" ]]; then
  >&2 echo "Missing repo access token"
  exit 43
fi

if ! [[ "${KUBERNETES_CONFIG_REPO_URL}" =~ ^https://(.+) ]]; then
  >&2 echo "Unable to handle Kubernetes repo URL '${KUBERNETES_CONFIG_REPO_URL}'"
  exit 44
fi

config_repo_url_with_auth="https://${config_repo_auth}@${KUBERNETES_CONFIG_REPO_URL:8}"
deploy_target_branch="${OBMONDO_DEPLOY_TARGET_BRANCH:-main}"
config_repo_name=$(echo "$KUBERNETES_CONFIG_REPO_URL" | sed -r "s/.+\/(.+)\..+/\1/")
config_repo_path="/tmp/${config_repo_name}"

git config --global user.email "${USER_EMAIL}"
git config --global user.name "${USER_NAME}"

git clone "${config_repo_url_with_auth}" "${config_repo_path}"
git -C "${config_repo_path}" checkout -b "argocd-deploy" --track "origin/${deploy_target_branch}"

# Loop over all clusters that are defined in config repo and copy
# corresponding compiled files into cloned repo.
find "${config_repo_path}/k8s/" -mindepth 2 -maxdepth 2 -type f -name '*.jsonnet' -exec dirname {} \; | while read -r cluster_dir; do
  ./build/kube-prometheus/build.sh "$cluster_dir"
  git -C "${config_repo_path}" add -f "${cluster_dir}"
done

# Check if we have modifications to commit
CHANGES=$(git -C "${config_repo_path}" status --porcelain | wc -l)

if (( CHANGES > 0 )); then
  title='Updated Prometheus builds'

  git -C "${config_repo_path}" status
  git -C "${config_repo_path}" commit -m "${title}"

  # Push changes to the remote repository
  git -C "${config_repo_path}" push origin HEAD


  export GITEA_TOKEN
  export GITHUB_TOKEN

  case "${KUBERNETES_CONFIG_REPO_URL}" in
    *gitea*)
      token=${GITEA_TOKEN}
      URL="gitea.obmondo.com"
      owner="EnableIT"
      repo="KubeAid"
      ;;
    *github*)
      token=${GITHUB_TOKEN}
      URL="api.github.com"
      owner="Obmondo"
      repo="kubeaid"
  esac

  # Create a pull request using the Gitea or GitHub API
  output=$(curl -X POST \
    -H "Authorization: token $token" \
    -d '{
      "title": "'"${title}"'",
      "head": "your_branch_with_changes",
      "base": "'"${deploy_target_branch}"'",
      "body": "Auto-generated pull request from Obmondo, created from changes by '"${USER_NAME}"' ('"${USER_EMAIL}"')."
    }' \
    "https://${URL}/repos/$owner/$repo/pulls")
  
  # Check for warnings or errors in the output and handle as needed
  if grep -q WARNINGS <<< "${output}"; then
    exit 1
  fi

  # Extract the pull request number from the output
  pull_request_number=$(echo "$output" | jq -r '.number')

  # Check the status of an Action workflow associated with the pull request
  workflow_status=$(curl -s -H "Authorization: token $token" \
    "https://${URL}/repos/$owner/$repo/actions/runs?event=workflow_dispatch" | \
    jq --arg pr "$pull_request_number" '.workflow_runs[] | select(.head_repository.owner.login == "'"$owner"'" and .head_repository.name == "'"$repo"'" and .pull_requests[0].number == $pr)')

  workflow_conclusion=$(echo "$workflow_status" | jq -r '.conclusion')

  # If the workflow has succeeded, merge the pull request
  if [ "$workflow_conclusion" == "success" ]; then
    merge_response=$(curl -s -X PUT -H "Authorization: token $token" \
      "https://${URL}/repos/$owner/$repo/pulls/$pull_request_number/merge")
    echo "Merge response: $merge_response"
  else
    echo "Workflow has not succeeded, skipping merge."
  fi

  # Delete the source branch after merging
  delete_branch_response=$(curl -X DELETE \
    -H "Authorization: token $token" \
    "https://${URL}/repos/OWNER/REPO_NAME/git/refs/heads/BRANCH_NAME")

  echo "$delete_branch_response"
fi
