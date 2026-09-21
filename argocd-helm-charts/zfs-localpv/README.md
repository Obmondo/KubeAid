# ZFS LocalPV

Wrapper chart for the upstream [`zfs-localpv`](https://github.com/openebs/zfs-localpv) chart (pinned to `2.10.1`,
appVersion `2.10.1`), OpenEBS's CSI driver (`zfs.csi.openebs.io`) that provisions **ZFS dataset**-backed local
`PersistentVolume`s, with snapshot/clone and per-volume ZFS tuning (recordsize, compression, dedup).

## Why it's in KubeAid

Not currently rendered automatically by `kubeaid-cli` (no entry in `pkg/constants/templates.go`) — it's an
opt-in chart for **Hetzner bare-metal** clusters that allocate NVMe disks to a mirrored ZFS pool, per
`docs/hosting/cloud-providers.md`'s bare-metal disk-layout guidance ("Allocate NVMes to a ZPool (mirror mode) for
ContainerD, logs, and OpenEBS ZFS LocalPV"). Where it's used, it's the higher-performance NVMe-backed alternative
to [`localpv-provisioner`](../localpv-provisioner)'s hostPath storage.

## Prerequisites

1. A ZFS pool already created on every node that will run the driver, e.g.:

   ```sh
   sudo zpool create -m /mnt/nvmelocal mypool mirror /dev/sdb /dev/sdc
   ```

   (assuming `/dev/sdb` and `/dev/sdc` are the disks for the mirrored pool, and `nvmelocal` is the pool name,
   mounted at `/mnt/nvmelocal`; use `sudo fdisk -l` to check available drives first).
2. Nodes labelled so `zfsController`/`zfsNode` land only where the pool exists — this chart's default
   `nodeSelector` is `disk: nvme` (label nodes with `kubectl label node <name> disk=nvme`, and `filesystem=zfs` if
   scoping further, e.g. via a custom `nodeSelector` — see
   [examples/values-nodeselector.yaml](examples/values-nodeselector.yaml)). Verify with
   `kubectl get node <node_name> --show-labels`.

## Key values / KubeAid-specific configuration

Upstream values live under the `zfs-localpv:` key; the chart adds one KubeAid-specific top-level key.

- `zfs-localpv.zfsNode.nodeSelector` / `zfsController.nodeSelector`: `disk: nvme` — restrict the driver to
  NVMe-labelled nodes (`values.yaml`).
- `zfs-localpv.zfsExporter`: a Prometheus exporter (`obmondo/zfs_exporter`, from `harbor.obmondo.com/`) is
  bundled and enabled by default, with a `ServiceMonitor` scraping `/metrics` every 10s on port 9134.
- `zfs-localpv.zfsNode.priorityClass.name: zfs-csi-node-critical` / `zfsController.priorityClass.name:
  zfs-csi-controller-critical` — dedicated `PriorityClass`es, created by default.
- `storageClass.enabled` (default `false`, chart-added key) — when `true`, `templates/storageclass.yaml` renders
  a `zfs-localpv` `StorageClass` (and, if `storageClass.shared: true`, also a `zfs-localpv-shared` one) using
  `storageClass.poolName` (**required** when enabled) and `storageClass.reclaimPolicy` (default `Delete`).
  `storageClass.default: true` additionally marks `zfs-localpv` as the cluster's default StorageClass, for
  clusters where it is the only storage and PVCs without a `storageClassName` (kube-prometheus) must bind. See
  [examples/values-storageclass.yaml](examples/values-storageclass.yaml) for a worked example; confirm with
  `kubectl get sc` once deployed.

## Docs links

- Upstream chart & storageclass reference: <https://github.com/openebs/zfs-localpv/blob/develop/docs/storageclasses.md>
- OpenEBS docs: <https://openebs.io/docs>
- [Hetzner bare-metal disk layout](../../docs/hosting/cloud-providers.md)
- [KubeAid: Helm umbrella pattern](../../docs/kubeaid/helm-umbrella-pattern.md)
