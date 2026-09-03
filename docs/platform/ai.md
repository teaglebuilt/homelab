# AI Platform

## Knowledge

[knowledge](https://github.com/teaglebuilt/knowledge) is the git backed knowledge tree of data sources. Kubernetes Jobs run that use this repo to sync the knowledge tree with vector database (qdrant)

## Gateway

The AI Gateway provides a unified interface for multiple LLM providers, enabling:
all AI traffic flows through [Kgateway](https://kgateway.dev/docs/main) which provides:

- TLS termination
- Request routing based on model endpoints
- Observability and metrics collection
- Request routing and load balancing
- Cost tracking and monitoring
- Authentication and rate limiting

### Providers

| Provider | Description |
|----------|-------------|
| `Anthropic` | Claude models for advanced reasoning |
| `OpenAI` | GPT models for general-purpose AI |
| `Amazon Bedrock` | AWS-managed foundation models |
| `Ollama` | Self-hosted open-source LLMs |


See [Kubernetes Infrastructure](../infra/kubernetes.md) for gateway configuration details.

## Agents

[KAgent]() is used for agent declaration and configuration management

### Agent Harness

[Hermes]() is used with Substrate for agent runtime
