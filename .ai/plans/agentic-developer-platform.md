# Agentic Developer Platform — Design Plan

> **Status:** Design / architecture plan. Not an implementation. Produced by the
> `agentic-engineering` factory via `/homelab-architect` orchestration, grounded in the
> IndyDevDan video *"Top #1 Opportunity for Senior Engineers: Agentic Engineering"*
> ([`.ai/context/research/…2KcITKKJikA.md`](../context/research/youtube%20-%20Top%20%231%20Opportunity%20for%20Senior%20Engineers%20Agentic%20Engineering%20(2KcITKKJikA).md)).
>
> **Scope:** The **developer platform for the homelab itself** — the harness + software
> factory + GitOps landing zone that turns operator intent into shipped, validated changes to
> this monorepo. It deliberately does **not** cover the *AI platform* (agents/models/knowledge
> as a hosted product) — that is a separate plan (`ai-platform-design.md`, currently being
> reworked). This plan is about the machine that *builds* the homelab; that plan is about a
> capability the homelab *hosts*. They meet only at agentgateway + `homelab-agent` MCP.
>
> **Audience:** `homelab-developer` (implementation) and future-me.
>
> **Grounded against:** repo state (`.claude/`, `.ai/`, `.mcp.json`, `.github/workflows/`,
> `Taskfile.yml`) as of 2026-08-11. Live-cluster claims are labeled **[inferred]** until
> verified via `homelab-agent`; everything else is **[observed]** in-repo.

---

## 1. Vision & North Star

Reframe "developer platform." In the enterprise sense it means an Internal Developer Platform:
a Backstage/Port portal, golden-path scaffolding, self-service provisioning, multi-tenant, with
per-team RBAC. **Almost none of that weight applies to a single operator.**

Through the video's lens, the developer platform for *this* homelab is: **the agent harness +
software factory that converts a prompt into a merged, reconciled, validated change against the
monorepo.** Its "developers" are two: the operator, and the operator's fleet of agents. Its job
is to make *"add a capability to the homelab"* a repeatable golden path — plan → stories →
build → GitOps merge → live — instead of hand-driving `kubectl` and YAML.

The single constraint that drives every "skip" below: **one operator, and the scarce resource
is operator attention + token budget, not compute or tenancy.** That is why this plan is
telemetry-first and portal-free.

### What "good" looks like

- One entry point: `/agentic-engineering <idea>` runs the whole loop; the operator writes a
  prompt, not YAML, for the common case.
- The harness is **self-describing**: a catalog of the agents, skills, and MCP tools that
  exist, so the operator (and agents) can discover the golden paths without grepping.
- Every homelab change is **observable as it happens** — factory/harness runs trace through
  the same OTel → Grafana path the LLMs already use, so "is this agent doing useful work?" is a
  question with a dashboard answer, not a guess.
- Adding a capability never means editing the harness — it means dropping in a skill/agent/MCP
  entry. Open to extension, closed to modification.

## 2. Guiding Principles — adopt vs. skip

| Principle | Consequence |
| --- | --- |
| **For me, not for an org.** | No IDP portal (Backstage/Port), no multi-tenancy, no per-user RBAC, no service-catalog product. |
| **Compose, don't reinvent.** | The platform is the *composition* of `.claude/` + `.ai/` + kagent + agentgateway + GitOps that already exists. Build only the thin missing glue (hooks, catalog, run-log). |
| **The rented harness is the floor, not the problem.** | Claude Code is the harness *runtime*. The differentiator is the composition layer on top of it — invest there, **not** in a bespoke Pi-style net-new harness (over-engineering for one operator). |
| **Add, don't modify.** | New capability = new skill/agent/MCP entry, never a fork of the harness. Make this an invariant. |
| **Measure before you go always-on.** | No agent runs unattended until its tokens are *measured*. The video's own warning: 90% of agent cron jobs are dead-useless. |
| **Honest anti-over-engineering.** | If a component solves scale/tenancy/compliance/revenue we don't have → **skip**, and say why. |

**Adopt (from the video):** own the harness; build the *factory* not features; extensible-by-composition;
give agents broad API access behind guardrails.
**Skip / reframe:** the **token-arbitrage "infinite cash glitch"** framing (pillar 4) — a homelab
has **no revenue to capture**. Copying the tokenomics funnel literally is cargo-culting. Reframe
level-3 "value capture" as **operator toil eliminated + mean-time-to-change reduced** — the KPI is
*hours of my attention reclaimed*, not dollars. Also skip the enterprise factory theatre
(scouting/regression agent-teams, "80+ specs"): plan-review + build + validate is enough here.

## 3. Current-State Assessment

**This is consolidation, not greenfield.** The platform already exists as three loosely-joined
layers; the work is to *name* them a platform, close the observability gap, and make the golden
path discoverable. Nothing here needs a new cluster or a new product.

### Real and deployed / in-repo (observed)

| Layer | Component | Where | Notes |
| --- | --- | --- | --- |
| **Harness (DX layer)** | Claude Code harness | `.claude/agents/` (`architect`, `developer`, `network-agent`, `security-agent`, `n8n-workflow-builder`); `.claude/skills/` (~14: `agentic-engineering`, `homelab-architect`, `homelab-developer`, `kagent`, `agentgateway`, `kgateway`, `cilium`, `talos`, `nvidia-nim`, `observability-engineering`, `n8n-workflow`, `platform-engineering`, `scrape`, `infrastructure-architect`) | The DX/portal layer. **`.claude/hooks/` exists but is EMPTY** — no telemetry, no policy enforcement. |
| **Factory (procedure)** | `/agentic-engineering` 6-phase loop | `.claude/skills/agentic-engineering/SKILL.md` | Explicitly built on this video. Ground → Design → Review (5-pillar rubric) → Decompose → Build → Validate. Templates: `.ai/templates/{plan,story,invariants}.md`. |
| **Agentic access (tool fabric)** | `homelab-agent` MCP (helm/k8s/cilium/argo), `n8n` MCP, `unifi` MCP | `.mcp.json` | Live cluster + automation + network reachable as tools. All via `${AI_GATEWAY_IP}/mcp` (agentgateway boundary), n8n `/mcp-server/http`, unifi stdio. |
| **Release / landing zone** | GitOps: label-gated CI, ArgoCD, Helmfile, Taskfile | `.github/workflows/{pr-ci-checks,pr-labeler,release}.yaml`; `Taskfile.yml` (`deploy-kubernetes`, `platform:deploy`) | The factory's Phase-6 landing zone already exists. CI is **label-gated** (`docs` label → docs_ci, etc.). |
| **Observability (for LLMs)** | OTel → collector → Grafana | `platform/observability/…`; dashboards `agent-tracing`, `llm-usage` | **[inferred]** live. Covers LLM traffic — but **nothing measures factory/harness/agent runs**. |

### Gaps / footguns

1. **`.claude/hooks/` is empty.** No run telemetry, no enforced read/write discipline. The
   factory's safety rules ("mutation only in Build", "read-leaning grounding") are *documented*
   but not *enforced* by the harness. This is the single highest-leverage gap.
2. **The harness is not self-describing.** No catalog/index of agents+skills+MCP tools; a new
   capability's "golden path" is discoverable only by grepping `.claude/`. There is no
   `.ai/stories/*/index.md` yet either (the story template references one that doesn't exist).
3. **AFK is blind.** With no factory/agent telemetry, any always-on agent would burn tokens
   with no way to tell if the work is useful — exactly the failure mode the video calls out.
4. **Harness ownership boundary is ambiguous.** Per MEMORY, `~/.claude` is symlinked to
   `aiconfig/.claude` (global), yet this repo has its *own* project-scoped `.claude/`. Which
   agents/skills are homelab-specific (live here) vs. general (live in aiconfig) is unstated.
5. **Token-tax points exist.** SOPS decrypt is manual (agent can't self-serve secrets, by
   design); Proxmox/Talos control-plane APIs are not exposed as MCP tools. Some are *correctly*
   withheld (destructive); some are just friction. Not yet triaged.

## 4. Build vs Buy vs Skip

| Capability | Decision | One-liner |
| --- | --- | --- |
| IDP portal (Backstage / Port) | **Skip** | Single operator. The "portal" is Claude Code + the kagent `/mcp` endpoint. |
| Golden-path scaffolding | **Have → extend** | `.ai/templates/{plan,story}.md` + the factory loop already are the golden paths. |
| Self-service provisioning | **Have** | GitOps: `task deploy-kubernetes` / `platform:deploy` + Helmfile stages + ArgoCD. |
| Service catalog | **Have (reframed)** | The monorepo + live `homelab-agent` queries. Skip a Backstage catalog. |
| Harness telemetry + policy hooks | **Build (thin)** | Fill empty `.claude/hooks/`; enforce read/write discipline; emit run traces. Highest ROI. |
| Harness catalog / self-description | **Build (thin)** | A generated index of agents+skills+MCP tools = discoverable golden paths. |
| Factory run-log / metrics | **Build (thin)** | Prerequisite for measuring AFK value. Reuse OTel or an append-only log. |
| Always-on toil-reducer agents | **Defer** | Gated on telemetry (Phase 0). Then: drift-detection, dep-triage, health digest. |
| Custom net-new harness (Pi-style, "new harness daily") | **Skip** | Over-engineering for one operator. Rented runtime + rich composition wins. |
| Multi-agent scouting / regression teams | **Skip / defer** | Enterprise factory weight; the review→build→validate loop suffices. |
| Token-arbitrage / revenue capture (pillar 4, level 3) | **Reframe** | No revenue. KPI = operator hours reclaimed + MTTC, measured via Phase 0. |

## 5. Cross-Cutting Concerns

- **Resource discipline:** the GPU constraint belongs to the AI platform, not here. This
  platform's scarce resources are **operator attention and token spend** — hence telemetry-first
  and "measure before always-on."
- **Guardrails / security:** agentgateway stays the single tool/authz boundary (`/mcp`); HITL on
  every mutating tool; mutation only in the factory's Build phase via the `developer` agent;
  SOPS+KMS for all secrets (never surfaced into a plan/story/prompt); Cilium egress boundaries;
  **no destructive prod access** (no nuking DBs/volumes). The new hooks should *enforce* the
  read-leaning-until-Build rule the factory currently only documents. Delegate any UniFi change
  to `network-agent`; any host/RBAC/supply-chain change to `security-agent`.
- **Observability:** extend the existing OTel → Grafana path (`agent-tracing`, `llm-usage`) to
  cover harness/factory runs, so a factory run is a trace and "useful tokens" is a metric.
- **GitOps + declarative:** the entire platform is already in-repo (`.claude/`, `.ai/`,
  `platform/`, `kubernetes/`). "Deploy the platform" = merge + reconcile. Keep it that way — the
  harness config is source-controlled infra like everything else.

## 6. Phased Roadmap

Ordered by ROI-per-effort and dependency. Each phase is independently valuable; **Phase 0 gates
everything unattended.**

- **Phase 0 — Instrument & enforce the harness (hygiene).** Fill `.claude/hooks/` with (a) a
  Stop/PostToolUse hook that appends a factory/agent run-log and emits an OTel span, and (b)
  a PreToolUse guard that enforces the read-leaning-until-Build discipline (block mutating MCP
  calls outside an explicit Build context). Add a Grafana panel for harness runs. *Unlocks:* you
  can now see the platform working and safely let agents run longer. Prereq for Phase 3.
- **Phase 1 — Name the platform: catalog + invariants.** Generate a discoverable catalog of
  agents + skills + MCP tools (the golden paths) and write the platform invariants
  (`.ai/context/invariants/PLATFORM.md`: "add don't modify", "one tool boundary", "mutation only
  in Build", "measure before always-on"). Create the missing `.ai/stories/*/index.md`. *Unlocks:*
  the ad-hoc `.claude/`+`.ai/` becomes a legible platform with one entry point.
- **Phase 2 — Close the agentic-access gaps.** Triage token-tax points; expose the *safe* ones as
  MCP tools (e.g. read-only Proxmox/Talos status), consciously document the *withheld*
  destructive ones. *Unlocks:* fewer "token tax" detours mid-run.
- **Phase 3 — AFK toil-reducers (gated on Phase 0).** Introduce a *small* set of always-on agents
  whose value is measurable in operator hours: ArgoCD drift-detection → open a PR; dependency
  update triage (renovate/dependabot → agent labels + reviews); weekly cluster-health digest;
  cert/secret-expiry watch. Each ships with a "hours saved" success metric, not a token count.

## 7. Open Questions for the Operator

1. **Harness ownership boundary** — do homelab-specific agents/skills live in this repo's
   `.claude/` (project-scoped, versioned with the infra) or in the global `aiconfig/.claude`
   symlink? *Cheapest path:* keep homelab-specific ones here (they reference this repo's cluster);
   promote only genuinely-general ones to aiconfig. Needs a one-time call to stop drift.
2. **Do you want AFK agents at all**, or is the on-demand factory enough? *Cheapest path:*
   on-demand only — skip Phase 3 entirely and stop after Phase 1.
3. **Telemetry sink** — reuse the existing OTel collector for harness runs, or a lighter
   append-only local run-log? *Cheapest path:* a Stop-hook that appends JSONL to
   `.ai/context/runbook/factory-runs.jsonl`, upgrade to OTel only if you actually build dashboards.

## 8. Risks, Validation & Rollback

- **Risks / tradeoffs:** Phase 0 hooks add latency to every tool call — keep them thin
  (append + fire-and-forget span), never blocking on the network. Enforcing read/write discipline
  in a PreToolUse hook risks false-positives that block legitimate Build mutations — scope it by
  an explicit env/flag the factory sets in Build, and fail-open with a warning rather than hard
  block until trusted. AFK agents (Phase 3) are the real risk surface: an unattended agent with
  MCP access is the thing to be conservative about — hence HITL + no-prod-nuke + Phase-0 telemetry
  as hard prerequisites.
- **Validation plan:** Phase 0 — trigger a factory run, confirm a run-log entry + a trace appears
  in Grafana `agent-tracing`; confirm a mutating MCP call outside Build is blocked/warned. Phase 1
  — the catalog lists every agent/skill/MCP tool actually present (diff against `.claude/` +
  `.mcp.json`). Phase 3 — each AFK agent's first week produces the artifact it promises (a drift
  PR, a labeled dep bump) and its trace shows non-trivial useful work.
- **Rollback plan:** everything is additive and in-repo. Remove a hook file / catalog / story and
  the harness reverts to today's behavior; disable an AFK agent by deleting its n8n/kagent
  manifest. No cluster state is destructively changed by this plan.

## 9. Related Agents & Skills

- **Agents:** `@architect` (owner via `/homelab-architect`), `@developer` (implementation),
  `@security-agent` (hook policy review, guardrails), `@network-agent` (if any AFK agent touches
  UniFi).
- **Skills:** `/agentic-engineering` (the factory — the platform's runtime loop),
  `/homelab-architect`, `/homelab-developer`, `/platform-engineering`,
  `/observability-engineering` (Phase 0 telemetry), `/claude-code` (hook/harness patterns),
  `/kagent` + `/agentgateway` (tool-fabric boundary), `/n8n-workflow` (AFK glue).

## 10. Stories

Decomposed under [`.ai/stories/platform/`](../stories/platform/index.md):

- [`harness-telemetry-hooks`](../stories/platform/harness-telemetry-hooks.md) — Phase 0: fill
  `.claude/hooks/` with run-log + trace emission.
- [`harness-guardrail-hook`](../stories/platform/harness-guardrail-hook.md) — Phase 0: enforce
  read-leaning-until-Build discipline in a PreToolUse hook.
- [`platform-catalog-and-invariants`](../stories/platform/platform-catalog-and-invariants.md) —
  Phase 1: generate the golden-path catalog + write `PLATFORM.md` invariants + stories index.
- [`agentic-access-gap-triage`](../stories/platform/agentic-access-gap-triage.md) — Phase 2:
  triage token-tax points; expose safe read-only APIs as MCP, document withheld destructive ones.
- [`afk-drift-detection-agent`](../stories/platform/afk-drift-detection-agent.md) — Phase 3
  (gated on Phase 0): ArgoCD OutOfSync → open a remediation PR; measured in operator hours saved.
