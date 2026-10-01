# Tempo

Tempo is a **high-scale distributed tracing backend** that:

- **Trace-ID lookup model** - No indexing of every attribute, keeps ingestion fast and storage costs low
- **OpenTelemetry native** - First-class support for OTLP protocol
- **Object storage backed** - Stores traces in affordable S3, GCS, or Azure Blob Storage
- **TraceQL query language** - Powerful query language inspired by PromQL and LogQL
- **Apache Parquet format** - 5-10x less data pulled per query vs legacy formats
- **Multi-tenant by default** - Built-in tenant isolation via `X-Scope-OrgID` header

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
    backend: azure  # or s3, gcs
    azure:
      container_name: tempo-traces
      storage_account_name: mystorageaccount
      use_federated_token: true  # Workload Identity

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

## Server Configuration

```yaml
server:
  http_listen_port: 3200          # Default HTTP port
  grpc_listen_port: 9095          # Default gRPC port
  graceful_shutdown_timeout: 30s
  http_server_read_timeout: 30s
  http_server_write_timeout: 30s
```

## Distributor Configuration

```yaml
distributor:
  ring:
    kvstore:
      store: memberlist           # memberlist, consul, etcd
    heartbeat_period: 5s
    heartbeat_timeout: 1m

  receivers:
    jaeger:
      protocols:
        grpc:
          endpoint: 0.0.0.0:14250
        thrift_http:
          endpoint: 0.0.0.0:14268
        thrift_compact:
          endpoint: 0.0.0.0:6831
        thrift_binary:
          endpoint: 0.0.0.0:6832

    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

    opencensus:
      endpoint: 0.0.0.0:55678

    zipkin:
      endpoint: 0.0.0.0:9411

  # Forwarding to other services
  forwarders:
    - name: otlp
      queue:
        size: 1000
      backend: otlp
      otlp:
        endpoints:
          - http://other-service:4317
```

## Ingester Configuration

```yaml
ingester:
  lifecycler:
    ring:
      kvstore:
        store: memberlist
      replication_factor: 3       # Number of replicas
    heartbeat_period: 5s
    join_after: 10s
    min_ready_duration: 10s
    final_sleep: 30s

  # Trace processing
  trace_idle_period: 5s           # Flush to WAL after idle
  max_block_duration: 30m         # Max time before flush
  max_block_bytes: 524288000      # ~500MB default
  complete_block_timeout: 1h
  flush_check_period: 30s
  concurrent_flushes: 4           # Parallel flush operations

  # WAL configuration
  wal:
    path: /var/tempo/wal
    encoding: snappy              # snappy, lz4, gzip, none
    checkpoint_duration: 5m
    replay_memory_ceiling: 4GB    # ~75% of available memory
```

## Querier Configuration

```yaml
querier:
  frontend_worker:
    frontend_address: tempo-query-frontend:9095
    match_max_concurrent: true

  # Query behavior
  query_timeout: 30s              # Default query timeout
  max_concurrent_queries: 20      # Max parallel queries
  search_query_timeout: 30s       # Search timeout
  trace_by_id_timeout: 10s        # Trace lookup timeout

  # Shuffle sharding
  shuffle_sharding_ingesters_enabled: true
  shuffle_sharding_ingesters_lookback_period: 1h

  # Backend search windows
  query_backend_after: 15m        # Search backend if older than this
  query_ingesters_until: 30m      # Search ingesters if newer than this

  # Size limits
  max_spans_per_span_set: 100
  query_expr_size_limit_bytes: 131072  # 128KB
```

## Query Frontend Configuration

```yaml
query_frontend:
  # Result streaming
  search:
    concurrent_jobs: 1000
    target_bytes_per_job: 104857600  # 100MB
    default_result_limit: 20
    max_result_limit: 0             # 0 = unlimited
    max_duration: 168h              # 7 days

  # TraceQL metrics
  metrics:
    max_duration: 24h
    query_backend_after: 15m
    concurrent_jobs: 1000
    target_bytes_per_job: 104857600

  # Trace by ID
  trace_by_id:
    query_shards: 50
    hedge_requests_at: 2s
    hedge_requests_up_to: 2
```

## Compactor Configuration

```yaml
compactor:
  ring:
    kvstore:
      store: memberlist

  compaction:
    compaction_window: 1h         # Time window to compact
    block_retention: 336h         # 14 days default retention
    max_block_bytes: 107374182400 # ~107GB max block size
    compacted_block_retention: 1h
    v2_in_buffer_bytes: 5242880
    v2_out_buffer_bytes: 20971520
    v2_prefetch_traces_count: 1000

  # Deletion
  retention_concurrency: 10
```

## Storage Configuration

### Global Storage Settings

```yaml
storage:
  trace:
    backend: azure                # local, s3, gcs, azure

    # Block polling
    blocklist_poll: 5m
    blocklist_poll_fallback: true
    blocklist_poll_jitter_ms: 500
    blocklist_poll_tenant_index_builders: 1

    # Bloom filters
    bloom_filter_false_positive: 0.01
    bloom_filter_shard_size_bytes: 102400

    # Index
    index_downsample_bytes: 1048576

    # WAL
    wal:
      path: /var/tempo/wal
      encoding: snappy

    # Cache
    cache: memcached
    memcached:
      host: tempo-memcached:11211
      service: memcached-client
      timeout: 500ms
```

### Azure Storage

```yaml
storage:
  trace:
    backend: azure
    azure:
      container_name: tempo-traces
      storage_account_name: mystorageaccount
      # Authentication (choose one):
      use_federated_token: true           # Workload Identity
      # use_managed_identity: true        # Managed Identity
      # user_assigned_id: <client-id>     # User-assigned MI
      # storage_account_key: <key>        # Account key (dev)
      endpoint_suffix: blob.core.windows.net
      hedge_requests_at: 400ms
      hedge_requests_up_to: 2
```

### S3 Storage

```yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: my-tempo-bucket
      region: us-east-1
      endpoint: s3.us-east-1.amazonaws.com
      access_key: <access-key>           # Or use IAM role
      secret_key: <secret-key>
      insecure: false
      hedge_requests_at: 400ms
      hedge_requests_up_to: 2
```

### GCS Storage

```yaml
storage:
  trace:
    backend: gcs
    gcs:
      bucket_name: my-tempo-bucket
      prefix: tempo/                     # Optional
      # Uses Workload Identity or service account
```

## Limits Configuration

### Global Limits

```yaml
overrides:
  defaults:
    # Ingestion limits
    ingestion_rate_limit_bytes: 15000000    # 15MB/s
    ingestion_burst_size_bytes: 20000000    # 20MB burst
    max_bytes_per_trace: 5000000            # 5MB per trace
    max_traces_per_user: 0                  # 0 = unlimited

    # Query limits
    max_search_bytes_per_trace: 0           # 0 = unlimited

    # Forwarders
    forwarders: []
```

### Per-Tenant Overrides

```yaml
overrides:
  defaults:
    ingestion_rate_limit_bytes: 15000000

  # Per-tenant overrides
  tenant-a:
    ingestion_rate_limit_bytes: 50000000
    max_bytes_per_trace: 10000000

  tenant-b:
    ingestion_rate_limit_bytes: 5000000
    max_bytes_per_trace: 2000000
```

## Metrics Generator Configuration

```yaml
metrics_generator:
  ring:
    kvstore:
      store: memberlist

  processor:
    service_graphs:
      wait: 10s
      max_items: 10000
      workers: 10
      histogram_buckets: [0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4, 12.8]

    span_metrics:
      histogram_buckets: [0.002, 0.004, 0.008, 0.016, 0.032, 0.064, 0.128, 0.256, 0.512, 1.024, 2.048, 4.096, 8.192, 16.384]
      intrinsic_dimensions:
        service: true
        span_name: true
        span_kind: true
        status_code: true
        status_message: false

    local_blocks:
      block_duration: 5m
      max_live_traces: 100000
      max_block_duration: 1h
      flush_check_period: 10s

  # Storage for WAL
  storage:
    path: /var/tempo/generator/wal
    remote_write:
      - url: http://prometheus:9090/api/v1/write
        send_exemplars: true

  # Collection interval
  collection_interval: 15s

  # Processor selection
  processors:
    - service-graphs
    - span-metrics
    # - local-blocks    # For TraceQL metrics
```

## Multi-Tenancy

```yaml
multitenancy_enabled: true        # Enable multi-tenant mode

# All requests require X-Scope-OrgID header
# Tenant ID is used for:
# - Storage isolation
# - Per-tenant limits
# - Access control (external)
```

## Hash Ring Configuration

### Memberlist (Default)

```yaml
memberlist:
  bind_port: 7946
  join_members:
    - tempo-gossip-ring:7946
  abort_if_cluster_join_fails: false
  max_join_retries: 10
  min_join_backoff: 1s
  max_join_backoff: 1m
```

### Consul

```yaml
ring:
  kvstore:
    store: consul
    consul:
      host: consul:8500
      acl_token: <token>
```

### Etcd

```yaml
ring:
  kvstore:
    store: etcd
    etcd:
      endpoints:
        - etcd:2379
```

## Search Configuration

```yaml
search:
  # Query sharding
  query_backend_after: 15m
  query_ingesters_until: 30m

  # External hedge requests
  external_hedge_requests_at: 8s
  external_hedge_requests_up_to: 2

  # Tag search
  prefer_self: 10                 # Prefer recent data weight
```

## Usage Report

```yaml
usage_report:
  reporting_enabled: true         # Send anonymous usage stats
```

## Important Default Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| HTTP Port | 3200 | HTTP listen port |
| gRPC Port | 9095 | gRPC listen port |
| Rate Limit | 15MB/s | Ingestion rate limit |
| Burst Size | 20MB | Ingestion burst |
| Max Trace Size | 5MB | Maximum trace size |
| Trace Idle Period | 5s | Flush to WAL after idle |
| Block Retention | 336h (14d) | Block expiration |
| Max Block Size | 500MB | Ingester block size |
| Replication Factor | 3 | Number of ingester replicas |
| Query Timeout | 30s | Default query timeout |

## Helm Values Mapping

### Monolithic Mode

```yaml
# tempo chart values.yaml
tempo:
  server:
    http_listen_port: 3200

  storage:
    trace:
      backend: azure
      azure:
        container_name: tempo-traces
        storage_account_name: mystorageaccount

  ingester:
    trace_idle_period: 5s
    max_block_duration: 30m

  overrides:
    defaults:
      ingestion_rate_limit_bytes: 15000000
```

### Distributed Mode

```yaml
# tempo-distributed chart values.yaml
tempo:
  structuredConfig:
    storage:
      trace:
        backend: azure
        azure:
          container_name: tempo-traces

    ingester:
      trace_idle_period: 5s

    compactor:
      compaction:
        block_retention: 336h

    overrides:
      defaults:
        ingestion_rate_limit_bytes: 15000000
```

## Environment Variable Expansion

Enable environment variable substitution:

```yaml
# Helm values
extraArgs:
  config.expand-env: true

extraEnv:
  - name: AZURE_STORAGE_KEY
    valueFrom:
      secretKeyRef:
        name: tempo-secret
        key: storage-key

# In config
storage:
  trace:
    azure:
      storage_account_key: ${AZURE_STORAGE_KEY}
```

## Configuration Validation

```bash
# Validate configuration
tempo -config.file=/etc/tempo/config.yaml -config.verify-flags

# Print resolved configuration
tempo -config.file=/etc/tempo/config.yaml -print-config-stderr
```

## Common Configuration Patterns

### Development

```yaml
storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces

ingester:
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: 24h
```

### Production (Azure)

```yaml
storage:
  trace:
    backend: azure
    azure:
      container_name: tempo-traces
      storage_account_name: prodstorageaccount
      use_federated_token: true
      hedge_requests_at: 400ms
      hedge_requests_up_to: 2

ingester:
  lifecycler:
    ring:
      replication_factor: 3

compactor:
  compaction:
    block_retention: 336h

overrides:
  defaults:
    ingestion_rate_limit_bytes: 50000000
    max_bytes_per_trace: 10000000
```

### High-Throughput

```yaml
distributor:
  ring:
    kvstore:
      store: memberlist

ingester:
  concurrent_flushes: 8
  max_block_bytes: 1073741824    # 1GB

querier:
  max_concurrent_queries: 50

overrides:
  defaults:
    ingestion_rate_limit_bytes: 600000000  # 600MB/s
    ingestion_burst_size_bytes: 800000000
```

## Storage Architecture

Tempo stores all trace data in object storage with the following structure:

```
<bucketname>/<tenantID>/<blockID>/
├── meta.json
├── index
├── data
├── bloom_0
├── bloom_1
└── bloom_n
```

## Apache Parquet Block Format

**Default format** (since Tempo 2.0): vParquet4

**Benefits:**

- 5-10x less data pulled per query
- Search speed: 300 GB/s (vs 40-50 GB/s with legacy format)
- Selective column retrieval
- Required for TraceQL

**Dedicated Columns:**

- Well-known attributes stored in dedicated columns for faster retrieval
- All other attributes stored in generic key/value maps

## Object Store Backends

### AWS S3

**Required IAM Permissions:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-tempo-bucket",
        "arn:aws:s3:::my-tempo-bucket/*"
      ]
    }
  ]
}
```

**Configuration:**

```yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: my-tempo-bucket
      region: us-east-1
      endpoint: s3.us-east-1.amazonaws.com
      # Option 1: IAM Role (Recommended)
      # Use service account with IAM role annotation
      # Option 2: Access Keys
      access_key: ${AWS_ACCESS_KEY_ID}
      secret_key: ${AWS_SECRET_ACCESS_KEY}
      insecure: false

# For EKS with IRSA
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/tempo-role
```

**SSE-KMS Encryption:**

```yaml
storage:
  trace:
    s3:
      sse:
        type: SSE-KMS
        kms_key_id: <kms-key-arn>
```

### Azure Blob Storage

**Authentication Methods:**

#### 1. Workload Identity Federation (Recommended)

```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: <identity-client-id>

podLabels:
  azure.workload.identity/use: "true"

storage:
  trace:
    backend: azure
    azure:
      container_name: tempo-traces
      storage_account_name: mystorageaccount
      use_federated_token: true
      endpoint_suffix: blob.core.windows.net
```

#### 2. User-Assigned Managed Identity

```yaml
storage:
  trace:
    backend: azure
    azure:
      container_name: tempo-traces
      storage_account_name: mystorageaccount
      use_managed_identity: true
      user_assigned_id: <identity-client-id>
```

#### 3. Account Key (Development Only)

```yaml
storage:
  trace:
    backend: azure
    azure:
      container_name: tempo-traces
      storage_account_name: mystorageaccount
      storage_account_key: ${AZURE_STORAGE_KEY}

extraArgs:
  config.expand-env: true

extraEnv:
  - name: AZURE_STORAGE_KEY
    valueFrom:
      secretKeyRef:
        name: azure-storage-secret
        key: account-key
```

#### 4. SAS Token

```yaml
storage:
  trace:
    backend: azure
    azure:
      container_name: tempo-traces
      storage_account_name: mystorageaccount
      sas_token: ${AZURE_SAS_TOKEN}
```

**Required RBAC Role:**

- `Storage Blob Data Contributor` on the storage account

**Azure Configuration Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `storage_account_name` | String | Azure storage account name |
| `container_name` | String | Container for trace data |
| `prefix` | String | Optional path prefix |
| `endpoint_suffix` | String | Default: `blob.core.windows.net` |
| `hedge_requests_at` | Duration | Threshold for hedged requests |
| `hedge_requests_up_to` | Integer | Max hedged requests |

**Azurite Emulator (Local Development):**

```yaml
storage:
  trace:
    azure:
      endpoint_suffix: azurite-host.svc.cluster.local:10000
      # Tempo auto-detects non-blob endpoints
```

### Google Cloud Storage

**Configuration:**

```yaml
storage:
  trace:
    backend: gcs
    gcs:
      bucket_name: my-tempo-bucket
      prefix: tempo-traces/  # Optional
      # Uses Workload Identity or service account JSON
      service_account: |
        ${GCS_SERVICE_ACCOUNT_JSON}
```

**For GKE with Workload Identity:**

```yaml
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: tempo@project.iam.gserviceaccount.com
```

### MinIO (On-Premises)

```yaml
storage:
  trace:
    backend: s3
    s3:
      endpoint: minio.minio.svc:9000
      bucket: tempo-traces
      access_key: ${MINIO_ACCESS_KEY}
      secret_key: ${MINIO_SECRET_KEY}
      insecure: true  # Set false for TLS
```

### Local Filesystem (Development Only)

```yaml
storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces
    wal:
      path: /var/tempo/wal
```

**Limitations:**

- NOT production-supported
- Single-node only
- No persistence across pod restarts

## Retention Configuration

**Enable Retention:**

```yaml
compactor:
  compaction:
    block_retention: 336h  # 14 days (minimum: 1h)
```

**Compactor Configuration:**

```yaml
compactor:
  config:
    compaction:
      compaction_window: 1h
      block_retention: 336h        # 14 days
      max_block_bytes: 107374182400  # ~107GB
      compacted_block_retention: 1h
```

## Write Ahead Log (WAL)

**Purpose:** Records incoming data for crash recovery.

**Configuration:**

```yaml
ingester:
  config:
    trace_idle_period: 5s    # Flush to WAL after idle
    max_block_duration: 30m  # Max time before flush
    complete_block_timeout: 1h

storage:
  trace:
    wal:
      path: /var/tempo/wal
      encoding: snappy
```

**Requirements:**

- Use StatefulSets with persistent volumes
- Each ingester must have unique WAL directory
- Expect ~10-15GB disk usage per ingester

## Caching

### Background Cache

```yaml
storage:
  trace:
    cache: memcached
    memcached:
      host: tempo-memcached.observability.svc
      service: memcached-client
      timeout: 500ms
      max_idle_conns: 16
```

### Search Cache

```yaml
storage:
  trace:
    search:
      cache_control:
        footer: true
        column_index: true
        offset_index: true
```

## Bloom Filters and Indexes

**Configuration:**

```yaml
storage:
  trace:
    blocklist_poll: 5m
    blocklist_poll_fallback: true

    # Bloom filter settings
    bloom_filter_false_positive: 0.01
    bloom_filter_shard_size_bytes: 102400  # 100KiB

    # Index settings
    index_downsample_bytes: 1048576  # 1MiB
```

## Performance Optimization

### Hedging Requests

Reduce long-tail latency by sending parallel requests:

```yaml
storage:
  trace:
    azure:
      hedge_requests_at: 400ms
      hedge_requests_up_to: 2
    s3:
      hedge_requests_at: 400ms
      hedge_requests_up_to: 2
```

### Block List Polling

```yaml
storage:
  trace:
    blocklist_poll: 5m
    blocklist_poll_jitter_ms: 500
    blocklist_poll_tenant_index_builders: 1
```

## Azure Lifecycle Management

Automatically delete old data:

```json
{
  "rules": [
    {
      "enabled": true,
      "name": "tempo-cleanup",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "delete": {
              "daysAfterModificationGreaterThan": 60
            }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["tempo-traces/"]
        }
      }
    }
  ]
}
```

## Deployment Mode Considerations

### Monolithic Mode

- Apply storage config under `tempo.storage.trace`

### Distributed Mode

- Apply at root `storage.trace` level
- Propagate `extraArgs` and `extraEnv` to all services:
  - distributor
  - ingester
  - querier
  - queryFrontend
  - compactor

```yaml
# Distributed mode - propagate env vars
distributor:
  extraArgs:
    config.expand-env: true
  extraEnv:
    - name: AZURE_STORAGE_KEY
      valueFrom:
        secretKeyRef:
          name: azure-secret
          key: key

ingester:
  extraArgs:
    config.expand-env: true
  extraEnv:
    - name: AZURE_STORAGE_KEY
      valueFrom:
        secretKeyRef:
          name: azure-secret
          key: key

# Repeat for querier, queryFrontend, compactor
```

# Restart pod to refresh token

```bash
kubectl delete pod -n observability <tempo-pod>
```

### Compactor Issues

```bash
# Check compactor logs
kubectl logs -n observability -l app.kubernetes.io/component=compactor --tail=200

# Verify compactor is running
kubectl get pods -n observability -l app.kubernetes.io/component=compactor
```

## Breaking Changes

### Tempo 2.9+

- Review release notes before upgrading

### Port Migration (Chart v1.21.1+)

- Default HTTP port changed from 3100 to 3200

### Configuration Structure (Chart v1.19.0+)

- `overrides` structure reorganized

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
