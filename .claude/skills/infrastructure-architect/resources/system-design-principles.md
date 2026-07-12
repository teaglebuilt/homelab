# System Design Principles

Fundamental principles and patterns for designing scalable, reliable, maintainable systems.

## Core Principles

### 1. SOLID Principles (for Architecture)

**Single Responsibility**
Each component/service should have one reason to change.
```
❌ Bad: "UserService" handles auth, profile, notifications, billing
✅ Good: Separate services: AuthService, ProfileService, NotificationService, BillingService
```

**Open-Closed**
Open for extension, closed for modification.
```
✅ Plugin architecture, event-driven systems, strategy pattern
```

**Liskov Substitution**
Implementations should be interchangeable.
```
✅ Interface-based design, dependency injection
```

**Interface Segregation**
Many specific interfaces > one general interface.
```
❌ One large "IUserService" with 50 methods
✅ IUserAuth, IUserProfile, IUserSettings (focused interfaces)
```

**Dependency Inversion**
Depend on abstractions, not concretions.
```typescript
// ❌ Direct dependency
class UserController {
  constructor() {
    this.db = new PostgresDB();  // Concrete
  }
}

// ✅ Dependency injection
class UserController {
  constructor(private db: IDatabase) {}  // Abstract
}
```

---

### 2. 12-Factor App

**I. Codebase:** One codebase, many deploys
```
✅ Single repo → Deploy to dev, staging, prod
```

**II. Dependencies:** Explicitly declare dependencies
```yaml
# package.json
{
  "dependencies": {
    "express": "4.18.0",  # Explicit version
    "prisma": "5.0.0"
  }
}
```

**III. Config:** Store config in environment
```typescript
// ❌ Hardcoded
const dbUrl = "postgresql://localhost:5432/mydb";

// ✅ Environment variable
const dbUrl = process.env.DATABASE_URL;
```

**IV. Backing Services:** Treat as attached resources
```
Database, cache, queue = swappable resources via URLs
```

**V. Build, Release, Run:** Strict separation
```
Build → Release (build + config) → Run
```

**VI. Processes:** Stateless processes
```
✅ Store session in Redis, not in-memory
```

**VII. Port Binding:** Export services via port
```typescript
app.listen(process.env.PORT || 3000);
```

**VIII. Concurrency:** Scale via process model
```
✅ Horizontal scaling (add more processes)
❌ Vertical scaling only (bigger server)
```

**IX. Disposability:** Fast startup, graceful shutdown
```typescript
process.on('SIGTERM', async () => {
  await server.close();
  await db.disconnect();
  process.exit(0);
});
```

**X. Dev/Prod Parity:** Keep environments similar
```
✅ Docker ensures same environment everywhere
```

**XI. Logs:** Treat logs as event streams
```
✅ Log to stdout → Aggregation tool (ELK, Loki)
❌ Log to files directly
```

**XII. Admin Processes:** Run admin tasks as one-off processes
```bash
# ✅ One-off migration
npm run migrate

# ❌ Built into application
```

---

### 3. CAP Theorem

**You can have at most 2 of 3:**

```
Consistency (C): All nodes see same data
Availability (A): System always responds
Partition Tolerance (P): System works despite network splits

Network partitions WILL happen → Must choose: CP or AP
```

**CP Systems (Consistency + Partition Tolerance):**
- MongoDB (default), HBase, Redis
- Sacrifice: Availability (may reject requests during partition)
- Use case: Banking (consistency critical)

**AP Systems (Availability + Partition Tolerance):**
- Cassandra, DynamoDB, Couchbase
- Sacrifice: Consistency (eventual consistency)
- Use case: Social media (availability critical)

**CA Systems (Consistency + Availability):**
- Traditional RDBMS in single datacenter
- Sacrifice: Partition Tolerance (not distributed)
- Reality: Network partitions happen, so CA is theoretical

---

### 4. Eventual Consistency

**Definition:** System will become consistent given enough time without new updates.

```
User posts comment (writes to primary DB)
  ↓
Replication to replicas (takes 100ms)
  ↓
Read from replica immediately → May not see comment yet
  ↓
Wait 100ms → Comment appears
```

**Handling in Code:**
```typescript
// After write, read from primary (strong consistency)
await db.comments.create({ data: comment });
const newComment = await db.$queryRaw`
  SELECT * FROM comments WHERE id = ${comment.id}
`; // Guaranteed to see the write

// Or: Accept eventual consistency
await db.comments.create({ data: comment });
// UI shows optimistic update immediately
// Background sync handles replication
```

---

### 5. Idempotency

**Definition:** Operation can be applied multiple times without changing result beyond first application.

```
// ❌ Not idempotent
function incrementBalance(userId, amount) {
  balance += amount;  // Multiple calls = wrong balance
}

// ✅ Idempotent (with idempotency key)
function creditAccount(userId, amount, idempotencyKey) {
  if (processedKeys.has(idempotencyKey)) {
    return alreadyProcessed;  // Skip duplicate
  }

  balance += amount;
  processedKeys.add(idempotencyKey);
}
```

**HTTP Idempotency:**
```
GET, PUT, DELETE = Idempotent
POST = NOT idempotent (creates new resource each time)
```

---

### 6. Circuit Breaker Pattern

**Prevent cascading failures:**

```typescript
class CircuitBreaker {
  state = 'CLOSED';  // CLOSED, OPEN, HALF_OPEN
  failureCount = 0;
  failureThreshold = 5;
  timeout = 60000;  // 1 minute

  async call(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() > this.nextAttempt) {
        this.state = 'HALF_OPEN';  // Try one request
      } else {
        throw new Error('Circuit breaker OPEN');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  onSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }

  onFailure() {
    this.failureCount++;
    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
      this.nextAttempt = Date.now() + this.timeout;
    }
  }
}

// Usage
const breaker = new CircuitBreaker();
await breaker.call(() => externalAPI.getData());
```

---

### 7. Bulkhead Pattern

**Isolate failures:**

```
Connection pools, thread pools, separate services

Example:
- Search service fails → Doesn't affect checkout
- Analytics DB slow → Doesn't affect user DB
```

```typescript
// Separate connection pools
const userDBPool = new Pool({ max: 20 });      // Critical
const analyticsDBPool = new Pool({ max: 10 }); // Non-critical

// Analytics queries don't starve user queries
```

---

### 8. Retry with Exponential Backoff

```typescript
async function fetchWithRetry(url, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fetch(url);
    } catch (error) {
      if (i === maxRetries - 1) throw error;

      // Exponential backoff: 1s, 2s, 4s, 8s
      const delay = Math.pow(2, i) * 1000;

      // Jitter: Randomize to avoid thundering herd
      const jitter = Math.random() * 1000;

      await sleep(delay + jitter);
    }
  }
}
```

---

### 9. Saga Pattern (Distributed Transactions)

**Problem:** No distributed ACID transactions in microservices

**Solution:** Chain of local transactions with compensation

```
Order Saga:
1. Create Order       → Compensate: Cancel Order
2. Reserve Inventory  → Compensate: Release Inventory
3. Charge Payment     → Compensate: Refund Payment
4. Ship Order         → Compensate: Cancel Shipment

If step 3 fails:
← Compensate step 2 (release inventory)
← Compensate step 1 (cancel order)
```

**Implementation:**
```typescript
async function createOrderSaga(order) {
  const saga = new Saga();

  try {
    // Step 1
    const orderId = await saga.execute(
      () => orderService.create(order),
      () => orderService.cancel(orderId)
    );

    // Step 2
    await saga.execute(
      () => inventoryService.reserve(order.items),
      () => inventoryService.release(order.items)
    );

    // Step 3
    await saga.execute(
      () => paymentService.charge(order.total),
      () => paymentService.refund(order.total)
    );

    return orderId;
  } catch (error) {
    // Execute compensations in reverse order
    await saga.compensate();
    throw error;
  }
}
```

---

### 10. CQRS (Command Query Responsibility Segregation)

**Separate read and write models:**

```
Commands (writes):
  → Optimized for consistency
  → Normalized schema

Queries (reads):
  → Optimized for performance
  → Denormalized schema (pre-joined)
```

---

### 11. Event Sourcing

**Store events, not current state:**

```
Traditional:
  User { id: 1, balance: 100 }  ← Current state only

Event Sourcing:
  UserCreated { id: 1, initialBalance: 0 }
  MoneyDeposited { id: 1, amount: 150 }
  MoneyWithdrawn { id: 1, amount: 50 }
  ← Full history, balance = sum(events)
```

**Benefits:**
- ✅ Complete audit trail
- ✅ Temporal queries ("balance on Jan 1st")
- ✅ Event replay

**Drawbacks:**
- ❌ Complexity
- ❌ Storage growth
- ❌ Schema evolution challenges

---

## Design Trade-Offs

### Consistency vs. Availability

| Choice | Pros | Cons | Use Case |
|--------|------|------|----------|
| Strong Consistency | No anomalies | Lower availability | Banking |
| Eventual Consistency | High availability | Read stale data | Social media |

### Latency vs. Throughput

| Choice | Pros | Cons |
|--------|------|------|
| Low Latency | Fast responses | Lower throughput |
| High Throughput | Process more | Higher latency |

### Normalization vs. Denormalization

| Choice | Pros | Cons |
|--------|------|------|
| Normalized | No duplication, consistency | Slow reads (joins) |
| Denormalized | Fast reads | Data duplication, consistency risk |

---

## Scalability Patterns

### Horizontal Scaling (Scale Out)
```
Add more servers
✅ Unlimited scaling potential
❌ Requires stateless design
```

### Vertical Scaling (Scale Up)
```
Bigger server
✅ Simple (no code changes)
❌ Hardware limits (max 96 vCPU, 768 GB RAM)
```

### Sharding (Data Partitioning)
```
Split data across multiple databases

User sharding:
  users 0-999      → Shard 1
  users 1000-1999  → Shard 2
  users 2000-2999  → Shard 3

✅ Scales infinitely
❌ Cross-shard queries difficult
❌ Rebalancing complex
```

---

## Anti-Patterns

❌ **Premature Optimization** - Optimize based on actual metrics, not assumptions
❌ **Distributed Monolith** - Microservices with tight coupling
❌ **Over-Engineering** - CQRS+Event Sourcing for simple CRUD
❌ **Ignoring CAP** - Expecting strong consistency + high availability
❌ **Magic Numbers** - Hardcoded limits without reasoning
❌ **No Timeouts** - Hanging requests consume resources forever
❌ **Synchronous Microservices** - Chains create latency and coupling

---

**Related Resources:**
- architecture-patterns.md - Microservices, event-driven, CQRS
- data-architecture.md - Data modeling and storage patterns
- multi-region-design.md - CAP theorem in practice
