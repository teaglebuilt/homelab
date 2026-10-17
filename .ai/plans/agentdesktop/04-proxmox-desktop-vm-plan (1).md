# Proxmox Agent Workstation VM Plan

**MVP workstation:** `linux-agent-01`
**Agent Desktop baseline:** `v0.1.1`

Read `00-agentdesktop-capability-audit.md` first.

## Goal

Create a persistent Linux workstation VM on Proxmox that is suitable for Agent Desktop-managed Claude Code/Codex and remote use by Substrate actors.

The VM is a durable managed endpoint; task workspaces are disposable.

## Ownership

### Crossplane/OpenTofu owns

```text
VM existence
VM ID/name
Proxmox node/template
CPU/RAM/disk/network
cloud-init payload reference
QEMU guest agent
later GPU/PCI settings
```

### cloud-init/Ansible owns

This is the Linux MDM-equivalent layer Agent Desktop expects beneath it:

```text
base OS packages
Agent Desktop v0.1.1 binary installation
release checksum verification
agentdesktop Unix group
systemd service
small controller bootstrap file
optional controller CA trust
non-root task user
SSH/remote transport
Claude Code binary
Codex binary if used
Chromium/Playwright
git/node/python/build tooling
service health/remediation
```

### Agent Desktop owns

```text
endpoint enrollment identity
managed Claude/Codex configuration
MCP/skills inventory
sandbox policy
LLM gateway configuration/credential helpers
session/tool telemetry
```

Cloud-init/Ansible must **not** write Agent Desktop-owned Claude/Codex policy files.

## Persistent vs disposable state

### Preserve across tasks

```text
OS
Agent Desktop installation
/var/lib/agentdesktop or released equivalent
device private key/certificate
Agent Desktop configuration state
installed tool binaries
systemd service
SSH host identity
```

### Reset per task

```text
/workspaces/sessions/<id>
/browser-profiles/<id>
/artifacts/<id>
/tmp/task-<id>
child process tree
localhost dev servers
optional task-specific containers
```

Do not rollback the whole VM to a pre-enrollment snapshot after every task.

## VM class

Initial recommendation:

```text
OS: Ubuntu 24.04 LTS or another Agent Desktop-supported Linux distro
vCPU: 4-8
RAM: 16 GiB
Disk: 80-120 GiB
Network: isolated agent-workstation VLAN/subnet if available
GPU: none for MVP
```

Tune after measuring workloads.

## Template strategy

Prefer a golden Proxmox template for OS/base tooling, but do not bake live Agent Desktop device identity into the reusable template.

Golden template may include:

```text
base OS
qemu-guest-agent
SSH
cloud-init support
common build tools
browser packages
Agent Desktop binary package payload if immutable and not enrolled
```

Per-clone bootstrap handles:

```text
unique hostname/VM identity
Agent Desktop service state directory
controller bootstrap
remote execution identity
human-approved Agent Desktop enrollment
```

Never clone a template that already contains an enrolled Agent Desktop private key/device certificate.

## Linux Agent Desktop packaging

The `v0.1.1` release assets verified in this audit provide raw platform binaries/checksums; do not assume a production Linux package/systemd unit. Live docs may describe newer installer workflows, but the pinned release artifacts are authoritative for this MVP.

Our bootstrap legitimately supplies that missing MDM packaging layer.

Process:

1. download pinned `v0.1.1` Linux artifact from trusted release location;
2. verify published SHA256;
3. install to a controlled path such as `/usr/local/bin/agentdesktop`;
4. create `agentdesktop` Unix group;
5. create state/config directories with restrictive ownership;
6. install systemd unit;
7. write only the small controller bootstrap config;
8. start service;
9. verify local health socket.

## Users and local socket permissions

Create a dedicated non-root task user, for example:

```text
agent-task
```

The Agent Desktop system daemon's local socket may grant group access to:

```text
agentdesktop
```

Decision:

- if `agent-task` must launch Agent Desktop-managed Claude Code/Codex, add it to `agentdesktop`;
- otherwise leave it out;
- never use root for normal agent tasks;
- treat membership in `agentdesktop` as privileged because an authorized local user can request allowed client credentials.

Do not expose the socket over the network.

## Tool installation

Initial tools:

```text
Claude Code
Codex
Chromium/Chrome
Playwright
git
Node.js/pnpm
Python/uv
common compiler/build packages
```

Do **not** install Claude Desktop in the Linux MVP unless a concrete workload requires it. Do not authorize its gateway client ID merely because Agent Desktop supports it.

## Remote execution transport

The VM needs an OS-level transport separate from Agent Desktop.

MVP preference:

```text
SSH with dedicated non-root account
```

Later improvements:

```text
short-lived SSH certs
per-task principals
restricted command wrappers
```

The transport credential is not the Agent Desktop device certificate or gateway JWT.

## Filesystem layout

```text
/workspaces/sessions/<session-id>/
/browser-profiles/<session-id>/
/artifacts/<session-id>/
```

Keep Agent Desktop state outside these cleanup roots.

## Cleanup contract

At task release:

1. terminate process tree;
2. stop task-scoped dev servers/containers;
3. close browser process/profile;
4. export required artifacts;
5. remove workspace/profile/temp paths;
6. verify no sentinel/process remains;
7. mark workstation reusable.

A cleanup failure quarantines task reuse but should not automatically delete/re-enroll the workstation.

## Network policy / segmentation

Workstation should reach only what it requires:

```text
Agent Desktop controller fleet endpoint
existing ai-gateway
DNS/NTP
approved Git/package registries
approved application/test targets
remote-exec control path
```

It should not need direct access to:

```text
Proxmox management API
Crossplane controller/API
Kubernetes API
secret stores
other workstation admin interfaces
```

## Identity implication for shared workstations

All Agent Desktop gateway requests from this workstation carry the **enrolled OIDC user + device ID** regardless of which Substrate actor caused the local tool to run.

Therefore each remote task must record:

```text
actor_id
task/session_id
target Agent Desktop device ID/name
```

This is required for end-to-end attribution.

## VM replacement runbook

Because device identity is local and enrollment is human-approved in `v0.1.1`:

```text
quarantine old workstation
stop new task assignment
offboard/revoke endpoint
destroy/replace VM
bootstrap new VM
human-approved Agent Desktop enrollment
validate config/inventory/gateway
return to service
```

Do not build automatic pool churn around VM destruction until upstream enrollment supports the operational model we need.

## Acceptance criteria

- VM is reproducible from OpenTofu module;
- Agent Desktop v0.1.1 checksum is verified;
- `agentdesktop` group exists and socket permissions are understood;
- systemd service survives reboot;
- `agent-task` is non-root;
- endpoint can be enrolled without storing provider API keys;
- Claude Code/Codex binaries are detected by Agent Desktop;
- Agent Desktop-managed settings are not prewritten by cloud-init/Ansible;
- browser automation can run under task user;
- task cleanup preserves Agent Desktop identity/state;
- workstation cannot directly administer Proxmox or Kubernetes.
