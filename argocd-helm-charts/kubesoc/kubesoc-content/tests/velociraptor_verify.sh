#!/usr/bin/env bash
# `velociraptor artifacts verify` over every artifact the reconciler sets: this
# package's velociraptor/artifacts and security-operations files/velociraptor
# (verified together, so artifacts may call each other). Needs docker.
#   argocd-helm-charts/kubesoc/kubesoc-content/tests/velociraptor_verify.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

image=${VELOCIRAPTOR_IMAGE:-ghcr.io/maximewewer/velociraptor:0.77.1-distroless}
files=()
for f in kubesoc-content/velociraptor/artifacts/*.yaml security-operations/files/velociraptor/*.yaml; do
  [[ -f "$f" ]] && files+=("/src/$f")
done
if [[ ${#files[@]} -eq 0 ]]; then
  echo "no artifacts"
  exit 0
fi
docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" "$image" artifacts verify "${files[@]}"
echo "velociraptor verify: ${#files[@]} artifacts ok"
