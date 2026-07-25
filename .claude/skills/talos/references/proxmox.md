---
source_product: Talos Linux on Proxmox VE
source_version: v1.11 baseline; always match the installed cluster version
retrieved: 2026-07-21
primary_source: https://docs.siderolabs.com/talos/v1.11/platform-specific-installations/virtualized-platforms/proxmox
---

# Proxmox Integration

Keep the host/guest boundary clear:

- Proxmox owns VM lifecycle and virtual hardware.
- Talos owns the immutable guest operating system and Kubernetes node behavior.
- Kubernetes owns workloads and cluster controllers.

Do not work around a Proxmox hardware mapping problem by proposing mutable
changes inside Talos.

## VM Configuration Review

Before changing the Talos Terraform module, inspect existing patterns for:

- Proxmox node placement.
- Stable VM ID.
- CPU type and core count.
- Firmware and machine type.
- Boot order.
- System disk size and bus.
- NIC model and bridge/VLAN settings.
- Memory allocation and ballooning policy.
- QEMU guest agent extension.
- PCI passthrough and IOMMU mapping.

Changes to disks, firmware, machine type, image assets, PCI devices, or identity
can force VM replacement. Always inspect the Terraform plan and state the node
replacement risk explicitly.

## Image Assets

The official Proxmox guide recommends obtaining boot media from Image Factory.
When QEMU guest agent support is required, include the corresponding extension
in the custom asset and retain the related installer image reference for future
upgrades.

Avoid copying an ISO URL into automation without retaining:

- Talos version.
- Architecture.
- Schematic or extension selection.
- Checksum or immutable reference when available.

## PCI Passthrough

The end-to-end path is:

```text
Physical PCI device
  -> Proxmox host IOMMU and driver binding
  -> Proxmox VM PCI mapping
  -> Talos kernel/extension support
  -> Kubernetes runtime/device plugin
  -> Workload resource request
```

Diagnose in that order. If the VM does not receive the device, Talos and
Kubernetes configuration cannot fix it.

For a PCI change:

1. Confirm host address, vendor/device IDs, subsystem ID, and IOMMU group.
2. Confirm the device is mapped to the intended VM and Proxmox node.
3. Review whether Terraform will detach, recreate, or restart the VM.
4. Confirm the Talos image contains the required driver/runtime extensions.
5. Verify device visibility in Talos after boot.
6. Verify Kubernetes allocatable resources and dependent daemonsets.

## Storage

Talos uses its system disk for EFI, META, STATE, and EPHEMERAL partitions. The
official requirements recommend enough capacity for images and container work,
not merely the small immutable OS image.

When investigating disk pressure:

- Check the Proxmox virtual disk size first.
- Check Talos disks, mounts, and EPHEMERAL usage.
- Check Kubernetes image/container usage and evictions.
- Do not resize or replace the wrong virtual disk.
- Review whether changing Terraform disk settings causes replacement or an
  in-place expansion.

## Networking

A VM network problem can exist at multiple layers:

1. Proxmox bridge, VLAN, and virtual NIC.
2. Talos link, address, route, MTU, and DNS.
3. Cilium dataplane and Kubernetes services.
4. UniFi physical or routed network.

Keep the remediation in the layer that owns the failure.

## Safe Plan Requirements

Any Proxmox/Talos change plan should state:

- VM and node affected.
- Whether a reboot or replacement occurs.
- Expected control-plane or workload downtime.
- PCI and storage impact.
- How node identity is preserved.
- Validation after boot.
- Rollback limits if the VM is replaced.
