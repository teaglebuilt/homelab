# External Documentation Registry

Tier-3 reference. Load only after a domain skill (Tier 1) and repo invariants /
runbooks (Tier 2) fail to cover the detail. Always fetch inside a forked context.

**Fetch discipline:** fetch the INDEX (`llms.txt`) first, follow a single deep
link to the one page you need, and never inline a `llms-full.txt` dump — those
are the entire doc corpus concatenated (multiple MB) and will blow the context
window. Where only a full file exists, route a specific product sub-URL through
Firecrawl / `WebFetch`, not the aggregate.

| Topic keywords                          | Index (cheap, load first)              | Full (deep link only)                            | Fetch discipline                                              |
| --------------------------------------- | -------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| firecrawl, scrape API, crawl, extract   | https://docs.firecrawl.dev/llms.txt    | https://docs.firecrawl.dev/llms-full.txt         | Prefer the `scrape` skill. Index → one endpoint page. Never inline the full dump. `WebFetch` hangs on this host — use `curl`. |
| cloudflare tunnel, zero trust, dns, waf | (no small index published)             | https://developers.cloudflare.com/llms-full.txt  | Prefer the `cloudflare-one` skill. If routed here, Firecrawl / `WebFetch` a specific product sub-URL, not the aggregate. |
| privacy tooling, threat model           | https://www.privacyguides.org/llms.txt | —                                                | Index is sufficient.                                         |

As you learn specific product sub-paths, add them here so future fetches skip
the aggregate entirely.

## Known sub-paths

Append `.md` to any Firecrawl docs URL to get the markdown source directly.

| Topic | URL |
| --- | --- |
| firecrawl v2 API intro, base URL, auth | https://docs.firecrawl.dev/api-reference/v2-introduction.md |
| firecrawl scrape options and formats | https://docs.firecrawl.dev/api-reference/endpoint/scrape.md |
| firecrawl crawl options | https://docs.firecrawl.dev/api-reference/endpoint/crawl-post.md |
| firecrawl crawl status / polling | https://docs.firecrawl.dev/api-reference/endpoint/crawl-get.md |
| firecrawl map | https://docs.firecrawl.dev/api-reference/endpoint/map.md |
| firecrawl batch scrape | https://docs.firecrawl.dev/api-reference/endpoint/batch-scrape.md |
| firecrawl search | https://docs.firecrawl.dev/api-reference/endpoint/search.md |
| firecrawl errors and retry guidance | https://docs.firecrawl.dev/api-reference/errors.md |
| firecrawl self-hosting limits | https://docs.firecrawl.dev/contributing/self-host.md |
| firecrawl CLI | https://docs.firecrawl.dev/sdks/cli.md |
| firecrawl MCP server (local / self-hosted) | https://docs.firecrawl.dev/mcp-server/local.md |
