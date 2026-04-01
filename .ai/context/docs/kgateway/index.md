# kgateway - Kubernetes Gateway API Implementation

Envoy-based Gateway API implementation used as the primary ingress controller in this homelab. Deployed as a dependency of the `homelab-gateway` chart at v2.2.1.

## Relevance to This Repo

- Sole Gateway API implementation for the cluster
- Wrapped by `kubernetes/charts/homelab-gateway/` umbrella chart
- Provides both external (Cloudflare tunnel) and internal (LAN) Gateways
- Handles HTTPRoute, TLS termination, and cross-namespace routing
- AI gateway capabilities for LLM traffic routing

## Documentation to Scrape

See `scrape-plan.md` for URLs. Key topics:
- Gateway and HTTPRoute configuration
- TLS/Certificate integration with cert-manager
- AI gateway features (LLM routing, token-based rate limiting)
- Envoy proxy configuration and tuning
- Helm chart values reference
- Upgrade guides (relevant for version bumps)
