---
name: scrape
description: Design and run web scraping on the homelab's self-hosted Firecrawl. Triggers on "scrape this site", "crawl these docs", "extract data from a page", "map a site's URLs", or any mention of firecrawl. Delegates to the scraping-architect subagent, which owns tier selection and the exact /v2 request payloads.
---

# Scraping — Self-Hosted Firecrawl

Firecrawl runs in the `automation` namespace on the mlops cluster. Every
scraping path in the homelab goes through it: n8n workflows, kagent agents, and
Claude Code.

For anything beyond a one-line scrape, delegate to the `scraping-architect`
subagent via the Agent tool. Pass it:

- The target URL or site.
- The goal — what to find, and how much of the site is in scope.
- The output shape the caller needs.
- The caller surface: n8n HTTP Request node, firecrawl MCP tool, or CLI.
- Whether it runs once or on a schedule, and how fresh the data must be.

It returns the tier, the endpoint, the exact JSON body, and the caller wiring.
When building an n8n workflow, run `scraping-architect` first to settle the
request, then hand that payload to `n8n-workflow-builder` — the two skills
compose in that order.

## Endpoints

| Surface | Address |
| --- | --- |
| API (in-cluster) | `http://firecrawl-firecrawl-api.automation.svc.cluster.local:3002` |
| API (LAN) | `http://firecrawl.homelab.internal` |
| MCP | `http://firecrawl-mcp.automation.svc.cluster.local:3000/mcp`, federated into `homelab-agent` as target `firecrawl` |

No API key is required — the instance runs `USE_DB_AUTHENTICATION=false`.

## Tier ladder

Cheapest first. Do not skip a rung without a reason.

| Tier | Use | Endpoint |
| --- | --- | --- |
| 0 | A plain GET returns the data | n8n HTTP Request, no firecrawl |
| 1 | One page, need the content | `POST /v2/scrape` with `formats: ["markdown"]` |
| 2 | JS-rendered page | Same, plus `waitFor` |
| 3 | Many known pages | `POST /v2/map` to discover, then `POST /v2/batch/scrape` |
| 4 | A whole site | `POST /v2/crawl` with an explicit `limit`, then poll |
| 5 | Structured records | Parse the markdown in the caller, not in firecrawl |

Interaction — login, form submit, click-to-load — is **not** a firecrawl job on
this deployment. The `actions` parameter and the `screenshot` format both
require Fire-engine, which is not deployed. Escalate to a browser-driving agent
or say so plainly.

LLM extraction (`formats: ["json"]`, `summary`, `changeTracking` json mode) is
also unavailable: the chart ships an empty `OPENAI_API_KEY`. Ask for markdown
and parse it deterministically.

## How to interact with firecrawl

- **MCP** — tools are federated under the `homelab-agent` MCP server. Best for
  one-off scrapes you want inline in a conversation.
- **HTTP** — what n8n uses. See [n8n-http-patterns.md](resources/n8n-http-patterns.md).
- **CLI** — best for shell pipelines and quick verification.

```bash
firecrawl --api-url http://firecrawl.homelab.internal scrape https://example.com

# Or set via environment variable
export FIRECRAWL_API_URL=http://firecrawl.homelab.internal
firecrawl scrape https://example.com

# Configure and persist the custom API URL
firecrawl config --api-url http://firecrawl.homelab.internal
```

## Resources

- [firecrawl-api.md](resources/firecrawl-api.md) — v2 endpoints, every scrape
  and crawl option, formats, polling, error and retry table, CLI commands.
- [self-hosted.md](resources/self-hosted.md) — what is deployed, what does not
  work self-hosted and why, operational limits, the triage runbook, MCP tool
  names.
- [n8n-http-patterns.md](resources/n8n-http-patterns.md) — copy-paste request
  bodies for scrape, map-then-batch, crawl-with-polling, and webhooks.

## Upstream docs

Registered in `.ai/context/docs.md`. Fetch the index first, follow one endpoint
page, and never inline `llms-full.txt`.

- Index: https://docs.firecrawl.dev/llms.txt
- API introduction: https://docs.firecrawl.dev/api-reference/v2-introduction
- Self-hosting limits: https://docs.firecrawl.dev/contributing/self-host

The `WebFetch` tool currently hangs on `docs.firecrawl.dev`. Use
`curl -sS -m 30 <url> -o /tmp/<name>.md` and read the file instead.
