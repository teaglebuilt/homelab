# ADR-0008: OpenWebUI background tasks run on the local vLLM model

## Status
Proposed

## Context
OpenWebUI runs auxiliary generations (titles, tags, follow-ups, search/retrieval query rewriting, autocomplete) on the task model. `TASK_MODEL_EXTERNAL` is not set in values.yaml, so these default to the current chat model — Claude/Opus when chatting via /claude, and the A2A Pipe when chatting with an agent. vLLM serves Qwen2.5-3B-Instruct as `vllm-selfhosted` on the mlops 4070 SUPER.

## Decision Drivers
* **Must not** spend hosted-model tokens on titles and tags
* **Must not** trigger agent runs for auxiliary tasks

## Considered Options
### Option 1: Current chat model (status quo)
- **Pros**: no config
- **Cons**: hosted cost; agent runs triggered by title generation
### Option 2: gpt-4o-mini
- **Pros**: reliable; cheap
- **Cons**: still hosted
### Option 3: vllm-selfhosted
- **Pros**: free; local
- **Cons**: depends on GPU availability; small-model JSON reliability

## Decision
**Option 3**, with Option 2 as the documented fallback while GPU reliability work is open.

## Rationale
Auxiliary tasks are short and low-stakes, which fits a 3B model.

## Consequences
### Positive
- Removes per-chat hosted overhead
### Negative
- Titles and tags fail softly when vLLM is down
- Autocomplete disabled

## Implementation Notes
- `TASK_MODEL_EXTERNAL=vllm-selfhosted` (match the connection prefix), `ENABLE_AUTOCOMPLETE_GENERATION=false`
- The Pipe still returns early on task requests as defence in depth
- Verify the effective value in the admin UI after the fresh start (PersistentConfig)

## Related Decisions
- ADR-0001, ADR-0004
