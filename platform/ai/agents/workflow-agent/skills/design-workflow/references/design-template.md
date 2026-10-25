# Mandatory design response shape

Use this structure in user-visible designs; shorten only if request is trivial.

## Summary
- **Name / goal / status**: design only | validated | created | tested | published
- **Audience/owner**: ...
- **Assumptions and confidence**: verified versus proposed
- **Why this approach**: ...

## Architecture and contracts

```text
[Trigger] -> [Validation] -> [Collect] -> [Transform/Enrich] -> [Persist/Send]
                                 |                  |
                                 +-> [Retry/Error] +-> [Audit/Alert]
```

| # | Verified n8n node + version/mode, or UNVERIFIED | Function | Input -> Output | Credential/dependency |
|---|---|---|---|---|
| 1 | ... | ... | ... | ... |

Provide realistic sample **input** and **output** JSON with no sensitive values.
List any queues, subworkflows, external API resources and branch joins.

## Integrations and configuration

For each: service, availability evidence, version, internal URL placeholder or
verified URL, credential reference and scopes, rate/volume limits, state store.
Do not claim credentials are configured unless the system confirms it.

## Reliability / security

- Error route and notification policy
- Pagination, max pages, total time bound, timeouts, backoff and rate limits
- Idempotency, deduplication, replay/backfill, retention/deletion
- Secrets/RBAC and human approval points
- External content prompt-injection and SSRF protections
- Estimated load and possible operational bottlenecks

## Test plan and rollout

| Scenario | Fixture / action | Expected result |
|---|---|---|
| Happy path | ... | ... |
| Empty / invalid input | ... | ... |
| Repeat delivery | ... | ... |
| Dependency timeout / 429 | ... | ... |
| Unauthorized request | ... | ... |
| Partial failure / recovery | ... | ... |

Include smoke-test setup, a safe incremental rollout, rollback steps, run
metrics and links to workflow logs if available.

## Evidence, gaps, next action

- **MCP tools actually called:** ...
- **Workflows checked:** ID / none / unavailable
- **Official documentation / primary sources:** URLs
- **Unknowns/blockers:** ...
- **Next action:** builder handoff, configuration, authorization, or test

Never report an ID, validation result, running endpoint, commit or successful
execution unless returned by a real tool.
