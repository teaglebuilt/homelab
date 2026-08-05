---
name: n8n-workflow
description: Build or modify n8n workflows on the homelab n8n instance. Triggers on "create n8n workflow", "automate X in n8n", "update n8n
workflow", or any mention of n8n automation. Delegates to the n8n-workflow-builder subagent.
---

# n8n Workflow Builder

For any n8n workflow creation, modification, or archival task, delegate to the `n8n-workflow-builder` subagent via the Agent tool.

Pass the agent:
- The user's intent (what the workflow should do)
- Any specific trigger (cron, webhook, manual)
- External services involved (so it can pick the right credential names)
- Whether this is a NEW workflow or modification of an existing one (and the ID if known)

After the agent returns, surface the workflow URL and JSON path to the user.

## Scraping Workflows

Since firecrawl is self hosted we use `HTTP Request Node` instead of firecrawl node.

When building workflows to scrape use self hosted firecrawl and HTTP Request Nodes.

For firecrawl reference, docs, API, etc...go to https://docs.firecrawl.dev/llms-full.txt

## Plugin

- n8n-mcp-skills - use skills or plugin for extended information that you can use such as workflow patterns, syntax, node configuration, etc...
