# MCP tool playbook

This is a *capability map*, not a guarantee that these exact tools are connected. Inspect the actual bound MCP server tool declarations before use. Examples below reflect the public `n8n-mcp` management tooling and kagent 1.x bundled tools (October 2026). Another n8n MCP server may expose different schemas.

## Recommended tools and when to use them

| Need | Prefer | Fallback/notes |
| --- | --- | --- |
| MCP availability | `n8n_health_check` | Tool discovery/registration; don't mutate without working API |
| Find existing workflow | `n8n_list_workflows` | Search by exact ID/name; paginate if necessary |
| Read current graph | `n8n_get_workflow` | `mode: structure` for cheap topology, `full` for edits, `active` for published graph |
| Discover node types | `search_nodes`, `get_node`, `get_template` | Verify node operation and typeVersion |
| Inspect dynamic node values | `n8n_explore_node_resources` | May require credentials; avoid returning sensitive values |
| Pre-save validation | `validate_node`, `validate_workflow` | Use actual installed schemas |
| Create | `n8n_create_workflow` | Pass name, nodes, connections; remains inactive |
| Patch | `n8n_update_partial_workflow` | Prefer `validateOnly` then atomic update, retain unmodified nodes |
| Replace intentionally | `n8n_update_full_workflow` | Only after reading the whole graph and snapshotting |
| Instance validation | `n8n_validate_workflow` | `{id: ..., options: {profile: "strict"}}` where supported |
| Suggested repairs | `n8n_autofix_workflow` | Preview first via `applyFixes: false` |
| Execute test | `n8n_test_workflow` | Correct trigger, safe fixture/destination, real side-effect assessment |
| Execution debugging | `n8n_executions` | `action: get`, `mode: error` on failures |
| Baseline/rollback | `n8n_workflow_versions` | Local snapshot or n8n-native version, if supported |
| Homelab service/discovery | `k8s_get_resources`, `k8s_describe_resource` | Get namespace, service, endpoints, deployment, ConfigMap nonsecret keys |
| Cluster failures | `k8s_get_events`, `k8s_get_pod_logs` | Handle logs as sensitive; use minimal query scope |

## Concrete n8n calls (illustrative, not scripts to execute blindly)

```javascript
// 1. Read before modifying
n8n_list_workflows({ limit: 100 });
n8n_get_workflow({ id: "<workflow-id>", mode: "full" });

// 2. Dry-run a small correction and then write only after checking the dry-run
n8n_update_partial_workflow({
  id: "<workflow-id>",
  intent: "Fix data mapping for downstream node",
  validateOnly: true,
  operations: [
    { type: "updateNode", nodeName: "Transform", updates: { "parameters.assignments.assignments[0].value": "={{ $json.id }}" } }
  ]
});
// Note: field paths depend on actual node configuration; inspect get_node and existing graph.

// 3. Strict instance validation
n8n_validate_workflow({ id: "<workflow-id>", options: { profile: "strict" } });

// 4. If needed, request a preview of possible fixes (NOT mutation)
n8n_autofix_workflow({ id: "<workflow-id>", applyFixes: false });

// 5. Example HTTP trigger test (only when safe AND the HTTP trigger is available)
n8n_test_workflow({ workflowId: "<workflow-id>", triggerType: "webhook", data: { test_run: true, id: "fixture-001" } });

// 6. Example non-HTTP trigger test: prepare first; pinning isn't a sandbox
n8n_test_workflow({ workflowId: "<workflow-id>", method: "prepare" });
// Then use the returned node names to create pinData for a separately approved safe test.

// 7. Inspect terminal status (not only the start response)
n8n_executions({ action: "get", id: "<execution-id>", mode: "summary" });
n8n_executions({ action: "get", id: "<failed-execution-id>", mode: "error" });

// 8. Check version snapshots before/after an update
n8n_workflow_versions({ mode: "list", workflowId: "<workflow-id>", limit: 5 });
```

## kagent lookup strategy

1. Inspect discovered tools on the `RemoteMCPServer` resource and its `Accepted` condition; the installed tool catalog can differ by version. If the agent has no discovery tool, have an operator run:

   ```sh
   kubectl get remotemcpserver -n ai
   kubectl get remotemcpserver <server-name> -n ai -o jsonpath='{range .status.discoveredTools[*]}{.name}{"\n"}{end}'
   ```

2. Query only needed ConfigMaps, Services, Endpoints/EndpointSlices, and Deployments through `k8s_get_resources`. Use `k8s_describe_resource`, scoped logs and events for failures. For n8n instance configuration confirm target URL from the running cluster rather than trusting examples in archived repository docs.
3. To check credential *availability*, use n8n's credential metadata/list capabilities if present; do not fetch raw secrets through cluster tools. A kagent tool that returns entire Kubernetes Secret YAML is **not** appropriate for finding tokens; even base64-encoded values remain sensitive.
4. If API auth is missing or an MCP server isn't reachable, mark `BLOCKED`, naming the resource or prerequisite required, and avoid speculative writes.

## Tool connection nuance

In kagent 1.x, `AgentTemplate.spec.tools[].mcp.server` only resolves a `RemoteMCPServer` **in the same namespace as the AgentTemplate**. In the `ai` namespace, register namespace-local references to your actual n8n MCP and authorized kagent tools endpoints; do not point a binding directly to a `RemoteMCPServer` CR in `kagent`. On the Claude harness the server's whole tool set may be available even when `mcp.tools` lists a subset; enforce high-risk restrictions on the MCP server/proxy or with human approval, not solely through the skill's prose.

## Sources

- https://kagent.dev/docs/kagent/1.x/skills-and-mcp/skills/
- https://kagent.dev/docs/kagent/1.x/skills-and-mcp/about-tools/
- https://kagent.dev/docs/kagent/1.x/reference/tools-ecosystem/
- https://www.n8n-mcp.com/docs/workflow-management
