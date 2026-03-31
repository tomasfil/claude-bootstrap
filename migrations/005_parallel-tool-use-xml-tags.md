# Migration: Parallel Tool Use XML Tags

> Upgrade agent parallel execution blocks from plain markdown to Anthropic-recommended `<use_parallel_tool_calls>` XML tags + add read-only tool emphasis.

---

```yaml
id: "005"
name: parallel-tool-use-xml-tags
description: >
  Replaces plain "## Parallel Execution" blocks in agents with XML-tagged
  <use_parallel_tool_calls> pattern (Anthropic-recommended). Adds read-only
  tool emphasis and bias-toward-parallel wording for stronger compliance.
base_commit: "7644869716a8b8dc4fabb378bdbb4a41a01900c9"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/*.md` | Replace `## Parallel Execution` with `<use_parallel_tool_calls>` XML block |

---

## Actions

### Step 1 — Replace parallel execution blocks in all agents

For each agent file in `.claude/agents/` that contains `## Parallel Execution`, replace the entire block:

**Find this pattern:**
```markdown
## Parallel Execution
When multiple tool calls have no data dependencies → issue ALL in one message.
- Multiple Reads → batch
- Multiple Greps → batch
- Multiple WebSearches → batch
NEVER: Read A → respond → Read B → respond. INSTEAD: Read A + B → respond once.
```

**Replace with:**
```markdown
<use_parallel_tool_calls>
For maximum efficiency, invoke all independent tool calls simultaneously
rather than sequentially. Err on the side of maximizing parallel calls.
- Multiple Reads → batch in one message
- Multiple Greps → batch in one message
- Multiple WebSearches → batch in one message
- Read-only tools (Glob, Grep, Read) → ALWAYS parallel
NEVER: Read A → respond → Read B → respond. INSTEAD: Read A + B → respond.
</use_parallel_tool_calls>
```

Rules:
- Read each agent file before editing
- Only replace the exact `## Parallel Execution` block — leave Scope Lock, Self-Fix Protocol, Search Planning blocks untouched
- If an agent does not have the old block, skip it
- If an agent already has `<use_parallel_tool_calls>`, skip it

---

## Verify

```bash
# All agents with old pattern should be zero
grep -rl "## Parallel Execution" .claude/agents/*.md | wc -l  # expect: 0

# Agents with new pattern should match count of tool-using agents
grep -rl "use_parallel_tool_calls" .claude/agents/*.md | wc -l  # expect: >= 6
```

---

Migration complete: `005` — XML-tagged parallel tool use blocks in all agents
