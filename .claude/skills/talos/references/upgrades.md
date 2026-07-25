---
source_product: Talos Linux lifecycle management
source_version: v1.11 baseline; always inspect current and target versions
retrieved: 2026-07-21
primary_sources:
  - https://docs.siderolabs.com/talos/v1.11/configure-your-talos-cluster/lifecycle-management/upgrading-talos
  - https://docs.siderolabs.com/talos/v1.11/getting-started/support-matrix
  - https://docs.siderolabs.com/talos/v1.11/getting-started/what%27s-new-in-talos
---

# Talos and Kubernetes Upgrades

Treat an upgrade as a controlled migration of images, extensions,
configuration, and cluster availability.

## Supported Path

The official Talos upgrade guide says migrations are tested between adjacent
minor releases and recommends upgrading through the latest patch of every
intermediate minor release.

Therefore:

- Do not jump multiple Talos minor versions merely because the CLI accepts an
  image reference.
- Determine the latest patch for each intermediate minor at planning time.
- Read upgrade notes for each step.
- Rebuild or resolve the custom installer for every target step when extensions
  are required.

## Talos OS Versus Kubernetes

Talos OS upgrades and Kubernetes upgrades are separate operations. The Talos
upgrade guide explicitly notes that upgrading Talos does not upgrade Kubernetes
by default.

Keep separate plan sections, commits, or rollout phases for:

1. Talos OS and custom installer.
2. Kubernetes control-plane and node components.
3. Cilium and other cluster addons.
4. NVIDIA or storage stack changes.

Combine only when an explicit compatibility dependency requires it.

## Preflight

Before the first node:

- Record declared Talos and Kubernetes versions in Git.
- Query running versions on every node.
- Confirm local `talosctl` compatibility.
- Check control-plane and etcd health.
- Obtain and verify a recent etcd snapshot before control-plane risk.
- Review target release notes and configuration migrations.
- Confirm target Kubernetes support in the Talos support matrix.
- Resolve target Image Factory installer and extension set.
- Validate rendered machine configuration.
- Review Terraform plan for replacement.
- Define node order, validation gates, stop conditions, and rollback.

## Node Order

For a typical multi-node cluster:

1. Upgrade one non-critical worker.
2. Validate Talos, Kubernetes, networking, storage, GPU, and workloads.
3. Continue workers one at a time.
4. Upgrade control-plane nodes one at a time while preserving quorum.

For a single-control-plane homelab cluster:

- State that Kubernetes API downtime is expected during reboot/upgrade.
- Confirm workloads can tolerate temporary control-plane unavailability.
- Ensure a valid etcd snapshot and accessible Talos control path exist.
- Avoid combining other control-plane changes in the same maintenance window.

## Image and Extension Requirements

The official guide recommends a custom Image Factory installer so required
extensions are included. Avoid a generic installer when the current node uses:

- NVIDIA extensions.
- QEMU guest agent.
- Additional firmware.
- Alternative container runtime support.
- Other hardware-specific extensions.

## Rollback

Talos upgrades use an A/B image scheme and can automatically fall back when the
new image fails to boot. Manual `talosctl rollback` can return to the previous
boot image, but rollback is not a substitute for compatibility testing.

Rollback planning must distinguish:

- Talos image rollback.
- Machine configuration rollback.
- Kubernetes version rollback, which is a separate and more constrained issue.
- etcd storage-format implications.
- Terraform state and VM replacement.

Talos v1.11 introduced etcd 3.6 and an etcd downgrade API for storage format
management. Never improvise an etcd downgrade; follow the exact versioned docs
and validate quorum and backup state first.

## Kubernetes Upgrade Gate

Before `talosctl upgrade-k8s`:

- Verify target Kubernetes support for the running Talos version.
- Check removed APIs used by repository manifests and CRDs.
- Verify Cilium, CSI, cert-manager, Gateway API, Argo CD, and critical
  controllers support the target.
- Confirm etcd and control-plane health.
- Use dry-run behavior when available in the installed client.
- Validate nodes, system pods, DNS, networking, storage, and ingress afterward.

## Per-Node Validation

After every Talos node upgrade:

```bash
talosctl version --nodes <node>
talosctl health
talosctl get extensions --nodes <node>
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

Add hardware-specific checks for GPU, storage, and networking nodes.

## Stop Conditions

Stop the rollout when:

- A node does not rejoin.
- Required extensions are missing.
- Cilium or DNS is unhealthy.
- Storage mounts or CSI are degraded.
- GPU allocatable disappears.
- etcd alarms or quorum issues appear.
- Workloads fail in a way not explained by expected draining/restarts.

Do not continue merely because the Talos version query succeeded.
