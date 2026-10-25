# build_workflow skill

Reusable kagent 1.x skill for delivering n8n workflows through an MCP-driven engineering cycle: discover → design → create/update → validate → test → inspect → repair → retest → report.

## Installation into `teaglebuilt/homelab`

Copy the entire directory to `platform/ai/skills/build_workflow/`, preserving `SKILL.md` at the directory root. Commit it to a Git repository accessible to the kagent skill source fetcher. Get the **full commit SHA** that contains the skill, not a branch/tag or short SHA:

```sh
git add platform/ai/skills/build_workflow
git commit -m 'feat(ai): add build_workflow kagent skill'
git rev-parse HEAD
```

Merge the relevant `skills`, `tools`, and system-prompt sections from `examples/workflow-builder.agenttemplate.yaml` into the existing `workflow-builder` AgentTemplate in `ai`. Substitute the real commit SHA. kagent 1.x source refs are immutable and reject Git branch names; the `source.path` must select the directory holding `SKILL.md`.

You **must** configure a reachable n8n MCP server in `ai` and an authorized `RemoteMCPServer` for kagent tool-server operations in `ai`. These two example names are placeholders for namespace-local CR names, not new deployed services. Inspect `status.discoveredTools` and bind only tools actually installed. kagent 1.x does not allow referencing a `RemoteMCPServer` CR in another namespace.

After committing, validate against installed kagent CRDs and apply your merged AgentTemplate via your normal GitOps deployment. kagent needs an Agent/Harness pairing to run the AgentTemplate; modifying the template alone does not launch a runtime. Newly created workflow development should use a non-production n8n instance or safe destinations.

## Dry acceptance exercise

With the agent running and n8n MCP configured, ask it:

> Build an inactive n8n workflow with a test webhook that accepts `{ "id": "test-1", "message": "hello" }`, normalizes `message` to uppercase, and returns the normalized result. Use your tools to validate, safely test at least one successful request and one malformed request, inspect terminal execution results, repair failures and report the workflow ID and evidence. Do not publish or activate production resources.

If the available server cannot trigger a safe inactive workflow, it must report an explicitly unverified state, not manufacture success.

## Local static checks

```sh
python3 -m unittest discover -s platform/ai/skills/build_workflow/tests -v
```

These check documentation/package integrity, **not** live MCP connectivity or workflow execution.

## Notes

- The provided `repository.zip` is older than the homelab repository layout described in newer conversations. The skill is delivered as a focused patch, not a replacement archive for your repository; this prevents older files (including local configurations) from overwriting current ones.
- n8n MCP method signatures vary across providers and releases. The skill instructs the agent to inspect bound tool descriptions first.
- Source documentation: https://kagent.dev/docs/kagent/1.x/skills-and-mcp/skills/ and https://www.n8n-mcp.com/docs/workflow-management.
