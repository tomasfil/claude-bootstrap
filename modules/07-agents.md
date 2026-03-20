# Step 10 — Create .claude/agents/

> Mode C: read existing agents, only create missing ones, run collision check.

## Key Design Principles

Subagents are **isolated tool-use sessions**:

1. **Own context window** — parent conversation does NOT carry over
2. **Only channel is the prompt string** — include ALL necessary context in the prompt
3. **Parent receives final message** as a tool result (not intermediate steps)
4. **Cannot spawn other subagents** — single level of nesting only
5. **Scope tools per agent** — give each agent only the tools it needs

## Pre-flight: Agent Name Collision Check

Plugins may register agent names. Check for collisions before creating:

```bash
#!/usr/bin/env bash
# Check for plugin-registered agent names
AGENTS_DIR=".claude/agents"
COLLISIONS=()
for f in "$AGENTS_DIR"/*.md; do
  [ -f "$f" ] || continue
  name=$(grep -m1 '^name:' "$f" | sed 's/name:[[:space:]]*//')
  # Check if plugin already claims this name
  if claude --print-agents 2>/dev/null | grep -qw "$name"; then
    COLLISIONS+=("$name")
  fi
done
if [ ${#COLLISIONS[@]} -gt 0 ]; then
  echo "COLLISION: ${COLLISIONS[*]}"
  echo "Prefix these with 'project-' to avoid conflicts."
fi
```

### Known collisions to watch

The **superpowers** plugin registers `code-reviewer` and `code-simplifier`. If installed, prefix yours with `project-` (e.g., `project-code-reviewer`).

## Supported Frontmatter Fields

Every agent `.md` file supports this YAML frontmatter:

```yaml
name: agent-name          # required
description: "..."        # required — when to invoke
tools: Read, Grep, Glob   # optional — omit to inherit all
model: sonnet              # optional — sonnet/opus/haiku/inherit
memory: project            # optional — user/project/local for persistent memory
isolation: worktree        # optional — runs in temporary git worktree
background: true           # optional — always run as background task
permissionMode: acceptEdits # optional — default/acceptEdits/plan/bypassPermissions
maxTurns: 20               # optional — max agentic turns
skills: reflect, audit-file # optional — skills to preload
```

## Always Create: code-reviewer.md

**Spec**: Senior code reviewer agent.

- Reads `code-standards.md` rule for project conventions
- Checklist: standards compliance, security concerns, edge cases, dead code / cleanup opportunities
- Output format per finding: severity (critical/warning/nit) | file:line | issue | suggested fix
- Ends with overall assessment: approve, request changes, or needs discussion
- Tools: `Read`, `Grep`, `Glob` (read-only — no edits)
- Model: `sonnet` (fast, thorough enough for review)

## Conditional: test-writer.md

Create if project has a test framework detected.

**Spec**: Testing specialist agent.

- Reads existing tests to match style and patterns
- Coverage targets: happy path, edge cases, error handling, integration boundaries
- Runs tests after writing to confirm they pass
- Tools: `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash`

## Conditional: researcher.md

Create if codebase is large (>50 files) or complex.

**Spec**: Codebase researcher agent.

- Searches, reads, and traces code paths across the project
- Returns structured summary: relevant files, call chains, data flow, key findings
- Tools: `Read`, `Grep`, `Glob` (read-only)
- Model: `sonnet`

**Checkpoint**: `.claude/agents/` exists. `code-reviewer.md` present. Conditional agents created or skipped with reason. No name collisions (or collisions resolved with `project-` prefix).
