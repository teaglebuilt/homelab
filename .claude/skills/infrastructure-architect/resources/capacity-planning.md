# Capacity Planning

Guide to forecasting resource needs, load testing, and scaling strategies for infrastructure.

## Core Concepts

### Capacity Planning Process

```
1. Measure Current → 2. Forecast Growth → 3. Calculate Needs → 4. Add Buffer → 5. Monitor & Adjust
```

**Key Questions:**
- How many users/requests today?
- What's the growth rate?
- What resources are needed per user/request?
- What's our headroom/buffer?

## Measurement & Baselining

### Current Capacity Metrics

```yaml
# Key metrics to track
metrics:
  compute:
    - CPU utilization (%)
    - Memory utilization (%)
    - Network throughput (Gbps)
    - Disk IOPS

  application:
    - Requests per second (RPS)
    - Response time (P50, P95, P99)
    - Error rate (%)
    - Concurrent users

  database:
    - Queries per second (QPS)
    - Connection pool usage
    - Replication lag
    - Storage growth rate
```

### Baseline Example

```
Current Production Metrics (30-day average):
- Traffic: 1,000 RPS
- Users: 50,000 MAU
- CPU: 45% average, 75% peak
- Memory: 60% average, 80% peak
- Database: 500 QPS, 200ms P95
- Storage: 500 GB, growing 20 GB/month
```

## Forecasting Growth

### Linear Growth

```
Simple projection based on historical trend

Formula: Future = Current × (1 + growth_rate) ^ periods

Example:
Current: 1,000 RPS
Growth: 10% monthly
6 months: 1,000 × (1.1)^6 = 1,772 RPS
```

### Seasonal Patterns

```python
# Account for seasonal traffic
baseline = 1000  # RPS

seasonal_multipliers = {
    'Q1': 0.8,   # Post-holiday lull
    'Q2': 1.0,   # Normal
    'Q3': 1.1,   # Summer uptick
    'Q4': 1.5    # Holiday spike
}

# Plan for Q4 peak
peak_capacity_needed = baseline * seasonal_multipliers['Q4']
# = 1,000 × 1.5 = 1,500 RPS minimum
```

### Event-Driven Spikes

```
Product launch, marketing campaigns, sales events

Example: Black Friday planning
- Normal traffic: 1,000 RPS
- Expected spike: 10x = 10,000 RPS
- Duration: 8 hours
- Buffer: 50% = 15,000 RPS capacity needed
```

## Resource Calculation

### Compute Capacity

```python
# Calculate server requirements

# Current state
current_rps = 1000
current_servers = 10
rps_per_server = current_rps / current_servers  # 100 RPS/server

# Future projection (6 months)
future_rps = 2000
headroom = 0.3  # 30% buffer

required_capacity = future_rps * (1 + headroom)  # 2,600 RPS
required_servers = math.ceil(required_capacity / rps_per_server)
# = ceil(2,600 / 100) = 26 servers needed
```

### Database Sizing

```sql
-- Calculate database growth

-- Current: 500 GB
-- Growth: 20 GB/month
-- Timeframe: 12 months

Future storage = 500 + (20 × 12) = 740 GB

-- Add buffer (50%)
Recommended size = 740 × 1.5 = 1,110 GB ≈ 1.1 TB

-- IOPS calculation
-- Current: 1,000 IOPS at 500 QPS
-- Future: 1,000 QPS expected

Future IOPS = 1000 × (1000/500) = 2,000 IOPS
Recommended: 3,000 IOPS (50% buffer)
```

### Network Bandwidth

```
Calculate bandwidth needs

Current:
- 1,000 RPS
- 50 KB average response size
- Bandwidth: 1,000 × 50 KB = 50 MB/s = 400 Mbps

Future (2x traffic):
- 2,000 RPS
- 50 KB response
- Bandwidth: 2,000 × 50 KB = 100 MB/s = 800 Mbps
- With buffer: 1.2 Gbps recommended
```

## Load Testing

### Load Test Types

**1. Baseline Test**
```yaml
# Confirm current capacity
duration: 30m
users: 1000
rps: 1000
expected_p95: <200ms
```

**2. Stress Test**
```yaml
# Find breaking point
duration: 1h
ramp_up: 0 → 5000 users over 30m
hold: 5000 users for 30m
goal: Identify failure threshold
```

**3. Spike Test**
```yaml
# Sudden traffic surge
baseline: 1000 users
spike_to: 5000 users (instant)
duration: 10m
recovery: Back to 1000
goal: Test auto-scaling response
```

**4. Soak Test**
```yaml
# Sustained load over time
users: 2000
duration: 24h
goal: Identify memory leaks, resource exhaustion
```

### k6 Load Test Example

```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '5m', target: 1000 },   // Ramp up
    { duration: '30m', target: 1000 },  // Sustain
    { duration: '10m', target: 3000 },  // Spike
    { duration: '5m', target: 0 },      // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],   // 95% under 500ms
    http_req_failed: ['rate<0.01'],     // <1% errors
  },
};

export default function () {
  const res = http.get('https://api.example.com/users');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time OK': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
```

## Scaling Strategies

### Horizontal Scaling

```yaml
# Auto-scaling configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 10
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale at 70% CPU
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"  # 100 RPS per pod
```

### Vertical Scaling

```terraform
# Database upgrade path
resource "aws_db_instance" "prod" {
  identifier     = "prod-db"

  # Current: db.r5.xlarge (4 vCPU, 32 GB RAM)
  # Future: db.r5.2xlarge (8 vCPU, 64 GB RAM)
  instance_class = "db.r5.2xlarge"

  # Upgrade during maintenance window
  apply_immediately            = false
  preferred_maintenance_window = "sun:03:00-sun:04:00"
}
```

### Caching Strategy

```typescript
// Redis caching to reduce database load
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

async function getUser(userId: string) {
  // Check cache first
  const cached = await redis.get(`user:${userId}`);
  if (cached) {
    return JSON.parse(cached);  // Cache hit - no DB query
  }

  // Cache miss - query database
  const user = await db.users.findUnique({ where: { id: userId } });

  // Store in cache (1 hour TTL)
  await redis.setex(`user:${userId}`, 3600, JSON.stringify(user));

  return user;
}

// Impact: Reduces database queries by 80-90%
// Before: 1,000 QPS → After: 100-200 QPS
```

## Capacity Planning Template

```markdown
# Capacity Plan: Q4 2024

## Current State (Oct 2024)
- Traffic: 1,500 RPS average, 3,000 RPS peak
- Users: 100,000 MAU
- Compute: 20 servers (m5.xlarge)
- Database: db.r5.2xlarge, 1 TB storage
- Cost: $15,000/month

## Growth Forecast
- Expected growth: 50% over Q4 (Black Friday)
- Peak traffic: 6,000 RPS (2x current peak)
- New users: +25,000 (125,000 total MAU)

## Resource Requirements

### Compute
Current capacity: 20 × 150 RPS = 3,000 RPS
Required capacity: 6,000 RPS + 30% buffer = 7,800 RPS
Servers needed: ceil(7,800 / 150) = 52 servers

Action: Update auto-scaling max to 52 (from 30)

### Database
Current QPS: 800 avg, 1,500 peak
Expected QPS: 1,200 avg, 3,000 peak

Action: Upgrade to db.r5.4xlarge
Cost increase: +$1,200/month

### Storage
Current: 1 TB, growing 50 GB/month
6-month projection: 1 TB + (50 GB × 6) = 1.3 TB
With buffer: 2 TB recommended

Action: Increase provisioned storage to 2 TB

## Implementation Timeline
- Week 1 (Nov 1): Load testing (validate 6,000 RPS)
- Week 2 (Nov 8): Database upgrade
- Week 3 (Nov 15): Update auto-scaling config
- Week 4 (Nov 22): Final validation before Black Friday

## Cost Impact
Current: $15,000/month
Peak capacity (Q4): $28,000/month
Post-Q4 (scale down): $18,000/month

## Risks
- Database upgrade may cause brief downtime (plan for 5-10 min)
- Auto-scaling reaction time (~2 minutes) may not handle instant spikes
- Cold start latency if scaling from min to max

## Success Metrics
- P95 latency < 300ms during peak
- Error rate < 0.5%
- Zero downtime events
- Database CPU < 80%
```

## Headroom & Buffer

### Why Headroom Matters

```
No buffer:
100% capacity → Any spike → Overload → Outage

With 30% buffer:
70% normal usage → 100% capacity available for spikes
```

**Recommended Buffers:**
- CPU/Memory: 30% (run at 70% normally)
- Database: 50% (connections, IOPS)
- Network: 40% (burst capacity)
- Storage: 50-100% (growth runway)

## Cost Optimization

### Right-Sizing

```python
# Analyze current utilization
servers = [
    {'name': 'api-1', 'cpu': 25%, 'memory': 40%},
    {'name': 'api-2', 'cpu': 22%, 'memory': 38%},
    # ... 18 more servers averaging 25% CPU
]

# Under-utilized! Can reduce from m5.xlarge → m5.large
# Savings: ~40% per server
# Risk: Less headroom for spikes
# Recommendation: Test with load testing first
```

### Reserved Instances

```
# Baseline capacity (always running)
10 servers × m5.xlarge
- On-Demand: $1,400/month
- Reserved (1-year): $900/month  (36% savings)
- Reserved (3-year): $600/month  (57% savings)

# Burst capacity (auto-scaling)
0-40 servers × m5.xlarge
- Use On-Demand or Spot (60-80% discount)
```

## Monitoring & Alerts

```yaml
# Capacity monitoring alerts
alerts:
  - name: High CPU Utilization
    condition: cpu > 80%
    duration: 5m
    action: Page oncall + trigger auto-scale

  - name: Database Connection Pool Exhaustion
    condition: connections > 90%
    action: Alert team + consider vertical scaling

  - name: Storage Growth
    condition: storage > 80% capacity
    action: Ticket to provision more storage

  - name: Approaching Auto-Scale Limit
    condition: current_replicas > 0.9 × max_replicas
    action: Review if max needs increase
```

---

**Related Resources:**
- multi-region-design.md - Scaling across regions
- disaster-recovery.md - Capacity for DR scenarios
- cost-architecture.md - Cost-effective capacity planning
