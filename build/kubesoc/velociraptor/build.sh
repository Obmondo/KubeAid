#!/usr/bin/env bash
# Build the kubesoc Velociraptor image from the pinned official release.
#
#   ./build.sh                         build linux/amd64 into the local docker
#   ./build.sh --platform linux/arm64  another architecture (amd64, arm64)
#   ./build.sh --image REPO            image name (default ghcr.io/obmondo/kubesoc-velociraptor)
#   ./build.sh --print-sums VERSION    download VERSION, verify its Velocidex
#                                      signature, print the versions.env lines
#
# Never pushes. To publish, push the built tag yourself (or run buildx with
# --push in CI) after the build has passed its checks.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="ghcr.io/obmondo/kubesoc-velociraptor"
PLATFORM="linux/amd64"
KEY_FPR="0572F28B4EF19A043F4CBBE0B22A7FB19CB6CFA1"

print_sums() {
  local version="$1" tmp arch asset base sum signer
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  export GNUPGHOME="$tmp/gnupg"
  mkdir -m 0700 "$GNUPGHOME"
  gpg --batch --quiet --import "$HERE/velocidex-release-key.asc"
  echo "VELOCIRAPTOR_VERSION=$version"
  for arch in amd64 arm64; do
    asset="velociraptor-v${version}-linux-${arch}"
    base="https://github.com/Velocidex/velociraptor/releases/download/v${version}"
    curl -fsSL --retry 3 -o "$tmp/$asset" "$base/$asset"
    curl -fsSL --retry 3 -o "$tmp/$asset.sig" "$base/$asset.sig"
    signer="$(gpg --batch --status-fd 1 --verify "$tmp/$asset.sig" "$tmp/$asset" 2>/dev/null | awk '$2 == "VALIDSIG" { print $NF }')"
    if [ "$signer" != "$KEY_FPR" ]; then
      echo "$asset: bad or missing Velocidex signature" >&2
      return 1
    fi
    sum="$(shasum -a 256 "$tmp/$asset" 2>/dev/null || sha256sum "$tmp/$asset")"
    echo "SHA256_$(tr '[:lower:]' '[:upper:]' <<<"$arch")=${sum%% *}"
  done
}

while [ $# -gt 0 ]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --print-sums) print_sums "$2"; exit ;;
    -h|--help) sed -n '2,12p' "$0"; exit ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=versions.env
. "$HERE/versions.env"

docker buildx build \
  --platform "$PLATFORM" \
  --build-arg "VELOCIRAPTOR_VERSION=$VELOCIRAPTOR_VERSION" \
  --build-arg "SHA256_AMD64=$SHA256_AMD64" \
  --build-arg "SHA256_ARM64=$SHA256_ARM64" \
  --tag "$IMAGE:$VELOCIRAPTOR_VERSION" \
  --load \
  "$HERE"

# The image must run as non-root with the release binary as its entrypoint.
docker run --rm --platform "$PLATFORM" "$IMAGE:$VELOCIRAPTOR_VERSION" version | grep -q "version: $VELOCIRAPTOR_VERSION"
[ "$(docker image inspect "$IMAGE:$VELOCIRAPTOR_VERSION" --format '{{.Config.User}}')" = "65532:65532" ]
echo "built $IMAGE:$VELOCIRAPTOR_VERSION ($PLATFORM)"
