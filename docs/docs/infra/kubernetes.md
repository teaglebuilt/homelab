---
sidebar_position: 2
---

[Talos Linux](https://www.talos.dev/v1.9/) is a linux operating system that runs and manages kubernetes.

## Clusters

### MLOps Cluster

- `mlops-ctrl-00`
- `mlops-work-00`
- `mlops-work-01`

**vfio-pci** is set as the kernel driver on the GeoForce RTX 4070 Super. This is needed for gpu passthrough to work so the virtualized kubernetes node can utilize it. It is registered in proxmox as a PCIE device which is defined in terraform [here](https://github.com/teaglebuilt/homelab/blob/main/tf_modules/talos_cluster/pci_mapping.tf)

![GPU Node](https://raw.githubusercontent.com/teaglebuilt/homelab/main/docs/static/img/gpu-node.png)


### Administration Cluster

- `admin-ctrl-00`
- `admin-work-00`
- `admin-work-01`
