# Research

## Overview

The research platform enables AI-powered research and experimentation using self-hosted infrastructure.

## Capabilities

- **Self-hosted LLMs** - Run models locally with vLLM on the `mlops` GPU node
- **Agent frameworks** - Deploy and test AI agents
- **Experimentation** - Test new models and techniques
- **Data privacy** - Keep sensitive research data on-premises

## Where it runs

!!! info "Not deployed"
    The research stack is defined in `platform/research/` but is not deployed. Its
    `research:deploy` step is commented out in `platform/Taskfile.yml`, and neither cluster has a
    `research` namespace.

| Component | Cluster | Namespace | Defined in | Status |
|-----------|---------|-----------|------------|--------|
| SearXNG | — | `research` | `platform/research/kubernetes/searxng/` | Not deployed |
| JupyterHub | — | — | `platform/research/jupyterhub/` | Not deployed (not referenced by the research kustomization) |
| Open WebUI | `mlops` | `ai` | `platform/ai/kubernetes/integrations/openwebui/` | Deployed as part of the [AI Platform](ai/index.md) |
| vLLM (self-hosted LLM) | `mlops` | `ai` | `platform/ai/kubernetes/llm-providers/selfhosted/` | Deployed as part of the [AI Platform](ai/index.md) |
