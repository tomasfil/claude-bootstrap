# Migration 045 — Review Skill Open-Questions Discipline Check Paren Fix

<!-- migration-id: 045-review-find-paren-fix -->

> Fixes operator-precedence bug in the `/review` skill Open Questions Discipline check. The `find` command at line 47 of `.claude/skills/review/SKILL.md` uses `-o` to alternate between `-name "*-research.md"` and `-name "*-spec.md"` without parenthesis grouping. Without `\( ... \)`, `-mtime -7` binds only to the second `-name` clause — find returns ALL research files (no mtime filter) plus spec files within 7 days, producing false-positive Open Questions findings on every `/review` run. Fix: wrap the `-name` alternation in `\( ... \)` so `-mtime -7` applies to both patterns. Single-line, destructive replace — uses three-tier baseline-sentinel detection per `general.md` Migration Preservation Discipline to preserve any project-specific customizations to that line.

---

## Metadata

```yaml
id: "045"
breaking: false
affects: [skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

`templates/skills/review/SKILL.md` line 47 (shipped to client projects as `.claude/skills/review/SKILL.md:47`) contains:

```
recent=$(find .claude/specs/{branch}/ -maxdepth 2 -name "*-research.md" -o -name "*-spec.md" -mtime -7 2>/dev/null)
```

`find`'s default precedence is `-a` (AND) between adjacent primaries, `-o` (OR) lower. Without explicit grouping, the expression parses as:

```
(-name "*-research.md") OR (-name "*-spec.md" AND -mtime -7)
```

Result: every research file in the tree matches (mtime filter ignored), only spec files within 7 days match. The Open Questions Discipline step then `grep`s every historical research file for `## Open Questions` and emits WARNING on each absence — most historical research files predate the discipline and have no such section, so every `/review` run produces a flood of false-positive WARNINGs that drown real findings.

## Rationale

1. `/review` is an auto-run skill (triggers before `/commit`). False-positive WARNINGs on every run train users to ignore review output — degrades the signal-to-noise ratio of the entire review pipeline.
2. The fix is a mechanical paren addition around the `-name` alternation: `\( -name "*-research.md" -o -name "*-spec.md" \) -mtime -7`. Precedence becomes `(A OR B) AND C` — mtime applies to both patterns. Single-character-class change, zero-behavior-regression for the intended case (recent research + spec files).
3. **Project-specific customizations MUST be preserved.** The destructive line replace implements three-tier baseline-sentinel detection per `general.md` Migration Preservation Discipline: (a) post-045 idempotency sentinel present (`\( -name "*-research.md"` with backslash-paren) → SKIP already patched; (b) pre-045 baseline sentinel present (exact stock line without parens) → safe PATCH; (c) neither present → file was hand-edited post-bootstrap → `SKIP_HAND_EDITED` + `.bak-045` backup written + pointer to `## Manual-Apply-Guide`. Blind overwrite of customized content is structurally prevented.

---

## Changes

1. Replaces the `find` command at line 47 of `.claude/skills/review/SKILL.md` — adds `\( ... \)` grouping around the `-name` alternation so `-mtime -7` applies to both `*-research.md` and `*-spec.md`. Marker: presence of `\( -name "*-research.md"` substring on that line.
2. Advances `.claude/bootstrap-state.json` → `last_migration: "045"` + appends to `applied[]`.

Idempotent: re-run detects the paren grouping marker and prints `SKIP: already patched`.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f ".claude/skills/review/SKILL.md" ]] || { echo "ERROR: .claude/skills/review/SKILL.md missing"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

if grep -qF '\( -name "*-research.md"' .claude/skills/review/SKILL.md 2>/dev/null; then
  echo "SKIP: migration 045 already applied (paren grouping present on find command line)"
  exit 0
fi

echo "Applying migration 045: paren grouping not yet present on find command line"
```

### Step 1 — Patch `.claude/skills/review/SKILL.md`

Read-before-write with three-tier baseline-sentinel detection on the destructive single-line edit (per `general.md` Migration Preservation Discipline).

- **(a)** idempotency sentinel — `\( -name "*-research.md"` substring present → `SKIP: already patched`.
- **(b)** baseline sentinel — exact stock line `recent=$(find .claude/specs/{branch}/ -maxdepth 2 -name "*-research.md" -o -name "*-spec.md" -mtime -7 2>/dev/null)` present (pre-045 content, safe to replace) → `PATCHED`.
- **(c)** neither present — file was hand-edited post-bootstrap → write `.bak-045` backup (if absent), emit pointer to `## Manual-Apply-Guide`, do NOT overwrite → `SKIP_HAND_EDITED`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, shutil, sys

path = ".claude/skills/review/SKILL.md"
idempotency_sentinel = '\\( -name "*-research.md"'
baseline_sentinel = 'recent=$(find .claude/specs/{branch}/ -maxdepth 2 -name "*-research.md" -o -name "*-spec.md" -mtime -7 2>/dev/null)'
patched_line = 'recent=$(find .claude/specs/{branch}/ -maxdepth 2 \\( -name "*-research.md" -o -name "*-spec.md" \\) -mtime -7 2>/dev/null)'

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Tier (a) — idempotency sentinel
if idempotency_sentinel in content:
    print(f"SKIP: {path} already patched (idempotency sentinel present)")
    sys.exit(0)

# Tier (b) — baseline sentinel (exact stock line)
if baseline_sentinel in content:
    patched = content.replace(baseline_sentinel, patched_line, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(patched)
    print(f"PATCHED: {path} (baseline sentinel matched — paren grouping applied)")
    sys.exit(0)

# Tier (c) — neither sentinel present → hand-edited
backup = path + ".bak-045"
if not os.path.exists(backup):
    shutil.copy2(path, backup)
    print(f"BACKUP: wrote {backup}")

print(f"SKIP_HAND_EDITED: {path} — neither idempotency sentinel nor baseline sentinel present.")
print("This file was customized post-bootstrap. Automatic patching would lose your changes.")
print("See `## Manual-Apply-Guide` section in migrations/045-review-find-paren-fix.md for the verbatim")
print("new-content block + merge instructions. After manual merge, rerun this migration to advance state.")
sys.exit(0)
PY
```

### Step 2 — Update `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '045'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '045') or a == '045' for a in applied):
    applied.append({
        'id': '045',
        'applied_at': state['last_applied'],
        'description': 'Fix operator-precedence bug in /review skill open-questions discipline check — adds \\( ... \\) grouping around -name alternation in find command so -mtime -7 applies to both research and spec filename patterns.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=045')
PY
```

### Rules for migration scripts

- **Read-before-write** — the patch step reads the target file, detects an existing idempotency sentinel, falls back to baseline-sentinel match, and only writes on confirmed safe tier.
- **Idempotent** — re-running prints `SKIP: migration 045 already applied` at the top AND `SKIP: already patched` at the file step.
- **Self-contained** — all new content inlined in python3 heredocs; no external fetch.
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on failure.
- **Scope lock** — touches only: `.claude/skills/review/SKILL.md`, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no agent renames. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. review/SKILL.md carries the paren grouping on the find command line
if grep -qF '\( -name "*-research.md"' .claude/skills/review/SKILL.md 2>/dev/null; then
  echo "PASS: review/SKILL.md find command carries \\( ... \\) grouping"
else
  echo "FAIL: review/SKILL.md find command missing paren grouping"
  fail=1
fi

# 2. review/SKILL.md still contains the full find line on a single line (no accidental break)
if grep -qF 'find .claude/specs' .claude/skills/review/SKILL.md 2>/dev/null; then
  echo "PASS: review/SKILL.md still carries find .claude/specs pattern"
else
  echo "FAIL: review/SKILL.md find .claude/specs pattern missing"
  fail=1
fi

# 3. Exactly one line carries the patched form (no duplicate insert)
count=$(grep -cF '\( -name "*-research.md" -o -name "*-spec.md" \)' .claude/skills/review/SKILL.md 2>/dev/null)
if [[ "$count" == "1" ]]; then
  echo "PASS: review/SKILL.md contains exactly 1 patched line"
else
  echo "FAIL: review/SKILL.md contains $count patched lines (expected 1)"
  fail=1
fi

# 4. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "045" ]]; then
  echo "PASS: last_migration = 045"
else
  echo "FAIL: last_migration = $last (expected 045)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 045 verification: ALL PASS"
else
  echo "Migration 045 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"045"`
- append `{ "id": "045", "applied_at": "<ISO8601>", "description": "Fix operator-precedence bug in /review skill open-questions discipline check — adds \\( ... \\) grouping around -name alternation in find command so -mtime -7 applies to both research and spec filename patterns." }` to `applied[]`

---

## Rollback

Restore the patched file from version control or companion-repo snapshot:

```bash
#!/usr/bin/env bash
# Tracked strategy (file committed to project repo)
git checkout -- .claude/skills/review/SKILL.md

# Companion strategy — restore from companion repo snapshot
# cp ~/.claude-configs/<project>/.claude/skills/review/SKILL.md ./.claude/skills/review/

# Hand-edited strategy — restore from .bak-045 backup written during SKIP_HAND_EDITED branch
# cp .claude/skills/review/SKILL.md.bak-045 .claude/skills/review/SKILL.md
```

Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"044"` and remove the `045` entry from `applied[]`.

The migration is an in-place single-line edit. Rollback via `git checkout` is safe provided the file was tracked before apply.

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "045",
  "file": "045-review-find-paren-fix.md",
  "description": "Fix operator-precedence bug in /review skill open-questions discipline check — adds \\( ... \\) grouping around -name alternation in find command so -mtime -7 applies to both research and spec filename patterns, eliminating false-positive OQ findings on every /review run.",
  "breaking": false
}
```

---

## Manual-Apply-Guide

When Step 1 reports `SKIP_HAND_EDITED: .claude/skills/review/SKILL.md — neither idempotency sentinel nor baseline sentinel present`, the migration detected that line 47 (the `find` command in the Open Questions Discipline check) was customized post-bootstrap. Automatic patching is unsafe — your customization would be lost. This guide provides the verbatim new-content line plus merge instructions so you can manually integrate the paren fix while preserving your customization.

### What the migration would have done

Located the single line beginning with `recent=$(find .claude/specs/{branch}/` (previously around line 47 in the stock skill) and replaced it in full with the parenthesized form below.

### Verbatim new-content line (replace in full)

The patched line — paste this as a one-line replacement for the current `recent=$(find ...)` line in your customized `.claude/skills/review/SKILL.md`:

```
  recent=$(find .claude/specs/{branch}/ -maxdepth 2 \( -name "*-research.md" -o -name "*-spec.md" \) -mtime -7 2>/dev/null)
```

Leading indent: two spaces (the line sits inside an enumerated step body, preceded by the `Glob — find recent research + spec files in current branch's spec dir:` prose line).

### Merge instructions

1. **Locate your customized line.** Open `.claude/skills/review/SKILL.md` and find the `find .claude/specs/` command. It may appear on line 47 (stock position), or at a different line number if you added content above. It may include your own filename patterns, your own maxdepth, your own 2>/dev/null destination, or different `-mtime` thresholds.

2. **Identify which parts are your customization vs. the bug.** The bug is strictly: `-name "A" -o -name "B" -mtime -N` without parens. The fix wraps the `-o`-joined `-name` primaries in `\( ... \)` so the subsequent `-mtime` applies to both.

3. **Apply the paren grouping to your version.** Keep your customized filename patterns, your customized maxdepth, your customized mtime value, your customized redirects. Only add `\(` before the first `-name` in the alternation and `\)` after the last `-name` in the alternation. Example, if you added a third pattern:

   ```
   recent=$(find .claude/specs/{branch}/ -maxdepth 2 \( -name "*-research.md" -o -name "*-spec.md" -o -name "*-plan.md" \) -mtime -30 2>/dev/null)
   ```

4. **Save the file.**

5. **Rerun the migration.** After your manual merge, the file now contains the idempotency sentinel `\( -name "*-research.md"`. Rerunning `/migrate-bootstrap` will detect the sentinel in Step 1 and print `SKIP: already patched`, then proceed to Step 2 (bootstrap-state advance). This completes the migration cleanly.

6. **Restore the backup only if needed.** If you want to abandon the manual merge and inspect the original, the migration wrote `.claude/skills/review/SKILL.md.bak-045` on first SKIP_HAND_EDITED encounter. `cp .claude/skills/review/SKILL.md.bak-045 .claude/skills/review/SKILL.md` restores pre-migration state; you can then decide whether to restart the merge or abort.

### Why this matters

The Open Questions Discipline check runs on every `/review` invocation. `/review` is auto-run before `/commit`. Without the paren fix, every `/review` in a project with historical research files emits WARNING lines for each research file predating the discipline — drowning real review findings in noise and training users to skip review output. The fix is one-character-pair wide, zero-regression for the intended case, and required for the discipline check to produce actionable signal rather than noise.
