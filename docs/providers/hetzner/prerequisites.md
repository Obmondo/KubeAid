# Hetzner Prerequisites

## Hetzner HCloud

### HCloud SSH KeyPair
Create an HCloud SSH KeyPair. Note that no two HCloud SSH KeyPairs can have the same SSH public key.

## Hetzner Bare Metal

### Hetzner Bare Metal SSH KeyPair
Create a Hetzner Bare Metal SSH KeyPair at https://robot.hetzner.com/key/index. Note that no two Hetzner Bare Metal SSH KeyPairs can have the same SSH public key.

### RAID Cleanup (if applicable)
If you plan to set `cloud.hetzner.bareMetal.wipeDisks: True` in your configuration, remove any pre-existing RAID setup from your Hetzner Bare Metal servers by executing `wipefs -fa <partition-name>` for each partition.

## Hetzner Hybrid
Requires both HCloud and Hetzner Bare Metal prerequisites listed above.
