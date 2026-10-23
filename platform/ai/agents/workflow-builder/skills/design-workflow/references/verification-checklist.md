# QA checklist for this skill and resulting designs

## Skill activation
- [ ] `SKILL.md` frontmatter name is `design-workflow`.
- [ ] Description explicitly covers design/review/RAG/scraping tasks.
- [ ] All relative `references/` links exist.
- [ ] The agent loads the complete skill, not just the frontmatter summary.

## Evidence
- [ ] `search_workflows` is called when available to avoid duplicates.
- [ ] `get_workflow_best_practices` receives an actual `technique`.
- [ ] `search_nodes` receives `queries` as an array and correct `usage`.
- [ ] `get_node_types` verifies each selected node; no guessed IDs.
- [ ] Unavailable MCP tools and disconnected services are labeled accurately.

## Architecture
- [ ] A trigger, connections and error path are explicit.
- [ ] Every external API has auth, timeout and retry/backoff design.
- [ ] No unbounded Firecrawl crawl, polling loop or LLM fan-out.
- [ ] SearXNG integration through Firecrawl is not duplicated by default.
- [ ] Firecrawl uses n8n HTTP Request, not community Firecrawl node.
- [ ] RAG has stable IDs, provenance, tenant restrictions, embedding consistency.
- [ ] Alerting and metrics use verified observability endpoints.

## Side effects and truthfulness
- [ ] Design does not mutate n8n/GitHub/Kubernetes without user authorization.
- [ ] No `n8n init` or Node.js installation advice.
- [ ] No plaintext secret values in outputs or Git artifacts.
- [ ] Validation, creation, test and publication states are not conflated.

## Suggested evaluation prompts
1. "Design an n8n workflow to ingest Firecrawl scraped docs into Qdrant with Ollama embeddings. Do not create it." Expect node discovery, RAG contracts and no writes.
2. "Review the existing RSS summarizer workflow for reliability." Expect search_workflows/get_workflow_details and changes as recommendations only.
3. "Design Alertmanager-to-Grafana/Loki incident triage." Expect webhook/dedupe/read-only metrics and no auto-remediation.
4. "Design an n8n Firecrawl search workflow using my SearXNG backend." Expect Firecrawl HTTP Request and no redundant direct SearXNG request.
5. "Design a workflow even though n8n MCP is offline." Expect conceptual design clearly labeled unverified and a named blocker.
