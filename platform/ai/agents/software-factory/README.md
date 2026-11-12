# Repo-scoped Software Factory for kagent 1.x

A reusable Helm **application chart** that installs one `AgentTemplate` + one
`Agent` for each enabled role, using existing `Harness`, `ModelConfig` and MCP
resources in namespace `ai`. **No additional kagent controller, GPU deployment,
Postgres, Agent Substrate, or Helm CRDs are installed.**

## Recommendation: install the chart per repo; share the platform

```
mlops / namespace ai
  shared: kagent controller + Harness(kagent) + ModelConfigs + Substrate + MCP
  release factory-showyourdream: architect / developer / reviewer / tester / security
  release factory-homelab:       architect / developer / reviewer / tester / release
  release factory-anotherrepo:   architect / developer / reviewer / tester
```

Each release has unique named agents (`factory-showyourdream-architect`, etc.)
with a repository-scoped prompt and selected tools. **Helm release scoping is
not a security boundary**. Enforce repo scoping in GitHub App tokens and MCP.

## Prerequisites

- kagent v1alpha3 CRDs/controller running in target namespace (your `ai`).
- Existing `Harness/kagent` and `ModelConfig/llmd-vllm-config` in that namespace.
- `RemoteMCPServer/kb-mcp-read` in `ai`, or change architect tool bindings.
- **For working code edits:** an independently secured `RemoteMCPServer`
  exposing repo-scoped Git read/write operations, with discovery-verified names.
  Your existing `kind: MCPServer` GitHub resource is NOT directly usable as
  `RemoteMCPServer`; point a RemoteMCPServer at a genuine HTTP MCP endpoint.
- **For executing tests:** CI/test-runner MCP or a controlled sandbox.

Default role setup is safe but intentionally limited: architect can retrieve
knowledge; developer cannot mutate code until you connect a Git tool server.
Do not claim the factory is end-to-end autonomous until those dependencies exist.

## Install

```bash
# From directory containing this README
helm lint charts/software-factory -f examples/values-showyourdream.yaml
helm upgrade --install factory-showyourdream charts/software-factory \
  -n ai -f examples/values-showyourdream.yaml
helm upgrade --install factory-homelab charts/software-factory \
  -n ai -f examples/values-homelab.yaml

kubectl get agenttemplate,agent -n ai -l app.kubernetes.io/part-of=software-factory
kubectl get harness,modelconfig,remotemcpserver -n ai
```

Before deployment, render and review with `helm template`. To uninstall only a
repo's agents: `helm uninstall factory-showyourdream -n ai` (this does NOT
remove the shared controller, Harness or MCP infrastructure).

## Enable Git-backed skills

1. Copy `plugin/software-factory/` to `plugins/software-factory/` inside your
   `teaglebuilt/agent-plugins` repository or another Git repository.
2. Commit and capture the **full 40-character SHA**.
3. Set `plugin.enabled=true`, `plugin.url`, `plugin.commit`, `plugin.path`.
4. Reinstall/upgrade. Source path is under `source.path`, outside `source.git`.

The bundled plugin has six distinct skills: architecture-design,
implement-change, review-change, test-change, security-assessment, release-plan.
Each role only loads its own skill. For the default role prompts, the plugin is
optional and is **not** needed to render or start the chart.

## Role / harness choices

- `kagent` is the default for all roles; works with local `llmd-vllm-config`.
  This is intentionally a model-agnostic chart, not a second inference server.
- Current `Qwen/Qwen2.5-3B-Instruct` may have poor multi-step reliability.
  Use a stronger local model when feasible, and keep tests/PR gates external.
- You can select a different Harness and ModelConfig **per role**, but validate
  compatibility. Claude harness does not honor partial MCP tool allowlists.

## A2A or not?

A2A is always present for Agents at your kagent controller. Agents are invoked
through `/agents/{namespace}/{name}`. Do not install a separate A2A deployment.
For external orchestrators or coding clients, kagent also offers MCP access to
agent sessions. Use an external durable coordinator for an actual workflow.

`router.enabled=true` creates an optional conversational dispatcher using
`subAgent` bindings. It **hands over** the conversation (one Actor) and is NOT
an architect/developer/tester/reviewer pipeline. See `docs/orchestration.md`.

## GitOps / ArgoCD

The optional `examples/argocd-applicationset.yaml` defines an ApplicationSet
for homelab and showyourdream, with one chart release each. Move the chart into
`kubernetes/charts/software-factory` before applying; the path in the example is
proposed, not present in your current Git repository. Per-repo tool bindings
are still required for developer/tester access.

## Repo-specific bindings

`roles.<role>.toolBindings` is an array. Every entry needs:

```yaml
- serverName: repo-github-write
  tools: [create_branch, push_files, create_pull_request]
  requireApproval: true
```

Optional `serverNamespace` references a RemoteMCPServer outside `ai`, but the
server must explicitly allow access from `ai`, and the controller must watch
both namespaces. Tool names above are EXAMPLES only; discover the real names
from `status.discoveredTools` before use.

## Testing

Agent smoke-test prompts and pass/fail rules are in `tests/evaluation-prompts.md`.


```bash
bash scripts/validate.sh
helm template factory-showyourdream charts/software-factory -n ai \
  -f examples/values-showyourdream.yaml
kubectl apply --dry-run=server -f /path/to/rendered.yaml
```

This package was authored against kagent 1.x `api.kagent.dev/v1alpha3`. The
chart does not mutate your connected GitHub repo or live Kubernetes cluster.
