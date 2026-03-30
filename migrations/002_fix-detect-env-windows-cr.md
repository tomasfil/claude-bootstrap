---
id: "002"
name: fix-detect-env-windows-cr
description: Strip Windows carriage returns in detect-env.sh to fix bash arithmetic errors
base_commit: 9123a3aeef0f65b9fd48ca03476ec93442b44756
date: 2026-03-30
breaking: false
---

# Migration 002 — Fix detect-env.sh Windows CR

> On Windows (Git Bash), `cat` and `grep -c` output includes `\r` which breaks
> bash arithmetic expressions. Add `tr -d '\r'` to all numeric variable reads.

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/hooks/detect-env.sh` | Add `tr -d '\r'` to 4 numeric reads |

---

## Actions

### Step 1 — Patch detect-env.sh

In `.claude/hooks/detect-env.sh`, pipe `tr -d '\r'` into every `cat` or `grep -c` that feeds a numeric variable:

```bash
# Line: COUNT=$(cat "$SESSION_COUNT_FILE" ...)
# Before:
COUNT=$(cat "$SESSION_COUNT_FILE" 2>/dev/null || echo 0)
# After:
COUNT=$(cat "$SESSION_COUNT_FILE" 2>/dev/null | tr -d '\r' || echo 0)

# Line: LAST_DREAM=$(cat "$LAST_DREAM_FILE" ...)
# Before:
LAST_DREAM=$(cat "$LAST_DREAM_FILE" 2>/dev/null || echo 0)
# After:
LAST_DREAM=$(cat "$LAST_DREAM_FILE" 2>/dev/null | tr -d '\r' || echo 0)

# Line: CURRENT_ENTRIES=$(grep -c ...)
# Before:
CURRENT_ENTRIES=$(grep -c '^##\+ [0-9]\{4\}-' "$LOG_FILE" 2>/dev/null || echo 0)
# After:
CURRENT_ENTRIES=$(grep -c '^##\+ [0-9]\{4\}-' "$LOG_FILE" 2>/dev/null | tr -d '\r' || echo 0)

# Line: LAST_ENTRIES=$(cat "$LAST_REFLECT_FILE" ...)
# Before:
LAST_ENTRIES=$(cat "$LAST_REFLECT_FILE" 2>/dev/null || echo 0)
# After:
LAST_ENTRIES=$(cat "$LAST_REFLECT_FILE" 2>/dev/null | tr -d '\r' || echo 0)
```

---

## Verify

- [ ] `.claude/hooks/detect-env.sh` contains `tr -d '\r'` on all 4 numeric reads
- [ ] Run `bash .claude/hooks/detect-env.sh` — no arithmetic errors
- [ ] `settings.json` parses as valid JSON

---

Migration complete: `002` — Fix Windows carriage return in detect-env.sh arithmetic
