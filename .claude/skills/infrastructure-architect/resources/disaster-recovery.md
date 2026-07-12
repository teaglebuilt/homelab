# Disaster Recovery

Comprehensive guide to disaster recovery planning, RTO/RPO requirements, backup strategies, and failover procedures.

## Core Concepts

### RTO (Recovery Time Objective)

**Definition:** Maximum acceptable time to restore service after disaster.

**Examples:**
- RTO = 1 hour: Service must be restored within 1 hour
- RTO = 4 hours: Can tolerate 4-hour outage
- RTO = 24 hours: Next business day acceptable

**Cost Impact:**
- Lower RTO = Higher cost (hot standby, automation)
- Higher RTO = Lower cost (cold backup, manual restore)

### RPO (Recovery Point Objective)

**Definition:** Maximum acceptable data loss measured in time.

**Examples:**
- RPO = 0: Zero data loss (synchronous replication)
- RPO = 15 minutes: Can lose up to 15 minutes of data
- RPO = 24 hours: Daily backups acceptable

**Cost Impact:**
- Lower RPO = Higher cost (frequent backups, replication)
- Higher RPO = Lower cost (infrequent backups)

## DR Tiers

### Tier 0: No DR (Baseline)

**RTO:** Days to weeks
**RPO:** 24+ hours
**Cost:** 0% additional
**Method:** Rebuild from scratch

**Use Case:** Non-critical dev/test environments

---

### Tier 1: Backup & Restore

**RTO:** 12-24 hours
**RPO:** 24 hours
**Cost:** ~10% additional
**Method:** Daily backups to S3/Glacier

```terraform
# S3 backup bucket with lifecycle
resource "aws_s3_bucket" "backups" {
  bucket = "prod-database-backups"
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "archive-old-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }
}

# Daily backup script
resource "aws_cloudwatch_event_rule" "daily_backup" {
  name                = "daily-backup"
  schedule_expression = "cron(0 2 * * ? *)"  # 2 AM daily
}
```

**Pros:** ✅ Low cost, ✅ Simple
**Cons:** ❌ Slow recovery, ❌ High data loss

---

### Tier 2: Pilot Light

**RTO:** 1-4 hours
**RPO:** 1 hour
**Cost:** ~20-30% additional
**Method:** Minimal secondary environment + continuous backup

```
Primary:                Secondary (Minimal):
┌────────────┐         ┌────────────┐
│Full Stack  │   →     │Core DB Only│
│- Web       │  Data   │(Replicated)│
│- API       │  Repl   │            │
│- Database  │         │            │
└────────────┘         └────────────┘
    100%                    5-10%
  Running                 Running

During DR:
Secondary spins up full stack (1-4 hours)
```

**Implementation:**
```yaml
# Terraform: Secondary region (pilot light)
module "pilot_light_region" {
  source = "./modules/region"
  region = "eu-west-1"

  # Only run database replica
  enable_database = true
  enable_compute  = false  # Spin up during DR

  database_config = {
    instance_class = "db.r5.large"
    replica_source = module.primary_region.database_arn
  }
}

# DR automation
resource "aws_lambda_function" "activate_dr" {
  function_name = "activate-disaster-recovery"

  # Spins up compute when triggered
  environment {
    variables = {
      SECONDARY_REGION = "eu-west-1"
      SCALE_UP_COMPUTE = "true"
    }
  }
}
```

**Pros:** ✅ Faster than backup/restore, ✅ Lower cost than warm standby
**Cons:** ❌ Manual intervention, ❌ 1-4 hour RTO

---

### Tier 3: Warm Standby

**RTO:** 5-30 minutes
**RPO:** 5-15 minutes
**Cost:** ~50-70% additional
**Method:** Scaled-down secondary environment always running

```
Primary:                Secondary (Scaled Down):
┌────────────┐         ┌────────────┐
│Full Stack  │   →     │Full Stack  │
│- 10 servers│  Data   │- 2 servers │
│- Large DB  │  Repl   │- Small DB  │
└────────────┘         └────────────┘
    100%                   20-30%
  Running                 Running

During DR:
Secondary scales up to full capacity (5-30 min)
```

**Implementation:**
```yaml
# Auto-scaling group in secondary region
resource "aws_autoscaling_group" "secondary" {
  name     = "api-secondary"
  region   = "eu-west-1"

  # Normal: 2 instances (20% capacity)
  min_size         = 2
  desired_capacity = 2

  # DR: Scale to 10 instances (100% capacity)
  max_size = 10
}

# DR trigger increases desired capacity
resource "aws_autoscaling_policy" "dr_scale_up" {
  name                   = "dr-scale-up"
  autoscaling_group_name = aws_autoscaling_group.secondary.name

  # Scale to 10 when DR activated
  scaling_adjustment     = 8
  adjustment_type        = "ExactCapacity"
}
```

**Pros:** ✅ Fast recovery, ✅ Can test regularly
**Cons:** ❌ Higher cost, ❌ Still requires scaling

---

### Tier 4: Hot Standby (Active-Active)

**RTO:** < 5 minutes (often seconds)
**RPO:** Near-zero
**Cost:** ~100-150% additional
**Method:** Full capacity in multiple regions

```
Primary & Secondary (Both Full):
┌────────────┐         ┌────────────┐
│Full Stack  │  ←→     │Full Stack  │
│- 10 servers│  Data   │- 10 servers│
│- Large DB  │  Sync   │- Large DB  │
└────────────┘         └────────────┘
    50%                    50%
  Traffic                Traffic
```

**Implementation:**
```yaml
# DynamoDB Global Tables (automatic multi-region)
resource "aws_dynamodb_table" "users" {
  name         = "users"
  billing_mode = "PAY_PER_REQUEST"

  replica {
    region_name = "us-east-1"
  }

  replica {
    region_name = "eu-west-1"
  }

  # Automatic conflict resolution
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

# Route 53 health check failover
resource "aws_route53_health_check" "us_east" {
  fqdn = "api.us-east-1.example.com"
  type = "HTTPS"
}

resource "aws_route53_record" "api" {
  name = "api.example.com"
  type = "A"

  # Latency-based routing with failover
  set_identifier = "us-east-1"
  health_check_id = aws_route53_health_check.us_east.id

  latency_routing_policy {
    region = "us-east-1"
  }
}
```

**Pros:** ✅ Fastest recovery, ✅ No user impact, ✅ Global performance
**Cons:** ❌ Highest cost, ❌ Complexity, ❌ Data consistency challenges

---

## Backup Strategies

### Database Backups

```bash
# PostgreSQL automated backups
resource "aws_db_instance" "primary" {
  identifier = "prod-db"

  # Automated backups
  backup_retention_period = 7  # Keep 7 days
  backup_window          = "03:00-04:00"  # 3-4 AM

  # Point-in-time restore
  enabled_cloudwatch_logs_exports = ["postgresql"]
}

# Manual snapshot before major changes
aws rds create-db-snapshot \
  --db-instance-identifier prod-db \
  --db-snapshot-identifier pre-migration-2024-01-15
```

### Application State Backups

```yaml
# Velero: Kubernetes backup
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  template:
    includedNamespaces:
    - production
    storageLocation: aws-s3-backups
    volumeSnapshotLocations:
    - aws-ebs-snapshots
    ttl: 720h  # 30 days retention
```

### 3-2-1 Backup Rule

**Best Practice:**
- **3** copies of data
- **2** different media types
- **1** off-site copy

**Example:**
```
1. Production database (primary)
2. Local replica (secondary)
3. S3 backup (off-site)

Media types:
- EBS volumes (database)
- S3 (object storage)
```

---

## Testing DR Plans

### Monthly DR Drills

```markdown
# DR Drill Checklist

## Preparation (1 week before)
- [ ] Schedule 2-hour window
- [ ] Notify stakeholders
- [ ] Prepare runbook
- [ ] Set up monitoring

## Execution (2 hours)
- [ ] T+0: Simulate primary region failure
- [ ] T+5: Detect failure (monitoring alerts)
- [ ] T+10: Initiate DR procedure
- [ ] T+30: Secondary region serving traffic
- [ ] T+60: Verify functionality
- [ ] T+90: Measure RTO/RPO achieved
- [ ] T+120: Restore to primary

## Post-Drill (1 week after)
- [ ] Document actual RTO/RPO
- [ ] Identify issues encountered
- [ ] Update runbooks
- [ ] Action items assigned
```

### Chaos Engineering

```yaml
# Simulate region failure with Chaos Mesh
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: region-us-east-1-failure
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - production
    labelSelectors:
      'region': 'us-east-1'
  duration: '30m'

  # Isolate entire region
  direction: both
```

---

## DR Runbooks

### Example: Database Failover

```markdown
# Runbook: Promote Read Replica to Primary

## Prerequisites
- Read replica lag < 5 minutes
- Secondary region healthy
- Stakeholders notified

## Steps

### 1. Stop writes to primary (5 min)
```bash
# Set database to read-only
aws rds modify-db-instance \
  --db-instance-identifier prod-db \
  --no-publicly-accessible

# Verify no active connections
psql -h prod-db -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
```

### 2. Promote replica (10 min)
```bash
# Promote replica to standalone
aws rds promote-read-replica \
  --db-instance-identifier prod-db-replica-eu

# Wait for promotion
aws rds wait db-instance-available \
  --db-instance-identifier prod-db-replica-eu
```

### 3. Update application config (5 min)
```bash
# Update connection string
kubectl set env deployment/api \
  DATABASE_URL=postgresql://prod-db-replica-eu.amazonaws.com/myapp

# Rolling restart
kubectl rollout restart deployment/api
```

### 4. Update DNS (15 min)
```bash
# Update Route 53
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456 \
  --change-batch file://dns-update.json

# Verify propagation
dig api.example.com  # Should resolve to new region
```

### 5. Verify (15 min)
- Test critical user flows
- Check error rates in Datadog
- Monitor database connections
- Verify replication lag

## Rollback
If issues arise:
```bash
# Revert DNS
aws route53 change-resource-record-sets ...

# Scale down secondary
kubectl scale deployment/api --replicas=2
```

## Total Time: ~50 minutes
```

---

## Cost Analysis

### DR Cost Comparison

| Tier | RTO | RPO | Additional Cost | Use Case |
|------|-----|-----|-----------------|----------|
| Backup & Restore | 12-24h | 24h | +10% | Non-critical |
| Pilot Light | 1-4h | 1h | +20-30% | Standard |
| Warm Standby | 5-30m | 5-15m | +50-70% | Business-critical |
| Hot Standby | <5m | Near-zero | +100-150% | Mission-critical |

### Example Cost Breakdown (1000 RPS application)

**Single Region:** $5,000/month
```
- Compute: $2,000
- Database: $1,500
- Load balancer: $500
- Data transfer: $500
- Other: $500
```

**With Warm Standby DR:**
```
Primary Region:    $5,000  (100%)
Secondary Region:  $2,500  (50% - scaled down)
Data Replication:  $500    (10%)
------------------------------------
Total:             $8,000  (+60%)
```

---

## Compliance Requirements

### Industry Standards

**Healthcare (HIPAA):**
- Require documented DR plan
- Regular testing (quarterly minimum)
- Encrypted backups
- Audit logs

**Finance (PCI-DSS):**
- RTO < 4 hours for critical systems
- RPO < 1 hour
- Annual DR tests documented

**General (SOC 2):**
- DR plan documented
- Annual testing
- Incident response procedures

---

## Best Practices

✅ **Document everything** - Runbooks, dependencies, contacts
✅ **Test regularly** - Monthly drills, annual GameDays
✅ **Automate failover** - Reduce human error
✅ **Monitor replication lag** - Alert on delays
✅ **Encrypt backups** - At rest and in transit
✅ **Version backups** - Keep multiple restore points
✅ **Test restores** - Verify backups actually work
✅ **Update runbooks** - After every drill or incident

## Anti-Patterns

❌ **Untested DR plan** - "Hope is not a strategy"
❌ **No automation** - Manual failover too slow/error-prone
❌ **Single backup** - No versioning or redundancy
❌ **Forgetting DNS** - TTL too high for failover
❌ **No monitoring** - Can't detect failures quickly
❌ **Ignoring costs** - DR can double infrastructure spend

---

**Related Resources:**
- multi-region-design.md - Active-active and active-passive architectures
- capacity-planning.md - Sizing DR infrastructure
- cost-architecture.md - DR cost optimization
