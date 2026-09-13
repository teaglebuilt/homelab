# RAG

## Storage

1. Qdrant
2. S3 Vectors // TODO: not implemented yet (vector backup)

## Knowledge Management

Obsidian vault and tool to manage knowledge. From ingesting or querying knowledge data.

Repo: github.com/teaglebuilt/knowledge
Architecture: https://github.com/teaglebuilt/knowledge-tree/blob/master/docs/architecture.md

## Knowledge Retrievel

### Examples

1. **Manual** - Can be done in knowledge repo by using the tool or a claude skill.
2. **Scheduled** - Batch Job on Kubernetes
3. **Webhook** - Like post or video in rss feed and its ingested.

## Knowledge Storage

Two planes, deliberately separated. The **write plane** runs off-cluster on the
laptop and owns chunking, embedding, and the authoritative index. The **read
plane** runs in-cluster and is stateless — it embeds a query and searches the
Qdrant mirror. They meet only at the `knowledge` collection.

### Write plane — ingest and mirror

Manual (`make ingest`) or scheduled. LanceDB is authoritative; Qdrant is a replay
target so cluster workloads can query the same corpus.

```
 tree/**/*.md                  kb ingest                        kb sync
 (Obsidian vault)          ┌──────────────────────┐     ┌──────────────────────┐
        │                  │ parse frontmatter    │     │ replay LanceDB rows  │
        └─────────────────▶│ split on headings    │     │ upsert id=UUID(      │
                           │ child + parent chunk │     │   sha256(chunk_id))  │
                           │ embed bge-small 384d │     └──────────┬───────────┘
                           └──────┬───────────────┘                │
                                  │                                │
                  ┌───────────────┴───────────────┐                │
                  ▼                               ▼                ▼
          .lancedb/  chunks                   kb.duckdb   Qdrant `knowledge`
          vector + BM25 FTS                   hash gate     cluster mirror
           [authoritative]                   chunk meta   dense vectors only
```

`doc_hash` (sha256 of the normalized body) is the incremental gate — unchanged
files are never re-embedded. `chunk_id` is `path::doc_hash[:8]::index`, so a
re-sync upserts in place rather than duplicating.

### Read plane — one chat turn

OpenWebUI never embeds the knowledge tree and never reads the `knowledge`
collection directly. It reaches it through a tool call, which keeps a single
chunking strategy and a single embedding model in play.

```
 (1) user prompt
        │
        ▼
 ┌─────────────────────────────────┐
 │  open-webui-0          ns: ai   │  image 0.6.41
 └───┬───────────────────────▲─────┘
     │ (2) chat/completions  │ (6) grounded answer + citations
     │     tools=[kb_search] │
     ▼                       │
 ┌─────────────────────────────────┐
 │  agentgateway-proxy             │  ns: agentgateway-system
 │  /vllm  /anthropic  /mcp        │
 └───┬───────────────────────▲─────┘
     │ (3) tool_call         │ (5) tool result -> 2nd completion
     │     kb_search{q, k}   │
     ▼                       │
 ┌───────────────────────────┴───────────────────────┐
 │  kb-retrieval                     ns: ai          │
 │  ───────────────────────────────────────────────  │
 │   a. embed query    fastembed bge-small 384d      │
 │   b. ANN search     ──────────────┐               │
 │   c. rerank         [TODO] cross-encoder 50->5    │
 │   d. parent expand  [TODO] needs payload field    │
 │   e. abstain        [TODO] score threshold        │
 └───────────────────────────────────┼───────────────┘
                                     │ (4) k=50, cosine
                                     ▼
                    ┌──────────────────────────────────┐
                    │  Qdrant    collection:           │
                    │    `knowledge`   384-d, cosine   │
                    │    payload: chunk_id, path,      │
                    │             heading, text, tags  │
                    └──────────────────────────────────┘
```

The embedding model on both sides of the arrow is the same `BAAI/bge-small-en-v1.5`.
That is the load-bearing invariant: `kb-retrieval` must embed queries with the
exact model `kb ingest` used, or the vectors are not comparable.

### Qdrant tenancy

One Qdrant instance, two unrelated tenants. They never share a collection.

```
  Qdrant
   ├── knowledge            <- kb sync. The tree. Read via kb_search tool.
   └── open-webui_*         <- OpenWebUI's own RAG. Per-file/per-KB collections
                               created from chat file uploads only. Different
                               embedding model, different chunker, owned end to
                               end by OpenWebUI's metadata DB.
```

### Why not point OpenWebUI's RAG at the `knowledge` collection

Three independent blockers:

1. **Different embedding spaces.** `kb` embeds with `bge-small-en-v1.5` (384-d,
   local fastembed). OpenWebUI's `RAG_EMBEDDING_ENGINE` points at a different
   model entirely. Cross-model cosine similarity is noise.
2. **OpenWebUI owns its collection namespace.** `QDRANT_URI` declares where its
   *own* store lives. It prefixes and creates collections per file/KB; it has no
   mechanism to query a foreign one.
3. **The UI's source of truth is OpenWebUI's metadata DB.** A Knowledge Base is
   DB rows plus derived vectors. Points written straight into Qdrant have no
   rows, so they are invisible to the knowledge picker, `#` references, and
   citations.

### Alternative: `oikb` document sync

The official companion tool (`pip install oikb`) mirrors files into a Knowledge
Base over REST — sha256 manifest to `/sync/diff`, upload deltas, propagate
deletes. It would give native citation UX at the cost of a second chunker,
second embedding model, and a golden set that no longer describes what
OpenWebUI actually retrieves.

**Requires OpenWebUI 0.9.6+ (chart 14.11.0+). Cluster is on 0.6.41 /
chart 8.19.0, so this path is gated behind a major upgrade.**

### Known drift

| Item | Expected | Actual |
|---|---|---|
| Qdrant service | `qdrant.data.svc.cluster.local` | lives in `default` ns — NXDOMAIN from `ai` |
| Qdrant API key | SOPS `qdrant-secrets` | plaintext `apiKey:` inline in the kustomization |
| Embeddings route | `/v1/embeddings` on agentgateway | no such route; `RAG_EMBEDDING_MODEL=embeddings` resolves to nothing |
| Collections | `knowledge` populated | Qdrant empty — nothing has ever synced |
| Hybrid retrieval | dense + BM25 | cluster side is dense-only; `sync.py` pushes no sparse vectors |
