# kagent Documentation

> **Source:** https://kagent.dev/docs/kagent/

Your complete guide to the AI agent platform for Kubernetes.

## What is kagent?

Kagent is an open-source programming framework that brings the power of agentic AI to cloud-native environments. Built specifically for DevOps and platform engineers, Kagent enables AI agents to run directly in Kubernetes clusters to automate operations, troubleshoot issues, and solve complex cloud-native challenges.

Kagent was created at [Solo.io](https://www.solo.io) in 2025 and is a [Cloud Native Computing Foundation](https://www.cncf.io) sandbox project.

Unlike traditional chatbots, kagent leverages advanced reasoning and iterative planning capabilities to autonomously handle multi-step problems in cloud-native environments. It transforms AI insights into concrete actions, helping teams tackle common operational challenges like:

- Diagnosing connectivity issues across multiple service hops
- Troubleshooting application performance degradation
- Automating alert generation from Prometheus metrics
- Debugging Gateway and HTTPRoute configurations
- Managing progressive rollouts with Argo Rollouts

### Key Features

- **AI-Powered Automation** - Create intelligent agents that understand natural language and can perform complex Kubernetes operations
- **Multi-Provider Support** - Works with OpenAI, Anthropic, Google Vertex AI, Azure OpenAI, Ollama, and custom models
- **Tool Integration** - Supports Model Context Protocol (MCP) tools, built-in Kubernetes tools, and custom HTTP tools
- **Agent-to-Agent Communication** - Enable sophisticated workflows through A2A (Agent-to-Agent) interactions
- **Comprehensive Observability** - Built-in tracing and monitoring to understand agent behavior and performance
- **Cloud Native** - Designed from the ground up to run natively in Kubernetes environments

## Core Components

Kagent's architecture consists of three main components:

- **Tools**: Any MCP-style function that agents can leverage to interact with cloud-native systems. Kagent comes with pre-built tools that include capabilities like displaying pod logs, querying Prometheus metrics, generating resources and more. You can check the available tools in the tool registry.

- **Agents**: Autonomous systems that plan, execute, and analyze tasks using the available tools. These agents can chain multiple operations together to solve complex problems. Each agent can have access to one or more tools to accomplish its work. Agents can also be grouped into teams where a planning agent comes up with a plan and assigns tasks to individual agents in the team.

- **Framework**: A flexible interface that allows running agents either through a UI or declaratively. Built on Google's ADK framework, it provides extensive customization options.

## Architecture

Kagent consists of multiple components running inside and outside of Kubernetes cluster.

### Controller

The kagent controller is a Kubernetes controller, written in Go, that knows how to handle custom CRDs for creating and managing AI agents in the cluster.

### App/Engine

The kagent engine is the core component of kagent. It is a Python application that is responsible for running the agent's conversation loop. It is built on top of the [ADK](https://google.github.io/adk-docs/) framework.

The ADK team did a wonderful job of creating a flexible, powerful, and most importantly extensible framework for building AI agents. Kagent takes full advantage of this by using the framework and adding its own `Agents` and `Tools`.

Relevant ADK documentation:

- [Agents](https://google.github.io/adk-docs/agents/)
- [Tools](https://google.github.io/adk-docs/tools/)
- [Context](https://google.github.io/adk-docs/context/)

### CLI

Kagent CLI is one of the entry points to kagent. The CLI connects to the engine and allows you to manage resources and interact with agents.

### Dashboard (UI)

Kagent dashboard provides a web interface for managing and working with AI agents.

```shell
kagent dashboard
```

Or via kubectl port-forward:

```shell
kubectl -n kagent port-forward svc/kagent 8001:80
```

Then open your browser to [http://localhost:8001](http://localhost:8001).

## Documentation Links

### Getting Started
- [Installing kagent](https://kagent.dev/docs/kagent/introduction/installation)
- [Quick Start](https://kagent.dev/docs/kagent/getting-started/quickstart)
- [First Agent Guide](https://kagent.dev/docs/kagent/getting-started/first-agent)
- [First MCP Tool](https://kagent.dev/docs/kagent/getting-started/first-mcp-tool)

### Concepts
- [What is kagent](https://kagent.dev/docs/kagent/introduction/what-is-kagent)
- [Architecture](https://kagent.dev/docs/kagent/concepts/architecture)
- [Core Concepts](https://kagent.dev/docs/kagent/concepts)
- [Configuring LLM Providers](https://kagent.dev/docs/kagent/supported-providers)

### Examples
- [Tools](https://kagent.dev/tools)
- [Agents](https://kagent.dev/agents)
- [A2A Agents](https://kagent.dev/docs/kagent/examples/a2a-agents)
- [Documentation Agent](https://kagent.dev/docs/kagent/examples/documentation)
- [Slack and A2A](https://kagent.dev/docs/kagent/examples/slack-a2a)
- [Discord and A2A](https://kagent.dev/docs/kagent/examples/discord-a2a)

### Community
- [GitHub](https://github.com/kagent-dev/kagent)
- [Discord](https://discord.gg/Fu3k65f2k3)
- [Contributing](https://github.com/kagent-dev/kagent/blob/main/CONTRIBUTING.md)
- [FAQ](https://kagent.dev/docs/kagent/resources/faq)
- [Roadmap](https://github.com/orgs/kagent-dev/projects/3)
