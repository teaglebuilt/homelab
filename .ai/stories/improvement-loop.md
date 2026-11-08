# Agentic Learning

Can we use an n8n workflow to orchestrate the improvement loop for agents using agentevals now that is setup on the cluster?

- [ ] - setup [agent evals](./agentevaluations.md)
- [ ] - Use n8n workflow
- [ ] - Integrate agent task execution

- When agent (kagent) executs a task a learning record is created. kagent already creates tasks? [task-management](./task-framework.md)
```json
{
  "agent": "workflow-builder",
  "repository": "teaglebuilt/homelab",
  "task_id": "task-1042",
  "model": "Qwen/Qwen2.5-3B-Instruct",
  "agent_version": "v1",
  "task": "Create Firecrawl ingestion workflow",
  "outcome": {
    "workflow_created": true,
    "workflow_validated": false,
    "execution_passed": false
  },
  "feedback": {
    "category": "incorrect_node_parameters",
    "rating": 2,
    "corrective_action": "Verify node schema before creating"
  },
  "verified": true
}
```
