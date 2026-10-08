#!/usr/bin/env bash
# CI test script for the vuls-dictionary Helm chart.
# Runs helm template with various value combinations to verify the chart renders correctly.
set -euo pipefail

CHART_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_NAME="test"
PASS=0
FAIL=0

run_test() {
  local desc="$1"
  shift
  echo -n "TEST: ${desc} ... "
  if output=$(helm template "$RELEASE_NAME" "$CHART_DIR" "$@" 2>&1); then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    echo "$output"
    FAIL=$((FAIL + 1))
  fi
}

assert_present() {
  local desc="$1"
  local pattern="$2"
  shift 2
  echo -n "TEST: ${desc} ... "
  if helm template "$RELEASE_NAME" "$CHART_DIR" "$@" 2>&1 | grep -q "$pattern"; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL (expected pattern: ${pattern})"
    FAIL=$((FAIL + 1))
  fi
}

assert_absent() {
  local desc="$1"
  local pattern="$2"
  shift 2
  echo -n "TEST: ${desc} ... "
  if helm template "$RELEASE_NAME" "$CHART_DIR" "$@" 2>&1 | grep -q "$pattern"; then
    echo "FAIL (unexpected pattern found: ${pattern})"
    FAIL=$((FAIL + 1))
  else
    echo "PASS"
    PASS=$((PASS + 1))
  fi
}

echo "=== vuls-dictionary Helm chart CI tests ==="
echo ""

# --- Default values ---
run_test "default values render successfully"

assert_present "default: vuls DB PVC present" "db-pvc"
assert_present "default: vuls-server deployment present" "vuls-server"
assert_present "default: configmap present" "vuls-config"
assert_present "default: results PVC present" "results-pvc"

# --- vulsServer enabled ---
run_test "vulsServer enabled renders successfully" \
  --set vulsServer.enabled=true

assert_present "vulsServer: deployment created" "test-vuls-dictionary-vuls-server" \
  --set vulsServer.enabled=true

assert_present "vulsServer: service created" "kind: Service" \
  --set vulsServer.enabled=true

assert_present "vulsServer: configmap created" "vuls-config" \
  --set vulsServer.enabled=true

assert_present "vulsServer: results PVC created" "results-pvc" \
  --set vulsServer.enabled=true

assert_present "vulsServer: db PVC created" "db-pvc" \
  --set vulsServer.enabled=true

assert_present "vulsServer: image is vuls/vuls:v0.41.0" "vuls/vuls:v0.41.0" \
  --set vulsServer.enabled=true

assert_present "vulsServer: listens on port 5515" "containerPort: 5515" \
  --set vulsServer.enabled=true

assert_present "vulsServer: vuls2 DB path is separate PVC" "Path = \"/vuls-db/vuls.db\"" \
  --set vulsServer.enabled=true \
  --show-only templates/configmap.yaml

assert_present "vulsServer: cleanup init container present" "cleanup-vuls-results" \
  --set vulsServer.enabled=true \
  --show-only templates/deployment-vuls-server.yaml

assert_present "vulsServer: legacy DB cleanup present" "removing legacy database file" \
  --set vulsServer.enabled=true \
  --show-only templates/deployment-vuls-server.yaml

assert_present "vulsServer: DB fetch skips valid cache" "skipping fetch" \
  --set vulsServer.enabled=true \
  --show-only templates/deployment-vuls-server.yaml

# --- Ingress variations ---
run_test "ingress disabled (default)" \
  --set ingress.enabled=false

assert_absent "ingress disabled: no Ingress resource" "kind: Ingress" \
  --set ingress.enabled=false

run_test "ingress enabled without vuls-server" \
  --set ingress.enabled=true

assert_absent "ingress without vulsServer: no vuls-server backend in ingress" "vuls-server" \
  --set ingress.enabled=true \
  --show-only templates/ingress.yaml

run_test "ingress enabled with vuls-server" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true

assert_present "ingress with vulsServer: vuls-server backend present" "test-vuls-dictionary-vuls-server" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true

assert_present "ingress with vulsServer: port 5515 in ingress" "number: 5515" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true

# --- InFlightReq middleware ---
assert_absent "inFlightReq disabled (default): no Middleware" "kind: Middleware" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true

assert_present "inFlightReq enabled: Middleware rendered" "kind: Middleware" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true \
  --set ingress.vulsServer.inFlightReq.enabled=true

assert_present "inFlightReq enabled: amount set" "amount: 3" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true \
  --set ingress.vulsServer.inFlightReq.enabled=true \
  --set ingress.vulsServer.inFlightReq.amount=3

assert_present "inFlightReq enabled: ingress carries the middleware annotation" "router.middlewares: default-test-vuls-dictionary-vuls-inflight@kubernetescrd" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true \
  --set ingress.vulsServer.inFlightReq.enabled=true

assert_present "inFlightReq enabled: existing middlewares annotation kept" "router.middlewares: traefik-jwt@kubernetescrd,default-test-vuls-dictionary-vuls-inflight@kubernetescrd" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=true \
  --set ingress.vulsServer.enabled=true \
  --set ingress.vulsServer.inFlightReq.enabled=true \
  --set 'ingress.annotations.traefik\.ingress\.kubernetes\.io/router\.middlewares=traefik-jwt@kubernetescrd'

assert_absent "inFlightReq enabled but ingress disabled: no Middleware" "kind: Middleware" \
  --set vulsServer.enabled=true \
  --set ingress.enabled=false \
  --set ingress.vulsServer.inFlightReq.enabled=true

# --- vulsExporter sidecar ---
run_test "vulsExporter disabled by default" \
  --set vulsServer.enabled=true

assert_absent "vulsExporter disabled: no exporter container" "vuls-exporter" \
  --show-only templates/deployment-vuls-server.yaml

assert_absent "vulsExporter disabled: no exporter configmap" "vuls-exporter-config" \
  --show-only templates/configmap-vuls-exporter.yaml 2>/dev/null || true

run_test "vulsExporter enabled renders successfully" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --set vulsExporter.tls.secretName=vuls-exporter-tls

assert_present "vulsExporter: sidecar container present" "vuls-exporter" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --set vulsExporter.tls.secretName=vuls-exporter-tls \
  --show-only templates/deployment-vuls-server.yaml

assert_present "vulsExporter: TLS secret volume mounted" "vuls-exporter-tls" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --set vulsExporter.tls.secretName=vuls-exporter-tls \
  --show-only templates/deployment-vuls-server.yaml

assert_present "vulsExporter: configmap created" "vuls-exporter-config" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --set vulsExporter.tls.secretName=vuls-exporter-tls \
  --show-only templates/configmap-vuls-exporter.yaml

assert_present "vulsExporter: config has obmondo URL" "https://api.obmondo.com" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --set vulsExporter.tls.secretName=vuls-exporter-tls \
  --show-only templates/configmap-vuls-exporter.yaml

assert_present "vulsExporter: config has cert paths" "cert_file" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --set vulsExporter.tls.secretName=vuls-exporter-tls \
  --show-only templates/configmap-vuls-exporter.yaml

run_test "vulsExporter without TLS secret renders successfully" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com

assert_absent "vulsExporter no TLS: no TLS volume" "vuls-exporter-tls" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --show-only templates/deployment-vuls-server.yaml

assert_absent "vulsExporter no TLS: no cert_file in config" "cert_file" \
  --set vulsExporter.enabled=true \
  --set vulsExporter.obmondo.url=https://api.obmondo.com \
  --show-only templates/configmap-vuls-exporter.yaml

# --- Custom values ---
run_test "custom vuls-server port" \
  --set vulsServer.enabled=true \
  --set vulsServer.port=9999

assert_present "custom port: containerPort 9999" "containerPort: 9999" \
  --set vulsServer.enabled=true \
  --set vulsServer.port=9999

run_test "custom results storage size" \
  --set vulsServer.enabled=true \
  --set vulsServer.resultsStorage.size=10Gi

assert_present "custom storage: 10Gi in results PVC" "storage: 10Gi" \
  --set vulsServer.enabled=true \
  --set vulsServer.resultsStorage.size=10Gi

run_test "custom database storage size" \
  --set vulsServer.enabled=true \
  --set vulsServer.databaseStorage.size=30Gi

assert_present "custom database storage: 30Gi in db PVC" "storage: 30Gi" \
  --set vulsServer.enabled=true \
  --set vulsServer.databaseStorage.size=30Gi \
  --show-only templates/pvc-db.yaml

run_test "vuls2 disabled renders without db PVC" \
  --set vuls2.enabled=false

assert_absent "vuls2 disabled: no db PVC" "db-pvc" \
  --set vuls2.enabled=false

assert_absent "vuls2 disabled: no vuls-db volume" "vuls-db" \
  --set vuls2.enabled=false \
  --show-only templates/deployment-vuls-server.yaml

# --- Summary ---
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
