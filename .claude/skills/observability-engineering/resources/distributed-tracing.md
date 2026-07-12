# Distributed Tracing

Guide to implementing distributed tracing with Jaeger, Tempo, and other tools.

## What is Distributed Tracing?

Tracks requests as they flow through microservices:

```
User Request
  ↓
API Gateway (span 1) ──→ 50ms
  ↓
User Service (span 2) ──→ 20ms
  ↓
Database (span 3) ──────→ 80ms
Total: 150ms

Trace shows:
- Total request time: 150ms
- Database was bottleneck: 80ms (53%)
```

## Jaeger Setup

```yaml
# docker-compose.yml
version: '3'
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"  # UI
      - "14268:14268"  # HTTP collector
      - "6831:6831/udp"  # Agent
```

## Instrumentation

```typescript
import { trace, context, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('user-service');

async function getUser(userId: string) {
  const span = tracer.startSpan('getUser');
  span.setAttribute('user.id', userId);

  try {
    const user = await db.users.findUnique({ where: { id: userId } });
    span.setStatus({ code: SpanStatusCode.OK });
    return user;
  } catch (error) {
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message
    });
    span.recordException(error);
    throw error;
  } finally {
    span.end();
  }
}
```

## Trace Propagation

```typescript
// Service A creates trace
const span = tracer.startSpan('callServiceB');
const headers = {};

// Inject trace context into headers
propagation.inject(context.active(), headers);

// Call Service B with trace context
await fetch('http://service-b/api', { headers });

span.end();

// Service B continues the trace
const extractedContext = propagation.extract(context.active(), req.headers);
const span = tracer.startSpan('handleRequest', {}, extractedContext);
```

## Best Practices

✅ Trace critical paths
✅ Add meaningful attributes
✅ Sample high-volume endpoints
✅ Keep span names consistent
✅ Record errors in spans

---

**Related Resources:**
- opentelemetry.md - OTEL implementation
- correlation-strategies.md - Trace ID usage
