# Frontmatter Field Reference

## Skill Fields (13)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Display name and `/slash-command` identifier |
| `description` | string | Recommended | Trigger description — "Use when..." |
| `argument-hint` | string | No | Autocomplete hint (e.g., `[filename]`) |
| `disable-model-invocation` | boolean | No | Prevent auto-invocation |
| `user-invocable` | boolean | No | Set `false` to hide from `/` menu |
| `allowed-tools` | string | No | Tools allowed without permission prompts |
| `model` | string | No | Model override: `haiku`, `sonnet`, `opus` |
| `effort` | string | No | Effort level: `low`, `medium`, `high`, `max` |
| `context` | string | No | `fork` runs in isolated subagent |
| `agent` | string | No | Subagent type when `context: fork` |
| `hooks` | object | No | Lifecycle hooks scoped to this skill |
| `paths` | string/list | No | Glob patterns for auto-activation |
| `shell` | string | No | `bash` (default) or `powershell` |

## Agent Fields (16)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Unique identifier, lowercase-hyphens |
| `description` | string | Yes | When to invoke. `"PROACTIVELY"` for auto-invocation |
| `tools` | string/list | No | Tool allowlist. Inherits all if omitted |
| `disallowedTools` | string/list | No | Tools to deny |
| `model` | string | No | `haiku`, `sonnet`, `opus`, `inherit` |
| `permissionMode` | string | No | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | integer | No | Max agentic turns |
| `skills` | list | No | Skills preloaded into agent context at startup |
| `mcpServers` | list | No | MCP servers for this subagent |
| `hooks` | object | No | Lifecycle hooks scoped to this subagent |
| `memory` | string | No | `user`, `project`, or `local` |
| `background` | boolean | No | Always run as background task |
| `effort` | string | No | `low`, `medium`, `high`, `max` |
| `isolation` | string | No | `worktree` for isolated git copy |
| `initialPrompt` | string | No | Auto-submitted first user turn |
| `color` | string | No | CLI output color (e.g., `green`, `magenta`) |

## Key Patterns

### context: fork (skills)
Runs skill in isolated subagent — main context only sees final result.
Use for orchestrator skills that dispatch agents and produce intermediate output.

### skills preloading (agents)
`skills: [write-prompt]` injects full SKILL.md content into agent context at startup.
Agent uses it as domain knowledge, doesn't invoke it dynamically.

### paths (skills)
`paths: "src/**/*.ts"` auto-activates skill when working with matching files.
Complementary to routing hooks — paths is automatic, hooks catch natural language.
