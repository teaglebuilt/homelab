# Goal

Build an agent execution platform in this homelab that combines:

* **kagent** as the agent orchestration/control layer.
* **Agent Substrate** as the Kubernetes execution, isolation, persistence, suspend/resume, and WorkerPool layer for agent brains.
* **AgentHarness** where appropriate for long-running coding/research agents.
* **Proxmox VMs** as pooled, full desktop computers available to agents when they require GUI/browser/full-OS/GPU/Windows capabilities.
* **Agent Desktop** installed on each managed VM for endpoint identity, enrollment, AI-tool configuration, inventory, model credentials, and governance.
* A custom lightweight **desktopd** daemon inside each VM for actual shell/browser/filesystem/GUI/computer-use execution.
* A Kubernetes **Desktop Broker** that allocates, leases, resets, and releases Proxmox desktops to Substrate agents.
* The existing **Envoy AI Gateway** as the model data plane.
* Existing homelab observability, secrets, GitOps, networking, storage, and PKI wherever appropriate.

The intended high-level architecture is:

```text
                      OpenWebUI / APIs / Users
                               |
                               v
                            kagent
                               |
                               v
                       Agent Substrate
                    Actors / AgentHarnesses
                               |
                         MCP / gRPC / API
                               |
                               v
                        Desktop Broker
                               |
                +--------------+--------------+
                |                             |
                v                             v
        Proxmox Linux VMs             Proxmox Windows VMs
                |                             |
        Agent Desktop daemon           Agent Desktop daemon
        desktopd                       desktopd
        Claude/Codex/etc.              Browser/apps/etc.
                |                             |
                +-------------+---------------+
                              |
                              v
                       Envoy AI Gateway
                    /       |       |       \
                Ollama  Anthropic OpenAI  Bedrock
```

The key architectural principle is:

> The **agent brain** runs on Agent Substrate. A **desktop VM is an external resource leased by that agent only when necessary**.

Do not couple one agent permanently to one VM.

---

# Repository Context

This work belongs in the existing homelab repository.

Before making any changes:

1. Inspect the complete repository.
2. Understand the current Kubernetes, Talos, Proxmox, AI Gateway, kagent, storage, security, observability, and GitOps patterns.
3. Reuse existing conventions rather than creating parallel infrastructure.
4. Inspect current upstream documentation/releases for:

   * kagent
   * Agent Substrate
   * AgentHarness
   * Agent Desktop
   * Envoy Gateway / AI Gateway
   * Proxmox APIs/provider
5. Do not assume API versions or CRD schemas from memory.
6. Verify installed/current versions before writing manifests.

The repository already contains areas such as:

```text
kubernetes/
platform/
  ai/
    k8s/
  automation/
  observability/
tf_modules/
```

Prefer extending these structures cleanly.

---

# Core Design

## 1. Agent Substrate

Install/configure Agent Substrate on the Talos Kubernetes cluster.

Create several WorkerPools with separate trust/resource profiles.

Start with:

```text
general-agents
coding-agents
trusted-platform-agents
untrusted-agents
```

Intended characteristics:

### general-agents

Normal research/API/tool agents.

### coding-agents

Higher CPU/RAM allocation for coding agents and AgentHarness workloads.

### trusted-platform-agents

Agents allowed to reach sensitive infrastructure tools such as:

* Kubernetes
* Proxmox
* Grafana
* GitHub
* internal administration MCP servers

### untrusted-agents

Strongly restricted network and tool access.

Use the security/isolation model recommended by current Agent Substrate documentation.

Configure durable actor state/object storage using S3-compatible object storage where supported.

Do not use the NFS NAS for Actor snapshots unless required by the current Substrate implementation.

---

# 2. AgentHarness

Support AgentHarness for persistent coding/research/platform agents.

Potential initial agents:

```text
homelab-platform-engineer
coding-agent
qa-agent
research-agent
```

An AgentHarness should be able to use:

```text
GitHub MCP
Kubernetes MCP
Desktop Broker MCP
Grafana/observability tools
approved research tools
```

Do not grant every agent every tool.

Design explicit capability policies.

---

# 3. Desktop Broker

Create a Kubernetes-hosted service called something similar to:

```text
desktop-broker
```

Its responsibility is to manage a pool of Proxmox desktop VMs.

It should NOT execute GUI commands itself.

Responsibilities:

```text
discover desktops
register desktops
track health
track capabilities
lease desktop
renew lease
release desktop
reset desktop
restore snapshot
mark unhealthy
quarantine desktop
provide short-lived session credentials
expose metrics
```

Initial logical API:

```text
desktop.acquire
desktop.release
desktop.status
desktop.list
desktop.heartbeat
```

Example:

```json
{
  "os": "linux",
  "capabilities": [
    "browser",
    "docker",
    "node"
  ],
  "gpu": false,
  "ttl": "60m"
}
```

Example response:

```json
{
  "desktop_id": "linux-desktop-03",
  "session_id": "sess-123",
  "endpoint": "...",
  "expires_at": "...",
  "capabilities": [
    "browser",
    "docker",
    "node",
    "shell"
  ]
}
```

Expose the Broker to agents through MCP if that is the cleanest integration with kagent.

Keep the internal service implementation independent of MCP so additional APIs can be added later.

---

# 4. Kubernetes CRDs

Create a Kubernetes-native representation of desktops and sessions.

Prefer CRDs approximately like:

```yaml
apiVersion: agents.homelab.internal/v1alpha1
kind: AgentDesktop
metadata:
  name: linux-desktop-01

spec:
  provider: proxmox

  vm:
    id: 301

  os: ubuntu

  capabilities:
    browser: true
    shell: true
    docker: true
    computerUse: true
    gpu: false

  lifecycle:
    mode: pooled

status:
  state: Ready
```

And:

```yaml
apiVersion: agents.homelab.internal/v1alpha1
kind: DesktopSession
metadata:
  name: session-123

spec:
  desktopRef: linux-desktop-01

  owner:
    type: substrate-actor
    name: qa-agent-73

  ttl: 1h

status:
  phase: Active
```

Exact schemas may differ.

Design them thoughtfully.

The goal is to eventually support:

```bash
kubectl get agentdesktops
kubectl get desktopsessions
```

with output similar to:

```text
NAME                 OS          STATE    GPU
linux-desktop-01     ubuntu      Ready    false
linux-desktop-02     ubuntu      Busy     false
gpu-desktop-01       ubuntu      Ready    true
windows-desktop-01   windows     Ready    false
```

---

# 5. Proxmox Desktop Pool

Use Proxmox as the full-computer execution layer.

Create reusable golden VM templates.

Initial pool:

```text
linux-desktop-01
linux-desktop-02
linux-desktop-03

windows-desktop-01

gpu-desktop-01
```

Do not provision all of these immediately if unnecessary.

Start with two Linux VMs for the MVP.

Each Linux VM should contain:

```text
Agent Desktop daemon
desktopd
Claude Code
Codex/OpenCode where appropriate
Chromium/Chrome
Playwright
git
Node.js
Python
Docker or Podman if practical
development utilities
```

Potential GPU pool members can be added later.

---

# 6. Golden Image + Reset Model

Desktop VMs should be disposable.

Desired lifecycle:

```text
golden template
      |
      v
pooled VM
      |
      v
agent acquires lease
      |
      v
work performed
      |
      v
artifacts exported
      |
      v
lease released
      |
      v
snapshot/template reset
      |
      v
health verification
      |
      v
READY
```

Never trust that cleanup scripts completely remove agent state.

Prefer rollback/rebuild from a known-good snapshot/template.

Investigate the safest Proxmox mechanisms for this.

---

# 7. desktopd

Build a small daemon named `desktopd` or equivalent.

Prefer **Go or Rust** unless repository conventions strongly suggest otherwise.

desktopd is the actual execution interface running inside each VM.

It should initially support:

```text
health
exec
process status
read file
write file
list directory
take screenshot

browser launch
browser navigate
browser click
browser type
browser screenshot
browser DOM/accessibility inspection
```

Later capabilities may include:

```text
native mouse
native keyboard
window enumeration
desktop screenshot
clipboard
file upload/download
video recording
audio
GPU workloads
```

Do not expose a permanently unauthenticated remote shell.

Every request must be tied to a valid DesktopSession.

Use short-lived credentials issued by the Desktop Broker.

---

# 8. Browser Automation

Prefer structured browser control before pixel-based computer use.

Priority:

```text
1. Playwright / browser DOM
2. accessibility tree
3. browser screenshot + vision
4. native desktop computer-use
```

Use full GUI mouse/keyboard automation only when structured interfaces are insufficient.

---

# 9. Agent Desktop

Install Agent Desktop on each Proxmox VM.

Use it for:

```text
device identity
device enrollment
AI harness discovery
configuration reconciliation
inventory
model-gateway credentials
MCP configuration governance
skills/tool governance
telemetry
```

Do NOT attempt to make Agent Desktop itself perform remote GUI control.

That is desktopd's job.

The Agent Desktop daemon and desktopd should remain distinct components.

---

# 10. Agent Desktop Controller

Run the Agent Desktop controller on Kubernetes.

Use production-oriented deployment patterns.

Pay particular attention to mTLS requirements.

If the controller must terminate client-certificate TLS itself, do not terminate TLS at a normal HTTP ingress in front of it.

Use an L4/TCP path where necessary.

Integrate with the existing:

```text
Cilium
Gateway API
cert-manager
External Secrets
internal DNS
```

without violating Agent Desktop's mTLS requirements.

---

# 11. Identity

Build a clear identity model.

A request should be traceable through:

```text
human/service
     |
Substrate Actor
     |
DesktopSession
     |
AgentDesktop device
     |
AI client
     |
model request
```

Eventually we should be able to answer:

```text
Which agent used which desktop?
Who initiated the agent?
Which Claude/Codex session ran?
Which MCP tools were called?
Which model was used?
How many tokens were consumed?
How much did it cost?
What files/artifacts were produced?
```

Use short-lived credentials whenever possible.

---

# 12. AI Gateway

Do NOT deploy another gateway unless technically necessary.

Reuse the existing Envoy AI Gateway.

The gateway should remain the model data plane for:

```text
Ollama
NVIDIA/local inference
Anthropic
OpenAI
Bedrock
future providers
```

Agent Desktop should issue short-lived model access credentials.

Envoy should validate those credentials.

Provider API keys must remain server-side.

Do not distribute raw Anthropic/OpenAI provider keys to the VMs.

Eventually support routing based on:

```text
user
actor
device
client
requested model
cost
GPU availability
local/cloud policy
```

---

# 13. Desktop Scheduling

The Desktop Broker should choose desktops based on capabilities.

Example:

```text
agent needs Chrome
        ->
normal Linux desktop

agent needs CUDA
        ->
GPU desktop

agent needs Windows application
        ->
Windows desktop

agent needs only GitHub/Kubernetes APIs
        ->
NO desktop allocated
```

This last case is important.

Agents should not acquire a desktop unless one is actually needed.

---

# 14. State Ownership

Keep state ownership explicit.

## Agent Substrate owns

```text
reasoning state
conversation/session state
agent memory
agent execution lifecycle
agent checkpoints
```

## Desktop VM owns only temporary execution state

```text
repository checkout
build output
browser state
temporary files
GUI state
local process state
```

## Persistent artifacts should leave the desktop

For example:

```text
Git commits/PRs -> GitHub
screenshots -> S3
logs -> observability stack
test results -> S3/GitHub
agent state -> Substrate object storage
```

Do not rely on long-lived VM filesystem state.

---

# 15. Observability

Instrument the entire flow with OpenTelemetry where practical.

Desired trace:

```text
user request
  |
kagent
  |
Substrate Actor
  |
desktop.acquire
  |
desktopd.exec
  |
browser operation
  |
Claude/Codex model call
  |
Envoy AI Gateway
  |
model provider
```

Useful attributes:

```text
agent.id
actor.id
harness.id

desktop.id
desktop.os
desktop.gpu

session.id
user.id

client.id
model.name
model.provider

mcp.server
mcp.tool

gen_ai.usage.input_tokens
gen_ai.usage.output_tokens

cost
duration
status
```

Integrate with the existing observability stack.

Prefer:

```text
OpenTelemetry Collector
Prometheus
Tempo
Loki
Grafana
```

if compatible with what is currently deployed.

Create dashboards for:

```text
active agents
active desktop sessions
desktop utilization
desktop failures
desktop reset duration
GPU desktop utilization
model requests
tokens
cost
MCP calls
agent execution traces
```

---

# 16. Security

Security is a first-class requirement.

Desktop VMs should be treated as semi-untrusted execution environments.

Implement or plan:

```text
network segmentation
short-lived session credentials
per-session authorization
mTLS where appropriate
no static model provider credentials
VM rollback after jobs
MCP allowlists
tool approval boundaries
audit logging
least privilege
namespace isolation
Substrate isolation
```

A compromised desktop should not automatically yield:

```text
Kubernetes administrator access
Proxmox administrator access
AWS credentials
raw model provider API keys
other desktop sessions
Substrate worker control
```

The Desktop Broker should be the only normal component allowed to manage desktop lifecycle through Proxmox.

---

# 17. Networking

Define explicit communication paths.

Desired model:

```text
Substrate Actor
     |
     v
Desktop Broker

Desktop Broker
     |
     v
Proxmox API

Substrate Actor
     |
     v
desktopd session endpoint

desktop VM
     |
     v
Envoy AI Gateway

desktop VM
     |
     v
approved external/internal services
```

Do not simply put everything on a flat trusted network.

Use Cilium policies where possible.

---

# 18. Repository Structure

Prefer something close to:

```text
platform/
  ai/
    k8s/

      kagent/

      substrate/
        kustomization.yaml
        workerpools/
          general.yaml
          coding.yaml
          trusted.yaml
          untrusted.yaml

      agent-desktop/
        controller/
        pki/
        database/
        networking/

      desktop-broker/
        deployment.yaml
        service.yaml
        rbac.yaml
        networkpolicy.yaml
        servicemonitor.yaml

      desktops/
        crds/
        examples/

services/
  desktop-broker/

services/
  desktopd/

tf_modules/
  agent_desktop_vm/

docs/
  architecture/
    agent-runtime.md
```

Adjust this after understanding current repo conventions.

Do not reorganize unrelated parts of the repository.

---

# 19. Implementation Phases

Do not attempt everything in one giant change.

## Phase 1 — Architecture and verification

Before writing significant code:

1. Inspect repository.
2. Inspect current kagent setup.
3. Verify current Agent Substrate APIs.
4. Verify AgentHarness APIs.
5. Verify Agent Desktop deployment model.
6. Verify Envoy JWT capabilities currently available.
7. Identify existing Proxmox Terraform modules.
8. Produce:

```text
docs/architecture/agent-runtime.md
```

Include:

```text
architecture
trust boundaries
network flows
identity model
CRDs
component ownership
implementation plan
risks
```

Stop and ensure the design is internally consistent before large implementation changes.

---

## Phase 2 — Agent Substrate

Deploy:

```text
Agent Substrate
WorkerPools
object-storage configuration
basic test actor
```

Prove:

```text
actor runs
actor can suspend
actor can resume
actor state survives
```

---

## Phase 3 — Desktop Broker MVP

Implement:

```text
desktop inventory
desktop.acquire
desktop.release
lease TTL
health checking
```

Do NOT implement full VM lifecycle yet.

Use statically registered desktops first.

---

## Phase 4 — First Proxmox Desktop

Build one Ubuntu desktop VM.

Install:

```text
Agent Desktop
desktopd
Chrome
Playwright
Claude Code
development tools
```

Prove:

```text
Substrate Actor
   ->
Desktop Broker
   ->
desktop.acquire
   ->
desktopd.exec("uname -a")
   ->
desktop.release
```

---

## Phase 5 — Browser Task

Demonstrate:

```text
Actor acquires desktop
Actor launches browser
Actor navigates to a page
Actor inspects page
Actor captures screenshot
Actor releases desktop
```

---

## Phase 6 — Snapshot Reset

Add:

```text
lease complete
   ->
Proxmox rollback/rebuild
   ->
desktop health check
   ->
READY
```

Verify one session cannot read data from the previous session.

---

## Phase 7 — Agent Desktop Integration

Enroll desktops into Agent Desktop.

Route Claude/Codex model requests through existing Envoy AI Gateway using short-lived identity.

Verify:

```text
desktop has no raw OpenAI/Anthropic provider key
```

---

## Phase 8 — AgentHarness

Deploy a persistent coding/platform AgentHarness on Substrate.

Give it Desktop Broker access.

Demonstrate:

```text
AgentHarness
   ->
desktop.acquire
   ->
clone repo
   ->
run application
   ->
browser test
   ->
produce artifact
   ->
desktop.release
```

---

## Phase 9 — Dynamic Proxmox Pool

Add:

```text
golden templates
cloning
pool reconciliation
capacity management
snapshot reset
health checks
quarantine
```

Eventually support:

```text
Linux pool
Windows pool
GPU pool
```

---

# 20. Testing

Add automated tests.

At minimum:

### Broker

```text
acquire available desktop
reject double allocation
lease expiration
lease renewal
release
unhealthy desktop exclusion
capability scheduling
```

### desktopd

```text
reject invalid credential
reject expired session
exec command
file operations
browser operation
```

### lifecycle

```text
session A writes secret.txt
session A ends
VM resets
session B begins
secret.txt must not exist
```

### security

```text
agent cannot access another session
desktop cannot call Proxmox API
desktop cannot retrieve model provider secrets
untrusted WorkerPool cannot access privileged MCP tools
```

---

# 21. Developer Experience

Add useful Taskfile commands following existing repository conventions.

Examples:

```bash
task agent:status

task substrate:status

task desktops:list

task desktops:acquire

task desktops:release

task desktops:reset

task desktop:logs

task desktop:health
```

Names can change to match repository conventions.

---

# 22. Documentation

Document:

```text
How an agent gets a desktop
How desktop leases work
How desktops reset
How Agent Desktop fits in
How Agent Substrate fits in
How AgentHarness fits in
How identity propagates
How model credentials work
How to add a desktop capability
How to create a new WorkerPool
How to add a Windows desktop
How to add a GPU desktop
How to troubleshoot sessions
```

Include Mermaid diagrams.

---

# 23. Important Constraints

Do not:

* create one VM permanently per agent
* store agent reasoning state primarily inside desktop VMs
* expose static provider API keys to desktops
* make Agent Desktop responsible for GUI execution
* make Agent Substrate manage Proxmox directly
* allow individual agents unrestricted Proxmox API access
* expose desktopd without authentication
* assume current CRD/API versions
* create a second AI gateway without proving it is necessary
* replace existing platform components simply because another project's example architecture uses different software
* deploy everything before proving the MVP lifecycle

Prefer:

```text
Agent Substrate = agent runtime
Desktop Broker = resource scheduler
Proxmox = computer runtime
Agent Desktop = endpoint governance
desktopd = computer execution API
Envoy AI Gateway = model gateway
```

---

# Initial Success Criteria

The first meaningful end-to-end milestone is:

```text
1. A kagent/AgentHarness agent executes on Agent Substrate.

2. The agent calls Desktop Broker.

3. Desktop Broker leases linux-desktop-01.

4. The agent receives a short-lived session credential.

5. The agent calls desktopd.

6. desktopd runs:
      git clone
      pnpm install
      pnpm dev

7. The agent launches Chromium through desktopd.

8. The agent loads localhost.

9. The agent captures a screenshot/test result.

10. Claude/Codex calls from the VM go through our Envoy AI Gateway.

11. The agent releases the desktop.

12. Proxmox restores the VM to a clean snapshot.

13. The desktop returns to READY.

14. Grafana/Tempo shows a trace tying together:
      agent
      actor
      desktop session
      desktop
      model call
      tool calls
      duration
      token usage
```

That proves the architecture.

---

# Working Method

Work incrementally.

For every phase:

1. Inspect existing code first.
2. Verify current upstream APIs.
3. Explain the proposed change briefly.
4. Make the smallest coherent implementation.
5. Validate manifests.
6. Run applicable tests.
7. Check generated Kubernetes resources.
8. Identify anything that cannot be validated locally.
9. Update architecture documentation.
10. Do not silently leave placeholder code pretending to be functional.

When there is an architectural choice, optimize for:

```text
security
clear ownership
replaceability
observability
GitOps
Kubernetes-native orchestration
simple failure recovery
minimal persistent state on desktop VMs
```

The desired result is not merely remote desktop automation.

We are building a **general-purpose infrastructure layer where stateful AI agents running on Kubernetes can dynamically acquire secure, disposable, full computers as tools.**
