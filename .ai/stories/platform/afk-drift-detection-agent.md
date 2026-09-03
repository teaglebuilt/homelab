# AFK Drift-Detection Agent

> **Parent plan:** [`agentic-developer-platform`](../../plans/agentic-developer-platform.md)
> **Area:** platform
> **Status:** todo
> **Owns:** the first always-on agent — ArgoCD drift → remediation PR — measured in hours saved.

## Overview

This is the plan's Phase 3 pilot for "always-on agents that produce *useful* tokens." Instead of
the video's revenue framing (which does not apply to a homelab), success is measured in **operator
toil eliminated**: when ArgoCD reports an app OutOfSync, an agent investigates and opens a
remediation PR, so the operator reviews a diff instead of hunting drift by hand. It is deliberately
gated on Phase 0 telemetry — no unattended agent ships until its tokens are measurable.

## Examples / Desired Flow

1. ArgoCD marks an Application OutOfSync → the agent inspects via `homelab-agent` (`argo_*`,
   `k8s_get_*`) → opens a PR that reconciles repo ⇄ cluster, labeled for CI.
2. Weekly, the operator sees N drift PRs auto-raised instead of discovering drift reactively.

## Current State

- **Repo:** GitOps via ArgoCD + Helmfile; CI is label-gated (`.github/workflows/pr-ci-checks.yaml`).
  n8n is live with MCP access to the `ai` fabric (event/cron glue). No drift agent today.
- **Live:** ArgoCD sync status via `homelab-agent` `argo_*` **[inferred]**.
- **Blocked by:** `harness-telemetry-hooks` + `harness-guardrail-hook` (Phase 0) — hard prereqs.

## Scope

**In:** one scheduled/eventful agent (n8n cron or kagent) that detects OutOfSync and opens a PR;
a "hours saved" success metric; HITL — it opens a PR, it does **not** auto-sync prod.
**Out:** auto-remediation without human review; touching destructive resources; any second AFK
agent (dep-triage, health digest come later, same pattern).

## Implementation Notes

- Owning system & path: `platform/automation/kubernetes/n8n/` (cron/event workflow) or a kagent
  Agent + schedule; PRs via `gh`.
- **Read-only detection, PR-only action** — never `argo promote`/`sync` prod unattended; the PR +
  existing CI + operator review is the gate.
- Must emit run telemetry (Phase 0) so "useful tokens" is verifiable, not assumed.
- Delegate network-touching remediation to `network-agent`; secrets stay SOPS.

## Acceptance Criteria

- [ ] A real OutOfSync condition yields an auto-opened, correctly-labeled remediation PR.
- [ ] The agent never mutates prod state directly; it only proposes.
- [ ] Its runs appear in the Phase-0 run-log/trace with non-trivial useful work.
- [ ] First-week outcome recorded as operator-hours-saved, not token count.

## Validation

Induce (or wait for) an OutOfSync app; confirm the PR is raised and accurate; confirm via the
run-log that the agent's tokens produced the PR (not idle polling).

## Related Agents & Skills

- **Agents:** `@developer`, `@security-agent` (unattended-access review), `@network-agent` (if net).
- **Skills:** `/n8n-workflow`, `/kagent`, `/observability-engineering` (verify useful-token metric).
