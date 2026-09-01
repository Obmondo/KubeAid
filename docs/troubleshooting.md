# Troubleshooting

Platform-level problems on a running KubeAid cluster, in symptom → cause → fix form.

> **Bootstrap or provisioning failing?** Failures during `kubeaid-cli cluster bootstrap` (Hetzner capacity errors,
> immutable machine templates, stuck control planes, NAT gateway issues, and more) are covered in the
> [kubeaid-cli troubleshooting guide](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/troubleshooting.md) -
> start there, not here. Bootstrap logs live in `~/.config/kubeaid-cli/<cluster>/logs/` (one timestamped file per run).

## ArgoCD application OutOfSync or stuck syncing

**Symptom:** An Application stays `OutOfSync`, or repeated syncs never converge.

**Cause:** Manual changes on the cluster (drift), immutable or defaulted fields that differ from the manifest,
resources modified by controllers, stale repo-server cache, or an annotation exceeding the Kubernetes size limit.

**Fix:**

- Inspect what actually differs: `argocd app diff <app-name>`, and use `ignoreDifferences` for known discrepancies.
  See [GitOps Drift Detection](./kubeaid/gitops-drift-detection.md#troubleshooting).
- Sync only the out-of-sync resources (**Selective Sync**) instead of the whole app, and use prune only when the
  change actually removed resources. See the
  [service window guide](./operations/argocd-apps-service-window.md).
- If the sync fails because the annotation size exceeds the Kubernetes limit, use **"Apply (server-side)"** from the
  ArgoCD UI.
- If ArgoCD reports `Manifest generation error (cached)`, force a fresh comparison:

  ```bash
  kubectl annotate app <name> argocd.argoproj.io/refresh=hard --overwrite
  ```

  See the kubeaid-cli troubleshooting guide's
  [ArgoCD section](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/troubleshooting.md#argocd).

## Sealed secrets fail to decrypt after cluster recreation

**Symptom:** SealedSecrets that worked before no longer produce Secrets; the controller logs decryption errors.

**Cause:** A recreated cluster gets a new sealed-secrets controller keypair, so secrets sealed against the old
cluster's public key can no longer be decrypted. (Also note: the namespace is bound at seal time - a SealedSecret
moved to a different namespace will never decrypt.)

**Fix:** Restore the old cluster's sealing keys from backup, as described in the
[sealed-secrets README](../argocd-helm-charts/sealed-secrets/README.md#how-to-backup-and-restore-sealed-secrets):

```bash
# On the old cluster (or from an existing backup): back up the active sealing keys
kubectl get secrets -n system -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o yaml > backup_key.yml

# On the new cluster: restore them
kubectl apply -f backup_key.yml
```

The README also documents an automated backup path via Velero. If no key backup exists, re-seal each secret from its
original plaintext against the new cluster.

## Kubeconfig not found

**Symptom:** `kubectl` cannot find a kubeconfig, or connects to the wrong cluster.

**Cause:** Wrong path, the cluster was never created, or the cluster is VPN-type (where the generic kubeconfig flow
doesn't apply).

**Fix:** The kubeconfig is written into the cluster's directory under the per-user config root — the exact
`export KUBECONFIG=...` line is printed at the end of `cluster bootstrap`. On Linux:

```bash
export KUBECONFIG=~/.config/kubeaid-cli/<cluster>/kubeconfigs/main.yaml
kubectl cluster-info
```

(On macOS the per-user root is `~/Library/Application Support/kubeaid-cli/` instead, and a local K3D
cluster's kubeconfig is `kubeconfigs/management/host.yaml`.)

For **VPN-type clusters** (`cluster.type: vpn`), the public kube-apiserver load balancer is disabled after bootstrap
and API access moves to the NetBird mesh - follow the
[post-bootstrap operator guide](https://github.com/Obmondo/kubeaid-cli/blob/main/docs/post-bootstrap.md) instead.

## kube-prometheus build errors

**Symptom:** `./build/kube-prometheus/build.sh` fails with Jsonnet dependency errors.

**Cause:** A stale or corrupted local cache of the Jsonnet libraries for that kube-prometheus version.

**Fix:** Remove the cached libraries and rebuild, per
[Prometheus Configuration](./kubeaid/prometheus-configuration.md#troubleshooting):

```bash
rm -rf ./build/kube-prometheus/libraries/<version>/
./build/kube-prometheus/build.sh ../kubeaid-config/k8s/<cluster-name>
```

## Chart update conflicts on your KubeAid mirror

**Symptom:** Pulling upstream KubeAid updates into your mirror produces merge conflicts in `argocd-helm-charts/`.

**Cause:** Local commits were made on the master/main branch of the mirror. That branch is used to deliver upstream
updates, so any local change there will eventually collide with them.

**Fix:** Never commit to your mirror's master/main branch - all customization belongs in your kubeaid-config
repository as value overrides (see the
[Helm Umbrella Pattern](./kubeaid/helm-umbrella-pattern.md#customizing-an-application)). Move any local changes into
kubeaid-config, resolve the mirror back to upstream's state, and resume pulling updates as described in
[Post-Configuration, Step 6](./getting-started/post-configuration.md#step-6-configure-updates).

## Node disk full or degraded

**Symptom:** A node reports disk pressure, or a bare-metal node has a failing/corrupted disk (e.g. a degraded
zpool).

**Cause:** Workloads or logs filling the disk, or physical disk failure.

**Fix:** For a faulty disk, follow the [node disk repair procedure](./operations/fixing-a-k8s-node-disk.md): cordon
and drain the node, check etcd health (and Rook Ceph, if it runs on the node) before taking it down, have the disk
replaced, then rejoin and verify. For orphaned PersistentVolumeClaims silently consuming storage, enable the
`orphan-pvc` mixin described in [Monitoring](./monitoring.md#orphan-pvc-detection).
