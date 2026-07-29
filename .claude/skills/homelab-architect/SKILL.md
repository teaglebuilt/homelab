---
name: homelab-architect
description: Plan, evaluate, review, or design infrastructure changes in the teaglebuilt homelab repository.
argument-hint: "<architecture task>"
context: fork
agent: architect
disable-model-invocation: true
---

# Homelab Architecture Task

Analyze this architecture request:

$ARGUMENTS

If no task was supplied, report that `/homelab-architect` requires an architecture request and stop.

## Operating Rules

1. Read `CLAUDE.md` for current repository layout, conventions, and load-bearing architectural decisions.
2. Inspect the relevant implementation before recommending changes.
3. Determine which cluster, platform, service, and environment are affected.
4. Use repository state as the source of intended configuration.
5. Inspect live state with read-only tools when the decision depends on what is currently deployed.
6. Clearly distinguish repository state, live state, documentation, and inference.
7. Check the pinned or installed version before giving version-specific advice.
8. Prefer existing tools and patterns over introducing another system.
9. Reject enterprise complexity that does not provide proportional value for this single-operator homelab.
10. Do not implement or apply changes. Produce a plan for `homelab-developer`.

## Domain Skill Routing

Load only the skills required for the task.

| Domain                                                                                            | Skill                                                                     |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Talos machine configuration, Image Factory, system extensions, upgrades, etcd or Talos-on-Proxmox | `talos`                                                                   |
| Cilium, ClusterMesh, Hubble, NetworkPolicy, LB IPAM, L2 announcements or eBPF networking          | `cilium`                                                                  |
| Gateway API, Gateway, HTTPRoute, TLS policies or standard API traffic                             | `kgateway`                                                                |
| MCP, A2A, LLM-provider routing, agent connectivity or agent traffic policy                        | `agentgateway`                                                            |
| kagent agents, AgentHarness, Substrate, agent memory, HITL or kagent CRDs                         | `kagent`                                                                  |
| General architecture methods, ADRs or capacity planning                                           | `infrastructure-architect`, only when its broader methods materially help |
| NVIDIA NIM deployment and model serving                                                           | `nvidia-nim`                                                              |
| cloudflare tunnels, cloudflare_tunnel.tf, cloudflare/                                                                               | `cloudflare-one`                                                          |

Use `.ai/context/docs/` only when:

* No appropriate skill exists.
* Repository-specific scraped documentation is needed.
* The selected domain skill explicitly routes to those documents.

Do not load both an entire documentation directory and a domain skill by default.

## Specialist Agent Delegation

Delegate with the Agent tool only when the specialist agent exists and the task falls inside its documented ownership.

| Domain                                                                          | Agent                  |
| ------------------------------------------------------------------------------- | ---------------------- |
| UniFi controller, VLANs, switch ports, UDM firewall or physical network fabric  | `network-agent`        |
| Security posture, RBAC, NetworkPolicy review, secrets, exposure or supply chain | `security-agent`       |
| Advanced Terraform module, state or provider architecture                       | `terraform-specialist` |

Do not delegate Kubernetes, Talos, MLOps or cloud work to an agent that is not defined in `.claude/agents/`. Handle those domains through the main architect agent and relevant skills.

## Analysis Workflow

### 1. Establish Current State

* Locate the relevant repository files.
* Identify the owning system: Terraform, Talos, Helmfile, ArgoCD, Kustomize, Helm, Docker Compose or another platform component.
* Identify current versions, namespaces, clusters and dependencies.
* Inspect live state when it could differ materially from Git.

### 2. Identify Constraints

Check:

* Existing architectural decisions in `CLAUDE.md`.
* Helmfile stage and `needs:` ordering.
* Terraform module boundaries.
* ArgoCD versus Helmfile ownership.
* Namespace and cross-namespace references.
* Gateway API and ReferenceGrant requirements.
* SOPS encryption requirements.
* Node capacity, scheduling and GPU requirements.
* Upgrade compatibility and rollback limitations.

### 3. Evaluate the Change

For a technology choice:

* Compare it with existing capabilities.
* State whether an existing tool already covers the need.
* Recommend one option.
* Explain important tradeoffs.
* Include a migration path when replacing something.

For a new service:

* Identify its owning directory and deployment system.
* Determine namespace, dependencies, storage, secrets, networking, observability and backup requirements.
* Identify any HTTPRoute, Gateway, certificate or DNS resources.
* Define the smallest viable implementation.

For an upgrade:

* Identify current and target versions.
* Review breaking changes and compatibility.
* Separate coupled upgrades unless coordination is required.
* Define rollout checkpoints, downtime and rollback.

For an architecture review:

* Compare intended design, repository implementation and live state.
* Identify drift, gaps, duplication and operational risks.
* Prioritize recommendations.

## Required Output

Return:

1. **Recommendation**
2. **Current state and evidence**
3. **Constraints and assumptions**
4. **Affected files**
5. **Resource ownership and Helmfile stage**
6. **Dependencies and ordering**
7. **Risks and tradeoffs**
8. **Validation plan**
9. **Rollback plan**
10. **Developer handoff**

Reference specific repository paths. Do not provide generic advice where repository evidence is available.
