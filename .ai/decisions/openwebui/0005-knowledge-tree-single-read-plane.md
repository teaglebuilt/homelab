# ADR-0005: The knowledge tree has one read plane (kb_search); OpenWebUI Knowledge is for uploads only

## Status
Proposed

## Context
The knowledge repo (639 markdown docs) is embedded locally with fastembed BAAI/bge-small-en-v1.5 (384-d, cosine), chunked by heading (~450-token children, 60 overlap), stored in LanceDB with BM25, and pushed by `make sync` to Qdrant collection `knowledge` (unnamed dense vector; payload chunk_id/path/heading/text/tags). Agents read it via the `kb_search` MCP tool (dense-only). OpenWebUI's Qdrant integration only queries its own prefixed collections, filtered by `tenant_id` and linked by `metadata.file_id` to File/Knowledge rows in its database.

## Decision Drivers
* **Must** give chat and agents identical retrieval (no drift)
* **Must not** couple the pipeline to OpenWebUI's internal vector schema
* **Should** meet hybrid (dense + sparse) retrieval on the read path agents use

## Considered Options
### Option a: Separate collections; tree only via kb_search tool
- **Pros**: no drift; no schema coupling
- **Cons**: retrieval only when the model calls the tool
### Option b: Align embedders and share one collection (or upload the tree into an OpenWebUI KB)
- **Pros**: native OpenWebUI citations and #-attach
- **Cons**: schema/file-link mismatch or a second chunker+embedder; split reindex ownership; drift between chat and agents
### Option c: External loader/retrieval hooks
- **Pros**: —
- **Cons**: the external loader is ingestion-only and the external reranker is post-retrieval; no external retrieval backend exists for Knowledge
### Option d: a + a "Ground in knowledge tree" Filter + pipeline fixes
- **Pros**: no drift; deterministic grounding on demand; read path upgraded to hybrid
- **Cons**: citation rendering via filter events untested

## Decision
We will use **Option d**.

## Rationale
The blocker for a single collection is schema and ownership, not dimension. One read plane removes drift by construction.

## Consequences
### Positive
- Agents and chat retrieve identically; the knowledge repo owns indexing
- OpenWebUI uploads stay local (in-process bge-small; no gateway embeddings route)
### Negative
- No native OpenWebUI KB features for the tree
- Pipeline work in the knowledge repo is required before quality matches local `kb query`

## Implementation Notes
- OpenWebUI: `RAG_EMBEDDING_ENGINE=""`, `RAG_EMBEDDING_MODEL=BAAI/bge-small-en-v1.5`, hybrid search on, `VECTOR_DB=qdrant`; remove the `/v1` embeddings env
- `/mcp/chat` exposes `kb_search`; Filter `kb_grounding` calls the same service
- Knowledge repo: delete-by-path before upsert (fixes stale points on edit and delete); named sparse BM25 vector + RRF; parent_text in payload; in-cluster CronJob for ingest+sync; golden set 6 → 50
- Reranker only if the golden set shows the need (shared service for both planes)
- Treat kb_search output as untrusted text

## Related Decisions
- ADR-0003, ADR-0007
