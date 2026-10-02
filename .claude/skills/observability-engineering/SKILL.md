---
name: observability-engineering
description: >
  Homelab observability hub — topology, pinned versions, endpoints, and ownership of the
  metrics/logs/traces stack (Prometheus, Loki, Tempo, OpenTelemetry, Vector, Grafana)
  across the application and mlops clusters. Load this first for any change to
  platform/observability/**, kubernetes/helmfile.d/04-monitoring*, or
  kubernetes/apps/monitoring/**, and for cross-signal work (trace/log/metric
  correlation, sampling, retention, cardinality, SLO alerts). It routes to the
  prometheus, loki, tempo, opentelemetry, and grafana skills for backend depth.
metadata:
  repository: teaglebuilt/homelab
---

# Observability Engineering

This skill owns homelab facts. Backend skills own generic product knowledge. Read this
file, then load only the backend skill the task needs. When a backend skill contradicts
the **Homelab Overrides** below, the overrides win.

## Topology

| Cluster | Runs | Ships to |
| --- | --- | --- |
| `application` (hub) | kube-prometheus-stack (Prometheus, Alertmanager, Grafana), Loki, Tempo, `otel-collector`, Vector, grafana-operator | local backends |
| `mlops` (spoke) | PrometheusAgent, `otel-agent`, Vector | `application` over Cilium ClusterMesh global Services |

Signal flow:

```
apps --OTLP--> otel-agent (mlops) --> otel-collector-mesh:4317 --+
apps --OTLP--> otel-collector (application) <--------------------+
                 |-- traces  --> tempo.observability:4317
                 |-- logs    --> loki-gateway.observability/otlp
                 `-- metrics --> prometheus-community-kube-prometheus.observability:9090/api/v1/write
pod logs --> Vector --> loki-gateway-mesh.observability (both clusters)
Tempo metrics-generator --> Prometheus remote write (service graphs, span metrics)
mlops PrometheusAgent --> remote write --> application Prometheus
```

All components run in the `observability` namespace.

## Pinned Versions

| Component | Chart / version | Mode | Defined in |
| --- | --- | --- | --- |
| kube-prometheus-stack | 61.7.1 | full on application, agent on mlops | `platform/observability/kubernetes/apps/prometheus/overlays/<cluster>/` |
| Loki | `loki` 7.0.0 | SingleBinary, `auth_enabled: false` | `platform/observability/kubernetes/apps/loki/kustomization.yaml` |
| Tempo | `tempo` 1.24.4 (monolithic chart) | single binary, multitenancy off | `platform/observability/kubernetes/apps/tempo/kustomization.yaml` |
| OpenTelemetry Operator | 0.114.1 | `OpenTelemetryCollector` CRs | `platform/observability/kubernetes/apps/opentelemetry/overlays/<cluster>/` |
| Vector | 0.44.0 | Helmfile stage 04 | `kubernetes/apps/monitoring/vector.yaml.gotmpl` |
| grafana-operator | 5.24.0 | Helmfile stage 04, application only | `kubernetes/helmfile.d/04-monitoring.gotmpl.yaml` |

Re-check these before giving version-specific advice. The chart pins above are the
source of truth, not this table.

## Repository Ownership

| Concern | Location | Deployed by |
| --- | --- | --- |
| Per-cluster stack composition | `platform/observability/kubernetes/overlays/{application,mlops}/` | `task platform:observability:deploy CLUSTER=<cluster>` |
| Prometheus values, operator, alert rules | `platform/observability/kubernetes/apps/prometheus/overlays/<cluster>/` (`rules/` on application) | same |
| Grafana instance, datasources, dashboards, HTTPRoute | `platform/observability/kubernetes/apps/grafana/overlays/application/` | same |
| Collector CRs | `platform/observability/kubernetes/apps/opentelemetry/overlays/<cluster>/otel-collector.yaml` | same |
| Loki / Tempo | `platform/observability/kubernetes/apps/{loki,tempo}/` | same |
| Vector, grafana-operator CRDs | `kubernetes/helmfile.d/04-monitoring.gotmpl.yaml` | Helmfile stage 04 |
| Unifi metrics (InfluxDB, Chronograf, Unpoller, Grafana) | `platform/observability/compose.yaml` | Docker Compose, separate from K8s |
| Graylog / OpenSearch | `platform/observability/{graylog,opensearch}/` | Compose |
| Parca | `platform/observability/charts/parca-4.19.0` | — |

The Kustomize stack, the Helmfile stage, and the Compose stack are separate
deployments. Identify the owner before editing.

## Skill Routing

| Task | Skill | Start with |
| --- | --- | --- |
| PromQL, recording/alert rules, targets, TSDB cardinality, Prometheus HTTP API | `prometheus` | [SKILL.md](../prometheus/SKILL.md), [promql_functions.md](../prometheus/references/promql_functions.md), [api_reference.md](../prometheus/references/api_reference.md) |
| LogQL queries | `loki` | [logql.md](../loki/references/logql.md) |
| Loki schema, storage, retention, compaction, limits | `loki` | [storage.md](../loki/references/storage.md) |
| OTLP log ingestion, structured metadata, resource-attribute → label mapping | `loki` | [opentelemetry.md](../loki/references/opentelemetry.md) |
| TraceQL queries | `tempo` | [traceql.md](../tempo/references/traceql.md) |
| Tempo config, metrics-generator, overrides, storage | `tempo` | [configuration.md](../tempo/references/configuration.md), [storage.md](../tempo/references/storage.md) |
| Collector pipelines, processors, exporters | `opentelemetry` | [COLLECTOR.md](../opentelemetry/references/COLLECTOR.md) |
| Operator, CR deployment, k8sattributes | `opentelemetry` | [KUBERNETES.md](../opentelemetry/references/KUBERNETES.md) |
| SDK and auto-instrumentation | `opentelemetry` | [INSTRUMENTATION.md](../opentelemetry/references/INSTRUMENTATION.md) |
| Dropped or missing telemetry | `opentelemetry` | [TROUBLESHOOTING.md](../opentelemetry/references/TROUBLESHOOTING.md) |
| Dashboards, datasources, alerting via the Grafana API | `grafana` | [SKILL.md](../grafana/SKILL.md) |
| Trace ↔ log ↔ metric correlation | this skill | [correlation-strategies.md](resources/correlation-strategies.md) |
| Span design and context propagation | this skill | [distributed-tracing.md](resources/distributed-tracing.md) |
| Sampling, retention, cardinality budget | this skill | [observability-cost-optimization.md](resources/observability-cost-optimization.md) |
| Structured logging practice | this skill | [logs-aggregation.md](resources/logs-aggregation.md) |
| Commercial APM comparison (background only) | this skill | [apm-tools.md](resources/apm-tools.md) |

Load one backend skill per signal. Cross-signal tasks such as Loki → Tempo derived
fields or Tempo service graphs in Prometheus need both backend skills plus
`correlation-strategies.md`.

## Homelab Overrides

The backend skills are generic. These facts take precedence over them.

- **Storage is SeaweedFS S3** (`seaweedfs-s3.storage.svc.cluster.local:8333`, path-style,
  insecure). Skip GCS and public-cloud IAM sections in `loki` and `tempo`.
- **Loki is SingleBinary.** `read`, `write`, and `backend` are scaled to 0, and memcached
  caches are disabled. Ignore SSD/microservices sizing advice. Retention is 24h, and
  `allow_structured_metadata: true` is load-bearing for Loki → Tempo correlation.
- **Tempo uses the monolithic `tempo` chart, not `tempo-distributed`.** Values live under
  `tempo:` in the chart. Distributor/ingester/querier scaling advice does not apply.
  Retention is 24h, and `config.expand-env` is on for S3 credentials.
- **Loki and Tempo use emptyDir for WAL and `persistence.enabled: false`.** Do not enable
  persistence. It adds an immutable volumeClaimTemplate to the StatefulSet.
- **No multi-tenancy.** Omit `X-Scope-OrgID` unless you are explicitly changing that.
- **Collectors are `OpenTelemetryCollector` CRs managed by the operator**, not the
  `opentelemetry-collector` Helm chart. The `presets:` and `mode:` examples in the
  `opentelemetry` skill map to CR `spec` fields.
- **mlops collector must not be named `otel-collector`.** The mesh Service selects that
  instance label, and reusing the name creates a forwarding loop.
- **Prometheus is reached by port-forward, not an HTTPRoute.** To use the `prometheus`
  skill scripts:
  `kubectl --kubeconfig kubernetes/generated/application/kubeconfig -n observability port-forward svc/prometheus-community-kube-prometheus 9090`,
  then target `http://localhost:9090`.
- **Prometheus on application has the remote-write receiver enabled** (needed by Tempo
  metrics-generator, the OTel exporter, and the mlops agent). Retention is 15d.
  `*SelectorNilUsesHelmValues: false`, so any ServiceMonitor/PodMonitor/PrometheusRule
  in any namespace is picked up.
- **Grafana is managed by grafana-operator.** Datasources and dashboards are
  `GrafanaDatasource` and `GrafanaDashboard` CRs in Git. API or UI edits are reverted on
  reconcile. Use the `grafana` skill API tooling to read, export, or prototype, then
  commit the result as a CR.

## Operating Rules

1. Confirm the chart and image version before advising on a config field. Loki and Tempo
   rename and relocate settings between minor versions.
2. Loki schema changes are forward-dated `schemaConfig` entries, not in-place edits.
3. Label cardinality is the main cost and failure driver in both Loki and Prometheus.
   Push detail into structured metadata, span attributes, or the log line.
4. Inspect live state read-only first. Use the kagent `k8s_*` tools when the homelab MCP
   server is connected. Otherwise use local `kubectl` with the generated kubeconfig for
   the target cluster.
5. Validate rendered output, not just values:
   `kustomize build --enable-helm --enable-exec --enable-alpha-plugins --load-restrictor LoadRestrictionsNone platform/observability/kubernetes/overlays/<cluster>`,
   `helmfile -f kubernetes/helmfile.d/04-monitoring.gotmpl.yaml template`, and
   `docker compose -f platform/observability/compose.yaml config`.
6. Changes to one cluster's overlay often need the matching change on the other, for
   example a new pipeline in both `otel-collector` and `otel-agent`. Check both overlays.

## Query Workflow

1. Pick the backend: metrics → `prometheus`, logs → `loki`, traces → `tempo`.
2. Start from the narrowest selector or span filter, then add parsers and filters. Never
   run an unbounded selector over a long range. Loki and Tempo hold only 24h.
3. State the time range and the cluster with the query.
