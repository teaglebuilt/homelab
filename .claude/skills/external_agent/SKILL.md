---
name: delegate-to-kagent
description: Delegate specialized tasks to kagent agents running in the homelab cluster using the homelab agent MCP server.
---

# Delegate to agent

Use this skill when a task is better handled by a specialized agent running in the homelab Kubernetes cluster.

The primary delegation tool is:

`mcp__homelab-agent__kagent-controller_invoke_agent`

This tool invokes a kagent agent remotely and returns the agent's response.

## When to use this skill

Delegate when:

- the task belongs to a specialized domain agent
- the cluster agent has tools or context not available locally
- the task requires Kubernetes, Cilium, GPU, observability, research, or infrastructure-specific expertise
- multiple independent investigations can be delegated and their results combined
- the user explicitly asks to consult or invoke a cluster agent

Do not delegate trivial questions that can be answered directly.

Do not repeatedly call agents when the previous result already contains enough information.

## Delegation workflow

1. Understand the user's goal.
2. Determine whether a specialized cluster agent is appropriate.
3. Select the most specific agent available.
4. Form a self-contained task for that agent.
5. Invoke the agent with `mcp__homelab-agent__kagent-controller_invoke_agent`.
6. Review the returned result.
7. If necessary, invoke another specialist.
8. Synthesize the results into one answer for the user.

## Agent selection

Prefer the narrowest relevant specialist.

Examples:

- Kubernetes workload problems → `platform-engineer`
- Cilium networking problems → `cilium-agent`
- NVIDIA or GPU problems → `gpu-agent`
- logs, metrics, traces → `observability-agent`
- GitHub or web research → `research-agent`
- ArgoCD or GitOps problems → `gitops-agent`

If no specialist clearly matches, use `platform-engineer`.

See `references/agent-catalog.md` for the current agent catalog.

## Invoking an agent

Use:

`mcp__homelab-agent__kagent-controller_invoke_agent`

Provide:

- the target agent
- a complete task description
- relevant context
- desired output
- important constraints

The delegated task should be understandable without access to the current conversation.

### Good delegated task

Investigate why pods in namespace `ai` cannot communicate with Qdrant.

Check:
- pod readiness
- services and endpoints
- Cilium endpoints
- CiliumNetworkPolicies
- Hubble flows and drops
- DNS resolution

Return:
1. evidence gathered
2. likely root cause
3. recommended remediation

Do not change cluster state unless explicitly required.

### Bad delegated task

"Check the problem."

The remote agent may not have enough context to understand what problem is being referenced.

## Example: single-agent delegation

User request:

> Why can't OpenWebUI reach Qdrant?

Determine that this is primarily a networking issue.

Invoke the `cilium-agent` using:

`mcp__homelab-agent__kagent-controller_invoke_agent`

Task:

Investigate connectivity between OpenWebUI and Qdrant in the `ai` namespace.

Inspect Kubernetes Services, Endpoints, CiliumEndpoints, policies, DNS, and Hubble flows.

Identify the likely cause and return supporting evidence.

Do not make any cluster changes.

After receiving the response:

- verify whether the evidence supports the conclusion
- explain the findings to the user
- only suggest remediation supported by the investigation

## Example: multi-agent investigation

User request:

> My AI workloads are suddenly slow. Figure out why.

This crosses multiple domains.

Delegate independently:

### GPU investigation

Agent: `gpu-agent`

Task:

Investigate whether GPU saturation, VRAM pressure, throttling, PCIe link degradation, device plugin issues, or DCGM metrics explain the slowdown.

Return evidence and likely causes.

### Observability investigation

Agent: `observability-agent`

Task:

Investigate recent latency changes across AI workloads.

Check metrics, logs, traces, pod restarts, resource pressure, request latency, and dependency performance.

Return evidence and likely causes.

### Platform investigation

Agent: `platform-engineer`

Task:

Investigate Kubernetes scheduling, node pressure, CPU/memory contention, storage latency, networking, and recent deployment changes affecting AI workloads.

Return evidence and likely causes.

After all responses return:

1. compare their evidence
2. identify overlapping signals
3. rank likely causes
4. distinguish facts from hypotheses
5. present a single consolidated diagnosis

## Delegation principles

### Keep tasks self-contained

Every delegated task must include enough context for the remote agent to work independently.

Include where relevant:

- namespace
- workload name
- affected service
- error message
- time window
- expected behavior
- observed behavior
- known recent changes

### Delegate goals, not conversations

Do not send an entire conversation unless necessary.

Instead summarize the relevant context.

Good:

Investigate why deployment `open-webui` in namespace `ai` has been restarting since approximately 14:00.

Bad:

Read this entire chat and figure out what is wrong.

### Ask for evidence

Always ask agents to provide evidence supporting conclusions.

Useful evidence includes:

- Kubernetes object state
- pod events
- logs
- metrics
- traces
- Hubble flows
- configuration differences
- timestamps

### Prefer read-only investigation first

For diagnostic tasks, instruct the agent not to mutate infrastructure unless the user explicitly requested a change.

Use:

"Do not make cluster changes. Return the proposed remediation first."

### Avoid delegation loops

Do not delegate to an agent simply because that agent may delegate back to the current agent.

If the same investigation begins bouncing between agents, stop and synthesize the available evidence.

### Avoid unnecessary fan-out

Do not invoke every agent for every problem.

Use multiple agents only when:

- the problem spans multiple domains
- independent evidence is useful
- parallel investigation materially improves the result

## Recommended output from delegated agents

When possible, ask agents to return:

1. Summary
2. Evidence
3. Root cause or leading hypothesis
4. Confidence
5. Recommended next action
6. Changes required, if any

Example:

Summary:
OpenWebUI cannot reach Qdrant because traffic is being denied by a CiliumNetworkPolicy.

Evidence:
- Service resolves correctly.
- Qdrant endpoints are healthy.
- Hubble shows policy-denied flows from OpenWebUI.
- Matching CiliumNetworkPolicy does not allow the OpenWebUI identity.

Confidence:
High

Recommended action:
Add an ingress rule permitting traffic from the OpenWebUI workload to Qdrant TCP port 6333.

## Safety

Treat delegated agents as privileged infrastructure actors.

Before requesting destructive or state-changing actions such as:

- deleting resources
- restarting nodes
- modifying network policy
- changing firewall rules
- rotating secrets
- modifying storage
- applying manifests

first obtain a diagnosis and proposed change.

Unless explicitly instructed otherwise, delegation should default to investigation and recommendation rather than mutation.
