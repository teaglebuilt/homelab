* `.ai/context/` -- AI agent context. `docs/` has scraped technology documentation. `knowledge/` has domain-specific reference material.
* `docs/` -- MkDocs site describing the homelab platform for end users.
* `.claude/agents/` -- Claude Code agent definitions (homelab-architect, terraform-specialist, memory-optimizer).
* `.cursor/rules/` -- Cursor IDE rules split by role (.arch.mdc, .dev.mdc) and domain (kubernetes.mdc, terraform.mdc).

## Workflow

- **Architect** (Claude Code preferred): Multi-file analysis, technology research, infrastructure planning, reviewing Helm chart dependencies, designing Helmfile stage changes. Use `homelab-architect` agent.
- **Developer** (Cursor preferred): In-file editing of YAML manifests, Helm templates, Terraform modules, Ansible playbooks. Follow patterns in `.cursor/rules/`.
- **Reference**: Technology docs in `.ai/context/docs/<technology>/` are scraped from upstream sources. See `.ai/context/docs/scrape-plan.md` for the full list.
