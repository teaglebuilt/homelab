# Embedding Model Migration Guide

Switching embedding models requires a full re-embedding migration.
Dimensions change; old and new vectors are incompatible.

## Table of Contents
1. [Pre-Migration Checklist](#pre-migration-checklist)
2. [Migration Plan (pgvector)](#migration-plan-pgvector)
3. [Migration Plan (Weaviate)](#migration-plan-weaviate)
4. [Re-Embedding Script](#re-embedding-script)
5. [Rollback Procedure](#rollback-procedure)
6. [Cost Estimation](#cost-estimation)

---

## Pre-Migration Checklist

Before starting any migration:

- [ ] Know the current model name and dimension (query `embedding_model` column)
- [ ] Know the new model name and dimension
- [ ] Estimate token count → calculate API cost (see Cost Estimation)
- [ ] Take a database backup
- [ ] Test re-embedding script on 100-row sample first
- [ ] Confirm index type for new dimension (HNSW for >100K rows)
- [ ] Schedule during low-traffic window (re-embedding can take hours)

---

## Migration Plan (pgvector)

### Phase 1 — Expand (add new column, keep old)

```sql
-- V{N}__expand_embedding_{table}_{new_model_safe_name}.sql

-- up
ALTER TABLE {table}
  ADD COLUMN embedding_v2        vector({new_dims}),
  ADD COLUMN embedding_model_v2  varchar(100) DEFAULT '{new_model}';

CREATE INDEX {table}_embedding_v2_hnsw_idx
  ON {table} USING hnsw (embedding_v2 vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- down
DROP INDEX IF EXISTS {table}_embedding_v2_hnsw_idx;
ALTER TABLE {table}
  DROP COLUMN IF EXISTS embedding_v2,
  DROP COLUMN IF EXISTS embedding_model_v2;
```

### Phase 2 — Re-embed (run script, see below)

Track progress in a migration state column:

```sql
ALTER TABLE {table}
  ADD COLUMN IF NOT EXISTS reembedding_status varchar(20) DEFAULT 'pending';
-- Values: pending | in_progress | complete | failed
```

### Phase 3 — Verify (before swapping)

```sql
-- Verify all rows have new embedding
SELECT
  COUNT(*) FILTER (WHERE embedding_v2 IS NOT NULL) AS done,
  COUNT(*) FILTER (WHERE embedding_v2 IS NULL)     AS pending,
  COUNT(*)                                          AS total
FROM {table};

-- Spot-check recall quality
SELECT id, name,
  1 - (embedding    <=> query_vec::vector) AS old_sim,
  1 - (embedding_v2 <=> query_vec::vector) AS new_sim
FROM {table}
WHERE embedding IS NOT NULL AND embedding_v2 IS NOT NULL
LIMIT 20;
```

### Phase 4 — Contract (swap, drop old)

```sql
-- V{N+1}__contract_embedding_{table}.sql

-- up
-- Drop old index first
DROP INDEX IF EXISTS {table}_embedding_hnsw_idx;

ALTER TABLE {table}
  DROP COLUMN embedding,
  DROP COLUMN embedding_model,
  DROP COLUMN IF EXISTS reembedding_status;

ALTER TABLE {table}
  RENAME COLUMN embedding_v2 TO embedding;

ALTER TABLE {table}
  RENAME COLUMN embedding_model_v2 TO embedding_model;

-- Also rename the index for clarity
ALTER INDEX {table}_embedding_v2_hnsw_idx
  RENAME TO {table}_embedding_hnsw_idx;

-- down (data loss warning — restore from backup)
ALTER TABLE {table}
  ADD COLUMN embedding_legacy vector({old_dims}),
  ADD COLUMN embedding_model_legacy varchar(100);
-- NOTE: old vector data is gone after contract phase. Restore from pre-migration backup.
```

---

## Migration Plan (Weaviate)

Weaviate does not support in-place dimension changes. Create a new collection.

```python
import weaviate
import weaviate.classes as wvc

# Step 1: Create new collection with new model
client.collections.create(
    name="{CollectionName}_v2",
    vectorizer_config=wvc.config.Configure.Vectorizer.text2vec_openai(
        model="{new_model}",
    ),
    vector_index_config=wvc.config.Configure.VectorIndex.hnsw(
        distance_metric=wvc.config.VectorDistances.COSINE,
    ),
    properties=[ ... ],  # same properties as original
)

# Step 2: Re-ingest all objects (see Re-Embedding Script)
# Step 3: Update application to use "{CollectionName}_v2"
# Step 4: Delete old collection after cutover
client.collections.delete("{CollectionName}")
client.collections.get("{CollectionName}_v2").config.update(
    # Can rename via backup/restore; or just keep _v2 name
)
```

---

## Re-Embedding Script

```python
#!/usr/bin/env python3
"""
Re-embedding script for pgvector migration.
Run AFTER Phase 1 (expand) migration.

Usage:
    python scripts/re_embed.py \
        --table vendors \
        --text-col description \
        --from-col embedding \
        --to-col embedding_v2 \
        --model text-embedding-3-large \
        --batch-size 100
"""

import asyncio
import asyncpg
import argparse
from openai import AsyncOpenAI
import os
import time

openai_client = AsyncOpenAI()


async def re_embed(
    pool: asyncpg.Pool,
    table: str,
    text_col: str,
    from_col: str,
    to_col: str,
    model: str,
    batch_size: int = 100,
) -> None:
    # Count pending rows
    total = await pool.fetchval(
        f"SELECT COUNT(*) FROM {table} WHERE {to_col} IS NULL"
    )
    print(f"Re-embedding {total} rows in {table} using {model}")

    processed = 0
    while True:
        # Fetch a batch
        rows = await pool.fetch(
            f"""
            SELECT id, {text_col}
            FROM {table}
            WHERE {to_col} IS NULL
              AND {text_col} IS NOT NULL
            LIMIT $1
            FOR UPDATE SKIP LOCKED
            """,
            batch_size,
        )

        if not rows:
            break

        texts = [r[text_col] for r in rows]
        ids   = [r["id"] for r in rows]

        # Generate embeddings
        response = await openai_client.embeddings.create(
            input=texts,
            model=model,
        )
        embeddings = [item.embedding for item in response.data]

        # Write back
        async with pool.acquire() as conn:
            async with conn.transaction():
                for row_id, embedding in zip(ids, embeddings):
                    await conn.execute(
                        f"UPDATE {table} SET {to_col} = $1 WHERE id = $2",
                        embedding,
                        row_id,
                    )

        processed += len(rows)
        print(f"  Progress: {processed}/{total} ({100*processed//total}%)")
        time.sleep(0.1)  # rate limiting pause

    print(f"Done. Re-embedded {processed} rows.")


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--table",      required=True)
    parser.add_argument("--text-col",   required=True)
    parser.add_argument("--from-col",   required=True)
    parser.add_argument("--to-col",     required=True)
    parser.add_argument("--model",      required=True)
    parser.add_argument("--batch-size", type=int, default=100)
    args = parser.parse_args()

    pool = await asyncpg.create_pool(os.environ["DATABASE_URL"])
    await re_embed(pool, args.table, args.text_col,
                   args.from_col, args.to_col, args.model, args.batch_size)
    await pool.close()


if __name__ == "__main__":
    asyncio.run(main())
```

---

## Rollback Procedure

If migration fails during Phase 2 (re-embedding), rollback is safe:

```sql
-- Safe rollback: just drop the v2 column (no data lost from original)
DROP INDEX IF EXISTS {table}_embedding_v2_hnsw_idx;
ALTER TABLE {table}
  DROP COLUMN IF EXISTS embedding_v2,
  DROP COLUMN IF EXISTS embedding_model_v2,
  DROP COLUMN IF EXISTS reembedding_status;
```

If migration fails during Phase 4 (contract), restore from pre-migration backup — old vector data was dropped.

---

## Cost Estimation

```
tokens_per_row = avg_chars / 4  (rough approximation)
total_tokens = tokens_per_row * row_count

# OpenAI pricing (as of 2025):
# text-embedding-3-small: $0.020 / 1M tokens
# text-embedding-3-large: $0.130 / 1M tokens

cost_small = (total_tokens / 1_000_000) * 0.020
cost_large = (total_tokens / 1_000_000) * 0.130
```

**Example:** 100K vendor descriptions, avg 200 chars:
- `total_tokens` = 100,000 × 50 = 5M tokens
- `text-embedding-3-small`: ~$0.10
- `text-embedding-3-large`: ~$0.65

---

## Migration Strategies (§38)

Choose based on risk tolerance and corpus size.

### Strategy A — Hard Cutover (Default for Low-Risk)
Use the Expand → Re-embed → Swap → Contract pattern documented above.
- Suitable when: dev/staging migration, non-critical corpora, small teams
- Risk: brief window where old and new index coexist; rollback is clean via column drop

### Strategy B — Shadow Index (High-Stakes Pipelines)
Write embeddings to both old and new columns. Read from old. Compare recall divergence before cutting over.
```python
# Dual-write at ingestion (both models run in parallel)
async def embed_dual(text: str) -> tuple:
    old_emb, new_emb = await asyncio.gather(
        embed(text, model=OLD_MODEL),
        embed(text, model=NEW_MODEL),
    )
    return old_emb, new_emb

# At query time: run both retrievers, compare top-k overlap
old_results = retrieve(query_emb_old, index="embedding")
new_results = retrieve(query_emb_new, index="embedding_v2")
overlap = len(set(old_results) & set(new_results)) / k
# Proceed with cutover only when overlap >= 0.90 on golden set
```
- Suitable when: production corpus, high query volume, no tolerance for recall regression
- Cost: 2× embedding API calls during transition period
- Cutover gate: shadow recall@k ≥ baseline − 0.02 on golden set

### Strategy C — A/B at Query Time
Route X% of live traffic to the new embedding; measure production metrics before full cutover.
```python
def get_retriever(user_id: str, rollout_pct: float = 0.05):
    # Deterministic assignment — same user always gets same model
    bucket = int(hashlib.md5(user_id.encode()).hexdigest(), 16) % 100
    if bucket < rollout_pct * 100:
        return retriever_v2  # new model
    return retriever_v1      # old model
```
- Suitable when: you want production recall signal before full cutover
- Requires: A/B metric tracking (Recall@k by group, user satisfaction, abstention rate)
- Cutover gate: new model group shows Recall@k ≥ old model group after 1000+ queries

### Strategy Selection Guide

| Condition | Strategy |
|---|---|
| Dev / non-critical / small corpus | A — Hard Cutover |
| Production, high stakes, can afford 2× embedding cost | B — Shadow Index |
| Production, want real-user signal, low risk tolerance | C — A/B at Query Time |
| Need to minimize downtime window | B or C (never hard cutover during peak) |
