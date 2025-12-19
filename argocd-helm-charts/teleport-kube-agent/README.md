# Teleport would need a secret to work

**NOTE: if there is no secret, pod would fail to start.**

## To get the cert from sealed-secret (its not required, but add this for info)

```sh
kubectl get secret --namespace system -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o jsonpath='{'.items[0].data."tls\.crt"'}' | base64 -d > /tmp/staging.pem
```

## To generate the secrete

```sh
kubectl create secret generic teleport-kube-agent-join-token -n obmondo --dry-run=client --from-literal=auth-token=xxx -o yaml | kubeseal --controller-name sealed-secrets-controller --controller-namespace sealed-secrets --cert /tmp/staging.pem -o yaml - > /tmp/teleport-kube-agent-join-token.yaml
```
