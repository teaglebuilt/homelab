# About tools

An AgentTemplate's `spec.tools` list defines what an agent can do beyond its system prompt. Each entry is a **tool binding**, and each binding connects the agent to one source.

- `mcp`: Tools from a Model Context Protocol (MCP) server.
- `subAgent`: Another AgentTemplate that takes work from the agent that you are configuring.

You must set exactly one of these fields on a binding. If you set both or neither fields, the API server rejects the AgentTemplate with the error `exactly one of the fields in [mcp subAgent] must be set`.

Both kinds resolve within the AgentTemplate's own namespace, so a binding cannot reach a server or a template in another namespace.

## MCP tools

An `mcp` binding references an MCP server in the AgentTemplate's namespace. The optional `tools` list limits which of that server's tools the agent gets. On the kagent and Codex harnesses, a list narrows the binding to the tools that you name. To give the agent every tool that the server offers, omit the list or leave it empty.

```yaml
tools:
  - mcp:
      server:
        kind: RemoteMCPServer
        name: my-mcp-server
      tools:
        - search_docs
        - fetch_page
      requireApproval: true
```

| Field | Description |
| --- | --- |
| `mcp.server.kind` | The kind of server resource. `RemoteMCPServer` is the only accepted value. |
| `mcp.server.name` | The server's name, in the AgentTemplate's namespace. |
| `mcp.tools` | Optional. The names of the tools to bind, up to 50. Duplicates are collapsed. Omit the list, or leave it empty, to expose every tool on the server. On the Claude Harness, a list does not narrow the server. See [Tool selection on the Claude harness](#tool-selection-on-the-claude-harness). |
| `mcp.requireApproval` | Optional. Pauses the agent for a person's approval before each call to a tool that this binding exposes. On the Claude harness, the pause covers every tool on the server, because Claude approves one server at a time rather than one tool at a time. Omit to run the bound tools without approval. For more information, see [Human in the loop](https://kagent.dev/docs/kagent/1.x/agents/human-in-the-loop#require-approval-for-a-tool). |

### Tool selection on the Claude harness

Claude's MCP configuration has no per-tool allowlist. On the Claude harness, the `tools` list does not narrow a server, and the agent reaches every tool that the server serves. kagent admits the revision either way. Unless the list exactly matches the tools that kagent currently discovers on the server, kagent also records a warning on the Agent.

```sh
kubectl get agent <name> -n <namespace> -o jsonpath='{.status.warnings}'
```

To keep an agent on the Claude harness away from a tool, limit what the server exposes rather than what the binding selects. Give the agent its own RemoteMCPServer that serves only the tools that you intend. Where you do not control what the server serves, put the MCP server behind agentgateway and apply [tool access](https://agentgateway.dev/docs/kubernetes/latest/documentation/mcp/tool-access/) rules to the route. Those rules filter a disallowed tool out of the `tools/list` response, so the agent never sees it. Then point the RemoteMCPServer at that route. To put more than one MCP server behind one route, see [Virtual MCP](https://agentgateway.dev/docs/kubernetes/latest/documentation/mcp/virtual/).

For the bundled tool server, see the installation-level settings that drop providers and write tools in [Tools ecosystem](https://kagent.dev/docs/kagent/1.x/reference/tools-ecosystem#narrow-what-kagent-tool-server-serves).

## Subagents as tools

A `subAgent` binding points at another AgentTemplate in the same namespace so that one agent can route work to another agent. The model reads the `description` when it decides whether to route work here. A description that states plainly what the bound agent is for therefore matters more than the detail of its configuration.

```yaml
tools:
  - subAgent:
      name: log-searcher
      description: Search application logs for a time range and a query string.
      templateRef:
        name: log-search-agent
```

Every field is required. For the complete schema, see the [API reference](https://kagent.dev/docs/kagent/1.x/reference/api-ref#subagenttoolbinding).

| Field | Description |
| --- | --- |
| `subAgent.name` | The name that the model sees for this binding. |
| `subAgent.description` | The text that tells the parent agent when to route work here. |
| `subAgent.templateRef.name` | The AgentTemplate to bind, in the same namespace. |

kagent compiles the bound template into the parent agent's own configuration and runs it inside the parent's Actor, so the two agents share one sandbox. A bound template is not an MCP server and has no endpoint of its own. A bound template also does not need an Agent resource because the parent's Agent runs it.

> [!NOTE]
> Dedicated subagents, which would give a bound agent its own Harness, Session, and Actor, are not part of the served API. The `subAgent.agentRef` field that would select one is unavailable, so `templateRef` is the only binding that you can write today.

### Subagent tree rules

A bound agent runs inside its parent, so kagent constrains the shape of the resulting tree. kagent rejects a violation while it compiles the Agent, before any revision exists.

- **One level of nesting.** A bound agent cannot bind another agent.
- **No cycles.** An AgentTemplate cannot reach itself through a chain of bindings.
- **No reuse within one tree.** The same AgentTemplate cannot appear twice in the same tree.
- **Unique binding names.** Two bindings on one AgentTemplate cannot share a `name`.

When kagent rejects a tree, the Agent's `Compatible` condition becomes `False`. The condition reports the reason `UnsupportedConfiguration`, and its message identifies the rule that failed. A binding that names an AgentTemplate that does not exist fails before any rule is checked, so the Agent's `ResolvedRefs` condition reports `ReferenceResolutionFailed` instead. Read the conditions in the output of the following command.

```sh
kubectl get agent <name> -n <namespace> \
  -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" "}{.reason}{": "}{.message}{"\n"}{end}'
```

The Claude and Codex harnesses apply further restrictions by not allowing a bound agent to have tools, skills, or plugins of its own. The bound agent must also use the same model provider and authentication as its parent. A tree that compiles on the kagent harness can therefore fail after you move it to a Harness that runs Claude or Codex.

## Plugins

A **plugin** is a bundle that an AgentTemplate attaches with `spec.plugins`. A plugin contains skills and can also declare Model Context Protocol (MCP) servers. Plugins follow the [Agent Plugins](https://agent-plugins.org) 1.0.0 specification. To attach a skill that is published on its own, see [Skills](https://kagent.dev/docs/kagent/1.x/skills-and-mcp/skills#attach-skills-to-an-agenttemplate).

## Plugin contents

A plugin root contains a manifest, and optionally the skills and the MCP servers that the plugin contributes.

- `plugin.json` (required): The manifest that gives the plugin its name.
- `skills/`: One subdirectory per skill, each with a `SKILL.md` file at its root.
- `mcp.json`: Declares MCP servers that kagent adds to the agent's [tools](https://kagent.dev/docs/kagent/1.x/skills-and-mcp/about-tools/).

kagent reads `name` from the manifest and ignores the rest. A manifest that sets `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, or `extensions` is accepted, but none of those fields change what the agent gets.

The name must be at most 64 characters. It must start and end with a lowercase letter or a digit, and the characters between can be lowercase letters, digits, dots, and hyphens. A name that contains `--` or `..` is rejected.

The manifest's `$schema` must be exactly `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`. kagent compares that value literally. kagent does not fetch the schema, and it does not check the manifest against the schema.

## Attach a plugin to an AgentTemplate

Use `spec.plugins` to attach a plugin and list the skills that the agent needs from it.

```yaml
apiVersion: api.kagent.dev/v1alpha3
kind: AgentTemplate
metadata:
  name: incident-responder
  namespace: kagent
spec:
  modelConfig:
    name: default-model-config
  systemPrompt: You help engineers work through production incidents.
  plugins:
    - source:
        git:
          url: https://github.com/example/agent-plugins
          commit: <full-commit-id>
        path: bundles/observability
      skills:
        - log-search
        - runbook-lookup
```

| Field | Description |
| --- | --- |
| `plugins[].source` | The location to fetch the plugin from. The source root must contain a `plugin.json` manifest. |
| `plugins[].skills` | The names of the skills inside that plugin to enable, up to 50. Omit the list, or leave it empty, to enable none of them. |
| `source.path` | The directory to select inside the artifact, when the content is not at its root. The path must be relative, and it cannot climb out of the artifact with `..` segments. |

One AgentTemplate accepts up to 20 plugins.

### Skill allowlist

List the name of each skill that you want in `plugins[].skills`. A skill's name is the name of its subdirectory under `skills/` in the plugin.

Attaching a plugin does not enable the skills that it contains, and an empty list does not enable any of them. kagent accepts an empty list rather than reporting an error, and the agent starts with no skills from that plugin. An explicit list also means that a later version of the plugin cannot add skills to your agent. To enable a new skill, add its name.

Plugin names must be unique. If two entries in `plugins` declare the same name in their manifests, the agent fails to start. Skill names come from your AgentTemplate, so kagent checks them before it fetches anything. A plugin name comes from the plugin's own manifest, and kagent can only check that name as each plugin is fetched.

## Claude-format plugins

kagent reads `plugin.json` at the plugin root. A plugin that instead keeps its manifest at `.claude-plugin/plugin.json` is a Claude-format plugin. kagent handles a Claude-format plugin differently on each Harness.

- On the Claude harness, kagent hands the whole plugin to the Claude CLI. The `plugins[].skills` allowlist does not apply, and the agent gets every skill in the plugin.
- On every other harness, the agent fails to start, with the error `plugin is Claude-format; only the Agent Plugins format (plugin.json at the plugin root) is supported here`.

kagent also does not check the `$schema` value in a Claude-format manifest.

## MCP servers

A plugin that includes `mcp.json` contributes MCP servers alongside any bound directly on the AgentTemplate. Only the kagent harness reads `mcp.json`. On every other harness, an agent gets only the servers that its AgentTemplate binds. The file has an `mcpServers` object, keyed by server name, and its `$schema` must be exactly `https://agent-plugins.org/schemas/1.0.0/mcp.schema.json`.

Each server specifies a transport in its `type` field, and the transport determines which other fields are allowed.

| Transport | Fields | Description |
| --- | --- | --- |
| `stdio` | `command`, `args`, `env`, `cwd` | Runs a process in the agent's sandbox. Specifying `url` or `headers` is rejected. |
| `streamable-http` | `url`, `headers` | Calls a remote server. Specifying `command`, `args`, `env`, or `cwd` is rejected. |
| `sse` | `url`, `headers` | Calls a remote server over Server-Sent Events. Accepts the same fields as `streamable-http`. |

The path rules on a `stdio` server keep a plugin self-contained. A plugin can run only what it ships or what the agent's image already provides, and it can write only to its own data directory.

- A `stdio` command must be a bare name on the agent's `PATH`, or a path that begins with `./` and resolves inside the plugin directory. A command that uses a path separator any other way or that contains whitespace is rejected.
- A `cwd` must begin with `./`, `${PLUGIN_ROOT}`, or `${PLUGIN_DATA}`, and it must resolve inside the plugin directory or that plugin's data directory. Omit `cwd` to run the command in the plugin directory. If a `cwd` under `${PLUGIN_DATA}` does not exist yet, kagent creates it.
- A remote `url` must be `http` or `https`, and it must not carry user information or fragments. Any host other than a loopback address must use HTTPS.
- Unrecognized fields are rejected rather than ignored.

If one server in the file is invalid, kagent logs the problem and skips that server, but the rest of the file is still loaded. A whole `mcp.json` contributes nothing when it fails to parse, declares an unexpected `$schema`, or omits `mcpServers`.

### Referring to plugin files

A `stdio` server often needs to run something that the plugin ships, or to write somewhere durable. kagent expands two variables in `args`, in `env` values, and in `cwd`.

- `${PLUGIN_ROOT}`: The directory that the plugin was unpacked into. Treat it as read-only.
- `${PLUGIN_DATA}`: The data directory that kagent creates for that plugin. Use it for anything that the server writes.

kagent also sets `PLUGIN_ROOT` and `PLUGIN_DATA` as environment variables on every `stdio` server, so a server can read them without the plugin declaring them. A plugin cannot override either variable. An `env` block that sets one of them is rejected.

## Plugin limits

kagent measures a plugin after fetching it and before mounting anything. A plugin is rejected if it contains more than 10,000 filesystem entries or more than 100 MB of regular files. A `.git` directory is skipped and counts toward neither. A symlink that resolves outside the artifact root is also rejected.

## Every source is immutable

A skill or a plugin changes what an agent does, so kagent only accepts artifact references that cannot shift underneath a running agent. Each source specifies exactly one of three kinds of artifact, and every kind must be pinned in its own way.

- **`oci`** : An image reference pinned to a digest, in the form `<repository>@sha256:<digest>`. A tag alone is rejected, because a tag can be moved to different content later.
- **`git`** : A repository URL together with a full commit identifier. An abbreviated commit, a branch, or a tag is rejected.
- **`bucket.s3`** : An endpoint, bucket, and key, together with the `versionId` of that exact object version. A region is included where the service requires one for request signing.

If a source sets more than one kind, or none of them, the API server rejects the AgentTemplate with the error `exactly one of the fields in [oci git bucket] must be set`.

Publishing a new version means updating the AgentTemplate to reference the new digest, commit, or object version. The update produces a new revision. Agents that are already running keep the content that they started with.

## Skills

A **skill** packages a piece of know-how that an agent can pick up: a set of instructions, together with whatever scripts, command-line tools, or reference files those instructions depend on. You attach a skill to an AgentTemplate by specifying where it comes from, and kagent fetches it and places it where the agent can find it.

## About

A skill is a directory whose root holds a `SKILL.md` file. That file carries front matter naming the skill and describing what it is for, followed by the instructions themselves.

The description makes a skill usable. When an agent starts, it reads the front matter of every skill that is attached to it. The agent then offers those skills to the model as tools that the model can call. The model chooses a skill from its description in the same way that it chooses any other tool. A description that states plainly when to use the skill therefore matters more than the length of the instructions behind it.

A skill can be published on its own, or bundled with other skills in a plugin. For what a plugin contains and how to attach one, see [Plugins](https://kagent.dev/docs/kagent/1.x/skills-and-mcp/plugins/).

## Attach skills to an AgentTemplate

Use `spec.skills` to attach a standalone skill. Each entry gives the skill a name and an immutable source to fetch it from.

```yaml
apiVersion: api.kagent.dev/v1alpha3
kind: AgentTemplate
metadata:
  name: incident-responder
  namespace: kagent
spec:
  modelConfig:
    name: default-model-config
  systemPrompt: You help engineers work through production incidents.
  skills:
    - name: incident-triage
      source:
        oci: registry.example.com/skills/incident-triage@sha256:<digest>
```

| Field | Description |
| --- | --- |
| `skills[].name` | The name that the skill is mounted under, and the name that the model sees. |
| `skills[].source` | The location to fetch this one skill from. The source root must contain a `SKILL.md` file. |
| `source.path` | The directory to select inside the artifact, when the content is not at its root. The path must be relative, and it cannot climb out of the artifact with `..` segments. |

One AgentTemplate accepts up to 50 standalone skills. To give an agent the skills that a plugin contains, [use `spec.plugins` instead](https://kagent.dev/docs/kagent/1.x/skills-and-mcp/plugins#attach-a-plugin-to-an-agenttemplate). An AgentTemplate can use both fields at once.

## Every source is immutable

A skill or a plugin changes what an agent does, so kagent only accepts artifact references that cannot shift underneath a running agent. Each source specifies exactly one of three kinds of artifact, and every kind must be pinned in its own way.

- **`oci`** : An image reference pinned to a digest, in the form `<repository>@sha256:<digest>`. A tag alone is rejected, because a tag can be moved to different content later.
- **`git`** : A repository URL together with a full commit identifier. An abbreviated commit, a branch, or a tag is rejected.
- **`bucket.s3`** : An endpoint, bucket, and key, together with the `versionId` of that exact object version. A region is included where the service requires one for request signing.

If a source sets more than one kind, or none of them, the API server rejects the AgentTemplate with the error `exactly one of the fields in [oci git bucket] must be set`.

Publishing a new version means updating the AgentTemplate to reference the new digest, commit, or object version. The update produces a new revision. Agents that are already running keep the content that they started with.

## Naming rules

kagent checks skill names before it fetches anything. These rules apply to every skill on an AgentTemplate, whether the skill is standalone or comes from a plugin.

- A name must be a single path component. A name containing a slash, or a name of `.` or `..`, is rejected.
- Names must be unique across the whole AgentTemplate. Because standalone skills and plugin skills are mounted into the same place, a standalone skill cannot reuse the name of an enabled plugin skill, and two plugins cannot both contribute the same name.
