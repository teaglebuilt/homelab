---
name: prometheus
description: >
  Prometheus metrics and PromQL for the homelab. Use when the question is
  numerical or about a threshold over time — request rates, error ratios,
  latency percentiles, saturation, capacity trends, restart counts, scrape
  health. Carries the two query paths and their endpoints, the data-model rules
  that make PromQL correct, and the query patterns for this estate.
---

# Prometheus and PromQL for the homelab

## Where the data is

One Prometheus, in the `application` cluster, holds metrics for **both**
clusters. `mlops` runs a PrometheusAgent that remote-writes into it. Filter by
the `cluster` label when the question is about one side.

Tempo's metrics-generator also remote-writes span metrics and service graphs
there, tagged `source="tempo"`.

## Two paths to it

**Prefer the Grafana tools.** `query_prometheus` and
`query_prometheus_histogram` take datasource UID `prometheus` and handle time
ranges for you.

The direct tools — `prometheus_query_tool`, `prometheus_query_range_tool`,
`prometheus_targets_tool`, `prometheus_label_names_tool` — default to
`http://localhost:9090`, which is wrong inside the cluster and will fail. Pass
`prometheus_url` explicitly on **every** call:

```
http://prometheus-mesh.observability.svc.cluster.local:9090
```

That is a ClusterMesh global Service. If it is unreachable, that is a mesh or
Prometheus problem — report it as such rather than retrying another URL.

## Data model

| Kind | Suffix | How to read it |
| --- | --- | --- |
| Counter | almost always `_total` | meaningless raw; wrap in `rate()` or `increase()` |
| Gauge | none | read directly |
| Histogram | `_bucket`, `_sum`, `_count` | percentiles via `histogram_quantile()` over buckets |

`rate()` on a gauge is wrong. A raw counter value is wrong. `histogram_quantile`
over a non-bucket series is wrong. These three mistakes produce plausible
numbers, so check the metric kind before trusting a result.

## Patterns

Request rate:

```promql
rate(http_requests_total{job="api"}[5m])
```

Error ratio — always a ratio of two rates, never a bare error count:

```promql
sum(rate(http_requests_total{job="api",status=~"5.."}[5m]))
  / sum(rate(http_requests_total{job="api"}[5m]))
```

Latency p95 — sum buckets by `le` *before* the quantile:

```promql
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket{job="api"}[5m])))
```

Saturation:

```promql
sum by (pod) (container_memory_working_set_bytes{namespace="ai"})
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="ai"}[5m]))
```

Memory against its limit, which is the question that actually predicts an OOM:

```promql
sum by (pod) (container_memory_working_set_bytes{namespace="ai"})
  / sum by (pod) (kube_pod_container_resource_limits{namespace="ai",resource="memory"})
```

Pod restarts:

```promql
increase(kube_pod_container_status_restarts_total{namespace="ai"}[1h])
```

Availability:

```promql
sum(up{job="api"}) / count(up{job="api"})
```

Growth, for capacity questions:

```promql
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[6h], 24*3600)
```

## Rules

A `rate()` window must cover at least four scrape intervals, so `[5m]` is the
safe floor. A shorter window yields gaps or nothing at all.

Aggregate before you divide. Keep labels consistent on both sides of a binary
operation or the result is silently empty.

An empty result is usually a label mismatch, not an absence of data. Check with
`list_prometheus_label_values` before concluding anything.

Never guess a metric name. `list_prometheus_metric_names` or
`list_prometheus_metric_metadata` confirms it exists.

For "is this scraping at all", use `prometheus_targets_tool` rather than
querying for absence — a down target and a renamed metric look identical from
the query side.

## Reporting

Report the PromQL you ran alongside the numbers, with units. State the time
range. If a query returned empty, say which label you suspect and what you
checked. Never present a number whose metric you did not confirm exists.

## References

- `references/promql_functions.md` — function semantics and selection
- `references/api_reference.md` — raw HTTP API, for anything the tools do not cover
