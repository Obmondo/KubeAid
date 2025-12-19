# Obmondo K8s Agent

This agent runs inside the Kubernetes cluster and pulls the metrics about the cluster from the Prometheus API.
These metrics are then forwarded to our Obmondo API.

## Adding K8s Agent to your cluster

The agent depends upon :

- a TLS secret certificate `obmondo-clientcert` which can be found in most of
our customer clusters under monitoring namespace.
- a docker config secret for pulling the docker image from our gitlab repo

To create the TLS secret :

```sh
# connect to the k8s cluster you want to deploy agent on
# get the tls.crt and tls.key from the existing secret into a local file

$ kubectl get secret obmondo-clientcert -n monitoring --template="{{index .data \"tls.crt\" | base64decode}}" > tls.crt
$ kubectl get secret obmondo-clientcert -n monitoring --template="{{index .data \"tls.key\" | base64decode}}" > tls.key

# verify the issuer using openssl
$ openssl x509 -in tls.crt -noout -text

# create the new secret and seal it using kubeseal
$ kubectl create secret tls k8s-agent-tls -n obmondo --dry-run=client --key="tls.key" --cert="tls.crt" -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller > k8s-agent-tls.yaml
```

To create the docker secret :

```sh
# create a access token in obmondo-k8s-agent gitlab repo
# with read_registry permission, or ask Ashish to provide the token

# connect to the K8s cluster you want to deploy agent on
$ kubectl create secret --namespace obmondo --dry-run=client docker-registry <secret-name> --docker-server=registry.obmondo.com --docker-username="oauth" --docker-password="<access-token>" -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller -o yaml > my-registry-access-token.yaml
```

Create an application file for ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: obmondo-k8s-agent
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: obmondo
  project: default
  source:
    path: argocd-helm-charts/obmondo-k8s-agent
    repoURL: https://gitlab.enableit.dk/kubernetes/kubeaid.git
    targetRevision: HEAD
    helm:
      valueFiles:
      - values.yaml
      - /path/to/override/values.yaml
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
```

Override the default access token of Helm chart by specifying it in the values file for ArgoCD

```yaml
imagePullSecrets:
  - name: 'my-registry-access-token'
```
