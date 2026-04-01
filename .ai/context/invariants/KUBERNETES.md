## Kubernetes Invariants (INV-K)

### INV-K001: Namespace Per Application

Each application deploys to its own namespace. Never deploy multiple unrelated applications to the same namespace.

```yaml
# Correct - dedicated namespace
apiVersion: v1
kind: Namespace
metadata:
  name: dagster
---
# Dagster resources in dagster namespace

# Incorrect - mixing apps in default namespace
# All apps in namespace: default  # NEVER
```

**Rationale**: Namespace isolation enables RBAC, resource quotas, and clean teardown.

### INV-K002: Resource Limits on All Pods

All pods must have resource requests and limits defined. No unbounded resource consumption.

```yaml
# Correct
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

# Incorrect - no limits
resources: {}  # NEVER
```

**Rationale**: Unbounded pods can starve other workloads and crash nodes.

### INV-K003: GPU Resources Explicitly Requested

Workloads requiring GPU must explicitly request `nvidia.com/gpu` resources. Never assume GPU availability.

```yaml
# Correct
resources:
  limits:
    nvidia.com/gpu: 1

# Incorrect - hoping GPU is available
# No GPU resource specified but expecting GPU access  # NEVER
```

**Rationale**: Without explicit GPU request, pods may schedule on non-GPU nodes or share GPUs unexpectedly.

### INV-K004: Helm Values Override Pattern

Base values in `values.yaml`, environment overrides in `values-<env>.yaml`. Never modify `values.yaml` for environment-specific settings.

```
k8s/apps/dagster/
├── Chart.yaml
├── values.yaml           # Defaults (environment-agnostic)
├── values-dev.yaml       # Dev overrides
└── values-prod.yaml      # Prod overrides (if needed)
```

**Rationale**: Keeps defaults clean and makes environment differences explicit.

### INV-K005: No Hardcoded Images Tags as `latest`

All container images must use specific version tags, never `latest`.

```yaml
# Correct
image: dagster/dagster:1.6.0

# Incorrect
image: dagster/dagster:latest  # NEVER
image: dagster/dagster         # NEVER (implies latest)
```

**Rationale**: `latest` is mutable and causes unpredictable deployments.
