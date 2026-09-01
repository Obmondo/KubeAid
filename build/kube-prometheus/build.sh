#!/usr/bin/env bash
#

# This script requires path to cluster folder in clone of customers
# kubernetes-config repo in arg $1. The folder should contain a
# <cluster-name>-vars.jsonnet file. With CAPI, the folder name can be
# different from the cluster name (e.g., folder: staging.local.example.com,
# cluster name: staging, jsonnet file: staging-vars.jsonnet).
# The manifests will be put in the cluster folder in a kube-prometheus subdir.
# And it must be run from the root of the argocd-apps repo. Example:
# ./build/kube-prometheus/build.sh ../kubernetes-config-enableit/k8s/kam.obmondo.com

set -euo pipefail

declare -i debug=0 \
  commit=0 \
  show_versions=0

declare cluster_dir='' \
  kubeaid_repo='' \
  kubeaid_repo_root='' \
  build_worktree=''

function realpath() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

basedir="$(dirname "$(realpath "${0}")")"

function _exit() {
  if [ -n "${build_worktree}" ] && [ -d "${build_worktree}" ]; then
    git -C "${kubeaid_repo_root}" worktree remove --force "${build_worktree}" 2>/dev/null ||
      { rm -rf "${build_worktree}" && git -C "${kubeaid_repo_root}" worktree prune; }
  fi
  if ! ((debug)); then
    if [ -n "${tmpdir+x}" ] && [ -d "${tmpdir}" ]; then
      rm -rf "${tmpdir}"
    fi
  fi
}

trap _exit EXIT

function usage() {
  cat <<EOF
${0} [-d|--debug] [--commit] [--kubeaid-repo <path>] [--versions] <CLUSTER>

Compile kube-prometheus manifests from jsonnet template.

The manifests are built from a temporary git worktree at the kubeaid tag
pinned as spec.source.targetRevision on the cluster's kube-prometheus
ArgoCD Application (HEAD means master). This checkout is left untouched.

Arguments:
  -d|--debug
    Leave temporary output folder when exiting.
  --commit
    Commit the generated manifests in the kubeaid-config repo.
  --kubeaid-repo <path>
    Build from this local kubeaid checkout as-is, skipping the tag check.
    For testing.
  --versions
    Show the kube-prometheus / Kubernetes compatibility table and exit.
EOF
}

function show_compatibility_table() {
  echo ""
  echo "Kubernetes Compatibility Matrix"
  echo ""
  {
    echo "kube-prometheus|k8s 1.26|k8s 1.27|k8s 1.28|k8s 1.32|k8s 1.33|k8s 1.34|k8s 1.35"
    echo "──────────────|───────|───────|───────|───────|───────|───────|───────"
    echo "v0.13.0|✓|✓|✓|✗|✗|✗|✗"
    echo "v0.16.0|✗|✗|✗|✓|✓|✓|✗"
    echo "v0.17.0|✗|✗|✗|✗|✓|✓|✓"
    echo "v0.18.0|✗|✗|✗|✗|✓|✓|✓"
  } | column -t -s '|'
  echo ""
  echo "Note: In CI we test only the last two releases on a regular basis."
}

while (($# > 0)); do
  case "${1}" in
  -d | --debug)
    debug=1
    ;;
  --commit)
    commit=1
    ;;
  --versions)
    show_versions=1
    ;;
  --kubeaid-repo)
    if ! [ -d "${2:-}" ]; then
      echo "--kubeaid-repo needs a path to a kubeaid checkout"
      exit 2
    fi
    kubeaid_repo="${2}"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    if ! [ -d "${1}" ]; then
      echo "Invalid argument ${1}"
      exit 2
    fi
    cluster_dir="${1}"
    ;;
  esac
  shift
done

if ((show_versions)); then
  show_compatibility_table
  exit 0
fi

if ! [[ "${cluster_dir}" ]]; then
  echo "Missing argument cluster_dir"
  exit 2
fi

# Find the vars.jsonnet file in the cluster directory
# With CAPI, folder name can differ from cluster name
cluster_jsonnet=$(find "${cluster_dir}" -maxdepth 1 -name "*-vars.jsonnet" -type f | head -n 1)

if [ -z "${cluster_jsonnet}" ]; then
  echo "No vars.jsonnet file found in ${cluster_dir}"
  echo "Expected a file named <cluster-name>-vars.jsonnet"
  exit 2
fi

# Sanity checks for jsonnet version
if ! tmp=$(jsonnet --version 2>&1); then
  echo "Missing the program 'jsonnet'"
  exit 2
fi
if ! [[ "${tmp}" =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  echo "Unable to parse jsonnet version ('${tmp}')"
  exit 2
fi

declare -i _version=$(((BASH_REMATCH[1] * 10 ** 6) + (BASH_REMATCH[2] * 10 ** 3) + BASH_REMATCH[3]))
if ((_version < 18000)); then
  echo "jsonnet version too old; aborting"
  exit 2
fi

# Pick the kubeaid checkout to build from. With --kubeaid-repo that checkout
# is used as-is; otherwise a temporary worktree at the tag the cluster pins as
# spec.source.targetRevision on its kube-prometheus ArgoCD Application, so
# this checkout and any local changes in it are left alone.
if [[ -n "${kubeaid_repo}" ]]; then
  basedir="$(realpath "${kubeaid_repo%/}")/build/kube-prometheus"
  if ! [[ -f "${basedir}/common-template.jsonnet" ]]; then
    echo "ERROR: ${kubeaid_repo} is not a kubeaid checkout (no build/kube-prometheus/common-template.jsonnet)"
    exit 2
  fi
  echo "Building from kubeaid checkout ${kubeaid_repo} as-is"
else
  kubeaid_repo_root=$(cd "${basedir}/../.." && pwd)
  argocd_app_file="${cluster_dir%/}/argocd-apps/templates/kube-prometheus.yaml"
  pinned_version=$(gojsontoyaml -yamltojson <"${argocd_app_file}" 2>/dev/null |
    jq -r '.spec.source.targetRevision // ""' 2>/dev/null || echo '')
  if [[ -z "${pinned_version}" ]]; then
    echo "ERROR: kubeaid tag missing in ${argocd_app_file} (spec.source.targetRevision)"
    exit 2
  fi

  # HEAD on the Application means the tip of master.
  pinned_ref="${pinned_version}"
  if [[ "${pinned_version}" == HEAD ]]; then
    pinned_ref=master
  fi
  if ! pinned_sha=$(git -C "${kubeaid_repo_root}" rev-parse --verify "${pinned_ref}^{commit}" 2>/dev/null); then
    echo "ERROR: kubeaid ref '${pinned_ref}' not found in ${kubeaid_repo_root}; run 'git -C ${kubeaid_repo_root} fetch --tags origin'"
    exit 2
  fi

  build_worktree=$(mktemp -d -t kubeaid-build.XXXXXX)
  git -C "${kubeaid_repo_root}" worktree add -q --detach "${build_worktree}" "${pinned_sha}"
  basedir="${build_worktree}/build/kube-prometheus"
  echo "Building from kubeaid ${pinned_version} (${pinned_sha:0:8}) in a temporary worktree"
fi

# Make sure to use project tooling
outdir="${cluster_dir%/}/kube-prometheus"

# NOTE: If 'kube_prometheus_version' isn't specified in the customer values file ($cluster_jsonnet),
# then we're setting 'main' as the default tag for it.
# You can always specify it to get the specific version/tag build by specifying `kube_prometheus_version`
# in the customer values file.
kube_prometheus_release=$(jsonnet "${cluster_jsonnet}" | jq -e -r '.kube_prometheus_version // "main"')
if [[ -z "${kube_prometheus_release}" ]]; then
  echo "Unable to parse kube-prometheus version, please verify '${cluster_jsonnet}'"
  exit 3
fi

jsonnet_lib_path="${basedir}/libraries/${kube_prometheus_release}/vendor"

if ! [ -e "${jsonnet_lib_path}" ]; then
  echo "Libraries not found for ${kube_prometheus_release} at ${jsonnet_lib_path}"
  echo "Run:  ./build/kube-prometheus/setup-version.sh ${kube_prometheus_release}"
  echo "(run with --versions to see the full compatibility table)"
  exit 2
fi

CLUSTER_VARS_FILE="${cluster_jsonnet}" bash "${basedir}/tests/lint_vars_access.sh"

cluster_name=$(basename "${cluster_dir%/}")

if ((commit)); then
  _original_branch=$(git -C "${cluster_dir}" rev-parse --abbrev-ref HEAD)
  _new_branch="kube-prometheus-${cluster_name}-${kube_prometheus_release}-$(date +%Y%m%d%H%M%S)"
  git -C "${cluster_dir}" checkout -q -b "${_new_branch}"
fi

build_start=$(date +%s)

# Use a temporary directory
tmpdir=$(mktemp -d)
mkdir "${tmpdir}/setup"

# Compile jsonnet files
# shellcheck disable=SC2016
jsonnet -J \
  "${jsonnet_lib_path}" \
  --ext-code-file vars="${cluster_jsonnet}" \
  -m "${tmpdir}" \
  "${basedir}/common-template.jsonnet" |
  while read -r f; do
    gojsontoyaml <"${f}" >"${f}.yaml"
    rm "${f}"
  done

rm -rf "${outdir}"
mv "${tmpdir}" "${outdir}"

build_end=$(date +%s)
kubeaid_version_desc=$(git -C "${basedir}" describe --tags --always 2>/dev/null || echo "unknown")
kubeaid_short_sha=$(git -C "${basedir}" rev-parse --short=8 HEAD 2>/dev/null || echo "")
echo "kubeaid=${kubeaid_version_desc} (${kubeaid_short_sha})  kube-prometheus=${kube_prometheus_release}  cluster=${cluster_name}  elapsed=$((build_end - build_start))s"
echo "  👉 ${outdir}"

if ((commit)); then
  if git -C "${cluster_dir}" diff --quiet -- kube-prometheus/ && git -C "${cluster_dir}" diff --cached --quiet -- kube-prometheus/; then
    echo "Nothing to commit in ${cluster_dir}/kube-prometheus"
    git -C "${cluster_dir}" checkout -q "${_original_branch}"
    git -C "${cluster_dir}" branch -q -d "${_new_branch}"
  else
    git -C "${cluster_dir}" add kube-prometheus/
    echo ""
    git -C "${cluster_dir}" diff --cached --stat
    echo ""

    if command -v gpg >/dev/null 2>&1 && gpg --card-status >/dev/null 2>&1; then
      echo "  >>> Touch your YubiKey to sign the commit <<<"
      echo ""
    fi

    if ! git -C "${cluster_dir}" commit -m "kube-prometheus: rebuild manifests for ${cluster_name} (${kube_prometheus_release})" 2>/dev/null; then
      echo "ERROR: GPG signing failed — YubiKey not touched in time or cancelled"
      echo ""
      echo "  Branch: ${_new_branch}"
      echo "  Retry:  git -C '${cluster_dir}' checkout '${_new_branch}' && git commit"
      git -C "${cluster_dir}" checkout -q "${_original_branch}"
      exit 1
    fi

    git -C "${cluster_dir}" checkout -q "${_original_branch}"

    echo ""
    read -rp "Push branch '${_new_branch}' or rebase into '${_original_branch}'? [push/rebase] " _action
    case "${_action}" in
    push)
      git -C "${cluster_dir}" push origin "${_new_branch}"
      ;;
    rebase)
      git -C "${cluster_dir}" rebase "${_new_branch}"
      git -C "${cluster_dir}" branch -d "${_new_branch}"
      ;;
    *)
      echo "Unknown action '${_action}', branch '${_new_branch}' left as-is"
      ;;
    esac
  fi
fi
