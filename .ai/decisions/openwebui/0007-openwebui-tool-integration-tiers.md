# ADR-0007: OpenWebUI tool integration — tiered MCP via agentgateway; OpenAPI only for Session-auth first-party services

## Status
Proposed

## Context
agentgateway's `/mcp` federates every MCP server, including kagent-tools with `shell`, `k8s_apply_manifest`, and `k8s_delete_resource`. OpenWebUI supports MCP (Streamable HTTP) and OpenAPI tool servers with None/Bearer/Session/OAuth/OAuth 2.1 auth. There is no IdP.

## Decision Drivers
* **Must** never expose mutating infra tools to chat
* **Should** share tool definitions between chat and agents
* **Should** obtain verified user identity where cheaply possible

## Considered Options
### Option 1: Connect OpenWebUI to root /mcp
- **Pros**: simple
- **Cons**: exposes shell and mutating tools
### Option 2: Tiered MCP endpoints with tool allow-lists
- **Pros**: one definition shared with agents; gateway authorization
- **Cons**: duplicated backend definitions
### Option 3: Everything as OpenAPI tool servers
- **Pros**: Session auth everywhere
- **Cons**: shims for MCP-native servers; agents can't share them

## Decision
**Option 2** for shared tools; OpenAPI tool servers only for first-party services that validate Session auth (Desktop Broker read API).

## Rationale
Keeps the gateway as the single place tools are authorized, while using Session auth where it actually yields verified identity.

## Consequences
### Positive
- Least privilege per tier; one place to audit tool calls
- Verified identity on Broker views
### Negative
- Bearer-tier identity remains asserted (`{{USER_EMAIL}}` header)
- OpenWebUI JWT forwarded to Session servers is a full credential; first-party servers only

## Implementation Notes
- `/mcp/chat`: kb_search, context7, firecrawl, read-only GitHub; `/mcp/ops` (admin group): read-only kagent-tools, grafana-mcp, Broker list/status
- No `desktop.acquire` from OpenWebUI
- n8n via its MCP Server Trigger; remove n8n_api_key and the github/n8n pipelines from OpenWebUI secrets
- Firecrawl and SearXNG through native web loader / search settings, not as tools
- No mcpo. Automations use bearer-auth tools only (OAuth forwarding bug #23851)
- Proposed invariant INV-S: "OpenWebUI never references the root /mcp backend"

## Related Decisions
- ADR-0001, ADR-0002, ADR-0006
