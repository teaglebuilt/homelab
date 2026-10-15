# Agent catalog

Generated from the live `mlops` cluster on 2026-10-15. Regenerate with:

```sh
kubectl get agent -n ai -o json | python3 -c '
import json,sys
for a in json.load(sys.stdin)["items"]:
    s=a["spec"]
    print(a["metadata"]["name"], s.get("templateRef",{}).get("name"), s.get("harnessRef",{}).get("name"))
'
kubectl get agenttemplate -n ai -o yaml
```

## Agents

| Agent | Template | Harness | Model | Purpose |
| --- | --- | --- | --- | --- |
| `solutions-architect` | `solutions-architect` | `kagent` | `llmd-vllm-config` (self-hosted vLLM) | Homelab/platform architecture plans grounded in the Qdrant `knowledge` tree and live cluster state. Not generic cloud advice. |
| `knowledge-scout-agent` | `knowledge-scout` | `kagent` | `llmd-vllm-config` (self-hosted vLLM) | Finds gaps in the knowledge tree via `kb_search`, scouts external sources, proposes citeable content. |
| `scraping-service-agent` | `scraping-service-agent` | `kagent` | `claude-opus-4-5` | Scraping-as-a-service: target URL + what to find + output schema, returns strict JSON. Reusable by any A2A/MCP caller. |

## Short forms accepted as the `$agent` argument

| Typed | Resolves to |
| --- | --- |
| `architect`, `solutions-architect` | `solutions-architect` |
| `scout`, `knowledge-scout`, `knowledge-scout-agent` | `knowledge-scout-agent` |
| `scraper`, `scraping`, `scraping-service-agent` | `scraping-service-agent` |
| `sandbox` | not an agent; selects the sandbox path |

All three run on the **kagent** harness, so per-tool selection is enforced and the
agents have native memory and compaction available.

## Tools per agent

| Agent | MCP server | Selected tools |
| --- | --- | --- |
| `solutions-architect` | `kb-retrieval` | `kb_search` |
| | `firecrawl` | `firecrawl_firecrawl_search`, `_agent`, `_agent_status`, `_research_search_github`, `_research_search_papers` |
| `knowledge-scout-agent` | `kb-retrieval` | `kb_search` |
| | `kagent-tool-server` | `shell`, `datetime_get_current_time` |
| | `firecrawl` | same five as above |
| `scraping-service-agent` | `firecrawl` | same five as above |

**Known defect:** the selected firecrawl names carry a doubled prefix
(`firecrawl_firecrawl_search`), while the server discovers `firecrawl_search`. On the
kagent harness partial selection is enforced, so these selections may resolve to no
tools. Verify before relying on firecrawl through any of these agents.

## Templates with no Agent

`llmd-inference-agent` exists as an AgentTemplate (routes to the self-hosted vLLM
OpenAI-compatible server) but has no `Agent` binding it to a harness, so it is not
invocable.

## Not in this cluster

Earlier revisions of this skill routed to `platform-engineer`, `cilium-agent`,
`gpu-agent`, `observability-agent`, `research-agent` and `gitops-agent`. None of
these exist. Do not route to them.
