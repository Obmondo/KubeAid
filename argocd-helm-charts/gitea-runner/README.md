# Gitea Runner

* There are some custom changes, have asked the author if he will accept the [patch](https://gitea.com/vquie/act_runner-helm/issues/2)

* The fix is [here](https://gitlab.enableit.dk/kubernetes/k8id/-/merge_requests/940)

* Create the runner token

```sh
kubectl create secret generic gitea-runner-token --namespace gitea --dry-run=client --from-literal=act-runner-token='lolmyrunnertoken' -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller -o yaml
```

## Increase parallel jobs execution

```yaml
act-runner:
  act_runner:
    parallel_jobs: 5
```

* Doc is [here](https://gitea.com/gitea/act_runner)

## Create kube config secret

```bash
#!/bin/bash

set -euo pipefail

CLUSTERNAME=$1
SERVICEACCOUNT=$2
NAMESPACE=$3
CONFIG="/tmp/$CLUSTERNAME.config"

kubectl get secret $(kubectl get serviceaccount $SERVICEACCOUNT -n $NAMESPACE -o json | jq -r '.secrets[0].name' ) -n $NAMESPACE -o  json | jq -r '.data["ca.crt"]' | base64 --decode > /tmp/k8s-$CLUSTERNAME.ca.crt

kubectl config --kubeconfig $CONFIG set-cluster $CLUSTERNAME --embed-certs=true --server="https://kubernetes.default.svc" --certificate-authority=/tmp/k8s-$CLUSTERNAME.ca.crt

kubectl config --kubeconfig $CONFIG set-credentials $SERVICEACCOUNT --token=$(kubectl get secret $(kubectl get serviceaccount $SERVICEACCOUNT -n $NAMESPACE -o json | jq -r '.secrets[0].name') -n $NAMESPACE -o json | jq -r '.data.token'  | base64 --decode)

kubectl config --kubeconfig $CONFIG set-context $CLUSTERNAME --cluster=$CLUSTERNAME --user=$SERVICEACCOUNT

kubectl config --kubeconfig $CONFIG use-context $CLUSTERNAME

cat $CONFIG | base64 --wrap=0

```
