Goal
----

Enable kagent long-term memory using a vector-capable Postgres (pgvector) backend and pick an embedding model/config strategy that fits our homelab constraints.

What I changed in this PR
- Turned on kagent's Postgres vector support (pgvector) in the mlops overlay Helm values.
  - File: platform/ai/kubernetes/overlays/mlops/kustomization.yaml
  - Change: database.postgres.vectorEnabled: true
- Added a ModelConfig for a dedicated embeddings model that kagent can reference.
  - File: platform/ai/kubernetes/llm-providers/embeddings/modelconfig-embeddings.yaml
  - Default: OpenAI provider using `text-embedding-3-small` (secret: openai-api-key-secret)
- Created this story/decision doc explaining choices and next steps.
  - File: .ai/stories/agent-memory/agent-memory.md

Why these changes
-----------------
1) Postgres vs Qdrant for kagent memory
   - kagent's memory system persists and searches vectors in the agent database layer. The kagent documentation and codebase support SQLite (libSQL) for dev and Postgres+pgvector for production. There is no first-class configuration in kagent to use an external vector DB (like Qdrant) as the agent's memory store.
   - Qdrant is already used in this repo as the knowledge store for the "knowledge tree" and `kb_search` tool. That's the correct architecture: keep the knowledge index in Qdrant (read-plane) and keep kagent memories in the kagent DB (write-plane) which supports TTL, access counters, and pruning.
   - Therefore: enable Postgres with pgvector for kagent memory. This centralizes agent session/events/memories and integrates with kagent's pruning and access-count logic.

2) Which embedding model to use (vLLM vs hosted provider)
   - Options:
     a) Use the existing vLLM self-hosted ModelConfig (llmd-vllm-config) to produce embeddings locally.
     b) Use a hosted embeddings model (OpenAI's text-embedding-3-* series) as a dedicated embeddings provider.
   - Considerations:
     - Dimensionality: kagent's docs expect embeddings of a particular dimensionality (the controller normalizes / truncates to a 768-d vector in some versions). Meanwhile our knowledge Qdrant collection uses BAAI/bge-small-en-v1.5 (384-d). Mixing dimensionalities between the knowledge index and agent memory will make cross-retrieval harder and inconsistent.
     - Capability: vLLM by default is an LLM inference server. Some vLLM deployments can serve OpenAI-compatible embedding endpoints if a compatible embedding model is installed/served; this requires extra configuration and confirmation that the served model produces the vector size we expect.
     - Cost and latency: hosted embeddings (OpenAI) are higher latency across the internet and have cost, but they provide well-tested, stable embedding sizes and quality. Self-hosted vLLM/embeddings remove external dependency and cost but require GPU, memory, and correct model choices.
   - Recommendation for this homelab:
     - Short term / easiest: configure kagent to use a hosted embeddings ModelConfig (OpenAI `text-embedding-3-small`) so memories start working predictably. This is what I've added in this PR as a ModelConfig called `embedding-model-openai`.
     - Long term: if you want to avoid external APIs, evaluate whether your vLLM deployment can serve embeddings (check vLLM docs / served model names). If it can, create a ModelConfig pointing to vLLM's embeddings endpoint (baseUrl + model name) and confirm the produced dimensionality. If vLLM embeddings are 768-d (or kagent can normalize appropriately), then switch the `embedding-model-openai` ModelConfig to point to vLLM.

How to enable memory for an Agent
--------------------------------
1) Create (or edit) the Agent/AgentTemplate's declarative.memory block and reference the embeddings ModelConfig above. Example (Agent YAML):

apiVersion: api.kagent.dev/v1alpha3
kind: Agent
metadata:
  name: my-agent
  namespace: ai
spec:
  declarative:
    modelConfig: claude-opus-5-direct
    memory:
      enabled: true
      modelConfig: embedding-model-openai
      # ttlDays: 30

2) Apply and watch the agent controller: `kubectl -n ai get agent my-agent -o yaml` — `status.conditions` should become Accepted=True and Ready=True. Use the UI to inspect memories.

Verification / testing
----------------------
- After deploying the updated Helm values (the kustomize overlay change) and the new ModelConfig, verify the kagent release (helm/kustomize) and then:
  1) Confirm Postgres has pgvector enabled and the expected tables/columns are present (check kagent Postgres schema or logs on startup).
  2) Create an Agent with memory enabled (see snippet above). Interact with it and use the `/api/memories` and `/api/memories/search` endpoints to confirm vectors are saved and searchable.
  3) Compare retrieved vectors / similarity results to the kb_search Qdrant results to confirm behavior. Remember the two systems may use different embedding models/dimensions.

Notes and next steps
--------------------
- If you want memory and the knowledge tree to share the same vector space (recommended for cross-retrieval), pick a single embedding model and use it for both: i.e., re-ingest the knowledge tree into Qdrant using the same embedding model or configure kagent memory to use the same model and dimensionality (if supported).
- If you prefer Qdrant as the canonical vector store for both memory and knowledge, we'd need to implement an adapter layer (outside kagent) that copies kagent's memory vectors into Qdrant and keeps TTL/pruning semantics in sync — this is more work and has operational complexity.
- If you want me to also:
  - configure an Agent resource in this PR with memory.enabled=true and the embedding ModelConfig referenced, or
  - convert the embedding ModelConfig to point at the vLLM self-hosted endpoint instead of OpenAI,
  say which option you prefer and I will update the PR.

References
----------
- kagent memory docs: https://kagent.dev/docs/kagent/1.x/agents/agent-memory/

