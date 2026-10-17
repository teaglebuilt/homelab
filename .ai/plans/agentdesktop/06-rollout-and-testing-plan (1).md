# Rollout and Testing Plan

## Principle

Build the smallest end-to-end path and add custom code only after the Agent Desktop capability audit proves the capability is missing.

Agent Substrate is already working and is **not** a rollout phase.

Read `00-agentdesktop-capability-audit.md` before every phase.

## Phase 0 — release and ownership gate

1. Pin Agent Desktop `v0.1.1` controller/chart/endpoint binary.
2. Record the published SHA256 for the Linux artifact.
3. Compare release schema/API/assets with current `main`/live docs so unreleased features are not assumed; specifically verify `daemon.reconcileInterval`, device-authorization enrollment, and endpoint installers.
4. Revise `.ai/stories/agent-desktop-integration.md` to reflect current ownership.
5. Record identity boundary: Substrate actor != Agent Desktop JWT user/device.

Exit criteria:

```text
no custom device identity service
no custom fleet inventory DB/UI
no duplicate Claude/Codex config writer
no duplicate sandbox policy layer
no duplicate gateway credential issuer
no duplicate Agent Desktop tool/session telemetry
no main-only Agent Desktop feature required by MVP
```

## Phase 1 — Crossplane/OpenTofu infrastructure spike

Pin and deploy:

```text
Crossplane v2.4 line
provider-opentofu v1.1.6
```

Then:

1. configure durable remote state;
2. prove provider health/no-op Workspace;
3. run the Proxmox workstation module under the provider's bundled OpenTofu runtime;
4. ensure module does not require OpenTofu 1.11-only features;
5. create a disposable test VM;
6. verify update/delete semantics before Agent Desktop enrollment;
7. document ArgoCD/Crossplane ownership;
8. choose conservative deletion policy for enrolled workstations.

Exit criteria:

```text
provider survives restart
remote state survives Pod replacement
no-op reconcile is safe
Proxmox credential stays in provider boundary
VM lifecycle behavior is understood
```

## Phase 2 — first persistent Linux workstation

Provision `linux-agent-01`.

Install only endpoint/bootstrap prerequisites:

```text
qemu guest agent
SSH/remote transport
Agent Desktop v0.1.1 binary + checksum verification
agentdesktop Unix group
systemd unit
small controller bootstrap
agent-task non-root user
Claude Code
Codex
Chromium/Playwright
git/node/python tooling
```

Do not manually write Claude/Codex managed settings.

Security checks:

- Agent Desktop socket is local only;
- unauthorized user cannot access it;
- task user receives `agentdesktop` group membership only if required;
- task user has no unrestricted sudo.

## Phase 3 — Agent Desktop Managed controller

Deploy upstream controller + DB/PKI/OIDC using production guidance.

1. fleet TLS/mTLS terminates at controller;
2. admin UI remains loopback/private;
3. mount both `controller.yaml` and `daemon.yaml` via chart overlay if required;
4. add platform hardening (NetworkPolicy/readiness etc.) without replacing controller logic;
5. configure minimal distributed policy;
6. `allowedClientIds = [claude-code, codex]` only;
7. set `programs.claudeCode.useLlmGateway: true`;
8. set `programs.codex.useLlmGateway: true`;
9. choose/document workstation enrollment OIDC principal;
10. enroll `linux-agent-01` with released human-approved flow;
11. verify inventory/config results/reboot behavior.

Do not depend on unreleased `controller.deviceAuthorization` for MVP.

## Phase 4 — existing AI gateway integration

Configure current `agentgateway` to validate Agent Desktop JWTs.

Test:

| Case | Expected |
|---|---|
| correct issuer/audience/client label | allow |
| expired JWT | deny |
| wrong audience | deny |
| disallowed client label | deny |
| malformed token | deny |

Then verify:

- Claude Code gets a short-lived credential through Agent Desktop;
- Codex gets a short-lived credential through Agent Desktop;
- raw provider keys are absent on workstation;
- gateway logs user/device/client attribution;
- docs/ADR explicitly states `client_id` is not process attestation;
- no claim is made that actor ID is in the JWT.

## Phase 5 — inventory and drift validation

Validate `inventoryInterval` behavior from the pinned release.

Test:

1. install/remove a test supported tool;
2. use daemon restart for deterministic pilot verification if needed;
3. verify local discovery;
4. verify fleet inventory update;
5. verify periodic refresh works in steady state;
6. mutate a managed setting and validate repair through released config-delivery/reconnect/restart behavior; do **not** configure `daemon.reconcileInterval` on `v0.1.1`.

Do not build a custom rescan daemon.

## Phase 6 — remote execution reuse spike

Before writing code, evaluate:

```text
existing SSH MCP / remote exec
kagent/KMCP integration
existing Playwright/browser MCP on target workstation
```

Decision gate:

- reuse if auth/audit/timeout/target/file-transfer requirements are met;
- write only a thin adapter for real gaps.

Explicitly confirm Agent Desktop is **not** used as remote shell transport.

## Phase 7 — first Substrate -> workstation task

From the existing Claude/Kagent Harness:

```text
select linux-agent-01
record actor/task -> Agent Desktop device mapping
remote exec a simple command
create task workspace
run repo test/dev command
launch Agent Desktop-managed Claude/Codex if needed
launch browser
inspect/capture artifact
cleanup task state
```

Verify simultaneously:

```text
Agent Desktop remains enrolled
config remains Applied
managed settings are unchanged
client obtains gateway credential through Agent Desktop, not remote-exec service
actor identity exists in remote-exec trace, not falsely in gateway JWT
Agent Desktop tool telemetry is not duplicated by execution telemetry
```

## Phase 8 — second desktop and optional Lease

Provision/enroll `linux-agent-02` using the same model.

Start with explicit targeting.

Only if concurrent actors contend, add Kubernetes `Lease` acquire/renew/release.

No custom broker DB/CRD unless Lease semantics prove insufficient.

## Phase 9 — task isolation hardening

Test:

```text
session A writes sentinel
session A browser receives cookie/history
session A exits
cleanup runs
session B starts
sentinel absent
cookie/history absent
A process group absent
Agent Desktop identity still intact
```

If cleanup is unreliable, quarantine/rebuild the task environment without rolling Agent Desktop state backward.

## Phase 10 — optional infrastructure API

After module is proven, consider Crossplane XRD/Composition for infrastructure classes only.

Do not use it to replace Agent Desktop fleet/policy APIs.

## Phase 11 — Windows / GPU

Only after Linux path is reliable:

```text
Windows endpoint packaging path (verify pinned release artifacts; wrap binary/service if installer is absent)
Windows remote transport/native app automation
GPU workstation class/PCI passthrough
capability-based selection
```

## Test categories

### Agent Desktop ownership tests

- enrollment/re-enrollment;
- local device key remains local;
- config Applied/failed/conflict states;
- tool discovery/inventory refresh;
- sandbox managed output;
- gateway helper credentials;
- selected telemetry;
- offboarding.

### Local API security tests

- unauthorized user cannot access socket;
- allowed task user can use managed client if intended;
- disallowed client label cannot get credential;
- socket is not reachable over network;
- local group membership is documented/limited.

### Infrastructure

- Crossplane/provider restart;
- OpenTofu state recovery;
- VM drift;
- deletion-policy safety;
- Proxmox outage/recovery.

### Cross-machine execution

- auth failure;
- timeout/cancel;
- output bounds;
- file-root validation;
- browser crash;
- process leak;
- cleanup/quarantine;
- later Lease collision/expiry.

### Identity/correlation

- actor/task ID present in remote-exec span;
- target Agent Desktop device ID/name recorded;
- gateway sees enrolled user/device/client;
- actor ID is not claimed to be in Agent Desktop JWT;
- trace/query can join actor task -> target device -> gateway request by correlation metadata/time.

### No-duplication checks

Before merge, verify:

```text
only Agent Desktop writes system-managed Claude/Codex/OpenCode files
only Agent Desktop/controller issues workstation model gateway credentials
only Agent Desktop owns endpoint enrollment identity
only Agent Desktop fleet state is used for AI endpoint inventory
cloud-init/Ansible owns packages/services only
custom execution logs do not duplicate Agent Desktop tool.use events
remote-exec service does not call Agent Desktop credential API on behalf of clients
```

## First milestone definition of done

```text
existing Harness on Substrate
  -> calls an existing/thin remote-execution MCP tool
  -> records actor/task -> linux-agent-01 device mapping
  -> runs work as non-root agent-task
  -> invokes Agent Desktop-managed Claude/Codex locally when needed
  -> controls Chromium/Playwright
  -> client gets credential from Agent Desktop
  -> model traffic uses existing ai-gateway
  -> artifacts return to actor
  -> task state is cleaned
  -> Agent Desktop identity/config remain healthy
```
