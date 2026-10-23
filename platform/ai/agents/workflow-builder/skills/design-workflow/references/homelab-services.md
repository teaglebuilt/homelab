# Homelab integration candidates and verification

This catalog combines user-stated target architecture with older uploaded
homelab repository snapshots. It is **not live cluster inventory**.
Before selecting a service, verify deployment, network reachability from n8n,
API/version, credentials, least-privilege scopes, and expected volume. Use
repository/GitHub read tools and Kubernetes MCP tools if available; otherwise
mark service `unverified` and request a connection check in the rollout plan.
Never copy credentials, token values, literal internal IPs, or host-specific
assumptions from historical source files into generated workflows.

| Service | Use in workflows | Verify / caveats |
|---|---|---|
| n8n | triggers, orchestration, retries, human approval, error workflows | official MCP/REST version, credentials, project, timezone, execution mode |
| Firecrawl (self-hosted) | scrape, crawl, search, extract Markdown | HTTP Request node only; exact self-hosted API version, support, queue limits and authentication |
| SearXNG | search backend for Firecrawl `/search` | Firecrawl `SEARXNG_ENDPOINT` integration and JSON format; direct HTTP only if needed separately |
| Qdrant | embeddings/vector metadata persistence and similarity retrieval | collection, vector size/distance, auth, TLS, payload indexes, tenancy |
| Ollama / gateway / vLLM | local inference, extraction or embedding | service URL, exposed models and embedding dimensions; GPU availability and concurrency |
| OpenWebUI | consumer for AI experiences, optionally webhook triggers | current APIs/auth; normally not RAG vector system itself |
| Redis | transient state, queues, locks, dedupe/counters | available DB/ACL/TTL, persistence, atomicity; not substitute for persistent storage blindly |
| S3-compatible object store / AWS S3 | raw documents, archives, checkpoints, exports | IAM/signed access, retention, bucket and object prefixes |
| Prometheus | query operational metrics, enrichment of alerts | read API permissions, query range/time zone/cardinality |
| Alertmanager | alert webhook receiver / notification routing | inbound webhook design vs Alertmanager API access; group/dedup semantics |
| Grafana | dashboard links, annotations | authenticated API if needed; not general purpose metric storage |
| Loki / Graylog / OpenSearch | incident log evidence and search | actual deployed backend, API capability and retention |
| Kubernetes / Talos / Cilium | platform facts, cluster remediation workflows | prefer read-only APIs; RBAC; explicit human approval for mutations |
| ArgoCD / GitHub | CI/CD, release/change notifications, GitOps sources | repo scopes, branch protections, PR/approval strategy |
| Paperless-ngx | OCR/document ingestion, categorization | API/schema/version, PII classification, authorization |
| RSSHub / FreshRSS / Miniflux | feeds and article ingestion | which reader/aggregator actually runs; feeds vs articles URLs |
| Crawl4AI | alternative extraction for specialized pages | verify runtime present, reachable, justified vs Firecrawl |
| Dagster / lakeFS | data pipeline runs, versions, datasets (optional) | only propose if current deployments and use cases are confirmed |
| Email / Slack / Matrix / webhooks | notifications and escalations | installed integrations, opt-in recipients, no secret-bearing messages |

The n8n workflow JSON path historically discussed for the homelab is
`platform/automation/kubernetes/n8n/workflows/`. An older repository snapshot
uses `platform/automation/k8s/n8n/`; **confirm the current directory** before
proposing a Git commit. A saved n8n workflow is not automatically Git-synced.

**Service-selection rubric:** reuse verified cluster services → prefer native
n8n nodes if catalog confirms capability → use HTTP Request for unsupported
internal APIs → introduce new products only when necessary, stating why.
