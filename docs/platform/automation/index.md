# Platform Automation

## Where it runs

| Component | Cluster | Namespace | Deployed from |
|-----------|---------|-----------|---------------|
| n8n, n8n workflow backup | `mlops` | `automation` | `platform/automation/kubernetes/n8n/` |
| Firecrawl | `mlops` | `automation` | `platform/automation/kubernetes/firecrawl/` |
| Scraping agent (kagent `Agent`) | `mlops` | `automation` | `platform/automation/kubernetes/agents/scraping-agent.yaml` |

All three are applied by `task platform:automation:deploy`, which runs only when `CLUSTER=mlops`.

## Workflow Automation

n8n is covered in [Workflows](../workflows.md).

## Scraping Automation

A dedicated scraping platform is **planned**: see "Build Scraping Platform" in `.ai/ROADMAP.md`.
Today, Firecrawl (listed above) does the scraping.
