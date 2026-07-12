# Infrastructure Architecture - System Design & Architectural Patterns

Comprehensive guide for designing cloud-native, scalable, resilient infrastructure architectures. Covers architectural patterns, multi-region design, disaster recovery, capacity planning, Architecture Decision Records (ADRs), system design principles, and reference architectures.

## Purpose

Enable architects and senior engineers to design robust, scalable infrastructure that meets business requirements while balancing cost, performance, security, and operational complexity.

## When to Use This Skill

Automatically activates when working on:
- Architecture Decision Records (ADRs)
- Multi-region and disaster recovery planning
- System design and architectural patterns
- Capacity planning and scaling strategies
- High-level infrastructure design
- Migration architecture and strategies
- Reference architecture creation
- Cost-aware architectural decisions
- Security architecture design

## Quick Start Checklist

When designing infrastructure architecture:

- [ ] Document architecture decisions (ADRs)
- [ ] Define SLAs, RTO, and RPO requirements
- [ ] Choose appropriate architectural patterns
- [ ] Plan for multi-region/disaster recovery
- [ ] Perform capacity planning and load estimation
- [ ] Design for security (zero trust, defense in depth)
- [ ] Consider cost implications of design choices
- [ ] Plan data architecture (storage, caching, replication)
- [ ] Document reference architecture with diagrams
- [ ] Review with stakeholders and technical leads

## Core Concepts

### Architectural Decision Records (ADRs)

**ADR Format:**
```markdown
# ADR-001: Use Kubernetes for Container Orchestration

## Status
Accepted

## Context
We need a container orchestration platform for our microservices.
Current: Manual Docker container management on EC2.
Challenges: No auto-scaling, manual deployment, poor observability.

## Decision
Use Kubernetes (EKS) for container orchestration.

## Consequences
Positive:
- Auto-scaling and self-healing
- Declarative configuration
- Rich ecosystem (Istio, ArgoCD, etc.)
- Industry standard with strong community

Negative:
- Learning curve for team
- Additional operational complexity
- Cost increase (~$150/month per cluster)

## Alternatives Considered
- AWS ECS: Simpler but less portable
- Docker Swarm: Simpler but smaller ecosystem
- Nomad: Interesting but less mature ecosystem
```

### Architectural Patterns

```
Monolith → All functionality in one application
  Pros: Simple deployment, easy local development
  Cons: Scaling challenges, deployment risk

Microservices → Small, independent services
  Pros: Independent scaling, technology flexibility
  Cons: Distributed complexity, network overhead

Serverless → FaaS + managed services
  Pros: No infrastructure management, pay-per-use
  Cons: Cold starts, vendor lock-in, debugging challenges

Event-Driven → Asynchronous message passing
  Pros: Decoupling, scalability, resilience
  Cons: Eventual consistency, debugging complexity

CQRS → Separate read/write models
  Pros: Optimized queries, scalability
  Cons: Complexity, eventual consistency
```

### Multi-Region Architecture

```
Active-Passive:
  Primary Region: Handles all traffic
  Secondary Region: Standby (replicated data)
  Failover: Manual or automated
  RTO: Minutes to hours
  Cost: Lower (secondary idle)

Active-Active:
  Both Regions: Handle traffic simultaneously
  Data: Bidirectional replication
  Failover: Automatic (load balancer)
  RTO: Seconds to minutes
  Cost: Higher (both active)
```

## Common Patterns

### Pattern 1: High Availability Architecture

```
┌─────────────────────────────────────────────────┐
│                  Route 53 DNS                    │
│              (Health checks enabled)             │
└─────────────────┬───────────────────────────────┘
                  │
      ┌───────────┴───────────┐
      │                       │
┌─────▼──────┐        ┌──────▼─────┐
│  Region A  │        │  Region B  │
│  (Primary) │        │ (Secondary)│
└─────┬──────┘        └──────┬─────┘
      │                      │
┌─────▼──────┐        ┌──────▼─────┐
│    ALB     │        │    ALB     │
└─────┬──────┘        └──────┬─────┘
      │                      │
┌─────▼──────┐        ┌──────▼─────┐
│  EKS/ECS   │        │  EKS/ECS   │
│  (Multi-AZ)│        │  (Multi-AZ)│
└─────┬──────┘        └──────┬─────┘
      │                      │
┌─────▼──────┐        ┌──────▼─────┐
│  RDS Multi │◄───────►│  RDS Read  │
│  -AZ       │ Replica │  Replica   │
└────────────┘        └────────────┘
```

### Pattern 2: Event-Driven Microservices

```yaml
# Event-driven architecture with message queue
services:
  order-service:
    publishes:
      - order.created
      - order.completed
    subscribes: []

  inventory-service:
    publishes:
      - inventory.updated
    subscribes:
      - order.created  # Reserve inventory

  notification-service:
    publishes: []
    subscribes:
      - order.created      # Send confirmation
      - order.completed    # Send receipt
      - inventory.updated  # Alert if low stock

message-broker: AWS SQS / EventBridge / Kafka
```

### Pattern 3: CQRS with Event Sourcing

```
Write Side (Commands):
  User Request → Command → Aggregate → Event Store

Read Side (Queries):
  Event Store → Projections → Read Models → Query Response

Benefits:
  - Optimized read models (denormalized)
  - Audit trail (event store)
  - Temporal queries (replay events)

Challenges:
  - Eventual consistency
  - Complexity
  - More storage
```

## Resource Files

For detailed guidance on specific topics, see:

### Design & Patterns
- **[architecture-patterns.md](resources/architecture-patterns.md)** - Microservices, monolith, serverless, event-driven, CQRS, hexagonal architecture
- **[system-design-principles.md](resources/system-design-principles.md)** - SOLID, 12-factor, CAP theorem, eventual consistency, idempotency
- **[reference-architectures.md](resources/reference-architectures.md)** - E-commerce, SaaS, data platform, ML platform examples

### Decision Making
- **[architecture-decision-records.md](resources/architecture-decision-records.md)** - ADR format, when to write, examples, tooling

### Reliability & Scale
- **[multi-region-design.md](resources/multi-region-design.md)** - Active-active, active-passive, data replication, latency considerations
- **[disaster-recovery.md](resources/disaster-recovery.md)** - RTO/RPO, backup strategies, failover procedures, testing
- **[capacity-planning.md](resources/capacity-planning.md)** - Load testing, resource forecasting, scaling strategies

### Data & Security
- **[data-architecture.md](resources/data-architecture.md)** - Data flow, storage selection, caching strategies, CDC, event sourcing
- **[security-architecture.md](resources/security-architecture.md)** - Zero trust, defense in depth, threat modeling, secure by design
- **[workload-classification.md](resources/workload-classification.md)** - Data classification levels (Unclassified, CUI, Secret, TS/SCI, ITAR), classification criteria, separation patterns, access control
- **[cleared-environment-architecture.md](resources/cleared-environment-architecture.md)** - Classified environment architectures (Secret, TS/SCI, CUI), security zones, cross-domain solutions, air-gapped patterns, SCIF requirements

### Cost & Migration
- **[cost-architecture.md](resources/cost-architecture.md)** - Cost-aware design, TCO analysis, FinOps integration
- **[migration-architecture.md](resources/migration-architecture.md)** - Strangler fig, big bang, phased migration patterns

## Best Practices

### 1. Document Key Decisions

Use ADRs for significant architectural choices. Make decision-making transparent.

### 2. Design for Failure

Assume everything fails. Build resilience with redundancy, retries, circuit breakers.

### 3. Start Simple, Scale Gradually

Don't over-engineer. Begin with monolith if appropriate, extract microservices as needed.

### 4. Think in Systems

Consider the entire system: application, data, network, security, operations, cost.

### 5. Balance Trade-offs

Every decision has trade-offs. Document them explicitly.

### 6. Cost-Aware Architecture

Design with cost implications in mind. Optimize for TCO, not just performance.

### 7. Security by Design

Integrate security from the start. Don't bolt it on later.

### 8. Measure Everything

Instrument for observability. You can't improve what you don't measure.

## Anti-Patterns to Avoid

❌ No architecture documentation (tribal knowledge)
❌ Over-engineering (premature microservices)
❌ Under-engineering (ignoring scalability)
❌ Technology-driven decisions (picking tech first)
❌ Ignoring operational complexity
❌ No disaster recovery plan
❌ Single points of failure
❌ Vendor lock-in without considering exit strategy
❌ No capacity planning (reactive scaling)
❌ Security as an afterthought

## Common Tasks

### Task: Create Architecture Decision Record

1. Identify decision that needs documentation
2. Use ADR template (context, decision, consequences)
3. List alternatives considered
4. Document trade-offs explicitly
5. Get review from technical leads
6. Commit to version control

### Task: Design Multi-Region Architecture

1. Define RTO/RPO requirements
2. Choose active-active or active-passive
3. Plan data replication strategy
4. Design DNS failover mechanism
5. Estimate costs (compute, data transfer, storage)
6. Document disaster recovery procedures
7. Test failover regularly

### Task: Perform Capacity Planning

1. Estimate peak load (users, requests, data volume)
2. Calculate resource requirements (compute, memory, storage)
3. Add headroom (30-50% buffer)
4. Design auto-scaling rules
5. Plan for growth (6-12 months)
6. Estimate costs
7. Monitor and adjust

## Integration Points

This skill integrates with:
- **platform-engineering**: Implements architectural designs with IaC
- **cloud-engineering**: Cloud-specific architectural patterns
- **sre**: Reliability requirements inform architecture
- **devsecops**: Security architecture requirements
- **release-engineering**: Deployment architecture
- **documentation-as-code**: Architecture diagrams and documentation

## Triggers and Activation

This skill activates when you:
- Work on Architecture Decision Records
- Design multi-region or DR solutions
- Create system architecture diagrams
- Perform capacity planning
- Evaluate architectural patterns
- Plan infrastructure migrations

---
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 SKILL ACTIVATED: infrastructure-architecture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


**Total Resources:** 11 detailed guides covering all aspects of infrastructure architecture
**Focus:** Design patterns, resilience, scalability, cost-awareness
**Maintained by:** Architecture team based on real-world production systems
