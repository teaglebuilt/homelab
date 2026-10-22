# Authentication and Authorization

> **Relevant source files**
> * [apps/api/src/__tests__/routes/auth-retry-after.routes.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/routes/auth-retry-after.routes.test.ts)
> * [apps/api/src/__tests__/routes/check-credits-middleware.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/routes/check-credits-middleware.test.ts)
> * [apps/api/src/__tests__/snips/v2/auth-denied.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/v2/auth-denied.test.ts)
> * [apps/api/src/__tests__/snips/v2/keyless.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/v2/keyless.test.ts)
> * [apps/api/src/__tests__/snips/v2/research.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/snips/v2/research.test.ts)
> * [apps/api/src/controllers/__tests__/auth.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/__tests__/auth.test.ts)
> * [apps/api/src/controllers/auth.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts)
> * [apps/api/src/controllers/v2/__tests__/research-timeouts.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/__tests__/research-timeouts.test.ts)
> * [apps/api/src/controllers/v2/research-proxy.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/v2/research-proxy.ts)
> * [apps/api/src/lib/__tests__/keyless-usage-log.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/__tests__/keyless-usage-log.test.ts)
> * [apps/api/src/lib/__tests__/spur.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/__tests__/spur.test.ts)
> * [apps/api/src/lib/auth-denied-log.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/auth-denied-log.ts)
> * [apps/api/src/lib/keyless-metrics.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless-metrics.ts)
> * [apps/api/src/lib/keyless.conversion.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.conversion.test.ts)
> * [apps/api/src/lib/keyless.signup-prompt.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.signup-prompt.test.ts)
> * [apps/api/src/lib/keyless.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.ts)
> * [apps/api/src/lib/research-upstream.test.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/research-upstream.test.ts)
> * [apps/api/src/lib/research-upstream.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/research-upstream.ts)
> * [apps/api/src/lib/spur.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/spur.ts)
> * [apps/api/src/routes/shared.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts)
> * [apps/api/src/routes/v1.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/v1.ts)
> * [apps/api/src/routes/v2.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/v2.ts)
> * [apps/api/src/services/billing/credit_billing.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/services/billing/credit_billing.ts)
> * [apps/api/src/services/rate-limiter.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/services/rate-limiter.ts)
> * [apps/api/src/services/spur-redis.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/services/spur-redis.ts)
> * [apps/api/src/types.ts](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/types.ts)

This page details the authentication flow, API key formats, AuthCreditUsageChunk (ACUC) structure, keyless free tier, rate limiting, and permission system in Firecrawl.

## Overview

The authentication and authorization system in Firecrawl validates inbound requests across the REST API, manages team identities, enforces credit balances and rate limits via **Autumn**, and handles specialized access modes such as OAuth tokens, preview tokens, and keyless free-tier usage [apps/api/src/controllers/auth.ts L1-L53](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L1-L53)

 [apps/api/src/routes/shared.ts L36-L160](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L36-L160)

Sources: [apps/api/src/controllers/auth.ts L1-L53](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L1-L53)

 [apps/api/src/routes/shared.ts L36-L160](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L36-L160)

## Authentication Flow

Requests to protected v1 and v2 routes pass through `authMiddleware`, which invokes `authenticateUser` to resolve credentials, evaluate team status, and attach the authorization context (`req.auth` and `req.acuc`) [apps/api/src/routes/shared.ts L10](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L10-L10)

 [apps/api/src/types.ts L168-L189](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/types.ts#L168-L189)

Title: Firecrawl Authentication and Authorization Sequence

```

```

Sources: [apps/api/src/controllers/auth.ts L1-L209](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L1-L209)

 [apps/api/src/routes/shared.ts L36-L160](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L36-L160)

 [apps/api/src/services/autumn/autumn.service.ts L1-L50](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/services/autumn/autumn.service.ts#L1-L50)

## API Key Formats and Token Resolution

Firecrawl normalizes and authenticates several credential types:

* **Standard API Keys**: Prefixed with `fc-` followed by a unique identifier or UUID [apps/api/src/controllers/auth.ts L102-L105](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L102-L105)
* **OAuth Tokens**: Prefixed with `fco_`. These are resolved to the underlying API key via the `resolveOAuthToken` introspection service, caching results in Redis up to 5 minutes [apps/api/src/controllers/auth.ts L177-L197](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L177-L197)
* **MCP Delegated Credentials**: Prefixed with `fcmcp_` and verified via `verifyMcpDelegatedCredential` using HMAC signatures [apps/api/src/controllers/auth.ts L48](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L48-L48)
* **Preview Tokens**: Mapped to a mock ACUC for playground or unauthenticated preview environments [apps/api/src/controllers/auth.ts L147-L159](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L147-L159)

Sources: [apps/api/src/controllers/auth.ts L48](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L48-L48)

 [apps/api/src/controllers/auth.ts L102-L105](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L102-L105)

 [apps/api/src/controllers/auth.ts L147-L197](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L147-L197)

## Keyless Free Tier

For selected endpoints (e.g., `/scrape`, `/search`), Firecrawl provides a keyless tier for official SDKs, CLI, and MCP servers without an explicit API key [apps/api/src/lib/keyless.ts L23-L28](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.ts#L23-L28)

* **Eligibility**: Gated per-IP using IPv4 addresses (`isKeylessIpEligible`) and filtered against suspicious reputation via Spur (`isKeylessIpSuspicious`) [apps/api/src/controllers/auth.ts L27](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L27-L27)  [apps/api/src/lib/keyless.ts L137-L139](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.ts#L137-L139)
* **Quotas**: Enforced via daily request counts (`keyless_requests:*`) and daily credit limits (`keyless_credits:*`) stored in Redis [apps/api/src/lib/keyless.ts L141-L152](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.ts#L141-L152)
* **Team Simulation**: Keyless requests execute under a synthetic team ID prefix `preview_keyless_<ip>`, mapping to a deterministic UUID via `keylessTeamUuid` [apps/api/src/lib/keyless.ts L97-L125](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.ts#L97-L125)

Sources: [apps/api/src/controllers/auth.ts L27](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L27-L27)

 [apps/api/src/lib/keyless.ts L23-L152](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/lib/keyless.ts#L23-L152)

## AuthCreditUsageChunk (ACUC) Structure and Caching

The `AuthCreditUsageChunk` (ACUC) structure carries tenant metadata, permissions, limits, and feature flags [apps/api/src/controllers/auth.ts L35-L41](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L35-L41)

Title: ACUC Code Entity Mapping

```sql
#mermaid-5kgbcac46dc{font-family:ui-sans-serif,-apple-system,system-ui,Segoe UI,Helvetica;font-size:16px;fill:#333;}@keyframes edge-animation-frame{from{stroke-dashoffset:0;}}@keyframes dash{to{stroke-dashoffset:0;}}#mermaid-5kgbcac46dc .edge-animation-slow{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 50s linear infinite;stroke-linecap:round;}#mermaid-5kgbcac46dc .edge-animation-fast{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 20s linear infinite;stroke-linecap:round;}#mermaid-5kgbcac46dc .error-icon{fill:#dddddd;}#mermaid-5kgbcac46dc .error-text{fill:#222222;stroke:#222222;}#mermaid-5kgbcac46dc .edge-thickness-normal{stroke-width:1px;}#mermaid-5kgbcac46dc .edge-thickness-thick{stroke-width:3.5px;}#mermaid-5kgbcac46dc .edge-pattern-solid{stroke-dasharray:0;}#mermaid-5kgbcac46dc .edge-thickness-invisible{stroke-width:0;fill:none;}#mermaid-5kgbcac46dc .edge-pattern-dashed{stroke-dasharray:3;}#mermaid-5kgbcac46dc .edge-pattern-dotted{stroke-dasharray:2;}#mermaid-5kgbcac46dc .marker{fill:#999;stroke:#999;}#mermaid-5kgbcac46dc .marker.cross{stroke:#999;}#mermaid-5kgbcac46dc svg{font-family:ui-sans-serif,-apple-system,system-ui,Segoe UI,Helvetica;font-size:16px;}#mermaid-5kgbcac46dc p{margin:0;}#mermaid-5kgbcac46dc g.classGroup text{fill:#dddddd;stroke:none;font-family:ui-sans-serif,-apple-system,system-ui,Segoe UI,Helvetica;font-size:10px;}#mermaid-5kgbcac46dc g.classGroup text .title{font-weight:bolder;}#mermaid-5kgbcac46dc .cluster-label text{fill:#444;}#mermaid-5kgbcac46dc .cluster-label span{color:#444;}#mermaid-5kgbcac46dc .cluster-label span p{background-color:transparent;}#mermaid-5kgbcac46dc .cluster rect{fill:#f8f8f8;stroke:#dddddd;stroke-width:1px;}#mermaid-5kgbcac46dc .cluster text{fill:#444;}#mermaid-5kgbcac46dc .cluster span{color:#444;}#mermaid-5kgbcac46dc .nodeLabel,#mermaid-5kgbcac46dc .edgeLabel{color:#333333;}#mermaid-5kgbcac46dc .noteLabel .nodeLabel,#mermaid-5kgbcac46dc .noteLabel .edgeLabel{color:#333;}#mermaid-5kgbcac46dc .edgeLabel .label rect{fill:#ffffff;}#mermaid-5kgbcac46dc .label text{fill:#333333;}#mermaid-5kgbcac46dc .labelBkg{background:#ffffff;}#mermaid-5kgbcac46dc .edgeLabel .label span{background:#ffffff;}#mermaid-5kgbcac46dc .classTitle{font-weight:bolder;}#mermaid-5kgbcac46dc .node rect,#mermaid-5kgbcac46dc .node circle,#mermaid-5kgbcac46dc .node ellipse,#mermaid-5kgbcac46dc .node polygon,#mermaid-5kgbcac46dc .node path{fill:#ffffff;stroke:#dddddd;stroke-width:1;}#mermaid-5kgbcac46dc .divider{stroke:#dddddd;stroke-width:1;}#mermaid-5kgbcac46dc g.clickable{cursor:pointer;}#mermaid-5kgbcac46dc g.classGroup rect{fill:#ffffff;stroke:#dddddd;}#mermaid-5kgbcac46dc g.classGroup line{stroke:#dddddd;stroke-width:1;}#mermaid-5kgbcac46dc .classLabel .box{stroke:none;stroke-width:0;fill:#ffffff;opacity:0.5;}#mermaid-5kgbcac46dc .classLabel .label{fill:#dddddd;font-size:10px;}#mermaid-5kgbcac46dc .relation{stroke:#999;stroke-width:1;fill:none;}#mermaid-5kgbcac46dc .dashed-line{stroke-dasharray:3;}#mermaid-5kgbcac46dc .dotted-line{stroke-dasharray:1 2;}#mermaid-5kgbcac46dc [id$="-compositionStart"],#mermaid-5kgbcac46dc .composition{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-compositionEnd"],#mermaid-5kgbcac46dc .composition{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-dependencyStart"],#mermaid-5kgbcac46dc .dependency{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-dependencyEnd"],#mermaid-5kgbcac46dc .dependency{fill:#999!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-extensionStart"],#mermaid-5kgbcac46dc .extension{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-extensionEnd"],#mermaid-5kgbcac46dc .extension{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-aggregationStart"],#mermaid-5kgbcac46dc .aggregation{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-aggregationEnd"],#mermaid-5kgbcac46dc .aggregation{fill:transparent!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-lollipopStart"],#mermaid-5kgbcac46dc .lollipop{fill:#ffffff!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc [id$="-lollipopEnd"],#mermaid-5kgbcac46dc .lollipop{fill:#ffffff!important;stroke:#999!important;stroke-width:1;}#mermaid-5kgbcac46dc .edgeTerminals{font-size:11px;line-height:initial;}#mermaid-5kgbcac46dc .classTitleText{text-anchor:middle;font-size:18px;fill:#333;}#mermaid-5kgbcac46dc .edgeLabel[data-look="neo"]{background-color:#ffffff;text-align:center;}#mermaid-5kgbcac46dc .edgeLabel[data-look="neo"] p{background-color:#ffffff;}#mermaid-5kgbcac46dc .edgeLabel[data-look="neo"] rect{opacity:0.5;background-color:#ffffff;fill:#ffffff;}#mermaid-5kgbcac46dc .label-icon{display:inline-block;height:1em;overflow:visible;vertical-align:-0.125em;}#mermaid-5kgbcac46dc .node .label-icon path{fill:currentColor;stroke:revert;stroke-width:revert;}#mermaid-5kgbcac46dc .node .neo-node{stroke:#dddddd;}#mermaid-5kgbcac46dc [data-look="neo"].node rect,#mermaid-5kgbcac46dc [data-look="neo"].cluster rect,#mermaid-5kgbcac46dc [data-look="neo"].node polygon{stroke:url(#mermaid-5kgbcac46dc-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-5kgbcac46dc [data-look="neo"].swimlane.cluster rect{filter:none;}#mermaid-5kgbcac46dc [data-look="neo"].node path{stroke:url(#mermaid-5kgbcac46dc-gradient);stroke-width:1px;}#mermaid-5kgbcac46dc [data-look="neo"].node .outer-path{filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-5kgbcac46dc [data-look="neo"].node .neo-line path{stroke:#dddddd;filter:none;}#mermaid-5kgbcac46dc [data-look="neo"].node circle{stroke:url(#mermaid-5kgbcac46dc-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-5kgbcac46dc [data-look="neo"].node circle .state-start{fill:#000000;}#mermaid-5kgbcac46dc [data-look="neo"].icon-shape .icon{fill:url(#mermaid-5kgbcac46dc-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-5kgbcac46dc [data-look="neo"].icon-shape .icon-neo path{stroke:url(#mermaid-5kgbcac46dc-gradient);filter:drop-shadow( 1px 2px 2px rgba(185,185,185,1));}#mermaid-5kgbcac46dc .nodeLabel p,#mermaid-5kgbcac46dc .edgeLabel p{color:inherit;}#mermaid-5kgbcac46dc :root{--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif;}AuthCreditUsageChunk+string team_id+number api_key_id+string org_id+TeamFlags flags+boolean is_banned+boolean is_extract+AgentSponsor _agentSponsorTeamFlags+boolean bypassCreditChecks+string scrapeZDR+string searchZDR+boolean ipWhitelist
```

* **Caching**: ACUC chunks are cached in Redis under `acuc_${credentialPurpose}_${api_key}_${mode}` with a 600-second TTL, protected against concurrent stampedes using Redlock (`redlock.using`) [apps/api/src/controllers/auth.ts L56-L145](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L56-L145)
* **Fail-Open Policy**: If Autumn is unreachable when resolving team limits (`readTeamLimits`), the system falls back to `FAIL_OPEN_LIMITS` (concurrency limit 200, rate limit multiplier 2500) with a shortened 60-second TTL [apps/api/src/controllers/auth.ts L59-L83](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L59-L83)

Sources: [apps/api/src/controllers/auth.ts L35-L145](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L35-L145)

 [apps/api/src/types.ts L8](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/types.ts#L8-L8)

## Permission System and Restrictions

Before granting access, the middleware layers enforce granular security constraints:

* **IP Restrictions**: `checkIpRestriction` validates inbound client IPs against team allowlists [apps/api/src/controllers/auth.ts L29](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L29-L29)
* **Key-Endpoint Restrictions**: `checkKeyEndpointRestriction` ensures API keys are authorized for specific paths [apps/api/src/controllers/auth.ts L30](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L30-L30)
* **Agent Sponsorship**: AI-agent provisioned keys check sponsor status (`getAgentSponsorStatus`). Unverified agent keys enforce a strict 50-credit limit and force index-only operation [apps/api/src/routes/shared.ts L65-L124](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L65-L124)

Sources: [apps/api/src/controllers/auth.ts L29-L30](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/controllers/auth.ts#L29-L30)

 [apps/api/src/routes/shared.ts L65-L124](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L65-L124)

## Rate Limiting and Credit Checks

Rate limits are enforced per minute via `rate-limiter-flexible` and Redis [apps/api/src/services/rate-limiter.ts L1-L17](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/services/rate-limiter.ts#L1-L17)

| Mode | Base Limit (RPM) | Scalable |
| --- | --- | --- |
| `scrape` | 10 | Yes (Multiplier) |
| `crawl` | 2 | Yes (Multiplier) |
| `search` | 10 | Yes (Multiplier) |
| `extract` | 2 | Yes (Multiplier) |
| `crawlStatus` | 500 | Yes (Multiplier) |

* **Autumn Rate Limit Multipliers**: Authenticated teams calculate effective limits via `getAutumnRateLimiter(mode, multiplier, flags)`, scaling base rates by the team's Autumn plan multiplier [apps/api/src/services/rate-limiter.ts L112-L132](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/services/rate-limiter.ts#L112-L132)
* **Credit Validation**: `checkCreditsMiddleware` queries `autumnService.checkCredits` to ensure balance availability before job submission, clamping job limits downwards if remaining credits are insufficient [apps/api/src/routes/shared.ts L46-L168](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L46-L168)  [apps/api/src/__tests__/routes/check-credits-middleware.test.ts L102-L192](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/routes/check-credits-middleware.test.ts#L102-L192)

Sources: [apps/api/src/services/rate-limiter.ts L1-L132](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/services/rate-limiter.ts#L1-L132)

 [apps/api/src/routes/shared.ts L46-L168](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/routes/shared.ts#L46-L168)

 [apps/api/src/__tests__/routes/check-credits-middleware.test.ts L102-L192](https://github.com/firecrawl/firecrawl/blob/f84845c8/apps/api/src/__tests__/routes/check-credits-middleware.test.ts#L102-L192)
