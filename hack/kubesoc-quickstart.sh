#!/usr/bin/env bash
# kubesoc quickstart: the security operations stack (Wazuh, DFIR-IRIS, MISP,
# Velociraptor, the reconciler) with one demo tenant on a single machine, for
# evaluation. Target: under 30 minutes on a fresh 8 CPU / 24 GiB Linux host.
#
#   git clone https://github.com/Obmondo/KubeAid && cd KubeAid
#   ./hack/kubesoc-quickstart.sh
#
# Steps (each is skipped when already done, so the script can be re-run):
#   1. k3s, unless $KUBECONFIG (or ~/.kube/config) already reaches a cluster
#   2. prerequisites from this checkout's charts: sealed-secrets, cert-manager,
#      CloudNativePG, mariadb-operator (+ its CRDs), a self-signed ClusterIssuer
#   3. a development Keycloak (in-memory, plain HTTP), unless KEYCLOAK_URL is set
#   4. kubeaid-cli siem quickstart --run: renders the config (profile single,
#      tenant "demo", reconciler dry-run off) and installs it with Helm
#
# Settings (environment):
#   KUBEAID_CLI      kubeaid-cli binary                   (default: kubeaid-cli)
#   NODE_IP          IP agents and browsers use           (default: first host IP)
#   DOMAIN           base domain of the SOC hosts         (default: $NODE_IP.nip.io)
#   WORKDIR          config, rendered files, install.sh   (default: ./kubesoc-quickstart)
#   KEYCLOAK_URL     existing Keycloak (with /auth)       (default: deploy a dev one)
#   CLUSTER_ISSUER   cert-manager ClusterIssuer           (default: kubesoc-selfsigned)
#   RECONCILER_TAG   siem-reconciler image tag            (default: the chart's)
#   AI_TRIAGE=1      enable AI triage (pulls the model; ~10 GiB more memory)
#   ASSUME_YES=1     do not ask before installing
#
# With self-signed certificates the browsers warn and single sign-on between
# the components may refuse the Keycloak certificate: for a full SSO trial use a
# real DOMAIN with DNS and CLUSTER_ISSUER=letsencrypt-prod.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
kubeaid="$(cd "$here/.." && pwd)"
charts="$kubeaid/argocd-helm-charts"

KUBEAID_CLI="${KUBEAID_CLI:-kubeaid-cli}"
WORKDIR="${WORKDIR:-$PWD/kubesoc-quickstart}"
CLUSTER_ISSUER="${CLUSTER_ISSUER:-kubesoc-selfsigned}"

log() { printf '\n==> %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }

need helm
need kubectl
need "$KUBEAID_CLI"

# 1. Cluster.
if ! kubectl version >/dev/null 2>&1; then
  if [ -r /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  else
    log "Installing k3s (single node, with its Traefik ingress)"
    need curl
    curl -sfL https://get.k3s.io | sudo sh -s - --write-kubeconfig-mode 0644
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  fi
  kubectl wait --for=condition=Ready node --all --timeout=5m
fi
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

NODE_IP="${NODE_IP:-$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')}"
DOMAIN="${DOMAIN:-$NODE_IP.nip.io}"
echo "node IP $NODE_IP, domain $DOMAIN"

# 2. Prerequisites.
release() { # name chart namespace [helm args...]
  local name="$1" chart="$2" ns="$3"
  shift 3
  log "Installing $name"
  helm upgrade --install "$name" "$chart" --namespace "$ns" --create-namespace --wait --timeout 15m "$@"
}
release sealed-secrets "$charts/sealed-secrets" sealed-secrets \
  --set sealed-secrets.namespace=sealed-secrets \
  --set sealed-secrets.fullnameOverride=sealed-secrets-controller \
  --set backup=null
release cert-manager "$charts/cert-manager" cert-manager
release cloudnative-pg "$charts/cloudnative-pg" cnpg-system
# mariadb-operator ships its CRDs as a separate chart.
release mariadb-operator-crds mariadb-operator-crds mariadb-operator \
  --repo https://mariadb-operator.github.io/mariadb-operator
release mariadb-operator "$charts/mariadb-operator" mariadb-operator

if [ "$CLUSTER_ISSUER" = kubesoc-selfsigned ]; then
  kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: kubesoc-selfsigned
spec:
  selfSigned: {}
EOF
fi

# 3. Keycloak.
if [ -z "${KEYCLOAK_URL:-}" ]; then
  log "Deploying a development Keycloak"
  kubectl get namespace keycloakx >/dev/null 2>&1 || kubectl create namespace keycloakx
  if ! kubectl -n keycloakx get secret keycloak-admin >/dev/null 2>&1; then
    kubectl -n keycloakx create secret generic keycloak-admin \
      --from-literal=KEYCLOAK_PASSWORD="$(head -c 18 /dev/urandom | base64 | tr -d '/+=')"
  fi
  sed "s/KEYCLOAK_HOST/keycloak.$DOMAIN/" "$here/kubesoc-quickstart/keycloak-dev.yaml" | kubectl apply -f -
  kubectl -n keycloakx rollout status deployment/keycloak --timeout 10m
  KEYCLOAK_URL="http://keycloak.$DOMAIN/auth"
  echo "Keycloak admin password: kubectl -n keycloakx get secret keycloak-admin -o jsonpath='{.data.KEYCLOAK_PASSWORD}' | base64 -d"
fi

# 4. The stack.
log "Rendering and installing the security operations stack"
args=(siem quickstart
  --dir "$WORKDIR"
  --kubeaid-dir "$kubeaid"
  --domain "$DOMAIN"
  --agent-address "$NODE_IP"
  --keycloak-url "$KEYCLOAK_URL"
  --cluster-issuer "$CLUSTER_ISSUER"
  --run)
[ -n "${RECONCILER_TAG:-}" ] && args+=(--reconciler-tag "$RECONCILER_TAG")
[ "${AI_TRIAGE:-0}" = 1 ] && args+=(--ai-triage)
[ "${ASSUME_YES:-0}" = 1 ] && args+=(--yes)
"$KUBEAID_CLI" "${args[@]}"

cat <<EOF

kubesoc quickstart is up (components keep starting for a few minutes):
  status:   $KUBEAID_CLI siem status --cluster-dir $WORKDIR/k8s/kubesoc-quickstart --agents=false
  enrol:    $KUBEAID_CLI siem enroll demo --os linux
  Wazuh:    https://wazuh.$DOMAIN      IRIS: https://iris.$DOMAIN
  MISP:     https://misp.$DOMAIN       Velociraptor: https://velociraptor.$DOMAIN
  tenant:   https://wazuh-demo.$DOMAIN (agents: $NODE_IP ports 1515/1514)
EOF
