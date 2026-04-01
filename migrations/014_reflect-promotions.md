# Migration: Reflect Promotions — Gotcha + Process Rule

> Adds `context: fork` gotcha to CLAUDE.md and agent dispatch rule to rules/general.md

---

```yaml
# --- Migration Metadata ---
id: "014"
name: "Reflect Promotions — Gotcha + Process Rule"
description: >
  Promotes two learnings: (1) context: fork skill frontmatter bug (claude-code#16803)
  as CLAUDE.md gotcha, (2) mandatory agent dispatch as rules/general.md process rule.
base_commit: "517cb79"
date: "2026-04-01"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `CLAUDE.md` | Add `context: fork` gotcha |
| modify | `.claude/rules/general.md` | Add agent dispatch rule to Process section |

---

## Actions

### Step 1 — Add context: fork gotcha to CLAUDE.md

Read `CLAUDE.md`. In the `## Gotchas` section, append:

```
- `context: fork` in skill frontmatter broken (claude-code#16803) — skills run inline, `agent:` field ignored; use `agent: general-purpose` for Pattern B until fixed
```

If no `## Gotchas` section exists, add one before `## Compact Instructions`.

### Step 2 — Add agent dispatch rule to rules/general.md

Read `.claude/rules/general.md`. In the `## Process` section, append:

```
- When plan|skill specifies agent → dispatch it; agent IS the quality layer; never substitute inline work
```

### Step 3 — Verify

1. Confirm `CLAUDE.md` Gotchas section contains `context: fork` entry
2. Confirm `.claude/rules/general.md` Process section contains agent dispatch rule
3. No broken cross-references introduced

---

## Verify

- [ ] `CLAUDE.md` contains `context: fork` gotcha
- [ ] `.claude/rules/general.md` contains agent dispatch rule in Process section
- [ ] Both files parse correctly (no broken markdown)

---

Migration complete: `014` — Added context: fork gotcha + agent dispatch process rule
