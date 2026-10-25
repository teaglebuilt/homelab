---
name: tempo
description: >
  Tempo distributed traces and TraceQL for the homelab. Use to find slow or
  failing requests, inspect spans, map service dependencies, expand a known
  trace_id, or answer where in a request path time is spent. Carries the
  datasource-proxy access pattern (there is no Tempo tool), TraceQL syntax, and
  the span-metrics shortcut in Prometheus.
---

# Tempo and TraceQL for the homelab

## How you reach Tempo

**There is no dedicated Tempo tool in mcp-grafana.** You reach Tempo through
Grafana's datasource proxy with `grafana_api_request`, which passes a path
straight through to Tempo's HTTP API. The datasource UID is `tempo`, so every
call is prefixed:

```
/api/datasources/proxy/uid/tempo
```

Appended to that prefix:

| Purpose | Path |
| --- | --- |
| Search by TraceQL | `/api/search?q=<traceql>&start=<unix>&end=<unix>&limit=20` |
| Fetch one trace, every span | `/api/traces/<traceID>` |
| Discover attributes | `/api/v2/search/tags` |
| Values for one attribute | `/api/v2/search/tag/<scope>.<name>/values` |
| TraceQL metrics over a range | `/api/metrics/query_range?q=<traceql>&start=<unix>&end=<unix>&step=1m` |

`start` and `end` are Unix **seconds**. Call `datetime_get_current_time` first
rather than assuming the clock.

URL-encode the query: `{` is `%7B`, `}` is `%7D`, `"` is `%22`, space is `%20`,
`>` is `%3E`.

Multitenancy is off, so send no `X-Scope-OrgID`.

## TraceQL

Intrinsics use a **colon**, attributes use a **period**. That distinction is the
most common mistake and fails quietly.

```traceql
{span:name = "HTTP GET"}
{span:duration > 500ms}
{span:status = error}
{trace:duration > 2s}
{trace:rootName = "POST /v1/chat/completions"}

{resource.service.name = "kagent-controller"}
{span.http.status_code >= 500}
{span.db.system = "postgresql"}
```

Combine within a span with `&&`, across alternatives with `||`:

```traceql
{resource.service.name = "n8n" && span:status = error}
```

Structural operators relate spans. `>` is a direct child, `>>` any descendant:

```traceql
{resource.service.name = "frontend"} > {resource.service.name = "api"}
{span:name = "HTTP POST"} >> {span.db.system != "" && span:duration > 100ms}
```

Aggregate over a trace with a pipe:

```traceql
{span.db.operation = "SELECT"} | count() > 3
{} | avg(span:duration) > 100ms
```

Durations accept `us`, `ms`, `s`, `m`.

Call `/api/v2/search/tags` before filtering on an attribute you have not already
seen in a result. A misspelled attribute returns an empty set, not an error.

## Use span metrics for aggregate questions

Tempo's metrics-generator remote-writes span metrics and service graphs into
Prometheus with `source="tempo"`. Rate and percentile questions across many
traces are far cheaper there than in Tempo.

Those series carry the dimensions `gen.ai.request.model`, `gen.ai.system` and
`kagent.user_id`, which is how you attribute latency to a specific model or
caller.

| Question | Where |
| --- | --- |
| "how often", "what is p95" | `traces_spanmetrics_*`, `traces_service_graph_*` in Prometheus |
| "show me one that failed" | TraceQL search |
| "what happened in this request" | `/api/traces/<traceID>` |

Use `query_prometheus` with UID `prometheus` for the metrics side.

## Rules

Retention is **24h**. A trace older than that is gone — report that rather than
retrying with a wider window.

Keep `limit` small, 20 or less. A search returns trace IDs and summaries; fetch
the full trace only for the ones you will actually read. A single large trace
can crowd out your context.

When you are handed a `trace_id` from a log line, go straight to
`/api/traces/<traceID>`. Do not search for it.

## Reporting

Report the TraceQL you ran and the trace IDs you found. When you name a slow
span, give its service, span name and duration. Never invent a span name or
service that the API did not return.
