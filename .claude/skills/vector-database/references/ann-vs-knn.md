# ANN vs KNN in RAG — Quick Reference

A practical guide to choosing between exact and approximate nearest-neighbor search for vector retrieval.

---

## The Core Tradeoff

| Item | Meaning | Strength | Weakness |
|------|---------|---------|---------|
| **KNN / Exact search** | Finds the true top-k closest vectors by comparing against all candidates | Highest recall / most accurate | Slower and expensive as data grows |
| **ANN / Approximate search** | Finds "almost nearest" vectors using indexes like **HNSW** or **IVFFlat** | Much faster at scale | Slight recall tradeoff |

**Simple rule:** KNN = accuracy baseline. ANN/HNSW = production scale.

---

## 1. KNN (Exact / Brute-Force Search)

**How it works:** Compares the query vector against *every* vector in the database, returning the true top-k closest.
**Complexity:** O(N) per query — scales linearly with dataset size.

**When to use:**
- Small datasets (< ~50k vectors)
- Local dev and golden-dataset testing
- Measuring "true recall" as a baseline to evaluate ANN against
- Offline batch jobs where latency doesn't matter
- Scoped verification within a narrow metadata filter (one document, one user, one tenant)

**Why it matters:** It's the only way to know what *perfect* retrieval looks like for your data. You can't measure ANN's recall loss without it.

---

## 2. ANN (Approximate Nearest Neighbor)

**How it works:** Uses a pre-built index structure to skip most comparisons, finding *probably* the top-k closest vectors much faster than brute force.

**Complexity:** HNSW usually gives logarithmic-like / sublinear search behavior in practice, but latency depends on index parameters, vector dimensions, metadata filters, and dataset shape — it is not a guaranteed `O(log N)` for every query/data shape.

**Common index types:**

| Index | Strength | Weakness |
|-------|---------|---------|
| **HNSW** | Excellent recall/speed tradeoff for large datasets; scales very far with proper infrastructure | Higher memory footprint (stores graph links), slower build time |
| **IVFFlat** | Lower memory, faster to build | Lower recall than HNSW at same speed |
| **Flat** | Exact (technically not ANN) — brute force | Slow at scale |

**When to use ANN:** Production retrieval on any non-trivial dataset (> ~50k vectors).

### A third axis: Quantization

Beyond choosing an index type, **vector quantization** (PQ — Product Quantization, SQ — Scalar Quantization) compresses the vectors themselves to trade accuracy for memory and speed. It composes with HNSW/IVFFlat — e.g. HNSW+PQ is a common large-scale config. Worth considering when memory becomes the bottleneck before latency does.

---

## Recall Tradeoff in Practice

ANN doesn't mean "bad recall" — **well-tuned HNSW can often reach 95–99% recall**, but this must be measured against exact KNN on *your own* golden dataset. Tuning knobs:

- **HNSW `ef_search`** (query-time) — higher = better recall, slower queries
- **HNSW `ef_construction`** (build-time) — higher = better-quality graph, slower index build
- **HNSW `M`** (build-time) — higher = better recall, more memory
- **IVFFlat `nprobe`** (query-time) — higher = better recall, slower queries

**The golden workflow:** Measure recall of your ANN config against KNN ground truth on a sample, then tune until recall@k is acceptable for your use case.

---

## Vector DB Support

**pgvector (Postgres)**
Exact search is the default and gives perfect recall. Adding **HNSW** or **IVFFlat** indexes enables approximate search for speed at scale.

**Weaviate**
Supports **HNSW** (scales well for large datasets), **Flat** (brute force, good for small datasets), **Dynamic** (auto-switches), and **HFresh**.

**Other engines** (Pinecone, Qdrant, Milvus, FAISS): support ANN-style indexing, often including HNSW or similar high-performance vector indexes, but **defaults vary by product and deployment mode**. FAISS in particular is a library with many index families; Pinecone abstracts internals. Always check the specific version and deployment.

---

## Recommended Pattern

### Broad production search

Use **ANN with HNSW** for production retrieval, paired with hybrid search and a reranker:

```text
User query
  ↓
Hybrid retrieval: BM25 + vector ANN/HNSW
  ↓
Retrieve top 50–100 chunks (over-retrieve on purpose)
  ↓
Rerank with your preferred reranker (e.g. Vertex AI Ranking, Cohere Rerank, cross-encoder)
  ↓
Keep top 5–10 chunks
  ↓
Generate grounded answer with citations
  ↓
Evaluate Recall@k + Faithfulness
```

**Why over-retrieve then rerank?** ANN gives fast, broad recall. The reranker cleans up ordering and relevance. This combo beats either alone — and compensates for ANN's small recall loss by widening the candidate pool.

### High-risk scoped verification

For high-risk answers — contractual clauses, financial terms, legal-like explanations — combine ANN with a scoped exact-KNN fallback:

```text
Broad production search:
  ANN/HNSW + hybrid retrieval + reranker

High-risk scoped verification:
  metadata filter (one document / one user / one tenant)
  → smaller candidate set
  → exact KNN or strong rerank
  → citation-required answer
```

This gives the best of both worlds: ANN handles scale, exact KNN handles the narrow, high-stakes cases where you can't afford to miss a clause.

---

## Recommendation Matrix

| Environment | Recommendation |
|-------------|---------------|
| **Small local dev / golden dataset testing** | Use **Exact KNN / Flat** to measure true recall baseline |
| **Production RAG** | Use **ANN / HNSW** for speed + scale |
| **High-risk answers** (contracts, financial terms, compliance) | Narrow with metadata filter → exact KNN or strong rerank → citation required |
| **Postgres pgvector** | Use HNSW when vector data grows beyond ~50k rows |
| **Weaviate** | Use HNSW as main vector index |

---

## Diagnostic Cues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Production retrieval slow at scale | Using exact KNN on large dataset | Switch to HNSW |
| ANN recall noticeably worse than KNN baseline | `ef_search` / `nprobe` too low | Increase ANN search params, re-measure |
| High latency even with HNSW | `ef_search` set too high, or k too large | Tune down, or add reranker on smaller top-k |
| Right chunks exist but never retrieved | Embedding model mismatch, not an ANN issue | Validate with KNN — if KNN also misses, fix embeddings/chunking |
| Memory pressure on vector DB | HNSW graph links + high `M` value | Lower `M`, or shard the index |

---

## Final Rule

> **Use exact KNN / Flat as the truth baseline. Use ANN/HNSW for production scale.**
> **For production: ANN/HNSW + hybrid search + reranker + Recall@k evaluation against KNN. For high-risk answers, add scoped verification and citation enforcement.**

---

## References

- [pgvector — GitHub](https://github.com/pgvector/pgvector)
- [Weaviate — Indexing Concepts](https://docs.weaviate.io/weaviate/concepts/indexing)
- [HNSW Paper — Malkov & Yashunin](https://arxiv.org/abs/1603.09320)
