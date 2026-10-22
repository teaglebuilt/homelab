# Workflow readiness and evidence gates

All items that apply must be supported by real tool responses. If a gate is inapplicable, explain why.

## Checklist

- [ ] Correct target n8n environment; existing workflow matched by ID rather than creating duplicates.
- [ ] Baseline/snapshot captured before modifying an existing workflow; unrelated nodes/connections preserved.
- [ ] All required nodes are installed, correct versions/parameters, and reachable in a connected graph.
- [ ] Input and output shapes, mapping and fallback/error paths match the user's requirements.
- [ ] Existing credential references are valid, secrets are not embedded, and endpoint configuration is verified through safe MCP reads.
- [ ] Final saved graph was read back from n8n and matches the intended design.
- [ ] Strict static/instance validation passes; any warnings are documented and nonblocking.
- [ ] Test plan covers success, empty/malformed input, external dependency failure, duplicates/idempotency, and request-specific corner cases where applicable.
- [ ] Tests were run against safe destinations with explicitly assessed side effects.
- [ ] Each required scenario has an observed terminal execution status, correct branch, and expected output assertions, not just a trigger acknowledgment.
- [ ] Failures caused by the final edit are corrected and affected scenarios have been rerun successfully.
- [ ] Logging, retry policies, failure alerts and external rate/cost considerations are reviewed as appropriate.
- [ ] Workflow still remains inactive/draft unless activation was separately approved.
- [ ] Deployment/rollback plan and any remaining operator action are recorded.

## State definitions

| State | Meaning |
| --- | --- |
| `BLOCKED` | Required MCP tool, authorization, credentials, environment, or business rule is missing. |
| `UNSAFE_TO_TEST` | Live side effects or data privacy risks prevent approved safe execution. |
| `VALIDATED_ONLY` | Graph persisted and static validation completed, but end-to-end run unverified. |
| `PARTIALLY_TESTED` | Some scenarios passed, but acceptance-critical scenarios lack successful evidence. |
| `READY` | All required gates pass in a controlled environment; deployment status must still be stated. |
| `READY_TO_ACTIVATE` | `READY`, currently inactive/draft, and approval or a production promotion step remains. |
| `ACTIVE_VERIFIED` | Approved deployment is active; published version inspected and authorized post-publish smoke run succeeded. |

## Completion report template

```text
Outcome: READY_TO_ACTIVATE | READY | ACTIVE_VERIFIED | PARTIALLY_TESTED | VALIDATED_ONLY | BLOCKED | UNSAFE_TO_TEST
Workflow: <name> (<id>)
Environment: <instance/namespace>; draft=<state>; active=<state>
Graph: <trigger> -> <transform> -> <sink>
Changes: <created/modified nodes and behavior>
Dependencies: <service names, credential reference IDs only, nonsecret settings>
Validation: <pass/fail, warnings and dispositions>
Tests:
  - <case>: <passed/failed/unverified>; execution=<id>; assertion=<observed evidence>
  - <case>: <passed/failed/unverified>; execution=<id>; assertion=<observed evidence>
Rollback: <snapshot/reference when changing existing workflow>
Remaining: <required approval, credential, export, alert or deployment action>
```
