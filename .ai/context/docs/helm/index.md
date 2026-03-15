# Helm Charts - Development Patterns

Helm chart authoring patterns relevant to this repo, particularly for the custom `homelab-gateway` umbrella chart.

## Relevance to This Repo

- `homelab-gateway` is the primary custom chart (umbrella pattern with kgateway subchart dependencies)
- Helmfile manages all chart releases with staged deployment ordering
- Values files use Go templating (`.gotmpl` extension) with `requiredEnv` for secret injection
- OCI registries used for some charts (kgateway, spegel, spin-operator)

## Documentation to Scrape

See `scrape-plan.md` for URLs. Key topics:
- Chart.yaml dependency management (OCI registries)
- Umbrella chart patterns
- Go template functions for Helm
- Helmfile integration patterns
- Values file organization
- Chart testing and linting
