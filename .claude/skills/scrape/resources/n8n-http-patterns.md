# Calling Firecrawl from n8n

Self-hosted firecrawl is driven from n8n with the **HTTP Request** node, not
the Firecrawl community node. The community node targets the cloud API and
expects credentials we do not have.

Base URL from inside the cluster:
`http://firecrawl-firecrawl-api.automation.svc.cluster.local:3002`.
From the LAN: `http://firecrawl.homelab.internal`. No `Authorization` header is
needed (`USE_DB_AUTHENTICATION=false`).

The bodies below are the payload contract. The `n8n-workflow-builder` agent
owns the actual node JSON and must confirm the current node schema with
`get_node_essentials` before wiring anything — do not paste node JSON from
memory into a workflow.

## Shared node settings

| Field | Value |
| --- | --- |
| Method | `POST` (`GET` for crawl status) |
| URL | `http://firecrawl-firecrawl-api.automation.svc.cluster.local:3002/v2/<endpoint>` |
| Send Body | on |
| Body Content Type | JSON |
| Specify Body | Using JSON |
| Options → Timeout | above the firecrawl `timeout` in the body |
| Options → Response → Never Error | on, when you want to branch on failure instead of halting the run |

Keep the node timeout above the request `timeout`. If n8n gives up first you
get an n8n error instead of firecrawl's own timeout response, and you lose the
diagnostic.

## Pattern 1: one page to markdown

The default for "read this page on a schedule". Cheapest thing that works.

```
POST /v2/scrape
```

```json
{
  "url": "https://example.com/page",
  "formats": ["markdown"],
  "onlyMainContent": true,
  "maxAge": 3600000,
  "timeout": 60000
}
```

`maxAge` of one hour means a workflow that ticks every 15 minutes only pays for
a real fetch once an hour. Raise it for anything that does not change often;
drop it to `0` only when you genuinely need this second's content.

For a JS-rendered page, add `waitFor` (start at 2000-3000 ms) before reaching
for anything more complicated. There is no `actions` escape hatch on this
deployment.

Markdown comes back at `{{ $json.data.markdown }}`, with status at
`{{ $json.data.metadata.statusCode }}`.

## Pattern 2: discover then batch

When you need many pages from one site and want the URL list to be inspectable
before spending anything.

Node 1 — map:

```
POST /v2/map
```

```json
{"url": "https://docs.example.com", "search": "changelog", "limit": 100}
```

Node 2 — Code or Set, to reduce `links[]` to a plain array of URL strings.

Node 3 — batch scrape:

```
POST /v2/batch/scrape
```

```json
{
  "urls": ["={{ $json.urls }}"],
  "formats": ["markdown"],
  "onlyMainContent": true,
  "ignoreInvalidURLs": true
}
```

Returns `{"success": true, "id": "..."}`. Poll it the same way as a crawl.

## Pattern 3: crawl with polling

Crawl is asynchronous. Start it, then poll — do not hold an HTTP node open
across a whole crawl, which is what produces 504s.

Node 1 — start:

```
POST /v2/crawl
```

```json
{
  "url": "https://docs.example.com",
  "limit": 50,
  "maxDiscoveryDepth": 2,
  "includePaths": ["^/docs/"],
  "delay": 1,
  "scrapeOptions": {"formats": ["markdown"], "onlyMainContent": true}
}
```

Always set `limit`. The default is 10000, which is a runaway, not a budget.
`delay` is in seconds and forces concurrency to 1 — good manners on someone
else's site, and kind to our single API replica.

Node 2 — Wait (30-60 s).

Node 3 — status:

```
GET /v2/crawl/{{ $('Start Crawl').item.json.id }}
```

Node 4 — IF on `{{ $json.status }}`:

- `completed` — continue.
- `failed` — branch to error handling.
- anything else — loop back to the Wait node.

Node 5 — Split Out on `data` to get one item per page, then parse
`$json.markdown` in a Code node.

Add a loop counter and bail after a bounded number of iterations. A crawl whose
queue pod restarted will never reach a terminal status, because the queue has
no persistent volume.

If `next` is populated on a completed crawl, the results were paginated at
10 MB. Follow that URL until it is null or you will silently drop pages.

## Pattern 4: webhook instead of polling

For long crawls, let firecrawl call n8n instead. Add to the crawl body:

```json
{
  "webhook": {
    "url": "http://n8n.homelab.internal/webhook/<path>",
    "events": ["completed", "failed"],
    "metadata": {"source": "docs-crawl"}
  }
}
```

Then a second workflow starting with a Webhook trigger consumes it. Use `page`
in `events` only if you want per-page delivery; on a large crawl that is a lot
of executions.

## Extraction

Do the extraction in n8n, not in firecrawl. The `json` format needs an LLM
provider that this deployment does not have configured, so a request asking for
it fails rather than degrading.

Ask for `markdown`, then parse deterministically in a Code node: regex, table
splitting, or heading-based sectioning. It is free, it is repeatable, and it
does not drift between runs. Reach for an LLM node only when the page shape is
genuinely unpredictable, and then only on the text firecrawl already extracted.

## Failure handling

- Retry 408, 429, 500, 502, 503, and 504. Do not retry 400, 401, 404, or 413 —
  those are payload bugs and will fail identically forever.
- Honour `Retry-After` on 429.
- A 504 means switch to the async endpoint, not raise the timeout.
- Firecrawl returns `{"success": false, "error": "..."}` on failure. Branch on
  `success`, not only on the HTTP status, when "Never Error" is enabled.
