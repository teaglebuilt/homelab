---
name: homelab-developer
description: Implement, debug, validate, or repair infrastructure code in the teaglebuilt homelab repository.
argument-hint: "<implementation task or path to plan file>"
context: fork
agent: developer
background: false
disable-model-invocation: true
---

# Homelab Development Task

Implement this homelab change:

$ARGUMENTS

If no task was supplied, report that `/homelab-developer` requires an implementation
request and stop. If the argument is a path under `.ai/plans/`, read that plan first
and implement it.

## Scope

This workflow implements changes. It does not make broad architectural decisions that
materially alter established ownership, topology, deployment strategy, or core platform
choices. When the task requires an unresolved architecture decision, stop and recommend:

```text
/homelab-architect <decision to evaluate>
```

## Operating Rules

1. Inspect the relevant existing implementation before writing code.
2. Follow established repository patterns unless the task explicitly changes them.
3. Prefer modifying existing files over adding parallel implementations.
4. Determine which system owns the resource before editing: Terraform/OpenTofu, Talos
   machine configuration, Helmfile, Helm, Kustomize, ArgoCD, or Docker Compose.
5. Treat every `generated/` directory as read-only output.
6. Never commit plaintext secrets. Use SOPS and the repository's existing KMS configuration.
7. Keep chart, provider, module, action, and image versions pinned. No `latest` or other
   mutable tags.
8. Do not hardcode values already represented by cluster definitions, Terraform variables,
   Helm values, or environment variables.
9. Distinguish repository desired state from live cluster state.
10. Begin live debugging with read-only inspection.
11. Do not apply, upgrade, delete, reset, reboot, or otherwise mutate live infrastructure
    unless the user explicitly requests it.
12. Do not claim success until relevant rendering, validation, tests, and diffs have been
    checked.
## Task Classification

Before editing, classify the request.

### Ready to Implement

* A specific bug or failure to repair
* An accepted architecture plan
* A clearly defined resource or service to add
* A version upgrade with an identified current and target version
* A concrete configuration change
* A refactor that preserves existing architecture
### Requires Architecture Review

Hand off to `homelab-architect` when the request requires choosing:

* A new cluster-wide technology
* A replacement for an existing load-bearing component
* A different GitOps or deployment ownership model
* A new cluster topology
* A storage, networking, identity, or secrets architecture
* A migration with unresolved alternatives
* A design that would substantially increase operational complexity
Minor implementation choices do not require a handoff. Make the smallest choice consistent
with existing repository patterns and state the assumption.

## Domain Skill Routing

Load only the skills required for the task. Each domain skill owns its own implementation
procedure — do not reimplement that guidance here.

| Domain                                                                                     | Skill                       |
| -----------------------------------------------------------------------------------------  | --------------------------- |
| Talos machine configuration, patches, Image Factory, extensions, upgrades, etcd, Proxmox   | `talos`                     |
| Cilium, ClusterMesh, Hubble, LB IPAM, L2 announcements, NetworkPolicy, eBPF networking     | `cilium`                    |
| Gateway API, Gateway, HTTPRoute, ReferenceGrant, traffic policies, standard API routing    | `kgateway`                  |
| MCP, A2A, LLM-provider routing, agent traffic, agent connectivity                          | `agentgateway`              |
| kagent agents, ModelConfig, MCPServer, AgentHarness, Substrate, memory, HITL               | `kagent`                    |
| NVIDIA NIM deployment and model serving                                                    | `nvidia-nim`                |
| Observability pipelines, OpenTelemetry, Prometheus, Loki, Tempo, dashboards, alerts        | `observability-engineering` |
| n8n workflow authoring and maintenance                                                     | `n8n-workflow`              |

For Helm, Helmfile, Kustomize, Terraform, Docker Compose, and secrets work — which have no
dedicated domain skill — read
[references/repo-native-procedures.md](references/repo-native-procedures.md).

Do not load every skill. Do not load a complete `.ai/context/docs/` directory and a domain
skill for the same subject. Use `.ai/context/docs/` only when no suitable domain skill
exists, the domain skill explicitly routes there, or repository-specific scraped material
contains details the skill lacks.

## Specialist Agent Routing

Delegate only when the task falls within the agent's documented ownership.

| Domain                                                                              | Agent                  |
| ----------------------------------------------------------------------------------- | ---------------------- |
| UniFi controller, VLANs, UDM firewall, switch ports, physical network fabric        | `network-agent`        |
| Security findings, RBAC review, secrets posture, exposure, supply-chain analysis     | `security-agent`       |
| Advanced Terraform module, provider, state, or migration work                        | `terraform-specialist` |
| n8n workflow creation and updates against the live instance                          | `n8n-workflow-builder` |

The `developer` agent owns ordinary Kubernetes, Helmfile, Kustomize, Talos, Cilium,
Gateway API, Docker Compose, and platform implementation by loading the appropriate domain
skills. Do not invent an agent name that is not in `.claude/agents/`.

## Implementation Workflow

### 1. Establish Scope

1. Identify the requested outcome.
2. Locate all relevant files and the existing examples closest to the change.
3. Determine the owning deployment system.
4. Identify affected clusters, namespaces, Helmfile stages, modules, or platform stacks.
5. Check current pinned versions.
6. Identify whether secrets, persistent storage, network exposure, GPU resources, or
   cross-namespace references are involved.
7. For multi-file changes, state the affected files before implementation.
### 2. Inspect Desired and Live State

Repository state is the source of intended configuration. Inspect live state when
debugging a failure, verifying drift, checking deployed chart versions, confirming CRDs or
schemas, checking node resources, or validating that a proposed fix matches the actual
failure.

Use read-only operations first. Do not silently modify the cluster to make repository code
appear correct.

### 3. Implement the Smallest Coherent Change

The change must match existing naming and directory conventions, preserve deployment
ownership and dependency ordering, avoid duplicate resources, and cover the full resource
lifecycle — configuration, secrets references, storage, networking, and observability where
required. Avoid unrelated cleanup. Do not introduce a new abstraction for one use case when
an existing pattern is adequate.

### 4. Validate

Run the narrowest applicable validations first, then broader repository validation. Inspect
command output rather than assuming success from an exit code.

### 5. Review the Diff

Inspect every changed file. Confirm no generated-file edits, no exposed secrets, no
unrelated resource changes, pinned versions, clear deployment ownership, and that
validation covered the actual rendered output.

### 6. Report Results

Separate repository changes, validation performed, live verification performed, live
changes intentionally not applied, and remaining risks.

## Validation Matrix

Choose checks based on changed files.

| Changed area        | Minimum validation                                                                     |
| ------------------- | -------------------------------------------------------------------------------------- |
| Helm chart          | `helm dependency update`, `helm lint`, `helm template`                                 |
| Helmfile            | Helmfile lint, template, or diff                                                        |
| Kustomize           | `kustomize build` using owning workflow flags                                            |
| Terraform/OpenTofu  | `tofu fmt -check`, init without backend when appropriate, validate, plan when possible  |
| Talos configuration | Render and `talosctl validate --strict`                                                 |
| Kubernetes YAML     | YAML parse and Kubernetes schema validation                                             |
| Gateway API         | Render, schema check, and reference/status review                                       |
| Docker Compose      | `docker compose config`                                                                 |
| Shell scripts       | `bash -n` and `shellcheck`                                                              |
| Python              | Existing formatter, linter, type checker, and tests                                     |
| Go                  | `gofmt`, `go vet`, and relevant tests                                                   |
| Secrets             | SOPS header/path check and secret scan                                                  |
| Images              | Confirm immutable version or digest                                                     |
| Documentation       | MkDocs build when docs are affected                                                     |

Use `task validate` when it exists and covers the relevant subsystem. If it does not,
run the subsystem checks directly and recommend adding a unified validation task
separately.

## Completion Checklist

* [ ] Existing implementation patterns were inspected.
* [ ] The owning deployment system is clear.
* [ ] Only relevant domain skills were loaded.
* [ ] No undefined specialist agents were used.
* [ ] No generated files were edited.
* [ ] No plaintext secrets were introduced.
* [ ] Versions and image tags are pinned.
* [ ] Namespace and cross-namespace references are correct.
* [ ] Helmfile stage and dependency ordering are correct.
* [ ] Terraform replacement risk was reviewed.
* [ ] Rendered output was inspected and relevant validation passed.
* [ ] The final diff contains no unrelated changes.
* [ ] Live changes were not made without explicit authorization.
* [ ] Repository state reflects every approved persistent live change.
## Required Output

1. **Implemented change**
2. **Files modified**
3. **Important implementation decisions**
4. **Validation performed and results**
5. **Rendered or planned impact**
6. **Live verification performed**
7. **Live actions intentionally not applied**
8. **Remaining risks or follow-up work**
Reference exact repository paths. Show concrete code or diffs where useful. Do not replace
the implementation summary with generic advice.
