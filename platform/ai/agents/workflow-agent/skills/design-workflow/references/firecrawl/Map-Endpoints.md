# Map Endpoints

> **Relevant source files**
> * [apps/api/.husky/pre-commit](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/.husky/pre-commit)
> * [apps/api/native/src/crawler.rs](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/native/src/crawler.rs)
> * [apps/api/src/__tests__/snips/mocks/map-sitemap-all-urls.json](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/mocks/map-sitemap-all-urls.json)
> * [apps/api/src/__tests__/snips/mocks/map-sitemap-deeply-nested-only.json](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/mocks/map-sitemap-deeply-nested-only.json)
> * [apps/api/src/__tests__/snips/mocks/map-sitemap-deeply-nested.json](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/mocks/map-sitemap-deeply-nested.json)
> * [apps/api/src/__tests__/snips/v1/map.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/v1/map.test.ts)
> * [apps/api/src/__tests__/snips/v2/map.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/v2/map.test.ts)
> * [apps/api/src/controllers/v1/extract.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v1/extract.ts)
> * [apps/api/src/controllers/v1/map.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v1/map.ts)
> * [apps/api/src/controllers/v1/types.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v1/types.ts)
> * [apps/api/src/controllers/v2/__tests__/crawl-prompt-zdr.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/__tests__/crawl-prompt-zdr.test.ts)
> * [apps/api/src/controllers/v2/agent.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/agent.ts)
> * [apps/api/src/controllers/v2/crawl-params-preview.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/crawl-params-preview.ts)
> * [apps/api/src/controllers/v2/extract.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/extract.ts)
> * [apps/api/src/controllers/v2/map.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts)
> * [apps/api/src/controllers/v2/types.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/types.ts)
> * [apps/api/src/lib/__tests__/url-utils.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/__tests__/url-utils.test.ts)
> * [apps/api/src/lib/map-utils.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts)
> * [apps/api/src/lib/otel-tracer.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/otel-tracer.ts)
> * [apps/api/src/lib/request-credits-store.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/request-credits-store.test.ts)
> * [apps/api/src/lib/request-credits-store.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/request-credits-store.ts)
> * [apps/api/src/lib/url-utils.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/url-utils.ts)
> * [apps/js-sdk/firecrawl/src/index.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/js-sdk/firecrawl/src/index.ts)
> * [apps/js-sdk/firecrawl/src/v2/methods/agent.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/js-sdk/firecrawl/src/v2/methods/agent.ts)
> * [apps/python-sdk/firecrawl/v2/methods/agent.py](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/python-sdk/firecrawl/v2/methods/agent.py)
> * [apps/python-sdk/firecrawl/v2/methods/aio/agent.py](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/python-sdk/firecrawl/v2/methods/aio/agent.py)

## Purpose and Scope

The `/map` endpoints are designed for high-performance URL discovery, sitemap parsing, and link filtering across target websites without executing full page scrapers or heavy DOM extraction. They power site structure analysis, crawl planning, and natural language parameter generation.

**Sources**: [apps/api/src/controllers/v2/map.ts L32-L35](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L32-L35)

 [apps/api/src/lib/map-utils.ts L83-L122](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L83-L122)

---

## API Versions

### v1 Map Endpoint

`POST /v1/map`
Maintains backward compatibility by returning a flat array of URL strings alongside request metadata.
**Response Format**: [apps/api/src/controllers/v1/types.ts L1148-L1154](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v1/types.ts#L1148-L1154)

### v2 Map Endpoint

`POST /v2/map`
Returns structured `MapDocument` objects containing the discovered URL along with optional metadata like page titles and descriptions.
**Response Format**: [apps/api/src/controllers/v2/types.ts L1013-L1024](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/types.ts#L1013-L1024)

**Sources**: [apps/api/src/controllers/v1/map.ts L12-L55](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v1/map.ts#L12-L55)

 [apps/api/src/controllers/v2/map.ts L32-L207](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L32-L207)

---

## Request Schema and Validation

Requests are validated using Zod schemas (`mapRequestSchema`) defined in the controllers. Common parameters include:

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `url` | `string` | **required** | Target root URL to map [apps/api/src/controllers/v2/types.ts L36-L85](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/types.ts#L36-L85) |
| `search` | `string` | `undefined` | Optional search query to filter and rank discovered URLs via cosine similarity [apps/api/src/lib/map-utils.ts L316-L321](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L316-L321) |
| `limit` | `number` | `5000` | Maximum number of URLs to return [apps/api/src/controllers/v1/types.ts L942-L961](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v1/types.ts#L942-L961) |
| `includeSubdomains` | `boolean` | `true` | Whether to include subdomains in discovery results [apps/api/src/lib/map-utils.ts L86](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L86-L86) |
| `sitemap` | `string` | `"include"` | Sitemap handling strategy (`"skip"`, `"include"`, `"only"`) [apps/api/src/controllers/v2/types.ts L960-L981](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/types.ts#L960-L981) |
| `useIndex` | `boolean` | `true` | Query the Supabase index cache for previously discovered URLs [apps/api/src/lib/map-utils.ts L94](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L94-L94) |
| `ignoreCache` | `boolean` | `false` | Skip Redis cache retrieval for search/Fire Engine outputs [apps/api/src/lib/map-utils.ts L95](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L95-L95) |

**Sources**: [apps/api/src/controllers/v2/types.ts L960-L1013](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/types.ts#L960-L1013)

 [apps/api/src/lib/map-utils.ts L83-L122](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L83-L122)

---

## URL Discovery Flow

The following diagram illustrates how incoming requests pass through `mapController`, hit specialized resolvers (`resolveViaAvgrab`), or fall back to the multi-strategy `getMapResults` orchestrator.

Title: "Map Request Execution and Discovery Flow"

```mermaid
flowchart TD

mermaid-2z8okny2zsy-flowchart-Req["POST /v2/map"]
mermaid-2z8okny2zsy-flowchart-Parse["mapRequestSchema.parse()"]
mermaid-2z8okny2zsy-flowchart-CheckSafe["resolveSafeMode()"]
mermaid-2z8okny2zsy-flowchart-Avgrab["resolveViaAvgrab()"]
mermaid-2z8okny2zsy-flowchart-AvSvc["Avgrab Service"]
mermaid-2z8okny2zsy-flowchart-BillAv["billTeam()"]
mermaid-2z8okny2zsy-flowchart-RespAv["Return MapResponse"]
mermaid-2z8okny2zsy-flowchart-Orchestrator["getMapResults()"]
mermaid-2z8okny2zsy-flowchart-Index["queryIndex()<br>Supabase Index Cache"]
mermaid-2z8okny2zsy-flowchart-Search["fireEngineMap()<br>Search Discovery"]
mermaid-2z8okny2zsy-flowchart-Sitemap["crawler.tryGetSitemap()<br>Sitemap XML Parser"]
mermaid-2z8okny2zsy-flowchart-Merge["dedupeMapDocumentArray()"]
mermaid-2z8okny2zsy-flowchart-Rank["search query present?"]
mermaid-2z8okny2zsy-flowchart-Cosine["performCosineSimilarityV2()"]
mermaid-2z8okny2zsy-flowchart-Filter["Path & Domain Validation"]
mermaid-2z8okny2zsy-flowchart-Bill["billTeam()"]
mermaid-2z8okny2zsy-flowchart-Log["logMap() & logRequest()"]
mermaid-2z8okny2zsy-flowchart-Resp["Return MapResponse"]
```

**Sources**: [apps/api/src/controllers/v2/map.ts L32-L207](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L32-L207)

 [apps/api/src/lib/map-utils.ts L83-L250](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L83-L250)

---

## Discovery Methods

1. **Specialized Resolvers (`resolveViaAvgrab`)**: Bypasses standard site crawling for recognized pattern URLs (e.g., social media profile trees) [apps/api/src/controllers/v2/map.ts L132-L187](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L132-L187)
2. **Index Cache Query (`queryIndex`)**: Queries domain splits against internal storage via `queryIndexAtDomainSplitLevelWithMeta` and `queryIndexAtSplitLevelWithMeta` [apps/api/src/lib/map-utils.ts L54-L81](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L54-L81)
3. **Sitemap Parsing**: Instantiates a crawler via `crawlToCrawler` to inspect `robots.txt` and parse XML sitemaps [apps/api/src/lib/map-utils.ts L166-L191](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L166-L191)
4. **Search-Based Discovery (`fireEngineMap`)**: Executes targeted search queries (`site:url`) with results cached in Redis via `redisEvictConnection` [apps/api/src/lib/map-utils.ts L227-L235](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L227-L235)

**Sources**: [apps/api/src/controllers/v2/map.ts L132-L187](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L132-L187)

 [apps/api/src/lib/map-utils.ts L54-L235](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L54-L235)

---

## Ranking, Filtering, and Deduplication

Discovered documents undergo rigorous normalization and deduplication through distinct utility modules.

Title: "Code Entity Space for Ranking and Filtering"

```sql
#mermaid-bnseeqncjx{font-family:ui-sans-serif,-apple-system,system-ui,Segoe UI,Helvetica;font-size:16px;fill:#333;}@keyframes edge-animation-frame{from{stroke-dashoffset:0;}}@keyframes dash{to{stroke-dashoffset:0;}}#mermaid-bnseeqncjx .edge-animation-slow{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 50s linear infinite;stroke-linecap:round;}#mermaid-bnseeqncjx .edge-animation-fast{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 20s linear infinite;stroke-linecap:round;}#mermaid-bnseeqncjx .error-icon{fill:#dddddd;}#mermaid-bnseeqncjx .error-text{fill:#222222;stroke:#222222;}#mermaid-bnseeqncjx .edge-thickness-normal{stroke-width:1px;}#mermaid-bnseeqncjx .edge-thickness-thick{stroke-width:3.5px;}#mermaid-bnseeqncjx .edge-pattern-solid{stroke-dasharray:0;}#mermaid-bnseeqncjx .edge-thickness-invisible{stroke-width:0;fill:none;}#mermaid-bnseeqncjx .edge-pattern-dashed{stroke-dasharray:3;}#mermaid-bnseeqncjx .edge-pattern-dotted{stroke-dasharray:2;}#mermaid-bnseeqncjx .marker{fill:#999;stroke:#999;}#mermaid-bnseeqncjx .marker.cross{stroke:#999;}#mermaid-bnseeqncjx svg{font-family:ui-sans-serif,-apple-system,system-ui,Segoe UI,Helvetica;font-size:16px;}#mermaid-bnseeqncjx p{margin:0;}#mermaid-bnseeqncjx g.classGroup text{fill:#dddddd;stroke:none;font-family:ui-sans-serif,-apple-system,system-ui,Segoe UI,Helvetica;font-size:10px;}#mermaid-bnseeqncjx g.classGroup text .title{font-weight:bolder;}#mermaid-bnseeqncjx .cluster-label text{fill:#444;}#mermaid-bnseeqncjx .cluster-label span{color:#444;}#mermaid-bnseeqncjx .cluster-label span p{background-color:transparent;}#mermaid-bnseeqncjx .cluster rect{fill:#f8f8f8;stroke:#dddddd;stroke-width:1px;}#mermaid-bnseeqncjx .cluster text{fill:#444;}#mermaid-bnseeqncjx .cluster span{color:#444;}#mermaid-bnseeqncjx .nodeLabel,#mermaid-bnseeqncjx .edgeLabel{color:#333333;}#mermaid-bnseeqncjx .noteLabel .nodeLabel,#mermaid-bnseeqncjx .noteLabel .edgeLabel{color:#333;}#mermaid-bnseeqncjx .edgeLabel .label rect{fill:#ffffff;}#mermaid-bnseeqncjx .label text{fill:#333333;}#mermaid-bnseeqncjx .labelBkg{background:#ffffff;}#mermaid-bnseeqncjx .edgeLabel .label span{background:#ffffff;}#mermaid-bnseeqncjx .classTitle{font-weight:bolder;}#mermaid-bnseeqncjx .node rect,#mermaid-bnseeqncjx .node circle,#mermaid-bnseeqncjx .node ellipse,#mermaid-bnseeqncjx .node polygon,#mermaid-bnseeqncjx .node path{fill:#ffffff;stroke:#dddddd;stroke-width:1;}#mermaid-bnseeqncjx .divider{stroke:#dddddd;stroke-width:1;}#mermaid-bnseeqncjx g.clickable{cursor:pointer;}#mermaid-bnseeqncjx g.classGroup rect{fill:#ffffff;stroke:#dddddd;}#mermaid-bnseeqncjx g.classGroup line{stroke:#dddddd;stroke-width:1;}#mermaid-bnseeqncjx .classLabel .box{stroke:none;stroke-width:0;fill:#ffffff;opacity:0.5;}#mermaid-bnseeqncjx .classLabel .label{fill:#dddddd;font-size:10px;}#mermaid-bnseeqncjx .relation{stroke:#999;stroke-width:1;fill:none;}#mermaid-bnseeqncjx .dashed-line{stroke-dasharray:3;}#mermaid-bnseeqncjx .dotted-line{stroke-dasharray:1 2;}#mermaid-bnseeqncjx [id$="-compositionStart"],#mermaid-bnseeqncjx .composition{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-compositionEnd"],#mermaid-bnseeqncjx .composition{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-dependencyStart"],#mermaid-bnseeqncjx .dependency{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-dependencyEnd"],#mermaid-bnseeqncjx .dependency{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-extensionStart"],#mermaid-bnseeqncjx .extension{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-extensionEnd"],#mermaid-bnseeqncjx .extension{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-aggregationStart"],#mermaid-bnseeqncjx .aggregation{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-aggregationEnd"],#mermaid-bnseeqncjx .aggregation{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-lollipopStart"],#mermaid-bnseeqncjx .lollipop{fill:#ffffff!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx [id$="-lollipopEnd"],#mermaid-bnseeqncjx .lollipop{fill:#ffffff!important;stroke:#999!important;stroke-width:1;}#mermaid-bnseeqncjx .edgeTerminals{font-size:11px;line-height:initial;}#mermaid-bnseeqncjx .classTitleText{text-anchor:middle;font-size:18px;fill:#333;}#mermaid-bnseeqncjx .edgeLabel[data-look="neo"]{background-color:#ffffff;text-align:center;}#mermaid-bnseeqncjx .edgeLabel[data-look="neo"] p{background-color:#ffffff;}#mermaid-bnseeqncjx .edgeLabel[data-look="neo"] rect{opacity:0.5;background-color:#ffffff;fill:#ffffff;}#mermaid-bnseeqncjx .label-icon{display:inline-block;height:1em;overflow:visible;vertical-align:-0.125em;}#mermaid-bnseeqncjx .node .label-icon path{fill:currentColor;stroke:revert;stroke-width:revert;}#mermaid-bnseeqncjx .node .neo-node{stroke:#dddddd;}#mermaid-bnseeqncjx [data-look="neo"].node rect,#mermaid-bnseeqncjx [data-look="neo"].cluster rect,#mermaid-bnseeqncjx [data-look="neo"].node polygon{stroke:url(#mermaid-bnseeqncjx-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-bnseeqncjx [data-look="neo"].swimlane.cluster rect{filter:none;}#mermaid-bnseeqncjx [data-look="neo"].node path{stroke:url(#mermaid-bnseeqncjx-gradient);stroke-width:1px;}#mermaid-bnseeqncjx [data-look="neo"].node .outer-path{filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-bnseeqncjx [data-look="neo"].node .neo-line path{stroke:#dddddd;filter:none;}#mermaid-bnseeqncjx [data-look="neo"].node circle{stroke:url(#mermaid-bnseeqncjx-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-bnseeqncjx [data-look="neo"].node circle .state-start{fill:#000000;}#mermaid-bnseeqncjx [data-look="neo"].icon-shape .icon{fill:url(#mermaid-bnseeqncjx-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-bnseeqncjx [data-look="neo"].icon-shape .icon-neo path{stroke:url(#mermaid-bnseeqncjx-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-bnseeqncjx .nodeLabel p,#mermaid-bnseeqncjx .edgeLabel p{color:inherit;}#mermaid-bnseeqncjx :root{--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif;}invokescleans duplicatesranks by searchenforces scopemapController+mapController(req, res)getMapResults+getMapResults(options) : MapResultdedupeMapDocumentArray+dedupeMapDocumentArray(documents) : MapDocument[]performCosineSimilarityV2+performCosineSimilarityV2(docs, query) : MapDocument[]validateUrl+checkAndUpdateURLForMap(url)+isSameDomain(url, resolved)+isSameSubdomain(url, base)
```

**Sources**: [apps/api/src/controllers/v2/map.ts L32-L207](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L32-L207)

 [apps/api/src/lib/map-utils.ts L38-L81](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-utils.ts#L38-L81)

 [apps/api/src/lib/map-cosine.ts L1-L10](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/map-cosine.ts#L1-L10)

 [apps/api/src/lib/validateUrl.ts L12-L19](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/validateUrl.ts#L12-L19)

---

## Natural Language Parameter Preview

The `crawlParamsPreviewController` uses map capabilities to inspect website structures (`buildPromptWithWebsiteStructure`) and feed discovered links into an LLM via `generateCrawlerOptionsFromPrompt` [apps/api/src/controllers/v2/crawl-params-preview.ts L47-L135](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/crawl-params-preview.ts#L47-L135)

**Sources**: [apps/api/src/controllers/v2/crawl-params-preview.ts L47-L135](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/crawl-params-preview.ts#L47-L135)

---

## Billing, Safety, and Logging

* **Billing**: Successful requests trigger `billTeam` with credit metering [apps/api/src/controllers/v2/map.ts L140-L153](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L140-L153)
* **Safe Mode & ZDR**: Zero Data Retention (`zeroDataRetention`) and Safe Mode lockdown rules enforce cache-only index lookups without outbound web requests [apps/api/src/controllers/v2/map.ts L36-L77](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L36-L77)
* **Audit Logging**: Jobs are recorded via `logMap` and `logRequest` [apps/api/src/controllers/v2/map.ts L116-L127](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L116-L127)  [apps/api/src/controllers/v2/map.ts L159-L180](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L159-L180)

**Sources**: [apps/api/src/controllers/v2/map.ts L36-L180](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/map.ts#L36-L180)
