# Homelab Architect Skill

> Use this skill when designing infrastructure, evaluating technology choices, planning deployments, reviewing architecture, or making decisions about how services fit together in the homelab.

## Agent

Use with agent: `architect`

## Context: fork

Heavy knowledge loading -- always fork to avoid polluting the main conversation.

## Before You Begin

1. Always read `CLAUDE.md` at the repo root for current conventions and layout
2. Load the relevant knowledge from `.ai/context/docs/` based on the task (see routing table below)

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
