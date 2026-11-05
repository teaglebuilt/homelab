# ADR-0005: The knowledge tree has one read plane; OpenWebUI reaches it as an External Knowledge connection

## Status
Accepted (2026-11-05). Revises the 2026-10 draft, which chose Option d on the
premise that no external retrieval backend existed. That premise was wrong.

## Context
The knowledge repo (639 markdown docs) is embedded locally with fastembed
BAAI/bge-small-en-v1.5 (384-d, cosine), chunked by heading, stored in LanceDB
with BM25, and pushed by `kb sync` to Qdrant collection `knowledge` (unnamed
dense vector, no sparse vector; 41,330 points as of 2026-11-05). Agents read it
via the `kb_search` MCP tool. The write plane (`kb-ingest`) adds points for
non-tree sources.

The original draft recorded that OpenWebUI "only queries its own prefixed
collections" and that "no external retrieval backend exists for Knowledge".
**Open WebUI has shipped External Knowledge since v0.10.0 (2026-06-29)**, and it
is present in the deployed 0.11.4. Verified in the running pod and against
v0.13.0 source:

* It is **not** an HTTP contract. `EXTERNAL_KNOWLEDGE_PROVIDERS = {qdrant,
  milvus, pgvector}`; the Qdrant path constructs a `QdrantClient` and calls
  `query_points`. There is nothing to implement — an existing collection is
  pointed at directly.
* Only ANN search is delegated. **OpenWebUI still embeds the query itself**
  (`embedding_function(query, prefix=rag.embedding_query_prefix)`), so its
  embedding space must match the collection's.
* Default field mapping is `content_field=payload.text`,
  `metadata_field=payload.metadata`, `document_id_field=id` — and `vector_field`
  is optional for Qdrant only (`using=None` selects an unnamed vector).
* External knowledge bases are read-only, enforced at 8 call sites.
* Configuration lives solely in the DB key `external_knowledge.connections`.
  There is no env var, so it is not declarable in values.yaml.

Compatibility was verified empirically, not inferred: embedding the same query
with OpenWebUI's own sentence-transformers stack and querying `knowledge`
directly returned the same five chunks in the same order as `kb_search`, with
scores agreeing to four decimals (0.8936 vs 0.8937; the delta is ONNX/torch
rounding).

Three defects meant OpenWebUI retrieval had never worked at all: `QDRANT_URI`
pointed at the internal gateway VIP on port 6333 (gateway serves only 80/443 —
"no route to host"); `RAG_OPENAI_API_BASE_URL` pointed at a gateway path with no
route (404); and `RAG_EMBEDDING_MODEL` was `embeddings`, which is not a model
name. Qdrant held no `open-webui_*` collections and the `knowledge`/`file`
tables were empty, confirming the feature had never been exercised.

## Decision Drivers
* **Must** give chat and agents identical retrieval (no drift)
* **Must not** couple the pipeline to OpenWebUI's internal vector schema
* **Must** keep the knowledge repo the sole owner of indexing
* **Should** meet hybrid (dense + sparse) retrieval on the read path agents use

## Considered Options
### Option a: Separate collections; tree only via the kb_search tool
- **Pros**: no drift; no schema coupling
- **Cons**: retrieval only when the model calls the tool; no `#`-attach
### Option b: Align embedders and share one collection via OpenWebUI's native path
- **Pros**: native citations and `#`-attach
- **Cons**: impossible as stated — the native path only queries `open-webui_*`
  collections keyed by `tenant_id`/`file_id`
### Option c: External loader / retrieval hooks
- **Pros**: —
- **Cons**: the external *document loader* is ingestion-only (`PUT /process`
  with raw file bytes) and the external *reranker* is post-retrieval. Neither
  replaces the vector query. **Superseded**: a genuine external retrieval
  backend does exist, just not as HTTP — see Option e.
### Option d: a + a "Ground in knowledge tree" Filter
- **Pros**: deterministic grounding on demand
- **Cons**: citation rendering via filter events untested; reimplements in a
  Filter what the platform now does natively
### Option e: External Knowledge connection pointed at `knowledge`, plus kb_search
- **Pros**: one index, one owner, zero drift by construction; native Knowledge
  UX and `#`-attach; read-only matches the ownership model; no second embedder
- **Cons**: OpenWebUI must run bge-small locally; no payload filtering on the
  external path; weak citation labels; DB-only config

## Decision
We will use **Option e**: a single External Knowledge connection to the existing
Qdrant collection `knowledge`, **and** keep `kb_search` exposed as a tool.

One read plane, two front doors. Both read the same collection, so neither can
drift from the other. The external KB gives `#`-attach and native citations; the
tool gives filtered retrieval (`source_type`, `path`) and `kb_get_document`,
which the external path cannot do.

## Rationale
The original blocker was schema and ownership, and Option e removes both: the
collection keeps its own schema, and OpenWebUI is a read-only consumer. This
serves the first decision driver — chat and agents retrieving identically —
better than Option d, which only approximated it through a Filter.

## Consequences
### Positive
- Agents and chat retrieve from the same points; the knowledge repo owns indexing
- No second embedder, no second index, no reindex ownership split
- Removes the hosted per-query embedding cost (local bge-small replaces
  text-embedding-3-small)
### Negative
- **No filtering on the external path.** `query_points` is called without
  `query_filter`, so one external KB is the whole collection. A KB scoped to
  `source_type=youtube` is not expressible; `kb_search` remains the only
  filtered reader.
- **Weak citations.** `_retrieve_qdrant` maps only content/metadata/document_id/
  score. `title`/`source`/`url`/`page` are read from the point root, where they
  do not exist, and `metadata['url']` is then overwritten with `None` — so
  clickable citation links are impossible. Mitigated by setting
  `metadata_field: payload` so `path`/`heading`/`tags` reach metadata, and by
  having `kb sync` write a `source` key.
- **Bypasses hybrid search, reranking and `RAG_RELEVANCE_THRESHOLD.`** The
  external branch assigns `query_result` directly, skipping `query_collection`.
  Costs nothing today (the collection is dense-only) but a future reranker will
  not apply to this path.
- **Multi-query truncation.** With query expansion, per-query results are
  concatenated and truncated without re-sorting, so the first query can consume
  the whole budget.
- **Not declarable in git.** Belongs to the ADR-0004 reconciler.
- `auth_mode` is hardcoded `service_account`: every user queries Qdrant as one
  credential. Acceptable at one human user; see ADR-0002.
- OpenWebUI's embedding model is now load-bearing for cross-system correctness.
  Changing `RAG_EMBEDDING_MODEL` silently breaks retrieval rather than failing.

## Implementation Notes
- Chart 18.0.0 / app 0.13.0. **0.13.0 ships DB migrations** — back up the SQLite
  volume before upgrading (ADR-0003 is still unimplemented; state is SQLite on a
  PVC with `helm.sh/resource-policy: keep`).
- values.yaml: `QDRANT_URI=http://qdrant.data.svc.cluster.local:6333`,
  `RAG_EMBEDDING_ENGINE=""`, `RAG_EMBEDDING_MODEL=BAAI/bge-small-en-v1.5`,
  `RAG_OPENAI_API_BASE_URL` removed.
- Leave `RAG_EMBEDDING_QUERY_PREFIX` unset. fastembed's `query_embed` for
  bge-small applies no prefix (it delegates to `embed`), and OpenWebUI's default
  is `None` — so the spaces match only while both stay unset.
- **`rag.embedding_engine` and `rag.embedding_model` are PersistentConfig**: env
  seeds first boot only, and the DB already holds `openai`/`embeddings`. The
  values.yaml change alone does not take effect — reset them via the admin UI or
  `/api/v1/retrieval/config` at cutover. Safe to reset: no knowledge bases,
  files, or `open-webui_*` collections exist.
- External connection: provider `qdrant`, endpoint
  `http://qdrant.data.svc.cluster.local:6333`, `auth_config.api_key` from the
  Qdrant key; KB source `{type: collection, name: knowledge}`,
  `metadata_field: payload` (leave `content_field` at its `payload.text`
  default, which already matches the payload).
- `/external/connections/{id}/test` does not test connectivity — it only checks
  two fields are non-empty. Use `/external/source/test` or `/retrieve-test`.
- Local embedding needs sentence-transformers + torch in the 2Gi limit
  (confirmed present in the non-slim image: 5.5.1 / 2.9.1+cpu) and first-boot
  egress to huggingface.co. The model cache lands on the PVC.
- Knowledge repo: named sparse BM25 vector + RRF; `parent_text` in the Qdrant
  payload (today it never leaves LanceDB); `source`/`title` on tree points for
  citation labels.
- Narrow `KB_INGEST_PATH_PREFIXES` to `tree/youtube/`. `kb sync` writes no
  `doc_hash` while `kb-ingest` dedups on it, so a tree-owned path looks new to
  the write plane, which then re-embeds and `delete_path`s the tree's points.
  The shipped default `tree/` does not prevent this.
- The golden set cannot currently measure this path: 6 cases, 3 with paths that
  no longer exist (recall capped at 0.50), and `kb/eval.py` exercises the local
  LanceDB hybrid path rather than Qdrant. Fix before tuning retrieval.
- Treat `kb_search` and external-knowledge output as untrusted text.

## Related Decisions
- ADR-0003, ADR-0004, ADR-0007, ADR-0009
