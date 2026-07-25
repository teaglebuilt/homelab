---
source_product: Talos Linux NVIDIA GPU support
source_version: v1.11 baseline; always match the installed cluster version
retrieved: 2026-07-21
primary_source: https://docs.siderolabs.com/talos/v1.11/configure-your-talos-cluster/hardware-and-drivers/nvidia-gpu
---

# NVIDIA GPU Support

NVIDIA support spans Proxmox, Talos, the container runtime, Kubernetes device
plugins, and workloads. Diagnose and change the full chain rather than editing
only the Kubernetes manifest that shows the symptom.

## Required Talos Extensions

The Talos v1.11 OSS NVIDIA guide uses:

- `nvidia-open-gpu-kernel-modules`
- `nvidia-container-toolkit`

The official guide warns that published NVIDIA extensions are bound to a
specific Talos release and must be updated when Talos is upgraded. Driver
versions must match across the kernel module and container toolkit extension
selection.

Always verify the exact extension names and compatible versions for the target
Talos release in Image Factory and the official extension catalog.

## End-to-End Dependency Chain

```text
Proxmox PCI passthrough
  -> Talos custom installer and extensions
  -> Kernel modules loaded
  -> NVIDIA device nodes available
  -> Container runtime handler configured
  -> Kubernetes RuntimeClass
  -> NVIDIA device plugin and feature discovery
  -> Node labels and nvidia.com/gpu allocatable
  -> Workload requests/limits
  -> DCGM exporter and application health
```

## Repository Inspection

Before proposing a change, inspect:

- `tf_modules/talos_cluster/image.tf`
- `tf_modules/talos_cluster/pci_mapping.tf`
- `tf_modules/talos_cluster/patches/worker/`
- Cluster-specific node definitions under `kubernetes/terraform/<cluster>/`
- `kubernetes/apps/hardware/nvidia/`
- GPU monitoring resources and Taskfile helpers

Follow actual repository paths if they have moved.

## Troubleshooting Order

1. Confirm Proxmox attached the correct PCI function(s) to the VM.
2. Confirm the Talos node booted the intended custom image.
3. List Talos extensions.
4. Verify relevant kernel modules and device resources.
5. Verify the configured container runtime handler.
6. Inspect the Kubernetes node labels and allocatable resources.
7. Inspect NVIDIA device plugin logs and pod state.
8. Inspect DCGM exporter.
9. Inspect the workload's RuntimeClass, node selection, and GPU resource
   request.

Useful read-only checks:

```bash
talosctl get extensions --nodes <gpu-node>
talosctl get modules --nodes <gpu-node>          # when supported
talosctl dmesg --nodes <gpu-node>
kubectl get node <gpu-node> -o jsonpath='{.status.allocatable.nvidia\.com/gpu}'
kubectl get pods -A -o wide | grep -E 'nvidia|dcgm|gpu'
```

Use service logs and resource names supported by the installed Talos version;
do not assume aliases.

## Upgrade Rules

Before a Talos upgrade on a GPU node:

- Resolve a target Image Factory installer containing the target-compatible
  NVIDIA extensions.
- Confirm matching NVIDIA driver versions across required extensions.
- Preserve any other hardware extensions on the node.
- Upgrade a non-control-plane GPU worker first when possible.
- Verify extension state before checking Kubernetes.
- Verify `nvidia.com/gpu` allocatable and run a small GPU test workload before
  restoring production inference workloads.

Never use a generic Talos installer for a GPU node that currently depends on
custom NVIDIA extensions.

## Common Misdiagnoses

- Device plugin CrashLoop does not prove the Kubernetes YAML is wrong; the host
  device or runtime may be absent.
- A node label does not prove the GPU is allocatable.
- A RuntimeClass does not install Talos runtime support.
- `nvidia-smi` inside a random container is not a valid first host diagnostic.
- A successful Talos upgrade does not prove GPU workloads are healthy.
