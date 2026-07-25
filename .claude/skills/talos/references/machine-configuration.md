---
source_product: Talos Linux
source_version: v1.11 baseline; always match the installed cluster version
retrieved: 2026-07-21
primary_sources:
  - https://docs.siderolabs.com/talos/v1.11/reference/configuration/v1alpha1/config
  - https://docs.siderolabs.com/talos/v1.11/reference/cli
---

# Machine Configuration

Talos machine configuration is the durable API contract for node and cluster
behavior. Treat generated configuration as an artifact produced from repository
inputs, not as the source of truth.

## Determine the Owning Layer

Before editing, find where the current value originates:

1. Cluster root-module input.
2. Reusable `tf_modules/talos_cluster` variable or local.
3. Control-plane or worker template.
4. Shared, role-specific, node-specific, or hardware-class patch.
5. Generated output.
6. Live node state.

Make the change at the highest reusable layer that accurately owns the value,
without making the reusable module cluster-specific.

Use these guidelines:

| Scope | Preferred owner |
|---|---|
| Every cluster using the module | Reusable module default or shared template |
| One cluster | Cluster root-module input |
| Every control-plane node | Control-plane template or patch |
| Every worker | Worker template or patch |
| One hardware class | Named hardware-class patch/input |
| One node | Node-specific input or patch |
| Temporary investigation | Read-only live query; avoid mutation |

## Version Awareness

Talos configuration fields and document kinds evolve. Before writing YAML:

```bash
talosctl version --nodes <node>
talosctl validate --help
```

Then consult the official configuration reference for that exact Talos minor
version. For an upgrade, read both current and target configuration references
and the target upgrade notes.

The repository may declare different versions for different clusters. Search:

```bash
rg -n 'talos_version|update_version|kubernetes_version' \
  kubernetes/terraform tf_modules/talos_cluster
```

## Multi-Document Configuration

Modern Talos machine configuration can contain multiple YAML documents. The
main configuration commonly remains `v1alpha1`, while additional documents can
configure extension services and other system features.

Preserve document boundaries. Do not flatten a multi-document configuration or
assume every field belongs under the main `machine:` or `cluster:` tree.

## Rendering and Validation

A complete change should be testable before it touches a node:

1. Format and validate Terraform.
2. Render the affected machine configurations.
3. Validate every rendered control-plane and worker config.
4. Diff rendered output against the previous artifact.
5. Inspect unexpected changes, especially secrets, install disks, endpoint,
   SANs, CNI settings, kernel modules, and extension configuration.

Offline validation:

```bash
talosctl validate \
  --config <rendered-machine-config.yaml> \
  --mode metal \
  --strict
```

For Proxmox VMs using the normal metal image, `--mode metal` is generally the
correct validation mode. Confirm this against the actual provisioning method.

Before a complete live apply, prefer a dry run when supported by the installed
client:

```bash
talosctl apply-config \
  --nodes <node> \
  --file <rendered-machine-config.yaml> \
  --dry-run
```

A trial apply can reduce risk for supported configuration changes, but it does
not replace offline validation, a stable control path, or a rollback plan.

## Sensitive Material

Machine configs and `talosconfig` contain credentials and certificates.

- Do not paste complete files into chat, logs, PR descriptions, or CI artifacts.
- Show only non-secret fields needed to explain a diff.
- Store generated credentials with restrictive permissions.
- Do not commit generated client configuration unless the repository explicitly
  has a protected encrypted workflow for it.
- Redact endpoints only when necessary; never redact so much that node identity
  becomes ambiguous during a recovery procedure.

## Completion Criteria

A machine configuration change is incomplete until:

- The owning repository input is updated.
- Rendered output is valid.
- The blast radius is stated.
- Reboot or service-restart behavior is understood.
- A rollback path is documented.
- Any approved live apply is reconciled back to Git.
