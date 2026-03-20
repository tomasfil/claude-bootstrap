# Agent Reference

## Frontmatter Fields

Agent definitions use YAML frontmatter in Markdown files.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name for the agent |
| `description` | Yes | What the agent does (shown in agent selection) |
| `tools` | No | Comma-separated allowlist of tools the agent can use |
| `disallowedTools` | No | Comma-separated list of tools the agent cannot use |
| `model` | No | Model to use: `sonnet`, `opus`, `haiku`, or `inherit` |
| `memory` | No | Persistent memory scope: `user`, `project`, or `local` |
| `hooks` | No | Lifecycle-scoped hooks specific to this agent |
| `isolation` | No | Set to `"worktree"` to run in a temporary git worktree |
| `background` | No | Set to `true` to always run as a background task |
| `permissionMode` | No | One of: `default`, `acceptEdits`, `plan`, `bypassPermissions` |
| `maxTurns` | No | Maximum number of agentic turns before forced stop |
| `skills` | No | List of skills to preload when the agent starts |

## Placement and Precedence

- **Project agents**: `.claude/agents/` — shared with the team via version control
- **User agents**: `~/.claude/agents/` — personal, not shared

Project agents take precedence over user agents when names collide.

## Design Principles

1. **Own context window.** Each agent runs in its own context. The parent
   agent's context is not shared — the prompt is the only communication
   channel.

2. **Prompt is the only channel.** Everything the agent needs to know must
   be in its system prompt (frontmatter + body) or discoverable through
   its allowed tools.

3. **Parent gets final message.** When an agent completes, the parent
   receives only the agent's final response. Intermediate reasoning is
   not forwarded.

4. **No nesting.** Agents cannot spawn other agents. The architecture is
   flat: parent → agent, never parent → agent → agent.

5. **Scope tools aggressively.** Give each agent only the tools it needs.
   A reviewer agent does not need Write. A search agent does not need Bash.

## Good Candidates for Agents

- **Large output tasks** — Generating lengthy reports, documentation, or
  code that would consume the parent's context
- **Isolated analysis** — Code review, security audit, dependency analysis
  where the agent reads but does not modify
- **Repetitive multi-file operations** — Applying the same transformation
  across many files
- **Parallelizable work** — Multiple independent tasks that can run as
  background agents simultaneously

## Workflow Patterns

### Sequential
Agents with dependencies. Agent B needs Agent A's output. Run them in
order, passing results through the parent.

### Parallel
Independent agents that can run simultaneously. Use `background: true`
for each and collect results when all complete. Best for tasks like
"review these 5 modules" or "run these 3 analysis passes."

### Evaluator-Optimizer
Two agents in a refinement loop. One generates, the other evaluates.
The parent orchestrates iterations until quality criteria are met.
Useful for code generation with quality gates.
