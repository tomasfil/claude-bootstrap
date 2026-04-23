# Migration 048 — /write-plan Spec Schema Gate

<!-- migration-id: 048-spec-schema-gate -->

> Add a main-thread Spec Schema Gate to `/write-plan` (new Step 1.5 between Step 1 and Step 2) that validates the spec file has all 5 required `##` section headers before dispatching `proj-plan-writer`. Section headers are checked via word-boundary prefix match within the first 40 chars of each `##` line: required prefixes are `Problem`, `Constraints`, `Approach`, `Components`, `Open Questions`. Escape hatch: `--skip-schema-gate` passed as a SEPARATE arg (not merged with the spec path) bypasses the check. Also adds a soft pointer to the new schema rule in `/brainstorm` spec-writing step, creates the new rule file `.claude/rules/spec-schema.md` (synced from `templates/rules/spec-schema.md` in the bootstrap repo), and updates the `/write-plan` `argument-hint` frontmatter field. Four file edits: (a) destructive frontmatter field replace + additive Step 1.5 insert in `.claude/skills/write-plan/SKILL.md` (three-tier baseline-sentinel detection); (b) additive reference line append in `.claude/skills/brainstorm/SKILL.md` (sentinel-guarded); (c) create new rule file `.claude/rules/spec-schema.md` (additive — create-if-absent); (d) bootstrap-state.json advance. Step (a) ships with a `## Manual-Apply-Guide` providing the verbatim new-content blocks for the `SKIP_HAND_EDITED` fallback path.

---

## Metadata

```yaml
id: "048"
breaking: false
affects: [skills, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Pre-Ship Checklist

- [x] **OQ-deep-think-spec-spot-check** — verified `templates/skills/deep-think/SKILL.md` Phase 6 `spec.md` output template uses all 5 required section headers in compatible form: `## Problem / Goal` (prefix `Problem` ✓), `## Constraints` (prefix `Constraints` ✓), `## Approach (approved)` (prefix `Approach` ✓), `## Components (files, interfaces, data flow)` (prefix `Components` ✓), `## Open Questions` (prefix `Open Questions` ✓). All 5 prefix checks PASS on stock deep-think output. Schema gate will not block specs authored via `/deep-think`.
- [x] **OQ-brainstorm-spec-spot-check** — verified `templates/skills/brainstorm/SKILL.md` `### Spec Output Format` uses the same 5 headers with prefix-compatible forms. Stock brainstorm output passes the schema gate unchanged.

---

## Problem

The `/write-plan` skill dispatches `proj-plan-writer` against whatever spec file the user passes — no structural validation of the spec's section-header shape. When a spec lacks required sections (missing `## Components`, missing `## Open Questions`, etc.), `proj-plan-writer` proceeds with a half-specified input and emits a plan that reflects that partial understanding: missing batches for components the spec did not enumerate, no triaged open-questions handoff to `/execute-plan`, no coverage against `open-questions-discipline.md` §Orchestrator Obligation.

Two failure modes compound:

1. **Silent partial-spec plans** — plan-writer produces a syntactically valid but semantically incomplete plan because it has no upstream signal that the spec was missing sections. The user only discovers the gap after plan review or during execution, by which point the cost of re-planning is ~5–10 agent dispatches deep.

2. **No canonical schema definition** — there is no single rule file defining "what a valid spec looks like". The 5-section shape is an emergent convention from `/brainstorm` and `/deep-think` output templates, but it is never stated as a rule. `/write-plan` cannot reference a schema it does not have. The spec shape drifts silently across manually-authored specs.

Fix: install a lightweight main-thread gate in `/write-plan` that runs BEFORE the plan-writer dispatch. Word-boundary prefix match on `##` section headers: required prefixes are `Problem`, `Constraints`, `Approach`, `Components`, `Open Questions`. Match window is the first 40 chars of each `##` line, case-sensitive first-word after `## `. Any missing prefix → BLOCK with a list of missing sections plus a pointer to the canonical schema rule. `--skip-schema-gate` as a separate arg bypasses the check for intentionally-partial specs (exploratory scratch, mid-refinement specs).

Paired with the new rule file `.claude/rules/spec-schema.md` (synced from `templates/rules/spec-schema.md`) that defines the prefix-match semantics, PASS/FAIL examples, and the escape-hatch flag. The rule file is the single source of truth for the schema definition — both the `/write-plan` gate and the `/brainstorm` spec-writing step point to it.

---

## Rationale

1. **Upstream gate > downstream detection.** Catching a missing `## Components` section at the `/write-plan` main-thread gate (zero dispatch cost) is structurally cheaper than catching it during plan review (one `proj-plan-writer` dispatch) or during execution (multiple `proj-code-writer-{lang}` dispatches). The gate converts a late-stage semantic failure into an early-stage structural failure with a precise fix ("add these sections to the spec").

2. **Word-boundary prefix match is the right precision.** Exact-string matching on full section names (`## Problem / Goal`, `## Problem Statement`) would force brainstorm + deep-think + manual specs to all emit identical header strings — false negatives on valid variants. Substring matching (`grep Problem`) would match unrelated prose (`## Known Problems`). First-word prefix match within the first 40 chars case-sensitive hits the sweet spot: flexible enough for `## Problem / Goal` and `## Problem Statement` to both pass, strict enough that `## The Problem` (first word `The`) and `## problems` (lowercase) fail. The shell check is one `grep -m1 "^## <prefix>"` per prefix — trivial to implement, trivial to audit.

3. **Escape hatch is a SEPARATE arg by design.** Merging `--skip-schema-gate` with the spec path (e.g., `spec.md --skip-schema-gate`) would make the arg order-dependent and hide the flag inside the primary arg. Separating them makes the bypass explicit: `/write-plan spec.md --skip-schema-gate` is unambiguous, the flag is visible at dispatch time, and the skill body can parse args with a simple `if "--skip-schema-gate" in args` check.

4. **`/brainstorm` soft pointer, not enforcement.** The brainstorm skill-writing step already produces spec files in the 5-section format — adding a schema reference is a soft pointer (one sentence), not an enforcement gate. Hard enforcement in brainstorm would duplicate the `/write-plan` gate without adding signal; the soft pointer just makes the requirement explicit at the authoring site.

5. **Three-tier baseline-sentinel detection preserves customizations.** Step (a) is a destructive frontmatter-field replace + additive Step 1.5 insert in `.claude/skills/write-plan/SKILL.md`. Per `.claude/rules/general.md` Migration Preservation Discipline, the destructive portion (frontmatter field replace) uses three-tier detection: idempotency sentinel (post-048 marker present → SKIP) → baseline sentinel (stock pre-048 content → safe PATCH) → hand-edited (neither sentinel → SKIP_HAND_EDITED + `.bak-048` backup + pointer to `## Manual-Apply-Guide`). The additive Step 1.5 insert is sentinel-guarded: `Step 1.5` or `Spec Schema Gate` substring present → SKIP. Step (b) `/brainstorm` reference is additive + sentinel-guarded. Step (c) creates a new rule file — the "destination file absent → create; present → respect existing content" pattern applies, no three-tier needed for pure creation.

6. **No technique sync needed.** This migration does not touch any `techniques/` file — only creates a new rule file and patches two skill bodies. No `.claude/references/techniques/` sync step per `.claude/rules/general.md` Migrations rule (technique changes would require sync, rule + skill changes do not).

---

## Changes

| File | Change |
|---|---|
| `.claude/skills/write-plan/SKILL.md` | DESTRUCTIVE `argument-hint` frontmatter field replace: `"[spec-file-path]"` → `"[spec-file-path] [--skip-schema-gate]"` (three-tier baseline-sentinel). ADDITIVE Step 1.5 insert: new Spec Schema Gate section inserted between Step 1 and Step 2 in the `### Steps` block (sentinel-guarded on `Step 1.5` / `Spec Schema Gate` substring). |
| `.claude/skills/brainstorm/SKILL.md` | ADDITIVE: append reference to `spec-schema` rule in the spec-writing step (Step 5 in the Full Exploration Flow). Sentinel-guarded on `spec-schema` substring. |
| `.claude/rules/spec-schema.md` | NEW FILE: canonical schema definition (5 required section prefixes, prefix-match semantics, PASS/FAIL examples, escape-hatch pointer). Additive — create-if-absent; existing file with sentinel line → SKIP. |
| `.claude/bootstrap-state.json` | Advance `last_migration` → `"048"` + append `048` entry to `applied[]`. |

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f ".claude/skills/write-plan/SKILL.md" ]] || { echo "ERROR: .claude/skills/write-plan/SKILL.md missing — run full bootstrap first"; exit 1; }
[[ -f ".claude/skills/brainstorm/SKILL.md" ]] || { echo "ERROR: .claude/skills/brainstorm/SKILL.md missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/rules" ]] || { echo "ERROR: .claude/rules directory missing — run full bootstrap first"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Patch `.claude/skills/write-plan/SKILL.md` (frontmatter replace + Step 1.5 insert)

Combined step: (1a) destructive `argument-hint` frontmatter field replace (three-tier detection); (1b) additive Step 1.5 insert between Step 1 and Step 2 (sentinel-guarded). Both sub-steps operate on the same file — single Python block handles both.

**Step 1a — `argument-hint` frontmatter field replace (three-tier):**

- **(a)** idempotency sentinel — `argument-hint: "[spec-file-path] [--skip-schema-gate]"` line present → SKIP this sub-step.
- **(b)** baseline sentinel — `argument-hint: "[spec-file-path]"` exact-line present (stock pre-048 content) → safe PATCH: replace in full with the post-048 form.
- **(c)** neither — file was hand-edited post-bootstrap → `SKIP_HAND_EDITED` + `.bak-048` backup + pointer to `## Manual-Apply-Guide § Step-1a`.

**Step 1b — Step 1.5 Spec Schema Gate insert (additive, sentinel-guarded):**

- **(a)** idempotency sentinel — `Step 1.5` substring OR `Spec Schema Gate` substring present anywhere in the file → SKIP this sub-step.
- **(b)** baseline sentinel — the line `1. Read spec from \`.claude/specs/{branch}/\` | conversation context` present followed by `2. Read \`.claude/skills/code-write/references/pipeline-traces.md\` (if exists)` as the immediate next enumerated item → safe INSERT: put the new Step 1.5 block between them.
- **(c)** neither — anchors missing → `SKIP_HAND_EDITED` + pointer to `## Manual-Apply-Guide § Step-1b` (no additional backup — the `.bak-048` from 1a covers it).

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, shutil, sys

path = ".claude/skills/write-plan/SKILL.md"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

original_content = content

# ----- Step 1a: argument-hint frontmatter field replace (three-tier) -----
arg_hint_idempotency = 'argument-hint: "[spec-file-path] [--skip-schema-gate]"'
arg_hint_baseline = 'argument-hint: "[spec-file-path]"'

step1a_status = None
if arg_hint_idempotency in content:
    step1a_status = "SKIP_ALREADY_APPLIED"
elif arg_hint_baseline in content:
    # Safe PATCH — write backup before any destructive edit.
    backup = path + ".bak-048"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"BACKUP: wrote {backup}")
    content = content.replace(arg_hint_baseline, arg_hint_idempotency, 1)
    step1a_status = "PATCHED"
else:
    step1a_status = "SKIP_HAND_EDITED"

# ----- Step 1b: Step 1.5 Spec Schema Gate insert (additive, sentinel-guarded) -----
step1_5_idempotency_a = "Step 1.5"
step1_5_idempotency_b = "Spec Schema Gate"

step1_5_baseline_line1 = "1. Read spec from `.claude/specs/{branch}/` | conversation context"
step1_5_baseline_line2 = "2. Read `.claude/skills/code-write/references/pipeline-traces.md` (if exists)"

step1_5_block = """1.5 **Spec Schema Gate** (runs on main thread before dispatching plan-writer):
    Parse `--skip-schema-gate` from args → if present, skip this step entirely and log "Spec schema gate bypassed by --skip-schema-gate flag".
    Otherwise, check spec file `##` section headers (word-boundary prefix match within first 40 chars of each `##` line).
    Required prefixes: `## Problem`, `## Constraints`, `## Approach`, `## Components`, `## Open Questions`
    Shell equivalent — per required prefix: `grep -m1 "^## <prefix>" <spec-file>` (non-zero exit = missing).
    All 5 found → PASS, continue to Step 2.
    Any missing → BLOCK with: "Spec schema validation failed. Missing sections: {comma-separated list of missing prefixes}. Fix the spec to include the missing section headers, or pass `--skip-schema-gate` as a separate arg to bypass. See `.claude/rules/spec-schema.md` (or `templates/rules/spec-schema.md` in the bootstrap repo) for the full schema definition and examples."
    Do NOT dispatch `proj-plan-writer` when blocked — return the block message to the user and stop.
"""

step1b_status = None
if step1_5_idempotency_a in content or step1_5_idempotency_b in content:
    step1b_status = "SKIP_ALREADY_APPLIED"
elif step1_5_baseline_line1 in content and step1_5_baseline_line2 in content:
    # Safe INSERT — make sure we have a backup (may already exist from Step 1a).
    backup = path + ".bak-048"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"BACKUP: wrote {backup}")
    # Replace the two-line sequence with line1 + Step 1.5 block + line2.
    old_sequence = step1_5_baseline_line1 + "\n" + step1_5_baseline_line2
    new_sequence = step1_5_baseline_line1 + "\n" + step1_5_block + step1_5_baseline_line2
    if old_sequence in content:
        content = content.replace(old_sequence, new_sequence, 1)
        step1b_status = "PATCHED"
    else:
        # Both lines present but not adjacent — hand-edited structure.
        step1b_status = "SKIP_HAND_EDITED"
else:
    step1b_status = "SKIP_HAND_EDITED"

# ----- Write if any change applied -----
if content != original_content:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

# ----- Report status -----
print(f"Step 1a (argument-hint): {step1a_status}")
print(f"Step 1b (Step 1.5 insert): {step1b_status}")

if step1a_status == "SKIP_HAND_EDITED" or step1b_status == "SKIP_HAND_EDITED":
    # Ensure backup exists on hand-edited path.
    backup = path + ".bak-048"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print(f"BACKUP: wrote {backup}")
    print(f"HAND-EDITED: {path} — one or both sub-steps could not apply automatically.")
    print("See '## Manual-Apply-Guide' in migrations/048-spec-schema-gate.md for verbatim")
    print("new-content blocks + merge instructions. After manual merge, rerun this migration")
    print("to advance state.")
PY
```

### Step 2 — Patch `.claude/skills/brainstorm/SKILL.md` (additive spec-schema reference)

Additive append — idempotency-guarded on `spec-schema` substring.

- **(a)** idempotency sentinel — `spec-schema` substring already present → SKIP.
- **(b)** else — locate the Full Exploration Flow Step 5 (spec save line) and extend it with the spec-schema reference. Fail loudly with a hand-patch block if the anchor is missing.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/skills/brainstorm/SKILL.md"

if not os.path.exists(path):
    print(f"SKIP: {path} not present — skill not installed in this project")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Tier (a) — idempotency
if "spec-schema" in content:
    print(f"SKIP: {path} already contains spec-schema reference")
    sys.exit(0)

# Anchor: the baseline spec-save line in Full Exploration Flow Step 5.
baseline_line = "5. Save spec → `.claude/specs/{branch}/{date}-{topic}-spec.md`. Specs use compressed telegraphic notation"
replacement_line = (
    "5. Save spec → `.claude/specs/{branch}/{date}-{topic}-spec.md`. Specs use compressed telegraphic notation. "
    "Spec output MUST use the 5-section schema from `templates/rules/spec-schema.md` (or `.claude/rules/spec-schema.md` in client projects): "
    "Problem/Goal, Constraints, Approach, Components, Open Questions. `/write-plan` Step 1.5 Spec Schema Gate enforces this at plan-write time"
)

if baseline_line not in content:
    print(f"FAIL: {path} missing Step 5 spec-save anchor — cannot insert spec-schema reference")
    print("Hand-patch required: locate the Full Exploration Flow Step 5 line in your customized file and extend it with:")
    print('---')
    print('Spec output MUST use the 5-section schema from `templates/rules/spec-schema.md` (or `.claude/rules/spec-schema.md` in client projects): '
          'Problem/Goal, Constraints, Approach, Components, Open Questions. `/write-plan` Step 1.5 Spec Schema Gate enforces this at plan-write time')
    print('---')
    sys.exit(1)

new_content = content.replace(baseline_line, replacement_line, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"PATCHED: {path} (spec-schema reference appended to Full Exploration Flow Step 5)")
PY
```

### Step 3 — Create `.claude/rules/spec-schema.md` (new file, additive)

Pure create pattern: if the file is absent → write canonical content; if present with the sentinel line → SKIP; if present without the sentinel (pre-existing hand-authored file with the same name) → SKIP_HAND_EDITED with pointer to `## Manual-Apply-Guide § Step-3`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/rules/spec-schema.md"
sentinel = "# Spec Schema"  # first line of canonical content

canonical_content = """# Spec Schema

## Rule
Every spec file consumed by `/write-plan` MUST carry all 5 required `##` section headers. Word-boundary prefix match within the first 40 chars of each `##` line. Missing section → plan-writer refuses dispatch unless `--skip-schema-gate` passed.

## Required Section Headers (prefix match)
- `## Problem` — maps to "Problem / Goal", "Problem Statement", etc.
- `## Constraints` — hard rules / budget / compatibility
- `## Approach` — chosen mechanism (may be "Approach (approved)")
- `## Components` — files / interfaces / data flow (may be "Components (files, interfaces, data flow)")
- `## Open Questions` — triaged per `open-questions-discipline.md`

## Prefix Match Definition
A `##` line matches a required prefix iff:
- Line starts with `## ` (two hashes + single space)
- First word after `## ` equals the required prefix (case-sensitive)
- Match window: first 40 chars of the line

Shell check: `grep -m1 "^## <prefix>" <spec-file>` per prefix — non-zero exit = missing section.

## Examples
PASS:
- `## Problem / Goal` — first word `Problem` matches
- `## Problem Statement` — first word `Problem` matches
- `## Approach (approved)` — first word `Approach` matches
- `## Components (files, interfaces, data flow)` — first word `Components` matches
- `## Open Questions` — first word `Open` matches full prefix `Open Questions`

FAIL:
- `## problems` — lowercase, case-sensitive mismatch
- `## The Problem` — first word `The`, not `Problem`
- `##Problem` — missing space after `##`
- `##  Problem` — double space after `##`
- `### Problem` — wrong heading level

## Enforcement
- `/write-plan` Step 1.5 Spec Schema Gate runs the 5 prefix checks before dispatching `proj-plan-writer`. Any missing → BLOCK with list of missing sections.
- Escape hatch: `--skip-schema-gate` flag passed as SEPARATE arg bypasses the check (use when spec intentionally partial, e.g., exploratory scratch).
- `/brainstorm` + `/deep-think` spec output templates already conform; re-running the schema gate on their output = no-op PASS.

---

# Canonical Spec Skeleton (reference — these are the exact `##` headings a valid spec MUST carry)

The remaining `##`-level headings in this file (below) are NOT rule sections; they are the literal headings every spec must include (or a prefix-compatible variant of each). Do not edit.

## Problem

Placeholder. In a real spec, this section states the problem or goal. Variant forms accepted by the gate: `## Problem / Goal`, `## Problem Statement`.

## Constraints

Placeholder. In a real spec, this section enumerates hard constraints: budget, compatibility, non-goals, rule conformance requirements.

## Approach

Placeholder. In a real spec, this section describes the chosen mechanism. Variant forms accepted by the gate: `## Approach (approved)`.

## Components

Placeholder. In a real spec, this section lists files, interfaces, data flow. Variant forms accepted by the gate: `## Components (files, interfaces, data flow)`.

## Open Questions

Placeholder. In a real spec, this section carries triaged open questions per `open-questions-discipline.md` (USER_DECIDES / AGENT_RECOMMENDS / AGENT_DECIDED).
"""

if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as f:
        existing = f.read()
    if sentinel in existing:
        print(f"SKIP: {path} already present (sentinel '{sentinel}' matched)")
        sys.exit(0)
    # File present but sentinel absent — hand-authored file with colliding name.
    print(f"SKIP_HAND_EDITED: {path} exists but does not carry the '{sentinel}' sentinel.")
    print("This file was hand-authored or derived from a different source. Automatic write would overwrite it.")
    print("See '## Manual-Apply-Guide' § Step-3 in migrations/048-spec-schema-gate.md for merge instructions.")
    sys.exit(0)

# Ensure parent directory exists.
os.makedirs(os.path.dirname(path), exist_ok=True)

with open(path, "w", encoding="utf-8") as f:
    f.write(canonical_content)

print(f"CREATED: {path} (canonical spec-schema rule written)")
PY
```

### Step 4 — Update `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '048'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '048') or a == '048' for a in applied):
    applied.append({
        'id': '048',
        'applied_at': state['last_applied'],
        'description': 'Add spec schema gate to /write-plan (Step 1.5): validates spec file has 5 required sections (Problem/Goal, Constraints, Approach, Components, Open Questions) before dispatching plan-writer. Escape hatch: --skip-schema-gate. Creates .claude/rules/spec-schema.md. Adds spec-schema reference to /brainstorm.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=048')
PY
```

### Rules for migration scripts

- **Read-before-write** — Step 1 combines a destructive frontmatter-field replace with three-tier detection and an additive Step 1.5 insert with sentinel guards; `.bak-048` backup written before any destructive edit. Steps 2 and 3 are additive — sentinel guards prevent duplicate insertion on re-run; Step 2 fails loudly with a verbatim hand-patch block when the anchor is missing; Step 3 skips cleanly if the file exists with a colliding name (pointer to Manual-Apply-Guide § Step-3).
- **Idempotent** — every step re-run detects its sentinel (`argument-hint: "[spec-file-path] [--skip-schema-gate]"` + `Spec Schema Gate` in Step 1; `spec-schema` substring in Step 2; sentinel line `# Spec Schema` in Step 3) and emits `SKIP: already patched` without writing.
- **Self-contained** — all logic inlined via python3 heredocs; no external fetch. Canonical rule-file content is embedded verbatim in Step 3.
- **Abort on error** — `set -euo pipefail` on every bash block. Step 2 exits non-zero on missing anchor (operator must hand-patch per the printed block). Steps 1 and 3 exit zero on SKIP_HAND_EDITED (operator merges per Manual-Apply-Guide then re-runs).
- **Scope lock** — touches only: `.claude/skills/write-plan/SKILL.md`, `.claude/skills/brainstorm/SKILL.md`, `.claude/rules/spec-schema.md`, `.claude/bootstrap-state.json`. No agent edits, no hook changes, no settings edits, no technique sync. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `agent-scope-lock.md`).
- **No technique sync** — this migration does not touch any `techniques/` file. Per `.claude/rules/general.md` Migrations rule, only technique changes require a `.claude/references/techniques/` sync step. Rule-file additions and skill-body patches do not.

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. write-plan/SKILL.md argument-hint updated to post-048 form
if grep -qF 'argument-hint: "[spec-file-path] [--skip-schema-gate]"' .claude/skills/write-plan/SKILL.md 2>/dev/null; then
  echo "PASS: write-plan/SKILL.md argument-hint updated to [--skip-schema-gate] form"
else
  echo "FAIL: write-plan/SKILL.md argument-hint not updated"
  fail=1
fi

# 2. write-plan/SKILL.md carries Step 1.5 Spec Schema Gate block
if grep -qF 'Step 1.5' .claude/skills/write-plan/SKILL.md 2>/dev/null || \
   grep -qF '1.5 **Spec Schema Gate**' .claude/skills/write-plan/SKILL.md 2>/dev/null; then
  echo "PASS: write-plan/SKILL.md carries Step 1.5 marker"
else
  echo "FAIL: write-plan/SKILL.md missing Step 1.5 Spec Schema Gate block"
  fail=1
fi
if grep -qF 'skip-schema-gate' .claude/skills/write-plan/SKILL.md 2>/dev/null; then
  echo "PASS: write-plan/SKILL.md Step 1.5 references --skip-schema-gate escape hatch"
else
  echo "FAIL: write-plan/SKILL.md Step 1.5 missing --skip-schema-gate reference"
  fail=1
fi
if grep -qF 'Spec schema validation failed' .claude/skills/write-plan/SKILL.md 2>/dev/null; then
  echo "PASS: write-plan/SKILL.md Step 1.5 carries BLOCK message template"
else
  echo "FAIL: write-plan/SKILL.md Step 1.5 missing BLOCK message template"
  fail=1
fi

# 3. write-plan/SKILL.md YAML frontmatter still parses
if python3 -c "
import sys, yaml
with open('.claude/skills/write-plan/SKILL.md') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
  echo "PASS: write-plan/SKILL.md YAML frontmatter parses"
else
  echo "FAIL: write-plan/SKILL.md YAML frontmatter invalid after patch"
  fail=1
fi

# 4. brainstorm/SKILL.md carries spec-schema reference
if grep -qF 'spec-schema' .claude/skills/brainstorm/SKILL.md 2>/dev/null; then
  echo "PASS: brainstorm/SKILL.md carries spec-schema reference"
else
  echo "FAIL: brainstorm/SKILL.md missing spec-schema reference"
  fail=1
fi

# 5. brainstorm/SKILL.md YAML frontmatter still parses
if python3 -c "
import sys, yaml
with open('.claude/skills/brainstorm/SKILL.md') as f:
    parts = f.read().split('---')
if len(parts) < 3:
    sys.exit(1)
yaml.safe_load(parts[1])
" 2>/dev/null; then
  echo "PASS: brainstorm/SKILL.md YAML frontmatter parses"
else
  echo "FAIL: brainstorm/SKILL.md YAML frontmatter invalid after patch"
  fail=1
fi

# 6. .claude/rules/spec-schema.md exists and carries the canonical sentinel
if [[ -f .claude/rules/spec-schema.md ]]; then
  echo "PASS: .claude/rules/spec-schema.md present"
  if head -n1 .claude/rules/spec-schema.md | grep -qF '# Spec Schema'; then
    echo "PASS: .claude/rules/spec-schema.md carries '# Spec Schema' sentinel on line 1"
  else
    echo "FAIL: .claude/rules/spec-schema.md line 1 does not carry '# Spec Schema' sentinel"
    fail=1
  fi
  # Check all 5 required sections are documented in the rule file itself
  for prefix in "Problem" "Constraints" "Approach" "Components" "Open Questions"; do
    if grep -qF "\`## $prefix\`" .claude/rules/spec-schema.md 2>/dev/null; then
      echo "PASS: .claude/rules/spec-schema.md documents '## $prefix' prefix"
    else
      echo "FAIL: .claude/rules/spec-schema.md missing documentation for '## $prefix' prefix"
      fail=1
    fi
  done
else
  echo "FAIL: .claude/rules/spec-schema.md not created"
  fail=1
fi

# 7. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "048" ]]; then
  echo "PASS: last_migration = 048"
else
  echo "FAIL: last_migration = $last (expected 048)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 048 verification: ALL PASS"
  echo ""
  echo "Optional cleanup: remove .bak-048 backups once you've confirmed the patches are correct:"
  echo "  find .claude/skills -name '*.bak-048' -delete"
else
  echo "Migration 048 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"048"`
- append `{ "id": "048", "applied_at": "<ISO8601>", "description": "Add spec schema gate to /write-plan (Step 1.5): validates spec file has 5 required sections (Problem/Goal, Constraints, Approach, Components, Open Questions) before dispatching plan-writer. Escape hatch: --skip-schema-gate. Creates .claude/rules/spec-schema.md. Adds spec-schema reference to /brainstorm." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Step 1a — `argument-hint: "[spec-file-path] [--skip-schema-gate]"` present → SKIP
- Step 1b — `Step 1.5` / `Spec Schema Gate` substring present → SKIP
- Step 2 — `spec-schema` substring present → SKIP
- Step 3 — `.claude/rules/spec-schema.md` present with `# Spec Schema` sentinel on line 1 → SKIP
- Step 4 — `applied[]` dedup check (migration id == `'048'`) → no duplicate append

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply (Step 1a or Step 1b) remain `SKIP_HAND_EDITED` on re-run (sentinel absent) — manual merge is still required per `## Manual-Apply-Guide`. A pre-existing hand-authored `.claude/rules/spec-schema.md` without the canonical sentinel remains untouched on re-run (operator merges canonical content per Manual-Apply-Guide § Step-3 or leaves as-is).

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-048 backup (written by Step 1 before any destructive edit)
if [[ -f .claude/skills/write-plan/SKILL.md.bak-048 ]]; then
  mv .claude/skills/write-plan/SKILL.md.bak-048 .claude/skills/write-plan/SKILL.md
  echo "Restored: .claude/skills/write-plan/SKILL.md from .bak-048"
fi

# Step 2 is additive — revert via git if tracked, or hand-strip the inserted sentence
git restore .claude/skills/brainstorm/SKILL.md 2>/dev/null || echo "WARN: .claude/skills/brainstorm/SKILL.md not git-tracked — hand-strip spec-schema sentence if needed"

# Step 3 is a new file — delete it to roll back
if [[ -f .claude/rules/spec-schema.md ]]; then
  # Only remove if it was created by this migration (sentinel on line 1 = canonical content)
  if head -n1 .claude/rules/spec-schema.md | grep -qF '# Spec Schema'; then
    rm .claude/rules/spec-schema.md
    echo "Removed: .claude/rules/spec-schema.md (created by migration 048)"
  else
    echo "WARN: .claude/rules/spec-schema.md present but sentinel absent — hand-authored, not removing"
  fi
fi

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '048':
    state['last_migration'] = '047'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '048') or a == '048'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=047')
PY
```

Rollback via `.bak-048` is safe because the migration writes the backup before any destructive edit in Step 1. If no backup exists, Step 1 was either SKIP_ALREADY_APPLIED (nothing to roll back) or SKIP_HAND_EDITED (nothing was written, so nothing to roll back). Step 2 has no backup — if the file is git-tracked, `git restore` recovers the pre-patch state; otherwise hand-strip the appended sentence. Step 3 creates a new file — delete it only if it carries the canonical sentinel (don't delete a hand-authored file with a colliding name).

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. The bootstrap templates (`templates/skills/write-plan/SKILL.md`,
`templates/skills/brainstorm/SKILL.md`, `templates/rules/spec-schema.md`) already carry
the correct post-048 state after Batch 04 of the workflow-improvements plan. No template edit
is needed beyond what Batch 04 already delivered; this migration exists only to propagate the
fixes to already-bootstrapped client projects whose `.claude/skills/` and `.claude/rules/`
have not yet been refreshed.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Manual-Apply-Guide

When Step 1 reports `HAND-EDITED: .claude/skills/write-plan/SKILL.md — one or both sub-steps could not apply automatically`, the migration detected that either the `argument-hint` frontmatter field OR the Steps block (or both) were customized post-bootstrap. Automatic patching is unsafe — the migration does not know whether the customization is deliberate. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the gate while preserving your customizations.

When Step 2 reports `FAIL: .claude/skills/brainstorm/SKILL.md missing Step 5 spec-save anchor`, the migration prints the verbatim sentence to stdout for direct hand-patching. No separate Manual-Apply-Guide section is needed for Step 2; paste the printed content into the appropriate place in your customized brainstorm skill body and rerun the migration.

When Step 3 reports `SKIP_HAND_EDITED: .claude/rules/spec-schema.md exists but does not carry the '# Spec Schema' sentinel`, the migration detected a hand-authored file with the same name. Use § Step-3 below to merge the canonical content.

---

### §Step-1a — Update `argument-hint` frontmatter field in `.claude/skills/write-plan/SKILL.md`

**Target**: the `argument-hint:` line inside the YAML frontmatter block at the top of `.claude/skills/write-plan/SKILL.md`.

**New content (verbatim — replace the existing `argument-hint:` line)**:

```yaml
argument-hint: "[spec-file-path] [--skip-schema-gate]"
```

**Context (showing surrounding lines)**:

```yaml
---
name: write-plan
description: >
  Use when you have requirements or a spec and need to break them into
  concrete implementation steps. Creates plan with dispatch batching.
  Use after /brainstorm or when starting from a clear spec. Dispatches proj-plan-writer.
argument-hint: "[spec-file-path] [--skip-schema-gate]"
allowed-tools: Agent Read Write
model: opus
effort: xhigh
# Skill Class: main-thread — dispatches proj-plan-writer, writes plan files
---
```

**Merge instructions**:

1. **Locate your customized frontmatter.** Open `.claude/skills/write-plan/SKILL.md`. Find the `argument-hint:` line inside the YAML frontmatter block (between the two `---` fences at the top).
2. **Check the current form.**
   - If `argument-hint: "[spec-file-path] [--skip-schema-gate]"` is already present: this sub-step is a no-op.
   - If `argument-hint: "[spec-file-path]"` (stock pre-048) is present: replace with the post-048 form above.
   - If `argument-hint:` has a customized value (e.g., `"[spec-file-path] [--force]"`): decide whether to add `[--skip-schema-gate]` to your customization. Canonical post-048 form includes only the schema-gate flag; if you have added other flags, concatenate them: `"[spec-file-path] [--skip-schema-gate] [--force]"`. Order is advisory — the skill body parses args by name, not position.
3. **Save the file.**
4. **Rerun the migration.** After your manual merge, the file contains the idempotency sentinel (`argument-hint: "[spec-file-path] [--skip-schema-gate]"` OR any customized form that still includes `[--skip-schema-gate]` — the idempotency check in Step 1a is exact-match on the canonical form; if your customized form differs, the sub-step will report `SKIP_HAND_EDITED` on re-run, which is safe — no overwrite happens).

---

### §Step-1b — Insert Step 1.5 Spec Schema Gate block between Step 1 and Step 2 in `.claude/skills/write-plan/SKILL.md`

**Target**: the `### Steps` block in `.claude/skills/write-plan/SKILL.md`. Specifically, insert the new Step 1.5 block between Step 1 (`1. Read spec from ...`) and Step 2 (`2. Read \`.claude/skills/code-write/references/pipeline-traces.md\` ...`).

**New content (verbatim — insert this block between Step 1 and Step 2 in the Steps list)**:

```markdown
1.5 **Spec Schema Gate** (runs on main thread before dispatching plan-writer):
    Parse `--skip-schema-gate` from args → if present, skip this step entirely and log "Spec schema gate bypassed by --skip-schema-gate flag".
    Otherwise, check spec file `##` section headers (word-boundary prefix match within first 40 chars of each `##` line).
    Required prefixes: `## Problem`, `## Constraints`, `## Approach`, `## Components`, `## Open Questions`
    Shell equivalent — per required prefix: `grep -m1 "^## <prefix>" <spec-file>` (non-zero exit = missing).
    All 5 found → PASS, continue to Step 2.
    Any missing → BLOCK with: "Spec schema validation failed. Missing sections: {comma-separated list of missing prefixes}. Fix the spec to include the missing section headers, or pass `--skip-schema-gate` as a separate arg to bypass. See `.claude/rules/spec-schema.md` (or `templates/rules/spec-schema.md` in the bootstrap repo) for the full schema definition and examples."
    Do NOT dispatch `proj-plan-writer` when blocked — return the block message to the user and stop.
```

**Context (showing surrounding lines in the Steps block)**:

```markdown
### Steps
1. Read spec from `.claude/specs/{branch}/` | conversation context
1.5 **Spec Schema Gate** (runs on main thread before dispatching plan-writer):
    [... block above ...]
2. Read `.claude/skills/code-write/references/pipeline-traces.md` (if exists)
3. Dispatch agent via `subagent_type="proj-plan-writer"` w/:
   [...]
```

**Merge instructions**:

1. **Locate the Steps block in your customized file.** Open `.claude/skills/write-plan/SKILL.md`. Find the `### Steps` heading. You should see numbered steps (1, 2, 3, ...) beneath it.
2. **Check whether Step 1.5 is already present.**
   - If a step numbered 1.5 exists (any content): this sub-step is effectively a no-op — the idempotency check on `Step 1.5` substring will SKIP on re-run. If the existing Step 1.5 content differs from the canonical block above, audit whether your customization achieves the same schema-gate intent; if so, leave it. If not, replace with the canonical block.
   - If no Step 1.5 exists and Steps 1 and 2 are adjacent (Step 2 immediately follows Step 1): paste the canonical Step 1.5 block between them.
   - If the Steps block has been restructured (different numbering, different content, additional pre-plan-writer steps): identify the logical position for a schema gate (it must run AFTER the spec has been read and BEFORE `proj-plan-writer` is dispatched). Paste the canonical Step 1.5 block at that position, renumbering as needed.
3. **Confirm the BLOCK message template is present.** The migration verify block checks for the string `Spec schema validation failed` — keep this exact phrase in your customized block so the verify passes.
4. **Confirm the `--skip-schema-gate` reference is present.** The verify block checks for the substring `skip-schema-gate` — keep this exact phrase so the verify passes.
5. **Save the file.**
6. **Rerun the migration.** After your manual merge, the file contains the idempotency sentinel (`Step 1.5` or `Spec Schema Gate` substring). Step 1b will print `SKIP: already patched` on re-run, then Step 2 (brainstorm), Step 3 (rule file create), and Step 4 (state advance) proceed. This completes the migration cleanly.
7. **Restore the backup only if needed.** The migration wrote `.claude/skills/write-plan/SKILL.md.bak-048` on first HAND-EDITED encounter (or on any destructive PATCH in Step 1a). `cp .claude/skills/write-plan/SKILL.md.bak-048 .claude/skills/write-plan/SKILL.md` restores pre-migration state.

---

### §Step-3 — Merge canonical `.claude/rules/spec-schema.md` with pre-existing hand-authored file

**Target**: `.claude/rules/spec-schema.md` (entire file).

**Canonical content (verbatim — this is what the migration would have written if the file had been absent)**:

```markdown
# Spec Schema

## Rule
Every spec file consumed by `/write-plan` MUST carry all 5 required `##` section headers. Word-boundary prefix match within the first 40 chars of each `##` line. Missing section → plan-writer refuses dispatch unless `--skip-schema-gate` passed.

## Required Section Headers (prefix match)
- `## Problem` — maps to "Problem / Goal", "Problem Statement", etc.
- `## Constraints` — hard rules / budget / compatibility
- `## Approach` — chosen mechanism (may be "Approach (approved)")
- `## Components` — files / interfaces / data flow (may be "Components (files, interfaces, data flow)")
- `## Open Questions` — triaged per `open-questions-discipline.md`

## Prefix Match Definition
A `##` line matches a required prefix iff:
- Line starts with `## ` (two hashes + single space)
- First word after `## ` equals the required prefix (case-sensitive)
- Match window: first 40 chars of the line

Shell check: `grep -m1 "^## <prefix>" <spec-file>` per prefix — non-zero exit = missing section.

## Examples
PASS:
- `## Problem / Goal` — first word `Problem` matches
- `## Problem Statement` — first word `Problem` matches
- `## Approach (approved)` — first word `Approach` matches
- `## Components (files, interfaces, data flow)` — first word `Components` matches
- `## Open Questions` — first word `Open` matches full prefix `Open Questions`

FAIL:
- `## problems` — lowercase, case-sensitive mismatch
- `## The Problem` — first word `The`, not `Problem`
- `##Problem` — missing space after `##`
- `##  Problem` — double space after `##`
- `### Problem` — wrong heading level

## Enforcement
- `/write-plan` Step 1.5 Spec Schema Gate runs the 5 prefix checks before dispatching `proj-plan-writer`. Any missing → BLOCK with list of missing sections.
- Escape hatch: `--skip-schema-gate` flag passed as SEPARATE arg bypasses the check (use when spec intentionally partial, e.g., exploratory scratch).
- `/brainstorm` + `/deep-think` spec output templates already conform; re-running the schema gate on their output = no-op PASS.

---

# Canonical Spec Skeleton (reference — these are the exact `##` headings a valid spec MUST carry)

The remaining `##`-level headings in this file (below) are NOT rule sections; they are the literal headings every spec must include (or a prefix-compatible variant of each). Do not edit.

## Problem

Placeholder. In a real spec, this section states the problem or goal. Variant forms accepted by the gate: `## Problem / Goal`, `## Problem Statement`.

## Constraints

Placeholder. In a real spec, this section enumerates hard constraints: budget, compatibility, non-goals, rule conformance requirements.

## Approach

Placeholder. In a real spec, this section describes the chosen mechanism. Variant forms accepted by the gate: `## Approach (approved)`.

## Components

Placeholder. In a real spec, this section lists files, interfaces, data flow. Variant forms accepted by the gate: `## Components (files, interfaces, data flow)`.

## Open Questions

Placeholder. In a real spec, this section carries triaged open questions per `open-questions-discipline.md` (USER_DECIDES / AGENT_RECOMMENDS / AGENT_DECIDED).
```

**Merge instructions**:

1. **Read your existing `.claude/rules/spec-schema.md`.** Understand what it currently defines.
2. **Decide whether to replace or merge.**
   - **Replace**: if your existing file is unrelated or stale (e.g., an old draft from a prior attempt), back it up (`cp .claude/rules/spec-schema.md .claude/rules/spec-schema.md.local`) and replace with the canonical content above.
   - **Merge**: if your existing file already defines a similar schema but with different prefixes / examples / enforcement wording, audit each section. The 5 required prefixes (`Problem`, `Constraints`, `Approach`, `Components`, `Open Questions`) are LOAD-BEARING — they are what `/write-plan` Step 1.5 checks. If you have customized the prefix list, the `/write-plan` gate must be updated in sync, or the gate will block specs that match your custom schema.
3. **Keep the `# Spec Schema` line 1 sentinel.** The migration's idempotency check requires this exact first line for Step 3 to SKIP on re-run. If you keep a customized file, ensure line 1 is `# Spec Schema` so re-runs don't re-trigger SKIP_HAND_EDITED.
4. **Save the file.**
5. **Rerun the migration.** Step 3 checks for the sentinel on line 1. If present, it SKIPs cleanly and the migration advances.

---

### Why this matters

The schema gate converts a late-stage semantic failure (plan-writer produces a semantically incomplete plan from a partial spec) into an early-stage structural failure (main-thread gate catches the missing section before any dispatch). The cost of the gate is a single grep loop on the main thread — zero dispatch, zero tokens beyond the check. The cost of a semantically incomplete plan is multiple agent dispatches later in the pipeline.

The `--skip-schema-gate` escape hatch exists for specs that are intentionally partial (exploratory drafts, mid-refinement specs, specs for tiny single-file changes where the full 5-section shape is overkill). The flag is a SEPARATE arg by design — merging it with the spec path would hide the bypass and make it order-dependent; separating it makes the bypass visible at the dispatch site.

The companion rule file `.claude/rules/spec-schema.md` is the single source of truth for the schema definition. Both `/write-plan` Step 1.5 and `/brainstorm` Step 5 point to it. Future changes to the schema (adding a 6th required section, loosening a prefix) are single-point edits in the rule file plus a paired update to the `/write-plan` gate implementation.
