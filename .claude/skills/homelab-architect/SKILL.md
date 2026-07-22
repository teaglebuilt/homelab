---
name: homelab-architect
description: Plan, evaluate, or review infrastructure changes in the teaglebuilt homelab repository.
argument-hint: "<architecture task>"
context: fork
agent: architect
disable-model-invocation: true
---

## Knowledge Routing

Load these files from `.ai/context/docs/` based on the task at hand. Do NOT load everything -- only what is relevant.

| Task Domain | Files to Load |
|-------------|---------------|
| Ingress, routing, TLS | `kgateway/`, `gateway-api/`, `cloudflare/` |
| AI platform (kagent, LLM routing) | `kagent/`, `agentgateway/`, `kgateway/` (AI gateway section) |
| Helm chart design or modification | `helm/`, `kustomize/` |
| Deployment pipeline or GitOps | `helm/` (helmfile section), `kustomize/` |
| Cloudflare tunnels or external access | `cloudflare/` |
| Cross-cutting (new service addition) | Load the service's specific docs + `kgateway/` + `helm/` |

## Skill Routing

Claude code skills relevant to the tools and technologies used in this repository

| Task Domain |    Skill      |
|-------------|---------------|
| HTTPRoute / Gateway resources / KGateway | `kgateway` `agentgateway` |
| kagent / AI Agents / Agent Harness / MCP | `kagent`, `agentgateway` |
| AI gateway routing | `kgateway` (AI gateway section) |
| Cilium, Clustermesh, NetworkPolicies, Kubernetes Networking, EBPF | `cilium` (AI gateway section) |
| Infrastructure Architecture | `infrastructure-architect` |

## Agent Routing

| Task Domain |    Agent               |
|-------------|------------------------|
| Kubernetes  | `kubernetes-architect` |
| Networking  | `network-agent`        |
| Security    | `security-agent`       |
| LLM         | `llm-architect`        |

## Procedures

### 1. Evaluate a Technology Choice

1. Load relevant docs from `.ai/context/docs/`
2. Read the current implementation in `kubernetes/` or `platform/` to understand what exists
3. Identify constraints: what Helmfile stage does this belong to? What namespace? What dependencies?
4. Evaluate the option against existing patterns (Gateway API, ArgoCD, Helmfile stages)
5. Produce a decision with: recommendation, tradeoffs, migration path if replacing something

### 2. Design a New Service Addition

1. Load docs for the service's technology domain
2. Determine: Platform (Docker Compose in `platform/`) or Kubernetes (`kubernetes/apps/`)?
3. If Kubernetes:
   - Which Helmfile stage (00-04)?
   - Does it need HTTPRoute/Gateway resources?
   - Does it need SOPS-encrypted secrets?
   - Does it need a Kustomize overlay for post-install resources?
4. If Platform:
   - Which stack directory in `platform/`?
   - Does it need K8s resources too (like `platform/ai/k8s/`)?
5. Produce: file list, Helmfile release config, Gateway/HTTPRoute if needed, namespace config

### 3. Review Architecture Decision

1. Load relevant domain knowledge
2. Read the current implementation files
3. Check against conventions in `CLAUDE.md`:
   - Helmfile stage ordering respected?
   - SOPS encryption for secrets?
   - Gateway API v1 spec compliance?
   - Node selectors correct for workload type?
4. Identify risks, missing pieces, and improvement opportunities
5. Produce: findings, prioritized recommendations

### 4. Plan an Upgrade or Migration

1. Load the technology's docs (especially upgrade guides if scraped)
2. Read current chart versions in `kubernetes/charts/` or Helmfile releases
3. Identify breaking changes between current and target versions
4. Design rollback procedure
5. Produce: step-by-step upgrade plan with validation checkpoints
