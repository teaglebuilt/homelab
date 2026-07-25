---
name: talos
description: >
  Version-aware Talos Linux expertise for this homelab. Use for talosctl,
  Talos machine configuration and patches, Image Factory schematics, system
  extensions, Proxmox Talos VMs, cluster bootstrap, Talos or Kubernetes
  upgrades, etcd backup and recovery, node diagnostics, NVIDIA GPU support,
  or the siderolabs/talos Terraform provider. Also use when changing
  tf_modules/talos_cluster, kubernetes/terraform/*, Talos Taskfiles, or
  Talos-specific cluster definitions. Do not use for ordinary Kubernetes app
  manifests, Helm releases, HTTPRoutes, or UniFi changes unless the issue
  specifically crosses into the Talos host or machine configuration layer.
metadata:
  product: talos-linux
  repository: teaglebuilt/homelab
  documentation-policy: version-matched-official-sources
---

# Talos Linux for the Homelab

Use this skill to make Talos work accurate, version-aware, repository-aware,
and operationally safe.

Talos is an immutable, API-managed operating system. Persistent fixes belong in
Terraform, generated machine configuration inputs, templates, or versioned
patches—not in one-off host mutations.

## Agent Boundaries

- Use `architect` for upgrades, migrations, topology, and rollout design.
- Use `developer` to implement Terraform, templates, patches, and Taskfiles.
- Use `security-agent` for credentials, trust, host hardening, or recovery risk.
- Use `network-agent` only for UniFi and physical network state.
- Cilium, kubelet, host DNS, kernel modules, runtime configuration, and Talos
  networking remain in the Talos/developer/architect scope.

## Required Workflow

1. Read `CLAUDE.md` and inspect existing repository patterns.
2. Identify the affected cluster and nodes.
3. Determine:
   - Talos version declared in Git.
   - Talos version running on each affected node.
   - Local `talosctl` version.
   - Kubernetes version declared and running.
4. Load only the reference files needed for the task.
5. Compare repository desired state with live state when diagnosing failures.
6. Begin with read-only inspection.
7. Make persistent changes in Git; do not leave a live patch as the only fix.
8. Render and validate machine configuration before proposing an apply.
9. State rollout order, validation checkpoints, blast radius, and rollback.
10. Require explicit user intent before any live mutation or destructive action.

Run the bundled context collector when repository and live-state discovery would
otherwise be repeated manually:

```bash
"${CLAUDE_SKILL_DIR}/scripts/collect-context.sh" --cluster mlops --node <node>
```

Validate rendered machine configuration with:

```bash
"${CLAUDE_SKILL_DIR}/scripts/validate-configs.sh" \
  --cluster mlops \
  --config-dir kubernetes/generated
```

## Non-Negotiable Safety Rules

- Never recommend SSH, a shell, package installation, `apt`, `dnf`, or direct
  host file editing on Talos.
- Never edit files under a `generated/` directory as the permanent fix.
- Never expose a complete `talosconfig`, machine secrets, certificates,
  bootstrap tokens, or decrypted SOPS content.
- Never assume the latest Talos documentation matches the installed version.
- Never run `apply-config`, `patch`, `upgrade`, `upgrade-k8s`, `bootstrap`,
  `reset`, `wipe`, `rollback`, `reboot`, or etcd recovery operations without
  explicit user intent.
- Never bootstrap an initialized healthy cluster.
- Never use reset or wipe as an early troubleshooting step.
- Never upgrade with a generic installer when nodes depend on custom extensions
  unless removing those extensions is intentional.
- Treat Talos OS and Kubernetes upgrades as separate changes.
- For a single-control-plane cluster, call out expected API downtime before
  proposing control-plane maintenance.

## Repository Discovery

Inspect these locations first, while allowing for repository evolution:

| Concern | Likely location |
|---|---|
| Cluster versions and root module | `kubernetes/terraform/<cluster>/` |
| Cluster identity and CIDRs | `kubernetes/clusters/<cluster>/cluster.yaml` |
| Reusable module | `tf_modules/talos_cluster/` |
| Machine templates | `tf_modules/talos_cluster/templates/` |
| Shared and role patches | `tf_modules/talos_cluster/patches/` |
| Image Factory and extensions | `tf_modules/talos_cluster/image.tf` |
| PCI/GPU mapping | `tf_modules/talos_cluster/pci_mapping.tf` |
| Talos Taskfile wrappers | `kubernetes/.taskfiles/talos/` |
| Cilium coupling | `kubernetes/apps/networking/cilium/` |
| NVIDIA Kubernetes resources | `kubernetes/apps/hardware/nvidia/` |

Use `find` and `rg` before assuming a path is still current.

## Reference Routing

Read only the relevant files:

- [machine-configuration.md](references/machine-configuration.md) — schemas,
  source precedence, rendering, validation, and configuration ownership.
- [patching.md](references/patching.md) — strategic merge versus RFC 6902,
  patch placement, merge behavior, and examples.
- [image-factory-and-extensions.md](references/image-factory-and-extensions.md) —
  custom installers, schematics, extension lifecycle, and upgrade coupling.
- [proxmox.md](references/proxmox.md) — VM hardware, disks, NICs, QEMU guest
  agent, Terraform replacement risk, and PCI passthrough boundaries.
- [nvidia.md](references/nvidia.md) — Talos NVIDIA extensions, runtime chain,
  version matching, validation, and upgrade checks.
- [upgrades.md](references/upgrades.md) — Talos and Kubernetes upgrade planning,
  intermediate releases, rollback, snapshots, and validation gates.
- [troubleshooting.md](references/troubleshooting.md) — read-only diagnostic
  ladder, symptom mapping, support bundles, and etcd recovery safety.

## Source Precedence

When sources disagree, use this order:

1. Live state for what is currently running or failing.
2. Repository state for intended configuration.
3. Official documentation for the installed Talos minor version.
4. Official release notes and upgrade notes for the target version.
5. General knowledge only when the above do not answer the question.

Verify exact flags and field names with the installed client and schema:

```bash
talosctl version --nodes <node>
talosctl <command> --help
talosctl validate --help
```

## Output Expectations

For implementation work, provide:

1. Files modified.
2. Why each file is the correct configuration layer.
3. Rendered or planned impact.
4. Validation commands and results.
5. Live actions intentionally left unapplied.
6. Rollout and rollback steps.

For troubleshooting, provide:

1. Evidence observed.
2. Desired-state versus live-state differences.
3. Most likely fault domain and confidence.
4. Next safest diagnostic command.
5. Remediation only after the diagnosis is grounded.
6. Recovery or destructive actions clearly separated from routine fixes.
