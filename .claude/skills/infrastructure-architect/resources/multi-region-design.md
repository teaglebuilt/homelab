# Multi-Region Design

Comprehensive guide to designing multi-region architectures for high availability, disaster recovery, and global performance.

## Why Multi-Region?

**Primary Drivers:**
1. **High Availability** - Survive regional outages
2. **Disaster Recovery** - RTO/RPO requirements
3. **Global Performance** - Reduce latency for users worldwide
4. **Compliance** - Data residency requirements
5. **Business Continuity** - Critical applications

## Architecture Patterns

### 1. Active-Passive (Warm Standby)

**Description:**
Primary region handles all traffic. Secondary region on standby with replicated data.

**Diagram:**
```
┌─────────────────────┐        ┌─────────────────────┐
│   Region A (Primary)│        │ Region B (Secondary)│
│                     │        │                     │
│   ┌─────────────┐   │        │   ┌─────────────┐   │
│   │ Application │◄──┼────────┼──►│ Application │   │
│   │  (Active)   │   │  Data  │   │  (Standby)  │   │
│   └──────┬──────┘   │  Repl  │   └─────────────┘   │
│          │          │        │                     │
│   ┌──────▼──────┐   │        │   ┌─────────────┐   │
│   │  Database   │───┼────────┼──►│  Database   │   │
│   │  (Primary)  │   │ Async  │   │  (Replica)  │   │
│   └─────────────┘   │        │   └─────────────┘   │
└─────────────────────┘        └─────────────────────┘
         100%                           0%
       Traffic                        Traffic
```

**When to Use:**
- RTO: 5-30 minutes acceptable
- Cost optimization (secondary idle)
- Simple failover needed

**Implementation:**
```yaml
# Route 53 health check and failover
resource "aws_route53_health_check" "primary" {
  fqdn              = "api.primary-region.example.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  # Primary region (active)
  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }
  health_check_id = aws_route53_health_check.primary.id
  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_failover" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  # Secondary region (standby)
  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }
  alias {
    name                   = aws_lb.secondary.dns_name
    zone_id                = aws_lb.secondary.zone_id
    evaluate_target_health = true
  }
}
```

**Pros:**
- ✅ Lower cost (secondary mostly idle)
- ✅ Simple to implement
- ✅ Data always available in secondary

**Cons:**
- ❌ Slower failover (5-30 minutes)
- ❌ Wasted capacity in secondary
- ❌ Manual failover often required

**Cost Estimate:**
- Primary: 100% of single-region cost
- Secondary: 30-50% (data replication + standby compute)
- **Total: ~130-150% of single-region**

---

### 2. Active-Active (Hot-Hot)

**Description:**
Multiple regions actively handle traffic simultaneously.

**Diagram:**
```
          ┌─────────────────┐
          │   Global Load   │
          │    Balancer     │
          │   (Route 53)    │
          └────────┬────────┘
                   │
        ┏━━━━━━━━━━┻━━━━━━━━━━┓
        ┃                     ┃
┌───────▼────────┐    ┌───────▼────────┐
│  Region A      │    │  Region B      │
│  ┌──────────┐  │    │  ┌──────────┐  │
│  │Application│ │    │  │Application│ │
│  │ (Active) │  │    │  │ (Active) │  │
│  └─────┬────┘  │    │  └─────┬────┘  │
│  ┌─────▼────┐  │    │  ┌─────▼────┐  │
│  │Database  │◄─┼────┼─►│Database  │  │
│  │(Primary) │  │ Bi │  │(Primary) │  │
│  └──────────┘  │ Dir│  └──────────┘  │
└────────────────┘ Sync└────────────────┘
      50%                     50%
    Traffic                 Traffic
```

**When to Use:**
- RTO: < 5 minutes required
- Global user base
- High availability critical
- Cost less of a concern

**Implementation:**
```typescript
// DynamoDB global tables (active-active)
resource "aws_dynamodb_table" "users" {
  name           = "users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  # Enable global tables
  replica {
    region_name = "us-east-1"
  }

  replica {
    region_name = "eu-west-1"
  }

  replica {
    region_name = "ap-southeast-1"
  }

  # Conflict resolution: last-writer-wins
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

// Route 53 latency-based routing
resource "aws_route53_record" "api_us" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  set_identifier = "us-east-1"
  latency_routing_policy {
    region = "us-east-1"
  }
  alias {
    name    = aws_lb.us_east_1.dns_name
    zone_id = aws_lb.us_east_1.zone_id
  }
}

resource "aws_route53_record" "api_eu" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  set_identifier = "eu-west-1"
  latency_routing_policy {
    region = "eu-west-1"
  }
  alias {
    name    = aws_lb.eu_west_1.dns_name
    zone_id = aws_lb.eu_west_1.zone_id
  }
}
```

**Pros:**
- ✅ Fastest failover (seconds)
- ✅ Optimal user latency (geo-routing)
- ✅ Full capacity utilization
- ✅ No wasted resources

**Cons:**
- ❌ Higher cost (2x infrastructure)
- ❌ Data consistency complexity
- ❌ Cross-region data transfer costs
- ❌ Difficult to test

**Cost Estimate:**
- Region A: 100% of single-region
- Region B: 100% of single-region
- Data transfer: 10-20% additional
- **Total: ~210-220% of single-region**

---

### 3. Read Replicas (Global Read)

**Description:**
Primary region for writes, multiple regions for reads.

**Diagram:**
```
          Writes (10%)
              │
      ┌───────▼────────┐
      │  Primary Region│
      │   (us-east-1)  │
      │  ┌──────────┐  │
      │  │ Database │  │
      │  │ (Primary)│  │
      │  └────┬─────┘  │
      └───────┼────────┘
              │
        Replication
       ┌──────┼──────┐
       │             │
┌──────▼──────┐ ┌───▼────────┐
│  Read Replica│ │Read Replica│
│  (eu-west-1)│ │(ap-south-1)│
│             │ │            │
│  Reads (45%)│ │Reads (45%) │
└─────────────┘ └────────────┘
```

**When to Use:**
- Read-heavy workloads (90%+ reads)
- Global user base
- Eventual consistency acceptable
- Cost optimization

**Implementation:**
```terraform
# Primary database
resource "aws_db_instance" "primary" {
  identifier = "users-primary"
  region     = "us-east-1"

  engine         = "postgres"
  instance_class = "db.r5.xlarge"

  backup_retention_period = 7
  multi_az                = true
}

# Read replica in Europe
resource "aws_db_instance" "replica_eu" {
  identifier = "users-replica-eu"
  region     = "eu-west-1"

  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = "db.r5.large"  # Can be smaller

  # No backups needed for replica
  backup_retention_period = 0
}

# Read replica in Asia
resource "aws_db_instance" "replica_asia" {
  identifier = "users-replica-asia"
  region     = "ap-southeast-1"

  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = "db.r5.large"

  backup_retention_period = 0
}
```

**Application Code:**
```typescript
// Smart connection routing
const connectionConfig = {
  write: process.env.DATABASE_PRIMARY_URL,
  read: [
    process.env.DATABASE_REPLICA_EU_URL,
    process.env.DATABASE_REPLICA_ASIA_URL,
  ]
};

// Use Prisma read replicas
const prisma = new PrismaClient({
  datasources: {
    db: {
      url: connectionConfig.write
    }
  }
});

// Explicit read from replica
const users = await prisma.$queryRaw`
  SELECT * FROM users WHERE region = 'EU'
` // Automatically routed to nearest replica

// Writes always go to primary
await prisma.user.create({
  data: { name: 'John' }
}); // Routed to primary
```

**Pros:**
- ✅ Lower cost than active-active
- ✅ Improved read performance globally
- ✅ Reduced load on primary

**Cons:**
- ❌ Replication lag (eventual consistency)
- ❌ Writes still centralized
- ❌ Application must handle read-after-write

**Cost Estimate:**
- Primary: 100%
- Replica 1: 50% (smaller instance)
- Replica 2: 50%
- **Total: ~200% of single-region**

---

## Data Replication Strategies

### Synchronous Replication
```
Client → Primary DB → Secondary DB → Client
         (wait)         (wait)       (response)
```
- ✅ Strong consistency
- ❌ Higher latency
- ❌ Availability impact if secondary fails

### Asynchronous Replication
```
Client → Primary DB → Client
         (no wait)    (response)
              ↓
         Secondary DB
         (background)
```
- ✅ Lower latency
- ✅ High availability
- ❌ Potential data loss
- ❌ Eventual consistency

### Comparison:

| Aspect | Synchronous | Asynchronous |
|--------|-------------|--------------|
| Consistency | Strong | Eventual |
| Latency | High (+50-200ms) | Low (no impact) |
| Data Loss Risk | None | Seconds to minutes |
| Availability | Lower | Higher |
| Use Case | Financial | Most applications |

---

## Handling Cross-Region Challenges

### 1. Network Latency

**Problem:** Cross-region latency 50-300ms

**Solutions:**
- Use CDN for static assets
- Cache aggressively at edge
- Async replication
- Regional data partitioning

```typescript
// Regional data partitioning
const userRegion = getUserRegion(userId);

// Route to nearest region
const regionalDB = {
  'US': usEastDB,
  'EU': euWestDB,
  'ASIA': apSouthDB
}[userRegion];

const user = await regionalDB.users.findUnique({
  where: { id: userId }
});
```

### 2. Data Consistency

**Problem:** Distributed data, potential conflicts

**Solutions:**
- Last-writer-wins (simple, lossy)
- Vector clocks (complex, accurate)
- CRDTs (Conflict-Free Replicated Data Types)
- Application-level conflict resolution

```typescript
// Last-writer-wins with timestamp
interface User {
  id: string;
  name: string;
  updatedAt: Date;  // Conflict resolution
  region: string;   // Origin tracking
}

async function resolveConflict(local: User, remote: User) {
  // Simple: most recent wins
  return local.updatedAt > remote.updatedAt ? local : remote;
}
```

### 3. Data Transfer Costs

**AWS Inter-Region Data Transfer:**
- us-east-1 → us-west-2: $0.02/GB
- us-east-1 → eu-west-1: $0.02/GB
- us-east-1 → ap-south-1: $0.08/GB

**Cost Optimization:**
```terraform
# Use VPC peering to reduce costs
resource "aws_vpc_peering_connection" "us_to_eu" {
  vpc_id        = aws_vpc.us_east.id
  peer_vpc_id   = aws_vpc.eu_west.id
  peer_region   = "eu-west-1"

  # Reduces data transfer cost vs public internet
}

# Compress data before transfer
resource "aws_lambda_function" "replicate_with_compression" {
  function_name = "replicate-compressed"

  environment {
    variables = {
      COMPRESSION = "gzip"  # Reduce data volume 60-80%
    }
  }
}
```

---

## Failover Procedures

### Automated Failover (Active-Passive)

```bash
#!/bin/bash
# Automated failover script

# 1. Detect primary region failure
PRIMARY_HEALTH=$(curl -f https://api.us-east-1.example.com/health || echo "FAIL")

if [ "$PRIMARY_HEALTH" == "FAIL" ]; then
  echo "Primary region unhealthy. Initiating failover..."

  # 2. Promote secondary database to primary
  aws rds promote-read-replica \
    --db-instance-identifier users-replica-eu \
    --region eu-west-1

  # 3. Update DNS to point to secondary
  aws route53 change-resource-record-sets \
    --hosted-zone-id Z1234567890ABC \
    --change-batch '{
      "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "api.example.com",
          "Type": "A",
          "SetIdentifier": "failover",
          "Failover": "PRIMARY",
          "AliasTarget": {
            "HostedZoneId": "Z0987654321XYZ",
            "DNSName": "api.eu-west-1.example.com",
            "EvaluateTargetHealth": true
          }
        }
      }]
    }'

  # 4. Notify team
  aws sns publish \
    --topic-arn arn:aws:sns:us-east-1:123456789:failover-alerts \
    --message "Failover to eu-west-1 completed"

  echo "Failover complete. Traffic now routing to eu-west-1."
fi
```

### Manual Failover Runbook

```markdown
# Multi-Region Failover Runbook

## Pre-Failover Checklist
- [ ] Confirm primary region is truly down (not false alarm)
- [ ] Verify secondary region is healthy
- [ ] Check replication lag < 5 minutes
- [ ] Notify stakeholders (Slack #incidents)
- [ ] Document start time

## Failover Steps (30 minutes)

### Step 1: Promote Secondary Database (5 min)
```bash
aws rds promote-read-replica \
  --db-instance-identifier users-replica-eu
```

### Step 2: Update Application Config (5 min)
```bash
kubectl set env deployment/api \
  DATABASE_URL=postgresql://eu-west-1.rds.amazonaws.com/users
```

### Step 3: Update DNS (10 min propagation)
```bash
# Update Route 53
aws route53 change-resource-record-sets ...
```

### Step 4: Verify Traffic (5 min)
- Check CloudWatch metrics
- Test critical user flows
- Monitor error rates

### Step 5: Monitor (5 min)
- Watch dashboards for 15 minutes
- Confirm no spike in errors
- Verify latency acceptable

## Post-Failover
- [ ] Update status page
- [ ] Monitor for 4 hours
- [ ] Plan failback when primary restored
- [ ] Post-mortem scheduled
```

---

## Testing Multi-Region Failover

### Chaos Engineering

```yaml
# Chaos Mesh experiment: Simulate region failure
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: region-failure-simulation
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - production
    labelSelectors:
      'region': 'us-east-1'
  direction: both
  duration: '30m'
```

### GameDays

**Quarterly failover testing:**
1. Schedule 2-hour window
2. Announce to team
3. Execute failover procedure
4. Measure RTO/RPO
5. Document learnings
6. Update runbooks

---

**Related Resources:**
- disaster-recovery.md - RTO/RPO planning and backup strategies
- capacity-planning.md - Sizing multi-region infrastructure
- cost-architecture.md - Multi-region cost optimization
