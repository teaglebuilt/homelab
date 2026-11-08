# Agentic Engineering

## Agent Catalog

| Agent | Purpose |
| --- | --- |
| `solutions-architect` | design and architect engineering solutions |
| `workflow-builder` | design and build workflows on n8n |
| `sre-team` | system reliability and observability |

## Agent Evaluations

First, generate output and traces from the agent
```sh
task platform:ai:evaluate \
  AGENT=solutions-architect \
  SUITE=solutions-architect \
  CASE=qdrant-architecture
```

load the traces to evaluate and score

```sh
task platform:ai:evals:score \
  SUITE=solutions-architect \
  TRACE=trace.otlp.json
```

## Agent Improvement
