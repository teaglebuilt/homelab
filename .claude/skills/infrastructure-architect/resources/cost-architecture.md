# Cost Architecture

Guide to designing cost-effective infrastructure with FinOps principles, TCO analysis, and optimization strategies.

## Cost-Aware Design Principles

### 1. Right-Sizing

**Don't overprovision:**
```
Actual usage: 2 vCPU, 4 GB RAM
❌ Provisioned: 8 vCPU, 32 GB RAM  ($500/month)
✅ Right-sized: 4 vCPU, 8 GB RAM   ($200/month)
Savings: 60%
```

### 2. Use Appropriate Storage Tiers

```
Hot data (frequent access):    S3 Standard      $0.023/GB
Warm data (weekly access):     S3 IA            $0.0125/GB  (46% cheaper)
Cold data (monthly access):    S3 Glacier       $0.004/GB   (83% cheaper)
Archive (yearly access):       S3 Deep Archive  $0.00099/GB (96% cheaper)
```

### 3. Auto-Scaling

**Scale down when not needed:**
```
Business hours (8am-6pm): 20 servers
Off hours (6pm-8am):      5 servers

Cost with no scaling:  20 × 24h × $0.10 = $48/day
Cost with scaling:     (20 × 10h + 5 × 14h) × $0.10 = $27/day
Savings: 44%
```

### 4. Serverless for Variable Workloads

```
Traditional (always-on server): $100/month (even with 0 requests)
Serverless (pay-per-invocation): $0-$100/month (scales with usage)

Good for: Batch jobs, webhooks, sporadic APIs
Bad for: High-throughput, predictable load
```

---

## Total Cost of Ownership (TCO)

### TCO Components

```
Infrastructure Costs:
- Compute (EC2, ECS, Lambda)
- Storage (S3, EBS)
- Network (data transfer, load balancers)
- Database (RDS, DynamoDB)

Operational Costs:
- Engineer time (management, debugging)
- Monitoring/observability tools
- Backup/DR infrastructure
- Support contracts

Hidden Costs:
- Data transfer (inter-region, internet egress)
- API calls (S3 PUT/GET)
- Snapshot storage
- DNS queries
```

### TCO Example

**Option A: Self-Managed Kubernetes on EC2**
```
Infrastructure:
- 10 × m5.xlarge nodes: $1,400/month
- EBS volumes: $200/month
- Load balancer: $50/month
- Data transfer: $300/month
Total: $1,950/month

Operational:
- 0.5 engineer (management): $7,500/month
- Monitoring (Datadog): $400/month
Total: $7,900/month

TCO: $9,850/month
```

**Option B: Managed EKS + Fargate**
```
Infrastructure:
- EKS cluster: $75/month
- Fargate vCPU/memory: $2,100/month
- Load balancer: $50/month
- Data transfer: $300/month
Total: $2,525/month

Operational:
- 0.2 engineer (less management): $3,000/month
- Monitoring: $400/month
Total: $3,400/month

TCO: $5,925/month (40% cheaper despite higher infrastructure cost)
```

---

## Cost Optimization Strategies

### Reserved Instances & Savings Plans

**Baseline (always-running) workloads:**
```
On-Demand:       $0.192/hour × 730 hours = $140/month
Reserved (1yr):  $0.123/hour × 730 hours = $90/month  (36% savings)
Reserved (3yr):  $0.082/hour × 730 hours = $60/month  (57% savings)

Recommendation:
- Cover 60-70% of baseline with Reserved
- Use On-Demand for burst capacity
```

**Savings Plans (more flexible than Reserved):**
```
Commit to $500/month compute spend
→ Get ~30-40% discount on all compute (EC2, Lambda, Fargate)
→ Applies automatically to any matching usage
```

---

### Spot Instances

**Non-critical, fault-tolerant workloads:**
```
On-Demand: $0.192/hour
Spot:      $0.058/hour  (70% discount)

Good for:
- Batch processing
- CI/CD workers
- Development environments
- Stateless web servers (with ASG)

Bad for:
- Databases
- Stateful applications
- Jobs that can't tolerate interruption
```

```yaml
# EKS with Spot instances
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
  limits:
    resources:
      cpu: 1000
      memory: 1000Gi
  ttlSecondsAfterEmpty: 30  # Terminate idle nodes
```

---

### Data Transfer Costs

**Expensive and often overlooked:**

```
AWS Inter-Region Transfer:
us-east-1 → eu-west-1: $0.02/GB

AWS to Internet:
First 10 TB: $0.09/GB
Next 40 TB:  $0.085/GB

Example: 10 TB/month egress
= 10,000 GB × $0.09 = $900/month
```

**Optimization:**
1. **Use CloudFront CDN** - Reduces origin egress
2. **Cache aggressively** - Fewer origin requests
3. **VPC Peering** - Free in same region
4. **Compress data** - Gzip reduces volume 60-80%

```typescript
// Enable compression
app.use(compression({
  level: 6,  // Balance speed vs compression ratio
  threshold: 1024,  // Only compress > 1KB
}));

// Before: 100 KB response × 1M requests = 100 GB egress = $9
// After:  30 KB response × 1M requests = 30 GB egress = $2.70
// Savings: 70%
```

---

### Database Cost Optimization

**RDS vs Self-Managed:**
```
RDS db.r5.xlarge (managed):
- Instance: $360/month
- Storage (1TB SSD): $115/month
- Backups (500GB): $50/month
- Multi-AZ: +100% = $1,050/month
Total: $1,050/month

Self-Managed on EC2:
- r5.xlarge: $140/month
- EBS (1TB SSD): $115/month
- Snapshot backups: $25/month
- Replica: $280/month
- Engineer time (0.3 FTE): $4,500/month
Total: $5,060/month

RDS is 79% cheaper including operational costs!
```

**DynamoDB On-Demand vs Provisioned:**
```
Predictable workload (1M reads, 100K writes daily):
On-Demand:
- Reads: 1M × $0.25/million = $0.25/day = $7.50/month
- Writes: 100K × $1.25/million = $0.125/day = $3.75/month
Total: $11.25/month

Provisioned:
- Reads: 12 RCU × $0.00013/hour × 730 = $1.14/month
- Writes: 2 WCU × $0.00065/hour × 730 = $0.95/month
Total: $2.09/month

Savings: 81% with provisioned (if predictable)
```

---

### Storage Lifecycle Policies

```terraform
# S3 intelligent tiering
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    # After 30 days: move to Infrequent Access (50% cheaper)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # After 90 days: move to Glacier (83% cheaper)
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # After 365 days: delete
    expiration {
      days = 365
    }
  }
}

# Cost Impact:
# 100 GB stored for 1 year
# All Standard: 100 × 12 × $0.023 = $276/year
# With lifecycle: ~$50/year (82% savings)
```

---

## Cost Monitoring & Alerting

### Cost Anomaly Detection

```terraform
# AWS Cost Anomaly Detection
resource "aws_ce_anomaly_monitor" "main" {
  name              = "cost-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "alert" {
  name      = "cost-anomaly-alert"
  frequency = "DAILY"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.main.arn
  ]

  subscriber {
    type    = "EMAIL"
    address = "finance@example.com"
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = ["500"]  # Alert if anomaly > $500
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }
}
```

### Cost Allocation Tags

```terraform
# Tag all resources for cost tracking
resource "aws_instance" "api" {
  tags = {
    Environment = "production"
    Team        = "backend"
    Service     = "api"
    CostCenter  = "engineering"
  }
}

# Generate cost reports by tag
# Cost by Team, Cost by Service, etc.
```

---

## FinOps Practices

### 1. Showback & Chargeback

**Showback (awareness):**
```
Monthly report:
- Team Backend: $15,000 (60%)
- Team Frontend: $5,000 (20%)
- Team Data: $5,000 (20%)

Share costs to build awareness
```

**Chargeback (accountability):**
```
Each team billed for their infrastructure
→ Incentivizes optimization
```

### 2. Unit Economics

**Cost per user/request:**
```
Monthly costs: $50,000
Monthly active users: 100,000
Cost per user: $0.50

Track over time:
Jan: $0.50/user
Feb: $0.45/user (10% reduction via optimization)
```

### 3. Cost-Performance Ratio

```
CPU utilization vs cost optimization

High utilization (85%): Cost-efficient, but risky (no headroom)
Medium utilization (70%): Balanced (recommended)
Low utilization (30%): Wasteful
```

---

## Architecture Cost Comparisons

### Monolith vs Microservices

**Monolith:**
```
Infrastructure: $2,000/month (simple, fewer services)
Operations: $5,000/month (0.5 engineer)
Total: $7,000/month
```

**Microservices (15 services):**
```
Infrastructure: $6,000/month (more services, load balancers)
Operations: $10,000/month (1 engineer - more complexity)
Total: $16,000/month

Trade-off: 2.3x cost, but better scalability/flexibility
```

### Multi-Region Cost Impact

**Single Region:**
```
Compute: $5,000
Database: $1,000
Total: $6,000/month
```

**Multi-Region (Active-Passive):**
```
Primary compute: $5,000
Primary DB: $1,000
Secondary compute (standby): $1,000
Secondary DB (replica): $500
Data replication: $500
Total: $8,000/month (+33%)
```

**Multi-Region (Active-Active):**
```
Primary compute: $5,000
Primary DB: $1,000
Secondary compute: $5,000
Secondary DB: $1,000
Data transfer: $1,500
Total: $13,500/month (+125%)
```

---

## Cost Optimization Checklist

**Compute:**
- [ ] Right-sized instances (not over-provisioned)
- [ ] Auto-scaling enabled (scale down off-hours)
- [ ] Reserved instances for baseline (30-60% savings)
- [ ] Spot instances for batch workloads (70% savings)
- [ ] Terminate unused resources

**Storage:**
- [ ] Lifecycle policies (archive old data)
- [ ] Delete unused snapshots
- [ ] Use appropriate storage tier (S3 IA, Glacier)
- [ ] Enable compression

**Database:**
- [ ] Right-sized instance
- [ ] Read replicas only if needed
- [ ] Delete old backups beyond retention
- [ ] Use Aurora Serverless v2 for variable load

**Network:**
- [ ] Use CloudFront CDN (reduce egress)
- [ ] VPC peering instead of internet (free intra-region)
- [ ] Compress responses
- [ ] Minimize inter-region transfer

**Monitoring:**
- [ ] Cost anomaly detection enabled
- [ ] Budget alerts configured
- [ ] Tag all resources
- [ ] Monthly cost review meetings

---

## Best Practices

✅ **Tag everything** - Enable cost allocation
✅ **Monitor continuously** - Anomaly detection
✅ **Right-size** - Don't overprovision
✅ **Auto-scale** - Scale down when idle
✅ **Use managed services** - Lower operational cost
✅ **Reserve baseline** - 30-60% discount
✅ **Delete unused** - Old snapshots, volumes
✅ **Review monthly** - Optimize continuously

## Anti-Patterns

❌ **Always-on instances** - No auto-scaling
❌ **No tagging** - Can't track costs
❌ **Over-provisioning** - "Just in case" sizing
❌ **Ignoring data transfer** - Huge surprise bills
❌ **No cost ownership** - Teams unaware of spend
❌ **Premature optimization** - Optimizing before measuring

---

**Related Resources:**
- capacity-planning.md - Right-sizing infrastructure
- multi-region-design.md - Multi-region cost implications
- disaster-recovery.md - DR cost tiers
