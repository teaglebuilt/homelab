# Self-hosted vLLM model profiles

One GPU → one loaded checkpoint. Profiles are **kustomize Components** that
patch `Deployment/vllm-selfhosted` args + labels.

`--served-model-name` stays `vllm-selfhosted` so `ModelConfig/llmd-vllm-config`
and agentgateway routes never change when you switch weights.

## Profiles (4070 SUPER 12GB)

| Directory | Hugging Face id | Notes |
|-----------|-----------------|-------|
| `qwen25-coder-14b-awq` | `Qwen/Qwen2.5-Coder-14B-Instruct-AWQ` | Best coding quality; 4k context (12GB KV tight) |
| `qwen25-coder-7b-awq` | `Qwen/Qwen2.5-Coder-7B-Instruct-AWQ` | Faster coding; 32k context |
| `qwen3-8b-awq` | `Qwen/Qwen3-8B-AWQ` | General + Qwen3 reasoning parser |

## Switch

Edit `../kustomization.yaml` — keep **exactly one** entry under `components:`:

```yaml
components:
  - models/qwen25-coder-14b-awq
```

Or:

```bash
task platform:ai:vllm:model -- qwen25-coder-7b-awq
task platform:ai:vllm:model:list
```

Then redeploy the AI overlay (`task platform:ai:deploy CLUSTER=mlops`).

## Add a profile

1. Copy an existing `models/<name>/` directory.
2. Edit `patch.yaml` (`--model`, parsers, `--max-model-len`, labels).
3. Point `components:` at the new directory.
