---
name: observability-engineering
description: >
  Observability for this homelab — Loki log storage and LogQL, Tempo trace storage
  and TraceQL, OpenTelemetry collectors and instrumentation, Prometheus and Grafana,
  Vector log shipping, trace/log/metric correlation, sampling, retention, and
  cost control. Use when configuring or debugging the monitoring stack, writing or
  optimizing a LogQL or TraceQL query, tuning Loki or Tempo storage, schema,
  compaction, caching or limits, wiring OTLP pipelines, or building dashboards and
  SLO alerts. Also use when changing kubernetes/helmfile.d/04-monitoring*,
  kubernetes/apps/monitoring/**, or platform/observability/**.
metadata:
  repository: teaglebuilt/homelab
---

# Observability Engineering

Stack: OpenTelemetry → Vector / OTLP → Loki (logs), Tempo (traces), Prometheus
(metrics), Grafana (query + dashboards). Traces are correlated to logs; see
`correlation-strategies.md`.

## Repository Ownership

| Concern | Location |
| --- | --- |
| Monitoring Helmfile stage | `kubernetes/helmfile.d/04-monitoring*` |
| Vector log shipper | `kubernetes/apps/monitoring/vector.yaml.gotmpl` |
| Per-app monitoring values | `kubernetes/apps/monitoring/` |
| Compose stack (Grafana, Loki, Tempo, Prometheus) | `platform/observability/compose.yaml` |
| Graylog / OpenSearch | `platform/observability/{graylog,opensearch}/` |
| K8s resources for the platform stack | `platform/observability/kubernetes/` |
| Parca (profiling) | `platform/observability/charts/parca-4.19.0` |

Determine the owning system before editing — the monitoring stage and the Compose
stack are separate deployments.

## Reference Routing

Read only what the task needs.

### Loki and logs

- [loki.md](resources/loki.md) — storage architecture, index engines (TSDB/bloom),
  object store backends, retention, WAL, caching, compaction, schema migration,
  storage troubleshooting.
- [logql.md](resources/logql.md) — stream selectors, line and label filters, parsers,
  line/label format, metric queries, structured metadata, query optimization, API
  parameters.
- [logs-aggregation.md](resources/logs-aggregation.md) — ELK vs Loki, structured
  logging practice.

### Tempo and traces

- [tempo.md](resources/tempo.md) — deployment modes, Helm values mapping, distributor,
  ingester, querier, query-frontend, compactor, storage, limits, metrics-generator,
  multi-tenancy, hash ring, search, defaults, env expansion, config validation.
- [traceql.md](resources/traceql.md) — trace structure, comparison/logical/structural
  operators, aggregations, metrics functions, `by()` grouping, `select`, sampling.
- [distributed-tracing.md](resources/distributed-tracing.md) — trace propagation and
  span design.

### Instrumentation and correlation

- [opentelemetry.md](resources/opentelemetry.md) — OTEL SDK, auto-instrumentation,
  collector pipelines, exporters.
- [correlation-strategies.md](resources/correlation-strategies.md) — trace IDs across
  logs, metrics, and traces.

### Cost and vendor comparison

- [observability-cost-optimization.md](resources/observability-cost-optimization.md) —
  sampling, retention, cardinality, cost strategies.
- [apm-tools.md](resources/apm-tools.md) — DataDog, New Relic, Dynatrace comparison.
  Background only; this homelab runs the OSS Grafana stack.

## Operating Rules

1. Match documentation to the deployed chart and image versions. Confirm them before
   advising on a config field — Loki and Tempo rename and relocate settings between
   minor versions.
2. Loki schema changes are forward-dated migrations, not in-place edits. Read the
   schema migration section before touching `schema_config`.
3. Keep the Tempo compactor a singleton. Verify before scaling.
4. Label cardinality is the primary Loki cost and failure driver. Push detail into
   structured metadata or the log line, not into stream labels.
5. Prefer `kagent-tools_k8s_*` for inline live inspection of monitoring pods; use local
   `kubectl` when output is large or piped.
6. Validate rendered output, not just the values file:
   `helmfile -f kubernetes/helmfile.d/04-monitoring*.yaml template` and
   `docker compose -f platform/observability/compose.yaml config`.

## Query Workflow

1. Confirm which backend answers the question — logs (Loki/LogQL), traces
   (Tempo/TraceQL), or metrics (Prometheus/PromQL).
2. Start from the narrowest stream selector or span filter, then add parsers and
   filters. Never start with an unbounded selector over a long range.
3. Check the optimization section of the relevant reference before widening a range.
4. State the time range and tenant with the query.
