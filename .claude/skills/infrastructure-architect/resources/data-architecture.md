# Data Architecture

Guide to data modeling, storage selection, caching strategies, and data flow design.

## Data Flow Patterns

### Request-Response (Synchronous)
```
Client → API → Database → API → Client
Fast, simple, but coupled
```

### Event-Driven (Asynchronous)
```
Service A → Event Bus → Service B
        ↘→ Service C
        ↘→ Service D

Decoupled, scalable, eventual consistency
```

### Change Data Capture (CDC)
```
Database → CDC Tool (Debezium) → Event Stream → Consumers
Real-time data replication without application changes
```

## Storage Selection

### Relational Databases (PostgreSQL, MySQL)

**Use When:**
- Structured data with relationships
- ACID transactions required
- Complex queries (JOIN, aggregate)
- Data integrity critical

**Example:**
```sql
-- E-commerce: Users, Orders, Products
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  total DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE order_items (
  order_id INT REFERENCES orders(id),
  product_id INT REFERENCES products(id),
  quantity INT NOT NULL,
  PRIMARY KEY (order_id, product_id)
);
```

**Pros:** ✅ Strong consistency, ✅ Complex queries
**Cons:** ❌ Vertical scaling limits, ❌ Schema rigidity

---

### Document Databases (MongoDB, DynamoDB)

**Use When:**
- Flexible/evolving schema
- Nested/hierarchical data
- High write throughput
- Simple queries (by ID, single table)

**Example:**
```javascript
// User profile with nested data
{
  _id: "user-123",
  email: "john@example.com",
  profile: {
    firstName: "John",
    lastName: "Doe",
    addresses: [
      { type: "home", city: "NYC", zip: "10001" },
      { type: "work", city: "SF", zip: "94102" }
    ]
  },
  preferences: {
    newsletter: true,
    theme: "dark"
  }
}
```

**Pros:** ✅ Flexible schema, ✅ Horizontal scaling
**Cons:** ❌ No JOIN support, ❌ Eventual consistency (some)

---

### Key-Value Stores (Redis, Memcached)

**Use When:**
- Caching
- Session storage
- Rate limiting
- Real-time leaderboards

**Example:**
```typescript
// Session storage
await redis.set('session:abc123', JSON.stringify(session), 'EX', 3600);

// Rate limiting
const key = `rate-limit:${userId}`;
const count = await redis.incr(key);
if (count === 1) await redis.expire(key, 60);  // 1 minute window
if (count > 100) throw new Error('Rate limit exceeded');

// Leaderboard
await redis.zadd('leaderboard', score, userId);
const top10 = await redis.zrevrange('leaderboard', 0, 9, 'WITHSCORES');
```

**Pros:** ✅ Ultra-fast (<1ms), ✅ Simple
**Cons:** ❌ Limited query capabilities, ❌ In-memory (volatile)

---

### Object Storage (S3, GCS, Azure Blob)

**Use When:**
- Files, images, videos
- Backups, archives
- Data lakes
- Static website hosting

**Example:**
```typescript
// Upload file
await s3.putObject({
  Bucket: 'user-uploads',
  Key: `avatars/${userId}.jpg`,
  Body: fileBuffer,
  ContentType: 'image/jpeg'
});

// Serve via CloudFront CDN
const url = `https://cdn.example.com/avatars/${userId}.jpg`;
```

**Pros:** ✅ Unlimited storage, ✅ Cheap, ✅ Durable (11 9s)
**Cons:** ❌ Not for structured data, ❌ Eventually consistent

---

### Time-Series Databases (InfluxDB, TimescaleDB)

**Use When:**
- Metrics, logs, events
- IoT sensor data
- Financial tick data
- Monitoring data

**Example:**
```sql
-- TimescaleDB (PostgreSQL extension)
CREATE TABLE metrics (
  time TIMESTAMPTZ NOT NULL,
  host TEXT NOT NULL,
  cpu_usage DOUBLE PRECISION,
  memory_usage DOUBLE PRECISION
);

SELECT create_hypertable('metrics', 'time');

-- Query: Average CPU by host, last 1 hour
SELECT host, AVG(cpu_usage)
FROM metrics
WHERE time > NOW() - INTERVAL '1 hour'
GROUP BY host;
```

**Pros:** ✅ Optimized for time-range queries, ✅ Compression
**Cons:** ❌ Specialized use case

---

### Search Engines (Elasticsearch, Algolia)

**Use When:**
- Full-text search
- Fuzzy matching
- Faceted search
- Analytics/aggregations

**Example:**
```javascript
// Index document
await es.index({
  index: 'products',
  id: 'product-123',
  body: {
    name: 'Wireless Headphones',
    description: 'High-quality Bluetooth headphones',
    price: 99.99,
    category: 'Electronics'
  }
});

// Search with fuzzy matching
const results = await es.search({
  index: 'products',
  body: {
    query: {
      multi_match: {
        query: 'hedphones',  // Typo
        fields: ['name', 'description'],
        fuzziness: 'AUTO'
      }
    }
  }
});
```

**Pros:** ✅ Powerful search, ✅ Fast
**Cons:** ❌ Not for primary data, ❌ Eventual consistency

---

## Storage Selection Matrix

| Use Case | Recommended | Alternative |
|----------|-------------|-------------|
| User accounts, orders | PostgreSQL | MySQL |
| Product catalog | PostgreSQL | MongoDB (if flexible schema) |
| Session storage | Redis | Memcached |
| File uploads | S3 | GCS, Azure Blob |
| Metrics/logs | InfluxDB | TimescaleDB, Prometheus |
| Full-text search | Elasticsearch | Algolia (managed) |
| Cache | Redis | Memcached |
| Real-time analytics | ClickHouse | BigQuery (batch) |

---

## Caching Strategies

### Cache-Aside (Lazy Loading)

```typescript
async function getUser(userId) {
  // 1. Try cache
  let user = await cache.get(`user:${userId}`);
  if (user) return JSON.parse(user);  // Cache hit

  // 2. Cache miss - fetch from DB
  user = await db.users.findUnique({ where: { id: userId } });

  // 3. Populate cache
  await cache.set(`user:${userId}`, JSON.stringify(user), 'EX', 3600);

  return user;
}
```

**Pros:** ✅ Only cache what's needed
**Cons:** ❌ First request slow (cache miss)

---

### Write-Through

```typescript
async function updateUser(userId, data) {
  // 1. Update database
  const user = await db.users.update({
    where: { id: userId },
    data
  });

  // 2. Update cache immediately
  await cache.set(`user:${userId}`, JSON.stringify(user), 'EX', 3600);

  return user;
}
```

**Pros:** ✅ Cache always fresh
**Cons:** ❌ Write latency (2 operations)

---

### Write-Behind (Write-Back)

```typescript
async function updateUser(userId, data) {
  // 1. Update cache immediately
  await cache.set(`user:${userId}`, JSON.stringify(data));

  // 2. Async write to database (background)
  queue.publish('user-updates', { userId, data });

  return data;
}
```

**Pros:** ✅ Fast writes
**Cons:** ❌ Risk of data loss, ❌ Complexity

---

## Data Consistency Patterns

### Strong Consistency
```
Write → Wait for all replicas → Success
All reads see latest write immediately
Use: Banking, inventory
```

### Eventual Consistency
```
Write → Primary → Success
Replicate to secondaries asynchronously
Reads may see stale data temporarily
Use: Social media, profiles
```

### Read-Your-Writes Consistency
```
After writing, read from same source (primary)
User sees their own writes immediately
Others may still see stale data
```

```typescript
// Read-your-writes pattern
async function updateProfile(userId, data) {
  await primaryDB.users.update({ where: { id: userId }, data });

  // Read from primary (not replica) to guarantee consistency
  return await primaryDB.users.findUnique({ where: { id: userId } });
}
```

---

## Data Partitioning (Sharding)

### Horizontal Sharding

```
Split data by rows across multiple databases

User sharding by user_id:
  Shard 1: users 0-999
  Shard 2: users 1000-1999
  Shard 3: users 2000-2999
```

```typescript
function getShardForUser(userId) {
  const shardCount = 4;
  const shardId = userId % shardCount;
  return shards[shardId];
}

async function getUserOrders(userId) {
  const shard = getShardForUser(userId);
  return await shard.query('SELECT * FROM orders WHERE user_id = ?', [userId]);
}
```

**Pros:** ✅ Unlimited scaling
**Cons:** ❌ Cross-shard queries difficult, ❌ Rebalancing complex

---

### Vertical Partitioning

```
Split data by columns

Users table split:
  - Hot data: user_id, email, name (frequently accessed)
  - Cold data: settings, preferences (rarely accessed)
```

---

## Data Replication

### Leader-Follower (Primary-Replica)

```
Primary (Writes) → Followers (Reads)

1 Primary, N Followers
Writes go to primary
Reads can use any follower
```

```typescript
// Write to primary
await primary.users.update({ where: { id: 1 }, data });

// Read from replica (load balancing)
const users = await replica.users.findMany();
```

---

### Multi-Leader

```
Multiple primaries accept writes
Conflict resolution required
```

**Conflict Resolution:**
- Last-write-wins (lossy)
- Version vectors
- CRDTs (Conflict-free Replicated Data Types)

---

## Change Data Capture (CDC)

```
Database → Debezium → Kafka → Consumers

Real-time data pipeline without app changes
```

```yaml
# Debezium connector for PostgreSQL
{
  "name": "postgres-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "debezium",
    "database.dbname": "mydb",
    "table.include.list": "public.users,public.orders",
    "topic.prefix": "cdc"
  }
}
```

**Use Cases:**
- Real-time search index updates
- Data warehouse sync
- Event-driven microservices
- Audit logging

---

## Data Modeling Best Practices

### 1. Design for Query Patterns
```
Know your queries first, then design schema
```

### 2. Denormalize for Performance
```
Trade storage for speed in read-heavy systems
```

### 3. Use Appropriate Data Types
```sql
-- ✅ Correct
timestamp TIMESTAMPTZ  -- Timezone-aware
price DECIMAL(10,2)    -- Exact (no floating point errors)

-- ❌ Wrong
timestamp INT          -- Unix epoch (no timezone)
price FLOAT            -- Rounding errors
```

### 4. Index Strategically
```sql
-- Index frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);

-- But don't over-index (slows writes)
```

### 5. Avoid Premature Optimization
```
Start simple (single database)
Scale when metrics show need
```

---

**Related Resources:**
- architecture-patterns.md - Event-driven, CQRS patterns
- system-design-principles.md - CAP theorem, consistency
- capacity-planning.md - Database sizing
