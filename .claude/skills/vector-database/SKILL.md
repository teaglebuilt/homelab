---
name: vector-database
description: "Use for all vector database work — pgvector schema design, Weaviate collection creation, RAG pipeline scaffolding, embedding model selection, index tuning (HNSW vs IVFFlat), and embedding model migration. Triggers on: 'vector search', 'pgvector', 'weaviate', 'embedding', 'RAG pipeline', 'semantic search', 'hybrid search', 'nearest neighbor', 'vector index', 're-embedding', 'ANN index'. Use whenever vectors, embeddings, or similarity search are involved, even if not explicitly named."
allowed-tools: Read, Glob, Grep
metadata:
  triggers: pgvector, weaviate, embedding, vector search, RAG pipeline, semantic search, hybrid search, vector index, re-embedding, ANN index, HNSW, IVFFlat, quantization, INT8, product quantization, binary quantization, HNSW benchmark, vector memory, index benchmarking
  related-skills: weaviate, weaviate-cookbooks, agentic-ai-dev, database-schema-designer
  domain: backend
  role: specialist
  scope: implementation
  output-format: code
last-reviewed: "2026-03-15"
---

# Vector Database Skill

## Iron Law

**Pin dimensions at model selection.** The embedding dimension must match the model exactly and is set once — changing models requires a full re-embedding migration. Store `embedding_model varchar(100)` alongside every vector column so the model is always auditable.

---

## Embedding Model Selection

Choose model before writing any schema. Dimension determines index shape.

| Model | Dims | Notes |
|-------|------|-------|
| `text-embedding-3-small` (OpenAI) | 1536 | Best cost/quality for most cases |
| `text-embedding-3-large` (OpenAI) | 3072 | Max OpenAI quality, 2× cost |
| `embed-english-v3.0` (Cohere) | 1024 | Native Weaviate integration |
| `voyage-3-large` (Voyage AI) | 1024 | Top retrieval benchmarks |
| `nomic-embed-text` (local) | 768 | Free, on-prem, no API call |

**Rule:** Once a dimension is written into schema, it cannot change without `/migrate-embedding-model`.

---

## pgvector

### When to Use
- Data lives in PostgreSQL (tickets, vendors, invoices, tenant records)
- You need vector search + relational JOINs in a single query
- Filtering on structured columns (city, category, rating) alongside semantic search

### Vector Column Declaration

```sql
-- ALWAYS enable extension in migration up
CREATE EXTENSION IF NOT EXISTS vector;

-- Column: dimension must match model exactly
ALTER TABLE vendors ADD COLUMN embedding vector(1536);
ALTER TABLE vendors ADD COLUMN embedding_model varchar(100) DEFAULT 'text-embedding-3-small';
```

### Distance Operators

| Operator | Distance Type | Use When |
|----------|--------------|----------|
| `<->` | L2 (Euclidean) | Default; requires L2-normalized embeddings |
| `<#>` | Negative inner product | Dot-product similarity (fast for normalized vecs) |
| `<=>` | Cosine | Cosine similarity; works unnormalized |

**Critical:** The operator used in queries MUST match the operator used in `CREATE INDEX`. Mismatch = full table scan silently.

### Index Selection

| | HNSW | IVFFlat |
|--|------|---------|
| **Build speed** | Slow, high memory | Fast, needs existing data |
| **Query recall** | Higher (~0.99) | Tunable via `probes` |
| **Use when** | >100K rows, production | Dev / budget-constrained / <100K rows |
| **Update behavior** | Good — no rebuild needed | Degrades; needs ANALYZE after bulk inserts |

```sql
-- HNSW (production default)
CREATE INDEX ON vendors USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- IVFFlat (dev/budget)
CREATE INDEX ON vendors USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
-- After bulk insert: ANALYZE vendors;
```

### Example Query Pattern (vendor matching)

```sql
SELECT v.id, v.name, v.city, v.rating,
       1 - (v.embedding <=> $1::vector) AS similarity
FROM vendors v
WHERE v.city = $2
  AND v.category = $3
  AND v.rating >= $4
  AND v.embedding IS NOT NULL
ORDER BY v.embedding <=> $1::vector
LIMIT 10;
```

For full migration template → see `references/pgvector-migration-template.md`

---

## Weaviate

### When to Use
- Data lives outside PostgreSQL (scraped text, PDFs, docs, external reviews)
- You need native hybrid search (BM25 + vector) with fusion control
- Multi-tenancy (one collection shared across tenants)
- Phase 2+ RAG against GCS / external document stores

### Collection Schema Essentials

```python
import weaviate
import weaviate.classes as wvc

client = weaviate.connect_to_weaviate_cloud(
    cluster_url=os.environ["WEAVIATE_URL"],
    auth_credentials=wvc.init.Auth.api_key(os.environ["WEAVIATE_API_KEY"]),
)

# ALWAYS set multi_tenancy at creation — cannot change later
client.collections.create(
    name="VendorReview",
    vectorizer_config=wvc.config.Configure.Vectorizer.text2vec_openai(
        model="text-embedding-3-small",
    ),
    vector_index_config=wvc.config.Configure.VectorIndex.hnsw(
        distance_metric=wvc.config.VectorDistances.COSINE,
    ),
    multi_tenancy_config=wvc.config.Configure.multi_tenancy(enabled=True),
    properties=[
        wvc.config.Property(name="text", data_type=wvc.config.DataType.TEXT),
        wvc.config.Property(name="source", data_type=wvc.config.DataType.TEXT),
        wvc.config.Property(name="vendor_id", data_type=wvc.config.DataType.TEXT),
    ],
)
```

### Query Patterns

```python
collection = client.collections.get("VendorReview")

# nearText (semantic)
result = collection.query.near_text(query="plumber emergency repair", limit=5)

# Hybrid search (BM25 + vector)
# alpha=1.0 = pure vector | alpha=0.0 = pure BM25
result = collection.query.hybrid(
    query="24-hour plumber",
    alpha=0.75,
    fusion_type=wvc.query.HybridFusion.RELATIVE_SCORE,
    limit=10,
)
```

**Fusion algorithms:**
- `RANKED_FUSION` — rank-based merge; stable, good default
- `RELATIVE_SCORE_FUSION` — score-normalized merge; better when score magnitude matters

For named vectors and multi-tenant patterns → see `references/weaviate-collection-patterns.md`

---

## Two-Tier Architecture Decision

When building a system with both structured and unstructured data:

| Tier | Store | Use For |
|------|-------|---------|
| 1 | pgvector (in Cloud SQL) | Data with a DB row — vendors, tickets, invoices, tenant records |
| 2 | Weaviate Serverless | Data outside DB — scraped reviews, PDFs in GCS, external docs |

**Rule:** Keep data in the tier where it originates. Don't sync Postgres rows to Weaviate at MVP — async sync lag introduces consistency bugs. Move to Weaviate only when matching against external documents.

---

## Slash Commands

- `/design-vector-schema` — pgvector migration SQL from model + row count + metric
- `/design-weaviate-collection` — Weaviate Python collection from vectorizer + schema
- `/scaffold-rag-pipeline` — Full RAG pipeline: chunk → embed → store → retrieve → rerank
- `/migrate-embedding-model` — Re-embedding migration plan + reversible SQL
- `/tune-vector-index` — HNSW vs IVFFlat recommendation + tuned params

## Reference Files

| File | Content | When to Use |
|------|---------|-------------|
| `references/pgvector-migration-template.md` | Full migration SQL with up/down, index, metadata column | pgvector schema design |
| `references/weaviate-collection-patterns.md` | Named vectors, multi-tenancy, advanced queries | Weaviate collection design |
| `references/rag-pipeline-patterns.md` | Chunking strategies, retrieval, reranking, LangChain wiring | Building RAG pipelines |
| `references/embedding-migration-guide.md` | Step-by-step model switching procedure | Re-embedding migrations |
| `references/vector-index-tuning-playbook.md` | Quantization strategies, HNSW benchmarking, memory estimation, Qdrant config | Index tuning and performance optimization |
| `references/ann-vs-knn.md` | KNN vs ANN tradeoffs, HNSW/IVFFlat tuning, recall measurement, high-risk scoped verification pattern | Choosing and tuning retrieval index strategy |
| `references/rag-ingest-checklist.md` | Production ingestion checklist: embeddings, chunking, null guards, multi-tenancy | Safe data ingestion into vector stores |
| `references/tier-1-tier-2-decision.md` | Decision framework: pgvector (hot path, SQL joins) vs Weaviate (cold path, pure semantic) | Choosing the right vector store for a use case |

## Documentation Sources

Before generating code, consult these sources for current APIs:

| Source | Tool | Purpose |
|--------|------|---------|
| pgvector | `Context7` MCP (`pgvector` library) | Vector operators, index syntax, distance functions |
| Weaviate Python v4 | `weaviate-docs` MCP | Collection API, query patterns, named vectors |
| OpenAI Embeddings | `Context7` MCP (`openai` library) | text-embedding-3-small/large, dimensions, pricing |
| Cohere Embed | `Context7` MCP (`cohere` library) | embed-english-v3.0, batch embedding |

## Post-Code Review

After writing vector database code, dispatch:
- `pgvector-schema-reviewer` — operator/index alignment, dimension match, null guards, reversible migrations
- `weaviate-schema-reviewer` — v4 client API, multi-tenancy declaration, distance metric
- `rag-pipeline-reviewer` — model pinning, batch embedding, silent retrieval failure risks
- `postgresql-database-reviewer` — for the broader migration (indexes, constraints, performance)
