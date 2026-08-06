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
| firecrawl, scrape API, crawl, extract   | https://docs.firecrawl.dev/llms.txt    | https://docs.firecrawl.dev/llms-full.txt         | Index → one endpoint page. Never inline the full dump.        |
| cloudflare tunnel, zero trust, dns, waf | (no small index published)             | https://developers.cloudflare.com/llms-full.txt  | Prefer the `cloudflare-one` skill. If routed here, Firecrawl / `WebFetch` a specific product sub-URL, not the aggregate. |
| privacy tooling, threat model           | https://www.privacyguides.org/llms.txt | —                                                | Index is sufficient.                                         |

As you learn specific product sub-paths, add them here so future fetches skip
the aggregate entirely.
