# Browser Use

> **Feature of** the [AI Platform](./index.md). Design context: [`.ai/plans/ai-platform-design.md`](../../plans/ai-platform-design.md) §5.D. Detailed scraping-platform design (tiers + n8n reuse): [`.ai/plans/scraping-platform.md`](../../plans/scraping-platform.md).
>
> **Goal:** Give agents *and* n8n workflows a real browser so they can drive JS-rendered sites, log into portals, fill forms, and extract data — not just fetch static HTML.

## Status

| Piece | State |
| --- | --- |
| `playwright-mcp` Deployment + Service + `RemoteMCPServer` | ✅ Written — [`platform/ai/kubernetes/mcp/playwright.yaml`](../../../platform/ai/kubernetes/mcp/playwright.yaml) |
| Wired into MCP kustomization | ✅ [`mcp/kustomization.yaml`](../../../platform/ai/kubernetes/mcp/kustomization.yaml) lists `playwright.yaml` |
| Aggregated on agentgateway `/mcp` | ✅ [`mcp-backend.yaml`](../../../platform/ai/kubernetes/mcp-backend.yaml) target `playwright-mcp` |
| **Deployed to cluster** | ❌ **Not applied** — no pod/RemoteMCPServer in `ai` ns; `playwright.yaml` is uncommitted |
| crawl4ai un-pinned from GPU + MCP-wrapped | ❌ Not done (see Guardrails) |
| Egress NetworkPolicy | ❌ Not done |
| First consumer wired (Charleston workflow) | ⛔ **Approach chosen: A (Playwright-agent, Anthropic Claude).** Blocked on 2 prerequisites (see below) |

**Bottom line:** the manifests are complete and correctly wired; nothing is running yet. "Browser use is complete" == deployed + tools discovered + smoke-tested (checklist below).

## Architecture

```
kagent agents ─┐
Claude Code    ├─▶ agentgateway  /mcp ─▶ mcp-backend ─┬─▶ playwright-mcp.ai.svc:8931/mcp   (interactive browser)
(IDE)          │                                      └─▶ crawl4ai.ai.svc:11235          (read-only scrape→md)
n8n workflows ─┘  (cross-ns: direct Service DNS, or aggregated /mcp via ReferenceGrant)
```

**Playwright MCP** (`mcr.microsoft.com/playwright/mcp:v0.0.78`, headless Chromium, Streamable HTTP on `:8931/mcp`) *is* an MCP server — it exposes ~25 browser tools (`browser_navigate`, `browser_click`, `browser_type`, `browser_snapshot`, …). It defaults to accessibility-tree snapshots (cheap, stable) with vision opt-in, and holds a hot session across calls. Run as a Deployment (not kagent `stdio` `MCPServer`) because the browser is a long-lived stateful process; `stdio` would cold-start Chromium every call.

It reaches consumers three ways, all through the existing fabric — **no new mechanism**:
1. **kagent agents** — reference the `playwright` `RemoteMCPServer` in an Agent's `tools`.
2. **Claude Code / Cursor** — already see it via the kagent controller `/mcp` aggregation (the `homelab-kagent` server in `.mcp.json`).
3. **n8n workflows** — n8n runs in-cluster (`automation` ns, node `mlops-work-01`), so it reaches `http://playwright-mcp.ai.svc.cluster.local:8931/mcp` **directly** (no NetworkPolicy blocks automation→ai). The aggregated agentgateway path is *prepared* ([`referencegrant-automation-to-mcp.yaml`](../../../platform/ai/kubernetes/referencegrant-automation-to-mcp.yaml)) but no `automation` HTTPRoute uses it yet — direct Service DNS is the pragmatic path today.

### Interactive vs. read-only (two complementary tools)
- **Playwright MCP** — *stateful interact*: JS forms, logins, multi-step flows, clicking through portals. Use when a static GET won't work.
- **crawl4ai** (already deployed, `platform/ai/kubernetes/integrations/crawl4ai/`) — *stateless read*: "give me this page as markdown." Cheaper; use for straight content extraction. Should be MCP-wrapped so agents get a `scrape_to_markdown(url)` tool.

## Guardrails (before heavy use)

- **Un-pin crawl4ai from the GPU.** It currently requests `nvidia.com/gpu: 1` (`integrations/crawl4ai/deployment.yaml`) — a headless scraper squatting on the one 12 GB card. Drop `runtimeClassName: nvidia`, the GPU nodeSelector, and the `nvidia.com/gpu` req/limit.
- **Egress policy.** A browser that can open any URL is a data-exfil surface. Add a `CiliumNetworkPolicy` on `playwright-mcp` (and crawl4ai): default-deny egress with a task-scoped allowlist. Highest-leverage control.
- **HITL for mutating actions.** When an *agent* drives the browser, gate form-submit / purchase / auth actions behind kagent `requireApproval`. (n8n cron scrapes are read-only navigation, lower risk.)
- **Resource ceiling.** The Deployment already caps CPU/mem and fixes Chromium's 64 Mi `/dev/shm` (256 Mi tmpfs). Keep it non-root + `drop: ALL` (already set).

## Completion checklist ("browser use is complete")

1. Deploy: `task ai:deploy` (mlops). Commit `playwright.yaml`.
2. `kubectl -n ai get pod -l app=playwright-mcp` → Running/Ready.
3. `kubectl -n ai get remotemcpserver playwright -o jsonpath='{.status.discoveredTools}'` → non-empty (Accepted + tools listed).
4. Smoke test through agentgateway: an agent (or `curl` MCP handshake) calls `browser_navigate` on a known JS page and gets a snapshot back.
5. Un-pin crawl4ai; add egress policy.
6. Only then wire the first workflow consumer.

## First consumer — Charleston Home Sales Monitor (`ZDtBcJfUy0nL999p`)

This active daily workflow (8 AM, emails a digest + appends to a Google Sheet) has **three scraper nodes that are dead TODO stubs**: they do plain `httpRequest` GETs against JS/ASP form-driven county deed sites (Charleston RMC, Berkeley/Dorchester ROD portals) that return no records. The sticky notes themselves say a real implementation *"needs to reverse-engineer the form POST / session flow (likely **Playwright** or an upstream data feed)."* → Playwright MCP is the missing capability; this workflow is its natural demonstrator.

### ⚠️ Honest tradeoff — a dedicated scraper already exists
There is already a **purpose-built, code-based scraper** for exactly this data: the `scraper-charleston-sales` CronJob (`platform/automation/kubernetes/scrapers/cronjob-charleston-sales.yaml`) runs `ghcr.io/nextgensolutions-llc/scrapers` (`scrapers.charleston_sales`, `LOOKBACK_DAYS=2`) daily at 6:30 AM and writes to the Postgres `leads` DB (`postgres-rw.data.svc.cluster.local`). The hard scraping is *already solved in code* and lands in a real database.

So there are **three** ways to make the n8n workflow's scraping real:

| Option | What | Reliability | Cost | "Browser use"? |
| --- | --- | --- | --- | --- |
| **A. Playwright-agent scrape in n8n** | AI-Agent node + Playwright MCP tool drives each county site, returns records in the existing normalize schema | Low–medium on these hard gov portals; non-deterministic | LLM tokens per run + a model credential in n8n | ✅ literally what was asked |
| **B. Read the Postgres `leads` DB** | Replace the stubs with a Postgres read of what the code scraper already collected | High (scraping solved in code) | Cheap, deterministic | ❌ no browser |
| **C. Hybrid** | Deploy + prove browser-use on a *tractable* target as the demonstrator; Charleston digest reads Postgres (B); reserve Playwright for sites with no code scraper | High | Low | ✅ capability available where it's actually needed |

**Decision (operator):** **A — Playwright-agent scrape inside n8n, using Anthropic Claude.** (My recommendation was C for reliability; operator chose A to exercise browser-use directly. Fragility on these gov portals is accepted and will be tuned via the agent prompt.)

## Implementation — chosen approach A

n8n has the required nodes: `@n8n/n8n-nodes-langchain.agent` (AI Agent v3.1), `@n8n/n8n-nodes-langchain.mcpClientTool` (MCP Client Tool v1.4), `@n8n/n8n-nodes-langchain.lmChatAnthropic` (Anthropic Chat Model v1.5).

**Per-county change** (×3: Charleston RMC, Berkeley ROD, Dorchester ROD) — replace each dead `httpRequest` "Fetch … (TODO)" node with:

```
AI Agent  ── ai_languageModel ─▶  Anthropic Chat Model  (cred: "Anthropic account")
   │        ── ai_tool ─────────▶  MCP Client Tool → http://playwright-mcp.ai.svc.cluster.local:8931/mcp
   │        ── ai_outputParser ─▶  Structured Output Parser  ({ records: [...] })
   ▼
(existing) Normalize <County> Items  →  Merge All Counties  → … unchanged downstream
```

- **Agent goal (per county):** "Using the browser tools, open <county deed-search URL>, search for Warranty Deeds (WD / General / Special) recorded in the last 2 days, and return every result." Output contract (structured parser) = `{ "records": [ { grantee, grantor, property_address, city, sale_price, recording_date, deed_type, document_url } ] }` — exactly what the existing Normalize nodes already map (`grantee→buyer_name`, etc.), so **all downstream logic (Merge → Filter → Dedupe → Classify → Sheet → Digest → Email) is preserved unchanged.**
- The Normalize nodes get a one-line tweak to read `records` from the agent's structured output instead of the old `httpRequest` body (the `_stub`/`records` shape already matches, so this may be a no-op).

**Prerequisites (operator, both required before I can apply):**
1. **Deploy Playwright MCP** — `task ai:deploy` (mlops), or a targeted `kubectl apply` of `mcp/playwright.yaml` + the `mcp-backend.yaml` update. Verify per the checklist above.
2. **Add an Anthropic credential in n8n** named **`Anthropic account`** (Settings → Credentials → Anthropic API, paste API key). n8n references credentials by **ID**, so this must exist before the model node can be wired.

Once both are done, the finish is mechanical: fetch the credential ID (`list_credentials`), build + `validate_workflow`, then `update_workflow` on `ZDtBcJfUy0nL999p` (remove 3 stub nodes, add 3 agent stacks, rewire). The workflow stays a no-op (no errors) until then, so nothing breaks in the interim.
