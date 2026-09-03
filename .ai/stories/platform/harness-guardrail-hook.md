# Harness Guardrail Hook

> **Parent plan:** [`agentic-developer-platform`](../../plans/agentic-developer-platform.md)
> **Area:** platform
> **Status:** todo
> **Owns:** enforcement of the "read-leaning until Build" discipline the factory only documents.

## Overview

The `/agentic-engineering` factory *documents* that mutation (apply/patch/delete, argo promote,
n8n create) may only happen in the Build phase, and grounding/inspection must use read-leaning
tools — but nothing *enforces* it. This story adds a `PreToolUse` hook that warns/blocks mutating
MCP/Bash calls outside an explicit Build context, turning a convention into a guardrail.

## Examples / Desired Flow

1. During Ground/Design, an agent tries `kagent-tools_k8s_apply` → the hook blocks it with a
   message pointing to the Build phase.
2. In Build, the factory sets a flag/env → the same call is allowed.

## Current State

- **Repo:** discipline lives as prose in `.claude/skills/agentic-engineering/SKILL.md`
  ("Read/write discipline (safety, non-negotiable)"); no hook enforces it. `.claude/hooks/` empty.
- **Live:** mutating tools are real (`CLAUDE.md`: "MCP changes are real") via `homelab-agent`.

## Scope

**In:** a `PreToolUse` hook that classifies mutating MCP/Bash calls and gates them on a Build-mode
signal; a documented way for the factory's Build phase to set that signal.
**Out:** run-logging/telemetry (→ `harness-telemetry-hooks`); network-layer authz (that stays at
agentgateway); HITL prompts (Claude Code already provides permission prompts).

## Implementation Notes

- Owning system & path: `.claude/hooks/<name>.sh|py` + `.claude/settings.local.json`.
- Match on tool name patterns: `*_apply`, `*_patch`, `*_delete`, `*_argo_*promote*`,
  `mcp__n8n__create*`, destructive `kubectl`/`helm` in Bash.
- **Fail-open with a loud warning** initially (log + allow) until trusted, then flip to block —
  avoids false-positives wedging legitimate Build mutations. Never withhold destructive *prod*
  access silently; that stays HITL.
- Secrets: SOPS discipline unchanged; the hook does not touch secret material.

## Acceptance Criteria

- [ ] A mutating MCP call outside Build is flagged (warn now / block once trusted).
- [ ] The same call inside a Build-mode run passes.
- [ ] The hook never blocks read-leaning grounding calls.

## Validation

Attempt a mutating MCP call in a non-Build session (expect warn/block); repeat with Build mode set
(expect allow). Confirm `k8s_get_*`/`helm_get_release` always pass.

## Related Agents & Skills

- **Agents:** `@security-agent` (owns guardrail policy review), `@developer`.
- **Skills:** `/claude-code` (PreToolUse hook shape), `/agentgateway` (where network authz lives).
