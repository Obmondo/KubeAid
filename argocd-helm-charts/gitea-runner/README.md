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
