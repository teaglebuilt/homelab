---
name: loki
description: >
  Loki logs and LogQL for the homelab. Use to find out why something failed, to
  search log text, to measure log volume or error rates, to extract structured
  fields, and to recover a trace_id for handoff to Tempo. Carries this
  deployment's label space, the writers that feed it, the retention and query
  limits that cause failures, and LogQL construction rules.
---

# Loki and LogQL for the homelab

## This deployment

Loki runs SingleBinary with `auth_enabled: false`, chart 7.0.0, behind an nginx
gateway. Chunks live in SeaweedFS S3. Every Loki tool takes a datasource UID —
always pass `loki`.

Two writers feed it:

- **Vector** ships pod logs from both clusters.
- **The OpenTelemetry collector** ships OTLP logs.

Both land in the single tenant `fake`, so `mlops` and `application` share one
label space. Always constrain by `cluster` when you care which side produced a
line.

`allow_structured_metadata` is on, so OTLP logs carry `trace_id` and `span_id`
as **structured metadata**, not as labels. That is the handoff to Tempo: extract
a `trace_id` and report it on its own line.

## Label space

Labels are low cardinality by design: `cluster`, `namespace`, `pod`,
`container`, `app`. Anything else — request IDs, user IDs, trace IDs — lives in
the line body or in structured metadata.

Do not invent a label. `list_loki_label_names` and `analyze_loki_labels` tell
you what exists; a filter on a label that is not there matches nothing and
reports no error.

## LogQL

A query is a stream selector, then line filters, then parsers. Order matters for
cost: filter before you parse, always.

Selector — required, and must be bounded:

```logql
{namespace="ai"}
{namespace="ai", pod=~"kagent-.*"}
```

Line filters, cheapest first:

```logql
{namespace="ai"} |= "error"
{namespace="ai"} != "healthz"
{namespace="ai"} |~ "timeout|refused"
```

Parsers, only after filtering has narrowed the stream:

```logql
{namespace="ai"} |= "error" | json
{namespace="ai"} |= "error" | logfmt | level="error"
```

Metric queries, for volume and rates:

```logql
count_over_time({namespace="ai"} |= "error" [5m])
sum by (pod) (count_over_time({namespace="ai"} |= "error" [1h]))
topk(5, sum by (pod) (count_over_time({namespace="ai"}[1h])))
```

Finding a trace to hand onward:

```logql
{namespace="ai"} |= "error" | json | line_format "{{.trace_id}} {{.message}}"
```

## Limits that cause failures

| Limit | Value | Effect |
| --- | --- | --- |
| `max_query_length` | 24h | a longer range fails outright |
| `max_query_lookback` | 24h | older data is gone, not slow |
| `max_entries_limit_per_query` | 10000 | a line query past this is rejected |

A query reaching further back than retention **fails** rather than returning
partial data. Say so instead of retrying with a wider window.

For "how often" questions use a metric query, never a line query you then count
yourself — that is what the 10000 limit exists to stop.

Never run an unbounded selector. `{namespace=~".+"}` over an hour will be
rejected or will time out. Start narrow and widen only if empty.

## Three different empties

Distinguish them explicitly, because they lead to opposite conclusions:

- **The query returned nothing** — the filter matched no lines in range.
- **The service is healthy** — there was nothing to log. Not the same thing.
- **Loki itself is unhealthy** — the query errored at the gateway. Report that as
  a Loki problem, not as an absence of logs.

## Reporting

Quote the log lines you found. Report the LogQL so it can be rerun. If you found
a `trace_id`, state it on its own line so it can be handed to Tempo.

## References

- `references/logql.md` — fuller LogQL syntax and function reference
- `references/storage.md` — chunk and index storage behaviour
- `references/opentelemetry.md` — OTLP ingestion and structured metadata
