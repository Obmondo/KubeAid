# Proposal: cleaning up orphaned PVCs/PVs when an ArgoCD application is deleted

## Problem

When an ArgoCD Application is deleted (the `resources-finalizer.argocd.argoproj.io`
finalizer that KubeAid's Application templates set), ArgoCD deletes the resources it tracks:
everything that appears in the rendered Helm manifests. PVCs created at runtime are not part of
those manifests, so they survive the deletion. Therefore:

- PVCs born from a StatefulSet's `volumeClaimTemplates` (created by the StatefulSet controller,
  carrying no ArgoCD tracking label and no owner reference) are still there lingering in the namespace.
- PVCs created by operators on behalf of their CRs (CloudNativePG, the redis and MariaDB
  operators, and similar), unless the operator implements its own cleanup are also lingering in the ns.

In a way, this is deliberate upstream behavior: volumes outlive their workloads by default so that scale-downs, rollbacks and accidental deletions never destroy data. But when we are deleting the argocd app itself , then we clearly dont want the persistence of data.

The PV layer is a second, separate stage: a PV is only reclaimed after its PVC is deleted, and
only if the StorageClass has `reclaimPolicy: Delete` (which is what we have). The orphan problem lives at the PVC layer.

### Why leftover PVCs/PVs matter

- **Storage cost** Every orphaned Bound PVC keeps its PV and the backing volume allocated. Orphans accumulate silently every time an app is removed or moved between clusters.
- **Stale data hazards.** The data keeps existing with no owner. For log stores and databases
  that is retained personal data, which matters for GDPR-style retention commitments.
- **Broken reinstalls.** StatefulSet PVC names are deterministic. A later reinstall silently
  adopts the old PVCs: which may cause confusion.
- **Operational noise.** Alerts come up and oncall engineer becomes sad.

## Solutions

### Option A: ArgoCD PostDelete hook

ArgoCD v2.10+ supports `PostDelete` resource hooks: a Job annotated with
`argocd.argoproj.io/hook: PostDelete` runs after ArgoCD has deleted the app's resources, and
can sweep up anything left behind by label.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-pvcs
  annotations:
    argocd.argoproj.io/hook: PostDelete
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      serviceAccountName: pvc-cleanup   # needs RBAC to delete PVCs in the namespace
      restartPolicy: Never
      containers:
        - name: kubectl
          image: bitnami/kubectl
          command:
            - kubectl
            - delete
            - pvc
            - -l
            - app.kubernetes.io/instance={{ .Release.Name }}
```

The ServiceAccount, Role and RoleBinding the Job uses must also be annotated as PostDelete
hooks so they exist while the Job runs.

**How to add it in KubeAid:** implement once as a small shared template, enabled per app from values with an explicit label selector. Turn it on only for apps whose data is rebuildable (log stores, caches) - we can ignore the most crucial apps if that is the mechanism we want.

**Why recommended:** the trigger matches the intent exactly. Cleanup runs only when the Application is cascade-deleted, which is precisely the "we are removing this app". StatefulSet churn, rolling updates and delete-and-recreate on immutable field changes never trigger it. It is also chart-agnostic: deleting by label catches both volumeClaimTemplate PVCs and operator-created PVCs, so it works uniformly across all wrapper charts regardless of what the upstream chart exposes.

**Limitations:**

- More moving parts: Job plus ServiceAccount plus RBAC, all hook-annotated.
- Only fires on a *cascade* delete. What is not a cascade deleted (which is what we need, so technically not a limitation):
    
    - argocd app delete <app> --cascade=false - ArgoCD strips the finalizer first, then deletes only the Application object. All workloads, PVCs included, keep running unmanaged. No hooks.
    - Manually removing the finalizer from the Application, then deleting it - same effect.
    - A hypothetical Application that never had the finalizer - which is not the case for us/ kubectl delete on it removes only the Application object.

- The label selector is a blunt instrument. It must be explicit and correct per app; a
  too-broad selector deletes volumes that belong to something else in the namespace.
- Requires ArgoCD v2.10 or newer.

### Option B: native StatefulSet `persistentVolumeClaimRetentionPolicy`

Kubernetes has a native mechanism (beta and enabled by default since v1.27, GA in v1.32):

```yaml
spec:
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Delete   # delete PVCs when the StatefulSet is deleted
    whenScaled: Retain    # keep PVCs on scale-down (safe default)
```

With `whenDeleted: Delete` the StatefulSet controller stamps owner references onto its PVCs,
so deleting the StatefulSet garbage-collects them, and a `reclaimPolicy: Delete` StorageClass
then removes the PVs and backing volumes. The whole chain is automatic with zero extra
infrastructure.

**How to add it:** set it through the upstream chart's values where exposed. Many modern
charts expose it (the loki chart in this repository exposes it per component as
`<component>.persistence.enableStatefulSetAutoDeletePVC` plus `whenDeleted`/`whenScaled`).

**Limitations:**

- Fires on *any* StatefulSet deletion, not just app removal. That includes Helm or ArgoCD
  deleting and recreating a StatefulSet because an immutable field changed, which then
  silently destroys the volumes. This makes it unsuitable for databases.
- Only covers StatefulSet volumeClaimTemplates. Operator-created PVCs are out of reach.
- Depends on chart support. Where the upstream chart does not expose the knob, it needs a
  wrapper-chart patch or a post-renderer.

Note that pod-level events (OOMKills, evictions, manual pod deletion, node reboots) never trigger it; only deletion of the StatefulSet object itself and scale-down do.

### Option C: Kyverno cleanup policy as a reporting net

Kyverno's cleanup controller supports scheduled cleanup policies that can match PVCs unmounted or unowned for some grace period, cluster-wide, regardless of how they were orphaned.

**How to add it:** best used report-first: run the match logic in audit mode, or as a Prometheus alert on PVCs with no consuming pod for N days, and only enable actual deletion for namespaces where data is known to be rebuildable.

**Limitations:** blanket auto-deletion of "unused" PVCs is dangerous; a database briefly
scaled to zero looks identical to an orphan.

### Not a fix: StorageClass `reclaimPolicy`

`reclaimPolicy` only decides what happens to the PV *after* its PVC is deleted. It does not
delete PVCs, so it cannot solve this on its own; with `Retain` it would orphan PVs on top of
PVCs. Keep it on `Delete` so that PVC cleanup cascades to the PV and the backing volume.
