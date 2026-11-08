# ADR-0001: OpenWebUI exposes kagent agents as models via an A2A Pipe Function

## Status
Accepted

## Context
OpenWebUI (application cluster) is the human front door to an agent platform on mlops: kagent Agents, AgentHarnesses on Agent Substrate, and Proxmox desktops leased through a Desktop Broker. OpenWebUI has no native A2A client. kagent exposes agents over A2A, with an MCP surface on kagent-controller. The agent story (.ai/stories/agent-desktop-integration.md) requires that the agent brain on Substrate holds desktop leases, that identity propagates, and that a single trace links chat → agent → actor → desktop → model call.

## Decision Drivers
* **Must** let a user chat directly with an agent (no second LLM delegating)
* **Must** surface progress (lease acquired, tool calls, screenshots) and human approvals
* **Must** survive long tasks and browser disconnects
* **Should** keep one network door into mlops (agentgateway) and be GitOps-managed

## Considered Options
### Option 1: kagent-controller /mcp as an OpenWebUI tool (agents-as-tools)
- **Pros**: zero code
- **Cons**: double LLM cost, opaque single tool result, tool timeout limits task length
### Option 2: A2A Pipe Function in OpenWebUI (agents-as-models)
- **Pros**: direct chat; status/citation/file events; A2A resubscribe; reads `__user__` for identity
- **Cons**: ~200 LOC maintained against A2A and the OpenWebUI Function API; runs in-process
### Option 3: Standalone OpenAI↔A2A adapter service
- **Pros**: reusable by non-OpenWebUI clients
- **Cons**: OpenAI streaming has no status channel; another service to operate

## Decision
We will use **Option 2**, with Option 1 kept only as a no-code smoke test of A2A invocation.

## Rationale
Only a Pipe can emit OpenWebUI status/citation events and read the authenticated user, and those are what make desktop-backed agents usable from chat.

## Consequences
### Positive
- Every Agent/AgentHarness appears in the model picker and in Channels
- OpenWebUI `chat_id` ↔ A2A `contextId`, so reopening a chat resumes the agent session; `tasks/resubscribe` recovers dropped streams
- A2A `input-required` becomes the platform's approval UX
- `traceparent` injection enables the end-to-end golden trace
### Negative
- The Pipe runs inside the OpenWebUI process; a bug can affect the UI
- Identity passed to kagent is asserted by the Pipe's service credential, not proven by the user
- Two moving upstream APIs to track

## Implementation Notes
- Source: `platform/ai/integrations/openwebui/functions/kagent_a2a.py`; deployed by the OpenWebUI reconciler (ADR-0004)
- Route: new HTTPRoute `/a2a/<ns>/<agent>` on `ai-gateway`; reached via `ai-gateway-mesh`
- The Pipe MUST return early for OpenWebUI task requests (title/tag/query generation) and MUST cache its model list
- `__user__.email` → A2A metadata → `DesktopSession.spec.owner.requestedBy`
- Upgrade trigger to Option 3: a second non-OpenWebUI client needs agents behind an OpenAI-compatible API

## Related Decisions
- ADR-0002, ADR-0004, ADR-0007
