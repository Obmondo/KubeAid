#!/usr/bin/env bash

set -euo pipefail

cd build/kube-prometheus

for cluster in kam.obmondo.com kbm.obmondo.com; do
  ./build.sh "${cluster}"
done

git diff -- .
