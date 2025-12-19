# Puppet Server with Linuxaid

## Secret setup to access puppet and hieradata git repo

* Create hiera and puppet git repo secret
* Create a Bot user on github/gitea
* Create a PAT and give only **read** permission for the below two repo (on gitea there is no option to be repo specific)
* Create a file based on the example [file](./examples/netrc)

```sh
kubectl create secret generic hiera-git-secret --dry-run=client --from-file=netrc=./netrc.enableit -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml
```

* Create puppet repo secret

```sh
kubectl create secret generic puppet-git-secret --dry-run=client --from-file=netrc=./netrc.enableit -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml
```

## Environment name

* Env name gets changed, when using hyphen, so watch out for that

```
Environment "adding-users-in-computer10" contained non-word characters, correcting name to adding_users_in_computer10
```

## Eyaml secret

* Create the private and public key.

```sh
# Run the following command to generate a private key:
docker run --rm  --name hiera-eyaml -it ubuntu:latest /bin/bash
root@b20b838ad0cb:/# apt update && apt install ruby
root@b20b838ad0cb:/# gem install hiera-eyaml
root@b20b838ad0cb:/# eyaml createkeys --pkcs7-private-key=/tmp/private_key.pkcs7.pem --pkcs7-public-key=/tmp/public_key.pkcs7.pem
```

* Create the k8s sealed secret with the above generated keys

```sh
sudo chmod 775  /tmp/private_key.pkcs7.pem
sudo chmod 775  /tmp/public_key.pkcs7.pem
kubectl create secret generic eyaml-keys --namespace puppetserver --dry-run=client --from-file=private_key.pkcs7.pem=/tmp/private_key.pkcs7.pem --from-file=public_key.pkcs7.pem=/tmp/public_key.pkcs7.pem -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml > eyaml-keys.yaml
```

## Add PuppetCA cert as a tlsoption (traefik)

* Create a secret, which will be consumed by tlsOption (Traefik), this is needed to 2 reasons.

1. prometheus agent on linux server sending metrics gets validated by traefik, since they send the metrics using the puppet client cert
2. puppetdb can be access only by using the puppet client cert.

If you are not setting up prometheus agent or dont want to talk to puppetdb, you can skip this step.

```raw
# take shell inside the puppetserver pod and copy the ca_crt.pem

root@puppet:/etc/puppetlabs/puppetserver/ca# cat ca_crt.pem
-----BEGIN CERTIFICATE-----
MIIFgTCCA2mgAwIBAgIBAjANBgkqhkiG9w0BAQsFADApMScwJQYDVQQDDB5QdXBw
ZXQgUm9vdCBDQTogZDc0ZWQyZTFjYzE1OWYwHhcNMjUwODEyMDE1OTUxWhcNNDAw
ODA5MDE1OTU1WjBFMUMwQQYDVQQDDDpQdXBwZXQgQ0EgZ2VuZXJhdGVkIG9uIHB1
```

Copy the above cert locally on your workstation and create the cert.

```sh
kubectl create secret generic puppetca-cert --dry-run=client --namespace traefik  --from-file=ca.crt=/tmp/kds.pem -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml > puppetca-cert.yaml
```

Add the tlsoption in the values-traefik.yaml

```yaml
    prometheus-puppet-agent-tls-auth:
      maxVersion: VersionTLS13
      minVersion: VersionTLS12
      clientAuth:
        clientAuthType: RequireAndVerifyClientCert
        secretNames:
          - puppetca-cert
```

### Connect the self hosted puppetserver to Obmondo

* Ask for a certificate from Obmondo
* Create the required secret

```sh
kubectl create secret tls obmondo-clientcert --namespace puppetserver --dry-run=client --key=./certs/puppetserver-private.key --cert=./certs/puppetserver-cert.pem --output=yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml - > k8s/kubeaid-kds-demo/sealed-secrets/puppetserver/obmondo-clientcert.yaml
```

* Replace the AUTOSIGN env variable, in the values file of puppetserver

```yaml
AUTOSIGN_CLIENT_CERT: /opt/obmondo/ssl/puppetserver-cert.crt
AUTOSIGN_CLIENT_KEY: /opt/obmondo/ssl/puppetserver-priv.key
```
