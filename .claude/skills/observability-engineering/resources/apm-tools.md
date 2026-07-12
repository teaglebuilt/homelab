# APM Tools

Comparison and guide to Application Performance Monitoring tools: DataDog, New Relic, Dynatrace.

## DataDog

```typescript
// DataDog APM
import tracer from 'dd-trace';
tracer.init({
  service: 'my-app',
  env: 'production',
  version: '1.0.0',
});

// Auto-instruments Express, Prisma, Redis, etc.
```

**Pros:**
- ✅ Easy setup (auto-instrumentation)
- ✅ Unified logs/metrics/traces
- ✅ Great dashboards
- ✅ APM + infrastructure monitoring

**Cons:**
- ❌ Expensive at scale
- ❌ Vendor lock-in

## New Relic

```javascript
// newrelic.js
exports.config = {
  app_name: ['My App'],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  distributed_tracing: {
    enabled: true,
  },
};

// Load before app
require('newrelic');
const app = require('./app');
```

**Pros:**
- ✅ Powerful query language (NRQL)
- ✅ Good for complex architectures
- ✅ Real-time alerting

**Cons:**
- ❌ Steeper learning curve
- ❌ Can be expensive

## Dynatrace

```
Dynatrace OneAgent (auto-deploys)
- No code changes required
- Full-stack monitoring
```

**Pros:**
- ✅ AI-powered root cause analysis
- ✅ Zero-code instrumentation
- ✅ Enterprise features

**Cons:**
- ❌ Most expensive
- ❌ Overkill for small teams

## Cost Comparison

```
Small team (5 services, 1M spans/month):
- DataDog: ~$500/month
- New Relic: ~$400/month
- Dynatrace: ~$800/month

Large team (50 services, 100M spans/month):
- DataDog: ~$5,000/month
- New Relic: ~$4,000/month
- Dynatrace: ~$10,000/month
```

## Open Source Alternative

```
Jaeger + Prometheus + Grafana = $0
(but requires self-hosting and maintenance)
```

---

**Related Resources:**
- observability-cost-optimization.md - Cost management
- opentelemetry.md - Vendor-neutral instrumentation
