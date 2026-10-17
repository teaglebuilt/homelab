# Architecture and Component Boundaries

**Agent Desktop baseline:** `v0.1.1`

## Objective

Allow kagent/AgentHarness workloads running on the existing Agent Substrate deployment to use full Proxmox workstations as external computers **without rebuilding capabilities already supplied by Agent Desktop**.

Read `00-agentdesktop-capability-audit.md` before implementing this plan.

## Existing runtime: do not rebuild it

`main` already contains the required agent runtime foundation:

```text
platform/ai/kubernetes/substrate/
platform/ai/kubernetes/harness/claude.yaml
platform/ai/kubernetes/harness/kagent.yaml
```

The Harnesses use the existing `kagent-default` Substrate WorkerPool and S3 snapshots. This project consumes that runtime.

## Four ownership planes

### 1. Agent runtime plane

```text
kagent / AgentHarness
        │
        ▼
Agent Substrate Actor
```

Owns:

```text
reasoning
agent/session state
actor/task identity
tool selection
Substrate scheduling/snapshot lifecycle
```

### 2. Endpoint management plane

```text
Agent Desktop Controller
        │ fleet mTLS
        ▼
Agent Desktop daemon on VM
```

Owns:

```text
OIDC enrollment
user + device identity
device certificate
fleet connectivity/inventory
AI tool discovery
MCP/skills/model inventory where supported
desired configuration distribution
managed program reconciliation
Claude Code/Codex sandbox intent
gateway credential helper
selected session/tool telemetry
fleet UI
```

Do not duplicate this plane.

### 3. Cross-machine execution plane

Because the Substrate actor and workstation are different machines, one bridge remains necessary:

```text
Substrate Actor
    │ actor/task/session identity
    │ MCP
    ▼
remote execution tool
    │ SSH or other audited transport
    ▼
non-root task user on VM
    │
    ├── launches Agent Desktop-managed Claude Code/Codex
    └── launches Playwright/browser helper
```

Agent Desktop does not provide controller-to-endpoint arbitrary command, file, browser, or job-dispatch APIs in `v0.1.1`.

The Agent Desktop local socket remains local and must not be turned into a network control channel.

### 4. Machine infrastructure plane

```text
ArgoCD/Kustomize
      │
      ▼
Crossplane v2
      │
      ▼
provider-opentofu Workspace
      │
      ▼
existing Proxmox HCL module
      │
      ▼
bpg/proxmox
      │
      ▼
Proxmox VM
```

Cloud-init/Ansible performs Linux package/service/bootstrap work equivalent to the MDM layer Agent Desktop expects underneath it.

## Target architecture

```text
                         KUBERNETES

                  kagent / AgentHarness
                          │
                          ▼
                    Agent Substrate
                          │
                    actor/task ID
                          │ MCP
                          ▼
                Remote Execution Tool
              (existing implementation first)
                          │
                 fixed target initially
              Kubernetes Lease only later
                          │
──────────────────────────┼──────────────────────────
                          │
                      Proxmox VM
                          │
                    task OS user
                          │
                   Agent Desktop
                          │
           ┌──────────────┼─────────────┐
           │              │             │
       Claude Code      Codex        Browser
           │              │             │
           └──────────────┼─────────────┘
                          ▼
              existing ai-gateway


                    MANAGEMENT PLANE

 Crossplane/provider-opentofu ──► Proxmox VM infrastructure
 cloud-init/Ansible ────────────► Linux package/service/bootstrap

 Agent Desktop Controller ──────► endpoint identity
                                  fleet inventory
                                  AI tool configuration
                                  supported MCP/skills inventory
                                  sandbox policy
                                  telemetry
                                  model credentials
```

## Identity boundary

Agent Desktop and Substrate identify different things.

### Substrate identity

```text
actor ID
task/session ID
Harness/agent identity
```

### Agent Desktop / gateway identity

Current Agent Desktop gateway JWT context is approximately:

```text
sub       = enrolled OIDC user
act.sub   = Agent Desktop device ID
client_id = requested allowed client label
```

The Actor/task identity is **not** automatically included in that JWT.

Therefore:

1. remote-execution telemetry must record `actor/task/session -> Agent Desktop device`;
2. gateway telemetry provides endpoint attribution (`user/device/client`), not actor attribution;
3. dashboards can correlate the two planes through target device + time/task metadata;
4. do not claim cryptographic end-to-end actor identity until a separate workload-identity mechanism is added.

### `client_id` boundary

Agent Desktop's local transport permissions authenticate the local user boundary, not the calling process. `client_id` is an asserted label useful for routing/auditing; it is not process attestation.

Keep `allowedClientIds` minimal and never make high-impact authorization depend only on `client_id`.

## Agent Desktop local socket boundary

For a root/system daemon on Unix, `v0.1.1` expects the local group:

```text
agentdesktop
```

The socket may be accessible to that group (`0660`).

Design:

```text
root:agentdesktop Agent Desktop daemon/socket
                │
                └── task user is a member only if it must run managed AI clients
```

Group membership is a privileged endpoint capability. Do not expose the socket over TCP and do not make it world-readable.

## Ownership matrix

| Concern | Owner | Do not build |
|---|---|---|
| Agent reasoning/session lifecycle | Agent Substrate | second agent runtime |
| Actor/task identity | Agent Substrate / kagent | repurpose Agent Desktop device identity |
| VM create/update/delete | Crossplane + provider-opentofu | Proxmox custom controller |
| Hypervisor execution | Proxmox | nested VM scheduler |
| Linux package/service bootstrap | cloud-init/Ansible | AI policy reconciliation |
| Endpoint enrollment/device identity | Agent Desktop | custom device identity service |
| Fleet inventory/config status | Agent Desktop | custom fleet database/UI |
| Tool/MCP/skills inventory | Agent Desktop where supported | duplicate fleet inventory |
| Claude/Codex/OpenCode managed settings | Agent Desktop | cloud-init-written tool policy |
| Claude/Codex sandbox intent | Agent Desktop | second tool sandbox layer |
| Model credentials | Agent Desktop + existing AI gateway | raw provider keys on VM |
| Endpoint model attribution | Agent Desktop + gateway | fake actor identity in JWT |
| Actor -> endpoint correlation | remote-execution telemetry | duplicate endpoint fleet service |
| Agent Desktop session/tool telemetry | Agent Desktop | duplicate tool event collector |
| Cross-machine command/browser transport | existing remote tooling; thin adapter only if needed | expose Agent Desktop socket remotely |
| Exclusive desktop allocation | fixed mapping, then Kubernetes `Lease` | broker DB/CRD in MVP |
| VM task-data cleanup | execution layer / OS | rollback Agent Desktop identity |

## Why no custom Desktop Broker in the MVP

Agent Desktop already provides most endpoint/fleet functions a broker would otherwise duplicate. The missing functions are only:

```text
cross-machine execution
exclusive target reservation when contention appears
```

Use fixed mappings first. Add standard Kubernetes `Lease` resources only when actual concurrency requires them.

## Persistent identity and reset strategy

Released Agent Desktop enrollment is human-approved and the device private key/state is local.

Preserve:

```text
/var/lib/agentdesktop (or equivalent endpoint state)
device private key/certificate
OS identity
installed tool binaries
Agent Desktop-managed settings
```

Reset only task state:

```text
worktree/workspace
browser profile
downloads/temp data
build artifacts
session processes
```

A VM replacement is an offboard/re-enroll event until Agent Desktop ships a reviewed zero-touch enrollment mechanism.

## Gateway decision

Reuse the repository's current `ai-gateway` / `agentgateway`.

For each client used on the workstation, Agent Desktop policy must explicitly set `useLlmGateway: true`. Do not assume the top-level gateway automatically applies to every supported client.

Initial clients:

```text
claude-code
codex
```

Do not pre-authorize `claude-desktop`, `opencode`, or other clients until they are actually part of the workstation class.

## First end-to-end proof

```text
existing Claude Harness on Substrate
        │ actor/task ID
        ▼
remote execution tool
        │ records actor -> target mapping
        ▼
linux-agent-01
        │
        ├── Agent Desktop v0.1.1 enrolled/managed
        ├── non-root task user
        ├── Claude Code/Codex managed by Agent Desktop
        └── Chromium/Playwright
                │
                ▼
        existing ai-gateway
```
