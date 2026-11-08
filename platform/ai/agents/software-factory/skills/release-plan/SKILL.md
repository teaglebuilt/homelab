---
name: release-plan
description: Plan safe release and rollback based on verified CI and review gates.
---

# Release plan
1. Enumerate required checks and actual statuses.
2. Check database migrations, configuration changes and GitOps dependencies.
3. Propose canary/rollout steps, success metrics, alerts and rollback.
4. Return GO, NO-GO or BLOCKED, citing gates.
5. Do not deploy, merge, or change protected branches.
