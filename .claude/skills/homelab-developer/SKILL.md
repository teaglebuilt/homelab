---

name: homelab-developer
description: Implement, debug, validate, or repair infrastructure code in the teaglebuilt homelab repository.
argument-hint: "<implementation task or accepted architecture plan>"
context: fork
agent: developer
disable-model-invocation: true
------------------------------

# Homelab Development Task

Implement this homelab change:

$ARGUMENTS

If no task was supplied, report that `/homelab-developer` requires an implementation request and stop.

## Purpose

Use this workflow to implement changes involving:

* Helm and Helmfile
* Kustomize
* Kubernetes and Gateway API resources
* Terraform or OpenTofu
* Talos machine configuration
* Docker Compose
* Cilium
* kgateway and agentgateway
* kagent and the AI platform
* NVIDIA GPU infrastructure
* Taskfiles, scripts, and repository automation

This workflow implements changes. It does not make broad architectural decisions that materially alter established ownership, topology, deployment strategy, or core platform choices.

When the task requires an unresolved architecture decision, stop and recommend:

```text
/homelab-architect <decision to evaluate>
```

## Operating Rules

1. Read `CLAUDE.md` before modifying anything.
2. Inspect the relevant existing implementation before writing code.
3. Follow established repository patterns unless the task explicitly changes them.
4. Prefer modifying existing files over adding parallel implementations.
5. Determine which system owns the resource before editing:

   * Terraform or OpenTofu
   * Talos machine configuration
   * Helmfile
   * Helm
   * Kustomize
   * ArgoCD
   * Docker Compose
6. Treat every `generated/` directory as read-only output.
7. Never commit plaintext secrets.
8. Use SOPS and the repository’s existing KMS configuration for secret material.
9. Keep chart, provider, module, action, and image versions pinned.
10. Do not use `latest` or another mutable image tag.
11. Do not hardcode values already represented by cluster definitions, Terraform variables, Helm values, or environment variables.
12. Distinguish repository desired state from live cluster state.
13. Begin live debugging with read-only inspection.
14. Do not apply, upgrade, delete, reset, reboot, or otherwise mutate live infrastructure unless the user explicitly requests it.
15. Do not claim success until relevant rendering, validation, tests, and diffs have been checked.

## Task Classification

Before editing, classify the request.

### Ready to Implement

Proceed when the request includes one of the following:

* A specific bug or failure to repair
* An accepted architecture plan
* A clearly defined resource or service to add
* A version upgrade with an identified current and target version
* A concrete configuration change
* A requested refactor that preserves existing architecture

### Requires Architecture Review

Stop and hand off to `homelab-architect` when the request requires choosing:

* A new cluster-wide technology
* A replacement for an existing load-bearing component
* A different GitOps or deployment ownership model
* A new cluster topology
* A storage, networking, identity, or secrets architecture
* A migration with unresolved alternatives
* A design that would substantially increase operational complexity

Minor implementation choices do not require a handoff. Make the smallest choice consistent with existing repository patterns and state the assumption.

## Domain Skill Routing

Load only the skills required for the task.

| Domain                                                                                               | Skill                       |
| ---------------------------------------------------------------------------------------------------- | --------------------------- |
| Talos machine configuration, patches, Image Factory, extensions, upgrades, etcd, or Talos on Proxmox | `talos`                     |
| Cilium, ClusterMesh, Hubble, LB IPAM, L2 announcements, NetworkPolicy, or eBPF networking            | `cilium`                    |
| Gateway API, Gateway, HTTPRoute, ReferenceGrant, traffic policies, or standard API routing           | `kgateway`                  |
| MCP, A2A, LLM-provider routing, agent traffic, or agent connectivity                                 | `agentgateway`              |
| kagent agents, ModelConfig, MCPServer, AgentHarness, Substrate, memory, or HITL                      | `kagent`                    |
| NVIDIA NIM deployment and model serving                                                              | `nvidia-nim`                |
| Observability pipelines, OpenTelemetry, Prometheus, Loki, Tempo, dashboards, or alerts               | `observability-engineering` |

Do not load every skill.

Do not load a complete `.ai/context/docs/` directory and a domain skill for the same subject by default.

Use `.ai/context/docs/` when:

* No suitable domain skill exists.
* The domain skill explicitly routes to those documents.
* Repository-specific scraped material contains required details not available through the skill.

## Specialist Agent Routing

Delegate only when the specialist agent exists and the task falls within its documented ownership.

| Domain                                                                              | Agent                  |
| ----------------------------------------------------------------------------------- | ---------------------- |
| UniFi controller, VLANs, UDM firewall, switch ports, or physical network fabric     | `network-agent`        |
| Security findings, RBAC review, secrets posture, exposure, or supply-chain analysis | `security-agent`       |
| Advanced Terraform module, provider, state, or migration work                       | `terraform-specialist` |

Do not delegate Kubernetes implementation to an undefined `kubernetes-developer`.

Do not delegate Terraform work to an undefined `terraform-agent`.

The main `developer` agent owns ordinary Kubernetes, Helmfile, Kustomize, Talos, Cilium, Gateway API, Docker Compose, and platform implementation by loading the appropriate domain skills.

## Implementation Workflow

### 1. Establish Scope

Before editing:

1. Identify the requested outcome.
2. Locate all relevant files.
3. Identify existing examples that most closely match the change.
4. Determine the owning deployment system.
5. Identify affected clusters, namespaces, Helmfile stages, modules, or platform stacks.
6. Check the current pinned versions.
7. Identify whether secrets, persistent storage, network exposure, GPU resources, or cross-namespace references are involved.
8. List the files expected to change.

For multi-file changes, state the affected files before implementation.

### 2. Inspect Desired and Live State

Use repository state as the source of intended configuration.

Inspect live state when:

* Debugging a current failure
* Verifying drift
* Checking deployed chart versions
* Confirming existing CRDs or resource schemas
* Checking available node resources
* Confirming Cilium, Gateway API, GPU, storage, or controller status
* Validating whether a proposed fix matches the actual failure

Use read-only operations first.

Do not silently modify the cluster to make repository code appear correct.

### 3. Implement the Smallest Coherent Change

The change must:

* Match existing naming and directory conventions
* Preserve current deployment ownership
* Avoid duplicate resources
* Preserve dependency ordering
* Include the full resource lifecycle
* Include configuration, secrets references, storage, networking, and observability when required
* Avoid unrelated cleanup unless it is necessary for the requested change

Do not introduce a new abstraction for one use case when an existing pattern is adequate.

### 4. Validate

Run the narrowest applicable validations first, followed by broader repository validation when available.

Inspect command output rather than assuming success from an exit code alone.

### 5. Review the Diff

Before completion:

1. Inspect every changed file.
2. Confirm there are no accidental generated-file edits.
3. Confirm no secret values or credentials were exposed.
4. Confirm no unrelated resources changed.
5. Confirm versions are pinned.
6. Confirm deployment ownership remains clear.
7. Confirm validation covers the actual rendered output.

### 6. Report Results

Separate:

* Repository changes completed
* Validation completed
* Live verification completed
* Live changes intentionally not applied
* Remaining risks or follow-up work

## Implementation Procedures

### Helm Chart Changes

1. Inspect existing charts under `kubernetes/charts/`.
2. Inspect the release that consumes the chart.
3. Load Helm documentation only when existing patterns do not answer the question.
4. Preserve:

   * Pinned chart and dependency versions
   * Existing values organization
   * Existing helper and label conventions
   * Clear ownership between the parent chart and dependencies
5. Put environment-specific configuration in values rather than templates.
6. Avoid adding raw manifests to a chart when an existing dependency value supports the requirement.
7. Update `Chart.lock` when dependencies change.
8. Validate with applicable commands:

```bash
helm dependency update <chart-directory>
helm lint <chart-directory>
helm template <release-name> <chart-directory> \
  --namespace <namespace> \
  --values <values-file>
```

Inspect the rendered resources for namespace, labels, selectors, references, and API versions.

### Helmfile Release Changes

1. Read the relevant files under `kubernetes/helmfile.d/`.
2. Determine the correct stage from the actual current stage structure.
3. Inspect nearby releases for repository conventions.
4. Use:

   * `needs:` for release dependencies
   * App-local values files
   * Explicit chart versions
   * `createNamespace: true` when Helmfile owns namespace creation
5. Use hooks only when the resource cannot be represented cleanly through the chart or a separately owned release.
6. Do not hide ordinary deployment resources inside shell hooks.
7. Confirm CRD ownership and installation order.
8. Render or diff before applying:

```bash
helmfile --file <helmfile> lint
helmfile --file <helmfile> template
helmfile --file <helmfile> diff
```

Do not run `helmfile apply` unless the user explicitly requests a live deployment.

### Gateway API and kgateway Changes

1. Load the `kgateway` skill.
2. Check the installed or pinned Gateway API and kgateway versions.
3. Inspect existing Gateway, HTTPRoute, policy, certificate, and ReferenceGrant resources.
4. Confirm:

   * Correct API version
   * Correct `parentRefs`
   * Correct listener `sectionName`
   * Correct namespace ownership
   * Correct backend Service and port
   * Required cross-namespace permissions
   * TLS and certificate ownership
   * ExternalDNS behavior
5. Do not route MCP, A2A, or LLM-provider traffic as ordinary kgateway work when it belongs to agentgateway.
6. Render and schema-validate the final resources.

Do not create a ReferenceGrant automatically merely because a route and Gateway are in different namespaces. Verify which cross-namespace reference is actually being made and place the grant in the namespace of the referenced object.

### Agentgateway Changes

1. Load the `agentgateway` skill.
2. Inspect the current agentgateway deployment and routes.
3. Determine whether the task concerns:

   * MCP server aggregation
   * A2A
   * LLM provider routing
   * Authentication or authorization
   * Traffic policy
   * Observability
4. Verify exact CRDs, fields, and Helm values against the pinned version.
5. Preserve separation between:

   * Standard application ingress through kgateway
   * Agent and LLM traffic through agentgateway
6. Validate the rendered resources and, when debugging, inspect actual route and backend status.

Do not duplicate the complete Agentgateway knowledge guide inside this workflow.

### kagent Changes

1. Load the `kagent` skill.
2. Inspect existing Agent, ModelConfig, MCPServer, RemoteMCPServer, skill, and provider resources.
3. Verify fields against the installed CRDs.
4. Confirm:

   * Namespace
   * ModelConfig reference
   * Tool API groups
   * Tool filtering
   * Approval requirements
   * Memory and context settings
   * Resource requests and limits
5. Keep system prompts focused on agent behavior.
6. Put reusable procedural knowledge in skills rather than growing agent system prompts indefinitely.
7. Validate CRD acceptance and deployment readiness separately.

### Talos and Talos Terraform Changes

1. Load the `talos` skill.
2. Determine the affected cluster and current Talos version.
3. Inspect:

   * `kubernetes/terraform/<cluster>/`
   * `kubernetes/clusters/<cluster>/`
   * `tf_modules/talos_cluster/`
   * Existing machine configuration patches
   * Image Factory and extension configuration
4. Make persistent changes through Terraform inputs, templates, or patches.
5. Never edit generated Talos configuration as the permanent fix.
6. Preserve required system extensions.
7. Validate rendered machine configurations with the matching `talosctl` client.
8. Review Terraform plans for node, disk, identity, or PCI-device replacement.

Do not apply Talos configuration, reboot, reset, bootstrap, upgrade, or recover etcd without explicit user intent.

### Terraform and OpenTofu Changes

1. Inspect the affected root module and reusable modules.
2. Use the `terraform-specialist` agent for advanced state, provider, migration, or module-interface work.
3. Follow existing repository conventions for:

   * Variable naming
   * Type constraints
   * Descriptions
   * Validation
   * Outputs
   * Provider constraints
4. Keep cluster-specific values outside reusable modules.
5. Avoid unnecessary data sources when values are already explicit module inputs.
6. Avoid hardcoding values that belong in cluster definitions or environment configuration.
7. Run:

```bash
tofu fmt -check -recursive
tofu -chdir=<module-or-root> init -backend=false
tofu -chdir=<module-or-root> validate
```

When credentials and backend access are available, also run:

```bash
tofu -chdir=<root-module> plan
```

Inspect the plan for replacements and destructive operations.

Do not apply Terraform unless the user explicitly requests a live infrastructure change.

### Kustomize Changes

1. Inspect current `kustomization.yaml` files in the same subsystem.
2. Determine who invokes the Kustomization:

   * Helmfile hook
   * ArgoCD
   * Parent Kustomization
   * Taskfile
3. Do not assume every Kustomization must run through a Helmfile hook.
4. Keep overlays narrow and composable.
5. Use generators only when they match the repository’s existing SOPS or configuration pattern.
6. Avoid generated name suffixes when stable names are required by references, but do not disable hashes globally without a reason.
7. Render with the same flags used by the owning workflow:

```bash
kustomize build <directory>
```

Add `--enable-helm`, `--enable-exec`, or alpha-plugin flags only when that Kustomization requires them.

### Cilium Changes

1. Load the `cilium` skill.
2. Inspect the cluster’s Talos, Kubernetes, Cilium, pod CIDR, service CIDR, cluster ID, and load-balancer pool configuration.
3. Verify compatibility with the pinned Cilium release.
4. Preserve:

   * kube-proxy replacement decisions
   * Talos API-server connectivity
   * ClusterMesh addressing
   * LB IPAM ownership
   * L2 announcement behavior
   * Gateway API integration
5. Validate chart values and rendered resources.
6. When debugging, inspect endpoints, identities, policy state, service maps, routes, and Hubble flows before changing configuration.

Do not introduce another CNI or ingress implementation as a workaround.

### NVIDIA and GPU Changes

1. Determine which layer owns the failure or change:

   * Proxmox PCI passthrough
   * Talos system extensions
   * Container runtime
   * RuntimeClass
   * NVIDIA device plugin
   * DCGM exporter
   * Kubernetes scheduling
   * NIM, Ollama, ComfyUI, or another workload
2. Load `talos` for host and extension work.
3. Load `nvidia-nim` for NIM-specific serving work.
4. Inspect the full GPU path rather than changing only the workload manifest.
5. Confirm GPU workloads request `nvidia.com/gpu`.
6. Confirm time-slicing or sharing behavior from actual device-plugin configuration.
7. Validate node labels, allocatable resources, device-plugin health, and workload scheduling.

### Docker Compose Changes

1. Inspect nearby platform stacks and the root Taskfile behavior.
2. Use the existing `platform/<category>/<stack>/` organization.
3. Pin image versions.
4. Put configuration in environment files or explicit Compose configuration.
5. Keep secrets out of plaintext Compose files.
6. Define:

   * Networks
   * Volumes
   * Health checks
   * Restart behavior
   * Resource constraints when supported
7. Validate with:

```bash
docker compose -f <compose-file> config
```

Do not start, stop, recreate, or delete live services unless explicitly requested.

### Secrets

1. Never place secret values directly in:

   * Kubernetes manifests
   * Helm values
   * Compose files
   * Taskfiles
   * Agent definitions
   * Skill files
2. Use the repository’s existing SOPS and AWS KMS workflow.
3. Confirm the file path matches `.sops.yaml`.
4. Check encrypted files contain a valid `sops:` section.
5. Avoid printing decrypted values in command output or the final response.
6. Run secret scanning when available.

## Validation Matrix

Choose checks based on changed files.

| Changed area        | Minimum validation                                                                     |
| ------------------- | -------------------------------------------------------------------------------------- |
| Helm chart          | `helm dependency update`, `helm lint`, `helm template`                                 |
| Helmfile            | Helmfile lint, template, or diff                                                       |
| Kustomize           | `kustomize build` using owning workflow flags                                          |
| Terraform/OpenTofu  | `tofu fmt -check`, init without backend when appropriate, validate, plan when possible |
| Talos configuration | Render and `talosctl validate --strict`                                                |
| Kubernetes YAML     | YAML parse and Kubernetes schema validation                                            |
| Gateway API         | Render, schema check, and reference/status review                                      |
| Docker Compose      | `docker compose config`                                                                |
| Shell scripts       | `bash -n` and `shellcheck`                                                             |
| Python              | Existing formatter, linter, type checker, and tests                                    |
| Go                  | `gofmt`, `go vet`, and relevant tests                                                  |
| Secrets             | SOPS header/path check and secret scan                                                 |
| Images              | Confirm immutable version or digest                                                    |
| Documentation       | MkDocs build when docs are affected                                                    |

Use the repository’s `task validate` command when it exists and includes the relevant subsystem.

If it does not exist, run the subsystem-specific checks directly and recommend adding a unified validation task separately.

## Completion Checklist

Before finishing:

* [ ] `CLAUDE.md` was read.
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
* [ ] Rendered output was inspected.
* [ ] Relevant validation passed.
* [ ] The final diff contains no unrelated changes.
* [ ] Live changes were not made without explicit authorization.
* [ ] Repository state reflects every approved persistent live change.

## Required Output

Return:

1. **Implemented change**
2. **Files modified**
3. **Important implementation decisions**
4. **Validation performed and results**
5. **Rendered or planned impact**
6. **Live verification performed**
7. **Live actions intentionally not applied**
8. **Remaining risks or follow-up work**

Reference exact repository paths.

Show concrete code or diffs where useful. Do not replace the implementation summary with generic advice.
