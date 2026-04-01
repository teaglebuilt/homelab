# Documentation Scrape Plan

URLs to scrape with `/scrape` for each technology context directory. Scrape into the corresponding directory as markdown files.

## kagent/

| File | URL | Notes |
|------|-----|-------|
| what-is-kagent.md | https://kagent.dev/docs/kagent/introduction/what-is-kagent | Architecture overview |
| quickstart.md | https://kagent.dev/docs/kagent/getting-started/quickstart | Installation and first agent |
| agent-crd.md | https://kagent.dev/docs/kagent/core-concepts/agents | Agent CRD specification |
| tools.md | https://kagent.dev/docs/kagent/core-concepts/tools | Tool integration (MCP, built-in) |
| llm-providers.md | https://kagent.dev/docs/kagent/core-concepts/model-providers | LLM provider configuration |
| k8s-agent.md | https://kagent.dev/agents/k8s-agent | Kubernetes agent system prompt |
| helm-install.md | https://kagent.dev/docs/kagent/getting-started/installation | Helm chart installation |

## agentgateway/

| File | URL | Notes |
|------|-----|-------|
| overview.md | https://agentgateway.dev/docs/ | Architecture and concepts |
| quickstart.md | https://agentgateway.dev/docs/quickstart/ | Getting started guide |
| kubernetes.md | https://agentgateway.dev/docs/kubernetes/latest/ | Kubernetes controller setup |
| configuration.md | https://agentgateway.dev/docs/configuration/ | Configuration reference |
| mcp-support.md | https://agentgateway.dev/docs/protocols/mcp/ | MCP protocol support |
| a2a-support.md | https://agentgateway.dev/docs/protocols/a2a/ | A2A protocol support |

## kgateway/

| File | URL | Notes |
|------|-----|-------|
| about.md | https://kgateway.dev/docs/ | Project overview |
| quickstart.md | https://kgateway.dev/docs/envoy/main/quickstart/ | Getting started |
| gateway-setup.md | https://kgateway.dev/docs/envoy/main/traffic-management/gateway/ | Gateway resource configuration |
| httproute.md | https://kgateway.dev/docs/envoy/main/traffic-management/httproute/ | HTTPRoute configuration |
| tls.md | https://kgateway.dev/docs/envoy/main/traffic-management/tls/ | TLS termination and certificates |
| ai-gateway.md | https://kgateway.dev/docs/envoy/main/ai-gateway/ | AI gateway features |
| helm-values.md | https://kgateway.dev/docs/envoy/main/install/helm-values/ | Helm chart values reference |
| upgrade.md | https://kgateway.dev/docs/envoy/main/install/upgrade/ | Upgrade procedures |

## gateway-api/

| File | URL | Notes |
|------|-----|-------|
| concepts.md | https://gateway-api.sigs.k8s.io/concepts/api-overview/ | API overview and concepts |
| httproute.md | https://gateway-api.sigs.k8s.io/api-types/httproute/ | HTTPRoute specification |
| gateway.md | https://gateway-api.sigs.k8s.io/api-types/gateway/ | Gateway specification |
| referencegrant.md | https://gateway-api.sigs.k8s.io/api-types/referencegrant/ | ReferenceGrant for cross-ns |
| grpcroute.md | https://gateway-api.sigs.k8s.io/api-types/grpcroute/ | GRPCRoute (future use for AI) |
| spec-reference.md | https://gateway-api.sigs.k8s.io/reference/spec/ | Full API spec reference |

## kustomize/

| File | URL | Notes |
|------|-----|-------|
| kustomization.md | https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/ | kustomization.yaml reference |
| patches.md | https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patches/ | Patch strategies |
| generators.md | https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/ | ConfigMap/Secret generators |
| helm-charts.md | https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/helmcharts/ | Helm integration |
| best-practices.md | https://kubectl.docs.kubernetes.io/guides/config_management/ | Configuration management guide |

## helm/

| File | URL | Notes |
|------|-----|-------|
| chart-best-practices.md | https://helm.sh/docs/chart_best_practices/ | Official best practices |
| chart-template-guide.md | https://helm.sh/docs/chart_template_guide/ | Template authoring guide |
| dependencies.md | https://helm.sh/docs/helm/helm_dependency/ | Dependency management |
| oci-registries.md | https://helm.sh/docs/topics/registries/ | OCI registry support |
| library-charts.md | https://helm.sh/docs/topics/library_charts/ | Library chart patterns |
| helmfile.md | https://helmfile.readthedocs.io/en/latest/ | Helmfile documentation |

## cloudflare/ (already partially scraped)

| File | URL | Notes |
|------|-----|-------|
| zero-trust.md | https://developers.cloudflare.com/cloudflare-one/ | Zero Trust overview |
| dns-records.md | https://developers.cloudflare.com/dns/manage-dns-records/ | DNS management |

## helmfile/

| File | URL | Notes |
|------|-----|-------|
| best-practices.md | https://helmfile.readthedocs.io/en/latest/writing-helmfile/ | Best Practices |
| hooks.md | https://helmfile.readthedocs.io/en/latest/#hooks| Helmfile Hooks |
| templating.md | https://helmfile.readthedocs.io/en/latest/#templating | Templating in helmfile |
