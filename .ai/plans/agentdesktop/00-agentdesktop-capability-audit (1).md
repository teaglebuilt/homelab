# Agent Desktop Capability Audit

**Purpose:** establish what Agent Desktop already owns before implementing any homelab-specific component, and prevent the project from rebuilding upstream capabilities.

**Reviewed:** 2026-10-14 against:

- the current Agent Desktop documentation;
- the latest signed release, **`v0.1.1`**;
- the current `agentdesktop-dev/agentdesktop` `main` branch where useful for forward-looking comparison.

## Baseline rule: released behavior wins

Production plans must target a reviewed, signed Agent Desktop release rather than implicitly depending on `main`.

As of this audit:

```text
latest release: v0.1.1
controller image: ghcr.io/agentdesktop-dev/agentdesktop-controller:v0.1.1
controller chart: oci://ghcr.io/agentdesktop-dev/charts/agentdesktop-controller:0.1.1
```

Features visible on `main` but absent from `v0.1.1` are **future options**, not MVP dependencies.

Example: `main` has `controller.deviceAuthorization` for OAuth 2.0 Device Authorization Grant enrollment on headless hosts. `v0.1.1` does not. Even when released, device authorization is still human-approved enrollment, not zero-touch MDM enrollment.

## Rule for every implementation phase

Before adding code or a Kubernetes resource, classify it as one of:

1. **Agent Desktop capability — use upstream.**
2. **Endpoint/MDM capability — use the normal machine-management layer.**
3. **Homelab integration gap — custom work is justified.**

Do not build a homelab replacement for category 1.

## Capability matrix

| Capability | `v0.1.1` | Owner / decision |
|---|---|---|
| Tool/version discovery | Yes | Agent Desktop |
| Periodic inventory refresh | Yes; `inventoryInterval`, default `15m` | Agent Desktop |
| MCP/skills inventory | Yes for supported tools | Agent Desktop |
| Local model inventory | Yes | Agent Desktop |
| Claude Code managed config | Yes | Agent Desktop |
| Claude Desktop managed config | Yes; system mode | Agent Desktop |
| Codex managed config | Yes | Agent Desktop |
| OpenCode managed config | Yes | Agent Desktop |
| Grok Build managed config | Yes | Agent Desktop |
| Shared Claude/Codex sandbox intent | Yes | Agent Desktop |
| Controller-distributed desired policy | Yes | Agent Desktop |
| Drift repair | Yes on config delivery/reconnect; periodic `daemon.reconcileInterval` is `main`-only, not `v0.1.1` | Agent Desktop; do not depend on periodic tick in MVP |
| Device enrollment / device certificate | Yes | Agent Desktop |
| Zero-touch managed enrollment | **No** | Do not invent around this in MVP |
| Headless Device Authorization enrollment | `main`, not `v0.1.1` | Future option after release validation |
| Short-lived gateway JWT | Yes | Agent Desktop Controller |
| Session/tool telemetry | Yes, selected hooks/events | Agent Desktop |
| Fleet inventory/status UI | Yes | Agent Desktop |
| VM provisioning | No | Crossplane/OpenTofu + Proxmox |
| Linux production package/systemd unit | No | Homelab MDM-equivalent bootstrap |
| Remote shell/process execution | No | Existing remote transport / MCP |
| Arbitrary remote file transfer | No | Existing remote transport / MCP |
| Remote browser/computer control | No | Existing browser/remote execution tooling |
| External actor-to-desktop scheduling/leases | No | Fixed mapping first; Kubernetes Lease later |

## What Agent Desktop already provides

Agent Desktop is the AI-tool-aware endpoint management plane.

Use it for:

```text
endpoint enrollment
user + device identity
device private key + controller-issued certificate
fleet connectivity/inventory
AI tool discovery
MCP/skills/local-model inventory supported by the installed release
controller-distributed desired configuration
configuration reconciliation + drift repair
Claude Code managed configuration
Claude Desktop managed configuration
Codex managed configuration
OpenCode managed configuration
Grok Build managed configuration
shared sandbox intent translated into Claude Code/Codex native policy
short-lived inference-gateway credentials
selected session/tool-use telemetry
fleet management UI
```

Do not create another service/database/UI for these concerns.

## Managed gateway configuration is per program

A top-level `llmGateway` does **not** by itself mean every program should be assumed to use it.

For each managed client in the MVP, configure its documented `useLlmGateway` field explicitly.

Example:

```yaml
llmGateway:
  url: https://ai-gateway.example.internal
  authentication:
    type: controllerJwt
    audience: agentgateway
    allowedClientIds:
      - claude-code
      - codex

programs:
  claudeCode:
    useLlmGateway: true

  codex:
    useLlmGateway: true
```

Only authorize client IDs for software actually used on the workstation.

Do not put `claude-desktop`, `opencode`, or future clients into `allowedClientIds` merely because Agent Desktop supports them.

## Gateway identity boundary

Agent Desktop gateway JWTs provide useful identity and attribution, but they are not a Substrate workload identity system.

Current JWT context includes:

```text
sub       = enrolled OIDC user
act.sub   = Agent Desktop device ID
client_id = requested/allowed client label
```

It does **not** contain the kagent/Agent Substrate actor or task/session identity.

Therefore:

- do not claim that Actor identity automatically propagates into model requests;
- correlate Actor/task -> workstation/device in the remote-execution telemetry layer;
- use Agent Desktop user/device/client claims for endpoint/model attribution;
- treat cross-plane correlation as a separate concern.

### `client_id` is not process attestation

Agent Desktop explicitly documents/source-comments that local transport permissions authenticate the local user boundary, **not the calling executable**. An authorized local process can request an allowed client label.

Therefore:

- `client_id` is useful for routing, policy, logging, and attribution;
- it is **not** cryptographic proof that Claude Code/Codex was the process that requested the credential;
- do not make high-impact authorization depend only on `client_id`;
- keep `allowedClientIds` minimal;
- protect which local OS users can access the Agent Desktop local API.

## Local API access is an endpoint security boundary

The Agent Desktop daemon local API is not a public TCP service. On Unix it uses a local socket.

In `v0.1.1`, a root/system daemon expects the local group:

```text
agentdesktop
```

and grants that group access to the daemon socket (`0660`). A user-mode daemon uses owner-only access.

For our Linux workstations:

```text
root/system Agent Desktop daemon
        │
        ▼
agentdesktop Unix group
        │
        └── only OS users authorized to use managed AI tools
```

If the remote task execution user must run Claude Code/Codex through Agent Desktop-managed credential helpers, explicitly add that task user to the `agentdesktop` group and treat that membership as a privileged local capability.

Do not make the socket world-readable and do not expose it over TCP.

## Agent Desktop's local API is not a remote-execution API

The endpoint daemon exposes a **local** API over its Unix socket / Windows named pipe.

The released API includes management/credential routes such as:

```text
/v1/health
/v1/daemon-info
/v1/config
/v1/effective-config
/v1/remote-config
/v1/discovery
/v1/enrollment
/v1/logout
/v1/telemetry
/v1/llm-gateway/credential
```

There is no released/documented route for:

```text
exec command
read/write arbitrary task file
start arbitrary process
start a Claude/Codex task remotely
browser navigate/click/type
screen capture
mouse/keyboard control
```

The local API should remain local. Do **not** expose the Agent Desktop socket over the network to create a remote-control mechanism.

## Agent Desktop controller is not a job dispatcher

The controller owns:

```text
OIDC enrollment
device certificates
configuration distribution
inventory
selected telemetry
gateway JWTs
fleet UI
```

It is not documented as owning:

```text
assign job to endpoint
reserve endpoint for actor
execute process on endpoint
stream stdout/stderr
control browser/UI
transfer arbitrary task files
```

Therefore a separate execution transport is justified **only because the agent brain stays on Agent Substrate while the computer is a different Proxmox VM**.

If the agent brain itself ran on that VM, this cross-machine execution layer could disappear.

## MCP boundary

Agent Desktop provides **inventory** of MCP configuration for supported tools. Do not assume it provides a fleet-wide MCP execution fabric or central MCP proxy.

Agent Desktop documentation also keeps MCP traffic separate from the inference-gateway path.

Therefore:

- use Agent Desktop for MCP/skills inventory on workstations;
- use its managed program configuration only for settings explicitly supported by the pinned release;
- use kagent/KMCP for the Kubernetes agent's MCP tool fabric;
- do not duplicate MCP inventory in a custom fleet database;
- a Remote Execution MCP server may exist as a **kagent tool**, but it is not an Agent Desktop replacement.

## Sandbox boundary

Agent Desktop already exposes shared sandbox intent:

```yaml
sandbox:
  network:
    allowedDomains: []
  filesystem:
    writable: []
    denied: []
```

It translates this into native sandbox configuration for supported developer tools such as Claude Code and Codex.

Therefore the homelab must **not** create a second Claude/Codex sandbox configuration layer.

Raw SSH commands, Playwright helpers, and other processes started outside those managed AI clients are not automatically governed by their native Agent Desktop-managed sandbox. The external execution transport still needs OS-level authorization and network controls.

## Telemetry boundary

Use Agent Desktop telemetry for the events it already owns, where supported by the installed client/hook integration:

```text
session.new
tool.use
tool.use.input  # only after privacy review
```

Do not assume every managed client produces identical telemetry coverage.

The cross-machine execution layer should emit only complementary data:

```text
Substrate actor/task/session ID
remote target / Agent Desktop device correlation
remote execution duration/result
browser helper result
lease/acquisition result (later)
cleanup/quarantine result
```

Do not recreate Agent Desktop's fleet/session/tool telemetry pipeline.


## Periodic drift-repair release boundary

Current `main` and the live production documentation describe `daemon.reconcileInterval` for periodic re-application of managed configuration. The `v0.1.1` released schema does **not** include that field.

Therefore the MVP must rely on released mechanisms only:

```text
controller configuration delivery
controller reconnect/restart
explicit daemon restart during pilot/repair
```

Do not configure `daemon.reconcileInterval` until it appears in the reviewed release schema. When upgrading, re-run this audit and then enable it if desired.

## Inventory refresh boundary

`v0.1.1` includes `inventoryInterval` with a default of `15m`.

Do not build a custom rescan service.

Current production documentation still recommends restarting the daemon after installing/removing developer tools during pilot validation, so use a deterministic restart in rollout tests until the pinned release behavior is validated in our environment. Periodic inventory refresh remains the normal steady-state mechanism.

## Machine deployment boundary

Agent Desktop explicitly leaves package/device deployment to an MDM/endpoint-management layer.

For this homelab:

```text
Crossplane/OpenTofu -> creates Proxmox machine
cloud-init/Ansible  -> Linux MDM-equivalent bootstrap
Agent Desktop       -> AI-tool-aware management after installation
```

Cloud-init/Ansible should install binaries/services and the small Agent Desktop bootstrap file. It must not independently manage Claude/Codex policy files that Agent Desktop owns.

### Endpoint packaging gap in the pinned release

The current production docs describe macOS/Windows installers and a Linux packaging gap, but the actual `v0.1.1` GitHub release assets visible in this audit are raw platform binaries plus checksums rather than PKG/MSI artifacts. Because **released behavior/artifacts win**, do not assume a production installer exists for any OS until the pinned release assets are verified.

For our Linux MVP, the conclusion is unchanged: our bootstrap legitimately owns:

```text
pinned release binary installation
agentdesktop Unix group creation
systemd unit
small controller bootstrap
optional controller CA installation
service health/remediation
```

This is endpoint-management work, not a reimplementation of Agent Desktop.

## Controller deployment gaps we must account for, not rebuild

Current production documentation identifies several upstream operational boundaries:

```text
single controller replica is the documented/default topology
admin UI is loopback-only and has no separate app-auth layer
fleet TLS/mTLS must terminate at the controller
existingConfigSecret currently needs an overlay when controller.yaml references daemon.yaml
device CA and gateway signing key rotation have no overlapping-key workflow
```

Our Kubernetes deployment may add platform overlays such as NetworkPolicy, readiness probes, PDB, Secret mounting, and L4 exposure. Those are deployment hardening around Agent Desktop, not replacements for its control plane.

## Enrollment boundary

For the released MVP (`v0.1.1`):

```text
enrollment = human-approved OIDC browser flow
zero-touch enrollment = unavailable
```

Preserve the VM's machine-local Agent Desktop identity after enrollment.

Current `main` adds a `controller.deviceAuthorization` option for headless hosts. After it ships in a reviewed release and the chosen IdP is confirmed to support RFC 8628, we can replace “browser on the VM” with “approve a verification code elsewhere.” This still does not make enrollment zero-touch.

## Proxmox boundary

Agent Desktop does not provision or reconcile Proxmox VMs.

Crossplane/OpenTofu remains justified for:

```text
VM existence
clone/template selection
CPU/RAM/disk/network
cloud-init inputs
GPU/PCI configuration later
```

It should not model Agent Desktop fleet state beyond infrastructure readiness.

## Scheduling boundary

Agent Desktop fleet inventory does not currently provide a lease/scheduler API for external Substrate actors.

Do not build scheduling until there is contention.

MVP:

```text
fixed target mapping
```

MVP+ only when required:

```text
Kubernetes coordination.k8s.io/v1 Lease
```

No custom `DesktopSession` CRD or broker database unless standard Leases prove insufficient.

## Final ownership matrix

| Capability | Owner |
|---|---|
| Agent reasoning/runtime | Agent Substrate / AgentHarness |
| Actor/task identity | Agent Substrate / kagent |
| AI endpoint identity | Agent Desktop |
| AI tool discovery/inventory | Agent Desktop |
| MCP/skills/local-model inventory | Agent Desktop |
| AI tool desired config | Agent Desktop |
| Claude/Codex sandbox policy | Agent Desktop |
| Model runtime credentials | Agent Desktop + existing AI gateway |
| Endpoint model attribution (user/device/client) | Agent Desktop + gateway |
| Actor -> endpoint correlation | remote execution telemetry |
| Session/tool telemetry | Agent Desktop where supported |
| VM infrastructure lifecycle | Crossplane/OpenTofu + Proxmox |
| Linux daemon/package bootstrap | cloud-init/Ansible as MDM equivalent |
| Cross-machine task execution | existing remote transport/MCP; custom only if needed |
| Browser automation outside local agent tool | Playwright/existing browser MCP |
| Desktop allocation | fixed mapping first; Kubernetes Lease later |

## Sources

- https://agentdesktop.dev/docs/
- https://agentdesktop.dev/docs/getting-started/managed/
- https://agentdesktop.dev/docs/operations/production/
- https://agentdesktop.dev/docs/operations/mdm-integrations/
- https://github.com/agentdesktop-dev/agentdesktop/releases/tag/v0.1.1
- https://github.com/agentdesktop-dev/agentdesktop/blob/v0.1.1/schema/daemon-config.md
- https://github.com/agentdesktop-dev/agentdesktop/blob/v0.1.1/crates/agent/src/api.rs
- https://github.com/agentdesktop-dev/agentdesktop/blob/v0.1.1/crates/agent/src/daemon.rs
- https://github.com/agentdesktop-dev/agentdesktop/blob/main/schema/daemon-config.md
