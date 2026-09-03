

| Capability | Decision | One-liner |
| --- | --- | --- |
| Agent runtime (kagent) | **Have** | Consolidate agents; don't add a framework. |
| Tool fabric (agentgateway MCP) | **Have** | One authz boundary; skip OpenFGA. |
| Multi-agent | **Build later (kagent A2A)** | Supervisor only when multi-domain routing is real. |
| Local serving (vLLM) | **Have → upgrade** | Move to AWQ 7–8B, `--max-num-seqs 8`. |
| QLoRA fine-tune (Unsloth) | **Build (add)** | One container + one Job. |

[] - Agent Runtime - KAgent
[] - Local serving (vLLM) - Move to AWQ 7–8B, `--max-num-seqs 8`.
[] - QLoRA fine-tune (Unsloth)
[] - Distillation dataset pipeline | **Build (add)** | Small script → hosted teacher → JSONL on NFS.
[] - knowledge-indexer + retrieval MCP
