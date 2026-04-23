# Migration 046 — Drift Fixes (proj-code-reviewer model field + proj-code-writer-bash classification comment)

<!-- migration-id: 046-drift-fixes -->

> Two small drift fixes for client-project agents. Fix 1 adds the `model: sonnet` field to `.claude/agents/proj-code-reviewer.md` frontmatter where it is missing — `/audit-model-usage` reports `UNKNOWN` when the field is absent, masking DRIFT/COMPLIANT signal and breaking the audit's ability to flag real model drift. Fix 2 updates the `# high:` justification comment on `.claude/agents/proj-code-writer-bash.md` to `# xhigh:` so the `# {effort}: {TOKEN}` invariant from migration 029 stays in sync with the `effort: xhigh` frontmatter field adopted in migration 044. Both edits are destructive line replaces — use three-tier baseline-sentinel detection per `.claude/rules/general.md` Migration Preservation Discipline to preserve any project-specific customizations. Customized files receive `SKIP_HAND_EDITED` + `.bak-046` backup + pointer to `## Manual-Apply-Guide`.

---

## Metadata

```yaml
id: "046"
breaking: false
affects: [agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Two independent drift findings surfaced after migrations 029 (justification-comment invariant) and 044 (xhigh effort adoption):

1. **`.claude/agents/proj-code-reviewer.md` is missing the `model:` frontmatter field.** `/audit-model-usage` (installed by migration 030) parses agent frontmatter and joins against `.claude/rules/model-selection.md` expected bindings. When `model:` is absent, the audit emits `UNKNOWN` for the row instead of `COMPLIANT` / `DRIFT`. `UNKNOWN` masks actual drift — an `UNKNOWN` row may be silently running on an unexpected model and the audit cannot tell. Per `.claude/rules/model-selection.md` § Agent Classification Table, `proj-code-reviewer` is classified as `sonnet` + `xhigh` + `SUBTLE_ERROR_RISK`. The frontmatter must carry `model: sonnet` on its own line between the description and the `effort:` field (or anywhere inside the frontmatter block — YAML order does not matter) for the audit to resolve the row correctly.

2. **`.claude/agents/proj-code-writer-bash.md` line 9 carries `# high: GENERATES_CODE` instead of `# xhigh: GENERATES_CODE`.** Migration 029 installed the `{effort}: {TOKEN}` justification-comment invariant. Migration 044 bumped `effort: high` → `effort: xhigh` across agents and (where adjacent) rewrote the justification comment in the same pass. For `proj-code-writer-bash.md`, the adjacent-comment rewrite may not have landed on every client project — the migration 044 Python block uses a 3-line lookahead window, and hand-edited files (extra whitespace, added sections between effort and the comment) can fall outside that window. The result: the effort field is `xhigh` but the comment still says `# high:`. The `/audit-agents` A7 presence check validates the `# {effort}: <TOKEN>` invariant; a mismatch between `effort: xhigh` and `# high: <TOKEN>` fails A7 and signals false drift. Fix: rewrite the comment token to `# xhigh:` to restore the invariant.

## Rationale

1. **`UNKNOWN` is worse than `DRIFT`.** `DRIFT` tells you there is a problem to fix. `UNKNOWN` tells you the audit could not evaluate the row — the agent may be running on the correct model, or it may be running on a wrong model, and you cannot tell. Restoring the explicit `model:` field converts `UNKNOWN` → `COMPLIANT` / `DRIFT`, restoring the audit signal.
2. **`{effort}: {TOKEN}` invariant is an audit contract.** Migration 029 installed the invariant explicitly so `/audit-agents` could detect agents bumped to new effort tiers without their justification comments being updated in sync. The invariant is not cosmetic — it is the structural hook the audit uses to validate that effort tier matches the declared rationale class.
3. **Three-tier baseline-sentinel detection preserves customizations.** Both edits are destructive line replaces per `.claude/rules/general.md` Migration Preservation Discipline. Each step implements: (a) post-046 idempotency sentinel present → SKIP already patched; (b) pre-046 baseline sentinel present (stock pre-migration content) → safe PATCH; (c) neither present → file was hand-edited post-bootstrap → `SKIP_HAND_EDITED` + `.bak-046` backup + pointer to `## Manual-Apply-Guide`. Blind overwrite of customized content is structurally prevented.
4. **No agent-design.md technique sync needed.** This migration does not change doctrine — it only applies missing field/comment corrections to deployed agents. The bootstrap templates (`templates/agents/proj-code-reviewer.md`, `templates/agents/proj-code-writer-bash.md`) already carry the correct state. Migration 044 shipped the updated `techniques/agent-design.md` already.

---

## Changes

1. **Step 1** — `.claude/agents/proj-code-reviewer.md`: insert `model: sonnet` line into the YAML frontmatter block (immediately before `effort: xhigh` or `effort: high` — placement is idempotent within the frontmatter). Marker: presence of `^model: sonnet$` line inside the frontmatter block.
2. **Step 2** — `.claude/agents/proj-code-writer-bash.md`: replace `^# high: GENERATES_CODE$` with `^# xhigh: GENERATES_CODE$`. Marker: presence of `^# xhigh: GENERATES_CODE$` inside the frontmatter block.
3. **Step 3** — Advance `.claude/bootstrap-state.json` → `last_migration: "046"` + append to `applied[]`.

Idempotent: re-run detects both sentinels and prints `SKIP: already patched` per file.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: no .claude/agents directory"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Patch `.claude/agents/proj-code-reviewer.md` (add `model: sonnet` to frontmatter)

Read-before-write with three-tier baseline-sentinel detection.

- **(a)** idempotency sentinel — `^model: sonnet$` line present inside the frontmatter block → `SKIP: already patched`.
- **(b)** baseline sentinel — file exists + YAML frontmatter parses + `model:` key absent from frontmatter → safe PATCH: insert `model: sonnet` line immediately before the `effort:` line inside the frontmatter block. Write `.bak-046` backup first.
- **(c)** file missing OR frontmatter absent OR both sentinels absent → `SKIP_HAND_EDITED` + `.bak-046` backup + pointer to `## Manual-Apply-Guide §Step-1`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, shutil, sys, re

path = ".claude/agents/proj-code-reviewer.md"

if not os.path.exists(path):
    print(f"SKIP: {path} not present — agent not installed in this project")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Split into frontmatter block + body.
# Frontmatter is delimited by opening '---\n' at start (or after initial blank) and closing '---\n'.
parts = content.split("---\n", 2)
if len(parts) < 3:
    # No frontmatter block recognized.
    backup = path + ".bak-046"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"BACKUP: wrote {backup}")
    print(f"SKIP_HAND_EDITED: {path} — no YAML frontmatter block recognized (expected '---' fence at top).")
    print("See '## Manual-Apply-Guide' § Step-1 in migrations/046-drift-fixes.md for manual insertion instructions.")
    sys.exit(0)

prefix, frontmatter, body = parts[0], parts[1], parts[2]

# Tier (a) — idempotency: model: sonnet already present on its own line in frontmatter.
if re.search(r'(?m)^model:\s*sonnet\s*$', frontmatter):
    print(f"SKIP: {path} already patched (model: sonnet present in frontmatter)")
    sys.exit(0)

# Tier (b) — baseline: model: key entirely absent from frontmatter.
if re.search(r'(?m)^model:\s*\S', frontmatter):
    # model: key present but not 'sonnet' — this is a hand-edit (different model value).
    backup = path + ".bak-046"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"BACKUP: wrote {backup}")
    print(f"SKIP_HAND_EDITED: {path} — model: field present but not 'sonnet' (likely customized).")
    print("See '## Manual-Apply-Guide' § Step-1 in migrations/046-drift-fixes.md for manual merge instructions.")
    sys.exit(0)

# Baseline matched: model: key is absent. Insert 'model: sonnet' immediately before the 'effort:' line.
# Safe PATCH path.
backup = path + ".bak-046"
if not os.path.exists(backup):
    shutil.copy2(path, backup)
    print(f"BACKUP: wrote {backup}")

effort_match = re.search(r'(?m)^(effort:\s*\S.*)$', frontmatter)
if effort_match:
    # Insert 'model: sonnet\n' immediately before the effort: line.
    insert_pos = effort_match.start()
    new_frontmatter = frontmatter[:insert_pos] + "model: sonnet\n" + frontmatter[insert_pos:]
else:
    # No effort: line found — append model: sonnet at end of frontmatter.
    if not frontmatter.endswith("\n"):
        frontmatter += "\n"
    new_frontmatter = frontmatter + "model: sonnet\n"

new_content = prefix + "---\n" + new_frontmatter + "---\n" + body

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"PATCHED: {path} (inserted 'model: sonnet' into frontmatter)")
PY
```

### Step 2 — Patch `.claude/agents/proj-code-writer-bash.md` (rewrite `# high:` → `# xhigh:`)

Read-before-write with three-tier baseline-sentinel detection.

- **(a)** idempotency sentinel — `^# xhigh: GENERATES_CODE$` line present → `SKIP: already patched`.
- **(b)** baseline sentinel — `^# high: GENERATES_CODE$` line present (stock pre-046 content) → safe PATCH: replace that exact line with `# xhigh: GENERATES_CODE`. Write `.bak-046` backup first.
- **(c)** neither sentinel present → `SKIP_HAND_EDITED` + `.bak-046` backup + pointer to `## Manual-Apply-Guide §Step-2`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, shutil, sys

path = ".claude/agents/proj-code-writer-bash.md"

if not os.path.exists(path):
    print(f"SKIP: {path} not present — agent not installed in this project")
    sys.exit(0)

idempotency_sentinel = "# xhigh: GENERATES_CODE"
baseline_sentinel = "# high: GENERATES_CODE"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Tier (a) — idempotency: '# xhigh: GENERATES_CODE' substring present.
if idempotency_sentinel in content:
    print(f"SKIP: {path} already patched (# xhigh: GENERATES_CODE present)")
    sys.exit(0)

# Tier (b) — baseline: '# high: GENERATES_CODE' substring present (pre-046 content).
if baseline_sentinel in content:
    backup = path + ".bak-046"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"BACKUP: wrote {backup}")

    patched = content.replace(baseline_sentinel, idempotency_sentinel, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(patched)
    print(f"PATCHED: {path} (# high: GENERATES_CODE -> # xhigh: GENERATES_CODE)")
    sys.exit(0)

# Tier (c) — neither sentinel: hand-edited.
backup = path + ".bak-046"
if not os.path.exists(backup):
    shutil.copy2(path, backup)
    print(f"BACKUP: wrote {backup}")

print(f"SKIP_HAND_EDITED: {path} — neither idempotency sentinel nor baseline sentinel present.")
print("This file was customized post-bootstrap. Automatic patching would lose your changes.")
print("See '## Manual-Apply-Guide' § Step-2 in migrations/046-drift-fixes.md for merge instructions.")
sys.exit(0)
PY
```

### Step 3 — Update `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '046'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '046') or a == '046' for a in applied):
    applied.append({
        'id': '046',
        'applied_at': state['last_applied'],
        'description': 'Drift fixes — add model: sonnet to proj-code-reviewer frontmatter (restores /audit-model-usage COMPLIANT signal) and rewrite # high: -> # xhigh: classification comment on proj-code-writer-bash (restores migration 029 justification-comment invariant after migration 044 adoption gap).'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=046')
PY
```

### Rules for migration scripts

- **Read-before-write** — each patch step reads the target file, detects sentinels in tiered order, and only writes on the safe-patch tier. Destructive edits always write `.bak-046` backup first.
- **Idempotent** — re-running prints `SKIP: already patched` per file on each step.
- **Self-contained** — all logic inlined via python3 heredocs; no external fetch.
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on unrecoverable errors.
- **Scope lock** — touches only: `.claude/agents/proj-code-reviewer.md`, `.claude/agents/proj-code-writer-bash.md`, `.claude/bootstrap-state.json`. No hook changes, no settings edits, no skill edits, no technique sync. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. proj-code-reviewer.md carries `model: sonnet` in frontmatter (or file is absent)
if [[ -f .claude/agents/proj-code-reviewer.md ]]; then
  if grep -qE '^model:\s*sonnet\s*$' .claude/agents/proj-code-reviewer.md; then
    echo "PASS: proj-code-reviewer.md carries 'model: sonnet'"
  else
    echo "FAIL: proj-code-reviewer.md missing 'model: sonnet' in frontmatter"
    fail=1
  fi
else
  echo "INFO: .claude/agents/proj-code-reviewer.md not present — skipping check"
fi

# 2. proj-code-reviewer.md frontmatter still parses as valid YAML
if [[ -f .claude/agents/proj-code-reviewer.md ]]; then
  if python3 -c "
import sys, yaml
with open('.claude/agents/proj-code-reviewer.md') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
    echo "PASS: proj-code-reviewer.md YAML frontmatter parses"
  else
    echo "FAIL: proj-code-reviewer.md YAML frontmatter invalid after patch"
    fail=1
  fi
fi

# 3. proj-code-writer-bash.md carries `# xhigh: GENERATES_CODE` (not `# high:` — which is the pre-046 state)
if [[ -f .claude/agents/proj-code-writer-bash.md ]]; then
  if grep -qF '# xhigh: GENERATES_CODE' .claude/agents/proj-code-writer-bash.md; then
    echo "PASS: proj-code-writer-bash.md carries '# xhigh: GENERATES_CODE'"
  else
    echo "FAIL: proj-code-writer-bash.md missing '# xhigh: GENERATES_CODE'"
    fail=1
  fi

  # 4. No orphan `# high: GENERATES_CODE` remains (would indicate Step 2 did not apply)
  if grep -qF '# high: GENERATES_CODE' .claude/agents/proj-code-writer-bash.md; then
    echo "FAIL: proj-code-writer-bash.md still carries '# high: GENERATES_CODE' — Step 2 did not apply"
    fail=1
  else
    echo "PASS: proj-code-writer-bash.md no longer carries '# high: GENERATES_CODE'"
  fi
else
  echo "INFO: .claude/agents/proj-code-writer-bash.md not present — skipping check"
fi

# 5. proj-code-writer-bash.md frontmatter still parses as valid YAML
if [[ -f .claude/agents/proj-code-writer-bash.md ]]; then
  if python3 -c "
import sys, yaml
with open('.claude/agents/proj-code-writer-bash.md') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
    echo "PASS: proj-code-writer-bash.md YAML frontmatter parses"
  else
    echo "FAIL: proj-code-writer-bash.md YAML frontmatter invalid after patch"
    fail=1
  fi
fi

# 6. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "046" ]]; then
  echo "PASS: last_migration = 046"
else
  echo "FAIL: last_migration = $last (expected 046)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 046 verification: ALL PASS"
  echo ""
  echo "Optional cleanup: remove .bak-046 backups once you've confirmed patches are correct:"
  echo "  find .claude/agents -name '*.bak-046' -delete"
else
  echo "Migration 046 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"046"`
- append `{ "id": "046", "applied_at": "<ISO8601>", "description": "Drift fixes — add model: sonnet to proj-code-reviewer frontmatter (restores /audit-model-usage COMPLIANT signal) and rewrite # high: -> # xhigh: classification comment on proj-code-writer-bash (restores migration 029 justification-comment invariant after migration 044 adoption gap)." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Step 1 — `^model: sonnet$` already present in frontmatter → SKIP
- Step 2 — `# xhigh: GENERATES_CODE` already present → SKIP
- Step 3 — `applied[]` dedup check (migration id == `'046'`) → no duplicate append

No backups are rewritten on re-run. Files that were SKIP_HAND_EDITED on first apply remain SKIP_HAND_EDITED on re-run (both sentinels absent) — manual merge is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-046 backups (written by the migration itself)
for bak in .claude/agents/proj-code-reviewer.md.bak-046 .claude/agents/proj-code-writer-bash.md.bak-046; do
  [[ -f "$bak" ]] || continue
  orig="${bak%.bak-046}"
  mv "$bak" "$orig"
  echo "Restored: $orig"
done

# Option B — tracked strategy (if .claude/ is committed to project repo)
# git checkout -- .claude/agents/proj-code-reviewer.md .claude/agents/proj-code-writer-bash.md

# Option C — companion strategy (restore from companion repo snapshot)
# cp ~/.claude-configs/<project>/.claude/agents/proj-code-reviewer.md ./.claude/agents/
# cp ~/.claude-configs/<project>/.claude/agents/proj-code-writer-bash.md ./.claude/agents/

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '046':
    state['last_migration'] = '045'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '046') or a == '046'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=045')
PY
```

Rollback via `.bak-046` is safe because the migration writes the backup before any destructive edit. If no backup exists, the file was either SKIP_ALREADY (nothing to roll back) or SKIP_HAND_EDITED (nothing was written, so nothing to roll back).

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. The bootstrap templates (`templates/agents/proj-code-reviewer.md`, `templates/agents/proj-code-writer-bash.md`) already carry the correct state — `templates/agents/proj-code-reviewer.md` has `model: sonnet` at line 8, and `templates/agents/proj-code-writer-bash.md` has `# xhigh: GENERATES_CODE` at line 9. No template edit is needed; this migration exists only to propagate the fixes to already-bootstrapped client projects whose `.claude/agents/` drifted.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Manual-Apply-Guide

When Step 1 or Step 2 reports `SKIP_HAND_EDITED: <path>`, the migration detected that the target file's frontmatter was customized post-bootstrap (baseline sentinel absent + post-migration sentinel absent). Automatic patching is unsafe — the migration does not know whether the customization is deliberate. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the drift fixes while preserving your customizations.

---

### §Step-1 — Insert `model: sonnet` into `.claude/agents/proj-code-reviewer.md` frontmatter

**Target**: `.claude/agents/proj-code-reviewer.md` — YAML frontmatter block (between the two `---` fence lines at the top of the file).

**New content (verbatim — add this line to the frontmatter block, anywhere between the opening and closing `---`)**:

```yaml
model: sonnet
```

**Recommended placement**: immediately before the `effort:` line, so the frontmatter reads in canonical order:

```yaml
name: proj-code-reviewer
description: >
  <existing description preserved>
model: sonnet
effort: xhigh
# xhigh: SUBTLE_ERROR_RISK + STATEFUL_MEMORY
<remaining frontmatter preserved>
```

**Merge instructions**:

1. **Locate your customized frontmatter.** Open `.claude/agents/proj-code-reviewer.md` and find the YAML frontmatter block (delimited by two `---` fence lines at the top of the file).
2. **Check whether `model:` is already present.**
   - If `model: sonnet` is already present: this migration step is a no-op for your file. No action needed.
   - If `model: <other-value>` is present (e.g., `model: opus`, `model: haiku`): this is a deliberate customization. Do NOT change it unless you want to conform to the `.claude/rules/model-selection.md` policy (which expects `sonnet` for `proj-code-reviewer`). If you do want to conform, change the line to `model: sonnet`.
   - If the `model:` key is absent entirely: add a new line `model: sonnet` inside the frontmatter block. Canonical placement is immediately before the `effort:` line.
3. **Save the file.**
4. **Rerun the migration.** After your manual merge, the file now contains the idempotency sentinel (`^model: sonnet$` on its own line inside the frontmatter). Rerunning `/migrate-bootstrap` will detect the sentinel in Step 1 and print `SKIP: already patched`, then proceed to Step 2. This completes the migration cleanly.
5. **Restore the backup only if needed.** If you want to abandon the manual merge and inspect the original, the migration wrote `.claude/agents/proj-code-reviewer.md.bak-046` on first SKIP_HAND_EDITED encounter (or on any destructive PATCH). `cp .claude/agents/proj-code-reviewer.md.bak-046 .claude/agents/proj-code-reviewer.md` restores pre-migration state.

**Verification**:

```bash
python3 -c "import yaml; yaml.safe_load(open('.claude/agents/proj-code-reviewer.md').read().split('---')[1]); print('OK')"
grep -E '^model:' .claude/agents/proj-code-reviewer.md
# Expected output:
#   OK
#   model: sonnet
```

---

### §Step-2 — Rewrite `# high: GENERATES_CODE` → `# xhigh: GENERATES_CODE` in `.claude/agents/proj-code-writer-bash.md`

**Target**: `.claude/agents/proj-code-writer-bash.md` — justification comment line inside the YAML frontmatter block, adjacent to the `effort:` line.

**New content (verbatim — replace the existing `# high: GENERATES_CODE` line)**:

```
# xhigh: GENERATES_CODE
```

**Context (showing surrounding lines)**:

```yaml
model: sonnet
effort: xhigh
# xhigh: GENERATES_CODE
maxTurns: 100
```

**Merge instructions**:

1. **Locate your customized frontmatter.** Open `.claude/agents/proj-code-writer-bash.md` and find the YAML frontmatter block.
2. **Check the justification comment line.** Look for a line starting with `# high:` or `# xhigh:` (typically immediately after `effort:`).
   - If `# xhigh: <TOKEN>` is already present: this migration step is a no-op. No action needed.
   - If `# high: <TOKEN>` is present (any token — `GENERATES_CODE`, `SUBTLE_ERROR_RISK`, etc.): rewrite the `# high:` prefix to `# xhigh:`. Keep the token unchanged. For the stock `proj-code-writer-bash` agent, the token is `GENERATES_CODE`.
   - If neither `# high:` nor `# xhigh:` is present: the justification comment was removed during customization. Add `# xhigh: GENERATES_CODE` immediately after the `effort: xhigh` line. Per migration 029, the `{effort}: {TOKEN}` invariant is required for `/audit-agents` A7 to pass.
3. **Check the effort field is `xhigh`.** The justification comment must agree with the effort value. If `effort:` is `high` (not `xhigh`), apply migration 044 first — that migration bumps `effort: high` → `effort: xhigh` and (when the adjacent-comment rewrite lands) the `# high:` comment in the same pass. Migration 046 assumes 044 has landed.
4. **Save the file.**
5. **Rerun the migration.** After your manual merge, the file contains the idempotency sentinel (`# xhigh: GENERATES_CODE`). Rerunning `/migrate-bootstrap` will detect the sentinel in Step 2 and print `SKIP: already patched`, then proceed to Step 3. This completes the migration cleanly.
6. **Restore the backup only if needed.** `cp .claude/agents/proj-code-writer-bash.md.bak-046 .claude/agents/proj-code-writer-bash.md` restores pre-migration state if the migration wrote a backup.

**Verification**:

```bash
python3 -c "import yaml; yaml.safe_load(open('.claude/agents/proj-code-writer-bash.md').read().split('---')[1]); print('OK')"
grep -F '# xhigh: GENERATES_CODE' .claude/agents/proj-code-writer-bash.md
# Expected output:
#   OK
#   # xhigh: GENERATES_CODE
```

---

### Why this matters

`/audit-model-usage` (installed migration 030) is an auto-run discipline skill that reports COMPLIANT / DRIFT / UNKNOWN per agent against `.claude/rules/model-selection.md`. An `UNKNOWN` row is worse than a `DRIFT` row — `UNKNOWN` means the audit could not evaluate, so any actual drift stays hidden. Step 1 restores the audit signal for `proj-code-reviewer`.

`/audit-agents` A7 presence check (installed migration 029) validates the `# {effort}: {TOKEN}` invariant. A mismatch between `effort: xhigh` and `# high: <TOKEN>` fails A7 and signals false drift. Step 2 restores the invariant for `proj-code-writer-bash`.

Both fixes are one-line edits, zero-regression, and structurally required for the audit pipeline to produce actionable signal rather than noise.
