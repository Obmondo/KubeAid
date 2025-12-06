#!/bin/sh

ROOT_CA_NAME=`jq -r '.root_ca_name' ca.config`
INTERMEDIATE_CA_NAME=`jq -r '.intermediate_ca_name' ca.config`
CA_ORG_NAME=`jq -r '.ca_org_name' ca.config`
CA_COUNTRY_NAME=`jq -r '.ca_country_name' ca.config`
CA_LOCALITY_NAME=`jq -r '.ca_locality_name' ca.config`
CA_DNS_NAMES=`jq -c .ca_dns_names ca.config`
CA_URL=`jq -r .ca_url ca.config`
JWK_PROVISIONER_NAME=`jq -r .jwk_provisioner_name ca.config`

export ROOT_CA_NAME INTERMEDIATE_CA_NAME CA_ORG_NAME CA_COUNTRY_NAME CA_LOCALITY_NAME CA_DNS_NAMES CA_URL JWK_PROVISIONER_NAME

# Write Out Root and Intermediate Certificate Templates
cat root-tls.json.tpl | envsubst | tee root-tls.json
cat intermediate-tls.json.tpl | envsubst | tee intermediate-tls.json

# Generate Root and Intermediate Passwords
ROOT_TLS_PASSWORD_B64=`tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_\`{|}~' </dev/urandom | head -c 64 | tee root-tls.password | base64 --wrap=0`
INTERMEDIATE_TLS_PASSWORD_B64=`tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_\`{|}~' </dev/urandom | head -c 64 | tee intermediate-tls.password | base64 --wrap=0`

# Generate Root CA Certificate Pair
step certificate create \
  "${ROOT_CA_NAME}" \
  "root-tls.crt" \
  "root-tls.key" \
  --template="root-tls.json" \
  --kty="EC" \
  --curve="P-256" \
  --password-file="root-tls.password" \
  --not-before="0s" \
  --not-after="44520h" \
  --force

TLS_ROOT_CRT=`cat root-tls.crt | sed 's/^/        /'`
TLS_ROOT_KEY=`cat root-tls.key | sed 's/^/        /'`
TLS_ROOT_FINGERPRINT=`step certificate fingerprint root-tls.crt`

# Generate Intermediate CA Certificate Pair
step certificate create \
  "${INTERMEDIATE_CA_NAME}" \
  "intermediate-tls.crt" \
  "intermediate-tls.key" \
  --template="intermediate-tls.json" \
  --kty="EC" \
  --curve="P-256" \
  --password-file="intermediate-tls.password" \
  --not-before="0s" \
  --not-after="17760h" \
  --ca="root-tls.crt" \
  --ca-key="root-tls.key" \
  --ca-password-file="root-tls.password" \
  --force

TLS_INTERMEDIATE_CRT=`cat intermediate-tls.crt | sed 's/^/        /'`
TLS_INTERMEDIATE_KEY=`cat intermediate-tls.key | sed 's/^/        /'`

# Generate SSH Host CA Password
SSH_HOST_PASSWORD=`tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_\`{|}~' </dev/urandom | head -c 64 | tee host-ssh.password`
SSH_HOST_PASSWORD_B64=`echo ${SSH_HOST_PASSWORD} | base64 --wrap=0`

# Generate SSH Host CA Keypair
ssh-keygen -q -t ecdsa -b 256 -f host-ssh.key -C "SSH Host Key" -N ${SSH_HOST_PASSWORD}

SSH_HOST_CRT=`cat host-ssh.key.pub`
SSH_HOST_KEY=`cat host-ssh.key | sed 's/^/        /'`

# Generate SSH User CA Password
SSH_USER_PASSWORD=`tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_\`{|}~' </dev/urandom | head -c 64 | tee user-ssh.password`
SSH_USER_PASSWORD_B64=`echo ${SSH_USER_PASSWORD} | base64 --wrap=0`

# Generate SSH User CA Keypair
ssh-keygen -q -t ecdsa -b 256 -f user-ssh.key -C "SSH User Key" -N ${SSH_USER_PASSWORD}

SSH_USER_CRT=`cat user-ssh.key.pub`
SSH_USER_KEY=`cat user-ssh.key | sed 's/^/        /'`

JWK_PROVISIONER_PASSWORD_B64=`tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_\`{|}~' </dev/urandom | head -c 64 | tee jwk_provisioner.password | base64 --wrap=0`

step crypto jwk create \
  jwk_provisioner.pub \
  jwk_provisioner.key \
  --kty=EC \
  --curve=P-256 \
  --use=sig \
  --password-file=jwk_provisioner.password \
  --force

JWK_PROVISIONER_KEY=`cat jwk_provisioner.key | step crypto jose format | tee jwk_provisioner.compact.key`
JWK_PROVISIONER_CRT_ALG=`jq '.alg' -r jwk_provisioner.pub`
JWK_PROVISIONER_CRT_CRV=`jq '.crv' -r jwk_provisioner.pub`
JWK_PROVISIONER_CRT_KID=`jq '.kid' -r jwk_provisioner.pub`
JWK_PROVISIONER_CRT_KTY=`jq '.kty' -r jwk_provisioner.pub`
JWK_PROVISIONER_CRT_USE=`jq '.use' -r jwk_provisioner.pub`
JWK_PROVISIONER_CRT_X=`jq '.x' -r jwk_provisioner.pub`
JWK_PROVISIONER_CRT_Y=`jq '.y' -r jwk_provisioner.pub`

export \
  ROOT_TLS_PASSWORD_B64 TLS_ROOT_CRT TLS_ROOT_KEY TLS_ROOT_FINGERPRINT \
  INTERMEDIATE_TLS_PASSWORD_B64 TLS_INTERMEDIATE_CRT TLS_INTERMEDIATE_KEY \
  SSH_HOST_PASSWORD_B64 SSH_HOST_CRT SSH_HOST_KEY \
  SSH_USER_PASSWORD_B64 SSH_USER_CRT SSH_USER_KEY \
  JWK_PROVISIONER_PASSWORD_B64 JWK_PROVISIONER_KEY JWK_PROVISIONER_CRT_ALG \
  JWK_PROVISIONER_CRT_CRV JWK_PROVISIONER_CRT_KID JWK_PROVISIONER_CRT_KTY \
  JWK_PROVISIONER_CRT_USE JWK_PROVISIONER_CRT_X JWK_PROVISIONER_CRT_Y

cat values.yml.tpl | envsubst | tee values.yml
