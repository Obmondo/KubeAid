#!/usr/bin/env bash
# `velociraptor artifacts verify` over every artifact the reconciler sets: this
# package's velociraptor/artifacts and the umbrella chart's files/velociraptor
# (verified together, so artifacts may call each other). Needs docker.
#   argocd-helm-charts/kubesoc/charts/kubesoc-content/tests/velociraptor_verify.sh
set -euo pipefail
# the umbrella chart root: its files/velociraptor and this package's artifacts
cd "$(dirname "$0")/../../.."

image=${VELOCIRAPTOR_IMAGE:-ghcr.io/maximewewer/velociraptor:0.77.1-distroless}
files=()
for f in charts/kubesoc-content/velociraptor/artifacts/*.yaml files/velociraptor/*.yaml; do
  [[ -f "$f" ]] && files+=("/src/$f")
done
# Finding nothing means the layout moved under this script, not that there is
# nothing to check: fail rather than report a green run that verified nothing.
if [[ ${#files[@]} -eq 0 ]]; then
  echo "no artifacts found under $PWD -- the paths this script globs have moved" >&2
  exit 1
fi
docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" "$image" artifacts verify "${files[@]}"
echo "velociraptor verify: ${#files[@]} artifacts ok"
