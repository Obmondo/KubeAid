#!/bin/bash

# Documentation
# It will drop the yaml files into kubernetes-config-<customer-id>/<cluster-name>
# You will have to simply drop the yaml file and add any more extra keys
#
# This scripts expect few things and does not do sanity check, so watch out for that
# It expects that both of these git repo sits in a same dir
# ssh://git@gitlab.enableit.dk:2223/kubernetes/kubernetes-config-<customer-id>.git
# ssh://git@gitlab.enableit.dk:2223/kubernetes/argocd-apps.git
#
# Example
# ./bin/generate-puppet-hiera.sh \
#     --cluster-name kam.obmondo.com \
#     --version 1.22.5 \
#     --san-domains kam.obmondo.com,localhost,176.9.67.43,htzsb44fsn1a.enableit.dk:78.46.72.21,htzsb45fsn1a.enableit.dk:176.9.124.207,htzsb45fsn1b.enableit.dk:85.10.211.48

set -euo pipefail

for cmd in docker eyaml yq; do
  if ! command -v "$cmd" >/dev/null; then
    echo "$cmd is not installed, please install it"
  fi
done

ARGFAIL() {
    echo -n "
Usage $0 [OPTION]:
  --cluster-name                  full cluser-name                   [Required]
  --version                       kubernetes cluster version         [Required]
  --container                     which container type to use
                                  - docker
                                  - podman
                                  - containerd                       Default=docker
  --san-domains                   list of domains in etcd clusters   [Required]
  --kubetool-version              kubetool version                   Default=6.2.0
  --eyaml-public-key              eyaml public key path, expects it
                                  to be under cluster-setup-scripts/puppet Default=public_key.pkcs7.pem
  --customer-id                   customer_id of a customer          Default=enableit
  -h | --help

Example:
# $0 --name your-cluster-name
"
}

if [[ $# -eq 0 ]]; then
  ARGFAIL
  exit 0
fi

declare CONTAINER_RT=docker
declare KUBETOOL_VERSION=6.2.0
declare EYAML_PUBLIC_KEY=public_key.pkcs7.pem
declare CUSTOMER_ID=enableit
declare -a ETCD_CLUSTERS_IPS=()
declare -a ETCD_CLUSTERS_EXTRA_SANS=()

while [[ $# -gt 0 ]]; do
  arg="$1"
  shift

  case "$arg" in
  --cluster-name)
    CLUSTER_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]') # Convert to lower case

    shift
    ;;
  --version)
    VERSION=$1

    shift
    ;;
  --container)
    # docker and cri_containerd is supported.
    CONTAINER_RT=$1

    echo -n "You have given ${CONTAINER_RT}, but this only works with docker, so defaulting to docker"
    shift
    ;;
  --san-domains)
    SAN_DOMAINS=$1

    shift
    ;;
  --kubetool-version)
    KUBETOOL_VERSION=$1

    shift
    ;;
  --eyaml-public-key)
    EYAML_PUBLIC_KEY=$1

    shift
    ;;
  --customer-id)
    CUSTOMER_ID=$1

    shift
    ;;
  -h|--help)
    ARGFAIL

    shift
    ;;
  esac
done

# If cluster name is not given in the args list, pick it up from the settings file
if [ -z "$CLUSTER_NAME" ]; then
  echo "no cluster name is given, please give one"
  exit 1
else
  if ! host "$CLUSTER_NAME" >/dev/null; then
    echo "$CLUSTER_NAME is not resolving, we can not proceed. Please add it in your DNS"
    exit 1
  fi
fi

if [ -z "$VERSION" ]; then
  echo -e "Need kubernetes version, can't proceed with that.
This scripts support kubernetes version 6.2.4"
  exit 1
fi

if [ -z "$SAN_DOMAINS" ]; then
  echo "NO san domains given, can't proceed with this."
  exit 1
else
  IFS="," read -r -a _SAN_DOMAINS <<< "${SAN_DOMAINS}"

  delim=""
  ETCD_INITIAL_CLUSTER=""
  for domain in "${_SAN_DOMAINS[@]}"; do
    if grep ':' <<< "$domain" >/dev/null; then
      ETCD_INITIAL_CLUSTER="$ETCD_INITIAL_CLUSTER$delim$domain"
      ETCD_CLUSTERS_IPS+=("$domain")
    else
      ETCD_INITIAL_CLUSTER="$ETCD_INITIAL_CLUSTER$delim$domain:$domain"
      ETCD_CLUSTERS_EXTRA_SANS+=("$domain")
    fi
    delim=","
  done

  unset IFS
fi

KUBERNETES_CONFIG_DIR="../kubernetes-config-${CUSTOMER_ID}/${CLUSTER_NAME}/hiera"
_EYAML_PUBLIC_KEY="../../../kubeaid/cluster-setup-files/puppet/${EYAML_PUBLIC_KEY}"

# Create the required directory
mkdir -p "${KUBERNETES_CONFIG_DIR}"
cd "${KUBERNETES_CONFIG_DIR}"

echo -e "OS=debian
INSTALL_DASHBOARD=true
CNI_PROVIDER=calico
ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER}
ETCD_IP=\"%{networking.ip}\"
KUBE_API_ADVERTISE_ADDRESS=\"%{networking.ip}\"
VERSION=${VERSION}
CONTAINER_RUNTIME=${CONTAINER_RT}" > kubetool_setup_env

# Generate the k8s hiera yaml files
docker run --rm -v "$(pwd)":/mnt --env-file kubetool_setup_env puppet/kubetool:"${KUBETOOL_VERSION}"

# NOTE: docker generate the yaml file with root perms
sudo chown -R "$USER:$USER" ./*

# Encrypt the keys
# cat htzsb45fsn1a.enableit.dk.yaml | yq eval '."kubernetes::etcdclient_key"' - | eyaml encrypt --stdin --output=block --pkcs7-public-key=../public_key.pkcs7.pem -
for ETCD_NODE in "${ETCD_CLUSTERS_IPS[@]}"; do
  NODE_FILENAME=$(echo "${ETCD_NODE}" | cut -d ':' -f1)

  # Need to encrypt these keys from the nodes file
  # kubernetes::etcdserver_key
  # kubernetes::etcdpeer_key
  # kubernetes::etcdclient_key

  for NODE_KEYS in etcdserver_key etcdpeer_key etcdclient_key; do
    _NODE_KEYS=$(yq eval ".\"kubernetes::${NODE_KEYS}\"" "${NODE_FILENAME}".yaml \
                  | eyaml encrypt --stdin --output=string --pkcs7-public-key="${_EYAML_PUBLIC_KEY}" -)

    yq eval --inplace ".\"kubernetes::${NODE_KEYS}\" = \"${_NODE_KEYS}\"" "${NODE_FILENAME}".yaml
  done
done

# NOTE
# We are removing etcdclient_crt and etcdclient_key from the hiera
# since its not getting used anywhere and when looked into cert, no details as well
#        Issuer: CN = etcd
#        Validity
#            Not Before: Dec 22 21:50:00 2021 GMT
#            Not After : Dec 21 21:50:00 2026 GMT
#        Subject: CN = client

yq eval --inplace "del(.\"kubernetes::etcdclient_key\")" Debian.yaml
yq eval --inplace "del(.\"kubernetes::etcdclient_crt\")" Debian.yaml

# Let's encrypt the Debian.yaml private keys
# Need to encrypt these keys from the OS family file
# kubernetes::etcd_ca_key
# kubernetes::kubernetes_ca_key
# kubernetes::discovery_token_hash
# kubernetes::sa_key
# kubernetes::token
for OSFAMILY_KEYS in etcd_ca_key kubernetes_ca_key discovery_token_hash sa_key token; do
  _OSFAMILY_KEYS=$(yq eval ".\"kubernetes::${OSFAMILY_KEYS}\"" Debian.yaml \
                  | eyaml encrypt \
                  --stdin --output=string \
                  --pkcs7-public-key="${_EYAML_PUBLIC_KEY}" -)

  yq eval --inplace ".\"kubernetes::${OSFAMILY_KEYS}\" = \"${_OSFAMILY_KEYS}\"" Debian.yaml
done

# Change the key name as per puppet role
# TODO: oneliner would be nice, but a quick solution is not bad though.
FRONT_CA_KEY=$(yq eval ".\"kubernetes::kubernetes_front_proxy_ca_key\"" Debian.yaml)
yq eval --inplace ".\"kubernetes::front_proxy_ca_key\" = \"${FRONT_CA_KEY}\"" Debian.yaml
FRONT_CA_CERT=$(yq eval ".\"kubernetes::kubernetes_front_proxy_ca_crt\"" Debian.yaml)
yq eval --inplace ".\"kubernetes::front_proxy_ca_crt\" = \"${FRONT_CA_CERT}\"" Debian.yaml

# Delete these keys, since will setup our own keys based on the role::virtualization::kubernetes class
yq eval --inplace "del(.\"kubernetes::etcd_peers\")" Debian.yaml
yq eval --inplace "del(.\"kubernetes::kubernetes_front_proxy_ca_crt\")" Debian.yaml
yq eval --inplace "del(.\"kubernetes::kubernetes_front_proxy_ca_key\")" Debian.yaml
yq eval --inplace "del(.\"kubernetes::kubernetes_package_version\")" Debian.yaml
yq eval --inplace "del(.\"kubernetes::kubernetes_version\")" Debian.yaml

# Let's encrypt the few bad keys which comes from the kubetool command.
ETCD_CLUSTER_NODES=""
delim=""
for IPS in "${ETCD_CLUSTERS_IPS[@]}"; do
  _HOSTNAME=$(cut -d ':' -f 1 <<< "${IPS}")
  NODE_IP=$(cut -d ':' -f 2 <<< "${IPS}")
  ETCD_CLUSTER_NODES="$ETCD_CLUSTER_NODES$delim${_HOSTNAME}=https://${NODE_IP}:2380"
  delim=","

  # Fix the peers list
  yq eval --inplace ".\"kubernetes::etcd_peers\" += [\"${NODE_IP}\"]" Debian.yaml
done

# Fix the initial_cluster setting
yq eval --inplace ".\"kubernetes::etcd_initial_cluster\" = \"${ETCD_CLUSTER_NODES}\"" Debian.yaml

# Let's fix the calico version as well
# NOTE: We are using 3.18 for now, since this is what we having been using and dont want any surprises.
yq eval --inplace ".\"kubernetes::cni_network_provider\" = \"https://docs.projectcalico.org/v3.18/manifests/calico.yaml\"" Debian.yaml

# Fix the controller address
# NOTE: We expect the cluster-name is a domain which can resolve.
yq eval --inplace ".\"kubernetes::controller_address\" = \"${CLUSTER_NAME}:6443\"" Debian.yaml

# Lets add the extra SANS cert
for DOMAIN in "${ETCD_CLUSTERS_EXTRA_SANS[@]}"; do
  yq eval --inplace ".\"kubernetes::apiserver_cert_extra_sans\" += [\"${DOMAIN}\"]" Debian.yaml

  # Remove these files as well
  rm -f "${DOMAIN}".yaml
done

# Lets add the api_server_count
yq eval --inplace ".\"kubernetes::api_server_count\" = ${#ETCD_CLUSTERS_IPS[@]}" Debian.yaml

# lets change all the keys
grep -l '^kubernetes::' ./* | xargs sed -i 's/^kubernetes/role::virtualization::kubernetes/g'

# Lets have some sane defaults
yq eval --inplace ".classes += [\"role::virtualization::kubernetes\"]" Debian.yaml
yq eval --inplace ".\"monitor::enable\" = false" Debian.yaml
yq eval --inplace ".\"common::network::firewall::enable\" = true" Debian.yaml
yq eval --inplace ".\"common::network::firewall::allow_docker\" = true" Debian.yaml
yq eval --inplace ".\"common::network::firewall::allow_k8s\" = true" Debian.yaml
yq eval --inplace ".\"common::network::firewall::enable_forwarding\" = true" Debian.yaml
yq eval --inplace ".\"common::monitor::exporter::ssl::enable\" = false" Debian.yaml
yq eval --inplace ".\"role::virtualization::kubernetes::extra_public_ports\" = [3025]" Debian.yaml
yq eval --inplace ".\"role::virtualization::kubernetes::role\" = \"controller\"" Debian.yaml
yq eval --inplace ".\"role::virtualization::kubernetes::version\" = \"${VERSION}\"" Debian.yaml

#- r2d2.enableit.dk # klavs home
TRUSTED_SOURCES=(109.238.49.196/28 bantha.enableit.dk atat.enableit.dk r2d2.enableit.dk)
for SOURCE in "${TRUSTED_SOURCES[@]}"; do
  yq eval --inplace ".\"role::virtualization::kubernetes::allow_k8s_api\" += [\"${SOURCE}\"]" Debian.yaml
done

# lets just sort the keys
yq eval --inplace 'sort_keys(.)' Debian.yaml
