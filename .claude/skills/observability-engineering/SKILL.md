# Observability Engineering

Deep dive into distributed tracing, APM tools, OpenTelemetry, logs aggregation, and observability best practices.

## Purpose

Enable teams to gain deep visibility into distributed systems with comprehensive observability practices beyond basic monitoring.

## When to Use This Skill

Automatically activates when working on:
- Distributed tracing (Jaeger, Tempo, Zipkin)
- OpenTelemetry instrumentation
- APM tools (DataDog, New Relic, Dynatrace)
- Logs aggregation (ELK, Loki)
- Correlation strategies (trace IDs, unified observability)
- Service mesh observability
- Observability cost optimization

## Quick Start Checklist

- [ ] Instrument application with OpenTelemetry
- [ ] Set up distributed tracing backend
- [ ] Configure logs aggregation
- [ ] Implement correlation (trace IDs across logs/metrics/traces)
- [ ] Set up APM dashboards
- [ ] Configure sampling strategies
- [ ] Monitor observability costs
- [ ] Create SLO-based alerts

## Core Concepts

### Three Pillars of Observability

```
Logs:    What happened (events)
Metrics: How much (counters, gauges)
Traces:  Where time was spent (distributed request flow)
```

### OpenTelemetry

```typescript
import { trace, context } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

async function handleRequest(req, res) {
  const span = tracer.startSpan('handleRequest');

  try {
    const user = await fetchUser(req.userId);
    span.setAttribute('user.id', user.id);

    const result = await processData(user);
    res.json(result);
  } finally {
    span.end();
  }
}
```

## Resource Files

### Tracing & APM
- **[distributed-tracing.md](resources/distributed-tracing.md)** - Jaeger, Tempo, trace propagation, span design
- **[opentelemetry.md](resources/opentelemetry.md)** - OTEL SDK, auto-instrumentation, collectors, exporters
- **[apm-tools.md](resources/apm-tools.md)** - DataDog, New Relic, Dynatrace comparison

### Logs & Correlation
- **[logs-aggregation.md](resources/logs-aggregation.md)** - ELK Stack, Loki, structured logging
- **[correlation-strategies.md](resources/correlation-strategies.md)** - Trace IDs, unified observability

### Cost & Best Practices
- **[observability-cost-optimization.md](resources/observability-cost-optimization.md)** - Sampling, retention, cost strategies

## Best Practices

✅ Use OpenTelemetry (vendor-neutral)
✅ Implement structured logging
✅ Correlate logs/metrics/traces (trace IDs)
✅ Sample intelligently (head-based, tail-based)
✅ Monitor observability costs
✅ Create dashboards from traces
✅ Use service mesh for automatic instrumentation

## Integration Points

- **sre**: Monitoring and alerting
- **devsecops**: Security monitoring
- **platform-engineering**: Service mesh observability
- **backend-dev-guidelines**: Application instrumentation

---
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 SKILL ACTIVATED: observability-engineering
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


**Total Resources:** 6 focused guides on observability engineering
**Focus:** Distributed tracing, OpenTelemetry, APM, cost optimization
