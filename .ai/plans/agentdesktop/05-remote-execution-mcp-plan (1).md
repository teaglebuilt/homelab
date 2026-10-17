# Remote Execution MCP / Cross-Machine Control Plan

## Decision after Agent Desktop capability audit

**A cross-machine execution layer is still required.**

Agent Desktop `v0.1.1` provides a local endpoint-management API but does **not** provide:

```text
remote command execution
remote arbitrary file transfer
remote process lifecycle/job dispatch
remote browser click/type/navigation
controller -> endpoint task assignment
external actor -> endpoint scheduling
```

Therefore this plan is justified, but it must remain narrow and must not duplicate Agent Desktop.

## Rule: reuse before build

Do not start by writing a `desktopd` daemon or a large Desktop Broker.

Evaluate in order:

1. existing audited SSH MCP / remote-exec tooling already compatible with kagent/KMCP;
2. normal SSH invoked by a thin MCP adapter;
3. existing Playwright/browser MCP/helper running on the workstation;
4. a small custom adapter only for remaining authorization, target-selection, correlation, or cleanup gaps.

Do not add Fleet/Coder or another management product solely to obtain command execution unless the reuse spike proves that is materially better.

## What Agent Desktop continues to own

Even when execution is initiated remotely, Agent Desktop still owns:

```text
managed Claude/Codex settings
sandbox intent inside supported AI clients
gateway credential helper
endpoint user/device identity
tool/MCP/skills inventory
configuration state
selected session/tool telemetry
```

The execution layer simply launches/controls programs on a different machine.

## Strict boundary: do not remote Agent Desktop's local API

Do **not**:

```text
forward /run/.../agentdesktop.sock over TCP
turn the local daemon API into a shell
add arbitrary exec routes to Agent Desktop
have the remote-exec service mint model JWTs directly
reuse the Agent Desktop device certificate as SSH auth
```

The remote execution layer should launch the managed client normally:

```text
Substrate actor
    │
    ▼
remote exec
    │
    ▼
claude / codex process on workstation
    │
    ▼
Agent Desktop credential helper/local socket
    │
    ▼
existing ai-gateway
```

This preserves upstream ownership of model credentials.

## Local user model

Use a dedicated non-root OS account, e.g.:

```text
agent-task
```

If that user must launch Agent Desktop-managed Claude/Codex, it may need membership in the local `agentdesktop` Unix group.

That membership is privileged because Agent Desktop's local transport authenticates the user boundary, not the executable. An allowed local user can request an allowed `client_id`.

Therefore:

- keep the task account dedicated;
- keep `allowedClientIds` minimal;
- do not share the account with unrelated services;
- do not use `client_id` as process attestation.

## Actor identity and correlation

Remote execution is the place where Substrate identity must be joined to endpoint identity.

Each task invocation should carry/record:

```text
actor_id
agent/harness name
task/session_id
target logical workstation
target Agent Desktop device ID/name
transport request ID
```

Agent Desktop gateway JWTs do not currently include the actor/task identity. Do not fake it by overloading `client_id`.

## MVP target selection

Start with explicit configuration:

```text
linux-agent-01 -> DNS/IP/SSH target -> Agent Desktop device identifier
```

No fleet database.

Agent Desktop remains authoritative for endpoint-management inventory; the execution configuration stores only transport-specific addressing/capability metadata needed to reach the target.

## Execution tool surface

If existing tools do not provide a clean MCP surface, a thin adapter should expose the minimum required operations.

Example:

```text
desktop.health(target)
desktop.exec(target, command, cwd?, timeout?)
desktop.upload(target, source, destination)
desktop.download(target, source, destination)
desktop.cleanup(target, session_id)
```

Browser operations should preferably come from an existing Playwright implementation rather than being reimplemented:

```text
browser.start
browser.navigate
browser.snapshot
browser.click
browser.type
browser.close
```

Do not expose Proxmox lifecycle operations from this MCP service.

## Command execution requirements

For any SSH/exec implementation:

```text
non-root account
bounded command duration
cancellation
stdout/stderr byte limits
exit status
explicit cwd
workspace root validation
no arbitrary sudo by default
process-group cleanup
audit record
```

## File operations

Prefer standard SSH/SFTP/SCP or an existing audited file-transfer primitive.

Restrict task operations to roots such as:

```text
/workspaces/sessions/<session-id>
/artifacts/<session-id>
```

Do not expose arbitrary Agent Desktop state paths.

## Browser control

Prefer this order:

1. local Playwright/browser MCP on the workstation;
2. accessibility/DOM structured actions;
3. screenshots/vision;
4. native GUI automation only when the application requires it.

Do not broadly expose Chrome DevTools ports to the network.

## Sandbox boundary

Agent Desktop sandbox policy governs supported commands/tool behavior **inside managed Claude Code/Codex**.

Raw SSH commands or browser helpers are outside that sandbox.

Use OS/network controls for the execution layer:

```text
non-root user
filesystem ownership/ACLs
network segmentation
resource limits
sudo restrictions
```

This is complementary, not duplicate sandboxing.

## Telemetry boundary

### Agent Desktop telemetry

Owns selected AI-client events such as:

```text
session.new
tool.use
tool.use.input (only if explicitly enabled)
```

### Remote execution telemetry

Emit only complementary data:

```text
actor/task/session -> target device mapping
transport duration/result
command/process result
browser-helper result
cleanup/quarantine result
lease result later
```

Do not duplicate Claude/Codex `tool.use` events.

## Authentication

### Actor -> MCP

Reuse kagent/KMCP authentication/authorization.

### MCP -> workstation

Prefer:

1. short-lived SSH certificates;
2. dedicated server-held pilot key if necessary;
3. credential never exposed to the actor prompt/context.

Keep remote execution credentials separate from Agent Desktop device certificates and model JWTs.

## Scheduling is deferred

MVP:

```text
explicit target = linux-agent-01
```

MVP+ only after contention:

```text
coordination.k8s.io/v1 Lease
```

No custom `DesktopSession` CRD or broker database unless standard Lease semantics are proven insufficient.

## Failure states

Execution-specific states only:

```text
TargetUnavailable
RemoteAuthenticationFailed
CommandTimeout
CommandFailed
BrowserSessionMissing
CleanupFailed
LeaseConflict  # later
```

A cleanup failure quarantines task reuse but does not automatically mutate Agent Desktop enrollment/config state.

## Reuse spike checklist

Before writing custom code, answer:

- Is there already an SSH MCP compatible with our trust requirements?
- Can kagent/KMCP invoke it with actor context?
- Does it support bounded exec and file transfer?
- Can an existing Playwright MCP run **on the target workstation**, not inside the Substrate actor?
- Can target/device correlation be added through metadata without modifying Agent Desktop?
- Can cleanup be implemented with existing OS primitives?

Only the missing pieces become custom code.

## Acceptance test

From an existing Harness on Substrate:

```text
1. actor selects linux-agent-01
2. remote layer records actor/task -> Agent Desktop device mapping
3. run a simple bounded command as agent-task
4. create task workspace
5. invoke Agent Desktop-managed Claude Code or Codex locally
6. client obtains its own gateway credential through Agent Desktop
7. use Chromium through Playwright
8. collect artifact
9. cleanup task state
10. verify Agent Desktop remains enrolled/config Applied
11. verify next task cannot see previous task workspace/browser state
```

This proves the actual missing integration: **a Kubernetes actor controlling a separate Agent Desktop-managed workstation without replacing Agent Desktop's management functions.**
