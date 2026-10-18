# Context management

An agent's prompt grows with the conversation: every message, tool call, and tool result accumulates, and long sessions eventually exceed the model's context window or degrade answer quality. Context compaction solves that by summarizing older session events so the prompt stays bounded while the agent keeps enough recent context to stay coherent.

This page applies to [declarative agents](https://kagent.dev/docs/kagent/1.x/agents/declarative-agents/), which run on the `kagent` harness. Compaction is a `spec.kagent` setting, so a Harness that selects `codex`, `claude`, or `byo` does not take compaction settings. Omitting the `compaction` block leaves the history uncompacted.

Compaction is configured on the Harness, not on the AgentTemplate. The setting belongs to the runner that drives the root agent, so the same AgentTemplate compacts differently on two Harnesses that set different values. An AgentTemplate cannot enable, disable, or tune compaction on its own. [Agent memory](https://kagent.dev/docs/kagent/1.x/agents/agent-memory/) follows the same Harness-versus-AgentTemplate split.

Two strategies ship, and both are configured on the same field:

- **Sliding window** -- `compactionInterval`, optionally with `overlapSize` -- summarizes each group of completed user-initiated invocations, pulling already-compacted invocations back into the next window so consecutive summaries overlap.
- **Tail retention** -- `tokenThreshold` with `eventRetentionSize` -- bounds the prompt once it passes a token count by summarizing the history but keeping the most recent events uncompacted.

## Configure compaction

The following manifest enables both strategies on a Harness resource that already selects the `kagent` harness. The `compaction` block is the only change. The rest of the Harness is unchanged.

```yaml
apiVersion: api.kagent.dev/v1alpha3
kind: Harness
metadata:
  name: my-harness
  namespace: kagent
spec:
  kagent:
    compaction:
      # Sliding window: summarize every 5 completed user-initiated invocations,
      # pulling the 2 most recent ones back into the next window so summaries overlap.
      compactionInterval: 5
      overlapSize: 2
      # Tail retention: once the prompt passes 24000 tokens, summarize the history
      # but keep the 10 most recent events uncompacted.
      tokenThreshold: 24000
      eventRetentionSize: 10
      # Optional: name a ModelConfig (in this Harness's namespace) to write the
      # summaries. When you omit it, the agent's own model summarizes.
      summarizer:
        modelConfigRef:
          name: summarizer-model-config
        # Optional: replace the runtime's default summarization prompt.
        # Must contain {conversation_history}, which the runtime replaces with
        # the rendered events.
        promptTemplate: >
          Summarize the following conversation so the agent can continue.
          {conversation_history}
  workload:
    image: ghcr.io/kagent-dev/kagent/golang-adk@sha256:eb1b0c7f635f31d464cff7cf212275f2642057a629ed20b39661e9f644f71f21
  substrate:
    workerPoolRef:
      name: kagent-default
    snapshotPolicy:
      location: s3://ate-snapshots/kagent/
```

`Harness.spec.kagent.compaction` is the only field this page owns. The generated [API reference](https://kagent.dev/docs/kagent/1.x/reference/api-ref#kagentharnesscompaction) carries the field-by-field schema, with types, defaults, and validation rules. [Agent harness](https://kagent.dev/docs/kagent/1.x/agents/agent-harness/) carries the complete Harness schema, including `workload`, `substrate`, and the harness selection.

The table below lists the compaction fields and their requirements:

| Field | Required | Description |
| --- | --- | --- |
| `compactionInterval` | Optional | The number of new user-initiated invocations that, once fully represented in the session, triggers a sliding-window compaction of those invocations. Minimum 1. |
| `overlapSize` | Optional | The number of already-compacted invocations pulled back into the next sliding window so consecutive summaries overlap. Requires `compactionInterval`. Minimum 0. |
| `tokenThreshold` | Optional | The prompt token count at which tail-retention compaction summarizes the history before the next model call. Requires `eventRetentionSize`. Minimum 1. |
| `eventRetentionSize` | Optional | The number of most recent events that tail retention keeps uncompacted. Requires `tokenThreshold`. Minimum 1. |
| `summarizer.modelConfigRef` | Optional | The ModelConfig in the Harness namespace that writes the summaries. When you omit it, the agent's own model summarizes. |
| `summarizer.promptTemplate` | Optional | Replaces the runtime's default summarization prompt. Must contain `{conversation_history}`, which the runtime replaces with the rendered events. |

## Admission rules

These are CEL validations on the CRD, so a manifest that breaks one is rejected by the API server at admission rather than failing at runtime. They are rules, not advice:

- At least one strategy must be configured -- `compactionInterval` or `tokenThreshold`.
- `tokenThreshold` and `eventRetentionSize` must be set together.
- `overlapSize` requires `compactionInterval`.
- A `promptTemplate` must contain `{conversation_history}`, which the runtime replaces with the rendered events.

## Summarizer model and revisions

The summarizer model resolves in the same way as the agent's own model: its config lands in the revision, its credentials and egress join the revision, and it joins the provenance. Changing the summarizer model therefore builds a new revision for every Agent that uses the Harness. A Session that is already running keeps summarizing with the model that it started with.

Naming an AgentTemplate's own model in `summarizer.modelConfigRef` is semantically a no-op for that AgentTemplate, because the runtime already summarizes by using that model by default. The setting applies to every Agent that uses the Harness, so templates that use a different model summarize with the named one instead. Setting the field still builds a new revision. A revision ID is a digest of the inputs that kagent resolved, and those inputs include each source resource's `metadata.generation`. Editing the Harness bumps that generation regardless of whether or not the result differs.

## Verify the configuration

If the summarizer names a ModelConfig that does not exist in the Harness namespace, the Agent is not ready. The failure surfaces on the Agent as `ResolvedRefs=False`, with a reason such as `resolve summarizer ModelConfig "x": model config "x" not found`. Confirm that the Agent is ready before relying on compaction:

```bash
kagent agent get <agent-name>
```

`READY` reports whether kagent built and prepared a revision. If `READY` stays `False`, inspect the Agent's conditions to find the failing reference:

```bash
kubectl get agent <agent-name> -n kagent -o jsonpath='{.status.conditions}' | jq
```

For more information, see [Your first agent](https://kagent.dev/docs/kagent/1.x/get-started/your-first-agent/).

## Next steps

[Declarative agents](https://kagent.dev/docs/kagent/1.x/agents/declarative-agents/)

Configure the rest of the kagent harness that compaction is enabled on.

[Agent memory](https://kagent.dev/docs/kagent/1.x/agents/agent-memory/)

Give agents on this Harness memory that outlasts a single conversation.

[API reference](https://kagent.dev/docs/kagent/1.x/reference/api-ref#kagentharnesscompaction)

Field-by-field schema for Harness.spec.kagent.compaction.
