## NVIDIA Invariants (INV-N)

### INV-N001: NIM Requires GPU Node

NIM deployments must be scheduled on nodes with GPU. Use node selectors or taints/tolerations.

```yaml
spec:
  nodeSelector:
    nvidia.com/gpu.present: "true"
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Exists"
      effect: "NoSchedule"
```

**Rationale**: NIM without GPU will fail or fall back to unusable CPU performance.

### INV-N002: Model Configuration in ConfigMap

NIM model selection and parameters must be in ConfigMaps, not hardcoded in deployments.

```yaml
# Correct
apiVersion: v1
kind: ConfigMap
metadata:
  name: nim-config
data:
  model_name: "meta/llama3-8b-instruct"
  max_tokens: "4096"

# Incorrect - hardcoded in deployment
env:
  - name: MODEL
    value: "meta/llama3-8b-instruct"  # Move to ConfigMap
```

**Rationale**: Enables model swapping without deployment changes.

### INV-N005: NIM Observability Enabled

All NIM deployments must have Prometheus metrics and request logging enabled for operational visibility.

```yaml
# Correct - observability enabled
env:
  - name: NIM_ENABLE_METRICS
    value: "true"
  - name: NIM_LOG_REQUESTS
    value: "true"
  - name: OTEL_SERVICE_NAME
    value: "nim-llm"

# Incorrect - no observability
env:
  - name: NIM_LOG_LEVEL
    value: "INFO"
  # Missing NIM_ENABLE_METRICS and NIM_LOG_REQUESTS
```
