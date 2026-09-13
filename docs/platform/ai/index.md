# AI Platform

1. [Platform AI Clients](#clients)
  1. Claude Code / Cursor
  2. OpenWebUI
2. [Platform AI Infrastructure](#platform-infrastructure)

```
                                   ┌─────────────────────── FRONT DOORS ───────────────────────┐
                                   │  OpenWebUI (chat)   n8n (events/cron/glue)   Claude Code    │
                                   │        │                   │                  /Cursor       │
                                   └────────┼───────────────────┼───────────────────┼───────────┘
                                            │                   │                   │ (kagent /mcp:
                                            ▼                   ▼                   │  list+invoke_agent)
                          ┌───────────────────────────────────────────────────────────────────┐
                          │                    agentgateway  (ai namespace)                     │
                          │   /  → kagent UI        /mcp → mcp-backend (tool fabric + authz)     │
                          └───────────────┬───────────────────────────────┬───────────────────┘
                                          │                               │
                          ┌───────────────▼──────────────┐   ┌────────────▼─────────────────────┐
                          │      AGENT RUNTIME (kagent)    │   │        MCP TOOL FABRIC         │
                          │  supervisor (A2A parent, opt.) │   │  github · knowledge-search     │
                          │   ├─ k8s-ops agent             │   │  firecrawl · crawl4ai(scrape)   │
                          │   ├─ knowledge/research agent  │──▶│  kagent-tools/querydoc/controller│
                          │   ├─ browser agent             │   │  comfyui · devbot-computer(defer)│
                          │   └─ (Hermes harness, deferred)│   └────────────────┬─────────────────┘
                          │  memory · HITL · skills(OCI/git)│                   │
                          └───────────────┬────────────────┘                    │
                                          │ ModelConfig                         │ tools call out
                    ┌─────────────────────▼─────────────────┐      ┌────────────▼───────────────┐
                    │            MODEL LAYER                  │    │      KNOWLEDGE LAYER        │
                    │ local: vLLM (AWQ 7-8B) · NIM · ollama   │    │ knowledge-indexer (FastAPI) │
                    │ hosted: Claude · GPT · Bedrock (teacher)│    │  /ingest  +  /mcp search    │
                    │ training: Unsloth QLoRA Job (scale-0)   │    │ Qdrant (knowledge_*) ·      │
                    └─────────────────────────────────────────┘    │ ollama nomic-embed 768d     │
                                          ▲                         └─────────────────────────────┘
                                          │ ONE GPU (RTX 4070 SUPER, 12 GB) — one heavy workload at a time
                                          └── embeddings on CPU · crawl4ai off-GPU · train via scale-to-zero
```

## Platform Clients

1. Claude Code
2. OpenWebUI
3. ComfyUI

## Platform Infrastructure

1. **AI Gateway**

The AI Gateway provides a unified interface for multiple LLM providers, enabling:

- Request routing and load balancing
- Cost tracking and monitoring
- Authentication and rate limiting

### Platform Providers

| Provider | Description |
|----------|-------------|
| `Anthropic` | Claude models for advanced reasoning |
| `OpenAI` | GPT models for general-purpose AI |
| `Amazon Bedrock` | AWS-managed foundation models |
| `Ollama` | Self-hosted open-source LLMs |
| `vLLM` | Self-hosted open-source LLMs |

2. **Agents**

3. **MCP**

## Use Cases

1. [AI Software Factory](./software-factory.md)
2. [RAG (Retrievel Augmented Generation)](./rag.md)
3. [Agentic Engineering](./agentic-engineering.md)
