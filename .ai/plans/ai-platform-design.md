# AI Platform — Design Plan

> **Status:** Design / architecture plan. Not an implementation. Produced by `homelab-architect` orchestration with specialist input (RAG, model-serving, browser/computer-use) and research into the [cnoe-io/ai-platform-engineering](https://github.com/cnoe-io/ai-platform-engineering) (CAIPE) project.
>
> **Scope:** Fills in and supersedes the stub feature stories under [`.ai/stories/ai/`](../stories/ai/index.md). This is the single source of truth for where the AI platform is going.
>
> **Audience:** `homelab-developer` (implementation) and future-me.

---

## 1. Vision & North Star

Build **my own AI platform** — a coherent, self-hosted system where I can run agents, give them tools and knowledge, serve open-weight models, and wire it all into the rest of the homelab. CAIPE ([cnoe-io/ai-platform-engineering](https://cnoe-io.github.io/ai-platform-engineering)) is the inspiration, **not the blueprint**: they are building an open-source *product* for multi-tenant enterprise platform-engineering teams, so they carry a lot of weight (Keycloak IdP federation, OpenFGA fine-grained authz, MongoDB config backbone, a dual-graph RAG stack, Slack/Webex/Backstage bots, 80+ formal specs) that exists to serve *other organizations*.

**This platform is for one operator (me).** That single fact is the design constraint that drives every "skip" decision below. The goal is the smallest coherent system that delivers the capabilities I actually want, built by *composing tools I already run* and writing only the thin connective tissue that's genuinely missing.

### What "good" looks like

- One **agent runtime** (kagent) with a handful of well-scoped agents, composed via in-process A2A subagents when a task spans domains — never a mesh of one-service-per-agent.
- One **tool fabric**: every capability (GitHub, browser, knowledge search, k8s ops, compute) is an MCP server, aggregated behind **agentgateway** as the single tool/authz boundary.
- One **model layer**: local vLLM for cheap/private/high-volume traffic; hosted frontier models (Claude/GPT/Bedrock) for reasoning, long context, and as the *teacher* for distillation.
- One **knowledge layer**: Qdrant + a small indexer, fed by my RSS stars and my markdown vault, queryable by both the chat UI and agents through the same MCP tool.
- **Front doors** I already have: OpenWebUI (chat), n8n (events/schedules/glue), Claude Code/Cursor (agents-as-tools via the kagent `/mcp` endpoint). Matrix only if I actually want phone-reachable ChatOps.

---

## 2. Guiding Principles (and what we adopt vs. skip from CAIPE)

| Principle | Consequence |
| --- | --- |
| **For me, not for an org.** | No multi-tenancy, no IdP federation, no per-user RBAC. |
| **Compose, don't reinvent.** | Reuse kagent, agentgateway, Qdrant, ollama, n8n, OpenWebUI, crawl4ai. Build only the ~200-LOC glue that's missing. |
| **One tool boundary.** | All tools are MCP servers behind agentgateway. This is CAIPE's best pattern and I already run the gateway. |
| **In-process composition over microservice mesh.** | Multi-agent = kagent A2A subagents, not one Deployment per tool-agent. CAIPE *themselves* abandoned the mesh. |
| **The GPU is sacred.** | One 12 GB card. Every design choice respects that it can hold exactly one heavy workload at a time. |
| **Honest anti-over-engineering.** | If a component exists to solve scale/tenancy/compliance I don't have, it's a "skip." |

### Adopt from CAIPE

- **MCP as the universal tool interface**, with a gateway enforcing policy before the tool call. (Already have agentgateway; skip their OpenFGA.)
- **Config/GitOps-declared agents** as source of truth. (kagent CRDs already give this — better than their MongoDB-backed records for a solo GitOps repo.)
- **A RAG server that exposes itself as an MCP tool** so agents query the KB as a tool.
- **A scheduler for event/cron-driven agent runs.** (Reuse n8n instead of building their `cron-runner`.)
- **"Worse is Better":** direct, flat, duplication over premature abstraction. Correct instinct for a solo maintainer.

### Skip from CAIPE (enterprise weight, not my problem)

- **The entire identity/authz stack** — Keycloak IdP federation, OpenFGA PDP, RBAC refactor, OBO/HMAC agent-context tokens. Replace with existing Cloudflare Access / internal gateway auth.
- **A2A-as-microservices** (one deployed service per tool agent). Use in-process subagents.
- **The RAG trifecta** — Milvus + Neo4j dual-graph + ontology-discovery agent + MinIO + etcd + Redis. Start with plain dense vector search on Qdrant.
- **MongoDB/GridFS config backbone, audit_service, keycloak_sync, skills entitlement/scanning.** GitOps + SOPS is my backbone.
- **Multi-client bots (Slack + Webex + Backstage).** Only the front doors I use.
- **80+ formal specs/ADRs.** Useful to *read* their decisions; not to replicate the process.

> ⚠️ **CAIPE is mid-migration.** Their docs describe a LangGraph supervisor + per-agent-A2A model that the `main` code has replaced with an in-process `deepagents` runtime, and their "multi-agent result synthesis" spec is explicitly **abandoned**. Treat their multi-agent *result-merging* as unsettled — do not copy it as proven.

---

## 3. Current-State Assessment

The platform is **already substantial** — this is a *consolidation + fill-the-gaps* effort, not greenfield. Everything lives in `platform/ai/`, deployed via Kustomize (`task ai:deploy`, mlops cluster only).

### What's real and deployed (in the kustomization build)

| Component | Where | Notes |
| --- | --- | --- |
| kagent 0.9.11 + agentgateway v2.2.1 | `platform/ai/kubernetes/kustomization.yaml` | `kmcp` enabled; hardened securityContext. **Substrate disabled** (`controller.substrate.enabled: false`). |
| AI gateway (agentgateway) | `.../aigateway/gateway.yaml` | HTTP/HTTPS listeners, OTel tracing params. Fronts UI + `/mcp`. |
| MCP tool fabric | `.../mcp-backend.yaml`, `mcp-route.yaml` | Aggregates github, comfyui, kagent-tools/querydoc/controller on `/mcp`. |
| LLM providers | `.../llm-providers/{selfhosted,nim,ollama,anthropic,openai,bedrock,comfyui}` | vLLM (Qwen2.5-3B), NIM (llama-3.2-3b), ollama, + hosted. |
| Self-hosted vLLM | `.../llm-providers/selfhosted/` | `vllm/vllm-openai:v0.11.0` pinned (CUDA 12.8), registered to kagent as `llmd-vllm-config` ModelConfig. |
| OpenWebUI | `.../integrations/openwebui/` | Helm chart 8.19.0. **Native Qdrant RAG not actually enabled** (silently on Chroma). |
| crawl4ai | `.../integrations/crawl4ai/` | Scrape-to-markdown. **Wastefully pinned to the GPU** (`nvidia.com/gpu: 1`). |
| openedai-speech | `.../integrations/openedai-speech/` | TTS. |
| Qdrant | `platform/data/kubernetes/apps/qdrant/` | Deployed into `ai` ns, `qdrant.ai.svc.cluster.local`. **API key is a hardcoded placeholder**, secret wiring commented out. |
| ollama `nomic-embed-text` | `.../llm-providers/ollama/models/` | 768-dim embeddings. |
| Observability | `platform/observability/...` | OTel → collector → Grafana dashboards (`agent-tracing`, `llm-usage`). |
| n8n | `platform/automation/kubernetes/n8n/` | Live; **already granted** access to the `ai` mcp-backend (`referencegrant-automation-to-mcp.yaml`). |
| FreshRSS | `platform/news/compose.yaml` | On Docker/LAN (not cluster). Google Reader API enabled. |

### What's staged/aspirational (NOT in the build) — accuracy matters here

- **Hermes AgentHarness** (`.../harness/hermes.yaml`): references `runtime: substrate` + a `kagent-default` worker pool, but **Substrate is disabled** in the Helm values and `harness/` is **not listed** in the top-level kustomization. → **Not deployed. Won't run until Substrate is enabled and wired.**
- **devbot computer-control agent** (`platform/ai/agents/computer_control/`): a **non-functional husk** — empty `Chart.yaml`, no `deployment.yaml`, no Service, no `RemoteMCPServer`, no MCP server process in the image, references non-existent Gitea/Harbor (`*.agentydragon.com`), and has a `devbot`/`agentdev` user mismatch. **Not in the build. Cannot run as-is.**
- **LiteLLM** (`.../integrations/litellm/`): Claude-Code→NIM bridge; commented out of `integrations/kustomization.yaml`.

### Known defects to fix regardless of new features

1. **Qdrant API key** is `your-super-secret-api-key` (placeholder) with `secretKeyRef` commented out → fake auth boundary + plaintext secret. **Fix before anything depends on Qdrant.**
2. **OpenWebUI RAG** never points at Qdrant (`VECTOR_DB`/`QDRANT_URI` unset) → using internal Chroma silently.
3. **crawl4ai squats on the GPU** → drop `runtimeClassName: nvidia` + GPU nodeSelector + `nvidia.com/gpu` req/limit.
4. **GPU PriorityClass trap** (`kubernetes/apps/hardware/nvidia/priorityclass.yaml`): `gpu-training` is *lower* priority than `gpu-serving`, so a training Job requesting the GPU sits **Pending forever** while vLLM holds it. This is a safe default but is **not** time-sharing — it must be documented, and training requires manual scale-to-zero of serving.

---

## 4. Target Architecture

```
                                   ┌─────────────────────── FRONT DOORS ───────────────────────┐
                                   │  OpenWebUI (chat)   n8n (events/cron/glue)   Claude Code    │
                                   │        │                   │                  /Cursor       │
                                   └────────┼───────────────────┼───────────────────┼───────────┘
                                            │                   │                   │ (kagent /mcp:
                                            ▼                   ▼                   │  list+invoke_agent)
                          ┌───────────────────────────────────────────────────────────────────┐
                          │                    agentgateway  (ai namespace)                     │
                          │   /  → kagent UI        /mcp → mcp-backend (tool fabric + authz)     │
                          └───────────────┬───────────────────────────────┬───────────────────┘
                                          │                               │
                          ┌───────────────▼──────────────┐   ┌────────────▼─────────────────────┐
                          │      AGENT RUNTIME (kagent)    │   │        MCP TOOL FABRIC            │
                          │  supervisor (A2A parent, opt.) │   │  github · knowledge-search       │
                          │   ├─ k8s-ops agent             │   │  playwright · crawl4ai(scrape)   │
                          │   ├─ knowledge/research agent   │──▶│  kagent-tools/querydoc/controller│
                          │   ├─ browser agent             │   │  comfyui · devbot-computer(defer)│
                          │   └─ (Hermes harness, deferred)│   └──────────────┬───────────────────┘
                          │  memory · HITL · skills(OCI/git)│                  │
                          └───────────────┬────────────────┘                  │
                                          │ ModelConfig                        │ tools call out
                    ┌─────────────────────▼─────────────────┐    ┌────────────▼───────────────┐
                    │            MODEL LAYER                  │    │      KNOWLEDGE LAYER        │
                    │ local: vLLM (AWQ 7-8B) · NIM · ollama   │    │ knowledge-indexer (FastAPI) │
                    │ hosted: Claude · GPT · Bedrock (teacher)│    │  /ingest  +  /mcp search    │
                    │ training: Unsloth QLoRA Job (scale-0)   │    │ Qdrant (knowledge_*) ·      │
                    └─────────────────────────────────────────┘    │ ollama nomic-embed 768d     │
                                          ▲                         └─────────────────────────────┘
                                          │ ONE GPU (RTX 4070 SUPER, 12 GB) — one heavy workload at a time
                                          └── embeddings on CPU · crawl4ai off-GPU · train via scale-to-zero
```

**The spine:** agentgateway is the one ingress for both the UI and the tool/authz fabric. kagent is the one agent runtime. Everything an agent can *do* is an MCP target on `mcp-backend`. Everything an agent can *think with* is a ModelConfig. Everything an agent can *know* is the knowledge-search MCP tool. Front doors and event glue attach at the edges (OpenWebUI, n8n, IDE).

---

## 5. Feature Designs

### A. Agent Orchestration & Harness  *(the spine — owned by this plan)*

**Answering the story's questions directly:**

- **"Can you create your own harness?"** Yes — two ways in kagent: (1) an **`AgentHarness`** with a BYO backend (e.g. Hermes), or (2) a **BYO Agent** (custom container running LangGraph/ADK/CrewAI/OpenAI-Agents). **But you almost certainly shouldn't build one yet.** Declarative kagent agents + MCP tools cover the vast majority of use cases with far less to operate. Reach for a custom harness only when you need a persistent shell/computer loop that declarative agents can't express.

- **"Use cases for Hermes?"** The Hermes `AgentHarness` on **Agent Substrate (ATE / OpenShell)** is the *deep autonomous agent* path — a long-running agent with its own shell/compute environment (think: an ops/coding agent that iterates in a sandbox). It is heavier than a declarative agent. **Deferred** (see below) — it's currently non-functional because Substrate is disabled.

- **"Combine with n8n?"** n8n is the **event/schedule/glue backbone**, not an agent. Patterns: n8n cron → invoke a kagent agent (A2A endpoint) for scheduled runs; n8n webhook → agent for event-driven tasks; agent calls an n8n webhook *as a tool* for side effects (notify, write to a system); n8n owns the RSS-star poll and git-sync triggers (§C). This reuses n8n's existing ReferenceGrant into `ai` — the path is pre-wired.

**Orchestration pattern — start flat, add a supervisor only when earned.**

The CAIPE lesson is decisive: they moved *away* from a supervisor-routing-to-A2A-microservices toward in-process subagents. For a solo operator:

1. **Phase 1 — a small set of well-scoped declarative agents**, each owning a domain and a tool subset:
   - `k8s-ops` (kagent-tools/querydoc/controller MCP) — cluster inspection & ops.
   - `knowledge` / `research` (knowledge-search + crawl4ai + playwright) — retrieval + web.
   - `browser` (playwright MCP) — interactive web automation.
   - `llmd-inference-agent` (exists) — routes to local vLLM.
   You invoke the specialist directly. **No router needed for single-domain tasks — don't build one prematurely.**
2. **Phase 2 — add a `homelab-supervisor` A2A parent** *only when* multi-domain tasks (e.g. "research X, then apply a manifest") become a real, recurring need. It lists the specialists as `type: Agent` tools (kagent agents-as-tools). Keep **one level of delegation** — kagent discourages deep nesting, and CAIPE's result-synthesis is unsettled.

**Free capabilities from kagent to use deliberately (not by default):**
- **Long-term memory** (`spec.declarative.memory`) — vector-backed, auto-prefetch, session summarization. Enable per-agent where continuity matters (the research agent), not everywhere.
- **HITL tool approval** (`requireApproval`) — gate *powerful* tools (browser submit, any desktop action, filesystem writes, manifest apply). Cascades correctly through A2A subagents. This is the primary guardrail (§7).
- **Skills** (OCI/git refs) — package reusable agent behavior; align with each agent's tools.
- **Context compaction** — for long sessions / large tool outputs.
- **`/mcp` controller endpoint** — already how Claude Code/Cursor invoke cluster agents (`list_agents`/`invoke_agent`) via the `homelab-kagent` MCP server in `.mcp.json`. The platform is *already* an "agents-as-tools for my IDE" surface — a capability worth leaning into.

**Hermes / Substrate — deferred, deliberate.** To make the Hermes harness real: enable Substrate in the kagent Helm values (`controller.substrate.enabled: true`, create the worker pool), wire `harness/` into the kustomization, and provide the gateway token secret. **Do this only when you want an OpenShell-backed autonomous agent** — it's the highest-capability, highest-complexity option and shouldn't gate the rest of the platform.

**Decision:** _Flat specialist agents now; supervisor when multi-domain routing is real; Hermes/Substrate as a deliberate later experiment. Do not build a custom harness or a router on spec._

---

### B. Model Serving + Fine-Tuning / Distillation

**Hardware reality (one RTX 4070 SUPER, 12 GB, ~10.2 GB usable at 0.85 util):**

| Workload | Feasible? |
| --- | --- |
| Serve 3B bf16 (current) | ✅ comfortable |
| Serve **4-bit AWQ 7–8B** | ✅ **recommended serving target** |
| Serve 7B fp16 | ❌ 14 GB weights alone |
| **QLoRA** 3B / 7–8B | ✅ (one at a time, seq ≤2048, bs 1–2, grad checkpointing) |
| Full fine-tune (any size) | ❌ optimizer states blow past 12 GB |
| **True logit distillation** from a large teacher | ❌ teacher won't co-reside |
| **Sequence-level (data) distillation** from a *hosted* teacher | ✅ **the realistic path** |

**"Can I build my own model off distillation?"** Yes — the honest, hardware-appropriate meaning: **use a hosted frontier teacher (Claude/GPT/Bedrock — already wired) to generate a supervised dataset over your task distribution, then QLoRA a small local student (Qwen2.5-3B/7B, Llama-3.1-8B) with Unsloth, merge, and serve on vLLM.** This is imitation-via-SFT, not logit distillation (hosted APIs don't expose logits). It's standard and it works here.

**Minimal viable stack (and nothing more):**
- **Serving:** upgrade vLLM to an **AWQ 7–8B instruct** model (`--quantization awq`, keep `--enforce-eager`, set `--max-num-seqs 8`). This roughly doubles capability and becomes the target for merged distilled adapters.
- **Training:** **Unsloth** (lowest VRAM, single-GPU optimized) in a container, run as a plain Kubernetes **`Job`**. No Kubeflow, no Volcano, no Katib.
- **Datasets:** JSONL on the existing NFS PVC (`vllm-pvc`). Version by date/hash in the filename.
- **Tracking:** **nothing** at first — TensorBoard logs to the PVC. Add MLflow *only if* you exceed ~10 comparative runs.
- **Jupyter:** no persistent service. An ephemeral notebook pod during a training window at most.

**Distillation recipe:** (1) script hits hosted teacher → `{instruction,input,teacher_output}` JSONL (with rejection sampling for quality — this dataset is 90% of the outcome); (2) Unsloth QLoRA the student (rank 16–32, seq 2048, 1–3 epochs) in a `gpu-training` Job **after serving is scaled to 0**; (3) merge adapter, optionally AWQ-quantize, write to `/data/providers/vllm/`; (4) point vLLM `--model` at it + new `--served-model-name`, register a sibling ModelConfig; (5) eval vs. base/teacher before promoting traffic.

**GPU scheduling — the honest truth.** `nvidia.com/gpu` is integer/non-divisible; the card holds exactly one pod; the namespace ResourceQuota caps it at 1. MIG is unsupported on the 4070; time-slicing shares compute but **not** the 12 GB, so serve+train can't coexist regardless. The existing PriorityClasses protect serving (good default) but mean **training never auto-starts** — it's a guardrail, not a scheduler. **Approach:** a `task ai:train` target that scales `vllm-selfhosted` (and NIM/ollama) to 0, submits the Job, waits, scales back — with agent/app traffic **failing over to hosted providers** during the window so "local model down for training" is invisible. Manual scale-to-zero is the *correct* automation level for one GPU.

**Also:** don't run vLLM + NIM + ollama all resident "just in case" — only one holds the GPU. Pick vLLM primary; keep the others as flip-to configs.

---

### C. RAG + Knowledge Management

**One store, two paths.** Qdrant is the single source of truth; ollama `nomic-embed-text` (768d, keep on **CPU**) is the single embedder; one small **`knowledge-indexer`** (FastAPI, ~200 LOC) owns chunk→embed→upsert and *also* exposes the retrieval MCP tool from the same process.

```
SOURCES              INGEST (write)             STORE           SERVE (read)
FreshRSS ─poll GReader─┐                       ┌────────┐   search_knowledge() ─▶ kagent agents + Claude Code
knowledge vault ─git──▶ knowledge-indexer ────▶│ Qdrant │◀──                       (mcp-backend target)
aiconfig ai-ml ─git──▶  (chunk·embed·upsert)   │knowledge_*│  OpenWebUI native RAG ─▶ chat UI (its own collections)
                              │ embed
                              ▼
                     ollama nomic-embed-text (768d, CPU)
```

**Ingestion:**
- **RSS "star → index"** (the concrete example): FreshRSS has **no star webhook**, so poll the **Google Reader API** (`/api/greader.php` → `user/-/state/com.google/starred`) on a short interval; new starred items → fetch/normalize → chunk → embed → upsert to `knowledge_rss`. Track processed IDs in the indexer PVC.
- **Markdown vault → index:** a CronJob (or n8n cron) does `git pull` on `~/github/teaglebuilt/knowledge` and `~/github/teaglebuilt/aiconfig/context/knowledge/ai-ml`, computes `git diff --name-status`, POSTs changed/deleted `.md` paths to `/ingest` (deletes remove points by `source_path`). Idempotent, incremental.

**Orchestration decision:** keep RAG logic in **versioned code** (the indexer), and let **n8n own only the triggers** (GReader poll + git-sync cron) — reusing the deployed scheduler and its existing grant into `ai`. Two Kubernetes `CronJob`s are the zero-extra-moving-parts alternative. **Do not** build the pipeline as n8n visual nodes, and **do not** route ingestion through OpenWebUI-native (it can't model "git repo" or "RSS star" and owns its own collections/embedder).

**Collections** (size 768, cosine, single dense vector): `knowledge_rss`, `knowledge_vault`. Consistent payload schema (`source`, `source_path`, `url`, `title`, `tags`, `chunk_index`, `sha`, `ingested_at`). Point ID = hash(`sha`+`chunk_index`) so re-ingest overwrites. Chunking: markdown-header-aware, ~512 tokens / ~50 overlap.

**Serving:** agents + Claude Code get `search_knowledge(query, collection?, top_k?, filter?)` as one more `mcp-backend` target (rides the existing agentgateway `/mcp` surface — zero consumer-side plumbing). OpenWebUI gets **two** independent uses: finish its **native Qdrant wiring** (`VECTOR_DB=qdrant`, `QDRANT_URI`, RAG embedder=nomic so dims match) for "drag a PDF into chat," *and* register the same retrieval MCP as an OWUI tool so chat can hit the curated KB. **Keep ownership split** (indexer owns `knowledge_*`; OWUI owns its uploads) — mixing embedders/dims in one collection silently corrupts search. **Skip kagent-querydoc** as the KB backbone (opaque, kagent-coupled).

**Skip (personal scale = thousands, not millions, of chunks):** rerankers, hybrid BM25/RRF, multi-query expansion, contextual compression, a FreshRSS star-webhook extension, and a fleet of microservices (one FastAPI pod with `/ingest` + `/mcp` + cron callers is the right size). Add complexity only when retrieval *visibly* fails — and measure first.

---

### D. Browser Use + Computer Use

**Two distinct capabilities — ~90% of agent web work needs only the first.**

**(a) Browser Use — do this first, high ROI.**
- **Deploy Playwright MCP** (`@playwright/mcp`, Microsoft, Apache-2.0) as a small headless-Chromium Deployment+Service in `ai`, registered as a `RemoteMCPServer` / `mcp-backend` target. It *is* an MCP server (~25 browser tools), defaults to **accessibility-tree snapshots** (2–5 KB, cheap/stable vs. screenshots), keeps a hot session (cookies/auth persist), near-zero maintenance. Deployment (not `stdio` MCPServer) because the browser is long-lived and stdio would cold-start Chromium every call.
- **Keep crawl4ai for read-only scrape→markdown**, but **un-pin it from the GPU** (defect #3) and wrap its HTTP API (`:11235`) as an MCP tool (`scrape_to_markdown(url)`). crawl4ai = stateless read; Playwright MCP = stateful interact. Complementary.
- **Skip the `browser-use` Python library as the primitive** — it embeds its *own* LLM loop; kagent is already the loop, so it'd be double agent loops + double tokens. Revisit only for a black-box "complete this web task" tool.
- **Defer Steel.dev** (self-hosted stealth/proxy CDP backend) until you actually hit anti-bot/datacenter-IP blocks; route its egress via the existing Cloudflare tunnel then.
- **Verdict: BUY.** Everything is off-the-shelf, MCP-ready; only thin manifests to write.

**(b) Computer Use (devbot) — deferred, experimental.**
- Today it's a **non-functional husk** (empty `Chart.yaml`, no deployment/service/MCP-server, references non-existent Gitea/Harbor, user mismatch). It cannot run.
- If/when pursued: **delete the Gitea/Harbor integrations** (use GitHub over a SOPS-delivered PAT + a generic NFS workspace); **base the desktop on Anthropic's computer-use reference container** (`ghcr.io/anthropics/anthropic-quickstarts:computer-use-demo-latest`) rather than a hand-rolled TigerVNC/XFCE image (it ships the working tool loop + every display/font/clipboard workaround); expose its tool interface as the `devbot-computer-control` `RemoteMCPServer`; write the missing `deployment.yaml`/`service.yaml`/`Chart.yaml` (or move to a plain `kubernetes/` subdir per repo convention).
- **Isolation (treat as hostile):** remove `docker.io`/DinD from the image; **default-deny Cilium egress** with a task-scoped allowlist (highest-leverage control); VNC only via authenticated route/port-forward (not bare LAN); non-root + resource quota; **on-demand** (scale 0→1 per task) not a persistent idle desktop.
- **Verdict:** a fragile, expensive, low-frequency 10%. Stand it up *after* browser use proves out, only for tasks with genuinely no web/API surface, and be willing to conclude it isn't worth the upkeep.

---

### E. Integrations (Front Doors & Glue)

| Integration | Role | Design | Verdict |
| --- | --- | --- | --- |
| **OpenWebUI** | Human chat front door | Already deployed. Wire it to invoke kagent agents (existing `pipelines/` pattern — `n8n_pipeline.py`, `github_pipeline.py`) + finish native Qdrant RAG (§C). | **Reuse + finish** |
| **n8n** | Event/schedule/glue backbone | Already granted into `ai`. Owns RSS-poll + git-sync triggers, scheduled/event agent invocations, notifications. Agents call n8n webhooks as tools. | **Reuse (core glue)** |
| **Claude Code / Cursor** | Agents-as-tools for my IDE | Already works via kagent controller `/mcp` (`homelab-kagent` in `.mcp.json`). Lean into it. | **Have it** |
| **Matrix** | Phone-reachable ChatOps + notifications | Net-new (not deployed). **Likely just an n8n workflow** (n8n has a Matrix node) relaying to/from agent A2A endpoints — not a new bespoke service. | **Defer / n8n-glue if wanted** |

**Honest call on Matrix:** it's a genuine nice-to-have (chat with agents + get notifications from a phone), but for a single operator OpenWebUI + n8n notifications cover most of it. If you want it, implement as an n8n Matrix workflow first; only build a dedicated bridge if that proves limiting.

---

## 6. Build vs. Buy vs. Skip — Master Table

| Capability | Decision | One-liner |
| --- | --- | --- |
| Agent runtime (kagent) | **Have** | Consolidate agents; don't add a framework. |
| Tool fabric (agentgateway MCP) | **Have** | One authz boundary; skip OpenFGA. |
| Multi-agent | **Build later (kagent A2A)** | Supervisor only when multi-domain routing is real. |
| Custom harness / Hermes / Substrate | **Defer** | Deliberate experiment, not a default. |
| Local serving (vLLM) | **Have → upgrade** | Move to AWQ 7–8B, `--max-num-seqs 8`. |
| Hosted models | **Have** | Reasoning, long ctx, distillation teacher, train-window fallback. |
| QLoRA fine-tune (Unsloth) | **Build (add)** | One container + one Job. |
| Distillation dataset pipeline | **Build (add)** | Small script → hosted teacher → JSONL on NFS. |
| Experiment tracking / Jupyter / Kubeflow | **Skip** | `runs/`+TensorBoard; add MLflow only if needed; never Kubeflow. |
| Vector store (Qdrant) | **Have → fix key** | Uncomment secret; drop placeholder. |
| Embeddings (nomic, CPU) | **Have** | Keep off the GPU. |
| knowledge-indexer + retrieval MCP | **Build (~200 LOC)** | The one net-new glue worth owning. |
| RSS star→index / git-sync | **Reuse n8n/CronJob** | Triggers only; logic in code. |
| Enterprise RAG (Milvus/Neo4j/ontology/reranker/hybrid) | **Skip** | Dense cosine top-k is enough. |
| Browser use (Playwright MCP) | **Buy/deploy** | The 90% workhorse. |
| Scrape (crawl4ai) | **Have → un-pin GPU + MCP-wrap** | Reclaim the GPU. |
| browser-use lib / Steel.dev | **Skip / defer** | Second agent loop / need-driven. |
| Computer use (devbot) | **Defer → Anthropic ref container** | Rebuild on the reference image, on-demand, or drop. |
| OpenWebUI / n8n / IDE | **Have** | Front doors + glue. |
| Matrix | **Defer (n8n-glue)** | Only if phone ChatOps is wanted. |
| Identity/authz (Keycloak/OpenFGA/RBAC) | **Skip** | Single operator; existing gateway/Cloudflare auth. |

---

## 7. Cross-Cutting Concerns

- **GPU discipline (the master constraint).** One heavy workload at a time. Primary = vLLM (AWQ 7–8B). Embeddings on CPU. crawl4ai off-GPU. ComfyUI on-demand. Training via scale-to-zero + hosted failover. Don't keep vLLM+NIM+ollama all resident. Document the PriorityClass behavior so future-me doesn't assume auto time-sharing.
- **Guardrails / security.** kagent **HITL approval** on all mutating/powerful tools (browser submit, desktop, fs writes, manifest apply). **Cilium default-deny egress** with task-scoped allowlists for browser/desktop pods (highest-leverage control). agentgateway as the single MCP boundary. Secrets stay in **SOPS+KMS** — never baked into images/prompts.
- **Observability.** Reuse the OTel→collector→Grafana path (`agent-tracing`, `llm-usage` dashboards already exist). Every new agent/tool should trace through it.
- **GitOps + declarative.** Agents, models, tools are CRDs/manifests in-repo (source of truth), deployed via `task ai:deploy`. This *is* the "config-driven agents" pattern CAIPE wanted — better for a solo repo than their DB backbone.

---

## 8. Phased Roadmap

Ordered by ROI-per-effort and dependency. Each phase is independently valuable.

- **Phase 0 — Hygiene / fix what's broken (low effort, do first).**
  Fix Qdrant secret wiring; enable OpenWebUI native Qdrant RAG; un-pin crawl4ai from the GPU; document the GPU PriorityClass trap; decide devbot's fate (leave husk out of the build, clearly marked WIP). *No new capability — removes footguns and reclaims the GPU.*

- **Phase 1 — Knowledge layer (highest personal ROI).**
  Build `knowledge-indexer` (`/ingest` + `/mcp search_knowledge`); collections + payload schema in Qdrant; RSS star→index via GReader poll (n8n) + git-sync (CronJob/n8n); add `knowledge-search` to `mcp-backend`; register it in OpenWebUI. *Delivers the "star an item → it's searchable by agents and chat" flow.*

- **Phase 2 — Browser use (high ROI automation).**
  Deploy Playwright MCP (Deployment+Service+RemoteMCPServer); MCP-wrap crawl4ai; Cilium egress policy on browser pods; HITL on mutating browser actions. *Agents can now drive the web.*

- **Phase 3 — Orchestration consolidation.**
  Define the specialist agent set (k8s-ops, knowledge, browser); wire OpenWebUI→agents (pipelines) and n8n event/cron→agent invocations; enable memory on the research agent; add the `homelab-supervisor` A2A parent only if multi-domain routing is a real need.

- **Phase 4 — Model lab.**
  Upgrade vLLM to AWQ 7–8B; add the Unsloth QLoRA `Job` + `task ai:train` scale-to-zero toggle; build the distillation dataset script against a hosted teacher; serve the merged student on vLLM behind a new ModelConfig. *Delivers "my own distilled model."*

- **Phase 5 — Deferred / experimental (only when justified).**
  Enable Hermes/Substrate for an OpenShell autonomous agent; rebuild devbot computer-use on the Anthropic reference container (on-demand, hardened) *if* a concrete non-web task appears; Matrix ChatOps as an n8n workflow *if* phone-reachable chat is wanted.

---

## 9. Open Questions for the Operator

1. **Supervisor agent:** do you have concrete multi-domain tasks in mind, or should we stay flat (invoke specialists directly) for now?
2. **Hermes/Substrate:** is a persistent OpenShell autonomous agent something you actively want soon, or park it as Phase 5?
3. **Matrix:** worth the ChatOps surface, or are OpenWebUI + n8n notifications enough? (Cheapest path is an n8n Matrix workflow.)
4. **Distillation target task:** what task distribution should the first distilled student specialize in (agent transcripts? a domain like k8s/homelab Q&A? RAG answering)? This choice defines the teacher-dataset script.
5. **devbot:** rebuild it on the Anthropic container, or delete the husk from the tree until a real computer-use need appears?
6. **Serving model pick:** AWQ build of Qwen2.5-7B-Instruct vs. Llama-3.1-8B-Instruct as the new vLLM default?

---

## 10. Related Agents & Skills

- **Agents:** `@architect` (this plan's owner via `/homelab-architect`), `@developer` (implementation), `@kubernetes-architect`, `@ml-engineer` / `@mlops-architect` (Phase 4), `@network-agent` (Cilium egress policies), `@security-agent` (HITL/guardrail review).
- **Skills:** `/homelab-architect`, `/kagent`, `/agentgateway`, `/kgateway`, `/nvidia-nim`, `/llm-app-patterns`, `/cloudflare-one` (tunnels/access).

## 11. Source Feature Stories (now superseded by this plan)

[`agent-harness`](../stories/ai/agent-harness.md) · [`browser-use`](../stories/ai/browser-use.md) · [`computer-use`](../stories/ai/computer-use.md) · [`rag`](../stories/ai/rag.md) · [`knowledge-management`](../stories/ai/knowledge-management.md) · [`vllm-open-weight-models`](../stories/ai/vllm-open-weight-models.md)
