#!/bin/bash
#
# Install jsonnet-bundler dependencies for a given kube-prometheus version.
#
# Must be run from the root of the KubeAid repo.
# Usage: ./build/kube-prometheus/setup-version.sh <version-tag>

set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version-tag>"
  exit 1
fi

if ! command -v jb &>/dev/null; then
  echo "'jb' command not found. Please install jsonnet-bundler."
  exit 1
fi

VERSION=$1
INSTALLPATH="${BASEDIR}/libraries/${VERSION}"

if [[ -e "$INSTALLPATH" ]]; then
  echo "Version $VERSION already exists at $INSTALLPATH. Remove it first to reinstall."
  exit 1
fi

mkdir -p "$INSTALLPATH"
cd "$INSTALLPATH" || exit 1

jb init
jb install "github.com/prometheus-operator/kube-prometheus/jsonnet/kube-prometheus@${VERSION}"
jb install "github.com/bitnami-labs/sealed-secrets/contrib/prometheus-mixin@main"
jb install "github.com/obmondo/ceph/monitoring/ceph-mixin@main"
jb install "gitlab.com/uneeq-oss/cert-manager-mixin@master"
jb install "github.com/grafana/jsonnet-libs/opensearch-mixin@master"
jb install "github.com/grafana/jsonnet-libs/cilium-enterprise-mixin@master"
jb install "github.com/adinhodovic/opencost-mixin@main"
jb install "github.com/grafana/jsonnet-libs/mixin-utils@master"

if [ "$VERSION" == "v0.13.0" ]; then
  jb install "github.com/adinhodovic/rabbitmq-mixin@master"
else
  jb install "github.com/grafana/jsonnet-libs/rabbitmq-mixin@master"
fi

echo ""
echo "Version ${VERSION} setup complete at ${INSTALLPATH}."
echo "Exact commits are pinned in jsonnetfile.lock.json."
