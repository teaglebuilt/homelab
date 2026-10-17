# Agent Desktop Managed Deployment Plan

**MVP target:** Agent Desktop `v0.1.1`
**Rule:** use released behavior; `main`-only features are future options.

Read `00-agentdesktop-capability-audit.md` first.

## Goal

Deploy the upstream Agent Desktop controller on Kubernetes and enroll persistent Proxmox Linux workstations so Agent Desktop owns endpoint identity, AI-tool configuration, inventory, sandbox policy, gateway credentials, and supported telemetry.

## What we are not building

Do not implement custom versions of:

```text
fleet controller UI/device DB
device PKI
device certificate enrollment
Claude/Codex/OpenCode settings reconciliation
MCP/skills inventory
Claude/Codex sandbox configuration
model credential helper
gateway JWT issuer
Agent Desktop session/tool telemetry
```

## Release gate

Pin:

```text
controller image: ghcr.io/agentdesktop-dev/agentdesktop-controller:v0.1.1
controller chart: oci://ghcr.io/agentdesktop-dev/charts/agentdesktop-controller:0.1.1
endpoint binary: v0.1.1 release artifact + verified SHA256
```

Before any future version bump:

1. compare release notes;
2. compare released daemon schema/API to `main`;
3. rerun `00-agentdesktop-capability-audit.md`;
4. update the plans only after behavior is released and validated.

`controller.deviceAuthorization` and `daemon.reconcileInterval` currently visible on `main`/live docs are **not** MVP dependencies because they are absent from the `v0.1.1` released schema.

## Kubernetes controller architecture

```text
L4 LoadBalancer / TCP passthrough
              │
              ▼
   Agent Desktop controller
       fleet :8443  <- TLS/mTLS terminates here
       admin :8080  <- loopback/private only
              │
              ▼
          PostgreSQL
```

Production requirements:

- fleet TLS/mTLS must terminate at the controller so it can see device certificates;
- do not put normal L7 TLS termination in front of the fleet API;
- keep admin UI loopback/private; use Kubernetes access/port-forward rather than public ingress;
- use dedicated device CA;
- use separate gateway JWT signing key;
- use durable PostgreSQL;
- store secrets through existing SOPS/External Secret conventions as appropriate.

## Chart overlay requirements

Current production guidance has deployment gaps that should be handled as Kubernetes packaging overlays, not by forking the controller logic.

Account for:

```text
mount controller.yaml
mount daemon.yaml when referenced by controller config
readiness/liveness suitable for the environment
NetworkPolicy
PDB if/when HA topology becomes supported/useful
provider-specific Service annotations only when needed
```

The documented controller topology is effectively a single controller replica today; do not claim validated HA that upstream does not claim.

## Controller configuration

Conceptual controller configuration:

```yaml
fleetListen: 0.0.0.0:8443
adminListen: 127.0.0.1:8080
databaseUrl: ${AGENTDESKTOP_DATABASE_URL}
tls: /etc/agentdesktop/tls
allowInsecureDev: false

oidc:
  issuer: https://<oidc-issuer>/
  clientId: agentdesktop
  redirectUri: http://127.0.0.1:51327/callback

gatewayJwt:
  privateKey: /etc/agentdesktop/tls/gateway-jwt-key.pem
  issuer: agentdesktop-controller
  keyId: agentdesktop
  lifetime: 15m

daemonConfig:
  path: /etc/agentdesktop/config/daemon.yaml
```

Use actual schema from the pinned release when implementing.

## Distributed daemon policy

For the first Linux workstation, keep the policy deliberately narrow.

Conceptual `daemon.yaml`:

```yaml
inventoryInterval: 15m

llmGateway:
  url: https://<existing-ai-gateway>/
  authentication:
    type: controllerJwt
    audience: agentgateway
    allowedClientIds:
      - claude-code
      - codex

programs:
  claudeCode:
    useLlmGateway: true
    companyAnnouncements:
      - Managed by Agent Desktop

  codex:
    useLlmGateway: true
    managedConfig: {}

sandbox:
  network:
    allowedDomains:
      - github.com
      - api.github.com
      - registry.npmjs.org
  filesystem:
    writable:
      - /workspaces
    denied:
      - /root
      - /home/agent-task/.ssh

telemetry:
  events:
    - session.new
    - tool.use
```

Notes:

- exact settings must validate against `v0.1.1` schema;
- `useLlmGateway: true` is explicit per client;
- do not add `claude-desktop`, `opencode`, etc. to `allowedClientIds` until those clients are part of the workstation class;
- enable `tool.use.input` only after privacy review because it may include source/prompt/tool arguments.

## Enrollment and identity decision

`v0.1.1` enrollment is human-approved OIDC. The daemon generates the device private key locally, submits a CSR, and receives its device certificate.

The team must explicitly decide which OIDC principal enrolls pooled workstations:

### Option A — operator's personal OIDC account

Simple for pilot, but all gateway JWTs from that workstation are attributed to that enrolled user.

### Option B — dedicated workstation/service OIDC principal

Cleaner attribution for shared agent workstations if the IdP and Agent Desktop flow support this operationally, but still requires human-approved enrollment in the released flow.

Do not pretend the Substrate actor becomes the JWT `sub`. It does not.

Record the chosen enrollment identity in the architecture ADR.

## Endpoint daemon local API security

For a system/root Linux daemon, create the `agentdesktop` Unix group as required by the released daemon.

The local socket is a privileged boundary:

```text
root:agentdesktop
mode 0660
```

Only OS users authorized to run Agent Desktop-managed clients should be members.

The remote task user may be added only if it must launch Claude Code/Codex and therefore reach their credential helper path.

Do not expose the local API over TCP.

## Gateway identity semantics

Current Agent Desktop gateway JWTs provide endpoint/user context:

```text
sub       = enrolled OIDC user
act.sub   = device ID
client_id = allowed requested label
```

`client_id` is not executable attestation. Treat it as an allowed label inside the local-user boundary.

Security implications:

- keep allowed client list small;
- do not authorize destructive operations solely on `client_id`;
- do not claim actor identity is present in the token;
- correlate actor -> device through remote-execution telemetry.

## MCP/skills boundary

Use Agent Desktop for **inventory** of workstation MCP/skills and managed settings actually supported by the pinned release.

Do not assume Agent Desktop is a fleet-wide MCP proxy or the Kubernetes agent's MCP fabric.

kagent/KMCP remains the Substrate actor's tool fabric.

## Drift repair in the pinned release

Do not configure `daemon.reconcileInterval` in the `v0.1.1` MVP. It is present on current `main`/live docs but absent from the released `v0.1.1` schema.

For MVP repair/validation use:

```text
controller config delivery/reconnect
explicit daemon restart when deterministic re-apply is required
```

When a later reviewed release includes `daemon.reconcileInterval`, add it as an optional policy setting after validation.

## Inventory behavior

`v0.1.1` includes `inventoryInterval` (default `15m`). Do not build a custom rescanner.

For deterministic rollout tests after installing/removing tools:

1. restart the daemon if needed;
2. verify `agentdesktop discover` locally;
3. verify controller inventory update;
4. then validate periodic refresh in steady state.

## Offboarding / replacement

Treat full VM replacement as endpoint replacement.

Procedure:

1. stop task allocation;
2. remove/revoke endpoint in Agent Desktop according to upstream workflow;
3. invalidate access at IdP/MDM boundary if required;
4. remember already-issued short-lived gateway JWTs are not retroactively erased instantly;
5. destroy VM only after offboarding is complete;
6. enroll replacement as a new device.

## Acceptance criteria

- controller/DB/keys are deployed from pinned release;
- fleet mTLS terminates at controller;
- admin UI is not exposed publicly;
- `linux-agent-01` appears online in fleet UI;
- tool inventory includes the installed clients;
- Claude Code and Codex configuration reports Applied/unchanged as expected;
- only `claude-code` and `codex` are allowed gateway client IDs for MVP;
- both clients explicitly use the gateway;
- provider API keys are absent from workstation;
- unauthorized local user cannot access Agent Desktop socket;
- authorized task user can run managed client when intended;
- disallowed `client_id` cannot obtain an Agent Desktop gateway credential;
- Substrate actor ID is not falsely represented as the Agent Desktop JWT user/device identity.
