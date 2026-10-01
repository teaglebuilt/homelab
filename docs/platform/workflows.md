# Workflows

## Where it runs

| Component | Cluster | Namespace | Deployed from |
|-----------|---------|-----------|---------------|
| n8n | `mlops` | `automation` | `platform/automation/kubernetes/n8n/` |
| n8n workflow backup CronJob (`n8n-workflow-backup`) | `mlops` | `automation` | `platform/automation/kubernetes/n8n/` |
| Firecrawl (API, workers, Playwright, MCP) | `mlops` | `automation` | `platform/automation/kubernetes/firecrawl/` |
| Postgres for n8n | `mlops` | `data` (CNPG cluster `postgres`) | `platform/data/kubernetes/apps/postgres/` |

The stack is deployed by `task platform:automation:deploy` (`platform/automation/Taskfile.yml`), which
runs only when `CLUSTER=mlops`. n8n is reachable in two ways:

* `n8n.homelab.internal` on the `mlops` internal gateway (`n8n/internal-httproute.yaml`), which serves
  the full app on the LAN.
* `n8n.teaglebuilt.tech` on `homelab-external-gateway` through the Cloudflare tunnel
  (`n8n/external-httproute.yaml`), which serves OAuth callbacks only.

## n8n Automation

[n8n](https://n8n.io/) provides workflow automation capabilities for the homelab.

## Use Cases

- **Data pipelines** - Automated data collection and processing
- **Notifications** - Alert routing and notification delivery
- **Integrations** - Connect various services and APIs
- **Scheduled tasks** - Cron-like job scheduling

## Integration with AI

Workflows can integrate with the [AI Platform](ai/index.md) to:

- Trigger LLM-based processing
- Automate content generation
- Build AI-powered automation pipelines
