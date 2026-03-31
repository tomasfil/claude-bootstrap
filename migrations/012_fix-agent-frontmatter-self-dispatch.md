# Migration: Fix Agent Frontmatter Self-Dispatch Bug

> Reverts migration 011 Pattern A changes — `agent:` must be `general-purpose` when skill body dispatches the specialist via Agent tool. Setting `agent:` to the specialist makes the fork become that agent, then "dispatch X" = self-dispatch → empty output.

---

```yaml
# --- Migration Metadata ---
id: "012"
name: "Fix Agent Frontmatter Self-Dispatch Bug"
description: >
  Migration 011 incorrectly set agent: to specialist names (reflector,
  project-code-reviewer) for skills whose body dispatches those agents.
  The agent: field sets the fork's IDENTITY, not its dispatch target.
  This fix reverts to agent: general-purpose so the fork can dispatch.
base_commit: "5782311"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/skills/review/SKILL.md` | `agent: project-code-reviewer` → `agent: general-purpose` |
| modify | `.claude/skills/reflect/SKILL.md` | `agent: reflector` → `agent: general-purpose` |
| modify | `.claude/skills/consolidate/SKILL.md` | `agent: reflector` → `agent: general-purpose` |

---

## Actions

### Step 1 — Check if migration 011 was applied

```bash
grep -l "agent: reflector\|agent: project-code-reviewer" .claude/skills/*/SKILL.md 2>/dev/null
```

If no matches, migration 011 Pattern A was never applied or already fixed — skip to Verify.

### Step 2 — Fix /review

If `.claude/skills/review/SKILL.md` exists AND contains `agent: project-code-reviewer`:
- Change `agent: project-code-reviewer` → `agent: general-purpose`

The skill body already says "Dispatch the `project-code-reviewer` agent" — this is correct for Pattern B (orchestrator dispatches specialist).

### Step 3 — Fix /reflect

If `.claude/skills/reflect/SKILL.md` exists AND contains `agent: reflector`:
- Change `agent: reflector` → `agent: general-purpose`

The skill body already says "Dispatch the `reflector` agent" — correct for Pattern B.

### Step 4 — Fix /consolidate

If `.claude/skills/consolidate/SKILL.md` exists AND contains `agent: reflector`:
- Change `agent: reflector` → `agent: general-purpose`

The skill body already says "Dispatch `reflector` agent" — correct for Pattern B.

### Step 5 — Verify no remaining self-dispatch

```bash
grep -l "agent: reflector\|agent: project-code-reviewer" .claude/skills/*/SKILL.md 2>/dev/null
```

Should return no matches.

---

## Verify

- [ ] `/review` SKILL.md contains `agent: general-purpose` (not `project-code-reviewer`)
- [ ] `/reflect` SKILL.md contains `agent: general-purpose` (not `reflector`)
- [ ] `/consolidate` SKILL.md contains `agent: general-purpose` (not `reflector`)
- [ ] All three skills still contain dispatch instructions in their body (not deleted)
- [ ] No skill has `agent:` set to a name that matches an agent it dispatches in its body

---

## Context: The Two Valid Patterns

For reference, these are the only valid skill patterns:

**Pattern A — Fork IS the agent (no dispatch needed):**
- `agent: specialist-name` in frontmatter
- Body contains direct instructions for that agent (no "dispatch X" language)
- Fork becomes the agent and executes directly

**Pattern B — Fork is orchestrator (dispatches via Agent tool):**
- `agent: general-purpose` in frontmatter
- Body says "Dispatch the `specialist-name` agent"
- Fork gathers context, then dispatches the specialist

**Never mix:** `agent: X` + body says "dispatch X" = self-dispatch → empty output.

---

Migration complete: `012` — Fix agent frontmatter self-dispatch bug (reverts 011 Pattern A)
