# Hetzner Features

## Disk layout for Hetzner Bare Metal servers

For each Hetzner Bare Metal server, we have **level 1 SWRAID** (Software RAID) enabled across disks whose WWNs you've specified in the general config file. And, by default, on top of that level 1 SWRAID, we create a **25G** sized `Logical Volume Group` (LVG) named **vg0**. It contains the **10G** sized **root** `Volume Group` (VG), where the Operating System gets installed.

If you have HDDs attached to the server, then we recommend you specify their WWNs in the general config file. So the OS will get installed there, and, you'll have your SSDs / NVMes solely dedicated to your stateful workloads.
