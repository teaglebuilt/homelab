# <Capability> — Design Plan

> **Status:** Design / architecture plan. Not an implementation. Produced by the
> `agentic-engineering` factory via `/homelab-architect` orchestration.
>
> **Scope:** <what this plan covers and what it deliberately does not>.
>
> **Audience:** `homelab-developer` (implementation) and future-me.
>
> **Grounded against:** repo state (list key files) + live cluster state (helm releases,
> k8s resources, cilium/argo state) as of <date>. Label inference vs. observed fact below.

---

## 1. Vision & North Star

<One paragraph: the capability, who it's for (default: the operator alone), and what "good"
looks like. State the single constraint that drives the "skip" decisions below — e.g. "this
is for one operator", "one 12 GB GPU", "GitOps is the backbone".>

### What "good" looks like

- <observable outcome 1>
- <observable outcome 2>

## 2. Guiding Principles — adopt vs. skip

| Principle | Consequence |
| --- | --- |
| <e.g. For me, not for an org.> | <e.g. No multi-tenancy / IdP / per-user RBAC.> |
| Compose, don't reinvent. | Reuse what's deployed; build only the thin missing glue. |
| Honest anti-over-engineering. | If a component solves scale/tenancy/compliance we don't have → **skip**. |

**Adopt:** <patterns worth taking, and from where>
**Skip:** <enterprise weight that isn't our problem, and why>

## 3. Current-State Assessment

> Consolidation + fill-the-gaps, or greenfield? Say which.

### Real and deployed (observed via `homelab-agent` / repo)

| Component | Where | Notes (repo state vs. live state) |
| --- | --- | --- |
| <component> | `<path>` | <version, namespace, what's actually running / broken> |

### Gaps / footguns

- <what's missing, misconfigured, or wastefully allocated>

## 4. Build vs. Buy vs. Skip

| Capability | Decision (Have / Build / Buy / Defer / Skip) | One-liner |
| --- | --- | --- |
| <capability> | <decision> | <why> |

## 5. Cross-Cutting Concerns

- **Resource discipline (GPU / capacity):** <the master constraint and how this respects it>
- **Guardrails / security:** <HITL on mutating tools, Cilium egress, SOPS, agentgateway boundary>
- **Observability:** <how new agents/tools trace through OTel → Grafana>
- **GitOps + declarative:** <CRDs/manifests in-repo as source of truth; `task <x>:deploy`>

## 6. Phased Roadmap

Ordered by ROI-per-effort and dependency. Each phase independently valuable.

- **Phase 0 — Hygiene / fix what's broken.** <remove footguns before adding capability>
- **Phase 1 — <highest-ROI capability>.** <deliverable + the flow it unlocks>
- **Phase 2 — <next>.** <…>

## 7. Open Questions for the Operator

1. <decision that needs the operator, with the cheapest-path option named>

## 8. Risks, Validation & Rollback

- **Risks / tradeoffs:** <honest operational burden, ordering hazards>
- **Validation plan:** <how we confirm it works against live state>
- **Rollback plan:** <how we back it out>

## 9. Related Agents & Skills

- **Agents:** `@architect` (owner via `/homelab-architect`), `@developer` (implementation),
  <specialists: `@network-agent`, `@security-agent`, …>
- **Skills:** `/homelab-architect`, <domain skills: `/kagent`, `/agentgateway`, …>

## 10. Stories

Decomposed under `.ai/stories/<area>/`:
[`<story-a>`](../stories/<area>/<story-a>.md) · [`<story-b>`](../stories/<area>/<story-b>.md)
