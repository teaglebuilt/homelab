# SRE Agent Team

A kagent 1.x agent team for this homelab. One agent you talk to, nine
specialists it delegates to, and one skill per agent carrying the method.

## Shape

`sre-agent` is the only `Agent` resource in the chart, bound to the `kagent`
Harness. Everything else is an `AgentTemplate` with no Agent of its own,
attached to the root through a `subAgent` tool binding.

```
sre-agent  (Agent + AgentTemplate)        skill: sre-lead
├── k8s                 k8s-agent         skill: k8s
├── prometheus          prometheus-agent  skill: prometheus
├── loki                loki-agent        skill: loki
├── tempo               tempo-agent       skill: tempo
├── grafana             grafana-agent     skill: grafana
├── opentelemetry       opentelemetry-agent  skill: opentelemetry
├── kgateway            kgateway-agent    skill: kgateway
├── cilium-debug        cilium-debug-agent    skill: cilium-debug
└── cilium-manager      cilium-manager-agent  skill: cilium-manager
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
  bound agent from holding its own tools, skills or plugins, and every
  specialist here has both a tool allowlist and a skill.

Because the team shares one sandbox, all ten skills mount into one `/skills`
directory. Skill names must therefore be unique across the whole tree, which is
why the two Cilium skills are `cilium-debug` and `cilium-manager` rather than
two things both called `cilium`.

## Why the prompts live in skills

Agent Substrate caps a single environment variable at 32768 characters, and
kagent passes the whole compiled agent configuration — every template's prompt,
description and tool list — in `KAGENT_CONFIG_JSON`. With the method inline in
each prompt this chart produced a 72706-character value and every Agent reported:

```
Compatible=False  ActorTemplateInvalid
environment variable "KAGENT_CONFIG_JSON" is 72706 characters;
Substrate supports at most 32768
```

Two things drove that total. The authored prompts were ~34k, and the
`{{include "builtin/..."}}` directives are **expanded into the config**, not
resolved at runtime — so the two-line preamble cost ~2.4k per template, or ~24k
across ten of them.

Both were fixed:

- Each specialist's method, query syntax and reporting rules moved into a skill.
  Skill content is fetched from the pinned artifact at startup and lives on the
  sandbox filesystem, so it costs nothing against the limit and can be as long
  as it needs to be.
- The builtin preamble is now on the root agent only. Specialists keep their
  specific safety rules inline — the ones that must hold even if the model never
  loads its skill — and the generic guardrails stay where the operator talks.

That leaves ~26k projected, roughly 20% under the cap, with the remainder spent
mostly on the tool allowlists that are the point of the design.

What stays inline is deliberate: the root's routing table, because routing must
work on the first turn, and each specialist's endpoint, datasource UID and
destructive-tool confirmations, because a skill the model declines to load must
not take those with it.

Skill files are **not** Helm-templated. `endpoints`, `datasourceUids` and
`retention` in `values.yaml` still drive the inline prompts, but the same facts
are written literally in the skills — change one and change the other.

## Why the model is `llmd-vllm-config`

Self-hosted vLLM, so invocations are free. The cost is reasoning quality, which
is why the prompts are written tight and directive rather than as the long
essays the upstream 0.9.11 charts shipped. The compaction `tokenThreshold` on
the `kagent` Harness is 22000; long prompts across ten templates would spend
that on boilerplate before the first tool call.

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

The skills ship as one Agent Plugins package — `plugin.json` plus `skills/` at
the root of this directory — pushed as a scratch OCI image.

```sh
task ai:push-plugin PLUGIN=sre-team
```

That prints a digest-pinned reference. Put the digest in `values.yaml`:

```yaml
plugin:
  oci: ghcr.io/nextgensolutions-llc/agent-plugin-sre-team@sha256:<commit_sha>
```

kagent only accepts artifact references that cannot move, so the CRD enforces
`^[^[:space:]@]+@sha256:[0-9a-f]{64}$` on that field. **A tag is rejected, and
so is the `<commit_sha>` placeholder** — the chart will not apply until a real
digest is substituted. Use `--set plugin.oci=...` to avoid committing one.

The package must be public, or the actor cannot pull it: the golden actor has no
registry credentials. Git sources fail for the same reason — it has no egress
(kagent#2604) — which is why this is OCI.

```sh
task ai:deploy-sre-team CLUSTER=mlops \
  PLUGIN_OCI='ghcr.io/nextgensolutions-llc/agent-plugin-sre-team@sha256:...'
```

`PLUGIN_OCI` is optional and overrides `plugin.oci` for that install, so the
digest need not be committed. Omit it once `values.yaml` holds a real one. The
equivalent by hand:

```sh
helm upgrade --install sre-team platform/ai/agents/sre-team/chart -n ai \
  --set plugin.oci='...@sha256:...'
```

Disable a specialist with `--set agents.<name>=false`; the root's binding
disappears with it.

Editing a skill means a new push and a new digest. Agents already running keep
the content they started with.

## Verify

```sh
kubectl get agent sre-agent -n ai \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
```

`Accepted` and `Ready` both True means it serves traffic.

| Condition | Reason | Cause |
| --- | --- | --- |
| `Compatible=False` | `ActorTemplateInvalid` | the config exceeds 32768 — the message gives the actual count |
| `Compatible=False` | `UnsupportedConfiguration` | broken subagent tree, or a non-`kagent` harness |
| `ResolvedRefs=False` | `ReferenceResolutionFailed` | a binding names a template that does not exist |

A skill that fails to fetch shows on the Agent rather than the template, so
check `Ready` and the controller log together:

```sh
kubectl logs -n ai deployment/kagent-controller | grep -i 'skill\|plugin\|oci'
```
