# Reboot a node

k8s resources are usually independent of any specific node and kubectl makes this task easy.

NOTE - you would still need to verify the resources which utilises PVCs and ensure that PVCs
are detachable and re-attachable so that pods do not suffer while getting migrated from one node to another.

On Hetzner bare-metal clusters, follow [Reboot a Hetzner bare-metal node](./hetzner-bare-metal-node-reboot.md) instead.

## Steps

1. You need to cordon the node. ```cordoning``` marks a node as unscheduled so that no new pods are placed there

```shell
kubectl cordon <node-name>
```

you can confirm the node's status as "SchedulingDisabled" by running:

```shell
kubectl get nodes
```

1. You need to drain the node.
first confirm by doing the dry run

```shell
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --dry-run=server
```

After you verify the listed resources, you can proceed with actually draining the node.

1. Reboot the node.

There are multiple methods to reboot the node, depends upon platform. you can also exec into the node and run

```shell
reboot
```

1. wait for a few minutes and verify if node have become healthy again

```shell
kubectl get nodes
```

1. You can now uncordon the node.

```shell
kubectl uncordon <node-name>
```
