---
source_product: Talos Linux
source_version: v1.11 baseline; always match the installed cluster version
retrieved: 2026-07-21
primary_sources:
  - https://docs.siderolabs.com/talos/v1.11/build-and-extend-talos/custom-images-and-development/system-extensions
  - https://docs.siderolabs.com/talos/v1.11/configure-your-talos-cluster/lifecycle-management/upgrading-talos
  - https://factory.talos.dev/
---

# Image Factory and System Extensions

Talos remains immutable when system extensions are installed. Extensions are
included in boot or installer assets and activated during installation or
upgrade; they are not packages installed interactively on a running node.

## Repository Workflow

For this homelab, inspect the reusable Talos module before changing an image:

```text
tf_modules/talos_cluster/image.tf
provider and version constraints
cluster root-module image inputs
hardware-specific extension selections
```

A good design keeps the following explicit:

- Talos release.
- Architecture (`amd64` or `arm64`).
- Platform or image type.
- Selected system extensions.
- Image Factory schematic or installer reference.
- Which node or hardware class consumes the image.

## Extension Lifecycle

The official Talos documentation states that system extensions are activated
at installation or upgrade time. Therefore:

1. Adding an extension requires new boot/install assets or a machine upgrade.
2. Removing an extension also requires moving to an image that omits it.
3. Upgrading Talos requires rebuilding or resolving an image for the target
   Talos release with the required extensions.
4. A generic installer can silently remove hardware or runtime functionality
   supplied by the custom image.

Verify the running node after install or upgrade:

```bash
talosctl get extensions --nodes <node>
talosctl get modules --nodes <node>   # when supported by the installed version
```

## Schematic Discipline

Treat the schematic as code:

- Keep extension selection reproducible in Terraform or a checked-in source
  document.
- Do not rely only on a copied factory URL with no record of its inputs.
- Update the image reference and declared Talos version in one reviewed change.
- Preserve firmware and runtime extensions required by each node class.
- Review security and support tier for each extension.
- Avoid extension sprawl; every extension increases image size and maintenance.

## Upgrade Coupling

Before changing Talos version:

1. List extensions on every affected hardware class.
2. Confirm each extension exists for the target release.
3. Review extension-specific version requirements.
4. Generate the target installer image.
5. Validate the image reference and architecture.
6. Upgrade one non-control-plane node first when topology allows.
7. Verify extensions and dependent workloads before continuing.

## Proxmox Notes

Image Factory assets used for Proxmox may include extensions such as the QEMU
guest agent. A custom ISO is useful for initial provisioning; the matching
custom installer reference is needed for later upgrades.

Do not confuse:

- The ISO or PXE asset used to boot/install a VM.
- The installer image used by the Talos upgrade API.
- The running immutable root filesystem.

All three must represent a coherent extension set.

## Validation Checklist

- [ ] Target Talos release is explicit.
- [ ] Architecture matches the VM or hardware.
- [ ] Required extensions are listed by source input, not memory.
- [ ] Extension availability and compatibility are verified for the target.
- [ ] Installer reference is reproducible.
- [ ] Generic installer is not replacing a custom image accidentally.
- [ ] Running extension state is verified after rollout.
- [ ] Dependent workloads are tested after extension changes.
