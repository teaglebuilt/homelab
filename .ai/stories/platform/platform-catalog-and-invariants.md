# Platform Catalog & Invariants

> **Parent plan:** [`agentic-developer-platform`](../../plans/agentic-developer-platform.md)
> **Area:** platform
> **Status:** todo
> **Owns:** the discoverable golden-path catalog + the platform invariants doc.

## Overview

The harness (agents + skills + MCP tools) is only discoverable by grepping `.claude/` and
`.mcp.json` — there is no catalog and no written contract for how to extend it. This story makes
the ad-hoc composition *legible as a platform*: a generated catalog of the golden paths, plus a
`PLATFORM.md` invariants doc codifying the "add don't modify / one tool boundary / mutation only
in Build / measure before always-on" rules.

## Examples / Desired Flow

1. Operator (or an agent) asks "what can this platform do?" → reads one catalog listing every
   agent, skill, and MCP tool with a one-line purpose.
2. Someone adds a capability → the invariants doc tells them to add a skill/agent/MCP entry, not
   edit the harness.

## Current State

- **Repo:** `.claude/agents/` (5 agents), `.claude/skills/` (~14 skills), `.mcp.json` (3 MCP
  servers) — no index. `.ai/context/invariants/` has `KUBERNETES.md`, `NVIDIA_NIM.md` but no
  platform/harness invariants. `.ai/templates/story.md` references a `.ai/stories/*/index.md`
  that did not exist before this plan.
- **Live:** n/a (repo-tooling story).

## Scope

**In:** a generated catalog (e.g. `.ai/context/platform-catalog.md`) diffable against the actual
`.claude/` + `.mcp.json`; `.ai/context/invariants/PLATFORM.md` (prefix `INV-*`, following
`.ai/templates/invariants.md`); confirm the stories index convention.
**Out:** a Backstage/Port portal (explicitly skipped in the plan); auto-regeneration tooling
beyond a simple script/checklist.

## Implementation Notes

- Owning system & path: `.ai/context/platform-catalog.md`, `.ai/context/invariants/PLATFORM.md`.
- The catalog must be *derivable* — a `ls .claude/{agents,skills}` + `.mcp.json` parse — so it
  can be regenerated and never drifts silently.
- Reconcile with plan Open Q1 (project `.claude/` vs global aiconfig symlink): the catalog should
  note which entries are homelab-specific vs. inherited-global.

## Acceptance Criteria

- [ ] Catalog lists every agent, skill, and MCP tool actually present, one-line purpose each.
- [ ] `PLATFORM.md` states the four invariants with correct/incorrect examples.
- [ ] Catalog entries are labeled homelab-specific vs. global.

## Validation

Diff the catalog against `ls .claude/agents .claude/skills` and the `.mcp.json` server list — no
missing or phantom entries.

## Related Agents & Skills

- **Agents:** `@architect` (owns invariants), `@developer`.
- **Skills:** `/platform-engineering`, `/claude-code`.
