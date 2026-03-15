# Kubernetes Gateway API

The standard Kubernetes API for service networking. This repo uses Gateway API v1 resources via kgateway.

## Relevance to This Repo

- All ingress routing uses Gateway API (not Ingress resources)
- HTTPRoute, Gateway, ReferenceGrant are the primary resource types
- Cross-namespace routing requires ReferenceGrants
- ExternalDNS watches Gateway API resources for DNS record creation

## Documentation to Scrape

See `scrape-plan.md` for URLs. Key topics:
- HTTPRoute specification and examples
- Gateway resource configuration
- ReferenceGrant for cross-namespace routing
- TLSRoute and GRPCRoute (future use)
- API versioning (v1 vs v1beta1)
