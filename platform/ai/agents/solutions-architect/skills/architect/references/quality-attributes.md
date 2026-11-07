# Quality Attributes Scoring Framework

## How to Use This Framework

1. **Identify the top 5 quality attributes** that matter most for the project (work with stakeholders)
2. **Weight them** — Not all attributes are equal. Assign weights (1-5) based on priority.
3. **Score each candidate architecture** against each attribute (1-5 scale)
4. **Calculate weighted scores** and compare
5. **Document the reasoning** — Scores without rationale are meaningless

## Quality Attribute Definitions

### Performance
How fast the system responds under expected load.
- **Measures:** Response time (p50, p95, p99), throughput (requests/sec), resource utilization
- **Architectural levers:** Caching strategy, async processing, data locality, connection pooling, read replicas
- **Tradeoffs with:** Maintainability (optimized code is harder to read), cost (more infra), consistency (caching = staleness risk)

### Scalability
Ability to handle growth in load, data, or users.
- **Measures:** Max concurrent users, data volume limits, horizontal scaling factor, cost-per-user curve
- **Architectural levers:** Stateless design, sharding, partitioning, auto-scaling, queue-based load leveling
- **Tradeoffs with:** Simplicity (distributed = complex), consistency (CAP theorem), cost (scale-out infra)

### Availability / Reliability
System uptime and resilience to failures.
- **Measures:** Uptime percentage (99.9% = 8.7h/year downtime), MTTR, MTBF, RTO/RPO
- **Architectural levers:** Redundancy, health checks, circuit breakers, graceful degradation, multi-region
- **Tradeoffs with:** Cost (redundancy is expensive), consistency (CAP), complexity (failover logic)

### Maintainability / Evolvability
Ease of understanding, modifying, and extending the system.
- **Measures:** Time to onboard new developer, time to implement average feature, defect rate after changes
- **Architectural levers:** Modularity, clear boundaries, documentation, consistent patterns, low coupling
- **Tradeoffs with:** Performance (abstractions add overhead), time to market (good structure takes time)

### Testability
Ease of verifying system behavior at all levels.
- **Measures:** Test execution time, code coverage meaningfulness, time to write tests for new feature
- **Architectural levers:** Dependency injection, interface-based design, pure functions, test fixtures
- **Tradeoffs with:** Simplicity (test infrastructure is code too), performance (test doubles vs real deps)

### Deployability
Speed and safety of getting changes to production.
- **Measures:** Deployment frequency, lead time, change failure rate, rollback time
- **Architectural levers:** CI/CD, feature flags, blue-green/canary deployments, independent deployables
- **Tradeoffs with:** Simplicity (deployment infra complexity), consistency (gradual rollouts = version skew)

### Security
Protection of data and system integrity.
- **Measures:** Attack surface area, time to patch, compliance adherence, penetration test findings
- **Architectural levers:** Defense in depth, zero trust, encryption at rest/transit, least privilege, audit logging
- **Tradeoffs with:** Developer experience (auth adds friction), performance (encryption overhead), usability

### Observability
Ability to understand system behavior in production.
- **Measures:** Mean time to detect issues, mean time to root cause, coverage of metrics/logs/traces
- **Architectural levers:** Structured logging, distributed tracing, metrics dashboards, alerting, health endpoints
- **Tradeoffs with:** Cost (observability infrastructure), performance (instrumentation overhead), storage

### Cost
Total cost of development and operation.
- **Measures:** Cloud spend, development hours, operational overhead, cost per user/transaction
- **Architectural levers:** Right-sizing, reserved instances, serverless for low traffic, shared infrastructure
- **Tradeoffs with:** Nearly everything (cost is usually the constraint, not the goal)

### Developer Experience
How productive and enjoyable the development workflow is.
- **Measures:** Local dev setup time, feedback loop speed, cognitive load per task, tool satisfaction
- **Architectural levers:** Hot reload, good abstractions, consistent patterns, documentation, dev containers
- **Tradeoffs with:** Production optimization (dev-friendly ≠ prod-optimal), operational needs

### Time to Market
Speed of delivering new features.
- **Measures:** Idea to production time, feature development cycle time
- **Architectural levers:** Simplicity, reusable components, low ceremony, pragmatic shortcuts
- **Tradeoffs with:** Maintainability (shortcuts create debt), scalability (simple now may not scale)

---

## Scoring Template

Rate each attribute 1-5 for each candidate architecture:

| Attribute | Weight (1-5) | Option A | Option B | Option C |
|-----------|-------------|----------|----------|----------|
| Performance | _ | _ | _ | _ |
| Scalability | _ | _ | _ | _ |
| Availability | _ | _ | _ | _ |
| Maintainability | _ | _ | _ | _ |
| Testability | _ | _ | _ | _ |
| Deployability | _ | _ | _ | _ |
| Security | _ | _ | _ | _ |
| Observability | _ | _ | _ | _ |
| Cost | _ | _ | _ | _ |
| Dev Experience | _ | _ | _ | _ |
| Time to Market | _ | _ | _ | _ |
| **Weighted Total** | | **_** | **_** | **_** |

**Scoring guide:**
- 1 = Significant weakness, active risk
- 2 = Below average, needs mitigation
- 3 = Adequate, meets minimum bar
- 4 = Strong, competitive advantage
- 5 = Excellent, best-in-class for this context

**Weighted score** = Sum of (weight × score) for each attribute

---

## Architectural Fitness Functions

Fitness functions are automated checks that validate the architecture continues to meet its intended qualities over time.

### Examples by Quality Attribute

**Maintainability:**
- No circular dependencies between modules (ArchUnit, madge, eslint-plugin-boundaries)
- Maximum module fan-out (no module depends on more than N others)
- Maximum file/function size thresholds
- Dependency direction rules (domain must not import infrastructure)

**Performance:**
- API response time p95 < threshold (load test in CI)
- Database query execution plans reviewed for N+ queries
- Bundle size budget for frontend artifacts

**Deployability:**
- Build time < N minutes
- No shared database migrations across service boundaries
- Contract tests pass between all service pairs

**Security:**
- No secrets in code (git-secrets, trufflehog)
- Dependency vulnerability scan passes
- Authentication required on all non-public endpoints

**Testability:**
- Test coverage above threshold for domain/business logic
- Integration test suite runs < N minutes
- No test interdependencies (tests pass in any order)

### Implementing Fitness Functions

1. Define as code (test, linting rule, CI check)
2. Run automatically (CI pipeline, pre-commit hook, or scheduled)
3. Fail the build if violated
4. Review and update periodically as architecture evolves
5. Document the "why" alongside each function
