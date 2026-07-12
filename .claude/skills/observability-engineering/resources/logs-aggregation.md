# Logs Aggregation

Guide to ELK Stack, Loki, and structured logging for centralized log management.

## ELK Stack (Elasticsearch, Logstash, Kibana)

```yaml
# docker-compose.yml
version: '3'
services:
  elasticsearch:
    image: elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
    ports:
      - "9200:9200"

  logstash:
    image: logstash:8.11.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf

  kibana:
    image: kibana:8.11.0
    ports:
      - "5601:5601"
```

## Structured Logging

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  format: winston.format.json(),
  transports: [
    new winston.transports.Console(),
  ],
});

logger.info('User logged in', {
  userId: 'user-123',
  ipAddress: req.ip,
  traceId: span.spanContext().traceId,  // Correlation
  timestamp: new Date().toISOString(),
});

// Output:
// {"level":"info","message":"User logged in","userId":"user-123","traceId":"abc123",...}
```

## Grafana Loki

```yaml
# loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: s3
      schema: v11
```

```typescript
// Ship logs to Loki
import Pino from 'pino';

const logger = Pino({
  transport: {
    target: 'pino-loki',
    options: {
      batching: true,
      interval: 5,
      host: 'http://loki:3100',
      labels: {
        service: 'my-app',
        env: 'production',
      },
    },
  },
});
```

## Log Levels

```typescript
logger.error('Payment failed', { orderId: '123', error: err.message });
logger.warn('High memory usage', { memoryMB: 850 });
logger.info('User registered', { userId: 'user-456' });
logger.debug('Cache miss', { key: 'user:123' });
```

## Best Practices

✅ Use structured logging (JSON)
✅ Include trace IDs for correlation
✅ Log at appropriate levels
✅ Avoid logging sensitive data (PII, passwords)
✅ Set retention policies (30-90 days)
✅ Index important fields

---

**Related Resources:**
- correlation-strategies.md - Linking logs with traces
- observability-cost-optimization.md - Log retention costs
