# Knowledge Management


## Sources

1. **RSS Feed** -
  - Path: `$ROOT/platform/{news,feed}`
  - Storage: `qdrant`
2. **Knowledge Database** - obsidian based vault or collection of markdown files
  - Path: `$HOME/github.com/teaglebuilt/knowledge`
  - Storage: Undecided

### Diagrams


```
SOURCES              INGEST (write)             STORE           SERVE (read)
FreshRSS ─poll GReader─┐                       ┌────────┐   search_knowledge() ─▶ kagent agents + Claude Code
knowledge vault ─git──▶ knowledge-indexer ────▶│ Qdrant │◀──                       (mcp-backend target)
aiconfig ai-ml ─git──▶  (chunk·embed·upsert)   │knowledge_*│  OpenWebUI native RAG ─▶ chat UI (its own collections)
                              │ embed
                              ▼
                     ollama nomic-embed-text (768d, CPU)
```
