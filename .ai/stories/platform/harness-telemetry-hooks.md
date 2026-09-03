# Harness Telemetry Hooks

> **Parent plan:** [`agentic-developer-platform`](../../plans/agentic-developer-platform.md)
> **Area:** platform
> **Status:** todo
> **Owns:** the run-log + trace emission that makes factory/agent runs observable.

## Overview

`.claude/hooks/` is empty, so nothing measures whether the harness/factory is doing useful work
— the exact blind spot the source video warns about ("90% of agent cron jobs are dead-useless").
This story adds a thin, fire-and-forget hook that records each run and emits a span, turning
"is this agent useful?" into a dashboard question. It is the prerequisite for any always-on
(AFK) agent.

## Examples / Desired Flow

1. Run `/agentic-engineering <idea>` → on Stop, a JSONL line is appended to the run-log
   (timestamp, session, tools used, tokens if available, outcome).
2. Open Grafana `agent-tracing` → the run appears as a span alongside the LLM traffic.

## Current State

- **Repo:** `.claude/hooks/` exists but is empty; hooks are configured in
  `.claude/settings.local.json` (currently no hooks wired).
- **Live:** OTel collector → Grafana with `agent-tracing` / `llm-usage` dashboards **[inferred]**
  in `platform/observability/`; today they cover LLM traffic only, not harness runs.

## Scope

**In:** a `Stop` (and optionally `PostToolUse`) hook script + its `settings` wiring; append-only
run-log; optional OTel span emission behind a flag.
**Out:** the guardrail/policy enforcement (→ `harness-guardrail-hook`); building new dashboards
beyond one harness-runs panel; AFK agents themselves.

## Implementation Notes

- Owning system & path: `.claude/hooks/<name>.sh|py` + `.claude/settings.local.json` hooks block.
- Keep it **non-blocking**: append locally, fire the span best-effort; never block a tool call on
  the network. Fail-open.
- Cheapest sink (per plan Open Q3): JSONL at `.ai/context/runbook/factory-runs.jsonl`; upgrade to
  OTel only if a dashboard is actually built.
- Secrets: none in the log — never write decrypted values or tokens.

## Acceptance Criteria

- [ ] A factory run produces exactly one run-log entry with tools-used + outcome.
- [ ] The hook adds no perceptible latency and fails open if the sink is unavailable.
- [ ] (If OTel enabled) the run appears as a span in Grafana `agent-tracing`.

## Validation

Trigger a run; `tail` the run-log for the new entry; if OTel enabled, confirm the span in Grafana
via the `homelab-agent` path or the dashboard directly.

## Related Agents & Skills

- **Agents:** `@developer`, `@security-agent` (confirm no secret leakage into the log).
- **Skills:** `/claude-code` (hook patterns), `/observability-engineering` (OTel span shape).
