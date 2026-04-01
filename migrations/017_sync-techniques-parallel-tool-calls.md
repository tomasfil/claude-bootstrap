# Migration: Sync Techniques — Parallel Tool Calls

> Fetch updated `techniques/prompt-engineering.md` and `techniques/agent-design.md` that were modified in 07be05a but not synced by migration 016.

---

```yaml
# --- Migration Metadata ---
id: "017"
name: "Sync Techniques — Parallel Tool Calls"
description: >
  Migration 016 audited prompt files for missing <use_parallel_tool_calls> but
  did not sync the updated technique files that document the patterns. This
  migration fetches the updated techniques so child projects have the reference
  material matching the rules they were asked to apply.
base_commit: "8693e80e872699759f2454af1cd031128e03eceb"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `techniques/prompt-engineering.md` | Sync: adds Batch Operations section with parallel tool call patterns |
| modify | `techniques/agent-design.md` | Sync: adds `<use_parallel_tool_calls>` block and compact form guidance |

---

## Actions

### Step 1 — Fetch updated techniques

Fetch both updated technique files from the bootstrap repo:

```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/prompt-engineering.md \
  --jq '.content' | base64 -d > techniques/prompt-engineering.md

gh api repos/tomasfil/claude-bootstrap/contents/techniques/agent-design.md \
  --jq '.content' | base64 -d > techniques/agent-design.md
```

If `techniques/` directory does not exist, create it first.

### Step 2 — Verify content

1. Confirm `techniques/prompt-engineering.md` contains a "Batch Operations" or "Parallel Tool Calls" section
2. Confirm `techniques/agent-design.md` contains `use_parallel_tool_calls`

### Step 3 — Wire + sync

1. Verify cross-references: every path mentioned in changed files exists
2. No changes to `claude-bootstrap.md` checklist (module list unchanged)
3. No changes to `settings.json` hooks

---

## Verify

```bash
# Both technique files must exist and contain the new content
grep -q "parallel_tool_calls\|Batch Operations\|Parallel Tool" techniques/prompt-engineering.md \
  && echo "OK: prompt-engineering" || echo "MISSING: prompt-engineering parallel section"

grep -q "use_parallel_tool_calls" techniques/agent-design.md \
  && echo "OK: agent-design" || echo "MISSING: agent-design parallel tag"
```

- [ ] `techniques/prompt-engineering.md` contains parallel tool call patterns
- [ ] `techniques/agent-design.md` contains `use_parallel_tool_calls` guidance
- [ ] No broken cross-references in technique files

---

Migration complete: `017` — Technique files synced for parallel tool calls patterns
