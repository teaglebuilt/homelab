# Observability Cost Optimization

Guide to managing observability costs through sampling, retention policies, and efficient practices.

## Sampling Strategies

### Head-Based Sampling
```typescript
// Sample 10% of traces
const sampler = new TraceIdRatioBasedSampler(0.1);

const sdk = new NodeSDK({
  sampler,
  // ...
});

// Pros: Simple, predictable cost
// Cons: May miss rare errors
```

### Tail-Based Sampling
```typescript
// Sample based on outcome (keep all errors, 1% of success)
const tailSampler = {
  shouldSample: (span) => {
    if (span.status.code === SpanStatusCode.ERROR) {
      return true;  // Keep all errors
    }
    if (span.attributes['http.status_code'] >= 500) {
      return true;  // Keep server errors
    }
    return Math.random() < 0.01;  // 1% of successful requests
  },
};

// Pros: Keeps important traces, lower cost
// Cons: More complex
```

## Retention Policies

```
Hot storage (recent, fast):
- Traces: 7 days
- Logs: 14 days
- Metrics: 30 days

Warm storage (archived, slower):
- Traces: 30 days
- Logs: 90 days
- Metrics: 1 year

Cold storage (compliance):
- Logs: 7 years (compressed)
```

## Cost Breakdown

```
Typical observability costs (10 services, 1M RPM):

DataDog:
- APM: $2,000/month (100M spans)
- Logs: $1,500/month (500 GB)
- Metrics: $500/month
- Total: $4,000/month

Self-Hosted (Jaeger + Loki + Prometheus):
- Infrastructure: $800/month
- Maintenance: $3,000/month (0.3 engineer)
- Total: $3,800/month

Savings with optimization:
- 90% sampling: $400 APM (vs $2,000)
- 30-day retention: $500 logs (vs $1,500)
- Total: $1,400/month (65% reduction)
```

## Optimization Strategies

### 1. Sample Aggressively
```
High-volume endpoints: 1% sample rate
Low-volume endpoints: 100% sample rate
Errors: Always keep
```

### 2. Reduce Log Volume
```typescript
// Don't log every request
if (req.path !== '/health' && req.path !== '/metrics') {
  logger.info('Request', { method: req.method, path: req.path });
}

// Sample logs
if (Math.random() < 0.1) {  // 10% of logs
  logger.debug('Debug info', { ...details });
}
```

### 3. Optimize Metric Cardinality
```typescript
// ❌ Bad: Unbounded cardinality
requestCounter.add(1, { userId: req.userId });  // Millions of users

// ✅ Good: Bounded cardinality
requestCounter.add(1, { endpoint: req.route });  // ~100 endpoints
```

### 4. Use Cheaper Storage
```
S3 Glacier for old logs: $0.004/GB (vs $0.023/GB Standard)
83% cheaper for infrequently accessed data
```

## Monitoring Observability Costs

```typescript
// Track observability data volume
observabilityCostGauge.set(dailySpanCount * 0.0001);  // $0.0001 per span

// Alert on cost spikes
if (dailyObservabilityCost > threshold) {
  alert('Observability costs exceeded budget');
}
```

## Best Practices

✅ Sample high-volume endpoints
✅ Always keep errors
✅ Set aggressive retention policies
✅ Reduce metric cardinality
✅ Use cheaper storage tiers
✅ Monitor observability costs

---

**Related Resources:**
- distributed-tracing.md - Sampling implementation
- logs-aggregation.md - Log retention
