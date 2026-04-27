# Migration 052 — Loopback Budget Composed Forms

<!-- migration-id: 052-loopback-budget-composed-forms -->

> Install `## Composed Forms` section into `.claude/rules/loopback-budget.md` (BNF grammar for two-label `+` composition; permitted/forbidden pair table; canonical-4 invariant). Update two `## Usage` bullets in-place to document composed-form usage and the corresponding `/audit-agents` A8 scan rule. The new section is additive (sentinel-guarded). The two Usage bullet edits are destructive in-place replacements; both use three-tier baseline-sentinel detection per `.claude/rules/general.md` Migration Preservation Discipline. Customized client files emit `SKIP_HAND_EDITED` + `.bak-052` backup + pointer to `## Manual-Apply-Guide`. Prerequisite for the wave-protocol agent-block migration which deploys composed annotations on `END_TO_END_FLOW`-shape agents.

---

## Metadata

```yaml
id: "052"
breaking: false
affects: [rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Migration 050 installed the canonical-4 loopback labels (`LOOPBACK-AUDIT`, `SINGLE-RETRY`, `CONVERGENCE-QUALITY`, `RESOURCE-BUDGET`) and a single-label annotation policy. Field design surfaced a control point that needs **two** simultaneously-active exit conditions: `END_TO_END_FLOW`-shape wave protocols carry an adaptive cap (`RESOURCE-BUDGET: ceiling=10`) AND a quality-extension trigger (`CONVERGENCE-QUALITY: signal=new-layer-discovered`) at the same loop boundary. The single-label vocabulary cannot express this without one of:

1. Inventing a 5th label (forbidden — breaks the canonical-4 invariant + `/audit-agents` A8 mechanical check).
2. Picking one label and silently dropping the other dimension (lossy; breaks `/reflect` clustering by label).
3. Composing the two existing labels with an explicit `+` operator under a documented grammar (chosen approach).

This migration installs a `## Composed Forms` section with a BNF grammar (using a `?` quantifier on the optional second-label group to enforce two-label maximum at parse time), permitted-pair table (`RESOURCE-BUDGET + CONVERGENCE-QUALITY`, `RESOURCE-BUDGET + LOOPBACK-AUDIT`), forbidden-pair table (`SINGLE-RETRY + any`, `LOOPBACK-AUDIT + CONVERGENCE-QUALITY`, three-label combinations), and a canonical-4 invariant statement. The `## Usage` bullets are updated in-place: bullet 1 documents that composing two canonical labels via `+` is NOT inventing a 5th label; bullet 2 documents that the A8 scan uses independent substring match per token so a composed annotation passes both token checks.

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/rules/loopback-budget.md` | Insert new `## Composed Forms` section before `## Usage` heading | Additive (sentinel-guarded) |
| `.claude/rules/loopback-budget.md` | Replace `## Usage` bullet 1 (`do not invent a 5th`) with extended form documenting composed-label exception | Destructive (three-tier) |
| `.claude/rules/loopback-budget.md` | Replace `## Usage` bullet 2 (audit-agents scan) with extended form including composed-form scan semantics + canonical/inline form preference | Destructive (three-tier) |
| `.claude/rules/loopback-budget.md` | Append `<!-- loopback-composed-forms-installed -->` sentinel at EOF | Additive (sentinel-guarded) |

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: .claude/rules/ missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/rules/loopback-budget.md" ]] || { printf "ERROR: .claude/rules/loopback-budget.md missing — migration 050 must be applied first\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

if grep -q "<!-- loopback-composed-forms-installed -->" .claude/rules/loopback-budget.md 2>/dev/null; then
  printf "SKIP: migration 052 already applied (sentinel present)\n"
  exit 0
fi

printf "Applying migration 052: composed-forms section + 2 Usage bullet updates\n"
```

### Step 1 — Insert `## Composed Forms` section before `## Usage` (additive)

Additive: inserts a new section block immediately above the existing `## Usage` heading. Sentinel-guarded — re-running with the section already present emits `SKIP`.

**Sentinel**: target file contains `^## Composed Forms` heading → SKIP.
**Anchor**: literal heading `## Usage` (start of line).

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/rules/loopback-budget.md"

python3 - "$TARGET" <<'PY'
import sys
from pathlib import Path

target = Path(sys.argv[1])
body = target.read_text(encoding="utf-8")

if "\n## Composed Forms\n" in body or body.startswith("## Composed Forms\n"):
    print(f"SKIP: {target} already contains '## Composed Forms' heading (052-1)")
    sys.exit(0)

ANCHOR = "\n## Usage\n"
if ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — '## Usage' heading not found at start of line. Manual application required. See migrations/052-loopback-budget-composed-forms.md §Manual-Apply-Guide §Step-1. Step skipped non-fatally.")
    sys.exit(0)

COMPOSED_FORMS_BLOCK = """
## Composed Forms

A single annotation comment may combine two canonical labels using the `+` operator:

```
<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
```

**Grammar:**
```
LOOPBACK_ANNOTATION := "<!--" SP LABEL_BLOCK ("+" SP LABEL_BLOCK)? SP "-->"
LABEL_BLOCK         := CANONICAL_LABEL ":" SP VALUE_LIST
CANONICAL_LABEL     := "RESOURCE-BUDGET" | "CONVERGENCE-QUALITY"
                     | "LOOPBACK-AUDIT" | "SINGLE-RETRY"
VALUE_LIST          := KV_PAIR ("," SP KV_PAIR)*
KV_PAIR             := KEY "=" VALUE
KEY                 := [a-zA-Z][a-zA-Z0-9_-]*
VALUE               := [A-Za-z0-9][A-Za-z0-9_-]*
SP                  := " " SP | ""
```

**Semantics of `+`:** both labels' constraints are active simultaneously at the same control point. Each is evaluated independently at every loop boundary; whichever exit condition fires first governs.

**Permitted pairs:**
- `RESOURCE-BUDGET + CONVERGENCE-QUALITY` — cost-ceiling + quality-extension (use for `END_TO_END_FLOW` adaptive loops)
- `RESOURCE-BUDGET + LOOPBACK-AUDIT` — cost-ceiling + correction-retry (use when a correction loop is embedded inside a budgeted outer loop)

**Forbidden pairs:**
- `SINGLE-RETRY + any` — SINGLE-RETRY is semantically exclusive (hard stop)
- `LOOPBACK-AUDIT + CONVERGENCE-QUALITY` — ambiguous dual-quality-exit
- Any three-label combination — decompose the loop instead. The grammar's `?` quantifier (zero-or-one) on the optional `("+" SP LABEL_BLOCK)` group enforces the two-label maximum at parse time.

**Canonical-4 invariant preserved:** composition uses existing labels only. No 5th label is introduced.
"""

new_body = body.replace(ANCHOR, COMPOSED_FORMS_BLOCK + ANCHOR, 1)

if new_body == body:
    print(f"ERROR: {target} anchor matched but replace was no-op — aborting to avoid silent drift")
    sys.exit(1)

target.write_text(new_body, encoding="utf-8")
print(f"PATCHED: {target} '## Composed Forms' section inserted before '## Usage' (052-1)")
PY
```

### Step 2 — Replace Usage bullet 1 (canonical-4 / 5th-label rule) with composed-form-aware form

Read-before-write with three-tier baseline-sentinel detection:

- **Tier 1 idempotency sentinel**: `Composing 2 canonical labels via` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th` present (stock post-migration-050 state, safe to replace) → `PATCHED`
- **Tier 3 neither present**: bullet has been customized post-bootstrap → `SKIP_HAND_EDITED` + write `.bak-052` backup if absent + pointer to `## Manual-Apply-Guide §Step-2`. Client customizations preserved.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys
from pathlib import Path

target = Path(".claude/rules/loopback-budget.md")
backup = Path(str(target) + ".bak-052")

POST_052_SENTINEL = "Composing 2 canonical labels via"
BASELINE_LINE = "- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th"
REPLACEMENT_LINE = '- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th. Composing 2 canonical labels via "+" (see "## Composed Forms" above) is NOT inventing a 5th; the canonical-4 set remains closed.'

content = target.read_text(encoding="utf-8")

if POST_052_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {target} Usage bullet 1 already patched (052-2)")
    sys.exit(0)

if BASELINE_LINE not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {target} Usage bullet 1 has been customized post-bootstrap — baseline line absent. Manual application required. See migrations/052-loopback-budget-composed-forms.md §Manual-Apply-Guide §Step-2. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

new_content = content.replace(BASELINE_LINE, REPLACEMENT_LINE, 1)

if new_content == content:
    print(f"ERROR: {target} baseline line detected but replace was no-op — aborting to avoid silent drift")
    sys.exit(1)

target.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {target} Usage bullet 1 (052-2)")
PY
```

### Step 3 — Replace Usage bullet 2 (audit-agents scan rule) with composed-form-aware form

Read-before-write with three-tier baseline-sentinel detection:

- **Tier 1 idempotency sentinel**: `check A8` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline sentinel**: `` - /audit-agents scans .claude/skills/*/SKILL.md for retry/convergence prose w/o a canonical label → FAIL w/ file:line `` present (stock post-migration-050 state, safe to replace) → `PATCHED`
- **Tier 3 neither present**: bullet has been customized post-bootstrap → `SKIP_HAND_EDITED` + write `.bak-052` backup if absent + pointer to `## Manual-Apply-Guide §Step-3`. Client customizations preserved.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import sys
from pathlib import Path

target = Path(".claude/rules/loopback-budget.md")
backup = Path(str(target) + ".bak-052")

POST_052_SENTINEL = "check A8"
BASELINE_LINE = "- `/audit-agents` scans `.claude/skills/*/SKILL.md` for retry/convergence prose w/o a canonical label → FAIL w/ file:line"
REPLACEMENT_LINE = '- /audit-agents scan (check A8): scans ".claude/skills/*/SKILL.md" for retry/convergence prose w/o any canonical label token → FAIL w/ file:line. Scan uses independent substring match per token — a comment containing RESOURCE-BUDGET + CONVERGENCE-QUALITY joined by + passes both token checks. Scan does NOT require a particular composition pair; presence of at least one canonical token suffices for PASS.'

content = target.read_text(encoding="utf-8")

if POST_052_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {target} Usage bullet 2 already patched (052-3)")
    sys.exit(0)

if BASELINE_LINE not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {target} Usage bullet 2 has been customized post-bootstrap — baseline line absent. Manual application required. See migrations/052-loopback-budget-composed-forms.md §Manual-Apply-Guide §Step-3. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

new_content = content.replace(BASELINE_LINE, REPLACEMENT_LINE, 1)

if new_content == content:
    print(f"ERROR: {target} baseline line detected but replace was no-op — aborting to avoid silent drift")
    sys.exit(1)

target.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {target} Usage bullet 2 (052-3)")
PY
```

### Step 4 — Append idempotency sentinel at EOF

Appends `<!-- loopback-composed-forms-installed -->` as a marker to enable the top-level idempotency check. Idempotency-guarded.

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=".claude/rules/loopback-budget.md"

if grep -q "<!-- loopback-composed-forms-installed -->" "$TARGET" 2>/dev/null; then
  printf "SKIP: %s already contains migration-052 sentinel\n" "$TARGET"
else
  printf "\n<!-- loopback-composed-forms-installed -->\n" >> "$TARGET"
  printf "APPENDED: migration-052 sentinel to %s\n" "$TARGET"
fi
```

### Step 5 — Update `.claude/bootstrap-state.json`

Advance `last_migration` and append to `applied[]`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '052'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '052') or a == '052' for a in applied):
    applied.append({
        'id': '052',
        'applied_at': state['last_applied'],
        'description': 'Install canonical Composed Forms section into loopback-budget.md (BNF grammar for two-label + composition; permitted/forbidden pair table; canonical-4 invariant). Updates two Usage bullets in-place to document composed-form usage and the corresponding A8 audit-scan rule.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=052')
PY
```

### Rules for migration scripts

- **Read-before-write** — every step reads the target file, checks sentinel, writes only on safe-patch tier. Destructive Steps 2 + 3 always write `.bak-052` backup before overwrite.
- **Idempotent** — re-running prints `SKIP_ALREADY_APPLIED` per destructive step and `SKIP: migration 052 already applied` at the top when the EOF sentinel is present.
- **Self-contained** — all new section content + replacement bullet text inlined in python3 heredocs. No remote fetch.
- **Additive default** — Step 1 (section insert) and Step 4 (sentinel append) are additive. Steps 2 + 3 (Usage bullet replacements) are destructive in-place edits with three-tier detection.
- **Scope lock** — touches only `.claude/rules/loopback-budget.md` + `.claude/bootstrap-state.json`. No agent edits, no skill edits, no hook changes. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `.claude/rules/agent-scope-lock.md`).
- **Non-fatal anchor miss** — Step 1 (`## Usage` anchor missing) emits `ANCHOR MISSING` + Manual-Apply-Guide pointer + `sys.exit(0)`; subsequent steps still run.

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. loopback-budget.md exists
if [[ -f ".claude/rules/loopback-budget.md" ]]; then
  printf "PASS: .claude/rules/loopback-budget.md present\n"
else
  printf "FAIL: .claude/rules/loopback-budget.md missing\n"
  fail=1
fi

# 2. ## Composed Forms heading present
if grep -q "^## Composed Forms" .claude/rules/loopback-budget.md 2>/dev/null; then
  printf "PASS: '## Composed Forms' heading present\n"
else
  printf "FAIL: '## Composed Forms' heading missing\n"
  fail=1
fi

# 3. BNF grammar markers present
for marker in "LOOPBACK_ANNOTATION" "LABEL_BLOCK" "CANONICAL_LABEL" "Permitted pairs" "Forbidden pairs" "Canonical-4 invariant preserved"; do
  if grep -q "$marker" .claude/rules/loopback-budget.md 2>/dev/null; then
    printf "PASS: '%s' present\n" "$marker"
  else
    printf "FAIL: '%s' missing\n" "$marker"
    fail=1
  fi
done

# 4. Usage bullet 1 carries composed-form sentinel
if grep -q "Composing 2 canonical labels via" .claude/rules/loopback-budget.md 2>/dev/null; then
  printf "PASS: Usage bullet 1 patched (composed-form-aware)\n"
else
  printf "FAIL: Usage bullet 1 missing 'Composing 2 canonical labels via' sentinel\n"
  fail=1
fi

# 5. Usage bullet 2 carries A8 sentinel
if grep -q "check A8" .claude/rules/loopback-budget.md 2>/dev/null; then
  printf "PASS: Usage bullet 2 patched (A8-aware)\n"
else
  printf "FAIL: Usage bullet 2 missing 'check A8' sentinel\n"
  fail=1
fi

# 6. EOF sentinel present
if grep -q "<!-- loopback-composed-forms-installed -->" .claude/rules/loopback-budget.md 2>/dev/null; then
  printf "PASS: migration-052 EOF sentinel present\n"
else
  printf "FAIL: migration-052 EOF sentinel missing\n"
  fail=1
fi

# 7. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "052" ]]; then
  printf "PASS: last_migration = 052\n"
else
  printf "FAIL: last_migration = %s (expected 052)\n" "$last"
  fail=1
fi

printf -- "---\n"
if [[ $fail -eq 0 ]]; then
  printf "Migration 052 verification: ALL PASS\n"
  printf "\nOptional cleanup: remove .bak-052 backups once you've confirmed patches are correct:\n"
  printf "  find .claude/rules -name '*.bak-052' -delete\n"
else
  printf "Migration 052 verification: FAILURES — state NOT updated\n"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix. `SKIP_HAND_EDITED` from Steps 2 or 3 will cause verify-step 4 or 5 to fail respectively — resolve by applying the corresponding `## Manual-Apply-Guide` section, then re-run verify.

---

## State Update

On success:
- `last_migration` → `"052"`
- append `{ "id": "052", "applied_at": "<ISO8601>", "description": "Install canonical Composed Forms section into loopback-budget.md (BNF grammar for two-label + composition; permitted/forbidden pair table; canonical-4 invariant). Updates two Usage bullets in-place to document composed-form usage and the corresponding A8 audit-scan rule." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Top-level — `<!-- loopback-composed-forms-installed -->` sentinel present → `SKIP: migration 052 already applied`
- Step 1 — `## Composed Forms` heading present → `SKIP`
- Step 2 — `Composing 2 canonical labels via` present in bullet 1 → `SKIP_ALREADY_APPLIED`
- Step 3 — `check A8` present in bullet 2 → `SKIP_ALREADY_APPLIED`
- Step 4 — EOF sentinel present → `SKIP`
- Step 5 — `applied[]` dedup check (migration id == `'052'`) → no duplicate append

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply remain `SKIP_HAND_EDITED` on re-run (both sentinels absent) — manual merge per `## Manual-Apply-Guide` is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-052 backup (written by Steps 2-3 before overwrite)
if [[ -f ".claude/rules/loopback-budget.md.bak-052" ]]; then
  mv ".claude/rules/loopback-budget.md.bak-052" ".claude/rules/loopback-budget.md"
  printf "Restored: .claude/rules/loopback-budget.md from .bak-052\n"
else
  printf "NOOP: .claude/rules/loopback-budget.md.bak-052 not present (file may have been SKIP_HAND_EDITED — no rollback needed)\n"
fi

# Option B — tracked strategy (if .claude/ is committed to project repo)
# git checkout -- .claude/rules/loopback-budget.md

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '052':
    state['last_migration'] = '051'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '052') or a == '052'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=051')
PY
```

Rollback via `.bak-052` is safe because Steps 2 and 3 write the backup before any destructive edit. If no backup exists, the file was either fully `SKIP_ALREADY_APPLIED` (nothing to roll back) or `SKIP_HAND_EDITED` (nothing was written, so nothing to roll back). Step 1 + Step 4 are additive; manual rollback removes the inserted `## Composed Forms` block and the trailing `<!-- loopback-composed-forms-installed -->` sentinel.

---

## Manual-Apply-Guide

Operators reach this section via the `SKIP_HAND_EDITED` or `ANCHOR MISSING` guidance lines emitted by the automated steps above. Each subsection below holds the verbatim target content for one step — copy directly into the corresponding file when automation skipped the patch.

**General procedure per skipped step**:
1. Open `.claude/rules/loopback-budget.md`.
2. Locate the section/bullet named in the step.
3. Read the new content block below for that step.
4. Manually merge: preserve your project-specific additions (extra bullets, extra commentary); incorporate the new content.
5. Save the file.
6. Run the verification snippet shown at the end of each subsection to confirm the patch landed correctly.
7. A `.bak-052` backup of the pre-migration file state exists at `.claude/rules/loopback-budget.md.bak-052` if the migration wrote one; use `diff .claude/rules/loopback-budget.md.bak-052 .claude/rules/loopback-budget.md` to see exactly what the migration would have overwritten.

---

### §Step-1 — `## Composed Forms` section insert

**Target**: `.claude/rules/loopback-budget.md` — new `## Composed Forms` section, inserted immediately above the existing `## Usage` heading.

**Context**: the migration detected that the literal anchor `## Usage` (start of line) was not found in the rules file. The Usage section may have been renamed, removed, or restructured.

**New content (verbatim — insert immediately above the section that documents per-label usage / annotation policy)**:

```markdown
## Composed Forms

A single annotation comment may combine two canonical labels using the `+` operator:

```
<!-- RESOURCE-BUDGET: ceiling=10 + CONVERGENCE-QUALITY: signal=new-layer-discovered -->
```

**Grammar:**
```
LOOPBACK_ANNOTATION := "<!--" SP LABEL_BLOCK ("+" SP LABEL_BLOCK)? SP "-->"
LABEL_BLOCK         := CANONICAL_LABEL ":" SP VALUE_LIST
CANONICAL_LABEL     := "RESOURCE-BUDGET" | "CONVERGENCE-QUALITY"
                     | "LOOPBACK-AUDIT" | "SINGLE-RETRY"
VALUE_LIST          := KV_PAIR ("," SP KV_PAIR)*
KV_PAIR             := KEY "=" VALUE
KEY                 := [a-zA-Z][a-zA-Z0-9_-]*
VALUE               := [A-Za-z0-9][A-Za-z0-9_-]*
SP                  := " " SP | ""
```

**Semantics of `+`:** both labels' constraints are active simultaneously at the same control point. Each is evaluated independently at every loop boundary; whichever exit condition fires first governs.

**Permitted pairs:**
- `RESOURCE-BUDGET + CONVERGENCE-QUALITY` — cost-ceiling + quality-extension (use for `END_TO_END_FLOW` adaptive loops)
- `RESOURCE-BUDGET + LOOPBACK-AUDIT` — cost-ceiling + correction-retry (use when a correction loop is embedded inside a budgeted outer loop)

**Forbidden pairs:**
- `SINGLE-RETRY + any` — SINGLE-RETRY is semantically exclusive (hard stop)
- `LOOPBACK-AUDIT + CONVERGENCE-QUALITY` — ambiguous dual-quality-exit
- Any three-label combination — decompose the loop instead. The grammar's `?` quantifier (zero-or-one) on the optional `("+" SP LABEL_BLOCK)` group enforces the two-label maximum at parse time.

**Canonical-4 invariant preserved:** composition uses existing labels only. No 5th label is introduced.
```

**Merge instructions**:
1. Open `.claude/rules/loopback-budget.md`.
2. Locate the section that documents per-label usage / annotation policy (typically `## Usage`, but may have been renamed to `## Annotation Policy` or similar).
3. Insert the verbatim block above immediately ABOVE that section heading, separated by one blank line.
4. Save the file.

**Verification**:
```bash
grep -q "^## Composed Forms" .claude/rules/loopback-budget.md && echo "PASS"
grep -q "LOOPBACK_ANNOTATION :=" .claude/rules/loopback-budget.md && echo "PASS"
```

---

### §Step-2 — Usage bullet 1 (canonical-4 / 5th-label rule)

**Target**: `.claude/rules/loopback-budget.md` — Usage bullet 1 (the bullet that says "do not invent a 5th").

**Context**: the migration detected that the baseline bullet `- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th` was absent from the file, meaning the bullet was customized post-bootstrap (different phrasing, additional clauses, or removed entirely).

**New content (verbatim — replace the entire bullet line)**:

```markdown
- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th. Composing 2 canonical labels via "+" (see "## Composed Forms" above) is NOT inventing a 5th; the canonical-4 set remains closed.
```

**Merge instructions**:
1. Open `.claude/rules/loopback-budget.md`.
2. Locate the Usage section bullet that mentions "do not invent a 5th" or equivalent canonical-4 invariant statement.
3. Replace the entire bullet with the verbatim line above. If you have added project-specific elaboration (e.g., a sub-bullet listing your project's canonical labels in scope), preserve it as a sub-bullet underneath.
4. Save the file.

**Verification**:
```bash
grep -q "Composing 2 canonical labels via" .claude/rules/loopback-budget.md && echo "PASS"
```

---

### §Step-3 — Usage bullet 2 (audit-agents scan rule)

**Target**: `.claude/rules/loopback-budget.md` — Usage bullet 2 (the bullet that says `/audit-agents` scans skill files).

**Context**: the migration detected that the baseline bullet `` - /audit-agents scans .claude/skills/*/SKILL.md for retry/convergence prose w/o a canonical label → FAIL w/ file:line `` was absent from the file, meaning the bullet was customized post-bootstrap.

**New content (verbatim — replace the entire bullet line)**:

```markdown
- /audit-agents scan (check A8): scans ".claude/skills/*/SKILL.md" for retry/convergence prose w/o any canonical label token → FAIL w/ file:line. Scan uses independent substring match per token — a comment containing RESOURCE-BUDGET + CONVERGENCE-QUALITY joined by + passes both token checks. Scan does NOT require a particular composition pair; presence of at least one canonical token suffices for PASS.
```

**Merge instructions**:
1. Open `.claude/rules/loopback-budget.md`.
2. Locate the Usage section bullet that mentions `/audit-agents scans` or describes the A8 mechanical check.
3. Replace the entire bullet with the verbatim line above. If you have added project-specific scan-target paths (e.g., custom skill subdirectories), preserve them as sub-bullets underneath.
4. Save the file.

**Verification**:
```bash
grep -q "check A8" .claude/rules/loopback-budget.md && echo "PASS"
```

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:

1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the template at `templates/rules/loopback-budget.md` is already in the target state).
2. Do NOT directly edit `.claude/rules/loopback-budget.md` in the bootstrap repo — direct edits bypass the template and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "052",
  "file": "052-loopback-budget-composed-forms.md",
  "description": "Install canonical Composed Forms section into loopback-budget.md (BNF grammar for two-label + composition; permitted/forbidden pair table). Updates two Usage bullets in-place to document the composed-form usage and the corresponding A8 audit-scan rule. Prerequisite for the wave-protocol agent-block migration which deploys composed annotations.",
  "breaking": false
}
```
