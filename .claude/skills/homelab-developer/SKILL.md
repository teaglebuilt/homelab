# Homelab Developer Skill

> Use this skill when implementing changes: writing Helm charts, Terraform modules, Kustomize overlays, Docker Compose stacks, Helmfile releases, Gateway API resources, or any other infrastructure code in this repo.

## Agent

Use with agent: `developer`

## Before You Begin

1. Always read `CLAUDE.md` at the repo root for current conventions and layout
2. Load the relevant knowledge from `.ai/context/docs/` based on the task (see routing table below)
3. Read existing examples in the repo before writing new code -- follow established patterns

## Knowledge Routing

Load these files from `.ai/context/docs/` based on the task at hand. Do NOT load everything -- only what is relevant.

| Task Domain | Files to Load |
|-------------|---------------|
| Helm chart authoring | `helm/` |
| Kustomize overlays | `kustomize/` |
| HTTPRoute / Gateway resources | `kgateway/`, `gateway-api/` |
| Terraform / Talos provisioning | (read existing `tf_modules/` and `kubernetes/terraform/` as reference) |
| Cloudflare tunnel config | `cloudflare/` |
| kagent / AI platform | `kagent/`, `agentgateway/` |
| AI gateway routing | `kgateway/` (AI gateway section) |

## Procedures

### 1. Write or Modify a Helm Chart

1. Load `helm/` docs from `.ai/context/docs/`
2. Read existing charts in `kubernetes/charts/` for patterns (especially `homelab-gateway/`)
3. Follow conventions:
   - Chart.yaml with proper dependencies and version
   - values.yaml with sensible defaults
   - Templates using `include` for common labels/selectors
4. If the chart wraps a subchart (like homelab-gateway wraps kgateway), use the dependency pattern
5. Test: `helm template` to validate output

### 2. Add a Helmfile Release

1. Read `kubernetes/helmfile.d/` to understand stage structure (00-prepare through 04-monitoring)
2. Determine the correct stage for this release
3. Follow existing release patterns:
   - `needs:` for inter-release dependencies
   - Values files in `kubernetes/apps/<category>/<app>/`
   - Hooks for Kustomize post-install if needed
4. If post-install resources needed, create `kustomization.yaml` in the app directory

### 3. Write Gateway API Resources

1. Load `kgateway/` and `gateway-api/` docs
2. Read existing Gateway/HTTPRoute examples in `kubernetes/apps/networking/`
3. Follow patterns:
   - Gateway resources reference the kgateway GatewayClass
   - HTTPRoute with proper `parentRefs` to the Gateway
   - ReferenceGrant for cross-namespace references
   - TLS via cert-manager Certificate resources
4. Validate against Gateway API v1 spec

### 4. Write Terraform / OpenTofu

1. Read existing modules in `tf_modules/` for patterns (talos_cluster, virtual_machine)
2. Read `kubernetes/terraform/` for cluster-level Terraform usage
3. Follow conventions:
   - Variables with descriptions and type constraints
   - Outputs for values needed by downstream modules
   - Use data sources over hardcoded values
   - State in remote backend with locking
4. For Talos-specific work, reference the talos_cluster module patterns

### 5. Write Kustomize Overlays

1. Load `kustomize/` docs
2. Read existing kustomization.yaml files in `kubernetes/apps/` for patterns
3. These are always invoked via Helmfile hooks, not standalone
4. Use `--enable-exec` and `--enable-helm` flags pattern
5. Keep overlays minimal -- only resources that cannot be in the Helm chart

### 6. Write Docker Compose Stack

1. Read existing stacks in `platform/` for patterns
2. Follow conventions:
   - Stack-specific directory under `platform/<category>/`
   - Environment variables from `.env` files
   - If K8s resources also needed, put them in a `k8s/` subdirectory
3. SOPS-encrypt any secrets before committing
