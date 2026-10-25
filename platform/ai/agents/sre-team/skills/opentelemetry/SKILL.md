---
name: opentelemetry
description: >
  OpenTelemetry collector pipelines across the homelab's two clusters. Use when
  telemetry is missing, delayed or malformed — which is a different problem from
  a backend being unhealthy. Carries the two-collector topology, the ordered
  diagnostic path, the collector's own self-reported metrics and how to read
  them, and the naming constraint that breaks cross-cluster forwarding.
---

# OpenTelemetry pipelines for the homelab

Your question is always "did the data get there, and if not where did it stop".
You own the pipeline, not the backends.

## Topology

Collectors are managed by the OpenTelemetry Operator as
`OpenTelemetryCollector` CRs in the `observability` namespace. There are two and
they are **not** interchangeable:

| Cluster | Name | Role |
| --- | --- | --- |
| `mlops` | `otel-agent` | forwards across ClusterMesh |
| `application` | `otel-collector` | terminates and fans out |

```
apps on mlops       --OTLP--> otel-agent --> otel-collector-mesh:4317
apps on application --OTLP--> otel-collector
                                |-- traces  --> tempo.observability:4317
                                |-- logs    --> loki-gateway.observability/otlp
                                `-- metrics --> prometheus remote write

pod logs --> Vector --> loki-gateway-mesh (both clusters)
Tempo metrics-generator --> Prometheus remote write
```

**The mlops collector must not be named `otel-collector`.** The mesh Service
selects on that name, so renaming it makes mlops traffic loop back to itself
instead of crossing to the application cluster. If you find a collector on
mlops named `otel-collector`, that is the bug — stop and report it.

## Diagnostic path

Work the path in order and stop at the first break.

**1. Does the collector exist and is it Ready.**
`k8s_get_resources` for `opentelemetrycollectors` in `observability`, on the
cluster you care about.

**2. What config is it actually running.**
`k8s_get_resource_yaml` on the CR, then the generated ConfigMap. A receiver,
processor or exporter that is defined but **absent from `service.pipelines` is
inert**. That omission is the single most common cause of a silent pipeline, and
it looks like healthy config until you check the pipeline list.

**3. What does it say.**
`k8s_get_pod_logs` on the collector pod. Exporter failures, queue-full and
permanent-error lines name the downstream that is refusing data.

**4. What do its own metrics say.**

```
otelcol_receiver_accepted_spans   / otelcol_receiver_refused_spans
otelcol_exporter_sent_spans       / otelcol_exporter_send_failed_spans
otelcol_exporter_queue_size       / otelcol_exporter_queue_capacity
otelcol_processor_dropped_spans
otelcol_processor_batch_batch_send_size
```

Read them as pairs:

| Pattern | Meaning |
| --- | --- |
| accepted high, sent zero | the exporter is failing — look downstream |
| refused at the receiver | the sender is wrong, or over a limit |
| queue_size pinned at capacity | downstream too slow; data is being dropped now |
| dropped_spans climbing | a processor is discarding, often a filter or memory_limiter |

The direct Prometheus tools default to `http://localhost:9090` and will fail.
Pass `prometheus_url` explicitly:
`http://prometheus-mesh.observability.svc.cluster.local:9090`

**5. Only then suspect the backend** — and say so, because that is another
specialist's work, not yours.

## Constraints

OTLP is gRPC on **4317** and HTTP on **4318**. A sender pointed at the wrong one
fails at connect, not at export.

Loki ingestion needs `allow_structured_metadata` so `trace_id` and `span_id`
survive as structured metadata. That setting is what makes logs link to traces;
without it correlation silently degrades.

## Safety

Read before you write. Report what a config change would be and let the operator
decide. Do not mutate a collector CR to test a theory — a collector restart
drops whatever is in its queue.

The durable change belongs in the operator CR in the repo, not in a live patch.

## Reporting

Name the stage you proved broken and the evidence for it.

"Telemetry is missing" is not a finding. "otel-agent on mlops accepted 1.2k
spans and sent 0; exporter logs show connection refused to
otel-collector-mesh:4317" is a finding.
