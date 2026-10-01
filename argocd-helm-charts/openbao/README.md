# OpenBao

OpenBao with 3 replicas and integrated (Raft) storage, auto-unsealed with a
static key. Mounts, policies and Kubernetes auth roles are applied from values.
Backups are Raft snapshots to S3. Requires OpenBao 2.6.0 or later.

## High availability

Each replica holds a full copy of the data on its own volume. One replica is the
leader; clients connect through the `openbao-active` Service, which points at
it. A write is committed once 2 of 3 replicas have persisted it, so the cluster
survives the loss of one replica. A PodDisruptionBudget keeps a drain from
taking out a majority, and data volumes are retained when the StatefulSet is
deleted or scaled down. A replica that comes back with an empty volume joins the
existing cluster and copies everything from the leader.

The web UI is served through the `openbao-ui` Service (ClusterIP), which targets
only the leader. Expose it per cluster or use `kubectl port-forward`.

## Unsealing

Every value OpenBao stores, including in snapshots, is encrypted. A replica
starts sealed and unseals itself with the static key, so a restart needs no
operator.

The key is 32 random bytes in the Secret `openbao-unseal` (deliver it as a
sealed-secret), one file per key named `unseal-<key id>.key`. `staticSeal`
in values selects the key:

```yaml
openbao:
  staticSeal:
    currentKeyId: "1"
    previousKeyId: ""
```

- Keep an offline copy of the key outside the cluster. Without it, no snapshot
  can be restored.
- Anyone holding the key plus a volume or a snapshot can read every secret.
- A key id always refers to exactly one key. Never reuse an id.

### Rotating the static key

1. Generate a new key (`openssl rand -out unseal-<new id>.key 32`) with a new id
   and add it to the sealed-secret next to the old one.
2. Set `currentKeyId` to the new id and `previousKeyId` to the old one.
3. Delete the replica pods one at a time, followers first and the leader last.
   The StatefulSet uses `OnDelete`, so a config change reaches a pod only when
   the pod is deleted. The pod that becomes leader re-wraps the stored keys with
   the new key. Followers log `post-unseal upgrade seal keys failed` with
   `node is not the leader`, which is expected.
4. Once the snapshot retention period has passed, clear `previousKeyId`, remove
   the old key file and roll the pods again. Snapshots taken before the rotation
   need the old key to restore.

The re-wrap needs the recovery key that self-initialization creates. Rotating
the static key does not rotate the data encryption keys (`bao operator rotate`).

## Setup

### Self-initialization

Self-initialization runs the `initialize` blocks in `selfInit.config` once, with
a root token that is revoked afterwards, when a new cluster is created. The
blocks go only to replica 0, and only when every other replica answers that it
is not initialized. If any replica answers that it is, replica 0 joins it; while
any replica does not answer, replica 0 waits. The other replicas never get the
blocks and can only join, so no replica can create a second cluster. The
replicas start together (`podManagementPolicy: Parallel`) so that replica 0 can
ask them. Self-initialization:

- creates the recovery key, needed for static key rotation
- enables the Kubernetes auth method; OpenBao reviews client tokens with its own
  service account, which the chart binds to `system:auth-delegator`
- creates the `openbao-config` admin policy and role used by the config Job

It never runs again, so anything that may change belongs in `config`. If a
request fails on the first start, the server refuses to start until its volume
is wiped, so test changes to these blocks on a throwaway cluster. Do not run the
first start with `trace` logging, which logs the recovery key share. If
`openbao.server.extraArgs` is overridden, keep `$(sh /openbao/self-init/select.sh)`
in it; the chart refuses to render otherwise.

While replica 0 waits, it keeps asking until every other replica answers, so
a bootstrap blocked by a Pending replica (e.g. fewer schedulable nodes than
replicas) continues on its own once that replica runs. Replica 0 only needs a
restart (delete the `openbao-0` pod) if it already decided to join and the
cluster it would join has gone, or if the replica count changed while it waited. If the cluster came up but the config Job keeps failing with 403
on login, self-initialization was interrupted before it created the
`openbao-config` role (`bao status` shows 0 recovery shares); on a new cluster,
delete the StatefulSet and its PVCs and sync again.

### Config

The top-level `config` values hold secret mounts, ACL policies and Kubernetes
auth roles. A Job applies them after every sync (ArgoCD PostSync hook), and an
hourly CronJob re-applies them to undo drift. With `prune: true`, everything of
these kinds that is not listed is deleted: ACL policies, Kubernetes auth roles,
roles of the auth methods in `config.authMethods`, and identity groups
(including ones created by hand). Mounts and auth methods are only ever
created. Roles are replaced on every run, so a field removed from values is
removed in OpenBao too. Names must be lowercase (OpenBao lowercases policy
names) and are validated when rendering.

Install one release per namespace and do not set `fullnameOverride` or
`nameOverride` (the chart refuses to render with them). When overriding
`openbao.server.volumes` or `volumeMounts`, keep the chart's `openbao-unseal` and
`openbao-self-init` entries: Helm replaces lists, and the chart refuses to
render without them.
The Job, the CronJob, their pods and service account are configured under
`config.job`, `config.driftCorrection`, `config.pod` and `config.serviceAccount`.
The service account name and the `openbao-config` token audience are fixed:
self-initialization binds the `openbao-config` role to them on first start.

Each role binds service accounts, namespaces and an audience. Clients log in
with a projected service account token whose audience matches the role.

`config.authMethods` adds auth methods besides Kubernetes, such as OIDC for
people: each is enabled if missing, then its config and roles are written, and
with `prune` roles no longer listed are deleted. Secret config values (e.g. an
OIDC client secret) are read from files via `configFiles`, mounted from a Secret
with `config.pod.extraVolumes` and `extraVolumeMounts`.

`config.identityGroups` maps groups from an auth method to policies: each entry
is an external identity group with an alias on an auth method, so everyone
whose login carries that group name (e.g. a Keycloak group in the OIDC `groups`
claim) gets its policies. One OIDC role can then serve everyone, and nobody has
to pick a role at login.

The `openbao-config` role is a full admin (`path "*"` with every capability,
including `sudo`), so chart versions that need new kinds of configuration work
on existing clusters without re-bootstrapping. Who can merge to the values, and
who has RBAC on the namespace (to run as the `openbao-config` service account),
decides who controls OpenBao.

## Backup

Enable `snapshotAgent` per cluster with the S3 endpoint, bucket and credentials
Secret. The CronJob logs in with the `snapshot` role, takes an online snapshot
from the leader and uploads it to S3. After each upload it deletes snapshots
older than `s3ExpireDays`, so its S3 credentials need delete as well as write.
The bucket must live outside the cluster.

- A snapshot is atomic and point-in-time, and holds everything: secrets,
  policies, auth config and tokens.
- Volume-level backups (Velero, CSI snapshots) are not valid backups: each
  volume is captured separately while Raft is writing. Exclude these volumes
  from Velero.

## Restore

A restore replaces the entire cluster state with the snapshot and blocks
requests until it finishes. Run it as a maintenance window.

1. Make sure every replica runs with the static key that was current when the
   snapshot was taken, as the current or previous key, and roll the pods if
   that changed. `-force` skips this check: the restore succeeds, but a replica
   restarted afterwards stays sealed with `unknown key id` until the snapshot's
   key is added as the previous key.
2. From a pod running as the `openbao-restore` service account (the chart binds
   the `restore` role to it but does not create it), with a
   projected token for audience `openbao-restore`, log in with the `restore`
   role and run `bao operator raft snapshot restore <file>`. This works on the
   same cluster and on a freshly initialized one.
3. Tokens issued after the snapshot are gone; clients log in again. Tokens that
   existed at snapshot time come back if not expired, even if revoked since.
   Policies and roles revert to the snapshot; sync the app, or wait for the
   drift CronJob, to re-apply the ones in values.
4. Verify the data, then reconcile anything the clients changed after the
   snapshot.
