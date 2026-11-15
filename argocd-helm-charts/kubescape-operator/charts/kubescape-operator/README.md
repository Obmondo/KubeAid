# Kubescape Operator

![Version: 1.42.0](https://img.shields.io/badge/Version-1.42.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.42.0](https://img.shields.io/badge/AppVersion-1.42.0-informational?style=flat-square)

[Kubescape operator documentation](https://kubescape.io/docs/install-operator/)

## Install

> **Warning:** We only support installing this chart using Helm or ArgoCD.
Using alternative installation methods, such as Kustomize, Helmfile or using custom scripts, may lead to unexpected behavior and issues.
We cannot guarantee compatibility or provide support for deployments that are installed using methods other than Helm or ArgoCD.

When installing with ArgoCD or another GitOps controller that continuously re-renders Helm charts, set `certificates.strategy=initContainer` so the admission and storage certificates are generated and patched at runtime instead of during template rendering.

> **Migrating from `strategy: hook`:** The `hook` strategy was removed in favour of `initContainer`. Update your values from `certificates.strategy: hook` to `certificates.strategy: initContainer`.

Run the install command:

```
helm repo add kubescape https://kubescape.github.io/helm-charts/ ; helm repo update ; helm upgrade --install kubescape kubescape/kubescape-operator -n kubescape --create-namespace --set clusterName=`kubectl config current-context`
```

Verify that the installation was successful:

```shell
$ kubectl get pods -n kubescape
kubescape     kubescape-548d6b4577-qshb5                          1/1     Running   0               60m
kubescape     kubevuln-6779c9d74b-wfgqf                           1/1     Running   0               60m
kubescape     operator-5d745b5b84-ts7zq                           1/1     Running   0               60m
kubescape     storage-59567854fd-hg8n8                            1/1     Running   0               60m
```

## Live namespace filters

Set `namespaceFilters.enabled: true` to edit scanning and monitoring namespaces
through one ConfigMap without restarting components after each filter edit.
Leave `namespaceFilters.existingConfigMap` empty for chart-managed filters, or
reference a separately named ConfigMap in `ksNamespace` for external ownership.
See [configuration, recovery, and ownership migration](../../docs/features/live-namespace-filters.md).

## Offline daily reports

Setting `capabilities.kubescapeOffline: enable` forces
`KS_SKIP_UPDATE_CHECK="true"` on the Operator container, overriding entries with
that name in `operator.env`. This suppresses the Operator's daily report to
`version-check.ks-services.co`. Operator v0.2.181 includes
[kubescape/operator#421](https://github.com/kubescape/operator/pull/421);
the chart defaults to the newer compatible v0.2.188 release. If overriding the
image, use v0.2.181 or a later release containing that fix. Older images do not
honor this setting for daily reports.

Online installations retain their existing reporting behavior. To opt out
explicitly online, set `KS_SKIP_UPDATE_CHECK=true` through `operator.env`.
`kubescape.skipUpdateCheck` remains scoped to the Kubescape scanner.

See the [published-image validation](../../docs/features/operator-daily-reports-validation.md)
for a reproducible check of offline suppression and online reporting.

## MCP endpoint for AI agents

Set `storage.mcp.enabled: true` to let AI agents in the cluster (for example [Kagent](https://kagent.dev)) read Kubescape's results over [MCP](https://modelcontextprotocol.io). Storage serves read-only tools at

```
POST /apis/spdx.softwarecomposition.kubescape.io/v1beta1/namespaces/<namespace>/mcpservers/default/mcp
```

The call goes through kube-apiserver with the agent's own token, and storage checks every read against the agent's RBAC, so an agent sees only what it may `get` or `list`. The chart creates two ClusterRoles to bind per namespace:

- `kubescape-mcp-reader`: call the endpoint, read vulnerability manifests and configuration scans
- `kubescape-mcp-runtime-reader`: read container profiles and SBOMs (what containers run and every package in an image)

The tools depend on the storage version. The chart's default (v0.0.382) serves the vulnerability tools (`list_vulnerability_manifests`, `list_vulnerabilities_in_manifest` and `list_vulnerability_matches_for_cve`) and the SBOM tools (`list_sboms` and `list_sbom_packages`). The configuration-scan and container-profile tools come with later releases. The two roles already cover them, so the RoleBindings stay the same when storage is upgraded.

Image-level vulnerability manifests and SBOMs are stored in the Kubescape namespace, workload scans in the workload's namespace. For an agent with the ServiceAccount `kagent/agent`:

```
kubectl -n kagent create rolebinding kubescape-mcp --clusterrole=kubescape-mcp-reader --serviceaccount=kagent:agent
kubectl -n kubescape create rolebinding kubescape-mcp --clusterrole=kubescape-mcp-reader --serviceaccount=kagent:agent
```

## Network policies

> **Warning:** NetworkPolicies are now created by default (`global.networkPolicy.enabled: true`). They
only restrict **ingress** to the Kubescape pods, to the traffic between Kubescape's own components plus
kube-apiserver and Prometheus. Egress stays open unless `global.networkPolicy.createEgressRules` is set.
If a tool outside the chart calls a Kubescape pod directly, add your own NetworkPolicy for it or set
`global.networkPolicy.enabled=false`. See [Network policies](https://github.com/kubescape/helm-charts/blob/main/docs/features/network-policies.md)
for the exact rules and the opt-in egress rules.

## Upgrade

`helm upgrade` updates everything in the chart **except** the CRDs under `crds/`. Helm installs those
once, on first install, and [never touches them again](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/).
So when a release changes a CRD schema, the cluster keeps the old one: the API server rejects fields it
does not know about under a strict apply, and silently prunes them otherwise.

If a release notes a CRD change, apply the chart's CRDs yourself before upgrading:

```shell
helm repo update
helm pull kubescape/kubescape-operator --untar --untardir /tmp
kubectl apply --server-side --force-conflicts -f /tmp/kubescape-operator/crds/
```

Then run the usual `helm upgrade`. Applying the CRDs is safe to repeat and does not touch existing
custom resources.

> **`capabilities.riskAcceptance`:** the `SecurityException` and `ClusterSecurityException` schemas
grew per-vulnerability `expiresAt`, `actionStatement`, `response`, `subcomponents`, and the `affected`
status. Clusters that installed the chart before that change need the apply above, otherwise those
fields are pruned or rejected.

The CRDs under `templates/` (the node-agent sensing CRDs and `seccompprofiles`) are managed by Helm and
do upgrade on their own.

## View results

The scanning results will be available gradually as the scans are completed.

View your configuration scan reports:

```
kubectl get workloadconfigurationscans -A
```

View your image vulnerabilities:

```
kubectl get vulnerabilitymanifests -A
```

## Uninstall

You can uninstall this helm chart by running the following command:

```shell
helm uninstall kubescape -n kubescape
```

Then, delete the kubescape namespace:

```shell
kubectl delete ns kubescape
```

### Adjusting Resource Usage for Your Cluster

By default, Kubescape is configured for small- to medium-sized clusters.
If you have a larger cluster and you experience slowdowns or see Kubernetes evicting components, please revise the amount of resources allocated for the troubled component.

Taking Kubescape for example, we found that our defaults of 500 MiB of memory and 500m CPU work well for clusters up to 1250 total resources.
If you have more total resources or experience resource pressure already, first check out how many resources are in your cluster by running the following command:

```
kubectl get all -A --no-headers | wc -l
```

The command should print an approximate count of resources in your cluster.
Then, based on the number you see, allocate 100 MiB of memory for every 200 resources in your cluster over the count of 1250, but no less than 128 MiB total.
The formula for memory is as follows:

```
MemoryLimit := max(128, 0.4 * YOUR_AMOUNT_OF_RESOURCES)
```

For example, if your cluster has 500 resources, a sensible memory limit would be:

```
kubescape:
  resources:
    limits:
      memory: 200Mi  # max(128, 0.4 * 500) == 200
```

If your cluster has 50 resources, we still recommend allocating at least 128 MiB of memory.

Regarding CPU, the more you allocate, the faster Kubescape will scan your cluster.
This is especially true for clusters that have a large amount of resources.
However, we recommend that you give Kubescape no less than 500m CPU no matter the size of your cluster so it can scan a relatively large amount of resources fast ;)

## Chart support

### Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| namespaceFilters.enabled | bool | `false` | Reload namespace selection from one shared ConfigMap without restarting components after filter edits. |
| namespaceFilters.existingConfigMap | string | `""` | External ConfigMap in ksNamespace with namespaceFilters.json; empty creates the chart-managed kubescape-namespace-filters. See the live-filter ownership migration guide above. |
| excludeControls | list | `[]` | Control IDs or legacy CIS section numbers omitted from every operator-triggered posture scan. Request exclusions are added to this list. |
| defaultFrameworks | list | `[]` | Install-time posture frameworks when a scan omits `targetNames`. Empty = operator legacy fallbacks. Clear with `--set defaultFrameworks=null`. |
| capabilities.agentRuntimePosture | string | `"disable"` | Grant the Kubescape scanner read-only access to the supported Agent Runtime resources: Sandbox, SandboxTemplate, and WorkerPool. |
| capabilities.sandboxSeccomp | string | `"disable"` | Experimental. Enforce the syscall rules of SandboxPolicy `privilege` sections with seccomp. Profiles are injected through NRI (containerd >= 2.2 or CRI-O >= 1.34) and apply when a container starts. Requires the SandboxPolicy CRDs and a node-agent release that includes the seccomp layer; older images ignore it. |
| global.networkPolicy.enabled | bool | `true` | Create ingress NetworkPolicies for all components. **On by default**, see [Network policies](https://github.com/kubescape/helm-charts/blob/main/docs/features/network-policies.md) |
| global.networkPolicy.createEgressRules | bool | `false` | Also restrict egress (DNS, kube-apiserver, proxy and the destinations each component needs) |
| global.networkPolicy.apiServerIP | string | `""` | Pin the kube-apiserver egress rule to this IP |
| global.networkPolicy.apiServerPort | int | `443` | kube-apiserver port for the egress rules; the `default/kubernetes` endpoint ports are added when they can be looked up |
| global.kubescapePsp.enabled | bool | `false` | Enable all privileges in Pod Security Policies for Kubescape namespace |
| global.httpsProxy | string | `""` | Set https egress proxy for all components. Must supply also port.  |
| global.proxySecretFile | string | `""` | Set proxy certificate / RootCA file content (not the file path) for all components to be used for proxy configured in global.httpsProxy |
| global.overrideDefaultCaCertificates.enabled | bool | `false` | Use to enable custom CA Certificates |
| global.overrideDefaultCaCertificates.caCertificates | string | `""` | Set the custom CA Certificates file in all container |
| global.extraCaCertificates.enabled | bool | `false` | Use to enable mapping extra CA Certificate files |
| global.extraCaCertificates.secretName | bool | `""` | Name of the secret that contents will be mapped to `/etc/ssl/certs` in each workload |
| certificates.strategy | string | `"template"` | Certificate management mode for the admission webhook and storage mTLS endpoints. Use `template` for standard Helm installs and `initContainer` for ArgoCD/GitOps-safe runtime certificate generation. |
| operator.admissionService | object | `{}` | **DEPRECATED** — use `operator.admissionWebhooks.service.*` instead. If set, takes precedence over the new path for backward compatibility. Will be removed in a future release. |
| customScheduling.affinity | yaml |  | Use the `affinity` sub-section to define affinity rules that will apply to all of the workloads managed by the kubescape-operator |
| customScheduling.nodeSelector | yaml | | Configure `nodeSelector` rules under the nodeSelector sub-section that will apply to all of the workloads managed by the kubescape-operator |
| customScheduling.tolerations | yaml | | Define `tolerations` in the tolerations sub-section that will apply to all of the workloads managed by the kubescape-operator |
| global.overrideRuntimePath | string | `""` | Override the runtime path for node-agent |
| global.apiAuth.enabled | bool | `true` | Require a service-account token (TokenReview) and an RBAC grant (SubjectAccessReview) on the in-cluster HTTP APIs of kubescape, kubevuln, synchronizer and the operator. The chart installs the RBAC, projected tokens for the callers and the env the servers read; the pinned images enforce the check. Set to `false` to turn the check off. On GKE Autopilot clusters that set `nodeAgent.gke.allowlist.enabled=true` with an allowlist that lacks the node-agent's projected token mount (`nodeAgent.gke.allowlist.supportsApiToken=false`, the case for the pinned `armo-kubescape-node-agent-1.40-v2`), the chart turns the check off by itself: the node-agent is rendered without the token mount, so GKE Warden keeps admitting it, and the servers get `KS_API_AUTH_DISABLED=true` |
| nodeAgent.gke.allowlist.supportsApiToken | bool | `false` | Whether `nodeAgent.gke.allowlist.name` includes the node-agent's projected API token volume (allowlists from 1.43 on). Set to `true` together with a 1.43 `name` to keep `global.apiAuth` effective on GKE Autopilot |
| global.apiAuth.audience | string | `"kubescape.io"` | Audience of the projected service-account tokens the callers send and the servers accept |
| credentials.cloudSecret | string | `""` | Leave it blank for the default secret. If you have an existing secret, override with the existing secret name to avoid Helm creating a default one |
| kubescape.affinity | object | `{}` | Assign custom [affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) rules to the deployment |
| kubescape.podLabels| object | `{}` | Optional labels to add to the pods |
| kubescape.podAnnotations| object | `{}` | optional map of annotations to be applied to the Pods |
| kubescape.downloadArtifacts | bool | `true` | download policies every scan, we recommend it should remain true, you should change to 'false' when running in an air-gapped environment or when scanning with high frequency (when running with Prometheus). When 'false', the policy library baked into the image is used, so the controls are those of the image tag and do not change until the image does |
| kubescape.image.repository | string | `"quay.io/kubescape/kubescape"` | [source code](https://github.com/kubescape/kubescape/tree/master/httphandler) (public repo) |
| kubescape.nodeSelector | object | `{}` | [Node selector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) |
| kubescape.serviceMonitor.enabled | bool | `false` | enable/disable service monitor for prometheus (operator) integration |
| kubescape.skipUpdateCheck | bool | `false` | skip check for a newer version |
| kubescape.volumes | object | `[]` | Additional volumes for Kubescape |
| kubescape.volumeMounts | object | `[]` | Additional volumeMounts for Kubescape |
| kubescapeScheduler.podLabels| object | `{}` | Optional labels to add to the pods |
| kubescapeScheduler.podAnnotations| object | `{}` | optional map of annotations to be applied to the Pods |
| kubescapeScheduler.scanSchedule | string | `"0 0 * * *"` | scan schedule frequency. The scheduled scan CronJob is created when `capabilities.configurationScan` is `enable` |
| kubescapeScheduler.volumes | object | `[]` | Additional volumes for scan scheduler |
| kubescapeScheduler.volumeMounts | object | `[]` | Additional volumeMounts for scan scheduler |
| kubevuln.affinity | object | `{}` | Assign custom [affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) rules to the deployment |
| kubevuln.podLabels| object | `{}` | Optional labels to add to the pods |
| kubevuln.podAnnotations| object | `{}` | optional map of annotations to be applied to the Pods |
| kubevuln.image.repository | string | `"quay.io/kubescape/kubevuln"` | [source code](https://github.com/kubescape/kubevuln) |
| kubevuln.nodeSelector | object | `{}` | [Node selector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) |
| kubevuln.volumes | object | `[]` | Additional volumes for the image vulnerability scanning |
| kubevuln.volumeMounts | object | `[]` | Additional volumeMounts for the image vulnerability scanning |
| kubevuln.tmpDirPersistence.ephemeral | bool | `false` | With `tmpDirPersistence.enabled`, create the `/tmp` claim per pod as a [generic ephemeral volume](https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/#generic-ephemeral-volumes) instead of a standalone PVC: deleted with the pod, not counted against the ephemeral-storage limits |
| kubevuln.grypeDbEphemeral.enabled | bool | `false` | Put the Grype DB on a generic ephemeral volume (`storageClassName`, `accessModes`, `size` (default `10Gi`), `annotations`) instead of an emptyDir; takes precedence over `config.grypeDbPersistence` |
| kubevuln.config.grypeDbListingURL | string | `""` | Parameter to override the default Grype vulnerability database URL (listings.json format) |
| kubevuln.config.proxyRegistryMap | object | `{}` | Map of source registry address to mirror registry address. When set, kubevuln rewrites image pull references accordingly (useful for air-gapped or offline registry mirrors) |
| kubevuln.config.cveMatchingMode | string | `""` | CVE matching mode: "off" (Grype defaults), "on" (CPE matching everywhere), or "adaptive" (CPE matching everywhere except trusted-vendor images, which rely on the vendor's authoritative feed). Empty derives the mode from useDefaultMatchers for backward compatibility (true -> "off", false -> "adaptive"). |
| kubevuln.config.trustedVendors | list | `[]` | Distro identifiers treated as trusted vendors in adaptive mode. Empty uses kubevuln's built-in default set (echo, chainguard, wolfi, minimos). |
| kubevulnScheduler.podLabels| object | `{}` | Optional labels to add to the pods |
| kubevulnScheduler.podAnnotations| object | `{}` | optional map of annotations to be applied to the Pods |
| kubevulnScheduler.scanSchedule | string | `"0 0 * * *"` | scan schedule frequency. The scheduled scan CronJob is created when `capabilities.vulnerabilityScan` is `enable` |
| kubevulnScheduler.volumes | object | `[]` | Additional volumes for scan scheduler |
| kubevulnScheduler.volumeMounts | object | `[]` | Additional volumeMounts for scan scheduler |
| operator.affinity | object | `{}` | Assign custom [affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) rules to the deployment |
| operator.podLabels| object | `{}` | Optional labels to add to the pods |
| operator.podAnnotations| object | `{}` | optional map of annotations to be applied to the Pods |
| operator.image.repository | string | `"quay.io/kubescape/operator"` | [source code](https://github.com/kubescape/operator) |
| operator.nodeSelector | object | `{}` | [Node selector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) |
| operator.volumes | object | `[]` | Additional volumes for the web socket |
| operator.volumeMounts | object | `[]` | Additional volumeMounts for the web socket |
| storage.hostNetwork | bool | `false` | Bind the storage APIServer to the host network. Required when using a custom CNI where the control plane cannot reach pod IPs |
| storage.containerProfileSqliteBackend | bool | `false` | Serve ContainerProfiles from storage's SQLite-native backend (payload and metadata in one transaction). Requires `storage.singleWriterEnabled`. Every storage start migrates existing profiles before serving; run `storage.containerProfileMigrationDryRun` once first. See [the storage doc](https://github.com/kubescape/storage/blob/main/docs/features/containerprofile-sqlite-backend.md) |
| storage.containerProfileMigrationDryRun | bool | `false` | At storage start, log what the ContainerProfile migration to the SQLite backend would do, without writing anything. Cannot be combined with `storage.containerProfileSqliteBackend` |
| storage.containerProfileMigrationStartupProbe.periodSeconds | int | `10` | With `storage.containerProfileSqliteBackend` or `storage.containerProfileMigrationDryRun` on, storage runs the migration before it serves `/livez`. A startup probe gives it up to `periodSeconds` x `failureThreshold` seconds (10 minutes by default) before the liveness probe can restart it |
| storage.containerProfileMigrationStartupProbe.failureThreshold | int | `60` | See `storage.containerProfileMigrationStartupProbe.periodSeconds` |
| storage.mcp.enabled | bool | `false` | Serve the read-only [MCP endpoint for AI agents](#mcp-endpoint-for-ai-agents) |
| storage.mcp.readerClusterRoles | bool | `true` | With `storage.mcp.enabled`, create the `kubescape-mcp-reader` and `kubescape-mcp-runtime-reader` ClusterRoles |
| nodeAgent.autoscaler.bottlerocketAutoDetect | bool | `true` | When the autoscaler is enabled, auto-detect AWS Bottlerocket nodes and set `seLinuxType: super_t` on the node-agent DaemonSet rendered for that node group, so you don't need to `--set nodeAgent.seLinuxType=super_t` manually |
| nodeAgent.config.httpExporterConfig.tokenFile | string | `"/var/run/secrets/kubescape.io/api-token/token"` | Projected service-account token that node-agent and the operator send to the synchronizer HTTP endpoint (see `global.apiAuth`) |
| nodeAgent.gVisorStart.enabled | bool | `false` | Experimental start collection on prepared self-managed Linux nodes. Requires an image containing node-agent #1069. See [setup and validation](../../docs/features/gvisor-start-source.md). |
| nodeAgent.gVisorStart.socketDirectory | string | `/run/kubescape/gvisor` | Pre-created root-owned 0700 host directory. Mounted as `Directory`; the receiver uses `events.sock` inside it. |
| nodeAgent.gVisorStart.runtimeEndpoint | string | `""` | Absolute local CRI socket path, or empty to reuse node-agent's detected runtime endpoint and existing mounts. |
| nodeAgent.gVisorStart.runtimeHandler | string | `runsc` | Expected CRI runtime handler. |
| nodeAgent.config.hostSensor.enabled | bool | `true` | Defines `KS_ENABLE_HOST_SCANNER` in kubescape to enable [host scanner feature](https://kubescape.io/docs/components/host-sensor/)
| nodeAgent.config.tracers.capSys | string | `enable` | Allow capSys tracing when required by enabled node-agent features. Set to disable to force-disable the capSys tracer |
| nodeAgent.config.tracers.dns | string | `enable` | Allow dns tracing when required by enabled node-agent features. Set to disable to force-disable the dns tracer |
| nodeAgent.config.tracers.exec | string | `enable` | Allow exec tracing when required by enabled node-agent features. Set to disable to force-disable the exec tracer |
| nodeAgent.config.tracers.exit | string | `enable` | Allow exit tracing when required by enabled node-agent features. Set to disable to force-disable the exit tracer |
| nodeAgent.config.tracers.fork | string | `enable` | Allow fork tracing when required by enabled node-agent features. Set to disable to force-disable the fork tracer |
| nodeAgent.config.tracers.hardlink | string | `enable` | Allow hardlink tracing when required by enabled node-agent features. Set to disable to force-disable the hardlink tracer |
| nodeAgent.config.tracers.http | string | `enable` | Allow HTTP tracing when required by enabled node-agent features. Set to disable to force-disable the HTTP tracer |
| nodeAgent.config.tracers.iouring | string | `enable` | Allow io_uring tracing when required by enabled node-agent features. Set to disable to force-disable the io_uring tracer |
| nodeAgent.config.tracers.network | string | `enable` | Allow network tracing when required by enabled node-agent features. Set to disable to force-disable the network tracer |
| nodeAgent.config.tracers.open | string | `enable` | Allow file-open tracing when required by enabled node-agent features. Set to disable to force-disable the file-open tracer |
| nodeAgent.config.tracers.ptrace | string | `enable` | Allow ptrace tracing when required by enabled node-agent features. Set to disable to force-disable the ptrace tracer |
| nodeAgent.config.tracers.randomx | string | `enable` | Allow RandomX tracing when required by enabled node-agent features. Set to disable to force-disable the RandomX tracer |
| nodeAgent.config.tracers.seccomp | string | `enable` | Allow seccomp tracing when required by enabled node-agent features. Set to disable to force-disable the seccomp tracer |
| nodeAgent.config.tracers.ssh | string | `enable` | Allow SSH tracing when required by enabled node-agent features. Set to disable to force-disable the SSH tracer |
| nodeAgent.config.tracers.symlink | string | `enable` | Allow symlink tracing when required by enabled node-agent features. Set to disable to force-disable the symlink tracer |
| nodeAgent.config.tracers.kmod | string | `enable` | Allow kernel module tracing when required by enabled node-agent features. Set to disable to force-disable the kernel module tracer |
| nodeAgent.config.tracers.unshare | string | `enable` | Allow unshare tracing when required by enabled node-agent features. Set to disable to force-disable the unshare tracer |
| nodeAgent.config.tracers.bpf | string | `enable` | Allow BPF tracing when required by enabled node-agent features. Set to disable to force-disable the BPF tracer |
| nodeAgent.config.tracers.top | string | `enable` | Allow top tracing when required by enabled node-agent features. Set to disable to force-disable the top tracer |
| prometheusExporter.serviceMonitor.enabled | bool | `false` | enable/disable service monitor for prometheus-exporter integration |
| awsIamRoleArn | string | `nil` | AWS IAM arn role |
| cloudProviderMetadata.secretRef.name | string | `nil` | secret name to define values for the provider's metadata |
| cloudProviderMetadata.cloudRegion | string or through `cloudProviderMetadata.secretRef.cloudRegionKey` if `cloudProviderMetadata.secretRef.name` is set | `nil` | cloud region |
| cloudProviderMetadata.gkeProject | string or through `cloudProviderMetadata.secretRef.gkeProjectKey` if `cloudProviderMetadata.secretRef.name` is set | `nil` | GKE project |
| cloudProviderMetadata.gkeServiceAccount | string | `nil` | GKE service account |
| cloudProviderMetadata.aksSubscriptionID | string or through `cloudProviderMetadata.secretRef.subscriptionIdKey` if `cloudProviderMetadata.secretRef.name` is set | `nil` | AKS subscription ID |
| cloudProviderMetadata.aksResourceGroup | string or through `cloudProviderMetadata.secretRef.resourceGroupKey` if `cloudProviderMetadata.secretRef.name` is set | `nil` | AKS resource group |
| cloudProviderMetadata.aksClientID | string or through `cloudProviderMetadata.secretRef.clientIdKey` if `cloudProviderMetadata.secretRef.name` is set | `nil` | AKS client ID |
| cloudProviderMetadata.aksClientSecret | string or through `cloudProviderMetadata.secretRef.clientSecretKey` if `cloudProviderMetadata.secretRef.name` is set | `nil` | AKS client secret |
| cloudProviderMetadata.aksTenantID | string or through `cloudProviderMetadata.secretRef.tenantIdKey` if `cloudProviderMetadata.secretRef.name` is set | `nil` | AKS tenant ID |
| cloudProviderMetadata.aksWorkloadIdentityClientID | string | `nil` | Azure Workload Identity client ID federated with the kubevuln ServiceAccount, used to pull images from private Azure Container Registries without static credentials. Annotates the kubevuln ServiceAccount with `azure.workload.identity/client-id` and labels the kubevuln pod with `azure.workload.identity/use: "true"`. Requires the Azure Workload Identity webhook and `kubevuln.image.tag` v0.3.545 or later (the first kubevuln release with kubevuln#1163). Ignored when `cloudProviderMetadata.awsIamRoleArn` or `cloudProviderMetadata.gkeServiceAccount` is set, since those take precedence on the kubevuln ServiceAccount. Configured inline; not affected by `cloudProviderMetadata.secretRef` |
| cloudProviderMetadata.aksWorkloadIdentityTenantID | string | `nil` | Azure Workload Identity tenant ID (optional). Annotates the kubevuln ServiceAccount with `azure.workload.identity/tenant-id`. Configured inline; not affected by `cloudProviderMetadata.secretRef` |
| volumes | object | `[]` | Additional volumes for all containers |
| volumeMounts | object | `[]` | Additional volumeMounts for all containers |
| imageScanning.privateRegistries.credentials | object | `[]` | Credentials for scanning images pulled from private container registries. This configuration is not needed when using `imagePullSecrets`|
| imageScanning.privateRegistries.credentials.registry | string | `nil` | URL of the private container registry.|
| imageScanning.privateRegistries.credentials.username | string | `nil` | Username/Client ID for authentication.|
| imageScanning.privateRegistries.credentials.password | string | `nil` | Password/Token/Client Secret for authentication.|
| imageScanning.privateRegistries.credentials.skipTlsVerify | bool | `false` | Skip TLS certificate verification |
| imageScanning.privateRegistries.credentials.insecure | bool | `false` | Use HTTP instead of HTTPS |
| configurations.priorityClass.enabled | bool | `true` | Add priority class to the installed components |
| configurations.priorityClass.daemonset | int | 100000100 | PriorityClass of the DaemonSet, this should be higher than the other components so the DaemonSet will schedule on all nodes |

# In-cluster components overview

An overview of each in-cluster component which is part of the Kubescape platform helm chart.
Follow the repository link for in-depth information on a specific component.

---

## High-level Architecture Diagram

```mermaid
graph TB

  client([client]) .-> dashboard
  masterSync .- sync
  sync --- store

  subgraph Cluster
    agent@{shape: procs, label: "Node Agent"}
    sync(Synchronizer)
    operator(Operator)
    k8sApi(Kubernetes API);
    kubevuln(Kubevuln)
    ks(Kubescape)
    store(Storage)
    store --- agent
    store --- operator
    operator -->|scan cluster| ks
    operator -->|scan images| kubevuln
    operator --- k8sApi
    ks --> k8sApi
  end;

subgraph Backend
    er(CloudEndpoint)
    dashboard(Dashboard) --> bus(Event Bus) --> masterSync("Master Synchronizer")
    ks --> er
    kubevuln --> er
  end;

  classDef k8s fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
  classDef plain fill:#ddd,stroke:#fff,stroke-width:1px,color:#000;
  class k8sApi k8s
  class agent,ks,operator,sync,masterSync,kollector,kubevuln,er,dashboard,store,bus plain
```

---

## [Synchronizer](https://github.com/kubescape/synchronizer)

* **Resource Kind:** `Deployment`
* **Communication:** gRPC, REST API, Websocket
* **Responsibility:** This component is an optional part of the Kubescape Operator. It enables users to replicate the Kubernetes objects in the cluster (somewhat like `rsync`) to a remote service. It is used for collecting the Kubescape Operator objects by central services monitoring multiple clusters.

In our architecture, the Synchronizer acts both as a server and a client, depending on its running configuration:

* Master Synchronizer: Refers to the instance running in the backend.
* In-cluster Synchronizer: Refers to the instance running in the cluster.
  Registered to the Master Synchronizer using a websocket; Synchronizes Kubernetes objects and virtual objects,
  this enables executing actions in runtime.

A Master Synchronizer communicates with multiple in-cluster Synchronizers.

```mermaid
graph TB
  subgraph Backend
    dashboard(Dashboard)
    event(Event Bus)
    masterSync("Synchronizer (Master)")
  end
   subgraph Cluster N
    sync3("Synchronizer (In-cluster)")
    store3(Storage)
  end;
  subgraph Cluster 2
    sync2("Synchronizer (In-cluster)")
    store2(Storage)
  end;
  subgraph Cluster 1
    sync1("Synchronizer (In-cluster)")
    store1(Storage)
  end;

  dashboard --> event --> masterSync
  masterSync .- sync1
  masterSync .- sync2
  masterSync .- sync3
  sync1 --- store1
  sync2 --- store2
  sync3 --- store3


  classDef k8s fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
  classDef plain fill:#ddd,stroke:#fff,stroke-width:1px,color:#000;
  class k8sApi k8s
  class event,ks,store1,dashboard,store2,store3 plain
```

---

## [Storage](https://github.com/kubescape/storage)

* **Resource Kind:** `Deployment` (singleton)
* **Communication:** gRPC, REST API
* **Responsibility:** This component is a Kubernetes [aggregated API extension](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/) service. It stores the different objects produced by the other components and stores them on a volume as files and SQLite. It is a singleton component in the current implementation and cannot be scaled horizontaly, but it is running in 10k node clusters.

```mermaid
graph TD


subgraph Cluster
  agent@{shape: procs, label: "Node Agent"}
  k8sApi(Kubernetes API)
  etcd(ETCD)
  file(Files)
  sqlite(SQLite)
  store(Storage)
  sync(Synchronizer)
end;

  agent .->|Store results| k8sApi --- store <--> file
  store <--> sqlite
  k8sApi <--> etcd
  sync .->|Synchronize| k8sApi
  kubectl .- k8sApi
  k9s .- k8sApi
  Lens .- k8sApi
  Headlamp .- k8sApi

classDef k8s fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
classDef plain fill:#ddd,stroke:#fff,stroke-width:1px,color:#000;
class k8sApi k8s
class agent,kubectl,Lens,Headlamp,sync,etcd,file,k9s,sqlite plain
```

---

## [Operator](https://github.com/kubescape/operator)

* **Resource Kind:** `Deployment`
* **Communication:** gRPC, REST API
* **Responsibility:** This component is in charge of command and control of the scans in the cluster. There are multiple configuration options when and what to scan in the cluster. This component is in charge of orchestrating these activities by triggering the *Kubescape* and the *KubeVuln* components.

```mermaid
graph TB
  subgraph Cluster
    store(Storage)
    sync(Synchronizer)
    operator(Operator)
    k8sApi(Kubernetes API);
    kubevuln(Kubevuln)
    ks(Kubescape)
    urlCm{{ConfigMap<br>URLs }}
    recurringTempCm{{ConfigMap<br>Recur. Scan Template }}
    recurringScanCj{{CronJob<br>Recurring Scan }}
  end;
    masterSync(Master Synchronizer) .- sync --- store
    store ---> operator
    recurringScanCj ---> operator
    operator -->|scan cluster| ks
    operator -->|scan images| kubevuln
    operator --> k8sApi
    operator --- urlCm
    operator --- recurringTempCm

  classDef k8s fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
  classDef plain fill:#ddd,stroke:#fff,stroke-width:1px,color:#000;
  class k8sApi k8s
  class ks,store,masterSync,kollector,urlCm,recurringScanCj,recurringTempCm,kubevuln,er,dashboard,sync plain
```

---

## [Kubevuln](https://github.com/kubescape/kubevuln/)

* **Resource Kind:** `Deployment`
* **Communication:** gRPC, REST API
* **Responsibility:** This component is in charge of the image vulnerability scanning. It can either produce SBOM object in the *Storage* and match the SBOM entries with vulnerabilities, or relies on the *Node agent* to generate SBOM objects on the nodes and then produce vulnerability manfiests and VEX. All the results are stored in the *Storage* component via the Kubernetes API and optionally sent to external API endpoints.

```mermaid
graph TB

subgraph Cluster
    kubevuln(Kubevuln)
    k8sApi(Kubernetes API)
    operator(Operator)
    store(Storage)
    sync(Synchronizer)
    urlCm{{ConfigMap<br>URLs }}
    recurringScanCj{{CronJob<br>Recurring Scan }}
    recurringScanCm{{ConfigMap<br>Recurring Scan }}
    recurringTempCm{{ConfigMap<br>Recurring Scan Template }}

end

masterSync .- sync
sync .- store .-|Scan Notification| operator
operator -->|Collect NS, Images|k8sApi
operator -->|Start Scan| kubevuln
operator --- urlCm
urlCm --- kubevuln
recurringTempCm --- operator
recurringScanCj -->|Scan Notification| operator
recurringScanCm --- recurringScanCj

subgraph Backend
    er(CloudEndpoint)
    masterSync("Master Synchronizer")
    kubevuln -->|Scan Results| er
end;

classDef k8s fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
classDef plain fill:#ddd,stroke:#fff,stroke-width:1px,color:#000

class k8sApi k8s
class urlCm,recurringScanCm,operator,er,sync,masterSync,recurringScanCj,recurringTempCm,store plain


```

---

## [Kubescape](https://github.com/kubescape/kubescape/tree/master/httphandler)

* **Resource Kind:** `Deployment`
* **Communication:** gRPC, REST API
* **Responsibility:** This component is in charge of configuration and host scanning. It is, like the CLI, uses [OPA engine](https://github.com/open-policy-agent/opa) to run the project's own Rego library of rules. It also scans the Kubernetes host to validate their configurations. The output of the scans are stored in the *Storage* component via the Kubernetes API and optionally sent to external API endpoints.

```mermaid
graph TB

subgraph Cluster
    ks(Kubescape)
    k8sApi(Kubernetes API)
    operator(Operator)
    store(Storage)
    sync(Synchronizer)
    ksCm{{ConfigMap<br>Kubescape }}
    recurringScanCj{{CronJob<br>Recurring Scan }}
    recurringScanCm{{ConfigMap<br>Recurring Scan }}
    recurringTempCm{{ConfigMap<br>Recurring Scan Template }}
end

masterSync .- sync
sync .- store .-|Scan Notification| operator
operator -->|Start Scan| ks
ks-->|Collect Cluster Info|k8sApi
ksCm --- ks
recurringTempCm --- operator
recurringScanCj -->|Scan Notification| operator
recurringScanCm --- recurringScanCj
subgraph Backend
    er(CloudEndpoint)
    masterSync("Master Synchronizer")
    ks -->|Scan Results| er
end;

classDef k8s fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
classDef plain fill:#ddd,stroke:#fff,stroke-width:1px,color:#000

class k8sApi k8s
class ksCm,recurringScanCm,operator,er,store,masterSync,recurringScanCj,recurringTempCm,sync plain


```

---

## [Node Agent](https://github.com/kubescape/node-agent)

* **Resource Kind:** `Daemonset`
* **Communication:** gRPC, REST API
* **Responsibility:** This component has multiple purposes all bound to information available on Kubernetes nodes:
  * Produces SBOMs from the images avialable on the node (used by *KubeVuln*)
  * Produces information from the configurations of the Linux host of the Kubernetes node (used by *Kubescape*)
  * Creates *ApplicationProfile* using [Inspektor Gadget](https://inspektor-gadget.io) and eBPF. These profiles log the behavior of each container on the node (file access, processes launched, capabilities used, system calls done) into *ApplicationProfile* objects stored in the *Storage* component via the Kubernetes API and optionally sent to external API endpoints.
  * Creates *NetworkNeighborhood* objects using [Inspektor Gadget](https://inspektor-gadget.io) and eBPF. These profiles log the network activity of each container and they stored as objects in the *Storage* component via the Kubernetes API and optionally sent to external API endpoints.
  * Monitors container activity via eBPF and evaluates them using its own rule engine that combines static detection rules and anomaly detection to produce alerts that can be exported to AlertManager, Syslog, HTTP endpoints, STDOUT stream and other.

```mermaid
graph TD
subgraph Cluster
  k8sApi(Kubernetes API)
  subgraph Node1
    container11 .- linux1
    container12 .- linux1
    linux1(Linux Kernel) ---|eBPF| node1(Node Agent)
  end
  subgraph Node2
    container21 .- linux2
    container22 .- linux2
    linux2(Linux Kernel) ---|eBPF| node2(Node Agent)
  end
  subgraph Node3
    container31 .- linux3
    container32 .- linux3
    linux3(Linux Kernel) ---|eBPF| node3(Node Agent)
    store(Storage)
  end
end;

node1 --> k8sApi
node2 --> k8sApi
node3 --> k8sApi
k8sApi --> store

classDef k8s fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
classDef plain fill:#ddd,stroke:#fff,stroke-width:1px,color:#000;
class k8sApi k8s
class container11,container12,container21,container22,container31,container32,linux1,linux2,linux3,store plain
```

---

## Kubernetes API

Some in-cluster components communicate with the Kubernetes API server for different purposes:

* Operator

  Creates/updates/deletes resources for recurring scan purposes (CronJobs, ConfigMaps). Collects required information (NS, image names/tags) for Kubevuln's image scanning.

* Kubescape

  Collects namespaces, workloads, RBAC etc. required for cluster scans.

---

## Backend components

The backend components are running in [Kubescape's SaaS offering](https://cloud.armosec.io/).

### Dashboard

* REST API service

### CloudEndpoint

* **Responsibility:** Receive and process Kubescape & Kubevuln scan results.
* **Communication:** REST API

---

## Logging and troubleshooting

Each component writes logs to the standard output.

Every action has a generated `jobId` which is written to the log.

An action which creates sub-action(s), will be created with a different `jobId` but with a `parentId` which will correlate to the parent action's `jobId`.

### Distroless images

Each component is built as a distroless image. This means that the image does not contain any shell or package manager. This is done for security reasons.

In order to troubleshoot a component, you can use the `kubectl debug` command to add an [ephemeral container](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container) to the pod and run a shell in it:

```bash
kubectl -n kubescape debug -it <pod-name> --image=docker.io/busybox --target=<container-name>
```

**Note:** The `--target` parameter must be supported by the Container Runtime.
When not supported, the Ephemeral Container may not be started, or it may be started with an isolated process namespace so that `ps` does not reveal processes in other containers.

Use `kubectl delete` to remove the Pod when you're finished (there is no other way to remove the ephemeral container):

```bash
kubectl -n kubescape delete pod <pod-name>
```

---

## Recurring scans

3 types of recurring scans are supported:

  1. Cluster configuration scanning (Kubescape)
  2. Vulnerability scanning for container images (Kubevuln)
  3. Container registry scanning (Kubevuln)

When creating a recurring scan, the Operator component will create a `ConfigMap` and a `CronJob` from a recurring template ConfigMap. Each scan type comes with a template.

The CronJob itself does not run the scan directly. When a CronJob is ready to run, it will send a REST API request to the Operator component, which will then trigger the relevant scan.

The scan results are then sent by each relevant component to the CloudEndpoint.

---

## Common Issues

* Error starting the container watcher - `(fanotify)`.

  This error is usually caused by the `node-agent` not being able to find `runc` in any of the default paths.
  This can be fixed by adding the path of `runc` to the global configuration [here](#values).
  If you aren't sure where `runc` is located, you can run the following command on the node to find it:

  ```bash
  find / -name runc 2>/dev/null
  ```

  In case you are in an environment where you can't access the node, one solution is to run a privileged pod on the node, and run the command from there. To create a privileged pod, run the following command:

  ```bash
   kubectl run --rm -i --tty busybox --image=busybox --restart=Never --overrides='{"spec": {"template": {"spec": {"containers": [{"securityContext": {"privileged": true} }]}}}}' -- /bin/sh
  ```

  For K3s, the `runc` binary is different from the system one, and is located in `/var/lib/rancher/k3s/data/current/bin/runc`. Given this path, the option to set during the Helm installation is (note the `/host` prefix):

  ```bash
  --set global.overrideRuntimePath="/host/var/lib/rancher/k3s/data/current/bin/runc"
  ```

### Excluding controls from automatic scans

```yaml
excludeControls:
  - C-0069
  - C-0070
```

This installation setting applies to explicit, scheduled, and continuous
operator-triggered scans. Individual `scanV1` requests can add exclusions; an
empty request list does not clear the installation list. Controls are omitted
before evaluation and compliance scoring, using the CLI's `--exclude-controls`
behavior. Exclusions narrow the assessment scope; they do not make checks pass.
The default empty list changes nothing. Non-list, non-string, and blank values
are rejected. The chart defaults select operator `v0.2.209` and Kubescape scanner
`v4.0.20`, which include support for this setting. Keep a compatible pair if
overriding the image versions.

### Azure Workload Identity for ambient ACR authentication

To configure Kubevuln to scan private Azure Container Registries (ACR) using Azure Workload Identity without static credentials (`imagePullSecrets`):

1. **Enable Azure Workload Identity on AKS**: Ensure the Azure Workload Identity mutating webhook and OIDC issuer are enabled on your AKS cluster.
2. **Federate the ServiceAccount**: Establish federated identity credentials linking your Azure Managed Identity (or App Registration) with the `kubevuln` ServiceAccount in the release namespace (e.g. `system:serviceaccount:kubescape:kubevuln`). Ensure the identity has the `AcrPull` role on the target ACR.
3. **Compatible Kubevuln image prerequisite**: Ambient ACR authentication requires the ACR provider introduced in [kubescape/kubevuln#1163](https://github.com/kubescape/kubevuln/pull/1163). The chart defaults to `kubevuln.image.tag: v0.3.578`, which includes ambient ACR authentication.

#### Example `values.yaml`

```yaml
clusterName: my-aks-cluster

cloudProviderMetadata:
  aksWorkloadIdentityClientID: "11111111-2222-3333-4444-555555555555"
  aksWorkloadIdentityTenantID: "66666666-7777-8888-9999-000000000000" # optional

kubevuln:
  image:
    tag: v0.3.566 # any release from v0.3.545 on has the ACR provider
```

Or via Helm CLI:

```bash
helm upgrade --install kubescape kubescape/kubescape-operator \
  -n kubescape --create-namespace \
  --set clusterName=my-aks-cluster \
  --set cloudProviderMetadata.aksWorkloadIdentityClientID="11111111-2222-3333-4444-555555555555" \
  --set cloudProviderMetadata.aksWorkloadIdentityTenantID="66666666-7777-8888-9999-000000000000" \
  --set kubevuln.image.tag=v0.3.566
```

> **Note:**
> - `aksWorkloadIdentityClientID` and `aksWorkloadIdentityTenantID` are configured inline and are not read from `cloudProviderMetadata.secretRef`.
> - If updating an existing installation to enable Workload Identity, restart the Kubevuln pod (`kubectl rollout restart deployment/kubevuln -n kubescape`) to allow the Azure Workload Identity webhook to inject the federated token and environment variables.
