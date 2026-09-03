# Self-Hosted Firecrawl in This Homelab

What is actually deployed, what does not work, and how to triage it. Read this
before writing any firecrawl request — several documented features are absent
from a self-hosted stack and fail in confusing ways rather than returning a
clean "unsupported".

## Topology

| Piece | Address | Owner file |
| --- | --- | --- |
| API | `firecrawl-firecrawl-api.automation.svc.cluster.local:3002` | `platform/automation/kubernetes/firecrawl/kustomization.yaml` |
| API (LAN) | `http://firecrawl.homelab.internal` | `platform/automation/kubernetes/firecrawl/internal-httproute.yaml` |
| Playwright | `firecrawl-firecrawl-playwright:3000` | same kustomization |
| Queue | nuq worker + `firecrawl-firecrawl-nuq-postgres:5432` | same kustomization |
| Redis | `redis-service.data.svc.cluster.local:6379` | `platform/data/` (chart Redis disabled) |
| MCP server | `firecrawl-mcp.automation.svc.cluster.local:3000/mcp` | `platform/automation/kubernetes/firecrawl/mcp-deployment.yaml` |
| MCP federation | agentgateway target `firecrawl` | `platform/ai/kubernetes/mcp-backend.yaml` |
| MCP for kagent | `RemoteMCPServer/firecrawl` in namespace `ai` | `platform/ai/kubernetes/mcp/firecrawl.yaml` |

Everything runs in the `automation` namespace except the kagent CR and the
agentgateway backend, which live in `ai`.

Auth: the chart sets `USE_DB_AUTHENTICATION: "false"`, so the API accepts
unauthenticated requests. The MCP sidecar still sends
`FIRECRAWL_API_KEY=fc-self-hosted`, which the API ignores.

## What does not work here

From the upstream self-hosting guide, the default open-source stack supports
"core scrape, crawl, map, and search routes" with Fetch and Playwright
processing. Everything below is outside that.

| Feature | Status | Why |
| --- | --- | --- |
| `actions` (click, write, press, scroll, executeJavascript) | Unavailable | Fetch and Playwright both report no support. Requires Fire-engine, which is not deployed |
| `screenshot` format and screenshot actions | Unavailable | Same. Requires Fire-engine |
| `json` format, `summary` format, `changeTracking` in json mode | Unavailable | Need an OpenAI-compatible provider or Ollama. Our chart sets `secret.OPENAI_API_KEY: ""` |
| `proxy: "enhanced"` | Unavailable | Fire-engine anti-bot path |
| Agent, Interact/Browser sessions, feedback endpoints | Unavailable | Firecrawl Cloud only |
| `product`, `menu`, `audio`, `video` formats | Unavailable | Firecrawl Cloud only |
| `search` | Verify before relying on it | Needs a configured search backend |

The practical consequence: **this deployment reads pages, it does not drive
them.** A site that needs a login, a form submit, or a click-to-load is not a
firecrawl job here. Escalate it to the kagent scraping agent or say plainly
that it needs Fire-engine.

Likewise, structured extraction has to happen in the caller. Ask firecrawl for
markdown and parse it deterministically (n8n Code node, regex, table parsing)
rather than reaching for `formats: ["json"]`.

## Operational characteristics

- **One API replica, one nuq worker.** Concurrent heavy crawls serialize.
  Stagger scheduled workflows rather than adding replicas.
- **`nuqPostgres.persistence.enabled: false`.** The queue database has no
  volume, so in-flight crawl and batch jobs are lost when the pod restarts. Do
  not build anything that assumes a job id survives a redeploy.
- **Every image is on `latest`** (`firecrawl`, `playwright-service`,
  `nuq-postgres`) with `pullPolicy: Always`. A restart can change behaviour
  with no repo change. Anything that starts failing for no apparent reason
  deserves an image-digest check before a long debugging session.
- **Redis is cross-namespace**, in `data`. If `data` is down or its network
  policy changes, firecrawl fails in ways that do not mention Redis.
- **The MCP sidecar installs itself at boot.** It runs
  `npx -y firecrawl-mcp@3.23.0` on a `node:22-alpine` image, so the pod needs
  egress to the npm registry every start. No registry, no MCP server.
- **`scraping-service-agent` binding looks wrong.**
  `platform/automation/kubernetes/agents/scraping-agent.yaml` references a
  `RemoteMCPServer` named `firecrawl-mcp`, but the CR that ships is named
  `firecrawl` (`platform/ai/kubernetes/mcp/firecrawl.yaml`). Verify the
  agent's discovered tools before trusting it.

None of the above are this skill's to fix. They are watch-outs; changes to
them go through the `developer` agent.

## Triage runbook

Work down the list. Each step isolates a different layer.

1. **Is the API answering HTTP?**

   ```bash
   curl -sS -m 5 http://firecrawl.homelab.internal/v0/health/readiness
   ```

   Expect `{"status":"ok"}`. This is a heartbeat and nothing more — it does
   not check Redis, Postgres, Playwright, the workers, or outbound network.

2. **Can it complete a real scrape?** This is the only meaningful health
   check. Keep curl's `--max-time` above the request `timeout` so the API can
   return its own timeout response.

   ```bash
   curl -sS -m 75 -X POST http://firecrawl.homelab.internal/v2/scrape \
     -H 'Content-Type: application/json' \
     -d '{"url":"https://example.com","formats":["markdown"],"timeout":60000}'
   ```

   Readiness passing while this fails points at Playwright or at egress from
   the cluster, not at the API.

3. **Pod state and logs**, via `homelab-agent` MCP (`kagent-tools_k8s_get_*`,
   `_describe_*`, pod logs) or `kubectl`:

   ```bash
   kubectl -n automation get pods -l app.kubernetes.io/name=firecrawl
   kubectl -n automation logs deploy/firecrawl-firecrawl-api --tail=200
   kubectl -n automation logs deploy/firecrawl-firecrawl-playwright --tail=200
   ```

4. **Queue and Redis.** Check the nuq worker and nuq-postgres pods, then
   confirm `redis-service` in `data` is reachable. Jobs accepted but never
   progressing past `status: scraping` usually mean the worker or queue, not
   the API.

5. **MCP server.** `curl http://firecrawl-mcp.automation.svc:3000/health` from
   inside the cluster returns `ok`. If the pod is crash-looping at start, look
   for npm registry egress failures.

## Tool names through MCP

The `firecrawl-mcp` package exposes `firecrawl_scrape`, `firecrawl_map`,
`firecrawl_search`, `firecrawl_crawl`, `firecrawl_check_crawl_status`, and
`firecrawl_parse`. It also exposes `firecrawl_agent`, `firecrawl_agent_status`,
and `firecrawl_interact`, which are cloud-only and will not work against our
API.

agentgateway prefixes federated tools with the target name — the way the
`kagent-tools` target surfaces `helm_*` as `kagent-tools_helm_*`. Our target is
named `firecrawl`, so the names seen through `homelab-agent` are prefixed.
List the tools at runtime rather than assuming the exact string.
