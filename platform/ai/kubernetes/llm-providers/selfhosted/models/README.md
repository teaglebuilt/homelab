# Self-hosted vLLM model profiles

One GPU → one loaded checkpoint. Profiles are **kustomize Components** that
patch `Deployment/vllm-selfhosted` args + labels.

`--served-model-name` stays `vllm-selfhosted` so `ModelConfig/llmd-vllm-config`
and agentgateway routes never change when you switch weights.

## Profiles (4070 SUPER 12GB)

| Directory | Hugging Face id | Tool calling | Notes |
|-----------|-----------------|--------------|-------|
| `qwen25-coder-14b-awq` | `Qwen/Qwen2.5-Coder-14B-Instruct-AWQ` | plugin + jinja via `qwen25-coder-tools` | Best coding; 8k context (fp8 KV) |
| `qwen25-coder-7b-awq` | `Qwen/Qwen2.5-Coder-7B-Instruct-AWQ` | plugin + jinja via `qwen25-coder-tools` | Faster coding; 32k context |
| `qwen3-8b-awq` | `Qwen/Qwen3-8B-AWQ` | built-in `hermes` + `qwen3` reasoning | No extra mounts |

## Optional tool assets (`qwen25-coder-tools`)

Qwen2.5-**Coder** does not speak Hermes `<tool_call>` — it needs the out-of-tree
`qwen2_5_coder` parser + few-shot chat template. Those files live in
`qwen25-coder-tools/` and are **only** mounted when a profile lists that
directory under its own `components:`.

```
qwen25-coder-7b-awq/kustomization.yaml
  components:
    - ../qwen25-coder-tools   # ConfigMap → /opt/vllm-parsers
  patches: [patch.yaml]       # --tool-parser-plugin / --chat-template args
```

Profiles that use a built-in parser (e.g. `qwen3-8b-awq`) omit that component,
so no ConfigMap or volume appears on the Deployment.

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
3. If you need custom parser files, add `components: [../qwen25-coder-tools]`
   (or a new tools Component) and point `--tool-parser-plugin` /
   `--chat-template` at `/opt/vllm-parsers/...`.
4. Point the parent `components:` at the new directory.
