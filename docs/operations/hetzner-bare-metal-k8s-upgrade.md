# Upgrade Kubernetes on Hetzner Bare Metal

On Hetzner bare metal a Kubernetes upgrade reinstalls every server, and each server's storage is offline while
that happens. Prepare Ceph and ZFS LocalPV before each server goes. Otherwise a reinstall can lose data or stop
I/O across the cluster.

## What gets reinstalled

- **Control plane:** Cluster API replaces the control-plane servers one at a time, on every Kubernetes upgrade
  and on any KubeAid change to the `KubeadmControlPlane`. With no spare server it deletes the old Machine first
  and then installs the same server again, which often takes 30 to 60 minutes. Meanwhile the control plane runs
  on the remaining servers.
- **Workers:** each bare-metal worker is a standalone Machine named `<cluster>-<node-group>-<server-id>`. The
  upgrade changes its `version` field but never replaces the server, so you reinstall the workers yourself
  (see [Workers](#workers)). A kubelet may run up to three minor versions behind the API server; reinstall the
  workers before they get that far behind.

A reinstall affects a server's storage like this:

| On the server | After its reinstall |
| --- | --- |
| Ceph OSDs on the data disks (not listed in the host's `wwns`) | Come back, unless `bareMetal.wipeDisks: true` |
| Ceph OSDs on the OS disks (the host's `wwns`, usually device class `nvme`) | Usually come back, but not always: the install repartitions these disks |
| ZFS LocalPV volumes (the ZFS pool sits on the OS disks) | Lost |

When only three servers carry data disks, Ceph keeps all its copies on those three. Each reinstall then leaves
every placement group one copy short, and a second failure during the upgrade stops I/O. Nodes with RBD volumes
mounted can then hang until they are force-rebooted. Reinstall one server at a time and let Ceph recover in
between.

## Before the upgrade

1. Ceph is `HEALTH_OK` and every placement group is `active+clean` (`ceph status`).
2. Stop Ceph from marking a reinstalling server's OSDs out and rebalancing: `ceph osd set noout`.
3. Note which OSDs each server holds, and which of them are on its OS disks: `ceph osd tree`.
4. Count the hosts in each device class (`ceph osd tree`) and compare with the pool `size`
   (`ceph osd pool ls detail`). With a host failure domain and only `size` hosts in a class, Ceph has nowhere to
   put a copy elsewhere, so `ceph osd safe-to-destroy` never reports the OSDs safe. Each reinstall then runs that
   class one copy short until the OSDs are back; see [Storage steps](#storage-steps).
5. Stop the balancer, so it does not add backfill on top of the recovery: `ceph balancer off`.
6. Raise Rook's mon failover timeout. A reinstall takes longer than the default 10 minutes, and Rook then
   replaces the mon, possibly on a worker:

   ```bash
   kubectl -n rook-ceph patch cephcluster rook-ceph --type merge \
     -p '{"spec":{"healthCheck":{"daemonHealth":{"mon":{"timeout":"90m"}}}}}'
   ```

7. List the CloudNativePG primaries and instances on each server:
   `kubectl get pods -A -l cnpg.io/instanceRole=primary -o wide`. Their PodDisruptionBudgets block the drain:
   - several instances: switch the primary to an instance on another server before the server goes
     (`kubectl cnpg promote`, or patch `status.targetPrimary`).
   - one instance: set `spec.nodeMaintenanceWindow` (`inProgress: true`, `reusePVC: true`) on the cluster.
   - every instance of a cluster on the same server's ZFS LocalPV: its data is lost with the reinstall. Move or
     back up the cluster first.
8. If both CephFS MDS daemons run on the same server (`ceph fs status`), delete the standby's pod before that
   server goes, so it starts elsewhere and the active one fails over to a warm standby.
9. If you reach the API through a proxy that runs in the cluster, check that its replicas are not all on one
   server: draining that server cuts your `kubectl` access halfway.
10. Hold every control-plane Machine, so Cluster API waits for you before it drains one:

    ```bash
    kubectl -n capi-cluster annotate machine <machine> \
      pre-drain.delete.hook.machine.cluster.x-k8s.io/storage-gate=<your-name>
    ```

11. The control-plane MachineHealthCheck (`<cluster>-control-plane-unhealthy-5m`) gives a new Machine 3600
    seconds, counted from its creation, to bring up a Ready node. A slow deprovision of the old install eats into
    that, and when the time runs out the server is reinstalled again. Raise
    `spec.checks.nodeStartupTimeoutSeconds` for the upgrade; syncing the capi-cluster app afterwards restores it.

Then start the upgrade, either as described in
[Cluster Upgrade](../getting-started/basic-operations.md#cluster-upgrade) or by bumping `global.kubernetes.version`
in `argocd-apps/values-capi-cluster.yaml` and syncing the capi-cluster app.

## Control plane

For each control-plane server, in the order Cluster API picks them:

1. `kubectl -n capi-cluster get machines` shows a Machine Deleting, waiting for the pre-drain hook.
2. Prepare its server: steps 1 and 2 of [Storage steps](#storage-steps).
3. Release the Machine:

   ```bash
   kubectl -n capi-cluster annotate machine <machine> \
     pre-drain.delete.hook.machine.cluster.x-k8s.io/storage-gate-
   ```

4. When the new node is Ready, finish with steps 3 and 4 of [Storage steps](#storage-steps).

## Workers

Once the control plane is done, for each worker server:

1. Prepare its server: steps 1 and 2 of [Storage steps](#storage-steps).
2. Delete its Machine: `kubectl -n capi-cluster delete machine <cluster>-<node-group>-<server-id>`. Cluster API
   drains the node and frees the server.
3. Sync the capi-cluster app. Argo CD creates the Machine again, and the same server is installed with the new
   version.
4. When the new node is Ready, finish with steps 3 and 4 of [Storage steps](#storage-steps).

## Storage steps

1. Move the data off the server's OS-disk OSDs, and wait until Ceph has copies elsewhere:

   ```bash
   ceph osd out <ids>
   ceph osd safe-to-destroy <ids>   # repeat until it reports them safe
   ```

   If the class has only `size` hosts (step 4 of [Before the upgrade](#before-the-upgrade)), this never
   finishes: marking the OSDs out only leaves their placement groups undersized. Skip it, make sure every
   placement group is `active+clean` first, and treat the reinstall as a window with one copy fewer.

2. Back up or move the ZFS LocalPV volumes you want to keep. Their PVs name the node under `spec.nodeAffinity`.
3. Check `ceph osd tree`:
   - Data-disk OSDs come back up by themselves.
   - OS-disk OSDs that came back up: `ceph osd in <ids>`.
   - OS-disk OSDs that stay down: `ceph osd purge <id> --yes-i-really-mean-it`, then delete the
     `rook-ceph-osd-<id>` deployment. Rook skips a partition that still carries the old OSD's label, so on the
     server run `blkdiscard -f <partition>`, which erases every copy of the label. Then restart the operator so it
     prepares new OSDs: `kubectl -n rook-ceph rollout restart deploy/rook-ceph-operator`.
4. Wait until every placement group is `active+clean` again before the next server.

## After the upgrade

- `ceph osd unset noout`
- `ceph balancer on`
- Restore Rook's mon failover timeout:

  ```bash
  kubectl -n rook-ceph patch cephcluster rook-ceph --type json \
    -p '[{"op":"remove","path":"/spec/healthCheck/daemonHealth/mon/timeout"}]'
  ```

- Set `spec.nodeMaintenanceWindow.inProgress: false` on the CloudNativePG clusters you changed.
- Sync the capi-cluster app to restore the MachineHealthCheck timeout.
- `kubectl get nodes` shows the new version on every node. Check the nodes, not the Machines: a worker Machine
  shows the new version before its server is reinstalled.

## Pitfalls

- **Don't pause the Cluster** (`spec.paused`) while a Machine is between install and join. The bootstrap token
  lives 15 minutes and is refreshed only while Cluster API reconciles, so the join fails and the server is
  reinstalled.
- **A node whose RBD I/O hangs** can block systemd: PID 1 sits in `D` state (`ps -o stat= -p 1`), `sudo` hangs and
  pods stay Terminating. Only a forced reboot clears it: `sudo sh -c 'sync -f /; reboot -ff'`, or a hardware reset
  from the Robot panel.
- **One Machine stuck in Deleting** stops the upgrade. Cluster API replaces nothing else until it is gone. A
  common cause is a drain waiting on a PodDisruptionBudget, for example a CloudNativePG primary
  ([Before the upgrade](#before-the-upgrade), step 7).
- **A stray `cluster.x-k8s.io/remediate-machine` annotation** marks a Machine for remediation: a
  MachineHealthCheck that covers it replaces it, which on bare metal means a reinstall. Check
  `kubectl -n capi-cluster get machines -o yaml | grep remediate-machine` before you start.
