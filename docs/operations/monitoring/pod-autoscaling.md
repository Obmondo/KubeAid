# Pod Autoscaling Guide

**NOTE: Do not combine Kubernetes HPA + Prom Adapter (described in this guide) with Keda Project's autoscaling for the
same deployment. They will compete with each other and break things.**

**NOTE2: This assumes your cluster is setup with KubeAid because it provides sane defaults, although its possible to setup
this on non KubeAid clusters too.**

## Introduction & Situation

- Your application (running on K8s via a `Deployment` of pods) exposes metrics on an http endpoint.
- There is a `Service` for that deployment.
- There is a `ServiceMonitor` (K8s resource) for that service that tells Prometheus that it needs to scrape metrics
  from that service. Most likely it will add `pod="pod-name"` and `namespace="namespace-name"` labels to the metrics
  it fetches from individual pods.

## Setup Prerequisites

_This needs to be done only once._

- Set `enable_custom_metrics_apiservice: true` in your kubeaid managed cluster's prometheus build jsonnet vars file
  `(kubeaid-config/k8s/<clustername>/<clustername>-vars.jsonnet)`.
- Ensure `kube_prometheus_version` is newer than `v0.12.0`.

Regenerate kube prometheus YAML with
`kubeaid/build/kube-prometheus/build.sh /path/to/kubernetes-config-company/k8s/production.company.io/production.company.io-vars.jsonnet`

This will generate a few YAML files which define (setup or re-configure) prometheus, grafana, alertmanager,
prometheus-adapter, and other resources and configs needed by them.

We are using Prometheus adapter to provide the `custom.metrics.k8s.io` API.

Commit the changes to your cluster config repo and sync.

You should now see `custom.metrics.k8s.io` as running in the output of `kubectl api-versions`.

## Autoscaling HPA based on CPU/Memory and Custom Metrics

HorizontalPodAutoscaler automatically updates the replica count of a Deployment, with the aim of automatically scaling
the workload to match demand.

You can follow two methods here, depending on what you want to do. Method B is longer and is a superset of Method A.

- Method A: if your custom metric has the pod="pod-name" and namespace="namespace-name" label when you check it
  inside Prometheus.
- Method B: if you want to scale based on some result derived by performing a PromQL query on multiple custom
  metrics or if you have other advanced usecases.

In addition to scaling based on custom metrics you can scale based on CPU/Memory too in both methods.

### Method A

You do not need to set Prometheus Adapter rules yourself as the default rules in kubeaid already expose your custom
metrics to K8s as long as they have the `pod="pod-name"` and `namespace="namespace-name"` labels.

You can list all metrics available to K8s with `kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | jq`.

Lets say you have a metric
`autoscaleexp_custom_metric{pod="...", namespace="..."}` in the `autoscaleexp` namespace.

Check if it's working correctly with
`kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/autoscaleexp/pods/*/autoscaleexp_custom_metric | jq`.
You will see one item for each replica and each item will have the current value of the metric for that pod.

If it works, configure your HPA:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: intensive-app
spec:
  maxReplicas: 5
  minReplicas: 2
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: intensive-app
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 50
    scaleUp:
      policies:
        - type: Percent
          value: 50
          periodSeconds: 15
      selectPolicy: Max
      stabilizationWindowSeconds: 0
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 30
          type: Utilization
    - type: Pods
      pods:
        metric:
          name: autoscaleexp_custom_metric
        target:
          type: AverageValue
          averageValue: 80
```

### Method B

If you want to scale based on some result derived by performing a PromQL query on multiple custom metrics or
for any other advanced scenario, you need to add a Prometheus Adapter rule.

This needs be done in your cluster's jsonnet vars file. More info about this in the **Setup Prerequisites** section.

Lets say you want a new metric called `busy_optimizers_pct` which is the result of combining two metrics
called `optimization_requests_inprogress` and `optimization_tests_inprogress` which are exposed by pods in
the `modeling` namespace.

First check if `optimization_requests_inprogress` and `optimization_tests_inprogress` are accessible.

Example for `optimization_requests_inprogress`:

```shell
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/modeling/pods/*/optimization_requests_inprogress | jq
```

You will see one item for each replica and each item will have the current value of
`optimization_requests_inprogress` for that pod.

Write the rule in jsonnet, generate YAML and sync.

```jsonnet
  prometheus_adapter_additional_rules: [
    {
      seriesQuery: 'optimization_tests_inprogress',
      name: {
        as: 'busy_optimizers_pct',
      },
      resources: {
        overrides: {
          pod: {
            resource: 'pod',
          },
          namespace: {
            resource: 'namespace',
          },
        },
      },
      metricsQuery: '(sum(optimization_tests_inprogress{<<.LabelMatchers>>}) by (pod, namespace) + sum(optimization_requests_inprogress{<<.LabelMatchers>>}) by (pod, namespace)) * 100',
    },
  ],
```

Some notes for writing prometheus adapter rules:

- [Docs](https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config.md)
- We have to define resource overrides to associate a metric with a K8s resource.
  Left side is the label name (that label should be present in the original metrics) and right side is
  the kind of the k8s resource that label represents.
- `name > as` is the new name of a metric in the custom metrics API and it's value is the result of `metricsQuery`.

Wait for a minute and then check if the new metric `busy_optimizers_pct` is available via the API.

```shell
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/modeling/pods/*/busy_optimizers_pct | jq
```

Like before, you will see one item for each replica and each item will have the current value
of `busy_optimizers_pct` for that pod.

Configure the HPA.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: optimizer-v5
spec:
  maxReplicas: 5
  minReplicas: 2
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: optimizer-v5
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 50
    scaleUp:
      policies:
        - type: Percent
          value: 50
          periodSeconds: 15
      selectPolicy: Max
      stabilizationWindowSeconds: 0
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 50
          type: Utilization
    - type: Pods
      pods:
        metric:
          name: busy_optimizers_pct
        target:
          type: AverageValue
          averageValue: 90
```

## Algorithm Behavior

- If you're using Pod metrics (used in the examples in this guide) and not Object metrics then each pod in the
  deployment will probably have a different value of the custom metric. The controller will take the mean of the
  raw value of that metric across all pods and compare that against the target value set by you to determine the
  desired replica count.
- If you have multiple items in `HPA's Spec > metrics` for example one item for CPU, one for memory and another
  for a custom metric and each returns a different desired replica count then the maximum of those will be chosen.
- You can configure Stabilization window and Scaling policies to change how much time to wait before scaling and
  how fast should it scale.

## Reference Links

- [https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/walkthrough.md](https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/walkthrough.md)
- [https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config.md](https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config.md)
- [https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config-walkthrough.md](https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config-walkthrough.md)
