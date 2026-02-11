# Traefik - a loadbalancer

## Traefik dashboard

you can access it by doing ```kubectl -n traefik port-forward <podname> 9000:9000```
  and opening http://localhost:9000/dashboard/ in your browser

## Setup for Internal use

* We setup an internal service which will have an internal loadbalance IP

### AWS

```yaml
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
```

### AKS

```yaml
service:
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

## Public

* We setup an internal service which will have an internet-facing loadbalance IP.
  you will have to add these service annotation in your yaml file

### AWS Public

```yaml
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

### AKS Public

```yaml
service:
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "false"
    service.beta.kubernetes.io/azure-load-balancer-resource-group: <your-resource-group-name>
```

### TLS Auth

* [Doc](https://doc.traefik.io/traefik/https/tls/#client-authentication-mtls)
* NOTE: Make sure the key is either ca.crt or tls.ca

```sh
kubectl create secret generic internalca-cert --namespace traefik --dry-run=client --from-file=/path/to/ca.crt -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller -o yaml
```

* Add this in the values file

```yaml
tlsOptions:
  tls-client-auth:
    clientAuth:
      clientAuthType: VerifyClientCertIfGiven
      secretNames:
        - internalca-cert
```

## Troubleshooting

- Traefik has a default limit on Request Body that can affect file uploads. To re-configure it
using a middleware, [see this example.](./examples/request-body-middleware.yaml)

- If you want to run multiple traefik instances, ensure that each traefik deployment has the additional argument
which binds it to a specific ingress class `--providers.kubernetesingress.ingressclass=<ingress-class>`.
This ensures that multiple instances of Traefik don't try to update ingress resources at the same time leading
to the hostname of the ingress switching from one ingress class to another. 
## Upgrading Traefik

While upgrading to Traefik Helm chart v25.0.0 and Traefik v2.10.5, the Traefik deployment needs
to be deleted, or else ArgoCD throws a Sync error like this:

```text
Deployment.apps "traefik" is invalid: spec.selector: Invalid value: 
v1.LabelSelector{MatchLabels:map[string]string{"app.kubernetes.io/instance":"traefik-traefik",
"app.kubernetes.io/name":"traefik"}, MatchExpressions:[]v1.LabelSelectorRequirement(nil)}: 
field is immutable
```

This happens due to new label selectors in the new version of the Traefik Helm chart
and hence a rolling upgrade is not possible.
[Link to Upstream k8s issue](https://github.com/kubernetes/client-go/issues/508)

The procedure for the upgrade is:

* **[Pre-Requisite]** Use `kubectl port forward` to _argocd-server_ pod and open the UI on localhost.
This is recommended as Traefik will go down and ArgoCD's Ingress will not be able to handle requests.
* **[Pre-Requisite]** If you don't have access to port forward the argocd service, then use `helm template`
command to keep a copy of the _Deployment_ and _Service_ YAML of Traefik.
* Refresh the **Traefik** ArgoCD app on the cluster
* Verify the diff once the ArgoCD app is in _OutOfSync_ state
* Click on _Sync_ in the ArgoCD app, and select all the CRD (Custom Resource Definition) resources
which are _OutOfSync_.
* Click on _Sync_ in the ArgoCD app, and select all the resources which are _OutOfSync_ except
the **Deployment**, **Service**, and **Service Account**.
* Once the sync is completed successfully, there will be only the Traefik Deployment, Service and
Service Account will be shown as _OutOfSync_.
* Sync the _Service_ and _Service Account_.
* Delete the Traefik deployment from ArgoCD or using _kubectl_ cli.
* Once the pods are deleted successfully, sync the Traefik Deployment from ArgoCD.
* If you did not create a port forward to argocd, the ArgoCD UI will stop responding
as the Traefik Ingress will not be able to respond to the requests due to the Traefik
pod being deleted. Use `kubectl apply -f traefik-deployment.yaml` to create the
deployment from the **[Step 2]** above.
* Traefik pods should come up with the latest version.
