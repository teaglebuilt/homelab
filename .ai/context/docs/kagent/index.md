# kagent - Kubernetes Native AI Agent Framework

Kubernetes-native framework for building and running AI agents as custom resources. Used in this repo for the AI platform (`platform/ai/`).

## Relevance to This Repo

- Agents defined as Kubernetes CRDs deployed to the mlops cluster
- Integrates with MCP tools and LLM providers already configured in `platform/ai/k8s/`
- Agent-to-agent communication for multi-agent workflows
- Built-in observability (tracing, monitoring) compatible with the observability stack

## Documentation to Scrape

See `scrape-plan.md` for URLs. Key topics:
- Agent CRD specification and examples
- Tool integration (MCP, built-in K8s tools)
- LLM provider configuration (Ollama, OpenAI, Anthropic)
- Helm chart installation and values
- Architecture and component overview
