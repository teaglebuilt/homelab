---
name: tempo
description: Guide for implementing Grafana Tempo - a high-scale distributed tracing backend for OpenTelemetry traces. Use when configuring Tempo deployments, setting up storage backends (S3, GCS), writing TraceQL queries, deploying via Helm, understanding trace structure, or troubleshooting Tempo issues on Kubernetes.
---

> **Homelab:** this is an upstream, generic skill. Read the `observability-engineering`
> skill first for this repo's topology, pinned versions, endpoints and storage overrides.

# Grafana Tempo Skill

Comprehensive guide for Grafana Tempo - the cost-effective, high-scale distributed tracing backend designed for OpenTelemetry.

## What is Tempo?

Tempo is a **high-scale distributed tracing backend** that:

- **Trace-ID lookup model** - No indexing of every attribute, keeps ingestion fast and storage costs low
- **OpenTelemetry native** - First-class support for OTLP protocol
- **Object storage backed** - Stores traces in affordable S3 or GCS object storage
- **TraceQL query language** - Powerful query language inspired by PromQL and LogQL
- **Apache Parquet format** - 5-10x less data pulled per query vs legacy formats
- **Multi-tenant by default** - Built-in tenant isolation via `X-Scope-OrgID` header

## Architecture Overview

### Core Components

| Component | Purpose |
|-----------|---------|
| **Distributor** | Entry point for trace data, routes to ingesters via consistent hash ring |
| **Ingester** | Buffers traces in memory, creates Parquet blocks, flushes to storage |
| **Query Frontend** | Query orchestration, shards blockID space, coordinates queriers |
| **Querier** | Locates traces in ingesters or storage using bloom filters |
| **Compactor** | Compresses blocks, deduplicates data, manages retention |
| **Metrics Generator** | Optional: derives metrics from traces |

### Data Flow

**Write Path:**

```
Applications → Collector → Distributor → Ingester → Object Storage
                                  ↓
                           Consistent Hash Ring
                           (routes by traceID)
```

**Read Path:**

```
Query Request → Query Frontend → Queriers → Ingesters (recent data)
                      ↓                            ↓
                 Block Sharding          Object Storage (historical data)
                      ↓                            ↓
              Parallel Querier Work      Bloom Filters + Indexes
```

## Deployment Modes

### 1. Monolithic Mode (`-target=all`)

- All components in single process
- Best for: Local testing, small-scale deployments
- **Cannot horizontally scale** component count
- Scale by increasing replicas

### 2. Scalable Monolithic (`-target=scalable-single-binary`)

- All components in one process with horizontal scaling
- Each instance runs all components
- Good for development with scaling needs

### 3. Microservices Mode (Distributed) - Recommended for Production

```yaml
# Using tempo-distributed Helm chart
distributor:
  replicas: 3

ingester:
  replicas: 3

querier:
  replicas: 2

queryFrontend:
  replicas: 2

compactor:
  replicas: 1
```

## Helm Deployment

### Add Repository

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Install Distributed Tempo

```bash
helm install tempo grafana/tempo-distributed \
  --namespace observability \
  --values values.yaml
```

### Production Values Example

```yaml
# Storage configuration
storage:
  trace:
    backend: s3  # or gcs, local
    s3:
      bucket: tempo-traces
      endpoint: <s3-endpoint>
      region: us-east-1

# Distributor
distributor:
  replicas: 3
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      memory: 4Gi

# Ingester
ingester:
  replicas: 3
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      memory: 8Gi  # Spikes to 8GB periodically
  persistence:
    enabled: true
    size: 20Gi

# Querier
querier:
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      memory: 4Gi

# Query Frontend
queryFrontend:
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      memory: 2Gi

# Compactor
compactor:
  replicas: 1
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      memory: 6Gi

# Block retention
compactor:
  compaction:
    block_retention: 336h  # 14 days

# Gateway for external access
gateway:
  enabled: true
  replicas: 1

# Metrics Generator (optional)
metricsGenerator:
  enabled: false
```

## Storage Configuration

### AWS S3

```yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: my-tempo-bucket
      region: us-east-1
      endpoint: s3.us-east-1.amazonaws.com
      # Use IAM roles or access keys
      access_key: <access-key>
      secret_key: <secret-key>
```

### Google Cloud Storage

```yaml
storage:
  trace:
    backend: gcs
    gcs:
      bucket_name: my-tempo-bucket
      # Uses Workload Identity or service account
```

## TraceQL Query Language

### Basic Queries

```traceql
# Simplest query - all spans
{ }

# Filter by service
{ resource.service.name = "frontend" }

# Filter by operation
{ span:name = "GET /api/orders" }

# Filter by status
{ span:status = error }

# Filter by duration
{ span:duration > 500ms }

# Multiple conditions
{ resource.service.name = "api" && span:status = error }
```

### Structural Operators

```traceql
# Direct parent-child relationship
{ resource.service.name = "frontend" } > { resource.service.name = "api" }

# Ancestor-descendant relationship
{ span:name = "GET /api/products" } >> { span.db.system = "postgresql" }

# Sibling relationship
{ span:name = "span-a" } ~ { span:name = "span-b" }
```

### Aggregation Functions

```traceql
# Count spans
{ } | count() > 10

# Average duration
{ } | avg(span:duration) > 20ms

# Max duration
{ span:status = error } | max(span:duration)
```

### Metrics Functions

```traceql
# Rate of errors
{ span:status = error } | rate()

# Count over time
{ span:name = "GET /:endpoint" } | count_over_time()

# Percentile latency
{ span:name = "GET /:endpoint" } | quantile_over_time(span:duration, .99)

# Group by service
{ span:status = error } | rate() by(resource.service.name)

# Top 10 by error rate
{ span:status = error } | rate() by(resource.service.name) | topk(10)
```

## Trace Structure

### Intrinsic Fields (colon separator)

| Field | Description |
|-------|-------------|
| `span:name` | Operation name |
| `span:duration` | Elapsed time (e.g., "10ms", "1.5s") |
| `span:status` | `ok`, `error`, or `unset` |
| `span:kind` | `server`, `client`, `producer`, `consumer`, `internal` |
| `trace:duration` | Total trace duration |
| `trace:rootName` | Root span name |
| `trace:rootService` | Root span service |

### Attribute Scopes (period separator)

| Scope | Example | Description |
|-------|---------|-------------|
| `span.` | `span.http.method` | Span-level attributes |
| `resource.` | `resource.service.name` | Resource attributes |
| `event.` | `event.exception.message` | Event attributes |
| `link.` | `link.traceID` | Link attributes |

## Receiver Endpoints

| Protocol | Port | Endpoint |
|----------|------|----------|
| **OTLP gRPC** | 4317 | `/v1/traces` |
| **OTLP HTTP** | 4318 | `/v1/traces` |
| **Jaeger gRPC** | 14250 | - |
| **Jaeger Thrift HTTP** | 14268 | `/api/traces` |
| **Jaeger Thrift Compact** | 6831 | UDP |
| **Jaeger Thrift Binary** | 6832 | UDP |
| **Zipkin** | 9411 | `/api/v2/spans` |

## Multi-Tenancy

```yaml
# Enable multi-tenancy
multitenancy_enabled: true

# All requests must include X-Scope-OrgID header
# Example:
# curl -H "X-Scope-OrgID: tenant-1" http://tempo:3200/api/traces/<traceID>
```

## Troubleshooting

### Common Issues

**1. Ingester OOM**

```yaml
ingester:
  resources:
    limits:
      memory: 16Gi  # Increase from 8Gi
```

**2. Query Timeout**

```yaml
querier:
  query_timeout: 5m
  max_concurrent_queries: 20
```

### Diagnostic Commands

```bash
# Check pod status
kubectl get pods -n observability -l app.kubernetes.io/name=tempo

# Check distributor logs
kubectl logs -n observability -l app.kubernetes.io/component=distributor --tail=100

# Check ingester logs
kubectl logs -n observability -l app.kubernetes.io/component=ingester --tail=100

# Verify readiness
kubectl exec -it <tempo-pod> -n observability -- wget -qO- http://localhost:3200/ready

# Check ring status
kubectl port-forward svc/tempo-distributor 3200:3200 -n observability
curl http://localhost:3200/distributor/ring
```

## API Reference

### Trace Retrieval

```bash
# Get trace by ID
GET /api/traces/<traceID>

# Search traces (TraceQL)
GET /api/search?q={resource.service.name="api"}

# Search tags
GET /api/search/tags
GET /api/search/tag/<tag>/values
```

### Health

```bash
GET /ready
GET /metrics
```

## Reference Documentation

For detailed configuration by topic:

- **[Storage Configuration](references/storage.md)**: Object stores, retention, caching
- **[TraceQL Reference](references/traceql.md)**: Query syntax and examples
- **[Configuration Reference](references/configuration.md)**: Full configuration manifest

## External Resources

- [Official Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Tempo Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/tempo-distributed)
- [TraceQL Documentation](https://grafana.com/docs/tempo/latest/traceql/)
- [Tempo GitHub Repository](https://github.com/grafana/tempo)

---

## Gotchas

- **Retention is per-tenant**; global retention is fallback only — a misconfigured tenant silently overrides.
- **Tail sampling at end of OTel collector pipeline doesn't release the trace from inflight buffer** — under load the collector OOMs with traces it's about to drop.
- **TraceQL `{}` expressions are filter expressions, not query strings** — semantics differ from PromQL/LogQL; copy-pasting query patterns fails subtly.
- **Multi-tenant via X-Scope-OrgID**: missing/invalid header falls into "fake" tenant, same as Loki/Mimir.
- **Span size cap (default 1 MB)**: spans larger than the cap are silently truncated mid-attribute — debug by checking ingester metrics for `discarded_spans_total`.
- **Search by service.name vs resource.service.name**: depends on whether your OTel SDK puts the attribute on the span or on the resource — both look similar but indexed differently.
