# CCM AWS

Wrapper chart for the upstream [`aws-cloud-controller-manager`](https://github.com/kubernetes/cloud-provider-aws)
chart (pinned to `0.0.12`, image tag `v1.30.0` in this wrapper's `values.yaml`), the AWS cloud-controller-manager
that initialises node metadata (providerID, InternalIP, region/zone labels) and reconciles `LoadBalancer` Services
against ELB/NLB.

## Why it's in KubeAid

Rendered for **self-managed (CAPI) AWS clusters** — `AWSSpecificNonSecretTemplateNames` in `kubeaid-cli`, alongside
Cluster Autoscaler and the external snapshotter. **EKS** clusters skip it: the EKS control plane runs the cloud
controller itself, so `AWSEKSSpecificNonSecretTemplateNames` drops `ccm-aws` and adds
[`aws-ebs-csi-driver`](../aws-ebs-csi-driver) instead (EKS installs no storage driver by default).

## Key values / KubeAid-specific configuration

Upstream values live under the `aws-cloud-controller-manager:` key.

- `hostNetworking: true` — required for CCM to reach the EC2 instance-metadata endpoint
  (`169.254.169.254`) reliably across control-plane restarts during a Kubernetes version upgrade; without it CCM
  intermittently fails with `EC2RoleRequestError: no EC2 instance role found` even though the metadata endpoint is
  reachable from the node itself (`values-ccm-aws.yaml.tmpl`, `kubeaid-cli`).
- `namespace: kube-system`, `args` set `--cloud-provider=aws`, `--use-service-account-credentials=true`,
  `--configure-cloud-routes=false` (pod-network routing is Cilium's job, not CCM's).
- RBAC is left to the upstream defaults. Since chart `0.0.12` the controller credentials
  (`serviceaccounts/token` creation for `node-controller`, `service-controller`, etc.) come from a `kube-system`
  Role, and the chart refuses any `clusterRoleRules` that grant token creation
  ([kubernetes/cloud-provider-aws#1485](https://github.com/kubernetes/cloud-provider-aws/pull/1485)). Don't add
  that rule back in an override.

## Docs links

- Upstream project: <https://github.com/kubernetes/cloud-provider-aws>
- Upstream Helm repo: <https://kubernetes.github.io/cloud-provider-aws>
- [KubeAid: Helm umbrella pattern](../../docs/kubeaid/helm-umbrella-pattern.md)
