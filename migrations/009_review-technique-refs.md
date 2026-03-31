# Migration: Review Skill Technique References

> Adds technique INDEX.md awareness to /review skill so code reviews can check against RCCF, anti-hallucination, and agent design standards.

---

```yaml
# --- Migration Metadata ---
id: "009"
name: "Review Technique References"
description: >
  Updates /review skill to read .claude/references/techniques/INDEX.md before
  dispatching the project-code-reviewer agent. Enables technique-aware reviews
  for skills, agents, and code-writing components.
base_commit: "dd7df6d5e8c9a77aa3e59121ebbd54364e7054db"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/skills/review/SKILL.md` | Add INDEX.md reading step for technique-aware reviews |

---

## Actions

### Step 1 — Update /review skill (if exists)

**If** `.claude/skills/review/SKILL.md` exists AND does NOT already contain `references/techniques`:
- Read it
- Find the step: `Run \`git diff\` to see what's changed`
- After that step, insert:
  ```
  2. Read `.claude/references/techniques/INDEX.md` (if exists) — use it to decide which technique files are relevant to the review
  ```
- Renumber subsequent steps (old 2→3, old 3→4, old 4→5)
- Write updated file

**If** the file does not exist or already contains `references/techniques`, skip.

### Step 2 — Wire + sync

1. Verify `.claude/references/techniques/INDEX.md` exists (prerequisite from migration 008)
2. If INDEX.md is missing, warn: "Run migration 008 first to install technique references"

---

## Verify

- [ ] If `/review` exists: `grep "references/techniques" .claude/skills/review/SKILL.md`
- [ ] `.claude/references/techniques/INDEX.md` exists

---

Migration complete: `009` — Review skill now technique-aware
