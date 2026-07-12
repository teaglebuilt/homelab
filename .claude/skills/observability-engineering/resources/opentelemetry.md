# OpenTelemetry

Comprehensive guide to OpenTelemetry (OTEL) for vendor-neutral observability instrumentation.

## Setup

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { JaegerExporter } from '@opentelemetry/exporter-jaeger';

const sdk = new NodeSDK({
  traceExporter: new JaegerExporter({
    endpoint: 'http://jaeger:14268/api/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

## Auto-Instrumentation

```typescript
// Auto-instruments: HTTP, Express, Prisma, Redis, etc.
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const instrumentations = getNodeAutoInstrumentations({
  '@opentelemetry/instrumentation-http': {
    ignoreIncomingPaths: ['/health'],
  },
  '@opentelemetry/instrumentation-express': {
    enabled: true,
  },
  '@opentelemetry/instrumentation-prisma': {
    enabled: true,
  },
});
```

## Manual Instrumentation

```typescript
import { trace, SpanKind } from '@opentelemetry/api';

const tracer = trace.getTracer('my-app', '1.0.0');

async function processOrder(order) {
  const span = tracer.startSpan('processOrder', {
    kind: SpanKind.INTERNAL,
    attributes: {
      'order.id': order.id,
      'order.total': order.total,
    },
  });

  try {
    await validateOrder(order);
    await chargePayment(order);
    await shipOrder(order);

    span.setAttribute('order.status', 'completed');
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: SpanStatusCode.ERROR });
    throw error;
  } finally {
    span.end();
  }
}
```

## OTEL Collector

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  batch:
  memory_limiter:
    limit_mib: 1024

exporters:
  jaeger:
    endpoint: jaeger:14250
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

---

**Related Resources:**
- distributed-tracing.md - Tracing concepts
- apm-tools.md - APM integration
