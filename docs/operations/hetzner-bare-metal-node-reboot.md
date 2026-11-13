# Reboot a Hetzner bare-metal node

A step-by-step guide to reboot a node of a KubeAid cluster on Hetzner dedicated servers, for example onto a new kernel.
Run it top to bottom, one node at a time. Each step has a command and what you should see.

- Wait for Ceph to be clean before starting the next node.
- Do the control plane that holds the Failover IP last.
- Steps marked **CP** are for control-plane nodes only.

For the general cordon, drain and uncordon flow, see [Node Reboot](./node-reboot.md).

## 0. Pick the node

Set these once in your shell. Every command below uses them.

```shell
N=<node name>
IP=<node public IP>
CLUSTER=<cluster name>
```

## 1. Pre-checks

### Ceph is clean

```shell
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph pg stat
```

Expect: every PG `active+clean` (scrubbing is fine).

### The new kernel is installed

```shell
ssh root@$IP 'uname -r; ls /boot | grep vmlinuz-'
```

Expect: the new kernel in the list.

Ubuntu kernels from 7.0.0-41 (at least up to 7.0.0-44) deny signals inside containers while
`kernel.apparmor_restrict_unprivileged_unconfined` is `1`
([containerd#14485](https://github.com/containerd/containerd/issues/14485)). Check it before rebooting onto one:

```shell
ssh root@$IP sysctl kernel.apparmor_restrict_unprivileged_unconfined
```

Expect: `= 0`.

### CP: boot order

```shell
ssh root@$IP efibootmgr
```

Expect: the first ID in `BootOrder` is an `ubuntu` entry or a `UEFI: PXE IPv4` entry.

If it is a `Network Card` entry (the legacy PXE ROM on some boards), the node can stop at
`PXE-M0F: Exiting PXE ROM` and not come back. Servers installed before the boot-order fix in the capi-cluster chart
([#552](https://github.com/Obmondo/KubeAid/pull/552)) can have this. Move the `ubuntu` IDs to the front, for example:

```shell
ssh root@$IP efibootmgr -o 0003,0004,0001,0002
```

## 2. Prepare

### First node of the round only: Ceph noout

```shell
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd set noout
```

### CP: pause the MachineHealthCheck

Otherwise a reboot that takes longer than the health-check timeout gets the server reinstalled.

```shell
kubectl -n capi-cluster annotate mhc $CLUSTER-control-plane-unhealthy-5m cluster.x-k8s.io/paused=
```

### Drain

```shell
kubectl drain $N --ignore-daemonsets --delete-emptydir-data --timeout=15m
```

If it waits forever on a PodDisruptionBudget (for example a single-instance database), make sure that app can take the
downtime, then run it again with `--disable-eviction --grace-period=120` added.

### CP: the Failover IP is off this node

```shell
kubectl -n kube-system logs deploy/hetzner-robot-failover | tail -2
```

Expect: `Successfully updated Failover IP` or `already points to this node`, with an IP that is not `$IP`. After the
drain, the pod moves to another control plane and re-points the IP within one `cronTimeInterval` (5 minutes by
default).

### Nothing left on the node

```shell
kubectl get pods -A --field-selector spec.nodeName=$N \
  -o 'custom-columns=N:.metadata.name,K:.metadata.ownerReferences[0].kind' \
  | grep -v -e DaemonSet -e Node
```

Expect: only the `N K` header line.

## 3. Reboot

```shell
kubectl get node $N -o jsonpath='{.status.nodeInfo.bootID}'; echo
ssh root@$IP systemctl reboot
kubectl get node $N -w
```

Expect: `Ready` within about 10 minutes (stop the watch with Ctrl-C). If it is not, go to section 6.

## 4. After the reboot

### Check the kernel, then uncordon

```shell
ssh root@$IP uname -r
kubectl uncordon $N
```

### CP: control plane healthy, unpause the MachineHealthCheck

```shell
kubectl -n capi-cluster get kubeadmcontrolplanes,machines
kubectl -n capi-cluster annotate mhc $CLUSTER-control-plane-unhealthy-5m cluster.x-k8s.io/paused-
```

Expect: all control-plane machines ready before you unpause.

### Ceph clean again

```shell
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph pg stat
```

Expect: every PG `active+clean`. Only then start the next node.

## 5. After the last node

```shell
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd unset noout
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph crash archive-all
```

## 6. If it is not back in 10 minutes

Keep the MachineHealthCheck paused and do not touch the other control planes. etcd keeps working with 2 of 3.

1. `ping -c3 $IP` from your machine.
1. Hetzner Robot → the server → Reset → hardware reset. Wait 10 minutes.
1. Still down: open a Hetzner support ticket and ask them to check the screen and boot the `ubuntu` UEFI entry.
   See also [Hetzner hardware failures](../guides/hetzner/hetzner-hardware-failures.md).
