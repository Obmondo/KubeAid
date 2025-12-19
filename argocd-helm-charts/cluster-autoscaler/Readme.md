# Cluster Autoscaler

The helm chart deploys cluster autoscaler to dynamically scale up or scale down
your nodes using your cloud provider.
It works by using Node Groups (not a K8s resource) and adding more resources as required.

## AWS

In AWS, cluster autoscaler uses EC2 Autoscaling groups to manage the node groups. It runs as a Deployment in
your cluster. It needs permissions to examine and modify the EC2 Autoscaling groups and it is recommended to
use an [IAM role with a service account](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).

Also, there are annotations/tags that must be present on your nodes, for cluster autoscaler
to automatically discover the new nodes.

### Considerations

The cluster-autoscaler semantic version (Major and Minor) should match with Kubernetes version.
Compatibility is not verified for older versions of K8s with latest releases of cluster-autoscaler.

If you're running multiple ASGs (Auto Scaling Groups), the `--expander` flag supports three options:
`random`, `most-pods` and `least-waste`.

- `random` will expand a random ASG on scale up.
- `most-pods` will scale up the ASG that will schedule the most amount of pods.
- `least-waste` will expand the ASG that will waste the least amount of CPU/MEM resources.

In the event of a tie, cluster autoscaler will fall back to `random`.

## Create SealedSecret for cluster-autoscaler using literals

```sh
kubectl create secret generic cluster-autoscaler-azure-cluster-autoscaler -n  cluster-autoscaler \
--dry-run=client \
 --from-literal=SubscriptionID="jwdmkwd73eke38kjwkkwd" \
 --from-literal=TenantID="klwdmkk79j99i9"  \
 --from-literal=ClientID="keki9ieeennkjimdkwm" \
 --from-literal=ClientSecret="ddkwwkwkdkdmkwmww" \
 --from-literal=ResourceGroup="k8s-prod-az1" \
 --from-literal=NodeResourceGroup="MC_k8s-prod-az1_prod_az1_obmondo_eu_northeurope" \
 --from-literal=VMType="vmss" \
 --from-literal=ClusterName="obmondo" \
 -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller > cluster-autoscaler.yaml
```

Where, the literals from cloud to cloud differs. And NOTE that this is only valid for Azure cloud.

## Create Token

Generating a azure token with role as contributor, scope as a subscription id for lifelong.

```sh
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<subscription-id>" --years 4000 --output json
```

### Troubleshooting

1) [Troubleshooting docs](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#troubleshooting)

2) [Scale down issues](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#i-have-a-couple-of-nodes-with-low-utilization-but-they-are-not-scaled-down-why)

    cluster-autoscaler doesn't remove underutilized nodes if they are running pods that
    it shouldn't evict. Other possible reasons for not scaling down:

    - the node group already has the minimum size
    - node has the scale-down disabled annotation
    - node was unneeded for less than 10 minutes (configurable by `--scale-down-unneeded-time` flag)
    - there was a scale-up in the last 10 min (configurable by `--scale-down-delay-after-add` flag)
    - there was a failed scale-down for this group in the last 3 minutes
    (configurable by `--scale-down-delay-after-failure` flag)
    - there was a failed attempt to remove this particular node, in which case cluster-autoscaler
    will wait for extra 5 minutes before considering it for removal again
    - using large custom value for `--scale-down-delay-after-delete` or `--scan-interval`, which delays autoscaling action.
    - make sure `--scale-down-enabled` parameter in command is not set to false

3) [Scale up issues](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#i-have-a-couple-of-pending-pods-but-there-was-no-scale-up)

    CA doesn't add nodes to the cluster if it wouldn't make a pod schedulable.
    It will only consider adding nodes to node groups for which it was configured.
    So one of the reasons it doesn't scale up the cluster may be that the pod has too large
    (e.g. 100 CPUs), or too specific requests (like node selector), and wouldn't fit on any
    of the available node types. Another possible reason is that all suitable node groups
    are already at their maximum size.

4) [Peeking under the Hood of cluster-autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#how-can-i-check-what-is-going-on-in-ca-)

    - Check logs on the control plane (previously referred to as master) nodes, in `/var/log/cluster-autoscaler.log`.
    - Cluster Autoscaler 0.5 and later publishes kube-system/cluster-autoscaler-status config map.
    To see it, run `kubectl get configmap cluster-autoscaler-status -n aws -o yaml`.
    - Events:
      - on pods (particularly those that cannot be scheduled, or on underutilized nodes),
      - on nodes,
      - on kube-system/cluster-autoscaler-status config map.

### References

- https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md
- https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html
- https://aws.github.io/aws-eks-best-practices/scalability/docs/
