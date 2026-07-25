---
source_product: Talos Linux
source_version: v1.11 baseline; always match the installed cluster version
retrieved: 2026-07-21
primary_source: https://docs.siderolabs.com/talos/v1.11/configure-your-talos-cluster/system-configuration/patching
---

# Configuration Patching

Talos supports two patch formats:

- Strategic merge patches.
- RFC 6902 JSON patches.

Prefer strategic merge for readable, durable repository configuration. Use JSON
patches only when exact path or list manipulation is required.

## Strategic Merge

A strategic merge patch resembles a partial Talos configuration:

```yaml
machine:
  kubelet:
    nodeIP:
      validSubnets:
        - 192.168.2.0/24
```

Strategic merge supports multi-document Talos configuration and is usually the
best fit for version-controlled homelab patches.

Important merge behavior from the official patching guide:

- Most lists append rather than replace.
- `cluster.network.podSubnets` and `serviceSubnets` replace existing values.
- Network interfaces merge by `interface` or `deviceSelector`.
- VLANs merge by `vlanId`.
- Multi-document patches match documents by kind, API version, and name.
- `$patch: delete` can delete supported fields, list items, or additional
  documents; it cannot delete the main configuration document.

Always render the final result. A patch that looks correct by itself can produce
an invalid or duplicated list after merge.

## RFC 6902

Use JSON patch when the operation must be exact:

```yaml
- op: replace
  path: /machine/network/hostname
  value: mlops-work-00
```

The correct operation depends on whether the path exists. JSON patches do not
support patching multi-document configuration as a whole, so avoid them for
new-style additional documents.

## Patch Placement

Choose the narrowest correct scope:

```text
patches/
├── common/ or shared patch
├── controlplane/
├── worker/
└── hardware or node-specific patch
```

Repository names may differ; follow the existing module layout.

Do not:

- Put a node-specific PCI or disk value in a shared worker patch.
- Duplicate a value in both a template and patch.
- Create another patch when an existing patch clearly owns the concern.
- Depend on patch ordering without documenting it.
- Commit only the rendered result.

## Safe Workflow

1. Locate the current field in templates, inputs, and patches.
2. Determine scope and merge behavior.
3. Add or modify one patch at the owning layer.
4. Render the machine config.
5. Confirm the intended value appears once.
6. Validate with `talosctl validate --strict`.
7. Review whether the change is immediate, rebooting, or disruptive.
8. Use a live patch only with explicit approval and reconcile it to Git.

Useful offline command:

```bash
talosctl machineconfig patch \
  <base-config.yaml> \
  --patch @<patch.yaml> \
  --output <patched-config.yaml>
```

A live patch command changes real node state:

```bash
talosctl patch mc --nodes <node> --patch @<patch.yaml>
```

Do not run it merely to test whether a patch parses. Use offline rendering and
validation first.

## Cilium Example

When Cilium owns cluster networking, the Talos cluster configuration commonly
disables the default CNI:

```yaml
cluster:
  network:
    cni:
      name: none
```

This setting belongs in cluster configuration; Cilium Helm values remain in the
Kubernetes application layer. Do not mix Cilium chart configuration into a
Talos machine patch.
