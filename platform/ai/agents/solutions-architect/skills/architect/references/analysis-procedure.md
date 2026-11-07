# Architecture Analysis Procedures (kagent)

This agent runs on **kagent**, not a laptop checkout. Prefer MCP tools over
shell `find`/`grep` against a local tree. Use `kb_search` / `kb_get_document`
for the knowledge base, `github-mcp` for repository structure and file contents,
and `kagent-tools` for live cluster state.

---

## Phase 1: Map the Landscape

### 1.1 Project structure (GitHub MCP)

When analyzing a GitHub repo (homelab or external):

1. `search_code` with a scoped query for entry points and layout markers
   (e.g. `path:kubernetes/helmfile.d` `filename:Chart.yaml` `path:platform/`).
2. `get_file_contents` on root manifests: `README.md`, `Taskfile.yml`,
   `CLAUDE.md` / `AGENTS.md`, top-level `kustomization.yaml`, `go.mod` /
   `package.json` / `pyproject.toml` as applicable.
3. `list_commits` / `list_branches` only when history or branch topology matters.

Build a short map: deploy path (Helmfile stages vs Compose vs Argo), primary
languages, and where ADRs / docs live.

For **teaglebuilt/homelab**, expect:

- `kubernetes/helmfile.d/` — stages `00`–`04`
- `platform/*` — app stacks
- `tf_modules/`, `kubernetes/terraform/` — IaC
- `.ai/decisions/` — estate ADRs

### 1.2 Dependency / stack signals

Use `search_code` / `get_file_contents` rather than local package managers:

| Stack signal | Look for |
|---|---|
| JS/TS | `package.json`, workspaces, import paths |
| Python | `pyproject.toml`, `requirements.txt`, `uv.lock` |
| Go | `go.mod` |
| K8s | Helmfile releases, chart `Chart.yaml`, Gateway `HTTPRoute` |
| Data | CNPG Cluster CRs, Redis, Qdrant values |

### 1.3 Data layer

`search_code` for ORM / DB clients and migration dirs; confirm live databases
with `k8s_get_resources` in namespace `data` (or the project's declared ns) when
the question is about *this* cluster.

### 1.4 API / edge surface

`search_code` for `HTTPRoute`, `Gateway`, `ReferenceGrant`, Ingress (legacy),
OpenAPI/swagger paths. For live exposure: `k8s_get_resources` on
`HTTPRoute` / `Gateway` in `kube-system` and app namespaces.

---

## Phase 2: Identify Patterns in Use

| Pattern | Indicators (via file search) |
|---------|-----------|
| **Layered** | `controllers/`, `services/`, `repositories/`, `models/` |
| **Hexagonal** | `ports/`, `adapters/`, `domain/`, `infrastructure/` |
| **Clean Architecture** | `usecases/`, `entities/`, `interfaces/` |
| **Vertical Slice** | Feature folders with handler + service + repo |
| **DDD** | aggregates, domain events, ubiquitous language |
| **CQRS** | Separate `commands/` and `queries/` |
| **Event Sourcing** | Event store, projections |
| **Microservices** | Many Dockerfiles / charts / deploy units |
| **Modular Monolith** | `modules/` with public APIs |
| **GitOps platform** | Helmfile stages, Argo ApplicationSets, SOPS |

Cross-check README claims against what `search_code` actually finds.

---

## Phase 3: Assess Coupling and Cohesion

From GitHub evidence (and knowledge-tree notes on the stack):

- **Shared mutable state** — many writers to one DB / queue
- **Temporal coupling** — documented startup order / `needs:` chains
- **Knowledge coupling** — modules importing internals across boundaries
- **Fan-out / fan-in** — shared libraries or CRDs everything depends on
- **Shotgun surgery** — one feature touches many Helmfile stages / namespaces

For live coupling on this estate, also inspect Helmfile `needs:`, Gateway
cross-namespace `ReferenceGrant`s, and Cilium ClusterMesh Services.

---

## Phase 4: Ground in the knowledge tree

Before writing recommendations:

1. `kb_search` on each concern (2–5 queries). Prefer `source_type="tree"`.
2. `kb_get_document` on the strongest paths.
3. Cite `tree/<path>` in the assessment.
4. If empty: state **ungrounded in knowledge tree** and continue with GitHub /
   cluster evidence only.

---

## Phase 5: Produce Assessment

```markdown
# Architecture Assessment: [Project Name]

## Grounding
- Knowledge: [tree/… paths, or "none — kb_search empty"]
- Repo tools: [files / search_code queries used]
- Live cluster: [resources checked, or "n/a"]

## Current State

### Dominant Pattern
[Identified pattern(s)] applied [consistently / inconsistently] across [scope].

### Structure Overview
[High-level description]

### Strengths
- …

### Concerns
- …

## Recommendations (Prioritized)

### P0 — Address Now
### P1 — Address Soon
### P2 — Improve Over Time

## Suggested Fitness Functions
[Automated checks to prevent regression]

## Helmfile / GitOps impact (homelab)
[stage or overlay, or "none"]
```
