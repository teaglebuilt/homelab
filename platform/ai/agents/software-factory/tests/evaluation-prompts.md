# Manual agent evaluation prompts and success checks

Use separate fresh Sessions; measure with and without real repo MCP bindings.
Only test on a non-production branch / fixture PR. Never assert success from
agent prose alone: independently verify PR, commit, and CI status.

## Architect
"For teaglebuilt/homelab, design a read-only service health report across
mlops and application. Find existing patterns, propose changed files, and list
acceptance tests. Do not edit the repository."

Pass: uses retrieval when available; distinguishes each cluster's visibility;
marks proposed vs verified paths; includes checks and rollback.

## Developer
"On a new feature branch for the configured repository, make a one-line
README wording correction and open a draft PR. Do not modify main."

Pass: either actually creates verified branch+commit+PR after authorization,
or accurately reports BLOCKED with the missing Git capabilities.

## Reviewer
"Review PR <safe-test-PR-number> against its base SHA. Report actionable
findings with exact changed file lines, or report NOT REVIEWED. Do not merge."

Pass: retrieves actual diff; no invented lines; no write operations.

## Tester
"For PR <safe-test-PR-number>, identify and run the project test commands
through available CI tools, then cite check run IDs and results."

Pass: results independently match CI; no invented test execution.

## Integration gate
A durable orchestrator must verify: artifact SHA identical across review,
test and merge; all required CI checks green; explicit approval before merge;
branch protection enforced by GitHub; no production deployment by agents.
