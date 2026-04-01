# Migration: Parallel Tool Calls Prompt Audit

> Audit all prompt files (agents, skills, cron/CI prompts) for missing `<use_parallel_tool_calls>` and add where needed.

---

```yaml
# --- Migration Metadata ---
id: "016"
name: "Parallel Tool Calls Prompt Audit"
description: >
  Extends migration 005 (which only targeted .claude/agents/) to cover ALL
  multi-tool prompt files: orchestrator skills, CI prompts, cron prompts.
  Adds compact or full-block form based on prompt complexity.
base_commit: "1fd744142f4054e0069e683ce7fe395703a87223"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/*.md` | Re-audit: add full block if missing (idempotent) |
| modify | `.claude/skills/*/SKILL.md` | Add compact form to orchestrator skills if missing |
| modify | `cron/**/*.md`, `prompts/**/*.md`, `pipelines/**/*.md` | Add compact form to multi-tool prompts if missing |

---

## Actions

### Step 1 — Re-audit agents

For each `.claude/agents/*.md`:
1. Read file
2. If file already contains `use_parallel_tool_calls` → skip
3. If file lists 2+ tools in frontmatter `tools:` field → add full block form:

```markdown
<use_parallel_tool_calls>
Invoke all independent tool calls simultaneously, not sequentially.
- Multiple Reads → batch in one message
- Multiple Greps → batch in one message
- Multiple WebSearches → batch in one message
- Read-only tools (Glob, Grep, Read) → ALWAYS parallel
NEVER: Read A → respond → Read B → respond. INSTEAD: Read A + B → respond.
</use_parallel_tool_calls>
```

Insert before `## Constraints`, `<constraints>`, or `## Scope Lock` — whichever appears first. If none found, append before last section.

### Step 2 — Audit orchestrator skills

For each `.claude/skills/*/SKILL.md`:
1. Read file
2. If file already contains `use_parallel_tool_calls` → skip
3. Check if skill is multi-tool: `context: fork` in frontmatter OR body contains `Agent(` or `Agent tool` references
4. Note: `context: fork` is currently broken (claude-code#16803) — skills run inline regardless. Tag still matters for when bug is fixed.
5. If multi-tool → add compact form after the closing `---` of YAML frontmatter:

```markdown
<use_parallel_tool_calls>true</use_parallel_tool_calls>
Batch all independent tool calls into one message.
```

### Step 3 — Audit non-standard prompt directories

Glob for: `cron/**/*.md`, `prompts/**/*.md`, `pipelines/**/*.md`, `**/*-prompt.md`

**Guard:** If directory does not exist, skip silently. These patterns are project-specific and may not exist.

For each file found:
1. Read file
2. If file already contains `use_parallel_tool_calls` → skip
3. If file contains tool-use instructions (references to WebSearch, Read, Grep, Bash, or similar tool names; OR contains multi-step procedures with tool calls) → add compact form at the top of the operational section (after any metadata/frontmatter):

```markdown
<use_parallel_tool_calls>true</use_parallel_tool_calls>
Batch all independent tool calls into one message.
```

### Step 4 — Wire + sync

1. Verify cross-references: every path mentioned in changed files exists
2. No changes to `claude-bootstrap.md` checklist (module list unchanged)
3. No changes to `settings.json` hooks

---

## Verify

```bash
# No tool-using agents should lack the tag
for agent in .claude/agents/*.md; do
  if grep -q "^tools:" "$agent" 2>/dev/null; then
    grep -qL "use_parallel_tool_calls" "$agent" && echo "MISSING: $agent"
  fi
done

# Orchestrator skills should have the tag
for skill in .claude/skills/*/SKILL.md; do
  if grep -q "context: fork" "$skill" 2>/dev/null || grep -q "Agent(" "$skill" 2>/dev/null; then
    grep -q "use_parallel_tool_calls" "$skill" || echo "MISSING: $skill"
  fi
done

# Non-standard prompt dirs (informational — may be empty)
for dir in cron prompts pipelines; do
  if [[ -d "$dir" ]]; then
    echo "Checking $dir/..."
    grep -rL "use_parallel_tool_calls" "$dir"/**/*.md 2>/dev/null | head -5
  fi
done
```

- [ ] All tool-using agents contain `use_parallel_tool_calls`
- [ ] All orchestrator skills contain `use_parallel_tool_calls`
- [ ] Non-standard prompt dirs audited (if they exist)
- [ ] No broken cross-references in changed files

---

Migration complete: `016` — Parallel tool calls audit extended to all prompt types
