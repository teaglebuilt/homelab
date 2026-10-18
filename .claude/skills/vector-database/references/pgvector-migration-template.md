# pgvector Migration Templates

## Table of Contents
1. [Standard Migration (up + down)](#standard-migration)
2. [HNSW Index](#hnsw-index)
3. [IVFFlat Index](#ivfflat-index)
4. [Null Guard Pattern](#null-guard)
5. [Reversible Model Migration](#reversible-model-migration)

---

## Standard Migration

Every pgvector migration must:
- `CREATE EXTENSION IF NOT EXISTS vector` in `up()`
- Declare dimension matching the model exactly
- Add `embedding_model varchar(100)` alongside the vector column
- Include a reversible `down()`

```sql
-- V{N}__add_vector_search_{table}.sql

-- up
CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE {table}
  ADD COLUMN embedding         vector({dims}),
  ADD COLUMN embedding_model   varchar(100) DEFAULT '{model_name}',
  ADD COLUMN embedded_at       timestamptz;

COMMENT ON COLUMN {table}.embedding IS
  'Semantic embedding. Dimension={dims}. Model stored in embedding_model column.';

-- down
ALTER TABLE {table}
  DROP COLUMN IF EXISTS embedding,
  DROP COLUMN IF EXISTS embedding_model,
  DROP COLUMN IF EXISTS embedded_at;
```

### Real Examples by Model

**text-embedding-3-small (1536 dims)**
```sql
CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE vendors
  ADD COLUMN embedding         vector(1536),
  ADD COLUMN embedding_model   varchar(100) DEFAULT 'text-embedding-3-small',
  ADD COLUMN embedded_at       timestamptz;
```

**nomic-embed-text local (768 dims)**
```sql
CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE tickets
  ADD COLUMN embedding         vector(768),
  ADD COLUMN embedding_model   varchar(100) DEFAULT 'nomic-embed-text',
  ADD COLUMN embedded_at       timestamptz;
```

---

## HNSW Index

Use for production (>100K rows). No ANALYZE required after inserts.

```sql
-- Cosine similarity (most common)
CREATE INDEX {table}_embedding_hnsw_idx
  ON {table} USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- L2 similarity
CREATE INDEX {table}_embedding_hnsw_l2_idx
  ON {table} USING hnsw (embedding vector_l2_ops)
  WITH (m = 16, ef_construction = 64);

-- Inner product (for dot-product similarity)
CREATE INDEX {table}_embedding_hnsw_ip_idx
  ON {table} USING hnsw (embedding vector_ip_ops)
  WITH (m = 16, ef_construction = 64);
```

**Parameter tuning:**
| Parameter | Default | Increase when |
|-----------|---------|---------------|
| `m` | 16 | Higher recall needed (try 32, 64) |
| `ef_construction` | 64 | Higher quality index needed (try 128) |
| `ef_search` (query time) | 40 | Recall < 0.95 at query time |

Set `ef_search` at query time:
```sql
SET hnsw.ef_search = 100;
SELECT * FROM vendors ORDER BY embedding <=> $1 LIMIT 10;
```

---

## IVFFlat Index

Use for dev / budget-constrained / <100K rows. Requires data before creation.

```sql
-- MUST have data before creating IVFFlat index
-- lists = sqrt(row_count) is a good starting point
CREATE INDEX {table}_embedding_ivfflat_idx
  ON {table} USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- ALWAYS run ANALYZE after bulk inserts
ANALYZE {table};
```

**Probe tuning at query time:**
```sql
SET ivfflat.probes = 10;  -- higher = better recall, slower
SELECT * FROM vendors ORDER BY embedding <=> $1 LIMIT 10;
```

**lists formula:**
- < 1M rows: `lists = sqrt(row_count)`
- ≥ 1M rows: `lists = row_count / 1000`

---

## Null Guard

Always filter out rows with no embedding — they cause silent full scans.

```sql
-- Add partial index for non-null embeddings
CREATE INDEX {table}_embedding_notnull_idx
  ON {table} USING hnsw (embedding vector_cosine_ops)
  WHERE embedding IS NOT NULL;

-- Query guard
SELECT id, name,
       1 - (embedding <=> $1::vector) AS similarity
FROM {table}
WHERE embedding IS NOT NULL
ORDER BY embedding <=> $1::vector
LIMIT $2;
```

---

## Reversible Model Migration

When switching embedding models, use expand-deploy-contract:

```sql
-- Phase 1: Expand (add new column, keep old)
-- V{N}__expand_embedding_{table}_v2.sql

ALTER TABLE {table}
  ADD COLUMN embedding_v2        vector({new_dims}),
  ADD COLUMN embedding_model_v2  varchar(100) DEFAULT '{new_model}';

CREATE INDEX {table}_embedding_v2_hnsw_idx
  ON {table} USING hnsw (embedding_v2 vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);


-- Phase 2: Deploy re-embedding script (see embedding-migration-guide.md)
-- Run: python scripts/re_embed.py --table {table} --from-col embedding --to-col embedding_v2


-- Phase 3: Contract (swap columns, drop old)
-- V{N+1}__contract_embedding_{table}_v2.sql

ALTER TABLE {table}
  DROP COLUMN embedding,
  DROP COLUMN embedding_model;

ALTER TABLE {table}
  RENAME COLUMN embedding_v2 TO embedding;

ALTER TABLE {table}
  RENAME COLUMN embedding_model_v2 TO embedding_model;

-- Down (revert contract — restore old column structure)
-- NOTE: data in old embedding is gone after contract. Restore from backup.
ALTER TABLE {table}
  ADD COLUMN embedding_v2        vector({new_dims}),
  ADD COLUMN embedding_model_v2  varchar(100);

ALTER TABLE {table}
  RENAME COLUMN embedding TO embedding_v2;

ALTER TABLE {table}
  RENAME COLUMN embedding_model TO embedding_model_v2;
```

---

## Operator-Index Alignment Table

**This is the most common pgvector bug.** Always verify before deploy.

| Query Operator | Index ops | What it computes |
|----------------|-----------|-----------------|
| `<=>` | `vector_cosine_ops` | Cosine distance |
| `<->` | `vector_l2_ops` | L2 (Euclidean) distance |
| `<#>` | `vector_ip_ops` | Negative inner product |

Mismatch causes a silent sequential scan — no error, just 100× slower queries.
