---
name: agentic-engineering
description: Run an idea through the homelab software factory — ground it in live cluster state, design it, review it against the five pillars, decompose it into stories, build it, and validate. Use when starting a new capability, planning an architecture change, or turning a rough idea into an executable plan. Triggers on: run the factory, build this out, plan and build, architect and implement, software factory, agentic engineering.
argument-hint: "<idea or capability to run through the factory>"
disable-model-invocation: true
---

# Agentic Engineering — The Homelab Software Factory

Turn this idea into a grounded, reviewed, decomposed, and (optionally) built change:

$ARGUMENTS

If no idea was supplied, report that `/agentic-engineering` requires an idea or
capability to run through the factory, and stop.

## Prime Directive: use everything at your fingertips

This factory is not paper-planning. Every phase grounds in **real state** and reuses the
**real tools** this repo exposes. Do not invent cluster state you can query.

### Tool inventory (what the factory delegates to)

| Fabric | Access | Used in phase |
| --- | --- | --- |
| `homelab-agent` MCP (`kagent-tools_helm_*`, `_k8s_*`, `_cilium_*`, `_argo_*`) | Live cluster: releases, resources, events, logs, endpoint health, rollouts | Ground, Design, Validate |
| `n8n` MCP (`mcp__n8n__*`) | Inspect/build workflows (event & cron glue) | Ground (inspect), Build (create) |
| `unifi` MCP | Network fabric — **delegate to `network-agent`**, never drive directly | Design/Build (via agent) |
| Domain skills (`/kagent`, `/agentgateway`, `/kgateway`, `/talos`, `/cilium`, `/nvidia-nim`, `/observability-engineering`, `/n8n-workflow`, `/scrape`, `/cloudflare-one`) | Deep domain knowledge, loaded on demand | Design, Build |
| Specialist agents (`network-agent`, `security-agent`, `scraping-architect`) | Owned sub-domains | Design (review), Build (delegate) |

### Read/write discipline (safety, non-negotiable)

- **Grounding and inspection use read-leaning tools only**: `kagent-tools_k8s_get_*` /
  `_describe_*`, `helm_get_release`, `cilium_get_endpoint_health`, `argo_*` list/get,
  `mcp__n8n__get_*`/`search_*`. Never `apply`/`patch`/`delete`/`argo promote`/`n8n create`
  during Ground, Design, Review, or Decompose.
- **All mutation happens in Build**, through `/homelab-developer` (the `developer` agent has
  full tools), with intent confirmed. This mirrors `CLAUDE.md`'s rule: MCP changes are real.
- Secrets are **SOPS+KMS** only — never surfaced into a plan, story, or prompt in plaintext.

## The Loop

Run the phases in order. Each phase has a gate — do not advance past a failed gate without
telling the operator. Skipping phases is allowed **only** when the operator explicitly scopes
it (e.g. "just design it", "the plan exists, decompose and build").

### Phase 0 — Frame

- Restate the idea in one paragraph: the capability, who it's for (default: the operator
  alone), and the smallest version that delivers value.
- Name the affected surface: which cluster (`mlops` / `application`), which `platform/*` or
  `kubernetes/*` area, which deployment system owns it.
- **Gate:** if the idea is actually two ideas, split it and confirm which one runs first.

### Phase 1 — Ground in reality (repo + live cluster)

Establish current state from **both** sources, and label which is which:

1. **Repo state** — read the owning files, `CLAUDE.md` conventions, existing
   `.ai/plans/*.md` that overlap (especially `ai-platform-design.md`, the AI-platform SoT).
2. **Live state** — via `homelab-agent`, snapshot only what the decision depends on:
   what's actually released (`helm_get_release`), what's deployed (`k8s_get_*`), endpoint
   health / policy (`cilium_*`), rollout status (`argo_*`). Inspect n8n workflows if the
   idea touches automation.
- **Gate:** you can state, with evidence, what already exists that this idea overlaps.
  Duplication is worse than imperfection — if it already exists, say so and stop.

### Phase 2 — Design

Delegate the architecture to the existing architect path — do not reason it out here:

```
/homelab-architect <idea + the Phase-1 grounding you gathered>
```

That fork (the `architect` agent, opus/plan-mode, `homelab-agent`-equipped) will route to
domain skills and specialist agents and return a structured recommendation.

- Write the result to **`.ai/plans/<kebab-name>.md`** using `.ai/templates/plan.md` as the
  mold. If the idea extends an existing plan (e.g. the AI platform), **edit that plan**
  instead of forking a parallel one.
- **Gate:** the plan names affected files, owning deployment system + Helmfile stage,
  dependencies/ordering, risks, a validation plan, and a rollback plan.

### Phase 3 — Plan review (the five-pillar + anti-over-engineering rubric)

Review the plan against both the operator's standing bar and the five pillars. Be adversarial;
the operator *expects* pushback and honest admission of over-engineering.

**Anti-over-engineering (the operator's standing bar):**
- Does any component exist to solve scale / multi-tenancy / compliance this single-operator
  homelab does not have? → cut it, call it a "skip", say why.
- Does an existing tool already cover this need? → reuse it; new tools need strong cause.
- Does it break Helmfile stage ordering, ReferenceGrant/RBAC, or SOPS discipline? → fix before build.

**Five pillars (does the change strengthen the harness, or just add a feature?):**
1. **Agent Harness** — does it make the runtime the agents live in better, or bolt on a rented tool?
2. **Software Factory** — is it a repeatable procedure or a one-off? Prefer the procedure.
3. **Extensible** — pluggable/swappable behind the existing MCP-and-skills boundary, "open to extension, closed to modification"?
4. **Always-On / tokenomics** — if it runs unattended, is the token spend justified and *measured*? (No telemetry today — flag anything that assumes it.)
5. **Agentic Access** — is every new capability reachable as an MCP tool / CLI, or does it add a "token tax"?

- **Gate:** every rubric objection is either resolved in the plan or explicitly accepted by
  the operator with a reason. Record accepted tradeoffs in the plan's "Open Questions".

### Phase 4 — Decompose into stories

Break the approved plan into independently-valuable stories under
**`.ai/stories/<area>/<kebab-name>.md`** (`<area>` = `ai`, `kubernetes`, `data`, `security`,
`network`, …), using `.ai/templates/story.md`. Maintain `.ai/stories/<area>/index.md` as the
list. Each story is small enough for one `/homelab-developer` run and states its own
acceptance criteria and validation.

- **Gate:** stories are ordered by dependency and ROI-per-effort; each links back to the plan.

### Phase 5 — Build

For each story, in order, hand off to the developer path:

```
/homelab-developer .ai/stories/<area>/<name>.md
```

The `developer` agent (full tools) implements, following repo patterns, keeping versions
pinned and secrets in SOPS, and **may verify its own changes landed** via `homelab-agent`
(`k8s_get_*`, `helm_get_release`, `argo_*`). Stop and escalate to `/homelab-architect` if a
story surfaces an unresolved architecture decision.

- **Gate:** the change is applied *and* its validation step (from the story) passes.

### Phase 6 — Validate

Confirm the capability works end-to-end against **live state**, not just that files changed:
query the cluster via `homelab-agent`, run the story's validation, check the relevant
Grafana/OTel path (`agent-tracing`, `llm-usage`) if the change touches agents/LLMs. Report
outcomes faithfully — if a validation step was skipped or failed, say so with the evidence.

## Output contract

At minimum, running this factory produces:
1. A `.ai/plans/<name>.md` (new or edited) grounded in repo + live state.
2. A set of `.ai/stories/<area>/*.md` decomposed from it, with an updated index.
3. For any built story: the applied change + its validation result.

Reference specific repository paths and specific live-state evidence. Never hand back generic
advice where repo or cluster evidence is available.
