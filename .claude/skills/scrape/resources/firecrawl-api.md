# Firecrawl v2 API Reference

Condensed from `https://docs.firecrawl.dev/llms.txt` and the per-endpoint pages.
Only the parts that matter for this homelab. For anything not here, fetch the
single relevant endpoint page — never `llms-full.txt`.

Read [self-hosted.md](self-hosted.md) before using any of this. Several
documented options do not work on our deployment.

## Conventions

- Base path is `/v2`. Our base URL is `http://firecrawl.homelab.internal`
  (LAN) or `http://firecrawl-firecrawl-api.automation.svc.cluster.local:3002`
  (in-cluster).
- Auth is `Authorization: Bearer <key>`. Our instance runs
  `USE_DB_AUTHENTICATION=false`, so the header is optional.
- All durations are milliseconds unless stated otherwise. `delay` on crawl is
  the exception: it is in seconds.
- Errors return `{"success": false, "error": "...", "details": ...}`.

## Endpoints

| Method | Path | Sync? | Purpose |
| --- | --- | --- | --- |
| POST | `/v2/scrape` | sync | One URL, one document back |
| POST | `/v2/map` | sync | Discover URLs on a site, fast, no page fetches |
| POST | `/v2/crawl` | async | Follow links across a site |
| GET | `/v2/crawl/{id}` | — | Crawl status and results |
| DELETE | `/v2/crawl/{id}` | — | Cancel a crawl |
| GET | `/v2/crawl/{id}/errors` | — | Per-URL failures for a crawl |
| POST | `/v2/batch/scrape` | async | Many known URLs, same options for each |
| POST | `/v2/search` | sync | Web search, optionally scraping each result |
| GET | `/v0/health/readiness` | — | Heartbeat only (see below) |

`/v0/health/readiness` returns `{"status":"ok"}` and proves only that the API
process answers HTTP. It does not check Redis, Postgres, Playwright, the
workers, or outbound network access. A real scrape is the only meaningful
health check.

## Scrape

```
POST /v2/scrape
{
  "url": "https://example.com",
  "formats": ["markdown"],
  "onlyMainContent": true,
  "timeout": 60000
}
```

Response is `{"success": true, "data": {"markdown": "...", "metadata": {...}}}`.
`metadata` carries `statusCode`, `title`, `description`, `sourceURL` (what you
asked for) and `url` (where you landed after redirects).

### Options

| Option | Default | Notes |
| --- | --- | --- |
| `formats` | `["markdown"]` | Strings, or objects for the ones that take arguments |
| `onlyMainContent` | `true` | Deterministic HTML-level strip of nav/header/footer. No LLM |
| `includeTags` / `excludeTags` | — | CSS tag allowlist / denylist |
| `maxAge` | `172800000` (2 days) | Serve cache younger than this. The cheapest speedup available |
| `minAge` | — | Cache-only. 404 `SCRAPE_NO_CACHED_DATA` on miss. `1` accepts any cached copy |
| `headers` | — | Cookies, user-agent, and friends |
| `waitFor` | `0` | Extra delay before capture, on top of smart wait. The lever for JS-rendered pages |
| `timeout` | `60000` | Min 1000, max 300000 |
| `mobile` | `false` | Emulate a mobile device |
| `skipTlsVerification` | `true` | |
| `parsers` | `["pdf"]` | `[]` returns the PDF as base64 instead of parsing it |
| `blockAds` | `true` | Also blocks cookie popups |
| `removeBase64Images` | `true` | Keeps alt text, drops the inline data URL |
| `proxy` | `auto` | `basic` / `enhanced` / `auto`. `enhanced` needs Fire-engine, so unavailable here |
| `location` | US | `{"country": "DE", "languages": ["de-DE"]}` |
| `storeInCache` | `true` | Forced to `false` when using `actions` or `headers` |
| `actions` | — | **Not supported on our deployment.** See self-hosted.md |
| `redactPII` | `false` | |

### Formats

`markdown`, `html`, `rawHtml`, `links`, `images`, `summary`, `screenshot`,
`json`, `changeTracking`, `branding`, `product`, `menu`, `audio`, `video`.

On our deployment only `markdown`, `html`, `rawHtml`, `links`, and `images`
are dependable. `screenshot` needs Fire-engine; `json`, `summary`, and
`changeTracking` in json mode need an LLM provider we have not configured.

The argument-taking formats use object form:

```json
{"type": "json", "schema": { "...JSON Schema..." }, "prompt": "..."}
{"type": "screenshot", "fullPage": true, "quality": 80}
{"type": "changeTracking", "modes": ["git-diff"], "tag": "nightly"}
```

## Map

```
POST /v2/map
{"url": "https://docs.example.com", "limit": 200, "search": "api"}
```

Returns `{"success": true, "links": [{"url", "title", "description"}]}`.

| Option | Default | Notes |
| --- | --- | --- |
| `search` | — | Orders results by relevance to this term |
| `sitemap` | `include` | `skip` ignores the sitemap, `only` returns sitemap URLs and nothing else |
| `includeSubdomains` | `true` | |
| `ignoreQueryParameters` | `true` | |
| `ignoreCache` | `false` | Sitemap data is cached up to 7 days |
| `limit` | `5000` | Max 100000 |

Map is cheap and does not fetch page bodies. Use it to size a job before
committing to a crawl, and to build the URL list for a batch scrape.

## Crawl

```
POST /v2/crawl
{
  "url": "https://docs.example.com",
  "limit": 100,
  "maxDiscoveryDepth": 2,
  "includePaths": ["^/docs/"],
  "delay": 1,
  "scrapeOptions": {"formats": ["markdown"], "onlyMainContent": true}
}
```

Returns `{"success": true, "id": "<uuid>", "url": "<status url>"}` immediately.
Poll `GET /v2/crawl/{id}`:

```json
{
  "status": "scraping",
  "total": 100,
  "completed": 42,
  "creditsUsed": 42,
  "next": null,
  "data": [ { "markdown": "...", "metadata": {...} } ]
}
```

`status` is `scraping`, `completed`, or `failed`. `next` is a URL to the next
10 MB page of results and appears whenever the payload is oversized or the
crawl is still running — follow it until it is null.

| Option | Default | Notes |
| --- | --- | --- |
| `limit` | `10000` | Always set this explicitly. The default is not a budget |
| `maxDiscoveryDepth` | — | Root and sitemapped pages are depth 0 |
| `includePaths` / `excludePaths` | — | Regex against the pathname |
| `regexOnFullURL` | `false` | Match against the whole URL including query string |
| `sitemap` | `include` | `skip` / `include` / `only` |
| `ignoreQueryParameters` | `false` | Avoids re-scraping one path under many query strings |
| `crawlEntireDomain` | `false` | Allows sibling and parent paths, not just children |
| `allowExternalLinks` | `false` | |
| `allowSubdomains` | `false` | |
| `ignoreRobotsTxt` | `false` | Leave it alone unless you own the target |
| `delay` | — | Seconds between scrapes. Setting it forces concurrency to 1 |
| `maxConcurrency` | — | |
| `webhook` | — | `{"url", "headers", "metadata", "events": ["started","page","completed","failed"]}` |
| `scrapeOptions` | — | The full scrape options object, applied per page |
| `prompt` | — | Generates the options above from natural language. Explicit options win |

## Batch scrape

```
POST /v2/batch/scrape
{"urls": ["https://a.example/1", "https://a.example/2"], "formats": ["markdown"]}
```

Async with the same start-then-poll shape as crawl. Takes `webhook`,
`maxConcurrency`, and `ignoreInvalidURLs` (default `true`, rejected URLs come
back in `invalidURLs` instead of failing the whole request), plus every scrape
option.

Use `map` then `batch/scrape` when you know the shape of the site. It is more
predictable than a crawl and the URL list is inspectable before you spend
anything.

## Search

```
POST /v2/search
{"query": "...", "limit": 10, "scrapeOptions": {"formats": ["markdown"]}}
```

`query` maxes out at 500 characters. `limit` defaults to 10, max 100. Also
takes `sources`, `categories`, `tbs` (time filters such as `qdr:d`, `qdr:w`,
or `sbd:1` for sort-by-date), `location`, `country`, and `timeout`.

Search depends on a configured search backend. Verify it works on our instance
before designing anything around it.

## Errors and retries

| HTTP | Meaning | Retry |
| --- | --- | --- |
| 400 | Schema validation failed, or a malformed URL. Check `details` | No |
| 401 / 403 | Auth. Not applicable with `USE_DB_AUTHENTICATION=false` | No |
| 404 | Unknown job id or path. Also cache miss under `minAge` | No |
| 408 | Page exceeded the request `timeout` | Yes, backoff |
| 413 | Body too large. Shorten the schema or split the batch | No |
| 422 | Invalid JSON Schema, or the model could not conform | Sometimes |
| 429 | Rate or concurrency limit. Honour `Retry-After` | Yes, backoff |
| 500 / 502 / 503 | Server side | Yes, backoff |
| 504 | Gateway timeout, typically a long crawl held open | Yes — switch to async crawl and poll |

A 504 on a synchronous request is the API telling you to use the async
endpoints. Do not fix it by raising the caller's timeout.

## CLI

The `firecrawl` CLI speaks to any API URL, so it works against our instance
without credentials:

```bash
export FIRECRAWL_API_URL=http://firecrawl.homelab.internal
firecrawl scrape https://example.com --only-main-content

# or per invocation
firecrawl --api-url http://firecrawl.homelab.internal scrape https://example.com

# or persist it
firecrawl config --api-url http://firecrawl.homelab.internal
```

Useful subcommands: `scrape`, `crawl <url> --limit N --wait --progress`,
`map <url> --search term`, `search <query> --scrape`. Output controls are
`--format a,b`, `--pretty`, and `-o file`.
