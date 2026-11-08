# Architecture Patterns Reference

## Pattern Selection Decision Tree

Start here when choosing an architecture. Answer these questions in order:

### Question 1: What's the team/org structure?

| Situation | Lean Toward | Avoid |
|-----------|-------------|-------|
| 1-5 developers, single team | Monolith or modular monolith | Microservices, service mesh |
| 5-15 developers, 2-3 teams | Modular monolith or selective service extraction | Full microservices |
| 15+ developers, many teams | Microservices or service-oriented | Single monolith |
| Cross-functional product teams | Vertical slices, micro-frontends | Horizontal layers owned by different teams |

### Question 2: What's the domain complexity?

| Situation | Lean Toward | Avoid |
|-----------|-------------|-------|
| Simple CRUD, few entities | Layered monolith, serverless | DDD, event sourcing, CQRS |
| Moderate business logic | Modular monolith with clean boundaries | Over-decomposed services |
| Complex domain, many invariants | DDD tactical patterns, hexagonal | Anemic domain model, pure CRUD layers |
| Multiple distinct subdomains | Bounded contexts (monolith or services) | Single shared domain model |

### Question 3: What are the scaling characteristics?

| Situation | Lean Toward | Avoid |
|-----------|-------------|-------|
| Uniform load, modest scale | Monolith with horizontal scaling | Per-function decomposition |
| Spiky/unpredictable traffic | Serverless, auto-scaling containers | Fixed-capacity infrastructure |
| One hot path, rest is modest | Extract the hot path as a service | Decomposing everything |
| Independent scaling per feature | Microservices for those features | Scaling everything together if cost-prohibitive |

### Question 4: What's the data landscape?

| Situation | Lean Toward | Avoid |
|-----------|-------------|-------|
| Single relational model fits | Shared database | Premature database-per-service |
| Read/write patterns differ dramatically | CQRS | Single model forced to serve both |
| Need full audit trail / temporal queries | Event sourcing | Mutable-state-only if audit is required |
| Multiple storage technologies needed | Polyglot persistence | Forcing one DB for everything |
| Strong consistency required | Shared DB or sync communication | Eventual consistency where it doesn't fit |
| Eventual consistency acceptable | Event-driven, async messaging | Distributed transactions |

---

## Structural Patterns Deep Dive

### Monolith (Well-Structured)

**What it is:** Single deployable unit with internal organization (layers, modules, or feature folders).

**Strengths:**
- Simple to develop, test, deploy, and debug
- Single process = no network boundary issues
- Refactoring is straightforward (IDE support, compiler checks)
- Lower operational overhead
- Transactions are trivial (single database)

**Weaknesses:**
- Scaling is all-or-nothing
- Deployment couples all features
- Can degrade into a "big ball of mud" without discipline
- Tech stack is largely uniform

**When to choose:**
- Early-stage products, MVPs, small teams
- Domain boundaries are not yet clear
- Operational simplicity is a priority
- You want to go fast and refactor later

**Fitness functions:**
- Dependency rule enforcement (ArchUnit, eslint-plugin-boundaries)
- Module coupling metrics
- Build time thresholds
- Test execution time

---

### Modular Monolith

**What it is:** Monolith with strictly enforced module boundaries. Modules communicate through defined interfaces, not direct database access.

**Strengths:**
- Monolith simplicity with better long-term maintainability
- Clear extraction path to services if/when needed
- Enforced boundaries prevent coupling creep
- Each module can own its own schema/tables
- Transaction support within the monolith

**Weaknesses:**
- Requires discipline to maintain boundaries (without it, degrades to regular monolith)
- Still a single deployment unit
- Shared process means one module's failure can affect others

**When to choose:**
- Medium teams who want service-like boundaries without operational cost
- Domain is understood well enough to define modules
- You want optionality to extract services later
- Organization has discipline for boundary enforcement

**Key implementation details:**
- Each module exposes a public API (interface/facade)
- No direct database access across modules
- Communication through in-process events or API calls
- Separate schemas or table prefixes per module
- Enforced via linting, ArchUnit tests, or build tooling

---

### Microservices

**What it is:** Independently deployable services, each owning its data, communicating over the network.

**Strengths:**
- Independent deployment and scaling
- Team autonomy and ownership
- Technology heterogeneity (right tool per service)
- Fault isolation (one service failure ≠ system failure, if designed well)
- Scales with organizational growth

**Weaknesses:**
- Distributed system complexity (network failures, latency, consistency)
- Operational overhead (monitoring, tracing, deployment pipelines per service)
- Data consistency is hard (sagas, eventual consistency)
- Testing is harder (contract tests, integration environments)
- Debugging across services requires distributed tracing

**When to choose:**
- Large organizations with multiple autonomous teams
- Genuinely independent scaling requirements
- Domain boundaries are well-understood
- Team has operational maturity (observability, CI/CD, on-call)
- Business value justifies the operational cost

**Prerequisites (be honest about these):**
- Automated CI/CD per service
- Centralized logging and distributed tracing
- Service discovery and load balancing
- Health checks and circuit breakers
- Contract testing strategy
- On-call rotation and incident response

---

### Serverless / FaaS

**What it is:** Functions deployed individually, triggered by events, managed by cloud provider.

**Strengths:**
- Zero infrastructure management
- Pay-per-invocation (cost-effective for spiky/low traffic)
- Auto-scaling built in
- Fast to deploy individual functions

**Weaknesses:**
- Cold start latency
- Vendor lock-in
- Debugging and local development challenges
- Stateless constraint (state must live externally)
- Function composition can become complex
- Cost can spike with high sustained throughput

**When to choose:**
- Event-driven workloads (webhooks, file processing, scheduled jobs)
- Unpredictable or spiky traffic
- Small, independent functions with clear triggers
- Team wants minimal ops burden
- Cost optimization for low-traffic services

---

### Event-Driven Architecture

**What it is:** Components communicate by producing and consuming events rather than direct calls.

**Strengths:**
- Loose coupling between producers and consumers
- Natural audit trail (event log)
- Easy to add new consumers without changing producers
- Supports eventual consistency patterns
- Good for complex workflows and choreography

**Weaknesses:**
- Harder to reason about (no single request/response flow)
- Debugging requires event tracing
- Event schema evolution needs careful management
- Eventual consistency requires different mental model
- Can lead to event storms or infinite loops if not careful

**When to choose:**
- Multiple systems need to react to the same business events
- Audit trail / temporal queries are important
- Systems need to be decoupled for independent evolution
- Workflows span multiple bounded contexts

---

## Communication Patterns

### Synchronous vs Asynchronous Decision Matrix

| Factor | Sync (REST/gRPC/GraphQL) | Async (Messages/Events) |
|--------|-------------------------|------------------------|
| Latency requirement | Need immediate response | Can tolerate delay |
| Coupling | Higher (caller knows callee) | Lower (pub/sub) |
| Failure handling | Caller must handle failure | Retry/DLQ built in |
| Debugging | Easier (request/response) | Harder (trace events) |
| Throughput | Limited by slowest service | Buffer and process at own pace |
| Data consistency | Easier strong consistency | Eventual consistency |

### API Style Decision Matrix

| Factor | REST | gRPC | GraphQL |
|--------|------|------|---------|
| Client diversity | Many different clients | Internal services | Frontend-driven queries |
| Performance | Good | Excellent (binary, streaming) | Variable (query complexity) |
| Schema evolution | Versioned URLs or headers | Protobuf backward compat | Additive field evolution |
| Tooling maturity | Excellent | Good | Good |
| Learning curve | Low | Medium | Medium-High |
| Real-time | Webhooks/SSE | Bidirectional streaming | Subscriptions |
| Best for | Public APIs, simple CRUD | Service-to-service, high perf | Complex frontend data needs |

---

## Code-Level Architecture Patterns

### Layered vs Hexagonal vs Vertical Slice

| Factor | Layered (N-Tier) | Hexagonal (Ports & Adapters) | Vertical Slice |
|--------|------------------|------------------------------|----------------|
| Organization | By technical concern | By domain + port boundaries | By feature/use case |
| Change pattern | Feature touches all layers | Core domain isolated from infra | Change lives in one slice |
| Testing | Mock each layer | Port interfaces = easy to test | Test per feature independently |
| Complexity | Low initial, grows with features | Medium initial, scales well | Low per slice, need conventions |
| Best for | Simple CRUD apps | Complex domain logic | Feature-rich applications |
| Risk | Bloated layers, shotgun surgery | Over-abstraction if domain is simple | Duplication across slices |

### When to Use DDD Tactical Patterns

Use DDD when:
- Business rules are the hard part (not tech)
- Domain experts exist and are accessible
- Business language matters (ubiquitous language)
- Invariants need protection (aggregates)
- Multiple models of the same concept exist (bounded contexts)

Skip DDD when:
- It's mostly CRUD with thin business logic
- The team doesn't have access to domain experts
- The domain is well-understood and simple
- You're building infrastructure, not business software

---

## Migration Strategies

### Strangler Fig Pattern
Incrementally replace pieces of a legacy system by routing traffic through a facade that delegates to old or new implementation.

**Steps:**
1. Identify a bounded context to extract
2. Build new implementation alongside old
3. Route traffic through facade/proxy
4. Gradually shift traffic to new implementation
5. Decommission old code when fully migrated

### Branch by Abstraction
Introduce an abstraction layer, build new implementation behind it, switch over.

### Parallel Run
Run old and new systems simultaneously, compare outputs, switch when confident.

### Anti-Corruption Layer
Isolate new system from legacy with a translation layer that prevents legacy concepts from leaking in.
