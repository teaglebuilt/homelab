
# Architecture

## Overview

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

## Context Retreivel and Storage

```
SOURCES              INGEST (write)             STORE           SERVE (read)
FreshRSS ─poll GReader─┐                       ┌────────   ┐   search_knowledge() ─▶ kagent agents + Claude Code
knowledge vault ─git──▶ knowledge-indexer ────▶│ Qdrant    │◀──                       (mcp-backend target)
aiconfig ai-ml ─git──▶  (chunk·embed·upsert)   │knowledge_*│  OpenWebUI native RAG ─▶ chat UI (its own collections)
                              │ embed
                              ▼
                     ollama nomic-embed-text (768d, CPU)
```


**Ingestion:**

- **RSS "star → index"** (the concrete example): FreshRSS has **no star webhook**, so poll the **Google Reader API** (`/api/greader.php` → `user/-/state/com.google/starred`) on a short interval; new starred items → fetch/normalize → chunk → embed → upsert to `knowledge_rss`. Track processed IDs in the indexer PVC.

- **Markdown vault → index:** a CronJob (or n8n cron) does `git pull` on `~/github/teaglebuilt/knowledge` and `~/github/teaglebuilt/knowledge/`, computes `git diff --name-status`, POSTs changed/deleted `.md` paths to `/ingest` (deletes remove points by `source_path`). Idempotent, incremental.
