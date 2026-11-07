---
name: github-repo-explore
description: Guide for searching and exploring external GitHub repositories using the gh CLI. Use this when you need reference implementations, patterns, or code examples from open-source projects to help complete your task.
---

# GitHub Repository Search and Exploration

This skill enables agents to discover, clone, and explore external GitHub repositories when implementing features that may benefit from reference implementations in open-source projects using github mcp tools.

## When to Use This Skill

Use this skill when you need to:
- Find reference implementations for features you're building
- Explore how other projects implement similar patterns
- Search for code examples across GitHub
- Clone external repos for local exploration and learning
- Find libraries or tools that could inform your implementation

**Do NOT use this skill when**:
- The task is straightforward and doesn't need external references
- The codebase already has established patterns to follow
- You're working on proprietary code that shouldn't reference external sources

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Search GitHub for Repositories                              │
│     └─ search_repositories <query>                              │
│     └─ search_code <query>                                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ Found match
                             ▼
┌───────────────────────────────────────────────────────────────────┐
│  2. Read Code                                                     │
│       └─ get_file_contents                                        │
└────────────────────────────┬──────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Show Results                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Search GitHub

Use `github-mcp` tools to find relevant repositories or code.

### Search for Repositories

use `search_repositories` mcp tool

### Search for Code

use `search_code` mcp tool

`search_code <query>`

**Example**

`search_code apiVersion: api.kagent.dev/v1alpha3 language:YAML`
---

## Phase 2: Read Code

When you find a useful repository, clone it to the cache directory.

### Clone Commands

use `get_file_contents` mcp tool

---

## Phase 3: Report Findings
