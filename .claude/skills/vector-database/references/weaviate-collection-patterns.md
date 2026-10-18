# Weaviate Collection Patterns

## Table of Contents
1. [Client Setup](#client-setup)
2. [Basic Collection](#basic-collection)
3. [Named Vectors (Multi-Vector)](#named-vectors)
4. [Multi-Tenancy](#multi-tenancy)
5. [Query Patterns](#query-patterns)
6. [Batch Ingestion](#batch-ingestion)

---

## Client Setup

```python
import os
import weaviate
import weaviate.classes as wvc
from weaviate.classes.init import Auth

# Weaviate Cloud (Serverless)
client = weaviate.connect_to_weaviate_cloud(
    cluster_url=os.environ["WEAVIATE_URL"],        # from env — never hardcode
    auth_credentials=Auth.api_key(os.environ["WEAVIATE_API_KEY"]),
    headers={
        "X-OpenAI-Api-Key": os.environ["OPENAI_API_KEY"],  # if using text2vec_openai
    },
)

# Local / Docker
client = weaviate.connect_to_local()

# Always close connection
try:
    # ... your operations
    pass
finally:
    client.close()
```

---

## Basic Collection

```python
from weaviate.classes.config import (
    Configure, Property, DataType, VectorDistances
)

client.collections.create(
    name="VendorReview",

    # Vectorizer — picks embedding model
    vectorizer_config=Configure.Vectorizer.text2vec_openai(
        model="text-embedding-3-small",   # must match dimension below
    ),

    # Vector index
    vector_index_config=Configure.VectorIndex.hnsw(
        distance_metric=VectorDistances.COSINE,
        ef_construction=128,
        max_connections=64,
    ),

    # Multi-tenancy: set at creation, CANNOT change later
    multi_tenancy_config=Configure.multi_tenancy(enabled=False),

    # Properties
    properties=[
        Property(name="text",       data_type=DataType.TEXT),
        Property(name="source",     data_type=DataType.TEXT),
        Property(name="vendor_id",  data_type=DataType.TEXT),
        Property(name="rating",     data_type=DataType.NUMBER),
        Property(name="scraped_at", data_type=DataType.DATE),
    ],

    # Generative (optional, for RAG)
    generative_config=Configure.Generative.openai(model="gpt-4o-mini"),
)
```

---

## Named Vectors (Multi-Vector)

Use when different properties need different embedding strategies.

```python
client.collections.create(
    name="LeasePDF",

    # Named vectors — each property gets its own vector space
    vectorizer_config=[
        Configure.NamedVectors.text2vec_openai(
            name="summary_vec",
            source_properties=["summary"],
            model="text-embedding-3-small",
        ),
        Configure.NamedVectors.text2vec_openai(
            name="full_text_vec",
            source_properties=["full_text"],
            model="text-embedding-3-large",
        ),
    ],

    properties=[
        Property(name="summary",   data_type=DataType.TEXT),
        Property(name="full_text", data_type=DataType.TEXT),
        Property(name="lease_id",  data_type=DataType.TEXT),
        Property(name="tenant_id", data_type=DataType.TEXT),
    ],
)

# Query a named vector
collection = client.collections.get("LeasePDF")
result = collection.query.near_text(
    query="early termination clause",
    target_vector="summary_vec",   # specify which vector space to search
    limit=5,
)
```

---

## Multi-Tenancy

**Set `enabled=True` at collection creation — this cannot be changed later.**

```python
# Create multi-tenant collection
client.collections.create(
    name="TenantDocument",
    vectorizer_config=Configure.Vectorizer.text2vec_openai(
        model="text-embedding-3-small",
    ),
    multi_tenancy_config=Configure.multi_tenancy(
        enabled=True,
        auto_tenant_creation=False,  # explicit tenant management
    ),
    properties=[
        Property(name="content",    data_type=DataType.TEXT),
        Property(name="doc_type",   data_type=DataType.TEXT),
        Property(name="created_at", data_type=DataType.DATE),
    ],
)

collection = client.collections.get("TenantDocument")

# Create tenants
from weaviate.classes.tenants import Tenant
collection.tenants.create([
    Tenant(name="property_123"),
    Tenant(name="property_456"),
])

# Insert into a specific tenant
tenant_col = collection.with_tenant("property_123")
tenant_col.data.insert({
    "content": "Lease agreement for Unit 4B",
    "doc_type": "lease",
})

# Query within a specific tenant
result = tenant_col.query.near_text(
    query="late payment clause",
    limit=5,
)
```

---

## Query Patterns

### nearText (semantic only)
```python
collection = client.collections.get("VendorReview")

result = collection.query.near_text(
    query="emergency plumber available nights",
    limit=10,
    return_metadata=wvc.query.MetadataQuery(distance=True, score=True),
    filters=wvc.query.Filter.by_property("rating").greater_than(3.5),
)

for obj in result.objects:
    print(obj.properties["text"], obj.metadata.distance)
```

### Hybrid Search
```python
from weaviate.classes.query import HybridFusion

result = collection.query.hybrid(
    query="24-hour emergency plumber San Francisco",
    alpha=0.75,                              # 0=BM25 only, 1=vector only, 0.75=mostly vector
    fusion_type=HybridFusion.RELATIVE_SCORE, # or HybridFusion.RANKED
    limit=10,
    return_metadata=wvc.query.MetadataQuery(score=True, explain_score=True),
)
```

**Fusion algorithm choice:**
| Algorithm | When to Use |
|-----------|-------------|
| `RANKED_FUSION` | Default; stable ranking; good when scores vary widely |
| `RELATIVE_SCORE_FUSION` | When score magnitude matters; more sensitive to distribution |

### BM25 (keyword only)
```python
result = collection.query.bm25(
    query="plumber",
    query_properties=["text", "source"],
    limit=10,
)
```

### Generative (RAG)
```python
result = collection.generate.near_text(
    query="emergency plumber reviews",
    single_prompt="Summarize this review in one sentence: {text}",
    limit=5,
)

for obj in result.objects:
    print(obj.generated)
```

---

## Batch Ingestion

```python
import weaviate
from weaviate.util import generate_uuid5

collection = client.collections.get("VendorReview")

# Batch insert (rate-limited, recommended for >100 objects)
with collection.batch.dynamic() as batch:
    for item in items_to_insert:
        batch.add_object(
            properties={
                "text":      item["text"],
                "source":    item["source"],
                "vendor_id": item["vendor_id"],
                "rating":    item["rating"],
            },
            uuid=generate_uuid5(item["vendor_id"]),  # deterministic UUID = idempotent inserts
        )

# Check for batch errors
if collection.batch.failed_objects:
    for err in collection.batch.failed_objects:
        print(f"Failed: {err.message}")
```

---

## Collection Introspection

```python
# Check if collection exists
exists = client.collections.exists("VendorReview")

# Get collection config
collection = client.collections.get("VendorReview")
config = collection.config.get()
print(config.vectorizer_config)
print(config.multi_tenancy_config)

# List all collections
collections = client.collections.list_all()
for name, col in collections.items():
    print(name)

# Delete collection (irreversible)
client.collections.delete("VendorReview")
```
