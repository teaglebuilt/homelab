# RAG Pipeline Patterns

## Table of Contents
1. [Chunking Strategies](#chunking-strategies)
2. [Embedding Pipeline](#embedding-pipeline)
3. [pgvector Retrieval](#pgvector-retrieval)
4. [Weaviate Retrieval](#weaviate-retrieval)
5. [Reranking](#reranking)
6. [LangChain Integration](#langchain-integration)
7. [Two-Stage Retrieval](#two-stage-retrieval)
8. [Model-Specific Embedding Patterns](#model-specific-embedding-patterns)

---

## Chunking Strategies

Choose chunking before writing any pipeline code.

| Strategy | Chunk Size | Overlap | Use When |
|----------|-----------|---------|---------|
| Fixed token | 512 tokens | 50 | General text, uniform docs |
| Sentence | 3-5 sentences | 1 sentence | Conversational text, Q&A |
| Paragraph | 1 paragraph | 0 | Structured docs, reports |
| Semantic | Variable | N/A | When chunk coherence matters most |
| Recursive | 1000 chars → split at `\n\n` → `\n` → ` ` | 200 | Unstructured text (default for most RAG) |

```python
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Production default — handles most document types
splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
    length_function=len,
    separators=["\n\n", "\n", ". ", " ", ""],
)

chunks = splitter.split_text(document_text)
```

---

## Embedding Pipeline

```python
import asyncio
from openai import AsyncOpenAI
from typing import List

client = AsyncOpenAI()

# Batch embedding with rate limiting
async def embed_texts(
    texts: List[str],
    model: str = "text-embedding-3-small",
    batch_size: int = 100,
) -> List[List[float]]:
    """Embed texts in batches. model dimension must match schema."""
    all_embeddings = []

    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        response = await client.embeddings.create(
            input=batch,
            model=model,
        )
        embeddings = [item.embedding for item in response.data]
        all_embeddings.extend(embeddings)

    return all_embeddings


# Pinned model wrapper — prevents accidental model drift
class EmbeddingService:
    MODEL = "text-embedding-3-small"  # pin here, not at call site
    DIMS = 1536

    def __init__(self):
        self._client = AsyncOpenAI()

    async def embed(self, text: str) -> List[float]:
        response = await self._client.embeddings.create(
            input=text,
            model=self.MODEL,
        )
        return response.data[0].embedding

    async def embed_batch(self, texts: List[str]) -> List[List[float]]:
        return await embed_texts(texts, model=self.MODEL)
```

---

## pgvector Retrieval

```python
import asyncpg
from typing import List, Tuple

async def search_vendors(
    pool: asyncpg.Pool,
    query_embedding: List[float],
    city: str,
    category: str,
    limit: int = 10,
) -> List[dict]:
    """Semantic vendor search with structured filters."""
    rows = await pool.fetch(
        """
        SELECT
            id,
            name,
            city,
            category,
            rating,
            1 - (embedding <=> $1::vector) AS similarity
        FROM vendors
        WHERE city = $2
          AND category = $3
          AND embedding IS NOT NULL
        ORDER BY embedding <=> $1::vector
        LIMIT $4
        """,
        query_embedding,
        city,
        category,
        limit,
    )
    return [dict(r) for r in rows]


# With dynamic filters
async def search_with_filters(
    pool: asyncpg.Pool,
    query_embedding: List[float],
    filters: dict,
    limit: int = 10,
) -> List[dict]:
    """Build filter clause dynamically."""
    where_clauses = ["embedding IS NOT NULL"]
    params = [query_embedding]
    idx = 2

    if city := filters.get("city"):
        where_clauses.append(f"city = ${idx}")
        params.append(city)
        idx += 1

    if min_rating := filters.get("min_rating"):
        where_clauses.append(f"rating >= ${idx}")
        params.append(min_rating)
        idx += 1

    params.append(limit)

    sql = f"""
        SELECT id, name, 1 - (embedding <=> $1::vector) AS similarity
        FROM vendors
        WHERE {" AND ".join(where_clauses)}
        ORDER BY embedding <=> $1::vector
        LIMIT ${idx}
    """

    rows = await pool.fetch(sql, *params)
    return [dict(r) for r in rows]
```

---

## Weaviate Retrieval

```python
import weaviate
import weaviate.classes as wvc

def retrieve_vendor_reviews(
    client: weaviate.WeaviateClient,
    query: str,
    vendor_id: str | None = None,
    alpha: float = 0.75,
    limit: int = 10,
) -> list[dict]:
    """Hybrid search on Weaviate with optional vendor filter."""
    collection = client.collections.get("VendorReview")

    filters = None
    if vendor_id:
        filters = wvc.query.Filter.by_property("vendor_id").equal(vendor_id)

    result = collection.query.hybrid(
        query=query,
        alpha=alpha,
        fusion_type=wvc.query.HybridFusion.RELATIVE_SCORE,
        filters=filters,
        limit=limit,
        return_metadata=wvc.query.MetadataQuery(score=True),
    )

    return [
        {
            "text": obj.properties["text"],
            "source": obj.properties.get("source"),
            "score": obj.metadata.score,
        }
        for obj in result.objects
    ]
```

---

## Reranking

**Rule:** Always rerank for production. Initial retrieval (vector/hybrid) optimizes recall; reranking optimizes precision.

```python
import cohere

co = cohere.Client(os.environ["COHERE_API_KEY"])

def rerank_results(
    query: str,
    documents: list[dict],
    text_key: str = "text",
    top_n: int = 5,
    model: str = "rerank-english-v3.0",
) -> list[dict]:
    """Rerank retrieved documents by relevance to query."""
    if not documents:
        return []

    texts = [doc[text_key] for doc in documents]

    reranked = co.rerank(
        model=model,
        query=query,
        documents=texts,
        top_n=top_n,
    )

    return [
        {
            **documents[r.index],
            "rerank_score": r.relevance_score,
        }
        for r in reranked.results
    ]


# Full pipeline: retrieve → rerank
async def retrieve_and_rerank(
    query: str,
    query_embedding: list[float],
    pool: asyncpg.Pool,
    top_k_retrieve: int = 20,  # retrieve more, rerank down
    top_k_final: int = 5,
) -> list[dict]:
    candidates = await search_vendors(pool, query_embedding, limit=top_k_retrieve)
    return rerank_results(query, candidates, top_n=top_k_final)
```

---

## LangChain Integration

For LangChain-based pipelines, use `PGVector` from `langchain_community.vectorstores.pgvector` with `OpenAIEmbeddings(model=EMBEDDING_MODEL)`. Set `distance_strategy="cosine"` to match the index ops class. See the `agentic-ai-dev` skill for full LangGraph + RAG patterns.

---

## Two-Stage Retrieval

Pattern: pgvector (structured DB data) → Weaviate (external docs) → merge → rerank.

Key rules:
- Retrieve `N×3` candidates from each stage, rerank down to `N` final
- Tag each result with `"source": "internal"` or `"source": "external"` before merging
- Run `rerank_results(query, all_candidates)` across the merged list — not separately per stage
- Log `pg_candidates` and `weaviate_candidates` counts for observability

Full pattern: use `/scaffold-rag-pipeline --storage=both` to generate the complete implementation.

---

## Model-Specific Embedding Patterns

The generic `EmbeddingService` above works for OpenAI models. Some open-source models require
model-specific pre-processing to achieve production-quality retrieval.

### BGE Models — Query Instruction Prefix

BGE models (e.g. `BAAI/bge-large-en-v1.5`, `bge-m3`) require a query-time instruction prefix.
Documents are embedded without the prefix; queries get the prefix. Skipping this degrades
retrieval quality significantly.

```python
from sentence_transformers import SentenceTransformer
import numpy as np

class BGEEmbedder:
    """
    BGE (BAAI General Embedding) requires query instruction prefix.
    Documents: embed as-is.
    Queries:   prepend instruction prefix before embedding.
    """

    QUERY_PREFIX = "Represent this sentence for searching relevant passages: "

    def __init__(self, model_name: str = "BAAI/bge-large-en-v1.5", device: str = "cpu"):
        self.model = SentenceTransformer(model_name, device=device)

    def embed_query(self, query: str) -> list[float]:
        """Embed a query with the BGE instruction prefix."""
        prefixed = f"{self.QUERY_PREFIX}{query}"
        return self.model.encode(prefixed, normalize_embeddings=True).tolist()

    def embed_document(self, text: str) -> list[float]:
        """Embed a document — no prefix for indexing."""
        return self.model.encode(text, normalize_embeddings=True).tolist()

    def embed_batch(self, texts: list[str], is_query: bool = False) -> list[list[float]]:
        if is_query:
            texts = [f"{self.QUERY_PREFIX}{t}" for t in texts]
        return self.model.encode(texts, normalize_embeddings=True, batch_size=32).tolist()
```

**LangGraph integration:**
```python
bge = BGEEmbedder()

def retrieval_node(state: AgentState) -> AgentState:
    query_embedding = bge.embed_query(state["question"])
    results = await search_pgvector(pool, query_embedding)
    return {"retrieved_docs": results}
```

**ADK integration:**
```python
from google.adk.agents import LlmAgent
from google.adk.tools import FunctionTool

bge = BGEEmbedder()

@FunctionTool
def search_knowledge_base(query: str) -> list[dict]:
    """Search the knowledge base using BGE embeddings."""
    query_embedding = bge.embed_query(query)
    return search_pgvector_sync(pool, query_embedding)
```

---

### E5 Models — Query/Passage Instruction Prefixes

E5 models (e.g. `intfloat/multilingual-e5-large`) use `"query: "` and `"passage: "` prefixes.
Both query AND document embeddings need the prefix — asymmetric prefixes are required.

```python
from sentence_transformers import SentenceTransformer

class E5Embedder:
    """
    E5 (multilingual-e5-large, e5-large-v2) requires asymmetric prefixes.
    Queries:   prefix with "query: "
    Documents: prefix with "passage: "
    Mixing up prefixes causes significant retrieval quality degradation.
    """

    def __init__(self, model_name: str = "intfloat/multilingual-e5-large", device: str = "cpu"):
        self.model = SentenceTransformer(model_name, device=device)

    def embed_query(self, query: str) -> list[float]:
        return self.model.encode(f"query: {query}", normalize_embeddings=True).tolist()

    def embed_document(self, text: str) -> list[float]:
        return self.model.encode(f"passage: {text}", normalize_embeddings=True).tolist()

    def embed_batch_documents(self, texts: list[str]) -> list[list[float]]:
        prefixed = [f"passage: {t}" for t in texts]
        return self.model.encode(prefixed, normalize_embeddings=True, batch_size=32).tolist()
```

**When to use E5 over BGE:**
- Multilingual content (E5 supports 100+ languages)
- BGE: best for English-only with highest single-language accuracy
- E5: best for multilingual or when a single model must handle multiple languages

---

### OpenAI Matryoshka Dimension Reduction

OpenAI's `text-embedding-3-small` and `text-embedding-3-large` support Matryoshka embeddings:
truncating to fewer dimensions reduces storage and query cost with minimal quality loss.

```python
from openai import AsyncOpenAI

client = AsyncOpenAI()

async def embed_with_reduced_dims(
    texts: list[str],
    model: str = "text-embedding-3-small",
    dimensions: int = 512,   # 1536 full → 512 reduced = 67% smaller, ~2% quality loss
) -> list[list[float]]:
    """
    Embed with Matryoshka dimension reduction.
    Supported only by text-embedding-3-* models.

    Dimension trade-offs (text-embedding-3-small):
      1536 → full accuracy, full storage
       512 → ~98% accuracy, 67% storage reduction
       256 → ~95% accuracy, 83% storage reduction
    """
    response = await client.embeddings.create(
        input=texts,
        model=model,
        dimensions=dimensions,
    )
    return [item.embedding for item in response.data]


# Pinned reduced-dim service
class ReducedEmbeddingService:
    """Use when storage cost is a concern and ~2% quality loss is acceptable."""
    MODEL = "text-embedding-3-small"
    DIMS = 512  # update pgvector schema column to vector(512) to match

    def __init__(self):
        self._client = AsyncOpenAI()

    async def embed(self, text: str) -> list[float]:
        response = await self._client.embeddings.create(
            input=text,
            model=self.MODEL,
            dimensions=self.DIMS,
        )
        return response.data[0].embedding
```

**Schema requirement:** If using reduced dimensions, the pgvector column must match:
```sql
-- For 512-dim reduced embeddings
ALTER TABLE documents ADD COLUMN embedding vector(512);
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops);
```

**Decision guide:**

| Scenario | Embedder | Dimensions |
|----------|----------|------------|
| English RAG, best accuracy | `BGEEmbedder` (bge-large-en-v1.5) | 1024 |
| Multilingual RAG | `E5Embedder` (multilingual-e5-large) | 1024 |
| API-based, full accuracy | `EmbeddingService` (text-embedding-3-small) | 1536 |
| API-based, cost-optimized | `ReducedEmbeddingService` | 512 |
| Code search | OpenAI `text-embedding-3-small` or Voyage `voyage-code-3` | 1536 |

---

## Server-Side Vectorizer vs Pre-Computed Vectors (Path A vs Path B)

When writing to a vector store you have two choices for who runs the embedding:

| | Path A — Server vectorizer | Path B — Pre-computed (`Vectorizer.none()`) |
|---|---|---|
| **Setup** | Schema declares `text2vec_*`; you write text; vector store calls embedding API | Schema declares `Vectorizer.none()`; you embed in app code; you pass the vector |
| **PII control** | Raw text leaves your service | Redact → embed → store all in your code |
| **Cost tracking** | Hidden inside vector DB invoice | Logged once via `embed_text` event |
| **Local dev** | Needs the embedding module loaded (e.g. `text2vec-google`) | Works with vanilla Weaviate |
| **Model migration** | Re-config vector store | Update env var, re-ingest |
| **Multi-store RAG** | Each store owns its own pipeline | One embed function feeds all stores |

**Best practice:** Path B always for RAG ingest.
PII redaction + single-source-of-cost-truth + multi-store
support (pgvector + Weaviate) make Path A unworkable for production.
`WeaviateWriter.ensure_collection()` should hardcode `Configure.Vectorizer.none()`.

**Industry evidence — every shipped production AI product uses Path B:**

| Product | Vector store | Embedding path |
|---|---|---|
| Notion AI | Pinecone | Path B (Pinecone has no Path A) |
| GitHub Copilot for Docs | Azure AI Search | Path B |
| Anthropic Contextual Retrieval reference | Pinecone / Voyage | Path B |
| Linear "Search workspace" | Pinecone | Path B |
| Perplexity | Multi-store | Path B |
| Pinecone, Qdrant, pgvector, Vespa | (themselves) | Path B is the ONLY mode |

Path A exists for hackathons, demos, and starter tutorials. Production teams
without exception migrate to Path B within 6-12 months when PII, cost
tracking, model versioning, or multi-store needs arrive.

```python
# ✓ — Path B canonical pattern
self._client.collections.create(
    name="LeaseClauses",
    vectorizer_config=Configure.Vectorizer.none(),
    multi_tenancy_config=Configure.multi_tenancy(enabled=True, auto_tenant_creation=True),
    properties=[
        Property(name="text", data_type=DataType.TEXT),
        Property(name="embedding_model", data_type=DataType.TEXT),  # version stamp
        # ...
    ],
)

# Write path: embed → write
vec, meta = embed_text_for_storage(chunk["text"])
chunk["text"] = meta["redacted_text"]    # never store raw PII
collection.with_tenant(landlord_id).data.insert(properties=chunk, vector=vec)
```

---

## Tier 1 vs Tier 2 — Multi-Store RAG Architecture

Production RAG systems rarely run on one store. The two-tier split below — same pattern used by Stripe, Notion, Linear, GitHub Copilot — balances relational + semantic workloads.

| | Tier 1 — pgvector | Tier 2 — Weaviate |
|---|---|---|
| **Job** | Vectors that live alongside relational data | Pure unstructured text RAG corpus |
| **Typical uses** | Entity profiles, policy rule embeddings | Document clause chunks, FAQ corpus |
| **Query style** | Mixed — SQL JOIN + WHERE + vector | Pure semantic + hybrid BM25 |
| **Optimal latency** | <50ms (user-blocking matching) | <500ms (streamed chat response) |
| **Scale** | Millions of rows per tenant | Billions of chunks across tenants |
| **Consistency** | ACID with PostgreSQL | Eventual (writes → readable in seconds) |
| **Multi-tenancy** | `WHERE tenant_id = ?` (logical filter) | `with_tenant()` (physical shard) |
| **Hybrid search** | DIY (tsvector + cosine) | Native `hybrid()` query |

**Decision rule:**
- If the query needs SQL JOIN, PostGIS geo, or relational filters → **Tier 1 (pgvector)**
- If the query is "find similar text under tenant T" with hybrid BM25+vector → **Tier 2 (Weaviate)**

**Why split at all?** Putting everything in pgvector hits HNSW degradation past ~10M vectors per table; putting everything in Weaviate forces denormalizing relational data and loses native PostGIS. The split is not about size — it's about query characteristics.

---

## Best-in-Class Retrieval Stack

Single-stage dense retrieval plateaus at recall@5 ≈ 0.75–0.80 on long-document QA (BEIR, MTEB benchmarks). To clear 0.85+ on lease QA / legal docs / customer-support corpora, **three techniques stacked are mandatory** — not optional:

### 1. Hybrid search (BM25 + vector)

Pure vector misses exact phrases ("$2,400", "Section 5.3", proper names). BM25 alone misses paraphrase. Combine via score fusion:

```python
results = collection.with_tenant(landlord_id).query.hybrid(
    query="Can I have a cat?",
    vector=query_embedding,
    alpha=0.5,                    # 0.5 = balanced; tune per golden set
    limit=20,                     # over-fetch for reranker
).objects
```

Tune `alpha` empirically against `tests/golden/rag/<corpus>/`:
- `alpha=0` → pure BM25 (exact-match heavy)
- `alpha=1` → pure vector (semantic only)
- `alpha=0.5` → starting point; often optimal at ~0.5-0.7

### 2. Reranking (top-N → top-k)

Lifts recall@5 from ~0.78 → 0.92 on long-document QA. Two options:

| Option | Implementation | Trade-off |
|---|---|---|
| **Cohere/Voyage/BGE rerank via MCP** | New MCP tool wrapping the reranker API | Network hop; managed quality |
| **LLM-based LlmAgent rerank** | Inline `LlmAgent` step that scores candidates | Same model family as judge; one less vendor |

```python
# Pattern: hybrid → top-N=20 → rerank → top-k=5 → LLM
hybrid_candidates = collection.query.hybrid(...).objects[:20]
ranked = await reranker.rerank(query=q, documents=[c.text for c in hybrid_candidates])
top_k = [hybrid_candidates[i] for i in ranked[:5]]
# Pass top_k to the answering LLM
```

Single-stage = forbidden for production lease QA / legal RAG.

### 3. Contextual chunking (Anthropic 2024-09)

Plain section-body chunks miss cross-section references ("see Section 5.3" in Section 12). Solution: prepend section context to each chunk's `text` BEFORE embedding:

```python
# At chunk_agent — prepend lease+section context
contextual_text = f"[Lease {lease_id} | Section {section_number} {section_title}] {body}"
vec, meta = embed_text_for_storage(contextual_text)
chunk["text"] = meta["redacted_text"]
```

Reference: [Anthropic Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval) — reduces retrieval failure rate by ~49% over plain chunking.

### Eval gates for retrieval (mandatory before production)

`tests/golden/rag/<corpus>/` with ≥30 query-answer pairs containing:
- `query`
- `expected_chunk_ids` (list)
- `expected_section`
- `expected_answer_contains` (list of substrings)

Blocking thresholds:

| Metric | Threshold | What it measures |
|---|---|---|
| `recall@5` | ≥ 0.85 | At least one expected chunk in top 5 |
| `mrr@5` | ≥ 0.75 | First expected chunk's rank in top 5 |
| `HallucinationsV1` | ≤ 0.05 | LLM-as-judge hallucination rate |

If any threshold fails, retrieval is NOT production-ready. Add reranking, tune `alpha`, or expand contextual chunking before shipping.

---

## Cross-References

- `.claude/skills/google-adk/reference/adk-state-propagation.md` — ADK SequentialAgent `EventActions.state_delta` rule (CRITICAL for RAG ingest agents)
- `.claude/skills/vector-database/references/rag-ingest-checklist.md` — Section G (state propagation), Section H (live verification)
- `scripts/replay-golden-case.sh` + `scripts/verify-weaviate-tenant.sh` — live verification tooling
