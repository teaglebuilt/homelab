# Correlation Strategies

Guide to correlating logs, metrics, and traces for unified observability.

## Trace ID Propagation

```typescript
import { trace, context } from '@opentelemetry/api';
import { logger } from './logger';

app.use((req, res, next) => {
  const span = trace.getActiveSpan();
  const traceId = span?.spanContext().traceId;

  // Attach trace ID to logger context
  req.logger = logger.child({ traceId });

  next();
});

app.get('/users/:id', async (req, res) => {
  req.logger.info('Fetching user', { userId: req.params.id });
  // Log includes traceId automatically

  const user = await getUser(req.params.id);
  res.json(user);
});
```

## Unified Observability

```
Request arrives:
1. Generate trace ID
2. Create span (trace)
3. Emit metrics (counter, histogram)
4. Log with trace ID

All three pillars linked by trace ID:
- Logs: {"traceId": "abc123", "message": "User fetched"}
- Metrics: user_requests_total{trace_id="abc123"}
- Traces: Trace abc123 shows spans
```

## Correlation in Practice

```typescript
// 1. Start span (tracing)
const span = tracer.startSpan('handleRequest');
const traceId = span.spanContext().traceId;

// 2. Log with trace ID (logs)
logger.info('Processing request', { traceId, userId: req.userId });

// 3. Increment metric (metrics)
requestCounter.add(1, { traceId, endpoint: '/users' });

// 4. All linked by traceId
span.end();
```

## Querying Across Pillars

```
# Find all logs for a trace
traceId:"abc123"

# Find traces with errors
status:error AND service:"user-service"

# Find metrics for specific trace
trace_id="abc123" AND metric="http_request_duration"
```

## Best Practices

✅ Always propagate trace IDs
✅ Include trace IDs in all logs
✅ Use trace IDs in metric labels (when cardinality allows)
✅ Link dashboards (click log → view trace)
✅ Standardize field names (traceId, spanId)

---

**Related Resources:**
- distributed-tracing.md - Trace propagation
- logs-aggregation.md - Structured logging with trace IDs
