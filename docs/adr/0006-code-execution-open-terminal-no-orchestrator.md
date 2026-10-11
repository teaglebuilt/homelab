# ADR-0006: Code execution via a single Open Terminal; no Terminals orchestrator; Broker attach façade later

## Status
Proposed

## Context
OpenWebUI's recommended code-execution backend is Open Terminal (MIT). Terminals, the per-user orchestrator, is under the Open WebUI Enterprise License (production needs licensed seats; dev/test carve-out). The platform is single-user and is building a Desktop Broker that leases, resets and health-checks disposable Proxmox desktops for agents.

## Decision Drivers
* **Must** keep one owner for disposable-compute lifecycle
* **Must** keep the agent as the lease holder for desktops
* **Should** let the chat see agent desktop work

## Considered Options
### Option 1: Terminals orchestrator
- **Pros**: per-user policies, idle cleanup, resets
- **Cons**: licensing ambiguity for daily use; no isolation value for one user; a second compute scheduler beside the Broker; no HA
### Option 2: One Open Terminal pod (+ optional extra images as separate connections)
- **Pros**: MIT; trivial; adequate scratch space
- **Cons**: no lifecycle management
### Option 3: desktopd implements the Open Terminal API directly
- **Pros**: chat sidebar on real desktops
- **Cons**: static connection vs dynamic leases; two drivers on one VM; desktopd's API tied to upstream

## Decision
**Option 2 now**; later, the **Desktop Broker** exposes an Open Terminal-compatible attach endpoint (read-only by default) that resolves user/chat → active DesktopSession → desktopd.

## Rationale
The Broker already does what Terminals would do; a façade on it gives the sidebar without a second scheduler or breaking lease ownership.

## Consequences
### Positive
- No licence exposure; one lifecycle owner
- Chat can observe and download agent artifacts
### Negative
- Façade code to track the Open Terminal API
- Write access requires an explicit pause/take-over flow

## Implementation Notes
- Open Terminal: egress-only CiliumNetworkPolicy (no kagent, Broker, Proxmox, `data`); AGENTS.md from a ConfigMap; optional gVisor RuntimeClass
- Untested: OpenWebUI behaviour with a read-only terminal server; per-chat header support on terminal connections

## Related Decisions
- ADR-0001, ADR-0007
