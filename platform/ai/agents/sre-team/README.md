# SRE Agent Team

A kagent 1.x agent team for this homelab. One agent you talk to, nine
specialists it delegates to.

## Shape

`sre-agent` is the only `Agent` resource in the chart, bound to the `kagent`
Harness. Everything else is an `AgentTemplate` with no Agent of its own,
attached to the root through a `subAgent` tool binding.

```
sre-agent  (Agent + AgentTemplate)
├── k8s                 k8s-agent
├── prometheus          prometheus-agent
├── loki                loki-agent
├── tempo               tempo-agent
├── grafana             grafana-agent
├── opentelemetry       opentelemetry-agent
├── kgateway            kgateway-agent
├── cilium-debug        cilium-debug-agent
└── cilium-manager      cilium-manager-agent
```

kagent compiles a bound template into the parent's own runtime and executes it
inside the parent's Actor, so the whole team shares one sandbox and one
Harness. Three consequences shaped this chart:

- **Subagents cannot delegate.** The tree is one level deep by API rule, so all
  routing and all cross-signal correlation lives in the root's prompt. The
  ported 0.9.11 prompts told agents to "defer to the cilium-policy-agent"; that
  language was removed because a subagent has no way to do it.
- **Subagents need no Agent resource.** Adding one would give them a second,
  independent runtime and an A2A endpoint nobody calls.
- **The Harness must be `kagent`.** The Claude and Codex harnesses forbid a
  bound agent from holding its own tools, and every specialist here has a tool
  allowlist.

## Why the model is `llmd-vllm-config`

Self-hosted vLLM, so invocations are free. The cost is reasoning quality, which
is why the prompts are written tight and directive rather than as the long
essays the upstream 0.9.11 charts shipped — and why each specialist carries the
concrete query syntax and endpoints it needs instead of being told to work them
out. The compaction `tokenThreshold` on the `kagent` Harness is 22000; long
prompts across nine templates would spend that on boilerplate.

Switch the whole team with `--set modelConfig=claude-opus-4-5`.

## Tool reachability

The team runs in `mlops`. The observability backends run in `application` and
are reached over Cilium ClusterMesh global Services.

| Backend | Path | State |
| --- | --- | --- |
| Prometheus | `prometheus-mesh.observability:9090` | works |
| Grafana | `grafana-mesh.observability` | added by this change |
| Tempo | Grafana datasource proxy, uid `tempo` | works once Grafana is reachable |
| Loki | Grafana Loki tools, uid `loki` | blocked on Loki itself |

`prometheus_query_tool` and friends default to `http://localhost:9090`, which is
wrong inside the cluster. The prometheus agent's prompt names the mesh endpoint
and requires it on every call.

There are no Tempo tools in mcp-grafana 1.4.1. The tempo agent therefore uses
`grafana_api_request` against `/api/datasources/proxy/uid/tempo/...`, which
passes TraceQL straight through to Tempo's HTTP API. Verified returning 200.

## Install

```sh
helm upgrade --install sre-team platform/ai/agents/sre-team/chart -n ai
```

Or `task ai:deploy-sre-team CLUSTER=mlops`.

Disable a specialist with `--set agents.<name>=false`; the root's binding
disappears with it.

## Verify

```sh
kubectl get agent sre-agent -n ai \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
```

`Accepted` and `Ready` both True means it serves traffic. A broken subagent tree
shows as `Compatible=False` with reason `UnsupportedConfiguration`; a binding
naming a template that does not exist shows as
`ResolvedRefs=ReferenceResolutionFailed`.
