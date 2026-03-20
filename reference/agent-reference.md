# Agent Reference

## Frontmatter Fields

Agent files are Markdown with YAML frontmatter. Place them in `.claude/agents/` (project-scoped) or `~/.claude/agents/` (user-scoped). Project agents take precedence over user agents with the same name.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Agent identifier. Used to invoke the agent. |
| `description` | Yes | What the agent does. Shown in agent selection. |
| `tools` | No | Comma-separated allowlist of tools the agent can use. |
| `disallowedTools` | No | Comma-separated list of tools the agent cannot use. |
| `model` | No | Model to use: `sonnet`, `opus`, `haiku`, or `inherit` (use parent's model). |
| `memory` | No | Persistent memory scope: `user`, `project`, or `local`. |
| `hooks` | No | Lifecycle-scoped hooks specific to this agent. |
| `isolation` | No | Set to `"worktree"` to run in a temporary git worktree. |
| `background` | No | Set to `true` to always run as a background task. |
| `permissionMode` | No | One of: `default`, `acceptEdits`, `plan`, `bypassPermissions`. |
| `maxTurns` | No | Maximum number of agentic turns before stopping. |
| `skills` | No | List of skills to preload when the agent starts. |

## Design Principles

1. **Own context window.** Each agent runs in a separate context window. It does not share the parent's context.
2. **Prompt is the only channel.** The agent's Markdown body is its entire instruction set. Everything it needs to know must be in the prompt or discoverable via tools.
3. **Parent gets final message.** When the agent finishes, only its final message is returned to the parent. Intermediate reasoning is not visible.
4. **No nesting.** Agents cannot spawn other agents. The architecture is flat: parent → agent, never parent → agent → agent.
5. **Scope tools tightly.** Give agents only the tools they need. A review agent does not need Write. An analysis agent does not need Bash.

## Good Candidates for Agents

- **Large output tasks** — generating reports, documentation, or analysis that would flood the parent's context
- **Isolated analysis** — code review, security audit, dependency analysis where the agent needs to read many files but only report findings
- **Repetitive multi-file operations** — applying the same transformation across many files
- **Parallelizable work** — independent tasks that can run simultaneously as background agents

## Workflow Patterns

### Sequential
Agent A completes, its output feeds into Agent B. Use when tasks have dependencies.
```
Parent → Agent A → Parent → Agent B → Parent
```

### Parallel
Multiple agents run simultaneously on independent tasks. Use `background: true`.
```
Parent → Agent A (background)
       → Agent B (background)
       → Agent C (background)
       → Collect results
```

### Evaluator-Optimizer
One agent generates, another evaluates, iterate until quality bar is met.
```
Parent → Generator Agent → Parent → Evaluator Agent → Parent → (repeat if needed)
```

## Placement and Precedence

- `.claude/agents/` — project-scoped, committed to repo, shared with team
- `~/.claude/agents/` — user-scoped, personal, available in all projects

When both locations contain an agent with the same name, the project-scoped agent takes precedence.
