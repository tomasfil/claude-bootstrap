# Migration: Fix Agent Dispatch Pipeline

> Fix unreliable agent dispatch across skills — Pattern A skills get correct agent: frontmatter, Pattern B skills get mandatory dispatch w/ no main-thread fallbacks, /commit stripped to git-only.

---

```yaml
# --- Migration Metadata ---
id: "011"
name: "Fix Agent Dispatch Pipeline"
description: >
  Fix unreliable agent dispatch across skills. Pattern A skills get correct
  agent: frontmatter. Pattern B skills get mandatory dispatch, no main-thread
  fallbacks. /commit stripped to git-only.
base_commit: "d4bdde8"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/skills/review/SKILL.md` | `agent: project-code-reviewer`, remove fallback |
| modify | `.claude/skills/reflect/SKILL.md` | `agent: reflector`, remove main-thread fallback |
| modify | `.claude/skills/consolidate/SKILL.md` | `agent: reflector` |
| modify | `.claude/skills/brainstorm/SKILL.md` | MUST dispatch researcher |
| modify | `.claude/skills/ci-triage/SKILL.md` | MUST dispatch debugger |
| modify | `.claude/skills/module-write/SKILL.md` | MUST dispatch code-writer-markdown |
| modify | `.claude/skills/code-write/SKILL.md` | MUST dispatch (conditional fallback) |
| modify | `.claude/skills/execute-plan/SKILL.md` | MUST dispatch per-task agents |
| modify | `.claude/skills/tdd/SKILL.md` | MUST dispatch, keep agent-to-agent fallback |
| modify | `.claude/skills/debug/SKILL.md` | MUST dispatch debugger |
| modify | `.claude/skills/commit/SKILL.md` | Remove embedded verify/review |

---

## Actions

### Step 1 — Discovery

Scan `.claude/agents/` to inventory all available agents:

```bash
ls .claude/agents/*.md 2>/dev/null | sed 's|.claude/agents/||;s|\.md||' | sort
```

Present the agent-to-skill mapping to the user:

```
Agent Dispatch Mapping (discovered from .claude/agents/):
  /review        → project-code-reviewer
  /reflect       → reflector
  /consolidate   → reflector
  /brainstorm    → researcher (dispatched in body)
  /ci-triage     → debugger (dispatched in body)
  /module-write  → code-writer-markdown (dispatched in body)
  /code-write    → [list discovered code-writer-* agents] (dispatched by type)
  /tdd           → tdd-runner, test-writer (dispatched in body)
  /debug         → quick-check, debugger (dispatched in body)
  /execute-plan  → (per-task, uses plan's Agent: field)
```

Also check which code-writer specialist agents exist:

```bash
ls .claude/agents/code-writer-*.md 2>/dev/null
```

Record whether specialists were found — this affects Step 4.

Wait for user confirmation before proceeding.

### Step 2 — Pattern A: Fix single-agent skill frontmatters

For each skill below, guard with file-existence check AND verify current value is `general-purpose`:

**`/review`:**
- If `.claude/skills/review/SKILL.md` exists AND contains `agent: general-purpose`:
  - Change `agent: general-purpose` → `agent: project-code-reviewer`
  - Remove any `### Fallback` section or `> **Fallback:** If project-code-reviewer...` line

**`/reflect`:**
- If `.claude/skills/reflect/SKILL.md` exists AND contains `agent: general-purpose`:
  - Change `agent: general-purpose` → `agent: reflector`
  - Remove ONLY main-thread fallback lines (containing "perform the work on the main thread")
  - KEEP data-availability fallbacks (about instincts/, techniques/, log.md)

**`/consolidate`:**
- If `.claude/skills/consolidate/SKILL.md` exists AND contains `agent: general-purpose`:
  - Change `agent: general-purpose` → `agent: reflector`

### Step 3 — Pattern B: Remove main-thread fallbacks, mandate dispatch

For each skill below, guard with file-existence check:

**For all 7 skills** (`brainstorm`, `ci-triage`, `module-write`, `execute-plan`, `tdd`, `debug`, `code-write`):
- Remove any line matching: `> **Fallback:** If the X agent doesn't exist, perform the work on the main thread.`
- Strengthen dispatch language: change "Dispatch the X agent" → "MUST dispatch the X agent — do not perform this work inline"

**Exceptions:**
- **`/tdd`**: Remove main-thread fallback ONLY. KEEP the agent-to-agent fallback: "If the test-writer agent doesn't exist, use tdd-runner for all tasks"
- **`/code-write`**: See Step 4 (handled separately based on discovery)

### Step 4 — `/code-write` conditional fix

Based on Step 1 discovery:

**If `code-writer-*` agents were found:**
- Remove the main-thread fallback clause
- Add MUST dispatch language
- Add exception note: "If no code-writer-* agents exist in .claude/agents/, perform the work on the main thread"

**If NO `code-writer-*` agents were found:**
- Keep the existing fallback clause (Module 16 has not been run yet)
- Strengthen dispatch language but note the fallback is intentionally kept
- Log to `.learnings/log.md`: "Migration 011: /code-write fallback kept — no code-writer-* agents found. Run Module 16 to generate specialists."

### Step 5 — Strip `/commit` to git-only

If `.claude/skills/commit/SKILL.md` exists:
- If it contains `### Step 0: Auto-Verify` or `### Step 0`:
  - Remove the Step 0 block (auto-verify with verifier agent)
- If it contains `### Step 1: Auto-Review` or `### Step 1`:
  - Remove the Step 1 block (auto-review with project-code-reviewer)
- Renumber remaining steps if needed
- Add blockquote after the main heading: `> Assumes /review and /verify have already run per CLAUDE.md automation. Do not embed verify/review here.`

If Step 0/Step 1 are not present, the skill is already clean — skip.

### Step 6 — Verify

1. Pattern A skills: `grep "agent: general-purpose"` returns no matches in review, reflect, consolidate
2. Pattern B skills: `grep "MUST dispatch"` returns matches in all 7 orchestrator skills
3. Pattern B skills: `grep "perform the work on the main thread"` returns no matches (except code-write if Step 4 kept fallback)
4. `/commit`: no "Auto-Verify" or "Auto-Review" text
5. All modified files exist and are valid markdown

---

## Verify

- [ ] Step 1 discovery completed and mapping presented to user
- [ ] Pattern A: review has `agent: project-code-reviewer`, reflect/consolidate have `agent: reflector`
- [ ] Pattern B: all 7 skills have "MUST dispatch" language
- [ ] Pattern B: no main-thread fallbacks (except code-write conditional)
- [ ] /tdd: agent-to-agent fallback (test-writer to tdd-runner) preserved
- [ ] /commit: no embedded verify/review steps
- [ ] /code-write: fallback handled correctly based on specialist agent discovery

---

Migration complete: `011` — Fix agent dispatch pipeline across all orchestrator skills
