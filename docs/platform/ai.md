# AI Platform

## Coding

[aiconfig](https://github.com/teaglebuilt/aiconfig) is the dotfile-like config for my configurations between vibe coding tools and text editors. It interfaces with the AI Gateway that runs on my Kubernetes cluster.

## Gateway

The AI Gateway provides a unified interface for multiple LLM providers, enabling:

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

## Architecture

All AI traffic flows through [Kgateway](https://kgateway.dev/docs/main) which provides:

- TLS termination
- Request routing based on model endpoints
- Observability and metrics collection

See [Kubernetes Infrastructure](../infra/kubernetes.md) for gateway configuration details.
