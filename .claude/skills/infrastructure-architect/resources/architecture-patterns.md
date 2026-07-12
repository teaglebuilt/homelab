# Architecture Patterns

Comprehensive guide to common architectural patterns for modern infrastructure and applications.

## Pattern Catalog

### 1. Monolithic Architecture

**Description:**
All functionality in a single, unified application.

**Structure:**
```
┌────────────────────────────────────┐
│      Monolithic Application        │
│  ┌──────────────────────────────┐  │
│  │      Presentation Layer      │  │
│  ├──────────────────────────────┤  │
│  │       Business Logic         │  │
│  ├──────────────────────────────┤  │
│  │       Data Access Layer      │  │
│  └──────────────────────────────┘  │
└────────────────┬───────────────────┘
                 │
        ┌────────▼────────┐
        │    Database     │
        └─────────────────┘
```

**When to Use:**
- Starting new projects (validate product-market fit)
- Small to medium teams
- Simple business logic
- Tight coupling is acceptable

**Pros:**
- ✅ Simple deployment
- ✅ Easy local development
- ✅ Straightforward debugging
- ✅ Strong consistency
- ✅ Lower operational overhead

**Cons:**
- ❌ Scaling all-or-nothing
- ❌ Technology lock-in
- ❌ Long deployment cycles
- ❌ High deployment risk
- ❌ Difficult to isolate failures

**Example:**
```typescript
// Single Express application
const app = express();

// All routes in one application
app.use('/users', userRoutes);
app.use('/orders', orderRoutes);
app.use('/products', productRoutes);
app.use('/payments', paymentRoutes);

// Single database connection
const db = new PrismaClient();

app.listen(3000);
```

---

### 2. Microservices Architecture

**Description:**
Application broken into small, independent services communicating over network.

**Structure:**
```
                API Gateway
                     │
        ┌────────────┼────────────┐
        │            │            │
   ┌────▼───┐   ┌───▼────┐  ┌────▼───┐
   │ User   │   │ Order  │  │Product │
   │Service │   │Service │  │Service │
   └────┬───┘   └───┬────┘  └────┬───┘
        │           │            │
   ┌────▼───┐   ┌───▼────┐  ┌────▼───┐
   │UserDB  │   │OrderDB │  │Product │
   └────────┘   └────────┘  │  DB    │
                             └────────┘
```

**When to Use:**
- Large, complex applications
- Multiple independent teams
- Different scaling requirements per service
- Technology diversity needed

**Pros:**
- ✅ Independent scaling
- ✅ Technology flexibility
- ✅ Team autonomy
- ✅ Fault isolation
- ✅ Easier to understand (each service)

**Cons:**
- ❌ Distributed system complexity
- ❌ Network latency
- ❌ Data consistency challenges
- ❌ Debugging difficulty
- ❌ High operational overhead

**Example:**
```yaml
# User Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: user-service
        image: user-service:v1.0.0
        env:
        - name: DATABASE_URL
          value: postgresql://user-db:5432

---
# Order Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 5  # Scale independently
  template:
    spec:
      containers:
      - name: order-service
        image: order-service:v1.0.0
```

---

### 3. Serverless Architecture

**Description:**
Application built using Function-as-a-Service (FaaS) and managed services.

**Structure:**
```
┌──────────┐     ┌─────────────┐
│ API      │────►│  Lambda     │
│ Gateway  │     │  Functions  │
└──────────┘     └──────┬──────┘
                        │
          ┌─────────────┼─────────────┐
          │             │             │
     ┌────▼────┐   ┌────▼────┐  ┌────▼────┐
     │ DynamoDB│   │   S3    │  │  SQS    │
     └─────────┘   └─────────┘  └─────────┘
```

**When to Use:**
- Variable, unpredictable workloads
- Event-driven processing
- Low operational overhead desired
- Cost optimization for sporadic usage

**Pros:**
- ✅ No infrastructure management
- ✅ Automatic scaling
- ✅ Pay-per-use pricing
- ✅ Fast iteration
- ✅ High availability built-in

**Cons:**
- ❌ Cold start latency
- ❌ Vendor lock-in
- ❌ Debugging challenges
- ❌ Limited execution time
- ❌ Stateless (requires external state)

**Example:**
```typescript
// AWS Lambda handler
export const handler = async (event: APIGatewayEvent) => {
  const userId = event.pathParameters?.userId;

  // Auto-scales based on requests
  const user = await dynamodb.get({
    TableName: 'Users',
    Key: { userId }
  });

  return {
    statusCode: 200,
    body: JSON.stringify(user)
  };
};

// Terraform definition
resource "aws_lambda_function" "user_api" {
  function_name = "user-api"
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  # Only charged when invoked
  memory_size   = 512
  timeout       = 30
}
```

---

### 4. Event-Driven Architecture

**Description:**
Services communicate asynchronously through events.

**Structure:**
```
┌──────────┐        ┌──────────────┐        ┌──────────┐
│ Order    │──event─►│ Event Bus    │──event─►│Inventory │
│ Service  │        │ (SNS/SQS)    │        │ Service  │
└──────────┘        └───────┬──────┘        └──────────┘
                            │
                       event│
                            │
                     ┌──────▼─────┐
                     │Notification│
                     │  Service   │
                     └────────────┘
```

**When to Use:**
- Loose coupling required
- Asynchronous processing
- High scalability needs
- Multiple consumers per event

**Pros:**
- ✅ Loose coupling
- ✅ Scalability
- ✅ Resilience
- ✅ Easy to add consumers
- ✅ Event replay capability

**Cons:**
- ❌ Eventual consistency
- ❌ Debugging complexity
- ❌ Message ordering challenges
- ❌ Duplicate message handling
- ❌ Monitoring difficulty

**Example:**
```typescript
// Order service publishes event
const event = {
  eventType: 'order.created',
  orderId: '12345',
  userId: 'user-789',
  items: [...],
  timestamp: new Date().toISOString()
};

await eventBridge.putEvents({
  Entries: [{
    Source: 'order-service',
    DetailType: 'OrderCreated',
    Detail: JSON.stringify(event)
  }]
});

// Inventory service subscribes
eventBridge.on('order.created', async (event) => {
  await reserveInventory(event.items);
});

// Notification service subscribes
eventBridge.on('order.created', async (event) => {
  await sendOrderConfirmation(event.userId, event.orderId);
});
```

---

### 5. CQRS (Command Query Responsibility Segregation)

**Description:**
Separate read and write models for different optimization.

**Structure:**
```
Write Side:                    Read Side:
┌──────────┐                  ┌──────────┐
│ Commands │                  │ Queries  │
└────┬─────┘                  └────┬─────┘
     │                             │
┌────▼─────┐                  ┌────▼─────┐
│Write Model│                  │Read Model│
│(Normalized)                  │(Denorm.) │
└────┬─────┘                  └────▲─────┘
     │                             │
     │      ┌────────────┐         │
     └─────►│Event Store │─────────┘
            └────────────┘
```

**When to Use:**
- Complex domain logic
- Different read/write performance needs
- Audit requirements
- Temporal queries needed

**Pros:**
- ✅ Optimized read models
- ✅ Scalability (independent scaling)
- ✅ Audit trail
- ✅ Temporal queries
- ✅ Multiple read models

**Cons:**
- ❌ Complexity
- ❌ Eventual consistency
- ❌ More storage
- ❌ Synchronization overhead
- ❌ Learning curve

**Example:**
```typescript
// Write side: Commands
class CreateOrderCommand {
  constructor(
    public userId: string,
    public items: OrderItem[]
  ) {}
}

class OrderAggregate {
  async handle(command: CreateOrderCommand) {
    // Validate business rules
    const order = this.createOrder(command);

    // Persist event
    const event = new OrderCreatedEvent(order);
    await eventStore.append(event);

    return order.id;
  }
}

// Read side: Queries
class GetOrderQuery {
  constructor(public orderId: string) {}
}

class OrderQueryHandler {
  async handle(query: GetOrderQuery) {
    // Optimized read model (denormalized)
    return await readDb.query(`
      SELECT o.*, u.name as user_name, p.name as product_name
      FROM orders_view o
      JOIN users u ON o.user_id = u.id
      JOIN products p ON o.product_id = p.id
      WHERE o.id = $1
    `, [query.orderId]);
  }
}

// Event handler: Updates read model
eventStore.on('OrderCreated', async (event) => {
  // Update denormalized read model
  await readDb.insert('orders_view', {
    order_id: event.orderId,
    user_id: event.userId,
    user_name: event.userName,  // Denormalized
    ...event.data
  });
});
```

---

### 6. Hexagonal Architecture (Ports & Adapters)

**Description:**
Application core isolated from external concerns.

**Structure:**
```
          Adapters (External)
              │
    ┌─────────┼─────────┐
    │         │         │
┌───▼──┐ ┌───▼──┐ ┌───▼──┐
│REST  │ │GraphQL│ │ CLI  │
│ API  │ │  API │ │      │
└───┬──┘ └───┬──┘ └───┬──┘
    │        │        │
    └────────┼────────┘
          Ports
        ┌────▼────┐
        │  Core   │
        │Business │
        │  Logic  │
        └────┬────┘
          Ports
    ┌────────┼────────┐
    │        │        │
┌───▼──┐ ┌───▼──┐ ┌───▼──┐
│Postgres│MongoDB│  S3  │
└──────┘ └──────┘ └──────┘
     Adapters (External)
```

**When to Use:**
- Complex business logic
- Multiple interfaces (REST, GraphQL, CLI)
- Testing important
- Technology flexibility needed

**Pros:**
- ✅ Testable business logic
- ✅ Technology independence
- ✅ Clear boundaries
- ✅ Maintainability
- ✅ Adapter swapping

**Cons:**
- ❌ More abstraction layers
- ❌ Initial complexity
- ❌ Boilerplate code
- ❌ Learning curve

**Example:**
```typescript
// Core domain (independent)
interface UserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User>;
}

class CreateUserUseCase {
  constructor(private userRepo: UserRepository) {}

  async execute(userData: CreateUserData) {
    const user = User.create(userData);
    await this.userRepo.save(user);
    return user;
  }
}

// Adapter: PostgreSQL implementation
class PostgresUserRepository implements UserRepository {
  async save(user: User) {
    await db.users.create({ data: user.toJSON() });
  }

  async findById(id: string) {
    const data = await db.users.findUnique({ where: { id } });
    return User.fromJSON(data);
  }
}

// Adapter: MongoDB implementation
class MongoUserRepository implements UserRepository {
  async save(user: User) {
    await mongodb.collection('users').insertOne(user.toJSON());
  }

  async findById(id: string) {
    const data = await mongodb.collection('users').findOne({ _id: id });
    return User.fromJSON(data);
  }
}

// REST API adapter
app.post('/users', async (req, res) => {
  const useCase = new CreateUserUseCase(
    new PostgresUserRepository()  // Swap easily
  );
  const user = await useCase.execute(req.body);
  res.json(user);
});
```

---

## Pattern Selection Guide

| Pattern | Team Size | Complexity | Ops Overhead | When to Use |
|---------|-----------|------------|--------------|-------------|
| Monolith | Small | Low | Low | MVP, small apps, simple domains |
| Microservices | Large | High | High | Complex domains, scale diversity |
| Serverless | Any | Medium | Very Low | Event-driven, variable load |
| Event-Driven | Medium+ | High | Medium | Async processing, loose coupling |
| CQRS | Medium+ | Very High | High | Complex reads, audit needs |
| Hexagonal | Any | Medium | Low | Testability, tech flexibility |

## Anti-Patterns

❌ **Microservices too early** - Start with monolith, extract services as needed
❌ **Distributed monolith** - Microservices with tight coupling (worst of both worlds)
❌ **Technology-driven** - Choosing pattern because it's trendy
❌ **Over-engineering** - CQRS+Event Sourcing for simple CRUD
❌ **Under-engineering** - Monolith when clear service boundaries exist

## Migration Strategies

### Monolith → Microservices
1. **Strangler Fig Pattern** - Gradually extract services
2. **Start with periphery** - Extract non-core services first
3. **Database per service** - Split databases gradually
4. **API gateway** - Unified entry point

### Synchronous → Event-Driven
1. **Dual write** - Write to DB and event store
2. **Change Data Capture** - CDC tools (Debezium)
3. **Gradual migration** - Migrate one flow at a time

---

**Related Resources:**
- system-design-principles.md - SOLID, 12-factor, CAP theorem
- reference-architectures.md - Real-world architecture examples
- migration-architecture.md - Migration patterns and strategies
