---
name: architecture-design
description: Design software change architecture for an existing repository, based on source evidence.
---

# Architecture design

1. Inspect README, AGENTS.md/CLAUDE.md, architecture decision records, package and app layout.
2. Document current desired state vs live state separately; cite real paths.
3. Produce a minimal change plan, interfaces/data-flow, tests and rollback.
4. For homelab changes consider Talos, Cilium, kgateway, Kustomize, Helmfile stages, SOPS and cluster split.
5. Do not modify code; mark uninspected or inaccessible areas explicitly.
