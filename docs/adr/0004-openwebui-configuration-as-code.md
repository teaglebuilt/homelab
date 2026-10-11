# ADR-0004: OpenWebUI configuration as code via env + an API reconciler

## Status
Proposed

## Context
OpenWebUI stores most settings as PersistentConfig: env vars apply only on first boot, after which DB values win. Some objects (Functions, model presets, prompts, skills, groups, MCP connections — env support for MCP-type connections is unconfirmed in 0.11) exist only in the DB. GitOps for this repo means git is authoritative.

## Decision Drivers
* **Must** keep git authoritative for security-relevant config and all code (Functions)
* **Should** keep the admin UI usable for experiments

## Considered Options
### Option 1: `ENABLE_PERSISTENT_CONFIG=false`, env only
- **Pros**: env always wins
- **Cons**: UI edits silently discarded; DB-only objects (Functions, presets, MCP connections) still unmanaged
### Option 2: Persistent config + `task openwebui:reconcile` pushing declared state through the admin API
- **Pros**: covers DB-only objects; UI stays usable
- **Cons**: a reconciler to maintain; drift between runs
### Option 3: Click-ops
- **Pros**: no work
- **Cons**: not reproducible; in-process code not reviewed

## Decision
We will use **Option 2**.

## Rationale
It is the only option that manages Functions and connections, which are the parts that carry risk.

## Consequences
### Positive
- Reviewed in-process code only; reproducible rebuilds
### Negative
- UI-made changes are drift until codified
- One OpenWebUI API key (restricted endpoints) to protect

## Implementation Notes
- Declared state: `platform/ai/integrations/openwebui/{functions,models,prompts,skills,connections}/`
- `task openwebui:reconcile` (apply) and `--check` (CI drift/hash check)
- `ENABLE_API_KEYS=true`, `API_KEY_ALLOWED_ENDPOINTS` restricted to config endpoints
- Pipelines server and `platform/ai/integrations/openwebui/pipelines/` removed

## Related Decisions
- ADR-0001, ADR-0003
