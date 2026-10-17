# Decision: Kubernetes-Driven Proxmox VM Provisioning

**Decision:** use **Crossplane v2 + Upbound `provider-opentofu`** for the first implementation.

**Research date:** 2026-10-14
**Crossplane docs baseline:** v2.4
**provider-opentofu baseline:** v1.1.6

Read `00-agentdesktop-capability-audit.md` first.

## Why this does not duplicate Agent Desktop

Agent Desktop explicitly leaves underlying endpoint deployment to an MDM/device-management layer. It manages AI developer tools **after a machine exists and the daemon is installed**.

For this homelab:

```text
Crossplane/OpenTofu = machine infrastructure lifecycle
cloud-init/Ansible  = Linux MDM-equivalent package/service bootstrap
Agent Desktop       = AI-tool-aware endpoint management
```

The Agent Desktop capability audit does **not** change this infrastructure decision.

## Problem

Desktop VMs should be declaratively owned from Kubernetes while continuing to use the repository's existing HCL and `bpg/proxmox` provider.

Existing repo investment includes:

```text
tf_modules/virtual_machine/
tf_modules/talos_cluster/
machines/nixos/terraform/
```

GitOps is ArgoCD + Helmfile/Kustomize rather than Flux.

## Candidates

### Option A — Crossplane v2 + `provider-opentofu` — SELECTED

```text
ArgoCD/Kustomize
      │
      ▼
Crossplane Workspace
      │
      ▼
provider-opentofu
      │
      ▼
Proxmox OpenTofu module
      │
      ▼
bpg/proxmox
      │
      ▼
Proxmox VM
```

Why it fits:

- no Flux dependency;
- reuses existing HCL modules;
- exposes OpenTofu execution as Kubernetes reconciliation;
- supports later Crossplane XRs/Compositions;
- module remains runnable with normal `tofu` for break-glass operations;
- fits ArgoCD ownership of Kubernetes desired state.

### Current provider caveat

`provider-opentofu` v1.1.6 is the current release at this audit, but upstream still has open work for OpenTofu 1.11.x support. v1.1.0 documented a bundled OpenTofu 1.10.8 runtime; later 1.11 support remains an open issue/PR.

The homelab's existing modules use Terraform/OpenTofu constraints around `>= 1.5`, so the current provider runtime is compatible **as long as this desktop module does not introduce 1.11-only syntax/features**.

Requirements:

```text
pin provider-opentofu version
pin Crossplane chart version
run the desktop module through the provider during the spike
avoid OpenTofu 1.11-only features until provider support is verified
```

### Option B — Flux Tofu Controller — NOT SELECTED

Technically capable, but its standard workflow uses Flux source resources/source-controller. Adding Flux only to execute OpenTofu would introduce another GitOps/source control plane beside ArgoCD/Helmfile.

Reconsider only if Flux is intentionally adopted elsewhere.

### Option C — native Crossplane Proxmox provider — EVALUATE LATER

Potential future shape:

```text
AgentDesktopInfrastructure XR
      │
      ▼
Proxmox VirtualMachine managed resource
```

Potential benefits:

- no OpenTofu execution layer;
- no separate Terraform state;
- more direct managed-resource reconciliation.

Do not select it until the exact provider proves support for the Proxmox features required here:

```text
template clone
cloud-init
network/disk lifecycle
snapshot/rollback semantics
QEMU guest agent
later GPU/PCI passthrough
stable upgrade behavior
```

### Option D — custom Proxmox Kubernetes controller — REJECT

This would duplicate IaC/provider behavior and add unnecessary controller maintenance.

### Option E — Coder as VM lifecycle plane — REJECT FOR THIS PROJECT

Coder is useful for human developer workspaces, but it introduces a second workspace/product layer we do not currently need. Our desired state is narrower:

```text
Kubernetes owns VM infrastructure
Agent Desktop owns AI endpoint management
Substrate owns agent runtime
```

## Crossplane ownership boundary

Crossplane may own only infrastructure fields such as:

```text
VM name/ID
Proxmox node
source template/clone
CPU/RAM
disk/storage
bridge/VLAN
cloud-init inputs
QEMU guest agent
power/existence
later GPU/PCI configuration
```

Crossplane must **not** own:

```text
Agent Desktop enrollment state
Claude/Codex managed settings
MCP/skill inventory
sandbox policy
gateway credentials
Agent Desktop telemetry
actor/session leases
```

## OpenTofu state

Use durable remote state from the start.

Requirements:

- encrypted at rest;
- locking supported;
- restricted service identity;
- recovery documented;
- state is not stored only on provider Pod disk.

Select the backend during the spike based on the repo's existing cloud credentials/storage conventions.

## Module strategy

Do not force the current generic `tf_modules/virtual_machine` module to absorb workstation-specific behavior if that would make it incoherent.

Prefer a dedicated module if needed:

```text
tf_modules/agent_workstation/
```

Inputs should remain infrastructure-only, for example:

```text
name
vm_id
proxmox_node
template_vm_id
cores
memory
disk_size
storage
bridge
vlan_id
cloud_init_user_data
```

Agent Desktop configuration should not become HCL module variables except the minimum bootstrap information required to install/connect the daemon.

## ArgoCD / Crossplane ownership

Recommended model:

```text
Git
  │
ArgoCD
  │ owns Workspace desired state
  ▼
Crossplane
  │ owns OpenTofu reconciliation
  ▼
provider-opentofu
  │ owns HCL execution/state
  ▼
Proxmox
```

ArgoCD should not repeatedly fight provider-produced runtime status/output fields.

## Destruction policy

Persistent enrolled Agent Desktop machines should not be casually destroyed.

For the first workstation:

- use a conservative deletion policy;
- require deliberate Git change/manual confirmation before VM destruction;
- document that VM replacement also means Agent Desktop re-enrollment/offboarding;
- never scale the pool to zero automatically in MVP.

## Future Composition

After one workstation module is proven, consider a higher-level infrastructure-only API:

```yaml
apiVersion: ai.teaglebuilt.io/v1alpha1
kind: AgentWorkstation
metadata:
  name: linux-agent-01
spec:
  class: linux-coding
  resources:
    cpu: 8
    memory: 16Gi
```

A Composition may create the OpenTofu `Workspace` and infrastructure Secret references.

It should not model Agent Desktop application policy.

## Decision checkpoints

The Crossplane spike must prove:

1. v2.4 installs cleanly on the target cluster.
2. `provider-opentofu` v1.1.6 becomes healthy.
3. existing/new Proxmox module runs under the provider's bundled OpenTofu runtime.
4. remote state survives provider Pod replacement.
5. no-op reconciliation does not mutate the VM.
6. VM update/delete behavior is understood before enrollment.
7. Proxmox credentials remain only in the provider Secret boundary.

If these fail materially, reevaluate native Crossplane Proxmox provider or direct GitOps-triggered OpenTofu before writing a custom controller.
