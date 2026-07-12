# Reference Architectures

Real-world architecture examples for common application types with proven patterns and best practices.

## 1. E-Commerce Platform

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      CloudFront CDN                         │
│               (Static Assets, API Caching)                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
    ┌─────▼──────┐          ┌──────▼─────┐
    │    Web     │          │    API     │
    │  (S3/CF)   │          │  Gateway   │
    └────────────┘          └──────┬─────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
 ┌──────▼──────┐         ┌─────────▼─────────┐     ┌─────────▼─────────┐
 │   Product   │         │      Order        │     │     Payment       │
 │   Service   │         │     Service       │     │     Service       │
 │  (ECS)      │         │     (ECS)         │     │  (ECS + PCI DSS) │
 └──────┬──────┘         └────────┬──────────┘     └─────────┬─────────┘
        │                         │                          │
 ┌──────▼──────┐         ┌────────▼──────────┐     ┌─────────▼─────────┐
 │  Product DB │         │     Order DB      │     │    Payment DB     │
 │ (PostgreSQL)│         │   (PostgreSQL)    │     │  (PostgreSQL)     │
 │  Read Rep.  │         │   Multi-AZ        │     │  Encrypted        │
 └─────────────┘         └───────────────────┘     └───────────────────┘

        ┌────────────────────────────────┐
        │     Event Bus (EventBridge)    │
        │  order.created, inventory.low  │
        └────────┬───────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼─────┐ ┌───▼──────┐ ┌──▼──────┐
│Inventory│ │Email     │ │Analytics│
│Service  │ │Service   │ │Service  │
└─────────┘ └──────────┘ └─────────┘
```

### Key Components

**Frontend:**
- React SPA hosted on S3
- CloudFront for global CDN
- Server-side rendering for SEO

**API Gateway:**
- Kong for centralized auth, rate limiting
- JWT authentication
- API versioning (/v1/, /v2/)

**Services:**
- Product Service: Read-heavy, uses Redis cache
- Order Service: Write-heavy, ACID transactions
- Payment Service: PCI-DSS compliant, isolated VPC

**Data:**
- PostgreSQL for transactional data
- Read replicas for product catalog
- DynamoDB for session storage
- S3 for product images

**Event-Driven:**
- EventBridge for async communication
- Email notifications (order confirmation)
- Inventory updates
- Analytics tracking

### Traffic Patterns

```
Black Friday Load:
- Normal: 1,000 RPS
- Peak: 20,000 RPS (20x spike)
- Duration: 8 hours

Auto-Scaling:
- Product Service: 10 → 50 containers
- Order Service: 20 → 100 containers
- Database: Vertical scale before event
```

### Cost Breakdown (Monthly)

```
Compute (ECS Fargate): $3,000
Database (RDS): $1,500
CloudFront: $800
API Gateway: $400
S3 Storage: $100
Other: $200
Total: $6,000/month (avg)
Black Friday: $15,000 (spike month)
```

---

## 2. SaaS Multi-Tenant Platform

### Architecture Overview

```
┌───────────────────────────────────────────────────────┐
│              Route 53 (DNS)                           │
│         app.customer1.com → Load Balancer             │
│         app.customer2.com → Load Balancer             │
└─────────────────────┬─────────────────────────────────┘
                      │
              ┌───────▼────────┐
              │  Application   │
              │  Load Balancer │
              └───────┬────────┘
                      │
       ┌──────────────┼──────────────┐
       │              │              │
┌──────▼──────┐ ┌────▼──────┐ ┌────▼──────┐
│   API       │ │  Worker   │ │  Scheduler│
│ (Kubernetes)│ │  (Celery) │ │  (Cron)   │
└──────┬──────┘ └────┬──────┘ └────┬──────┘
       │             │              │
       └─────────────┼──────────────┘
                     │
        ┌────────────▼────────────┐
        │    PostgreSQL           │
        │  (Schema-per-tenant)    │
        │  or                     │
        │  (Shared schema +       │
        │   tenant_id column)     │
        └─────────────────────────┘

┌─────────────────────────────────────┐
│        Redis Cluster                │
│  - Session storage                  │
│  - Cache                            │
│  - Rate limiting (per tenant)       │
└─────────────────────────────────────┘
```

### Multi-Tenancy Patterns

**Option A: Shared Database, Shared Schema**
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  tenant_id INT NOT NULL,  -- Partition key
  email VARCHAR NOT NULL,
  UNIQUE(tenant_id, email)
);

-- Row-Level Security
CREATE POLICY tenant_isolation ON users
  USING (tenant_id = current_setting('app.tenant_id')::INT);
```

**Option B: Shared Database, Schema Per Tenant**
```sql
-- Separate schema for each tenant
CREATE SCHEMA tenant_123;
CREATE SCHEMA tenant_456;

-- Route queries to correct schema
SET search_path TO tenant_123;
SELECT * FROM users;
```

**Option C: Database Per Tenant**
```
Tenant 1 → Database 1
Tenant 2 → Database 2
Tenant 3 → Database 3

Pros: Maximum isolation, easy migration
Cons: Higher cost, complex management
```

### Rate Limiting Per Tenant

```typescript
// Redis-based rate limiting
async function checkRateLimit(tenantId: string, endpoint: string) {
  const key = `rate-limit:${tenantId}:${endpoint}`;
  const limit = getTenantLimit(tenantId);  // e.g., 1000 req/hour

  const count = await redis.incr(key);
  if (count === 1) {
    await redis.expire(key, 3600);  // 1 hour window
  }

  if (count > limit) {
    throw new RateLimitError(`Tenant ${tenantId} exceeded limit`);
  }
}
```

### Cost Model

```
Pricing Tiers:
- Starter: $29/month (10K requests, 1 GB storage)
- Professional: $99/month (100K requests, 10 GB storage)
- Enterprise: $499/month (unlimited requests, 100 GB storage)

Cost Allocation:
- Track usage per tenant (requests, storage, compute time)
- Bill based on tier + overages
```

---

## 3. Data Platform / Analytics

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Sources                             │
│  App DB, APIs, Third-party, Event Streams                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
           ┌──────────┴──────────┐
           │                     │
    ┌──────▼──────┐      ┌──────▼──────┐
    │  Ingestion  │      │   Kafka     │
    │  (Airbyte)  │      │  (Streams)  │
    └──────┬──────┘      └──────┬──────┘
           │                     │
           └──────────┬──────────┘
                      │
              ┌───────▼────────┐
              │   Data Lake    │
              │   (S3 Parquet) │
              └───────┬────────┘
                      │
       ┌──────────────┼──────────────┐
       │              │              │
┌──────▼──────┐ ┌────▼──────┐ ┌────▼──────┐
│   Spark     │ │   DBT     │ │  Airflow  │
│ (Transform) │ │(Transform)│ │(Orchestr.)│
└──────┬──────┘ └────┬──────┘ └────┬──────┘
       │             │              │
       └─────────────┼──────────────┘
                     │
        ┌────────────▼────────────┐
        │   Data Warehouse        │
        │   (Snowflake/BigQuery)  │
        └────────┬────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼──────┐ ┌──▼────────┐ ┌▼────────┐
│ Tableau  │ │ Superset  │ │ML Models│
│(BI Tool) │ │ (BI Tool) │ │(Sagemaker)
└──────────┘ └───────────┘ └─────────┘
```

### Data Pipeline

**Ingestion:**
```yaml
# Airbyte connector: PostgreSQL → S3
{
  "source": {
    "type": "postgres",
    "host": "prod-db.example.com",
    "database": "myapp",
    "tables": ["users", "orders", "products"]
  },
  "destination": {
    "type": "s3",
    "bucket": "data-lake",
    "format": "parquet",
    "partition_by": ["date"]
  },
  "schedule": "0 2 * * *"  # Daily at 2 AM
}
```

**Transformation (DBT):**
```sql
-- models/staging/stg_orders.sql
SELECT
  id,
  user_id,
  total,
  created_at::DATE as order_date,
  EXTRACT(YEAR FROM created_at) as order_year,
  EXTRACT(MONTH FROM created_at) as order_month
FROM {{ source('raw', 'orders') }}
WHERE created_at > '2020-01-01'

-- models/marts/fct_daily_revenue.sql
SELECT
  order_date,
  COUNT(*) as order_count,
  SUM(total) as revenue
FROM {{ ref('stg_orders') }}
GROUP BY order_date
```

**Orchestration (Airflow):**
```python
from airflow import DAG
from airflow.operators.bash import BashOperator

dag = DAG('daily_etl', schedule_interval='0 2 * * *')

ingest = BashOperator(
    task_id='ingest',
    bash_command='airbyte sync',
    dag=dag
)

transform = BashOperator(
    task_id='transform',
    bash_command='dbt run',
    dag=dag
)

ingest >> transform  # ingest then transform
```

---

## 4. ML Platform / AI Application

### Architecture Overview

```
┌────────────────────────────────────────────────────┐
│                 Client Application                 │
└──────────────────────┬─────────────────────────────┘
                       │
              ┌────────▼────────┐
              │   API Gateway   │
              └────────┬────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
   ┌──────▼─────┐ ┌───▼──────┐ ┌──▼────────┐
   │ Prediction │ │ Training │ │Monitoring │
   │   API      │ │  Service │ │ Service   │
   └──────┬─────┘ └───┬──────┘ └──┬────────┘
          │           │            │
   ┌──────▼─────┐ ┌───▼──────┐ ┌──▼────────┐
   │Model Store │ │ Feature  │ │  Metrics  │
   │ (S3/MLflow)│ │  Store   │ │ (Prom.)   │
   └────────────┘ └──────────┘ └───────────┘

Training Pipeline:
┌──────┐ → ┌────────┐ → ┌───────┐ → ┌───────┐ → ┌──────┐
│ Data │   │Feature │   │ Train │   │Evaluat│   │Deploy│
│ Prep │   │  Eng.  │   │ Model │   │ Model │   │Model │
└──────┘   └────────┘   └───────┘   └───────┘   └──────┘
```

### Model Serving

```python
# FastAPI for model serving
from fastapi import FastAPI
import mlflow.pyfunc

app = FastAPI()

# Load model at startup
model = mlflow.pyfunc.load_model('models:/sentiment-analysis/production')

@app.post("/predict")
async def predict(text: str):
    prediction = model.predict([text])
    return {
        "text": text,
        "sentiment": prediction[0],
        "confidence": prediction[1]
    }

# Auto-scaling based on RPS
# Scale 1 → 10 pods during high traffic
```

### Feature Store

```python
# Feast feature store
from feast import FeatureStore

store = FeatureStore(repo_path="feature_repo")

# Online serving (low latency)
features = store.get_online_features(
    entity_rows=[{"user_id": "123"}],
    features=["user_features:age", "user_features:location"]
).to_dict()

# Offline training (batch)
training_data = store.get_historical_features(
    entity_df=user_df,
    features=["user_features:*", "purchase_features:*"]
).to_df()
```

### MLOps Pipeline

```yaml
# CI/CD for ML models
name: Model Training Pipeline

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - name: Fetch training data
        run: python fetch_data.py

      - name: Train model
        run: python train.py

      - name: Evaluate model
        run: python evaluate.py

      - name: Compare with production
        run: python compare_models.py

      - name: Deploy if improved
        if: steps.compare.outputs.better == 'true'
        run: |
          mlflow models serve \
            -m models:/sentiment/production \
            -p 5000
```

---

## 5. Real-Time Chat Application

### Architecture Overview

```
┌────────────────────────────────────────────────┐
│          Clients (Web, Mobile)                 │
└───────────────────┬────────────────────────────┘
                    │ WebSocket
           ┌────────▼────────┐
           │  Load Balancer  │
           │ (sticky sessions)│
           └────────┬────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
  ┌─────▼──┐  ┌────▼───┐  ┌───▼────┐
  │WebSocket│ │WebSocket│ │WebSocket│
  │Server 1│  │Server 2│  │Server 3│
  └─────┬──┘  └────┬───┘  └───┬────┘
        │          │          │
        └──────────┼──────────┘
                   │
        ┌──────────▼──────────┐
        │   Redis Pub/Sub     │
        │  (Message Broker)   │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │   Cassandra         │
        │  (Message History)  │
        └─────────────────────┘
```

### Real-Time Communication

```typescript
// WebSocket server
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';

const io = new Server(3000);

// Redis adapter for scaling across servers
const pubClient = new Redis(process.env.REDIS_URL);
const subClient = pubClient.duplicate();
io.adapter(createAdapter(pubClient, subClient));

io.on('connection', (socket) => {
  const userId = socket.handshake.auth.userId;

  // Join user-specific room
  socket.join(`user:${userId}`);

  socket.on('message', async (data) => {
    const message = {
      id: generateId(),
      from: userId,
      to: data.to,
      text: data.text,
      timestamp: new Date()
    };

    // Persist to database
    await cassandra.execute(
      'INSERT INTO messages (id, from_user, to_user, text, timestamp) VALUES (?, ?, ?, ?, ?)',
      [message.id, message.from, message.to, message.text, message.timestamp]
    );

    // Send to recipient (real-time)
    io.to(`user:${data.to}`).emit('message', message);
  });
});
```

### Scaling WebSockets

```
Problem: WebSocket connections are stateful

Solution 1: Sticky sessions
- Load balancer pins client to same server
- Works but limits scaling

Solution 2: Redis Pub/Sub
- Servers subscribe to channels
- Messages broadcast across all servers
- Recipient receives regardless of server connection

Example:
User A on Server 1 sends message to User B on Server 2
Server 1 → Redis → Server 2 → User B
```

---

## Best Practices Across All Architectures

✅ **Multi-region** - Critical for DR and global performance
✅ **Auto-scaling** - Handle variable load
✅ **Monitoring** - Metrics, logs, traces
✅ **Caching** - Redis for hot data
✅ **CDN** - CloudFront for static assets
✅ **Database read replicas** - Scale reads
✅ **Event-driven** - Decouple services
✅ **Security** - mTLS, encryption, zero trust
✅ **Cost optimization** - Reserved instances, spot, auto-scale down

---

**Related Resources:**
- architecture-patterns.md - Patterns used in these examples
- multi-region-design.md - Global deployment
- capacity-planning.md - Sizing these architectures
- cost-architecture.md - Cost optimization
