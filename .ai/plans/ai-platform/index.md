

## 1. Vision

## 2. Guiding Principles

## 3. Current-State Assessment

## 4. Target Architecture

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
