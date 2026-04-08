# Migration: plan-writer-direct-write

> Give plan-writer agent Write tool so it saves plans directly instead of returning content to main thread

---

```yaml
# --- Migration Metadata ---
id: "024"
name: "Plan Writer Direct Write"
description: >
  Add Write tool to plan-writer agent and update /write-plan skill to let agent
  save plans directly to .claude/specs/. Eliminates token waste from round-tripping
  full plan content through main thread.
base_commit: "ac2defd2e9f72913fb2c84948950ab05a3050dad"
date: "2026-04-08"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/agents/plan-writer.md` | Add Write to tools, update process to save file + return path only |
| modify | `.claude/skills/write-plan/SKILL.md` | Remove main-thread save step, agent writes directly |

---

## Actions

### Step 1 — Update plan-writer agent tools

Read `.claude/agents/plan-writer.md`. Skip if missing.

In the YAML frontmatter, change:
```
tools: Read, Grep, Glob, LSP
```
to:
```
tools: Read, Write, Grep, Glob, LSP
```

### Step 2 — Update plan-writer process

In the same file, find the Process section. Replace step 7 (or last step about returning):

Change any line like:
```
7. Return complete plan as markdown
```
to:
```
7. Save plan to `.claude/specs/{date}-{topic}-plan.md` (compressed telegraphic notation)
8. Return ONLY the saved file path — no plan content in response
```

### Step 3 — Update /write-plan skill

Read `.claude/skills/write-plan/SKILL.md`. Skip if missing.

Replace the agent dispatch and save steps. The new flow:

1. **Step 1: Read Spec (main thread)** — unchanged
2. **Step 2: Confirm Scope (main thread)** — unchanged
3. **Step 3: Dispatch plan-writer Agent** — update to:
   ```
   Dispatch `plan-writer` agent with: full spec content, pipeline traces (if found),
   project conventions from CLAUDE.md, existing file structure context.

   Agent writes plan directly to `.claude/specs/{date}-{topic}-plan.md` and returns the file path.

   > **Fallback:** If `plan-writer` agent doesn't exist, perform work on main thread.
   ```
4. **Step 4: Report (main thread)** — replace any "Present Plan" + "Save Plan" steps with:
   ```
   Read the saved plan file. Present summary: total tasks, dependency chain, dispatch batches, any ambiguities.
   ```

Remove any step that saves the plan from the main thread — the agent handles this now.

### Step 4 — Verify

1. Confirm `.claude/agents/plan-writer.md` frontmatter contains `Write` in tools
2. Confirm `.claude/skills/write-plan/SKILL.md` has no "Save Plan (main thread)" step
3. Confirm skill references agent writing directly

---

## Verify

- [ ] `.claude/agents/plan-writer.md` has `tools:` including `Write`
- [ ] Plan-writer process mentions saving to `.claude/specs/` and returning file path
- [ ] `/write-plan` skill dispatches agent for writing, no main-thread save step
- [ ] No broken cross-references

---

Migration complete: `024` — plan-writer writes plans directly, returns file path only
