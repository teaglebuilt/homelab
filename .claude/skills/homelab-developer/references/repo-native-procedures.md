# Repo-Native Implementation Procedures

Procedures for the parts of this repository that have no dedicated domain skill: Helm,
Helmfile, Kustomize, Terraform/OpenTofu, Docker Compose, and secrets. Read the section you
need, not the whole file.

For Talos, Cilium, Gateway API, agentgateway, kagent, NVIDIA NIM, and observability, load
the corresponding domain skill instead.

## Contents

- [Helm Chart Changes](#helm-chart-changes)
- [Helmfile Release Changes](#helmfile-release-changes)
- [Kustomize Changes](#kustomize-changes)
- [Terraform and OpenTofu Changes](#terraform-and-opentofu-changes)
- [Docker Compose Changes](#docker-compose-changes)
- [Secrets](#secrets)

---

## Helm Chart Changes

1. Inspect existing charts under `kubernetes/charts/`.
2. Inspect the release that consumes the chart.
3. Load Helm documentation only when existing patterns do not answer the question.
4. Preserve pinned chart and dependency versions, existing values organization, existing
   helper and label conventions, and clear ownership between the parent chart and its
   dependencies.
5. Put environment-specific configuration in values rather than templates.
6. Avoid adding raw manifests to a chart when an existing dependency value supports the
   requirement.
7. Update `Chart.lock` when dependencies change.

```bash
helm dependency update <chart-directory>
helm lint <chart-directory>
helm template <release-name> <chart-directory> \
  --namespace <namespace> \
  --values <values-file>
```

Inspect rendered resources for namespace, labels, selectors, references, and API versions.

Note: `homelab-gateway` is a wrapper chart. It vendors kgateway CRDs and kgateway as
subchart dependencies, then adds Gateway, HTTPRoute, and Certificate templates on top.
Changes to routing behavior usually belong in its values, not new templates.

---

## Helmfile Release Changes

1. Read the relevant files under `kubernetes/helmfile.d/`.
2. Determine the correct stage from the actual current stage structure
   (`00-prepare` → `01-bootstrap` → `02-core` → `03-hardware` → `04-monitoring`).
3. Inspect nearby releases for repository conventions.
4. Use `needs:` for release dependencies, app-local values files, explicit chart versions,
   and `createNamespace: true` when Helmfile owns namespace creation.
5. Use hooks only when the resource cannot be represented cleanly through the chart or a
   separately owned release. Do not hide ordinary deployment resources inside shell hooks.
6. Confirm CRD ownership and installation order.

```bash
helmfile --file <helmfile> lint
helmfile --file <helmfile> template
helmfile --file <helmfile> diff
```

Do not run `helmfile apply` unless the user explicitly requests a live deployment.

---

## Kustomize Changes

1. Inspect current `kustomization.yaml` files in the same subsystem.
2. Determine who invokes the Kustomization: a Helmfile hook, ArgoCD, a parent
   Kustomization, or a Taskfile. Do not assume every Kustomization runs through a Helmfile
   hook.
3. Keep overlays narrow and composable.
4. Use generators only when they match the repository's existing SOPS or configuration
   pattern.
5. Avoid generated name suffixes when stable names are required by references, but do not
   disable hashes globally without a reason.

```bash
kustomize build <directory>
```

Add `--enable-helm`, `--enable-exec`, or alpha-plugin flags only when that Kustomization
requires them. Render with the same flags used by the owning workflow.

---

## Terraform and OpenTofu Changes

1. Inspect the affected root module and reusable modules under `tf_modules/`
   (`talos_cluster`, `virtual_machine`, `algo_vpn`).
2. Delegate to `terraform-specialist` for advanced state, provider, migration, or
   module-interface work.
3. Follow existing repository conventions for variable naming, type constraints,
   descriptions, validation, outputs, and provider constraints.
4. Keep cluster-specific values outside reusable modules.
5. Avoid unnecessary data sources when values are already explicit module inputs.
6. Avoid hardcoding values that belong in cluster definitions or environment configuration.

```bash
tofu fmt -check -recursive
tofu -chdir=<module-or-root> init -backend=false
tofu -chdir=<module-or-root> validate
```

When credentials and backend access are available:

```bash
tofu -chdir=<root-module> plan
```

Inspect the plan for replacements and destructive operations, especially node, disk,
identity, or PCI-device replacement. Do not apply Terraform unless the user explicitly
requests a live infrastructure change.

---

## Docker Compose Changes

1. Inspect nearby platform stacks and the root Taskfile behavior.
2. Use the existing `platform/<category>/<stack>/` organization.
3. Pin image versions.
4. Put configuration in environment files or explicit Compose configuration.
5. Keep secrets out of plaintext Compose files.
6. Define networks, volumes, health checks, restart behavior, and resource constraints
   where supported.
7. Platform services that need Kubernetes resources put them in a `kubernetes/`
   subdirectory (e.g. `platform/ai/kubernetes/`).

```bash
docker compose -f <compose-file> config
```

Do not start, stop, recreate, or delete live services unless explicitly requested.

---

## Secrets

1. Never place secret values directly in Kubernetes manifests, Helm values, Compose files,
   Taskfiles, agent definitions, or skill files.
2. Use the repository's existing SOPS and AWS KMS workflow.
3. Confirm the file path matches a rule in `.sops.yaml` (`kubernetes/*`, `platform/*`).
4. Check encrypted files contain a valid `sops:` section.
5. Avoid printing decrypted values in command output or the final response.
6. Run secret scanning when available.

```bash
sops -e <file>   # encrypt
sops -d <file>   # decrypt
```
