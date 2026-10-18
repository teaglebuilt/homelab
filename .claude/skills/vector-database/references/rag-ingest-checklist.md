# RAG Ingest Pipeline Checklist

Load this file BEFORE writing any agent or worker that ingests text into a
Weaviate collection or pgvector table for retrieval. Following this
checklist implements RAG hygiene, PII redaction, multi-tenancy, and observability by construction.

## When this applies

- Any agent/worker that takes text → produces a vector → writes to a
  vector store
- Examples: document ingestion agents, knowledge-base seeding scripts, batch backfill jobs
- **Does NOT apply** to query-time embedding (user types a question → embed
  → search). Use raw `embed_text()` for queries; redaction would break
  recall.

## Checklist (copy into your ingest agent's PR)

### A. Embedding API choice

- [ ] Use `your_project.embeddings.embed_text_for_storage(text)` — NOT raw
      `embed_text()`. The for-storage variant runs PII redaction and
      enforces `MAX_CHARS_PER_EMBEDDING` automatically.
- [ ] If you absolutely need raw `embed_text()` (e.g. embedding metadata
      labels, not user content), add an inline comment explaining why
      redaction would be incorrect for this caller.

### A2. Chunking — apply ~10% overlap

- [ ] Apply chunk overlap before storage. Recommended default:
      `CHUNK_OVERLAP_CHARS = 200` (~10% of typical chunk).
- [ ] Reference impl: your chunking agent's `_apply_overlap(...)` method —
      copy this pattern in custom chunkers (extends each chunk's body with
      leading N chars of the next chunk).
- [ ] Hard zero-overlap chunking is **forbidden** — retrieval recall
      collapses at chunk boundaries (LangChain's
      `RecursiveCharacterTextSplitter` documents this thoroughly).
- [ ] Cap final body at `CHUNK_BODY_MAX_CHARS = 4000` even after overlap is
      applied so `embed_text`'s 8192-char ceiling is never hit.
- [ ] Persist the chunking strategy in chunk metadata
      (`chunking_method = "section_boundary" | "paragraph_fallback" | …`)
      for downstream filtering and observability.

### A3. Schema — multi-tenancy + version stamp (mandatory at create time)

- [ ] When `ensure_collection()` runs for the first time, the create call
      MUST include `multi_tenancy_config=Configure.multi_tenancy(enabled=True,
      auto_tenant_creation=True)`. Tenant key = the natural isolation unit
      (landlord_id, vendor_id, organisation_id, …). Filter-only isolation
      is forbidden for new RAG collections — physical isolation is the
      industry-standard multi-tenant SaaS pattern.
- [ ] Schema MUST include `Property(name="embedding_model",
      data_type=DataType.TEXT)` for blue/green re-embedding migrations.
- [ ] `WeaviateWriter.upsert_chunks` auto-stamps `embedding_model =
      EMBEDDING_MODEL` on every chunk via `chunk.setdefault(...)` — don't
      reimplement; just include the property in the schema.
- [ ] Operations against a multi-tenancy-enabled collection MUST pass
      `tenant_id` to `upsert_chunks(...)` and `delete_by_document_id(...)`.
      Omitting it raises at the Weaviate layer.

### B. Persistence pattern

- [ ] After `embed_text_for_storage()`, replace the chunk's stored text
      with `meta["redacted_text"]` BEFORE writing to the vector store.
      Never persist raw PII alongside the vector.
- [ ] If `meta["redaction_counts"]` is non-empty, attach it to the chunk
      under a `pii_redactions` key — useful for downstream audits.

### C. Failure handling

- [ ] Per-chunk embedding failures must be **non-fatal** (BR-02 pattern):
      log + skip, continue with remaining chunks.
- [ ] Collection-level failures (Weaviate unreachable, schema missing)
      must be fatal — propagate the error so the pipeline reports
      `WEAVIATE_WRITE_FAILED` or equivalent.
- [ ] Stale-chunk deletion: call `delete_by_document_id()` (or your
      collection's analog) BEFORE upserting new chunks. Delete failures
      are logged but non-fatal (stale-data risk acceptable for most pipelines).

### D. Observability

- [ ] Per-call FinOps log fires automatically via `embed_text_for_storage`
      (`embedding_call_complete` event). Don't reimplement this.
- [ ] Per-pipeline aggregate cost: sum `len(chunk["text"])` across kept
      chunks and call `estimate_embedding_cost_usd(total_chars)`. Log
      result as `<pipeline>_cost_summary` with `document_id`/`tenant_id`/etc.
- [ ] Persist the aggregate cost on the response model (e.g.
      `embedding_cost_usd_estimate`) so downstream FinOps dashboards
      see ingest costs without scraping logs.

### E. Tenant scope

- [ ] Pre-fetch upstream content (e.g. PDF download via MCP) using a tool
      that runs `enforceTenantScope`. The vector store doesn't enforce
      tenant scope on its own.
- [ ] Filter retrieval queries by `document_id` / `tenant_id` / equivalent
      in the WHERE clause. Never trust callers to provide the right
      filter — bake it into the helper.

### F. Tests

- [ ] Unit test: pipeline rejects oversized input (>8192 chars) before
      Vertex AI is called. The `MAX_CHARS_PER_EMBEDDING` guard fires
      before any cost is incurred.
- [ ] Unit test: pipeline redacts PII in a sample chunk (assert
      `[REDACTED:email]` in stored text and original PII is gone).
- [ ] Eval test: golden dataset includes at least one case with PII
      strings — verifies the pipeline strips them end-to-end.

## Anti-patterns to refuse at code review

### ❌ Calling embed_text directly from an ingest path

```python
# ✗ — bypasses PII redaction and 8K-char ceiling; use embed_text_for_storage instead
for chunk in chunks:
    vec = embed_text(chunk["text"])
    writer.upsert_chunks([chunk], embeddings=[vec])
```

### ❌ Storing raw text alongside the vector

```python
# ✗ — chunk["text"] still has the un-redacted PII even though the
#     vector itself is safe-ish.
vec, meta = embed_text_for_storage(chunk["text"])
writer.upsert_chunks([chunk], embeddings=[vec])  # raw chunk["text"]!
```

### ❌ Skipping the failure-isolation rule

```python
# ✗ — one bad chunk takes down the whole lease (BR-02 violation)
for chunk in chunks:
    vec, _ = embed_text_for_storage(chunk["text"])  # raises on cost-cap
    embeddings.append(vec)
```

## G. ADK SequentialAgent state propagation (CRITICAL — hard-won lesson)

**Common bug: pipeline reports `chunks_written: 0` despite chunks landing in Weaviate.**
Direct `ctx.session.state[X] = Y`
mutations are visible to the next sub-agent in the SAME runner invocation,
but are LOST when `routes.py` re-reads via `session_service.get_session(...)`
because `InMemorySessionService` returns a light-copy of the storage session.

- [ ] Every `BaseAgent` sub-agent that writes state read by `routes.py`
      after `runner.run_async` completes MUST yield an
      `Event(actions=EventActions(state_delta={...}), ...)`. Direct
      `ctx.session.state[X] = Y` is in-runner-only.
- [ ] In an ingest pipeline this applies to: `download_status`,
      `document_chunks`, `chunking_method`, `ingestion_result`, `pipeline_error` —
      anything routes.py reads after the runner exits.
- [ ] Reference impl: your ingest agent's `embed_agent.py`
      (see `EventActions(state_delta={"ingestion_result": ...})` on the
      success Event AND the error Event).
- [ ] Cross-link: `.claude/skills/google-adk/reference/adk-state-propagation.md`
      contains the full diagnostic guide.

```python
# ✗ — direct mutation only; routes.py will read {} for ingestion_result
ctx.session.state["ingestion_result"] = result
yield Event(author=self.name, content=Content(...))

# ✓ — state_delta on the Event makes the mutation persist to storage
from google.adk.events import Event, EventActions
ctx.session.state["ingestion_result"] = result   # for in-runner readers
yield Event(
    author=self.name,
    actions=EventActions(state_delta={"ingestion_result": result}),  # storage
    content=Content(...),
)
```

## H. Live verification gate

Unit tests stub the LLM and the vector store — exactly the layers most
prone to live bugs. ANY PR that touches a RAG ingest agent MUST run these
gates locally before opening the PR.

- [ ] **Live fixture replay** — for every fixture in your test manifest, run
      `bash scripts/replay-golden-case.sh tests/golden/agent/case_*_<agent>_*.yaml
      http://localhost:<port>/run`. Each case must return its
      documented `expected_output` (status, error, chunks_written_min,
      success_rate_min). This proves the **HTTP path** works.
- [ ] **Direct vector-store verification** — query Weaviate directly to confirm
      chunks landed under the right tenant AND that no raw PII (email, SSN)
      is in stored `text` properties. A passing fixture replay with failing
      direct verification = ADK state-propagation bug — fix Section G above.
- [ ] Both gates are mandatory PR checklist items. Add a CI gate that greps
      the PR body for evidence of both having been run.

```bash
# Canonical end-to-end verification, copied into your PR body:
docker compose -f infra/docker-compose.yml --env-file .env build <agent>
docker compose -f infra/docker-compose.yml --env-file .env up -d --force-recreate <agent>
until docker ps --filter "name=<agent>" --format "{{.Status}}" | grep -q "(healthy)"; do sleep 3; done
for case in tests/golden/agent/case_*_<agent>_*.yaml; do
    bash scripts/replay-golden-case.sh "$case" "http://localhost:<port>/run"
done
WEAVIATE_API_KEY=$(grep '^WEAVIATE_API_KEY=' .env | cut -d= -f2-) \
    bash scripts/verify-weaviate-tenant.sh <document_id> <owner_id> <min_chunks>
docker logs <agent> --since 5m | grep '"level":"error"' | wc -l   # must be 0
```

## Reference

- `.claude/skills/google-adk/reference/adk-state-propagation.md` (Section G context)
- Your project's `embeddings.py` (canonical helpers)
- Your project's `redaction.py` (PII patterns)
- Your ingest agent's `embed_agent.py` (reference impl)
- `scripts/replay-golden-case.sh` + `scripts/verify-weaviate-tenant.sh` (live verification tooling)
