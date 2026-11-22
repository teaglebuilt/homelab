# AI Cost Optimizer — Homelab Implementation Plan

**Status:** Proposed / ready for implementation
**Target platform:** Talos Kubernetes on Proxmox, kagent, Agent Substrate, agentgateway/KGATEWAY, Ollama/vLLM, n8n, Prometheus/Grafana
**First pilot:** `medday-developer` (TypeScript/PNPM development workflow)
**Primary objective:** Reduce *cost per verified successful agent task* while maintaining task quality, reliability, and security.

> **Core distinction:** Running the same Claude/OpenAI API model through kagent does **not** inherently reduce token prices. Savings must come from prompt caching, cheaper-model routing, reduced context, eliminated model calls, eligible batch processing, and/or local inference. Subscription entitlements are not interchangeable with API billing.
>
> **Version caveat:** The repository snapshot and earlier discussion may refer to different kagent/agentgateway releases. Verify the installed CRDs, API shapes, prompt-cache controls, and gateway policies against the versions running in the cluster **before** applying any example manifests. This plan describes the desired architecture and integration points, not a claim that every API is already deployed.

---

## 1. Objectives and success criteria

### Goals

1. Centrally route development, research, and automation **tasks** to an appropriate agent/model (local, standard, premium).
2. Preserve native provider prompt caching, including accurate accounting of cache reads and writes.
3. Set per-task, per-agent, and periodic spending limits that protect against runaway execution.
4. Make verification results—not model self-assessments—the primary signal for escalation and success.
5. Trace each task across optimizer → kagent → harness/sandbox → gateway → model provider.
6. Compare optimized workloads against Opus-only and Sonnet-only baselines.
7. Enable future model selection based on observed *quality-adjusted cost*, not just token price.

### Non-goals (initial release)

- Reimplement kagent, Claude Code, Agent Substrate, or the LLM inference gateway.
- Guarantee hard dollar caps after a provider has accepted an in-flight request; use conservative reservations and bounded requests to minimize overspend.
- Transparently switch Claude Code harness models in the middle of a tool-use turn without verifying harness support.
- Replace Opus with a 12 GB local GPU model for complex code changes.
- Reuse Anthropic/OpenAI internal KV caches locally; a Redis response cache is not equivalent to provider prompt caching.
- Treat a green type check as sufficient for security-sensitive or semantically complex changes.

### Pilot acceptance criteria

- [ ] A task can be submitted through `POST /v1/tasks` and has a persistent ID and state.
- [ ] The router selects a model tier and records the policy decision and reason.
- [ ] `medday-developer` can execute `pnpm check-types` inside a sandbox that has the required dependencies.
- [ ] Tool timeout, sandbox failure, and model reasoning failure are classified separately.
- [ ] Verified failure can trigger **bounded** escalation from Sonnet to Opus, with budget checks.
- [ ] Task usage and estimated/actual cost are visible in Grafana, attributed to task/agent/model/provider.
- [ ] The optimizer stops launching new calls once a task's reserved budget is exhausted; any in-flight overspend is measured.
- [ ] A repeatable evaluation suite compares Opus-only, Sonnet-only, and optimized paths on the same tasks.
- [ ] The optimized strategy lowers **cost per verified successful task** without violating pre-set quality, security, or latency thresholds.

---

## 2. Reference architecture

```text
GitHub events / UI / n8n / OpenWebUI / CLI
                    |
                    v
       +----------------------------+
       | AI Cost Optimizer API      |
       | FastAPI                    |
       | - authorization            |
       | - task intake & state      |
       | - policy engine            |
       | - model/agent selection    |
       | - budget reservations      |
       | - verification/escalation  |
       +----------------------------+
          |              |          \
          |              |           +--> Postgres (tasks, costs, outcomes)
          |              +--------------> Redis (budget locks/leases)
          v
       kagent A2A / agent API
          |
          v
       Agent Harness + Substrate sandbox
       (Claude Code or native kagent harness)
          |                           \
          |                            +--> local tools (git, pnpm, tests)
          v
       agentgateway / KGATEWAY
          |               |              |
          v               v              v
       Ollama/vLLM     Sonnet/OpenAI     Opus
       (local)         (standard)       (premium)
          |               |              |
          +---------------+--------------+
                          |
                          v
       OpenTelemetry / Prometheus / Grafana
       (tokens, cache hits, spend, latency, outcomes)
```

**Routing boundary:** The initial release chooses an **agent/model at task start**. Request-level virtual-model routing or gateway callouts come later and only where the selected harness supports them safely.

**Data ownership:**

- **kagent:** agent sessions, invocation, runtime state, execution/tool integration.
- **Substrate/sandbox:** isolated filesystem, repo checkout, dependencies, command execution, resources/timeouts.
- **agentgateway:** authenticated provider access, supported traffic policies, request token/cost telemetry.
- **Optimizer:** task intent, model choice, budget lifecycle, orchestration, verifier results, escalation history, cost comparisons.
- **Prometheus/Grafana:** metrics and operational dashboards (not canonical financial ledger).

---

## 3. Proposed repository layout

Create the application under the existing `platform/ai` section of the homelab repo; deploy it through the same GitOps pattern used by current platform components.

```text
platform/ai/
├── cost-optimizer/
│   ├── README.md
│   ├── pyproject.toml
│   ├── Dockerfile
│   ├── alembic.ini
│   ├── migrations/
│   ├── app/
│   │   ├── main.py
│   │   ├── settings.py
│   │   ├── api/
│   │   │   ├── tasks.py
│   │   │   ├── decisions.py
│   │   │   ├── costs.py
│   │   │   └── health.py
│   │   ├── routing/
│   │   │   ├── classifier.py
│   │   │   ├── policy.py
│   │   │   └── selector.py
│   │   ├── budgets/
│   │   │   ├── reservations.py
│   │   │   └── accounting.py
│   │   ├── adapters/
│   │   │   ├── kagent.py
│   │   │   ├── agentgateway.py
│   │   │   └── local_models.py
│   │   ├── evaluation/
│   │   │   ├── verifier.py
│   │   │   ├── failure_classifier.py
│   │   │   └── escalation.py
│   │   ├── telemetry/
│   │   │   ├── metrics.py
│   │   │   └── tracing.py
│   │   └── storage/
│   │       ├── models.py
│   │       └── repositories.py
│   ├── policies/
│   │   ├── coding.yaml
│   │   ├── research.yaml
│   │   └── defaults.yaml
│   └── tests/
│       ├── unit/
│       ├── integration/
│       └── evals/
└── k8s/
    └── cost-optimizer/
        ├── kustomization.yaml
        ├── deployment.yaml
        ├── service.yaml
        ├── configmap.yaml
        ├── serviceaccount.yaml
        ├── networkpolicy.yaml
        ├── servicemonitor.yaml
        └── externalsecret.yaml
```

The **illustrative** `k8s/` paths should be wired into the actual root `platform/ai/k8s/kustomization.yaml`, or folded into the repository's current Argo CD application layout. Do not assume the old Envoy AI Gateway manifests are the current agentgateway deployment: inspect the live gateway/CRDs first.

---

## 4. Workstreams and milestones

### Phase 0 — Compatibility and baseline discovery

**Deliverable:** A reproducible picture of today's system and a baseline of provider usage.

- [ ] Inventory installed versions and CRDs for `kagent`, `AgentTemplate`, `ModelConfig`, `AgentHarness`, Agent Substrate, agentgateway/KGATEWAY, and any virtual-model resources.
- [ ] Identify which `medday-developer` harness is active: native kagent or managed Claude Code.
- [ ] Verify the exact mechanism by which that harness receives provider credentials, model selection, and request routing.
- [ ] Document the current sandbox Dockerfile, repository checkout/authentication, `node`/`pnpm` versions, package installation, working directory, and `pnpm check-types` execution.
- [ ] Trace how task/agent/session IDs can flow through gateway telemetry; add correlation IDs where missing.
- [ ] Confirm the APIs for fetching input/output/cache token usage and exact billing rates for the active models.
- [ ] Capture current Opus-only cost, success rate, duration, number of model calls, and failure classes on representative workloads.

**Exit gate:** The Medday task is runnable end-to-end and its spend is attributable, or known instrumentation gaps are documented with an implementation owner.

### Phase 1 — Usage telemetry and prompt caching

**Deliverable:** A dashboard showing where money is spent before optimization begins.

- [ ] Enable supported token and cost metrics in the gateway, including input, output, cached-input reads, and cache writes where exposed.
- [ ] Instrument optimizer and agent invocations with OpenTelemetry spans and stable attributes: `task_id`, `agent_name`, `harness`, `model`, `provider`, `routing_tier`, `outcome`.
- [ ] Keep task IDs as trace/log attributes; avoid high-cardinality `task_id` labels on all Prometheus metrics.
- [ ] Set up provider-specific caching correctly: `anthropic.promptCaching` only where supported for the native kagent harness; validate Claude Code's own caching independently.
- [ ] Stabilize tool definitions and system prompts where feasible so repeated calls can reuse cached prefixes.
- [ ] Reconcile reported token usage against provider billing for a sample of runs.
- [ ] Build Grafana panels: cost by model/agent, cost by task class, cache-read ratio, error/retry rate, latency, and effective cost per success.

**Exit gate:** Every pilot task has cost attribution and a documented caching read/write policy.

### Phase 2 — Optimizer API and deterministic policies

**Deliverable:** A service that routes tasks deliberately, not heuristically at every token.

- [ ] Build FastAPI endpoints for submitting tasks, reading status, retrieving decisions, and reporting task outcomes.
- [ ] Define normalized task categories: `typecheck`, `lint`, `format`, `summarize_logs`, `code_fix`, `refactor`, `architecture`, `research`.
- [ ] Create a deterministic rules engine based on task class, criticality, expected duration/context, verification availability, previous failures, and budget.
- [ ] Introduce model tiers: `none`, `local`, `standard`, `premium`.
- [ ] Map each tier to a **validated** model and kagent agent configuration. Create Sonnet and Opus variants of `medday-developer` with shared tools and sandbox image.
- [ ] Define explicit fallback behavior if the preferred model/provider is unavailable (not necessarily an automatic premium-model escalation).
- [ ] Add authenticated, idempotent task submission so GitHub/n8n retries do not double-run work.
- [ ] Persist task states (`queued`, `running`, `verifying`, `escalating`, `succeeded`, `failed`, `cancelled`) in PostgreSQL.

**Exit gate:** A policy-selected Medday task runs on Sonnet or Opus with a stored decision reason and traceable outcome.

### Phase 3 — Budget enforcement and bounded escalation

**Deliverable:** Autonomous jobs with controlled financial exposure.

- [ ] Define budgets for each job and per agent/day/month with separate estimation and actual-ledger fields.
- [ ] Reserve estimated worst-case spend atomically using PostgreSQL transactions or Redis atomic operations/leases; prevent concurrent double-spend.
- [ ] Bound `max_output_tokens`, number of calls, total runtime, and maximum escalation attempts.
- [ ] Reconcile final provider usage and release unused reservations.
- [ ] Classify failures: **environment/tool timeout**, **dependency/auth/network**, **model output/logic**, **verification failure**, **unknown**.
- [ ] Escalate from Sonnet to Opus only if a verified *model-addressable* failure occurs and remaining budget/policy allows.
- [ ] Hand the premium agent a concise failure report, changed files, test output, and relevant context rather than blindly replaying the entire transcript.
- [ ] Ensure the optimizer can stop creating new requests if a threshold is exceeded; explicitly document residual in-flight overrun risk.
- [ ] Add operational alerts for abnormal cost spikes, excessive retries, cache regression, and runaway sandbox jobs.

**Exit gate:** A failed Sonnet task can either terminate with a correct failure reason or escalate once within a configured limit. Budget exhaustion stops additional model calls.

### Phase 4 — Automated verification and evaluation

**Deliverable:** Confidence that lowering costs does not silently degrade engineering quality.

- [ ] Introduce task-specific deterministic verifiers (e.g., `pnpm check-types`, tests, lint, build).
- [ ] Run verifiers inside a correctly provisioned sandbox without charging model tokens for the command itself.
- [ ] Add worktree/branch isolation, pre/post diff capture, controlled repository permissions, and clean up abandoned environments.
- [ ] Create 30–50 representative benchmark tasks from real, reproducible failures with frozen inputs and target success conditions.
- [ ] Compare **Opus-only**, **Sonnet-only**, and **optimizer-routed** arms with matching tools, timeouts, context, and verification criteria.
- [ ] Measure completion rate, quality issues, total spend (including retries), wall-clock time, cache hit rates, and cost per success.
- [ ] Include security review or human approval for changes to auth, infrastructure, secrets, and critical operations.
- [ ] Define acceptable quality/latency regression thresholds before running the experiment.

**Exit gate:** The optimized route demonstrates lower cost per verified success under the agreed quality gates.

### Phase 5 — Adaptive and request-level optimization (optional)

**Deliverable:** Data-driven routing beyond static rules.

- [ ] Analyze historical task complexity and model success/failure rates.
- [ ] Introduce policy simulation/shadow mode before automatically applying learned routing decisions.
- [ ] Evaluate gateway virtual models or HTTP callouts only after validating the installed CRD shapes and compatibility with native Anthropic/Claude Code traffic.
- [ ] Add local-model task classification/summarization selectively; benchmark classification latency and accuracy against deterministic routing.
- [ ] Implement context minimization with repo search, AST/file-diff retrieval, and memory/RAG; track savings and accuracy separately.
- [ ] Add provider batch APIs for non-interactive research, extraction, and evaluation jobs when supported and beneficial.
- [ ] Expand from Medday to infrastructure, security, research, and n8n agents.

**Exit gate:** Adaptive decisions measurably improve cost per success over the deterministic policy in a controlled trial.

---

## 5. Initial policy design

```yaml
# platform/ai/cost-optimizer/policies/coding.yaml
version: 1
policy: coding-default

defaults:
  model_tier: standard
  max_escalations: 1
  require_verification: true
  max_task_cost_usd: 2.00
  max_runtime_seconds: 1800

rules:
  - match:
      kind: [typecheck, lint, format]
    tier: none
    execution: sandbox-command

  - match:
      kind: [summarize_logs, classify]
    tier: local

  - match:
      critical: true
    tier: premium
    require_approval: true

  - match:
      complexity: high
    tier: premium

  - match:
      kind: [code_fix, refactor]
    tier: standard

escalation:
  from: standard
  to: premium
  allowed_failure_classes:
    - verified_model_failure
  disallowed_failure_classes:
    - tool_timeout
    - missing_dependencies
    - repository_auth_failure
    - provider_outage
  max_attempts: 1
```

This is an **optimizer-owned YAML schema**, not a kagent or agentgateway CRD. Implement schema validation and unit tests before using it.

### Initial routing heuristic

| Task | First action / model | Escalation rule |
|---|---|---|
| `pnpm check-types` | Sandbox command; **no LLM** | Diagnose environment failures separately |
| Parse type-check output | Local model or simple parser | Standard model if interpretation needed |
| Fix straightforward TypeScript errors | Sonnet | Opus only after verified model-addressable failure |
| Multi-package refactor | Sonnet or Opus according to complexity | Verification + policy gate |
| Security-sensitive code/infrastructure | Premium + human review | Never auto-apply sensitive changes |
| Routine research extraction | Local/standard; batch if eligible | Premium on quality failure |

---

## 6. API contract (MVP)

### Submit task

```http
POST /v1/tasks
Content-Type: application/json
Authorization: Bearer <task-client-token>
Idempotency-Key: <stable-request-key>
```

```json
{
  "agent": "medday-developer",
  "kind": "code_fix",
  "task": "Fix the TypeScript errors in the Medday frontend",
  "repository": "nextgensolutions-llc/medday",
  "revision": "<commit-sha>",
  "budget_usd": 2.0,
  "optimize": true,
  "verification": ["pnpm check-types"]
}
```

### Return task decision

```json
{
  "task_id": "<uuid>",
  "status": "queued",
  "selected_tier": "standard",
  "selected_model": "<configured-sonnet-model-id>",
  "selected_agent": "medday-developer-sonnet",
  "decision_reason": "code_fix; standard complexity; deterministic verification available",
  "max_task_cost_usd": 2.0
}
```

### Query task

- `GET /v1/tasks/{task_id}` — lifecycle, current model, attempts and verification status.
- `GET /v1/tasks/{task_id}/costs` — estimated, reserved and actual cost, including cache-read/write breakdown.
- `GET /v1/tasks/{task_id}/decisions` — routing/escalation history with policy version.
- `POST /v1/tasks/{task_id}/cancel` — stop future work; cancel running session if supported by runtime.

**Implementation note:** Treat the response shapes above as our own API design. Discover and use the specific supported kagent A2A/agent invocation API on the installed version rather than hard-coding an unverified route.

---

## 7. Data model and instrumentation

### PostgreSQL tables

- `tasks`: ID, requester, repository, commit, category, priority, budget, state, created/finished timestamps.
- `task_attempts`: attempt ID, task ID, model, provider, agent, harness, status, runtime, failure class.
- `routing_decisions`: policy version, features, chosen tier/model, rationale, alternatives, timestamp.
- `usage_events`: provider request ID, tokens (input/output/cache read/cache write), estimated and billed cost, pricing version.
- `budget_reservations`: reservation ID, task/agent, amount, lease/state, created/settled timestamps.
- `verification_results`: command, environment image/version, exit code, timeout flag, stdout/stderr artifact references.
- `task_outcomes`: verified success, human review, quality signals, total spend, elapsed time.

### Prometheus / OpenTelemetry

Recommended low-cardinality metrics:

```text
ai_optimizer_requests_total{agent,provider,tier,outcome}
ai_optimizer_task_cost_usd_total{agent,provider,tier}
ai_optimizer_tasks_verified_total{agent,kind,outcome}
ai_optimizer_escalations_total{agent,from_tier,to_tier,reason}
ai_optimizer_task_duration_seconds_bucket{agent,kind}
ai_optimizer_cache_tokens_total{provider,model,type}
ai_optimizer_budget_denials_total{agent,reason}
```

Use trace/log fields—not unbounded Prometheus labels—for `task_id`, exact repository URL, request ID, or session ID.

### Key outcome metric

```text
cost_per_success = total_cost_of_all_attempts / verified_successful_tasks
```

Also track:

- Verified success rate and regression rate.
- Mean/p95 duration to verified completion.
- Number of model calls per successful task.
- Cache-read share of eligible prompt tokens and cache-write premiums.
- Failed work and escalations as a percentage of total spend.
- Budget forecast error and actual cost overruns.

---

## 8. Medday pilot workflow

1. GitHub event, CLI, or n8n submits an idempotent `code_fix` task against a fixed revision.
2. Optimizer authenticates request, loads policy, checks current budget and chooses `medday-developer-sonnet`.
3. kagent runs the chosen Claude Code agent against the isolated sandbox; repository credentials are provided as short-lived, least-privileged secrets.
4. Sandbox prepares dependencies using a prebuilt image and/or reproducible `pnpm install --frozen-lockfile` strategy.
5. Agent changes the branch and executes `pnpm check-types`.
6. Optimizer receives structured command/result telemetry and classifies the outcome.
7. If **type check passes**, apply any additional required tests/security checks, then mark verified success.
8. If **model-addressable verification fails**, check remaining budget and optionally rerun using the Opus agent with concise failure context.
9. If **tool timeout, unavailable dependency, failed clone, provider outage, or sandbox issue**, fail/repair infrastructure rather than spending money on Opus escalation.
10. Reconcile usage, release unused reservations, persist outcome, and render a cost comparison in Grafana.

### Medday-specific prerequisites

- The sandbox image must include pinned Node.js and pnpm versions plus all package/build dependencies.
- Working directory must match the repository/monorepo package graph.
- Private GitHub clone must use a GitHub App installation token or appropriately scoped credential; do not embed tokens in clone URLs, logs, or images.
- Configure command/sandbox lifetime separately from model request timeouts; measure which layer is timing out before changing values.
- Ensure the verifier cannot be tricked by an agent into editing or bypassing the checking script; invoke a trusted, fixed command from an independent verification phase.

---

## 9. Security and reliability guardrails

- [ ] Authenticate every optimizer request; authorize callers per repository and allowed agent.
- [ ] Keep provider credentials server-side; never allow arbitrary client headers to select high-cost premium backends without policy authorization.
- [ ] Store secrets in the existing secret-management flow (e.g., External Secrets/SOPS); prefer short-lived GitHub App tokens.
- [ ] Apply network policies and egress controls to the sandbox; restrict host mounts, credentials, and Kubernetes permissions.
- [ ] Run untrusted code in an isolated sandbox; review Kata/VM isolation for stronger multi-tenant boundaries.
- [ ] Treat retrieved repository content, documentation, and tool output as untrusted (prompt-injection defense).
- [ ] Require approval for production infrastructure changes, privileged operations, destructive actions, and sensitive security changes.
- [ ] Add cancellation, idempotency keys, retries with exponential backoff, dead-letter handling, and task lease expiry.
- [ ] Keep an audit trail of routing policy changes, budget overrides, model selection, and executed commands.
- [ ] Degrade safely when the optimizer, gateway, database, or provider is unavailable.

---

## 10. Testing strategy

| Layer | Tests | Release gate |
|---|---|---|
| Routing | Unit tests covering policy precedence, task classes, budget constraints | All deterministic cases pass |
| Budget accounting | Concurrent reservations, cancellation, expiry, reconciliation | No double-reserve; bounded exposure |
| kagent adapter | Mock A2A calls, task state mapping, cancellation | Retries/idempotency verified |
| Gateway integration | Real token/cost telemetry, cache-read/write behavior | Metrics reconcile with billed usage |
| Sandbox verifier | Dependency preparation, timeout, exit code, malicious task content | Environment failures classified correctly |
| Full task | Sonnet success, failure → Opus, provider outage, exhausted budget | Correct end states and spend accounting |
| Comparative evals | Opus-only vs Sonnet-only vs routed on frozen task set | Lower cost/success without quality regression |

Recommended CI pipeline: lint and type-check → unit tests → integration tests with test services → policy simulation → staging rollout → controlled benchmark → production enablement.

---

## 11. First pull requests (suggested sequencing)

### PR 1 — Observability baseline

- [ ] Document live kagent/agentgateway/harness versions and capabilities.
- [ ] Enable relevant traces and token/cost metrics.
- [ ] Add Grafana dashboard and baseline-run documentation.

### PR 2 — Optimizer API scaffold

- [ ] FastAPI project, Dockerfile, tests, health/readiness endpoints.
- [ ] PostgreSQL schema/migrations and Redis connections.
- [ ] Task submission with authentication and idempotency.
- [ ] Kubernetes deployment/service, security, and ServiceMonitor manifests.

### PR 3 — Model routing and kagent adapter

- [ ] Validated Sonnet/Opus agent configurations sharing the same sandbox.
- [ ] Policy loader and deterministic model selector.
- [ ] kagent adapter and persistent task lifecycle tracking.

### PR 4 — Budgets and verification

- [ ] Budget reservation/settlement and alerting.
- [ ] Trusted sandbox verifier for `pnpm check-types`.
- [ ] Failure classification and one bounded Opus escalation.

### PR 5 — Benchmarks and rollout

- [ ] Frozen 30–50 task evaluation suite.
- [ ] Baseline comparison dashboard/report.
- [ ] Canary/shadow rollout and documented rollback.

---

## 12. Rollout, rollback, and operations

1. Deploy in **observation-only mode**. All requests still use the existing agent/model; only metadata and usage are collected.
2. Enable **shadow routing**: compute proposed model choice, but do not alter execution.
3. Canary on a limited set of Medday task IDs, using small budgets and no automatic escalation initially.
4. Enable bounded Sonnet → Opus escalation after verification and failure classification are stable.
5. Increase scope gradually to research and n8n agents once benchmark results justify it.
6. Keep a simple feature flag to force **Opus-only**, **Sonnet-only**, or **routing disabled** to recover quickly.

**Runbook triggers:** missing metrics, provider billing mismatch, stale budget locks, runaway retries, sandbox timeout, cache regression, or unexpected increase in verification failures.

---

## 13. Outstanding design decisions

These do **not** block the scaffold, but must be confirmed before deploying production routing:

- Which kagent/harness versions are currently installed in the live cluster?
- Is the primary path direct Anthropic API, AWS Bedrock, or gateway-mediated Anthropic access?
- Which `medday-developer` manifests and Dockerfile are canonical?
- Will PostgreSQL be shared with an existing platform instance or deployed specifically for the optimizer?
- Which sandbox runtime (container vs Kata/VM) is approved for executing repository code?
- What is an acceptable per-task initial budget, and what changes require explicit human approval?
- Which outcomes beyond `pnpm check-types` count as a successful software-development task?
- Which model IDs and rate-card revisions should be used for cost estimation at deployment time?

---

## 14. Definition of done for the first release

A user can submit a Medday development task, and the platform:

1. Selects the appropriate agent/model using a readable, versioned policy.
2. Runs the task in a correctly provisioned isolated sandbox.
3. Executes a trusted verification command.
4. Distinguishes environment failures from model failures.
5. Escalates only when justified, within a defined call/runtime/budget limit.
6. Captures auditable provider token usage, cache charges, and total task cost.
7. Displays the outcome and cost in Grafana.
8. Can be compared against the same task executed with Opus-only or Sonnet-only.

**Success is not “more requests routed to local models.” Success is lower total cost per verified successful task, with no unacceptable regressions in correctness, safety, or delivery time.**
