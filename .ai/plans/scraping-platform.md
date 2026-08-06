# Scraping Platform — Design

> **Feature of** the [AI Platform](../stories/ai/index.md). Parent design: [`ai-platform-design.md`](./ai-platform-design.md) §5.D (Browser Use). This doc is the detailed design for scraping **as a shared, reusable capability that many n8n workflows consume**.
>
> **Goal:** Give the homelab a scraping platform that N n8n workflows (and kagent agents, and Claude Code) reuse as thin callers — not a copy-pasted AI-agent stack per workflow.

## Thesis — "many workflows" changes the default

The [browser-use story](../stories/ai/browser-use.md) chose **Option A: an AI-Agent node embedded in each workflow** (per-county, ×3). That is the wrong *default* once you have many workflows:

- **Duplication** — every author re-wires AI Agent + MCP Client + Structured Parser.
- **Cost** — most recurring scrapes hit the *same known site every tick*. Paying LLM tokens to re-derive a stable site's structure on every run, across many workflows, is money burned.
- **Fragility** — non-deterministic extraction on a cron schedule drifts silently.

So scraping is designed as a **shared service, tiered by cost/determinism**, where n8n workflows are thin callers and the LLM agent is an **escape hatch for the hard long tail — not the default path**. A platform for many workflows is mostly a *deterministic-tier* platform with an AI escape hatch.

## Tiers

| Tier | Endpoint | Use when | Determinism | Cost | Primary caller |
| --- | --- | --- | --- | --- | --- |
| **0 — static** | n8n HTTP Request node | a plain GET returns the data | deterministic | ~0 | n8n |
| **1 — render→markdown** | `crawl4ai.ai.svc:11235` (REST) | JS-rendered page, just need the content | deterministic | cheap (no LLM) | n8n, agents |
| **2 — scripted browser** | `playwright-mcp.ai.svc:8931/mcp` | a known multi-step flow (form/login) | deterministic tool calls | cheap (no LLM) | kagent agents, Claude Code |
| **3 — AI extraction** | `web-scraper` A2A agent | varied / unknown / hard sites | non-deterministic | LLM tokens | n8n, agents |

**Both Tier 1 (crawl4ai) and the Playwright stack are kept** — crawl4ai for cheap deterministic reads, Playwright for interactive. crawl4ai is **un-pinned from the GPU** (drop `runtimeClassName: nvidia`, the GPU nodeSelector, and the `nvidia.com/gpu` req/limit) so a headless scraper stops squatting the one 12 GB card.

**Note on Tier 2 from n8n:** raw Playwright MCP tools are meant to be *driven by an agent*, so from n8n the practical menu is **0 / 1 / 3**. Tier 2 is consumed by kagent agents and Claude Code (and, under the hood, by the Tier-3 agent). Don't try to script raw MCP tool sequences from n8n — use crawl4ai (deterministic) or the web-scraper agent (AI).

```
                          ┌──────────── n8n workflows (many) ────────────┐
                          │  each is a THIN CALLER: 1 node → endpoint → JSON │
                          └───┬──────────────┬───────────────────┬─────────┘
              Tier 0 ─────────┘   Tier 1 ────┘        Tier 3 ────┘
              HTTP Request        crawl4ai :11235      web-scraper A2A agent
              (static GET)        scrape→markdown       (url + goal + schema → JSON)
                                                              │  drives Tier 2
                                                              ▼
                                         playwright-mcp.ai.svc:8931/mcp
                                         (also used directly by kagent agents / Claude Code)
```

## The reuse contract (the crux)

The **web-scraper agent is generic scraping-as-a-service**. The *caller* supplies the target and the output shape per request:

```json
{ "url": "https://…", "goal": "find all X recorded in the last 2 days",
  "schema": { "records": [ { "field_a": "", "field_b": 0 } ] } }
```

The agent's system prompt is about *how to scrape generically and honor a caller-supplied schema* — **not** about any one domain. County deed records become just one caller passing its schema; the next workflow passes a different schema and reuses the same agent. This is what makes "many workflows" DRY. One agent, N callers.

**Downstream unchanged:** the agent returns `{"records":[…]}`; existing n8n Normalize → Merge → Filter → Dedupe → Classify → Sheet → Digest logic is preserved.

## Concurrency — serialize + stagger, don't build a load balancer

Playwright MCP is `replicas: 1`, `strategy: Recreate`, single hot browser session — a serial bottleneck. MCP streamable-HTTP is **session-stateful**, so naively scaling replicas breaks multi-turn sessions (a session must stick to one replica).

**Decision:** for a handful of cron workflows, **stagger their schedules** and let scraping serialize. That's the correct automation level for a homelab. Add consistent-hash-on-session routing across replicas **only if** real concurrency pain shows up. (crawl4ai Tier-1 calls are stateless and parallelize freely — another reason to keep the cheap tier.)

## Ownership / layout (duplication resolved)

The branch originally had `platform/ai/agents/browser_use/templates/{deployment,service,mcp-server}.yaml` **byte-identical** to `platform/ai/kubernetes/mcp/playwright.yaml` → the `playwright-mcp` Deployment had two owners.

**Resolution (operator) — the `browser_use` Helm chart owns the whole stack:**
- **`browser_use` chart** owns the Playwright MCP server (Deployment + Service + `RemoteMCPServer`) **and** the `web-scraper` Agent. The agent references the chart's own `playwright` `RemoteMCPServer` by name.
- `platform/ai/kubernetes/mcp/playwright.yaml` was **removed**, and its reference dropped from `mcp/kustomization.yaml`. (`mcp-backend.yaml` still targets `playwright-mcp.ai.svc:8931` — the chart deploys the same Service name/namespace, so the aggregated `/mcp` target still resolves.)
- **crawl4ai** stays where it was (`platform/ai/kubernetes/integrations/crawl4ai/`), restored and un-pinned from the GPU.

> Trade-off: this couples the shared Playwright *tool* to the browser-use *agent* chart rather than keeping it in the shared `mcp/` fabric. Fine for now — one deploy unit for browser-use — but if another consumer needs Playwright independent of the agent, the server is the reusable piece and may want to move back to `mcp/`.

## Guardrails

- **Egress NetworkPolicy** (highest-leverage, still open): default-deny Cilium egress on `playwright-mcp` and `crawl4ai` with a task-scoped allowlist. A browser that can open any URL is a data-exfil surface.
- **HITL** on *mutating* browser actions when an **agent** drives (kagent `requireApproval` on form-submit/auth/purchase). n8n cron scrapes are read-only navigation — lower risk.
- **Resource ceilings** already set on Playwright (CPU/mem caps, 256 Mi `/dev/shm`, non-root, `drop: ALL`). Keep them; mirror on crawl4ai.

## Implementation steps

1. **Restore crawl4ai, un-pinned from GPU** — bring back `integrations/crawl4ai/` (deployment/service/kustomization), remove `runtimeClassName: nvidia`, GPU nodeSelector, and `nvidia.com/gpu` req/limit. Re-add to `integrations/kustomization.yaml`.
2. **De-duplicate Playwright** — ✅ done: `browser_use` chart owns the server; `mcp/playwright.yaml` removed and its `mcp/kustomization.yaml` reference dropped.
3. **Generalize the `web-scraper` agent** — ✅ done: system prompt is now domain-agnostic and schema-driven (caller supplies `url` + `goal` + `schema`); keeps the chart's `playwright` `RemoteMCPServer` tool binding.
4. **Deploy** — `task ai:deploy` (mlops). Verify per the browser-use checklist: Playwright pod Ready; `RemoteMCPServer` `playwright` reports non-empty `discoveredTools`; smoke-test `browser_navigate` through agentgateway; crawl4ai returns markdown for a known URL.
5. **Egress policy** — add default-deny + allowlist CiliumNetworkPolicy for `playwright-mcp` and `crawl4ai`.
6. **First consumers** — wire the Charleston workflow to call the generic agent (schema = deed records) as the demonstrator; document the n8n calling pattern so future workflows reuse tiers 0/1/3 as a menu.

## Related

- Agents: `@architect` (owner), `@developer` (impl), `@network-agent` (Cilium egress), `@security-agent` (HITL/egress review).
- Skills: `/kagent`, `/agentgateway`, `/cilium`, `/n8n-workflow`.
