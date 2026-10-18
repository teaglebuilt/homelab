---
name: n8n-workflow
description: Build or modify n8n workflows on the homelab n8n instance. Triggers on "create n8n workflow", "automate X in n8n", "update n8n workflow", or any mention of n8n automation. Delegates to the n8n-workflow-builder subagent.
---

# n8n Workflow Builder

For any n8n workflow creation, modification, or archival task, delegate to the `n8n-workflow-builder` subagent via the Agent tool. If you *are* that subagent, skip this section and build.

Pass the agent:
- The user's intent (what the workflow should do)
- Any specific trigger (cron, webhook, manual)
- External services involved (so it can pick the right credential names)
- Whether this is a NEW workflow or modification of an existing one (and the ID if known)

After the agent returns, surface the workflow URL and JSON path to the user.

## Research before proposing

The n8n MCP server exposes this instance's live node catalog and workflow SDK, which is more
current than training data. Never name a node without checking it first.

1. `search_nodes` — find nodes by service, trigger, or utility (pass `usage: "agentTool"` for
   nodes bound as agent tools)
2. `get_node_types` — TypeScript definitions giving exact parameter names and structures,
   discriminators included
3. `explore_node_resources` — the resource/operation surface of a node
4. `get_workflow_best_practices` — instance guidance before you commit to a shape

Node types carry their package prefix: `nodes-base.slack`, never `slack`.

This server has no template search and no `get_node_essentials` / `get_node_documentation`;
reach for the `n8n-mcp-skills` plugin skills when you want pattern-level guidance.

Where MCP output disagrees with what you remember, MCP wins. Use its parameter names, note the
drift in your plan, and don't guess at behavior.

## Mandatory build order

Skipping steps creates invalid workflows:

1. `get_workflow_sdk_reference` — SDK patterns, expression syntax, import syntax, design guidance
2. `search_nodes` — every node needed, including utility nodes like set/if/merge
3. `get_node_types` — exact schemas for ALL node IDs
4. Write the workflow code per the SDK reference
5. `validate_workflow` — required before any create or update; iterate until it passes
   (`validate_node_config` to check a single node against its schema)
6. `create_workflow_from_code` (new) or `update_workflow` (existing), with a 1-2 sentence description

## Homelab conventions

- Workflows live in `platform/automation/kubernetes/n8n/workflows/*.json`. After a
  successful create or update, fetch it with `get_workflow_details` and save the JSON
  there under a descriptive filename.
- Reuse patterns from existing workflows when relevant.
- Never hardcode secrets. n8n credentials are set in the UI; reference them by name.

## Scraping Workflows

Since firecrawl is self hosted we use `HTTP Request Node` instead of firecrawl node.

When building workflows to scrape use self hosted firecrawl and HTTP Request Nodes.

For Firecrawl API/reference, go to https://docs.firecrawl.dev/api-reference

## Plugin

- n8n-mcp-skills - use skills or plugin for extended information that you can use such as workflow patterns, syntax, node configuration, etc...
