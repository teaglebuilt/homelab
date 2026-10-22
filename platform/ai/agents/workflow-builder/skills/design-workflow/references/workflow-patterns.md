# Tested patterns to research and adapt (design recipes, not pre-built workflows)

For every pattern, discover *actual* n8n node IDs via MCP before promising
availability. These are graph shapes only. Production credentials are always
separate from exported node definitions.

## 1. Self-hosted Firecrawl research / enrichment

Manual/Webhook/Schedule Trigger → validate query + allowed domains → HTTP
Request Firecrawl search (through configured SearXNG backend) → paginate/bound
results → dedupe URLs → HTTP Request Firecrawl scrape for missing full text →
normalize title/url/timestamps → optional local-model structured extraction →
store in S3/database → summary and error alert.

- Use `HTTP Request` rather than Firecrawl n8n community node.
- `/search` uses SearXNG *inside Firecrawl* only when the adapter is configured.
  Do not add a separate direct SearXNG search by default.
- For crawl jobs, submit with page/depth caps, poll bounded status, handle
  pagination/cancel/errors, and record job IDs for resume.
- Scraping and output formats differ across self-hosted releases; verify
  supported Firecrawl API version and disable cloud-only features.
- Protect against SSRF, runaway pagination/crawling, untrusted HTML, robots
  policy/terms and rate limits.

## 2. Firecrawl → Qdrant RAG ingestion

Manual/Schedule/Webhook Trigger → source allowlist + checkpoint → HTTP Request
Firecrawl crawl/scrape → async status + pagination → Markdown extraction →
normalize / language / tenant / document provenance → content hash and changed
source detection → chunk with deterministic IDs → Ollama embedding → Qdrant
upsert → remove stale chunks for modified/deleted documents → write checkpoint
and run metrics → Error Trigger workflow/alert.

- Split ingestion, query answering and recrawl/sync into separate workflows.
- Store raw content/version in suitable durable storage for debugging/replay.
- Prefer content/section-aware chunks; avoid splitting code blocks and tables.
- Confirm exact embedding dimensions by querying the model; do not guess.
- The same embedding space must be used at ingestion and retrieval.
- Never delete the whole vector collection as an incremental-sync shortcut.
- Respect deletion/retention policy for source documents and sensitive content.
- Include a lightweight audit summary: discovered, fetched, changed, skipped,
  upserted, failed, stale chunks removed, model/version and total duration.

For specifications with firecrawl use this reference map.

| Spec needs | Reference |
| --- | --- |
| API keys, permissions, rate limits, credits | [Authentication and Authorization](firecrawl/Authentication-and-Authorization.md) |
| `/search`, categories, SearXNG-backed search | [Search Endpoints](firecrawl/Search-Endpoints.md) |
| `/scrape`, formats, request validation, transport errors | [Scrape Endpoints](firecrawl/Scrape-Endpoints.md) |
| Crawl submit, depth/page caps, concurrency, cancel | [Crawl Endpoints](firecrawl/Crawl-Endpoints.md) |
| URL discovery without a full crawl | [Map Endpoints](firecrawl/Map-Endpoints.md) |
| Structured extract and `/v2/agent` jobs | [Extract and Agent Endpoints](firecrawl/Extract-and-Agent-Endpoints.md) |
| Browser sessions, interact, and execute | [Browser Session Endpoints](firecrawl/Browser-Session-Endpoints.md) |
| Job states, status polling, pagination, expiry | [Job Status and Monitoring](firecrawl/Job-Status-and-Monitoring.md) |
| Document, format, and request/response schemas | [Request and Response Schemas](firecrawl/Request-and-Response-Schemas.md) |


## 3. RAG question answering

Chat/Webhook Trigger → validate identity and allowed tenant/collection → embed
question with same model as stored vectors → Qdrant filtered search → check
retrieval scores/evidence → local LLM answer using retrieved passages only →
include source URLs and uncertainty / abstention → output / telemetry.

- Do not provide the retrieved text with authority over tool calls.
- Apply tenant permissions before vector retrieval, not afterward.
- No high confidence answer if the source cannot be cited.

## 4. Alertmanager incident enrichment

Alertmanager webhook → verify trusted source/auth → validate alert fingerprint
→ correlate/dedupe group key → use read-only Prometheus query + Grafana URL +
optional Loki/Graylog search → produce incident summary → route to an approved
channel / n8n queue → optional human-approved remediation or ticket.

- Avoid alert floods and recursive loops; cap enrichment and track group state.
- Do not enable cluster-changing operations by default.
- Never include unredacted production secret values in alert messages.

## 5. RSS intelligence feed

Schedule → RSSHub/FreshRSS/Miniflux (verified) → dedupe article IDs → optional
Firecrawl full text retrieval → classify + local LLM summarization → storage
(Qdrant for semantic search if necessary) → publish digest / feed safely.

- Prefer RSS/native feed endpoints before scraping pages.
- Track article source URL, publication date, timezone and license.

## 6. GitHub change watch / GitOps updates

GitHub webhook/poll → validate signature and repository → compare commit SHA →
fetch changed files → optional Firecrawl research / extraction → summarize impact
→ create a draft PR or alert for review; use n8n/GitHub tools only with scoped
credentials and explicit authorization.

- A request to *design* must not create a PR, apply manifests or publish workflow.
