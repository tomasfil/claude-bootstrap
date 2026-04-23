# Migration 050 — Loopback Budget Rule + Canonical Labels

> Install `.claude/rules/loopback-budget.md` as the single source of truth for retry / convergence / resource-cap vocabulary across the skill pack. Annotate 4 skill files (`/write-plan`, `/execute-plan`, `/deep-think`) with the 4 canonical labels on their existing cap statements (`LOOPBACK-AUDIT`, `SINGLE-RETRY`, `CONVERGENCE-QUALITY`, `RESOURCE-BUDGET`). Extend `/audit-agents` scope with A8 Canonical Label Compliance check that walks `.claude/skills/*/SKILL.md` for retry/convergence prose missing a canonical label → FAIL. Closes the drift vector where new loopback logic added to skills post-bootstrap diverges from the canonical vocabulary unless a mechanical check enforces it. All steps additive + sentinel-guarded — no three-tier detection needed (no destructive overwrites). `templates/skills/_template/` pre-fill is a no-op (directory absent in bootstrap repo).

---

## Metadata

```yaml
id: "050"
breaking: false
affects: [rules, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Across the skill pack, retry / convergence / resource-cap vocabulary has accumulated organically: `/write-plan` Post-Dispatch Audit uses "Loopback cap: 2 attempts"; `/execute-plan` Batch Failure Handling uses "Solo retry also fails → STOP"; `/deep-think` uses "0 HIGH gaps from critic for 1 consecutive round", "MAX_PHASE1_PASSES = 3", "MAX_GAP_PARALLEL = 3", "MAX_GAP_TOTAL = 15". Each statement is independently well-formed but collectively there is no shared vocabulary — four distinct phrasing styles for four distinct cap families. Two downstream consequences:

1. **Skill authors adding new loopback logic** invent a 5th phrasing style rather than reusing one of the existing families — because there is no named palette to reuse from. Over time the vocabulary splinters further.
2. **`/reflect` + `/consolidate` cannot cluster loopback events by family** — loopback telemetry could feed longitudinal pattern detection ("critic-convergence caps hit more often on UI proposals than on rule-engineering proposals", "batch-fail single-retries concentrate in test-writer dispatches") but the events arrive under inconsistent prose; automated clustering needs a canonical label on each event.

Adding a single rule file that defines the 4 labels and annotating every existing cap statement with its label closes both gaps. `/audit-agents` A8 check then enforces the vocabulary mechanically — any new retry/convergence cap without a canonical label fails the audit.

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/rules/loopback-budget.md` | NEW rule file — 4 canonical labels + usage guidance | Additive (new file) |
| `.claude/skills/write-plan/SKILL.md` | Annotate existing "Loopback cap: 2 attempts" statement with `LOOPBACK-AUDIT` label | Additive (sentinel-guarded) |
| `.claude/skills/execute-plan/SKILL.md` | Annotate existing "Solo retry also fails → STOP" statement with `SINGLE-RETRY` label | Additive (sentinel-guarded) |
| `.claude/skills/deep-think/SKILL.md` | Annotate 4 existing cap statements: Phase 4 `HIGH == 0 → CONVERGED` with `CONVERGENCE-QUALITY`; Phase 1 `MAX_PHASE1_PASSES = 3` / Phase 5 `MAX_GAP_PARALLEL = 3` / Phase 5 `MAX_GAP_TOTAL = 15` with `RESOURCE-BUDGET` | Additive (sentinel-guarded) |
| `.claude/skills/audit-agents/SKILL.md` | Append A8 Canonical Label Compliance check that walks skill files for retry/convergence prose missing a canonical label | Additive (sentinel-guarded) |
| `templates/skills/_template/` | Pre-fill Dispatch Map comment with canonical vocab pointer | NO-OP — directory absent in bootstrap repo |

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/rules" ]] || { echo "ERROR: .claude/rules/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills/write-plan" ]] || { echo "ERROR: .claude/skills/write-plan/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills/execute-plan" ]] || { echo "ERROR: .claude/skills/execute-plan/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills/deep-think" ]] || { echo "ERROR: .claude/skills/deep-think/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills/audit-agents" ]] || { echo "ERROR: .claude/skills/audit-agents/ missing — run full bootstrap first"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

---

### Step 1 — Create `.claude/rules/loopback-budget.md` (additive, new file)

Additive: creates a new rule file. If the file already exists with the canonical header, SKIP. Otherwise, write the file inline via heredoc.

**Sentinel**: target file exists AND contains `## Canonical Labels` heading AND contains all 4 label names (`LOOPBACK-AUDIT`, `SINGLE-RETRY`, `CONVERGENCE-QUALITY`, `RESOURCE-BUDGET`) → SKIP.

```bash
set -euo pipefail

TARGET=".claude/rules/loopback-budget.md"

if [[ -f "$TARGET" ]] \
  && grep -q "^## Canonical Labels$" "$TARGET" \
  && grep -q "LOOPBACK-AUDIT" "$TARGET" \
  && grep -q "SINGLE-RETRY" "$TARGET" \
  && grep -q "CONVERGENCE-QUALITY" "$TARGET" \
  && grep -q "RESOURCE-BUDGET" "$TARGET"; then
  echo "SKIP: $TARGET already contains canonical-labels rule"
else
  cat > "$TARGET" <<'RULE_EOF'
# Loopback Budget

## Rule
Every retry / convergence / resource cap in a skill MUST carry one of the 4 canonical labels. Labels are the single source of truth for loopback semantics across the skill pack. New caps without a canonical label → `/audit-agents` FAIL.

## Canonical Labels

### LOOPBACK-AUDIT
- **Where**: `/write-plan` Post-Dispatch Audit
- **Policy**: cap = 2 loopback attempts; HARD-FAIL on 3rd violation
- **Semantics**: re-dispatch plan-writer w/ corrective prompt; trust agent Self-Audit; do NOT pass broken plan to user

### SINGLE-RETRY
- **Where**: `/execute-plan` Batch Failure Handling
- **Policy**: per-batch failed task gets 1 SOLO retry; stop on 2nd fail
- **Semantics**: no re-batching; each retry = fresh context; STOP + report on solo fail

### CONVERGENCE-QUALITY
- **Where**: `/deep-think` Phase 4 adversarial critic loop
- **Policy**: iterate until 0 HIGH-severity gaps for 1 consecutive round OR cap hit
- **Semantics**: quality-driven exit (not count-driven); default cap=5 rounds, hard ceiling=10 via `--max-critic`

### RESOURCE-BUDGET
- **Where**: `/deep-think` Phase 1 pass cap, Phase 5 parallel-per-round cap, Phase 5 total-gap-resolution cap
- **Policy**: `MAX_PHASE1_PASSES=3`, `MAX_GAP_PARALLEL=3`, `MAX_GAP_TOTAL=15` (warn at 10)
- **Semantics**: cost-driven exit (token/dispatch budget); writes BELOW-THRESHOLD partial on exhaustion

## Usage
- Annotate cap statement w/ inline comment `# {LABEL}` on the same line or line above
- New retry/convergence logic in a skill MUST pick one of the 4 labels — do not invent a 5th
- `/audit-agents` scans `.claude/skills/*/SKILL.md` for retry/convergence prose w/o a canonical label → FAIL w/ file:line
- Extending policy (e.g. raising a cap) → keep the label; change the numeric value

## Rationale
Field observation: skill pack accumulated ad-hoc retry caps w/ inconsistent vocabulary ("cap 2", "loopback ≤2", "max retries", "convergence signal"). Single vocabulary lets `/audit-agents` enforce consistency mechanically, lets `/reflect` cluster loopback events by label, and gives skill authors a known palette when adding new loops.
RULE_EOF
  echo "WROTE: $TARGET"
fi
```

---

### Step 2 — Annotate `/write-plan` Post-Dispatch Audit loopback cap with `LOOPBACK-AUDIT` (additive)

Additive: inserts HTML-comment label annotation into the existing "Loopback cap: 2 attempts" statement. Anchor-landed; sentinel-guarded.

**Sentinel**: target file contains `LOOPBACK-AUDIT` → SKIP.
**Anchor**: literal string `**Loopback cap: 2 attempts.**`

```bash
set -euo pipefail

TARGET=".claude/skills/write-plan/SKILL.md"

python3 - "$TARGET" <<'PY'
import sys

target = sys.argv[1]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

SENTINEL = "LOOPBACK-AUDIT"

if SENTINEL in body:
    print(f"SKIP: {target} already contains {SENTINEL} label annotation")
    sys.exit(0)

ANCHOR = "**Loopback cap: 2 attempts.**"
if ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — '**Loopback cap: 2 attempts.**' not found. Manual merge required. See Manual-Apply-Guide §Step-2.")
    sys.exit(0)

REPLACEMENT = ANCHOR + " <!-- LOOPBACK-AUDIT: canonical label — see .claude/rules/loopback-budget.md -->"
body = body.replace(ANCHOR, REPLACEMENT, 1)

with open(target, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {target} LOOPBACK-AUDIT annotation appended to loopback-cap statement")
PY
```

---

### Step 3 — Annotate `/execute-plan` Batch Failure Handling with `SINGLE-RETRY` (additive)

Additive: inserts HTML-comment label annotation into the existing "Solo retry also fails → STOP" bullet. Anchor-landed; sentinel-guarded.

**Sentinel**: target file contains `SINGLE-RETRY` → SKIP.
**Anchor**: literal line `- Solo retry also fails → STOP, report to user, ask how to proceed (do NOT silently skip or continue past failing tasks)`

```bash
set -euo pipefail

TARGET=".claude/skills/execute-plan/SKILL.md"

python3 - "$TARGET" <<'PY'
import sys

target = sys.argv[1]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

SENTINEL = "SINGLE-RETRY"

if SENTINEL in body:
    print(f"SKIP: {target} already contains {SENTINEL} label annotation")
    sys.exit(0)

ANCHOR = "- Solo retry also fails → STOP, report to user, ask how to proceed (do NOT silently skip or continue past failing tasks)"
if ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — solo-retry bullet not found. Manual merge required. See Manual-Apply-Guide §Step-3.")
    sys.exit(0)

REPLACEMENT = ANCHOR + " <!-- SINGLE-RETRY: canonical label — see .claude/rules/loopback-budget.md -->"
body = body.replace(ANCHOR, REPLACEMENT, 1)

with open(target, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {target} SINGLE-RETRY annotation appended to solo-retry bullet")
PY
```

---

### Step 4 — Annotate 4 caps in `/deep-think` with `CONVERGENCE-QUALITY` + `RESOURCE-BUDGET` (additive)

Additive: inserts label annotations on 4 cap statements in `/deep-think`:
- Phase 4 convergence check `HIGH == 0 → CONVERGED` → `CONVERGENCE-QUALITY`
- Phase 5 convergence-caps table: `MAX_PHASE1_PASSES = 3` → `RESOURCE-BUDGET`; `MAX_CRITIC` → `CONVERGENCE-QUALITY`; `MAX_GAP_PARALLEL = 3` + `MAX_GAP_TOTAL = 15` → `RESOURCE-BUDGET`

**Sentinel**: target file contains `CONVERGENCE-QUALITY` → SKIP (all 4 annotations land in one pass; one sentinel guards the whole batch).

```bash
set -euo pipefail

TARGET=".claude/skills/deep-think/SKILL.md"

python3 - "$TARGET" <<'PY'
import sys

target = sys.argv[1]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

SENTINEL = "CONVERGENCE-QUALITY"

if SENTINEL in body:
    print(f"SKIP: {target} already contains {SENTINEL} label annotations (all 4 caps landed in one pass)")
    sys.exit(0)

# Annotation 1: Phase 4 convergence check header
ANCHOR_1 = "**Convergence check (read the new gap register):**\n- `HIGH == 0` → **CONVERGED**."
if ANCHOR_1 not in body:
    print(f"ANCHOR MISSING in {target} — Phase 4 convergence-check header not found. Manual merge required. See Manual-Apply-Guide §Step-4.")
    sys.exit(0)
REPLACEMENT_1 = "<!-- CONVERGENCE-QUALITY: canonical label — see .claude/rules/loopback-budget.md -->\n**Convergence check (read the new gap register):**\n- `HIGH == 0` → **CONVERGED**."
body = body.replace(ANCHOR_1, REPLACEMENT_1, 1)

# Annotation 2-4: Phase 5 convergence-caps table — replace header + 4 rows in one block
ANCHOR_2 = """**Convergence caps (observable units — NOT time):**

| Cap | Value | Enforced where |
|---|---|---|
| Phase 1 auto-retries (T1/T2/T3) | max 2 extra passes, 3 total | `MAX_PHASE1_PASSES = 3` |
| Phase 4 critic iterations | max 5 (override via `--max-critic`, hard ceiling 10) | `MAX_CRITIC` |
| Phase 5 parallel gap-resolution per round | max 3 | `MAX_GAP_PARALLEL = 3` |
| Phase 5 total gap-resolution dispatches per run | max 15 (warn at 10) | `MAX_GAP_TOTAL = 15` |"""

if ANCHOR_2 not in body:
    print(f"ANCHOR MISSING in {target} — Phase 5 convergence-caps table not found in expected form. Manual merge required. See Manual-Apply-Guide §Step-4.")
    sys.exit(0)

REPLACEMENT_2 = """**Convergence caps (observable units — NOT time):**

<!-- RESOURCE-BUDGET: canonical label — Phase 1 pass cap + Phase 5 parallel/total gap-resolution caps — see .claude/rules/loopback-budget.md -->
<!-- CONVERGENCE-QUALITY: canonical label — Phase 4 critic iteration cap — see .claude/rules/loopback-budget.md -->

| Cap | Value | Enforced where |
|---|---|---|
| Phase 1 auto-retries (T1/T2/T3) | max 2 extra passes, 3 total | `MAX_PHASE1_PASSES = 3` <!-- RESOURCE-BUDGET --> |
| Phase 4 critic iterations | max 5 (override via `--max-critic`, hard ceiling 10) | `MAX_CRITIC` <!-- CONVERGENCE-QUALITY --> |
| Phase 5 parallel gap-resolution per round | max 3 | `MAX_GAP_PARALLEL = 3` <!-- RESOURCE-BUDGET --> |
| Phase 5 total gap-resolution dispatches per run | max 15 (warn at 10) | `MAX_GAP_TOTAL = 15` <!-- RESOURCE-BUDGET --> |"""

body = body.replace(ANCHOR_2, REPLACEMENT_2, 1)

with open(target, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {target} CONVERGENCE-QUALITY + RESOURCE-BUDGET annotations landed on all 4 cap statements")
PY
```

---

### Step 5 — Extend `/audit-agents` with A8 Canonical Label Compliance check (additive)

Additive: inserts A8 section after A7 in `/audit-agents/SKILL.md`. Updates the Output yaml block to include A8. Adds A8 fix recommendation to the "After the agent returns" list.

**Sentinel**: target file contains `A8: Skill Audit — Canonical Label Compliance` heading → SKIP.
**Anchor 1** (A8 section): literal heading `### A7: effort:xhigh justification presence check` — new section inserts after the A7 block, before `### Output`.
**Anchor 2** (yaml block line): literal line `  A7_effort_high_justified: {PASS|FAIL|WARN|SKIP}`
**Anchor 3** (fix-recommendation line): literal line `- A7 WARN → \`INHERITED_DEFAULT\` is tracked debt; revisit classification per \`techniques/agent-design.md\` Skill Class → Model Binding`

```bash
set -euo pipefail

TARGET=".claude/skills/audit-agents/SKILL.md"

python3 - "$TARGET" <<'PY'
import sys

target = sys.argv[1]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

SENTINEL = "A8: Skill Audit — Canonical Label Compliance"

if SENTINEL in body:
    print(f"SKIP: {target} already contains A8 Canonical Label Compliance section")
    sys.exit(0)

# Anchor 1 — insert A8 section after A7 block
A7_END_ANCHOR = "Output: append A7 section to the audit report markdown.\n"
if A7_END_ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — 'Output: append A7 section to the audit report markdown.' line not found. Manual merge required. See Manual-Apply-Guide §Step-5.")
    sys.exit(0)

A8_BLOCK = """
### A8: Skill Audit — Canonical Label Compliance
Scope extension: this check walks `.claude/skills/*/SKILL.md` (not agents) and verifies that every retry / convergence / resource-cap statement carries one of the 4 canonical labels defined in `.claude/rules/loopback-budget.md`.

Canonical labels:
- `LOOPBACK-AUDIT` — write-plan Post-Dispatch Audit loopback cap (attempts = 2, HARD-FAIL on 3rd)
- `SINGLE-RETRY` — execute-plan per-batch failed-task retry (1 solo retry, STOP on 2nd fail)
- `CONVERGENCE-QUALITY` — deep-think critic iteration cap (0 HIGH-gap convergence criterion)
- `RESOURCE-BUDGET` — deep-think Phase 1 pass cap + Phase 5 parallel/total gap-resolution caps

For each `.claude/skills/*/SKILL.md`:
  Grep for retry/convergence trigger phrases (case-insensitive): `loopback`, `retry`, `iteration cap`, `convergence`, `MAX_`, `hard-fail after`, `attempts`, `re-dispatch.*fail`, `max .* passes`, `total .* dispatches`.
  For each match line:
    IF line OR immediately-adjacent line (±2) contains one of the 4 canonical labels → PASS for this statement.
    ELSE → FAIL w/ `file:line` evidence + snippet + suggested label.
  Skip matches inside fenced code blocks whose language tag is NOT markdown (e.g. `bash`, `python`, `json`) — those are illustrative, not policy.
  Skip matches inside the `loopback-budget.md` reference itself (it defines the labels; it does not need to self-annotate).

Report format (append to audit markdown):
```yaml
A8_canonical_label_compliance: {PASS|FAIL|SKIP}
findings:
  - check: A8
    severity: FAIL
    file: .claude/skills/{name}/SKILL.md
    line: {N}
    snippet: "{matched line, trimmed}"
    suggested_label: "{one of 4 canonical labels}"
    detail: "retry/convergence statement missing canonical label — annotate via inline `# {LABEL}` comment"
```

Rationale: new loopback logic added to skills post-bootstrap drifts away from the canonical vocabulary unless a mechanical check enforces it. A8 closes the drift vector — `/audit-agents` flags any new retry/convergence cap that lacks a canonical label, `/reflect` gets to cluster loopback events by label, and new skill authors see the 4-label palette on first audit failure instead of inventing a 5th.

Dispatch brief update: when dispatching `proj-consistency-checker`, extend scope from agent files to include `.claude/skills/*/SKILL.md` for A8 specifically. A1-A7 scope remains unchanged.
"""

body = body.replace(A7_END_ANCHOR, A7_END_ANCHOR + A8_BLOCK, 1)

# Anchor 2 — add A8 row to Output yaml block
YAML_ANCHOR = "  A7_effort_high_justified: {PASS|FAIL|WARN|SKIP}\n"
if YAML_ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — Output yaml 'A7_effort_high_justified' line not found. Manual merge required. See Manual-Apply-Guide §Step-5.")
    sys.exit(0)

YAML_REPLACEMENT = YAML_ANCHOR + "  A8_canonical_label_compliance: {PASS|FAIL|SKIP}\n"
body = body.replace(YAML_ANCHOR, YAML_REPLACEMENT, 1)

# Anchor 3 — add A8 fix recommendation
FIX_ANCHOR = "- A7 WARN → `INHERITED_DEFAULT` is tracked debt; revisit classification per `techniques/agent-design.md` Skill Class → Model Binding\n"
if FIX_ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — 'A7 WARN → INHERITED_DEFAULT' fix-recommendation line not found. Manual merge required. See Manual-Apply-Guide §Step-5.")
    sys.exit(0)

FIX_REPLACEMENT = FIX_ANCHOR + "- A8 FAIL → annotate the cited retry/convergence statement w/ one of the 4 canonical labels (`LOOPBACK-AUDIT` | `SINGLE-RETRY` | `CONVERGENCE-QUALITY` | `RESOURCE-BUDGET`) via inline HTML comment `<!-- {LABEL}: canonical label — see .claude/rules/loopback-budget.md -->` at end of line or on preceding line; see `.claude/rules/loopback-budget.md` for the full label semantics + where-applied pointers\n"
body = body.replace(FIX_ANCHOR, FIX_REPLACEMENT, 1)

with open(target, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {target} A8 Canonical Label Compliance section + yaml row + fix recommendation appended")
PY
```

---

### Step 6 — `_template/` pre-fill (NO-OP)

The bootstrap repo does not ship a `templates/skills/_template/` directory at this migration's cut time. No client project has it either (client projects derive skill scaffolds from the `templates/skills/<name>/` directories, which are the concrete source-of-truth per skill). If a future migration introduces `_template/`, that migration is responsible for pre-filling the Dispatch Map comment with the canonical-vocabulary pointer.

```bash
set -euo pipefail

if [[ -d ".claude/skills/_template" ]]; then
  echo "INFO: .claude/skills/_template/ present — manually ensure Dispatch Map comment includes 'canonical retry/convergence labels: see .claude/rules/loopback-budget.md' pointer. This migration does not patch _template because it is not part of the bootstrap repo at migration 050 cut time."
else
  echo "SKIP: .claude/skills/_template/ absent — no pre-fill needed"
fi
```

---

### Rules for migration scripts

- **Read-before-write** — every step checks its sentinel before writing. Re-running is safe.
- **Idempotent** — every step is sentinel-guarded. Re-running on an already-patched project emits `SKIP` lines and exits 0 without writing.
- **Self-contained** — new rule file content is inlined via heredoc (no remote fetch). Annotations are pure text substitution against literal anchors.
- **Additive only** — no destructive overwrites, no three-tier detection needed. If an anchor is missing (hand-edit drift), the step emits `ANCHOR MISSING` + pointer to Manual-Apply-Guide + `sys.exit(0)` (non-fatal per migration 031/039/042/049 precedent — subsequent steps still land).
- **No remote fetch** — unlike migrations that sync technique files, this migration creates a rule file that is net-new (no bootstrap-repo prerequisite for content).

### Required: register in migrations/index.json

Main thread applies this entry — do not attempt to edit `migrations/index.json` from inside the migration script. Entry appended by Batch 06 Task 06.8:

```json
{
  "id": "050",
  "file": "050-loopback-budget-rule.md",
  "description": "Canonical retry/convergence vocabulary via .claude/rules/loopback-budget.md — 4 labels: LOOPBACK-AUDIT (/write-plan), SINGLE-RETRY (/execute-plan), CONVERGENCE-QUALITY (/deep-think critic), RESOURCE-BUDGET (/deep-think caps). Annotate skill caps with labels. Extend /audit-agents to check skill files for label compliance.",
  "breaking": false
}
```

---

## Verify

```bash
set -euo pipefail

# 1. loopback-budget.md rule file present and correct
[[ -f ".claude/rules/loopback-budget.md" ]] || { echo "FAIL: .claude/rules/loopback-budget.md missing"; exit 1; }
grep -q "^## Canonical Labels$" .claude/rules/loopback-budget.md \
  || { echo "FAIL: .claude/rules/loopback-budget.md missing '## Canonical Labels' heading"; exit 1; }
for label in LOOPBACK-AUDIT SINGLE-RETRY CONVERGENCE-QUALITY RESOURCE-BUDGET; do
  grep -q "$label" .claude/rules/loopback-budget.md \
    || { echo "FAIL: .claude/rules/loopback-budget.md missing label $label"; exit 1; }
done

# 2. write-plan has LOOPBACK-AUDIT annotation
[[ -f ".claude/skills/write-plan/SKILL.md" ]] || { echo "FAIL: .claude/skills/write-plan/SKILL.md missing"; exit 1; }
grep -q "LOOPBACK-AUDIT" .claude/skills/write-plan/SKILL.md \
  || { echo "FAIL: write-plan/SKILL.md missing LOOPBACK-AUDIT annotation"; exit 1; }

# 3. execute-plan has SINGLE-RETRY annotation
[[ -f ".claude/skills/execute-plan/SKILL.md" ]] || { echo "FAIL: .claude/skills/execute-plan/SKILL.md missing"; exit 1; }
grep -q "SINGLE-RETRY" .claude/skills/execute-plan/SKILL.md \
  || { echo "FAIL: execute-plan/SKILL.md missing SINGLE-RETRY annotation"; exit 1; }

# 4. deep-think has CONVERGENCE-QUALITY + RESOURCE-BUDGET annotations
[[ -f ".claude/skills/deep-think/SKILL.md" ]] || { echo "FAIL: .claude/skills/deep-think/SKILL.md missing"; exit 1; }
grep -q "CONVERGENCE-QUALITY" .claude/skills/deep-think/SKILL.md \
  || { echo "FAIL: deep-think/SKILL.md missing CONVERGENCE-QUALITY annotation"; exit 1; }
grep -q "RESOURCE-BUDGET" .claude/skills/deep-think/SKILL.md \
  || { echo "FAIL: deep-think/SKILL.md missing RESOURCE-BUDGET annotation"; exit 1; }

# 5. audit-agents has A8 section + yaml row + fix recommendation
[[ -f ".claude/skills/audit-agents/SKILL.md" ]] || { echo "FAIL: .claude/skills/audit-agents/SKILL.md missing"; exit 1; }
grep -q "A8: Skill Audit — Canonical Label Compliance" .claude/skills/audit-agents/SKILL.md \
  || { echo "FAIL: audit-agents/SKILL.md missing A8 heading"; exit 1; }
grep -q "A8_canonical_label_compliance:" .claude/skills/audit-agents/SKILL.md \
  || { echo "FAIL: audit-agents/SKILL.md Output yaml missing A8_canonical_label_compliance row"; exit 1; }
grep -q "A8 FAIL → annotate" .claude/skills/audit-agents/SKILL.md \
  || { echo "FAIL: audit-agents/SKILL.md missing A8 fix recommendation"; exit 1; }

echo "PASS: migration 050 verified"
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing. `ANCHOR MISSING` emissions from Steps 2-5 will cause verify failures 2-5 respectively — resolve by applying the Manual-Apply-Guide section corresponding to the skipped step, then re-run verify.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "050"
- append `{ "id": "050", "applied_at": "{ISO8601}", "description": "Loopback budget rule + canonical labels. Installs .claude/rules/loopback-budget.md (4 labels: LOOPBACK-AUDIT, SINGLE-RETRY, CONVERGENCE-QUALITY, RESOURCE-BUDGET). Annotates existing cap statements in /write-plan, /execute-plan, /deep-think. Extends /audit-agents with A8 Canonical Label Compliance check that walks skill files for retry/convergence prose missing a canonical label." }` to `applied[]`

---

## Idempotency

Re-running after success: every step's sentinel passes, so every step emits `SKIP` and exits 0 without writing.

- Step 1 — `.claude/rules/loopback-budget.md` exists with `## Canonical Labels` + all 4 labels → SKIP
- Step 2 — `.claude/skills/write-plan/SKILL.md` contains `LOOPBACK-AUDIT` → SKIP
- Step 3 — `.claude/skills/execute-plan/SKILL.md` contains `SINGLE-RETRY` → SKIP
- Step 4 — `.claude/skills/deep-think/SKILL.md` contains `CONVERGENCE-QUALITY` → SKIP (covers all 4 cap annotations)
- Step 5 — `.claude/skills/audit-agents/SKILL.md` contains `A8: Skill Audit — Canonical Label Compliance` heading → SKIP
- Step 6 — no-op (directory absent)

Running on a partially hand-edited project (e.g. one skill already has the annotation, another does not): each step independently evaluates its sentinel and either patches or skips. The migration does not depend on all-or-nothing state.

---

## Rollback

```bash
set -euo pipefail

# Step 1: remove new rule file
if [[ -f ".claude/rules/loopback-budget.md" ]]; then
  rm ".claude/rules/loopback-budget.md"
  echo "REMOVED: .claude/rules/loopback-budget.md"
else
  echo "NOOP: .claude/rules/loopback-budget.md not present"
fi

# Steps 2-5: strip annotations via python text substitution
python3 <<'PY'
import re

TARGETS = {
    ".claude/skills/write-plan/SKILL.md": [
        (" <!-- LOOPBACK-AUDIT: canonical label — see .claude/rules/loopback-budget.md -->", ""),
    ],
    ".claude/skills/execute-plan/SKILL.md": [
        (" <!-- SINGLE-RETRY: canonical label — see .claude/rules/loopback-budget.md -->", ""),
    ],
    ".claude/skills/deep-think/SKILL.md": [
        ("<!-- CONVERGENCE-QUALITY: canonical label — see .claude/rules/loopback-budget.md -->\n", ""),
        ("\n<!-- RESOURCE-BUDGET: canonical label — Phase 1 pass cap + Phase 5 parallel/total gap-resolution caps — see .claude/rules/loopback-budget.md -->\n<!-- CONVERGENCE-QUALITY: canonical label — Phase 4 critic iteration cap — see .claude/rules/loopback-budget.md -->\n", "\n"),
        (" <!-- RESOURCE-BUDGET -->", ""),
        (" <!-- CONVERGENCE-QUALITY -->", ""),
    ],
    ".claude/skills/audit-agents/SKILL.md": [
        # A8 section (header + body through 'Dispatch brief update' paragraph)
        (re.compile(r"\n### A8: Skill Audit — Canonical Label Compliance\n.*?A1-A7 scope remains unchanged\.\n", re.DOTALL), ""),
        # A8 yaml row
        ("  A8_canonical_label_compliance: {PASS|FAIL|SKIP}\n", ""),
        # A8 fix recommendation line
        (re.compile(r"- A8 FAIL → annotate.*?where-applied pointers\n", re.DOTALL), ""),
    ],
}

for path, subs in TARGETS.items():
    try:
        with open(path, "r", encoding="utf-8") as f:
            body = f.read()
    except FileNotFoundError:
        print(f"SKIP: {path} not present")
        continue
    changed = 0
    for needle, replacement in subs:
        if isinstance(needle, re.Pattern):
            new_body, n = needle.subn(replacement, body)
        else:
            new_body = body.replace(needle, replacement)
            n = 1 if new_body != body else 0
        body = new_body
        changed += n
    if changed == 0:
        print(f"NOOP: {path} — no annotations to strip (already rolled back?)")
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(body)
        print(f"STRIPPED: {path} ({changed} substitutions applied)")
PY

# Reset bootstrap-state.json last_migration to 049 if currently at 050
python3 <<'PY'
import json, sys
try:
    with open(".claude/bootstrap-state.json", "r", encoding="utf-8") as f:
        state = json.load(f)
except FileNotFoundError:
    sys.exit(0)
if state.get("last_migration") == "050":
    state["last_migration"] = "049"
    state["applied"] = [a for a in state.get("applied", []) if a.get("id") != "050"]
    with open(".claude/bootstrap-state.json", "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    print("ROLLED BACK: bootstrap-state.json last_migration reset to 049")
else:
    print(f"NOOP: bootstrap-state.json last_migration is {state.get('last_migration')!r}, not 050")
PY
```

---

## Manual-Apply-Guide

Operators reach this section via the `ANCHOR MISSING` guidance lines emitted by the automated steps above. Each subsection below holds the verbatim target content for one step — copy directly into the corresponding file when automation skipped the patch.

### §Step-2 — `/write-plan` LOOPBACK-AUDIT annotation

Automation skipped this step because the literal anchor `**Loopback cap: 2 attempts.**` was not found in `.claude/skills/write-plan/SKILL.md`. The Post-Dispatch Audit section has been hand-edited to use different phrasing.

**What to change by hand:**

1. Open `.claude/skills/write-plan/SKILL.md`.
2. Locate the Post-Dispatch Audit section.
3. Find the statement that defines the loopback cap (paraphrasings of "after 2 failed loopback attempts"). Append this HTML comment at end of line (or on a preceding line if the cap sentence is inside a bullet):
   ```markdown
    <!-- LOOPBACK-AUDIT: canonical label — see .claude/rules/loopback-budget.md -->
   ```
4. Save.

### §Step-3 — `/execute-plan` SINGLE-RETRY annotation

Automation skipped because the literal anchor `- Solo retry also fails → STOP, report to user, ask how to proceed (do NOT silently skip or continue past failing tasks)` was not found in `.claude/skills/execute-plan/SKILL.md`.

**What to change by hand:**

1. Open `.claude/skills/execute-plan/SKILL.md`.
2. Locate the Batch Failure Handling section.
3. Find the solo-retry bullet (paraphrasings of "Solo retry also fails → STOP, report"). Append this HTML comment at end of line:
   ```markdown
    <!-- SINGLE-RETRY: canonical label — see .claude/rules/loopback-budget.md -->
   ```
4. Save.

### §Step-4 — `/deep-think` CONVERGENCE-QUALITY + RESOURCE-BUDGET annotations

Automation skipped because one of the two anchors was not found in `.claude/skills/deep-think/SKILL.md`. Required annotations:

**What to change by hand:**

1. Open `.claude/skills/deep-think/SKILL.md`.
2. Locate the Phase 4 `Convergence check (read the new gap register):` header. Prepend this line immediately above it:
   ```markdown
   <!-- CONVERGENCE-QUALITY: canonical label — see .claude/rules/loopback-budget.md -->
   ```
3. Locate the Phase 5 `Convergence caps (observable units — NOT time):` section. Immediately after the header paragraph (before the table), insert these two lines:
   ```markdown
   <!-- RESOURCE-BUDGET: canonical label — Phase 1 pass cap + Phase 5 parallel/total gap-resolution caps — see .claude/rules/loopback-budget.md -->
   <!-- CONVERGENCE-QUALITY: canonical label — Phase 4 critic iteration cap — see .claude/rules/loopback-budget.md -->
   ```
4. Inside the same Convergence caps table, append per-row markers at the end of each row's third column:
   - `| Phase 1 auto-retries (T1/T2/T3) | max 2 extra passes, 3 total | `MAX_PHASE1_PASSES = 3` <!-- RESOURCE-BUDGET --> |`
   - `| Phase 4 critic iterations | max 5 (override via `--max-critic`, hard ceiling 10) | `MAX_CRITIC` <!-- CONVERGENCE-QUALITY --> |`
   - `| Phase 5 parallel gap-resolution per round | max 3 | `MAX_GAP_PARALLEL = 3` <!-- RESOURCE-BUDGET --> |`
   - `| Phase 5 total gap-resolution dispatches per run | max 15 (warn at 10) | `MAX_GAP_TOTAL = 15` <!-- RESOURCE-BUDGET --> |`
5. Save.

### §Step-5 — `/audit-agents` A8 Canonical Label Compliance extension

Automation skipped because one of the three anchors was not found in `.claude/skills/audit-agents/SKILL.md`. Three insertions required:

**What to change by hand:**

1. Open `.claude/skills/audit-agents/SKILL.md`.
2. Locate the `### A7: effort:xhigh justification presence check` section. Immediately after the line `Output: append A7 section to the audit report markdown.` (which ends the A7 block), insert the following block before the `### Output` heading:

   ```markdown

   ### A8: Skill Audit — Canonical Label Compliance
   Scope extension: this check walks `.claude/skills/*/SKILL.md` (not agents) and verifies that every retry / convergence / resource-cap statement carries one of the 4 canonical labels defined in `.claude/rules/loopback-budget.md`.

   Canonical labels:
   - `LOOPBACK-AUDIT` — write-plan Post-Dispatch Audit loopback cap (attempts = 2, HARD-FAIL on 3rd)
   - `SINGLE-RETRY` — execute-plan per-batch failed-task retry (1 solo retry, STOP on 2nd fail)
   - `CONVERGENCE-QUALITY` — deep-think critic iteration cap (0 HIGH-gap convergence criterion)
   - `RESOURCE-BUDGET` — deep-think Phase 1 pass cap + Phase 5 parallel/total gap-resolution caps

   For each `.claude/skills/*/SKILL.md`:
     Grep for retry/convergence trigger phrases (case-insensitive): `loopback`, `retry`, `iteration cap`, `convergence`, `MAX_`, `hard-fail after`, `attempts`, `re-dispatch.*fail`, `max .* passes`, `total .* dispatches`.
     For each match line:
       IF line OR immediately-adjacent line (±2) contains one of the 4 canonical labels → PASS for this statement.
       ELSE → FAIL w/ `file:line` evidence + snippet + suggested label.
     Skip matches inside fenced code blocks whose language tag is NOT markdown (e.g. `bash`, `python`, `json`) — those are illustrative, not policy.
     Skip matches inside the `loopback-budget.md` reference itself (it defines the labels; it does not need to self-annotate).

   Report format (append to audit markdown):
   ```yaml
   A8_canonical_label_compliance: {PASS|FAIL|SKIP}
   findings:
     - check: A8
       severity: FAIL
       file: .claude/skills/{name}/SKILL.md
       line: {N}
       snippet: "{matched line, trimmed}"
       suggested_label: "{one of 4 canonical labels}"
       detail: "retry/convergence statement missing canonical label — annotate via inline `# {LABEL}` comment"
   ```

   Rationale: new loopback logic added to skills post-bootstrap drifts away from the canonical vocabulary unless a mechanical check enforces it. A8 closes the drift vector — `/audit-agents` flags any new retry/convergence cap that lacks a canonical label, `/reflect` gets to cluster loopback events by label, and new skill authors see the 4-label palette on first audit failure instead of inventing a 5th.

   Dispatch brief update: when dispatching `proj-consistency-checker`, extend scope from agent files to include `.claude/skills/*/SKILL.md` for A8 specifically. A1-A7 scope remains unchanged.
   ```

3. Locate the Output yaml block (the `audit: agent-rules-mcp` section). After the line `  A7_effort_high_justified: {PASS|FAIL|WARN|SKIP}`, add:

   ```yaml
     A8_canonical_label_compliance: {PASS|FAIL|SKIP}
   ```

4. Locate the fix-recommendation list (the `### After the agent returns` section). After the line `- A7 WARN → ...`, add:

   ```markdown
   - A8 FAIL → annotate the cited retry/convergence statement w/ one of the 4 canonical labels (`LOOPBACK-AUDIT` | `SINGLE-RETRY` | `CONVERGENCE-QUALITY` | `RESOURCE-BUDGET`) via inline HTML comment `<!-- {LABEL}: canonical label — see .claude/rules/loopback-budget.md -->` at end of line or on preceding line; see `.claude/rules/loopback-budget.md` for the full label semantics + where-applied pointers
   ```

5. Save.

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are generated output, not source of truth. To update the bootstrap repo's installed copies:

1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/`.
2. Do NOT directly edit `.claude/rules/loopback-budget.md`, `.claude/skills/write-plan/SKILL.md`, `.claude/skills/execute-plan/SKILL.md`, `.claude/skills/deep-think/SKILL.md`, or `.claude/skills/audit-agents/SKILL.md` in the bootstrap repo — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."
