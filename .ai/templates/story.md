# <Story Title>

> **Parent plan:** [`<plan-name>`](../../plans/<plan-name>.md)
> **Area:** <ai | kubernetes | data | security | network>
> **Status:** <todo | in-progress | done>
> **Owns:** <the one deliverable this story ships>

## Overview

<2–4 sentences: what this story delivers and why, in the smallest form that is independently
valuable. Small enough for one `/homelab-developer` run.>

## Examples / Desired Flow

1. <concrete user-visible example: "star an item in RSS → it's searchable by agents">

## Current State

- **Repo:** <owning files / deployment system — Helmfile stage, Kustomize, Compose, Terraform>
- **Live:** <what `homelab-agent` shows is deployed now, if relevant>

## Scope

**In:** <what this story does>
**Out:** <what it explicitly defers to another story>

## Implementation Notes

- Owning system & path: `<path>`
- Namespace / cluster: `<ns>` on `<cluster>`
- Dependencies / ordering: <ReferenceGrant, `needs:`, secrets, DNS, Gateway/HTTPRoute>
- Secrets: <SOPS-encrypted; never plaintext>

## Acceptance Criteria

- [ ] <observable, testable outcome>
- [ ] <…>

## Validation

<How to confirm it works against live state — the command / MCP query / dashboard, not just
"files changed">

## Related Agents & Skills

- **Agents:** <`@developer`, specialists>
- **Skills:** <domain skills to load>
