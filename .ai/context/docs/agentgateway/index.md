# agentgateway - AI Agent Traffic Gateway

Open-source data plane for AI agent communication using A2A and MCP protocols. Connects, secures, and observes agent-to-agent and agent-to-tool traffic.

## Relevance to This Repo

- Kubernetes controller with Gateway API support (aligns with kgateway/Gateway API patterns)
- MCP protocol proxy for agent-to-tool connections
- Can transform OpenAPI specs into MCP resources
- Complements kagent for agent networking within the cluster

## Documentation to Scrape

See `scrape-plan.md` for URLs. Key topics:
- Kubernetes deployment and controller setup
- Gateway API integration
- MCP and A2A protocol support
- Configuration and routing rules
- Integration with existing Gateway API infrastructure
