# Migration 049 — proj-plan-writer Opus Reclassification + plan-quality Logging

> Reclassify `proj-plan-writer` from `sonnet + MULTI_STEP_SYNTHESIS` to `opus + GENERATES_CODE` across the whole model-selection stack: agent frontmatter (`model:` field + `# xhigh:` justification comment), `.claude/rules/model-selection.md` agent classification row, and `techniques/agent-design.md` classification-criterion prose. Plan-writer generates novel structured batch files that directly populate downstream agent dispatch briefs — errors cascade through every task the plan drives — so the classification belongs alongside code-writer / test-writer / tdd-runner rather than alongside researcher. Add `plan-quality` logging triggers to three skills (`/write-plan` Post-Dispatch Audit loopbacks + HARD-FAIL, `/execute-plan` batch-fail, `/review` scope-violation findings) so the `/reflect` + `/consolidate` pipeline gets end-to-end plan-quality signal without manual log discipline. Destructive steps (agent frontmatter, model-selection row) use three-tier detection per `.claude/rules/general.md` §Migrations; additive steps (agent-design.md criterion, skill logging blocks) are sentinel-guarded and idempotent.

---

## Metadata

```yaml
id: "049"
breaking: false
affects: [agents, rules, skills, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Audit of `.claude/rules/model-selection.md` against `techniques/agent-design.md` classification criteria revealed a misclassification: `proj-plan-writer` was listed as `sonnet + MULTI_STEP_SYNTHESIS` on the basis that it "synthesizes" spec content into a plan. The actual output — master plan + dispatch-unit batch files with embedded task contracts, tier classifications, dep sets, verification commands — is **novel structured artifact generation**, not knowledge synthesis. Batch files directly populate downstream agent dispatch briefs (every `/execute-plan` dispatch reads ONE batch file as its entire task context). A wrong merge decision, a mis-assigned tier, an omitted dep — any of these cascades through every downstream dispatch that consumes the batch. Output errors compound.

The correct classification per the `GENERATES_CODE vs MULTI_STEP_SYNTHESIS` criterion documented in `agent-design.md` is:

- **GENERATES_CODE**: produces novel structured artifacts whose output directly populates another agent's dispatch brief → errors cascade → opus
- **MULTI_STEP_SYNTHESIS**: synthesizes existing knowledge into findings consumed as reference → errors degrade but do not cascade → sonnet

Plan-writer matches GENERATES_CODE on both facets: novel artifacts + orchestrator-shape (directly feeds workers). Researcher matches MULTI_STEP_SYNTHESIS: findings are reference material for downstream code-writers, not direct dispatch input.

Secondary gap: no structural channel exists for plan-quality signal to reach the `/reflect` + `/consolidate` pipeline. Post-Dispatch Audit loopbacks, batch-fail patterns, and scope-lock violations are observable but ephemeral — they surface in the session they occur, then disappear. Longitudinal pattern detection (e.g. "plan-writer loopbacks more frequently on bash-heavy plans", "batch-fail concentrated in test-writer dispatches after proj-researcher findings", "scope violations correlated with short batch contexts") requires each observation to land in `.learnings/log.md` under a shared category so `/consolidate` can cluster across sessions. The `plan-quality` category is the natural scope; three skills observe plan-quality events (`/write-plan` at audit, `/execute-plan` at batch fail, `/review` at scope finding) and none currently write log entries.

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/agents/proj-plan-writer.md` | Frontmatter: `model: sonnet` → `model: opus` + `# xhigh: MULTI_STEP_SYNTHESIS` → `# xhigh: GENERATES_CODE` | Destructive (three-tier + Manual-Apply-Guide) |
| `.claude/rules/model-selection.md` | Agent classification row: `\| proj-plan-writer \| sonnet \| xhigh \| MULTI_STEP_SYNTHESIS \|` → `\| proj-plan-writer \| opus \| xhigh \| GENERATES_CODE \|` | Destructive (three-tier + Manual-Apply-Guide) |
| `.claude/references/techniques/agent-design.md` | Fetch updated technique file from bootstrap repo (includes new `## GENERATES_CODE vs MULTI_STEP_SYNTHESIS — Classification Criterion` section) | Full-file replace (sentinel-guarded via pre-check: SKIP if idempotency sentinel already present; else fetch + verify fetched content carries sentinel + rename into place) |
| `.claude/skills/write-plan/SKILL.md` | Append `plan-quality` logging block after HARD-FAIL step in Post-Dispatch Audit | Additive (sentinel-guarded) |
| `.claude/skills/execute-plan/SKILL.md` | Append `plan-quality` logging block after Batch Failure Handling bullets | Additive (sentinel-guarded) |
| `.claude/skills/review/SKILL.md` | Insert `5.6 plan-quality logging on scope findings` substep after Step 5.5 | Additive (sentinel-guarded) |

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f ".claude/agents/proj-plan-writer.md" ]] || { echo "ERROR: .claude/agents/proj-plan-writer.md missing — run full bootstrap first"; exit 1; }
[[ -f ".claude/rules/model-selection.md" ]] || { echo "ERROR: .claude/rules/model-selection.md missing — apply migration 030 first"; exit 1; }
[[ -d ".claude/references/techniques" ]] || { echo "ERROR: .claude/references/techniques/ missing — apply migration 008 first"; exit 1; }
[[ -d ".claude/skills/write-plan" ]] || { echo "ERROR: .claude/skills/write-plan/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills/execute-plan" ]] || { echo "ERROR: .claude/skills/execute-plan/ missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills/review" ]] || { echo "ERROR: .claude/skills/review/ missing — run full bootstrap first"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required"; exit 1; }

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-tomasfil/claude-bootstrap}"
```

---

### Step 1 — Reclassify `proj-plan-writer.md` frontmatter (three-tier detection)

Destructive: replaces two frontmatter lines (`model:` + `# xhigh:`). Must preserve project-specific customizations when detected.

**Three-tier detection:**
- **Idempotency sentinel**: frontmatter contains BOTH `model: opus` AND `# xhigh: GENERATES_CODE` → SKIP (already patched).
- **Baseline sentinel**: frontmatter contains BOTH `model: sonnet` AND `# xhigh: MULTI_STEP_SYNTHESIS` → PATCH (stock pre-migration, safe to overwrite).
- **Neither present**: file has been hand-edited → SKIP_HAND_EDITED (write `.bak-049` backup if absent, emit guidance pointing to `## Manual-Apply-Guide § §Step-1 — proj-plan-writer.md frontmatter` below, do NOT overwrite).

```bash
set -euo pipefail

TARGET=".claude/agents/proj-plan-writer.md"
BACKUP=".claude/agents/proj-plan-writer.md.bak-049"

python3 - "$TARGET" "$BACKUP" <<'PY'
import os, sys, shutil

target, backup = sys.argv[1], sys.argv[2]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

# Split frontmatter / rest
if not body.startswith("---\n"):
    print(f"SKIP_HAND_EDITED: {target} has no YAML frontmatter — manual merge required. See Manual-Apply-Guide §Step-1.")
    sys.exit(0)

end = body.find("\n---\n", 4)
if end == -1:
    print(f"SKIP_HAND_EDITED: {target} frontmatter unterminated — manual merge required. See Manual-Apply-Guide §Step-1.")
    sys.exit(0)

frontmatter = body[4:end]
rest = body[end+5:]

has_opus = "model: opus" in frontmatter
has_generates_code = "# xhigh: GENERATES_CODE" in frontmatter
has_sonnet = "model: sonnet" in frontmatter
has_multi_step = "# xhigh: MULTI_STEP_SYNTHESIS" in frontmatter

# Tier 1: already patched
if has_opus and has_generates_code:
    print(f"SKIP: {target} already contains opus + GENERATES_CODE sentinels")
    sys.exit(0)

# Tier 2: baseline stock pre-migration — safe to patch
if has_sonnet and has_multi_step:
    new_frontmatter = frontmatter.replace("model: sonnet", "model: opus").replace("# xhigh: MULTI_STEP_SYNTHESIS", "# xhigh: GENERATES_CODE")
    new_body = "---\n" + new_frontmatter + "\n---\n" + rest
    # Write backup (always, since this IS a destructive patch)
    if not os.path.exists(backup):
        shutil.copy2(target, backup)
        print(f"BACKUP: {backup} written")
    with open(target, "w", encoding="utf-8") as f:
        f.write(new_body)
    print(f"PATCHED: {target} model + classification comment reclassified to opus + GENERATES_CODE")
    sys.exit(0)

# Tier 3: neither idempotency nor baseline sentinels present — hand-edited
if not os.path.exists(backup):
    shutil.copy2(target, backup)
    print(f"BACKUP: {backup} written (pre-hand-edit safety net)")

print(f"SKIP_HAND_EDITED: {target} frontmatter does not match baseline (sonnet + MULTI_STEP_SYNTHESIS) nor target (opus + GENERATES_CODE) — manual merge required.")
print(f"  → See Manual-Apply-Guide §Step-1 below for the verbatim target frontmatter form and merge instructions.")
print(f"  → Backup written to {backup} if this was the first SKIP_HAND_EDITED encounter.")
PY
```

---

### Step 2 — Reclassify `model-selection.md` agent row (three-tier detection)

Destructive: replaces one table row. Same three-tier detection as Step 1, scoped to the row.

**Three-tier detection:**
- **Idempotency sentinel**: file contains row `| proj-plan-writer | opus | xhigh | GENERATES_CODE |` → SKIP.
- **Baseline sentinel**: file contains row `| proj-plan-writer | sonnet | xhigh | MULTI_STEP_SYNTHESIS |` → PATCH.
- **Neither present**: → SKIP_HAND_EDITED (write `.bak-049` if absent, emit guidance, do NOT overwrite).

```bash
set -euo pipefail

TARGET=".claude/rules/model-selection.md"
BACKUP=".claude/rules/model-selection.md.bak-049"

python3 - "$TARGET" "$BACKUP" <<'PY'
import os, sys, shutil

target, backup = sys.argv[1], sys.argv[2]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

IDEMPOTENT = "| proj-plan-writer | opus | xhigh | GENERATES_CODE |"
BASELINE   = "| proj-plan-writer | sonnet | xhigh | MULTI_STEP_SYNTHESIS |"

has_idem = IDEMPOTENT in body
has_base = BASELINE in body

# Tier 1
if has_idem:
    print(f"SKIP: {target} already contains idempotency row (opus + GENERATES_CODE)")
    sys.exit(0)

# Tier 2
if has_base:
    if not os.path.exists(backup):
        shutil.copy2(target, backup)
        print(f"BACKUP: {backup} written")
    body = body.replace(BASELINE, IDEMPOTENT)
    with open(target, "w", encoding="utf-8") as f:
        f.write(body)
    print(f"PATCHED: {target} proj-plan-writer row reclassified to opus + GENERATES_CODE")
    sys.exit(0)

# Tier 3
if not os.path.exists(backup):
    shutil.copy2(target, backup)
    print(f"BACKUP: {backup} written (pre-hand-edit safety net)")

print(f"SKIP_HAND_EDITED: {target} has neither baseline nor idempotency row for proj-plan-writer — manual merge required.")
print(f"  → See Manual-Apply-Guide §Step-2 below for the verbatim target row and merge instructions.")
PY
```

---

### Step 3 — Sync updated `agent-design.md` technique (additive)

Additive: appends `## GENERATES_CODE vs MULTI_STEP_SYNTHESIS — Classification Criterion` section via fetch from bootstrap repo. Target path is the client layout `.claude/references/techniques/agent-design.md` (NOT `techniques/` at client root — per `.claude/rules/general.md` §Migrations).

Sentinel: target file already contains `GENERATES_CODE vs MULTI_STEP_SYNTHESIS` heading → SKIP. Otherwise → fetch, verify sentinel in fetched content, write.

```bash
set -euo pipefail

TARGET=".claude/references/techniques/agent-design.md"

if [[ -f "$TARGET" ]] && grep -q "GENERATES_CODE vs MULTI_STEP_SYNTHESIS" "$TARGET"; then
  echo "SKIP: $TARGET already contains GENERATES_CODE vs MULTI_STEP_SYNTHESIS sentinel"
else
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/agent-design.md" --jq '.content' | base64 -d > "$TMP"
  grep -q "GENERATES_CODE vs MULTI_STEP_SYNTHESIS" "$TMP" || {
    echo "FAIL: fetched agent-design.md does not contain GENERATES_CODE vs MULTI_STEP_SYNTHESIS sentinel — bootstrap repo may not have Batch 05a merged"
    exit 1
  }
  mv "$TMP" "$TARGET"
  trap - EXIT
  echo "WROTE: $TARGET (GENERATES_CODE classification criterion section now present)"
fi
```

---

### Step 4 — Append `plan-quality` logging block to `/write-plan` Post-Dispatch Audit (additive)

Additive: inserts logging block immediately after the HARD-FAIL step in Post-Dispatch Audit. Anchor-landed; sentinel-guarded.

**Sentinel**: target file contains `<!-- plan-quality-log -->` AND `plan-quality: {LOOPBACK-1|LOOPBACK-2|HARD-FAIL}` → SKIP.
**Anchor**: the line `6. After 2 failed loopbacks → **HARD-FAIL**` — new block goes immediately after the full HARD-FAIL paragraph (which ends with `Do NOT pass broken plan to user.`).

```bash
set -euo pipefail

TARGET=".claude/skills/write-plan/SKILL.md"

python3 - "$TARGET" <<'PY'
import sys

target = sys.argv[1]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

SENTINEL_MARKER = "<!-- plan-quality-log -->"
SENTINEL_CONTENT = "plan-quality: {LOOPBACK-1|LOOPBACK-2|HARD-FAIL}"

if SENTINEL_MARKER in body and SENTINEL_CONTENT in body:
    print(f"SKIP: {target} already contains plan-quality logging block")
    sys.exit(0)

ANCHOR = "Do NOT pass broken plan to user.\n"
if ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — HARD-FAIL paragraph not found. Manual merge required. See Manual-Apply-Guide §Step-4.")
    sys.exit(0)

BLOCK = """
<!-- plan-quality-log -->
**Plan-quality logging:** After any loopback (attempt 1, attempt 2) OR HARD-FAIL, append a structured entry to `.learnings/log.md` under the `plan-quality` category:
```
### {date} — plan-quality: {LOOPBACK-1|LOOPBACK-2|HARD-FAIL}
Batch: {batch file name(s) that violated merge criteria}
Violation: {which merge criteria failed — same-agent+same-layer / disjoint-deps / combined-tasks-cap / context-budget / files-cap}
Agent: proj-plan-writer
```
One entry per loopback event — attempt 1 + attempt 2 + HARD-FAIL produce 3 separate entries if the audit escalates through all tiers. This surfaces plan-quality signal to the `/reflect` + `/consolidate` pipeline automatically, feeding longitudinal trend detection without manual log discipline. Category `plan-quality` is shared with `/execute-plan` batch-fail entries and `/review` scope-violation entries (see those skills for sibling entry formats).
"""

# Insert block on a blank line right after the HARD-FAIL paragraph.
idx = body.index(ANCHOR) + len(ANCHOR)
# Consume a following blank line so the block spaces cleanly
if body[idx:idx+1] == "\n":
    idx += 1
body = body[:idx] + BLOCK + "\n" + body[idx:]

with open(target, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {target} Post-Dispatch Audit plan-quality logging block appended")
PY
```

---

### Step 5 — Append `plan-quality` logging block to `/execute-plan` Batch Failure Handling (additive)

Additive: inserts logging block immediately after the Batch Failure Handling bullets. Anchor-landed; sentinel-guarded.

**Sentinel**: target file contains `<!-- plan-quality-log -->` AND `plan-quality: BATCH-FAIL` → SKIP.
**Anchor**: the bullet line `- NEVER collapse multiple failed tasks back into one retry batch` — new block goes immediately after this bullet (last in the Batch Failure Handling list).

```bash
set -euo pipefail

TARGET=".claude/skills/execute-plan/SKILL.md"

python3 - "$TARGET" <<'PY'
import sys

target = sys.argv[1]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

SENTINEL_MARKER = "<!-- plan-quality-log -->"
SENTINEL_CONTENT = "plan-quality: BATCH-FAIL"

if SENTINEL_MARKER in body and SENTINEL_CONTENT in body:
    print(f"SKIP: {target} already contains plan-quality logging block")
    sys.exit(0)

ANCHOR = "- NEVER collapse multiple failed tasks back into one retry batch\n"
if ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — 'NEVER collapse' bullet not found. Manual merge required. See Manual-Apply-Guide §Step-5.")
    sys.exit(0)

BLOCK = """
<!-- plan-quality-log -->
**plan-quality logging on batch fail:** every batch that returns a partial-success map with one or more FAIL entries → append a structured entry to `.learnings/log.md` under the `plan-quality` category:
```
### {date} — plan-quality: BATCH-FAIL
Batch: {batch-NN-{summary}.md}
Task: {NN.M — first failing task ID in the partial-success map}
Verification: {exact command from batch header Verification: field}
Agent: {agent from batch header Agent: field}
```
One entry per failing batch (not per failing task) — if two tasks in the same batch fail, one log entry covers the batch with `Task:` pointing at the first failure. Solo-retry failures ALSO log an entry (use the solo-retry batch identifier `batch-NN-{summary}-retry-{M}`). Category `plan-quality` is shared with `/write-plan` post-dispatch-audit loopback entries and `/review` scope-violation entries (see those skills for sibling entry formats). This creates end-to-end plan-quality signal from planning (Post-Dispatch Audit loopbacks) through execution (batch fails) through review (scope violations) — all feeding the `/reflect` + `/consolidate` pipeline under one category.
"""

idx = body.index(ANCHOR) + len(ANCHOR)
body = body[:idx] + BLOCK + body[idx:]

with open(target, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {target} Batch Failure Handling plan-quality logging block appended")
PY
```

---

### Step 6 — Insert `5.6 plan-quality logging` substep into `/review` (additive)

Additive: inserts a new substep `5.6` immediately after Step 5.5 (Open Questions Discipline check) and before Step 6 (Present review results to user). Anchor-landed; sentinel-guarded.

**Sentinel**: target file contains `<!-- plan-quality-log -->` AND `plan-quality: SCOPE-VIOLATION` → SKIP.
**Anchor**: the line `6. Present review results to user` — new substep goes immediately before this line.

```bash
set -euo pipefail

TARGET=".claude/skills/review/SKILL.md"

python3 - "$TARGET" <<'PY'
import sys

target = sys.argv[1]

with open(target, "r", encoding="utf-8") as f:
    body = f.read()

SENTINEL_MARKER = "<!-- plan-quality-log -->"
SENTINEL_CONTENT = "plan-quality: SCOPE-VIOLATION"

if SENTINEL_MARKER in body and SENTINEL_CONTENT in body:
    print(f"SKIP: {target} already contains plan-quality logging substep")
    sys.exit(0)

ANCHOR = "6. Present review results to user\n"
if ANCHOR not in body:
    print(f"ANCHOR MISSING in {target} — Step 6 'Present review results to user' not found. Manual merge required. See Manual-Apply-Guide §Step-6.")
    sys.exit(0)

BLOCK = """<!-- plan-quality-log -->
5.6 **plan-quality logging on scope findings:** if the review report contains any finding about files changed OUTSIDE the listed batch scope (scope-lock violation per `.claude/rules/agent-scope-lock.md`) OR any missing-from-plan edit (file touched that no task listed in its `#### Files` section) — append a structured entry to `.learnings/log.md` under the `plan-quality` category, one per distinct offending file:
```
### {date} — plan-quality: SCOPE-VIOLATION
File: {absolute or project-relative file path}
Finding: {scope-lock-violation | missing-from-plan}
Review: {.claude/reports/review-{timestamp}.md path}
```
Detection: grep the review report for the phrases `scope-lock violation`, `outside listed scope`, `not listed in batch`, or `missing from plan`. Each match → one log entry keyed on the file path cited in the finding. Zero matches → skip this substep silently. Category `plan-quality` is shared with `/write-plan` post-dispatch-audit entries and `/execute-plan` batch-fail entries (see those skills for sibling entry formats). This means `/review` auto-logs scope-creep incidents during post-execution review, closing the planning → execution → review loop so the `/reflect` + `/consolidate` pipeline has ground-truth signal on scope discipline without manual triage.

"""

idx = body.index(ANCHOR)
body = body[:idx] + BLOCK + body[idx:]

with open(target, "w", encoding="utf-8") as f:
    f.write(body)
print(f"PATCHED: {target} Step 5.6 plan-quality logging substep inserted")
PY
```

---

### Rules for migration scripts

- **Read-before-write** — every fetch step (Step 3) writes to a tempfile first, checks the expected sentinel, and only renames into place when the fetched content passes the sentinel check. Destructive patches (Steps 1, 2) use three-tier detection + `.bak-049` backup.
- **Idempotent** — every step is sentinel-guarded. Re-running on an already-patched project emits `SKIP` lines and exits 0 without writing. `.bak-049` backups are written only on the first PATCH or the first SKIP_HAND_EDITED encounter — never on subsequent re-runs (the `if not os.path.exists(backup)` guard).
- **Self-contained** — all logic inlined via quoted heredocs; remote fetches use only the public `gh api` surface; no reference to gitignored paths beyond the in-project write targets.
- **Abort on error** — `set -euo pipefail` on every step wrapper; Python heredocs `sys.exit(0)` on SKIP / SKIP_HAND_EDITED / ANCHOR MISSING (deliberately non-fatal per migration 031/039/042 precedent so subsequent steps still land); `sys.exit(1)` only on fetch sentinel failure in Step 3 (indicates bootstrap repo has not merged Batch 05a — user should wait or override `BOOTSTRAP_REPO`).
- **Bootstrap-repo prereq** — Step 3 requires the bootstrap repo to have merged the corresponding `techniques/agent-design.md` update (from Batch 05a). If the bootstrap repo has not been updated, the fetched content fails the sentinel check and Step 3 fails loudly — no silent partial application.
- **Technique sync path** — Step 3 writes to `.claude/references/techniques/agent-design.md`, NOT `techniques/agent-design.md` at the client project root (per `.claude/rules/general.md` §Migrations).
- **Hand-edit preservation** — Steps 1 and 2 emit `SKIP_HAND_EDITED` + `.bak-049` backup + pointer to Manual-Apply-Guide when neither baseline nor idempotency sentinel is found. Client customizations are preserved; the operator applies the patch by hand using the verbatim content below.
- **Sentinel choice** — additive steps (4, 5, 6) use a pair of sentinels: the HTML comment `<!-- plan-quality-log -->` marks the block as inserted by this migration, and a content-level sentinel (`plan-quality: {LOOPBACK-1|LOOPBACK-2|HARD-FAIL}` / `plan-quality: BATCH-FAIL` / `plan-quality: SCOPE-VIOLATION`) guards against the comment being copied without the block. Both must be present to count as SKIP.

### Required: register in migrations/index.json

Main thread applies this entry — do not attempt to edit `migrations/index.json` from inside the migration script. Entry already appended by Batch 05b Task 05.9:

```json
{
  "id": "049",
  "file": "049-plan-writer-opus.md",
  "description": "Reclassify proj-plan-writer from sonnet+MULTI_STEP_SYNTHESIS to opus+GENERATES_CODE — plan-writer generates novel structured batch files that drive all downstream dispatches, making it the highest-leverage accuracy target. Sync GENERATES_CODE classification criterion to techniques/agent-design.md. Add plan-quality logging to /write-plan Post-Dispatch Audit, /execute-plan batch-fail path, and /review scope-violation findings.",
  "breaking": false
}
```

---

## Verify

```bash
set -euo pipefail

# 1. proj-plan-writer frontmatter reclassified
[[ -f ".claude/agents/proj-plan-writer.md" ]] || { echo "FAIL: .claude/agents/proj-plan-writer.md missing"; exit 1; }
grep -q "^model: opus$" .claude/agents/proj-plan-writer.md \
  || { echo "FAIL: proj-plan-writer.md model field not opus (check SKIP_HAND_EDITED output from Step 1 — see Manual-Apply-Guide §Step-1)"; exit 1; }
grep -q "# xhigh: GENERATES_CODE" .claude/agents/proj-plan-writer.md \
  || { echo "FAIL: proj-plan-writer.md classification comment not GENERATES_CODE"; exit 1; }

# 2. model-selection.md row reclassified
[[ -f ".claude/rules/model-selection.md" ]] || { echo "FAIL: .claude/rules/model-selection.md missing"; exit 1; }
grep -q "| proj-plan-writer | opus | xhigh | GENERATES_CODE |" .claude/rules/model-selection.md \
  || { echo "FAIL: model-selection.md proj-plan-writer row not opus + GENERATES_CODE (check SKIP_HAND_EDITED output from Step 2 — see Manual-Apply-Guide §Step-2)"; exit 1; }

# 3. agent-design.md technique has classification criterion section
[[ -f ".claude/references/techniques/agent-design.md" ]] || { echo "FAIL: .claude/references/techniques/agent-design.md missing"; exit 1; }
grep -q "GENERATES_CODE vs MULTI_STEP_SYNTHESIS" .claude/references/techniques/agent-design.md \
  || { echo "FAIL: agent-design.md missing GENERATES_CODE vs MULTI_STEP_SYNTHESIS section"; exit 1; }

# 4. write-plan/SKILL.md has plan-quality logging
[[ -f ".claude/skills/write-plan/SKILL.md" ]] || { echo "FAIL: .claude/skills/write-plan/SKILL.md missing"; exit 1; }
grep -q "plan-quality" .claude/skills/write-plan/SKILL.md \
  || { echo "FAIL: write-plan/SKILL.md missing plan-quality logging block"; exit 1; }
grep -q "plan-quality: {LOOPBACK-1|LOOPBACK-2|HARD-FAIL}" .claude/skills/write-plan/SKILL.md \
  || { echo "FAIL: write-plan/SKILL.md plan-quality block missing LOOPBACK / HARD-FAIL entry format"; exit 1; }

# 5. execute-plan/SKILL.md has plan-quality logging
[[ -f ".claude/skills/execute-plan/SKILL.md" ]] || { echo "FAIL: .claude/skills/execute-plan/SKILL.md missing"; exit 1; }
grep -q "plan-quality" .claude/skills/execute-plan/SKILL.md \
  || { echo "FAIL: execute-plan/SKILL.md missing plan-quality logging block"; exit 1; }
grep -q "plan-quality: BATCH-FAIL" .claude/skills/execute-plan/SKILL.md \
  || { echo "FAIL: execute-plan/SKILL.md plan-quality block missing BATCH-FAIL entry format"; exit 1; }

# 6. review/SKILL.md has plan-quality logging
[[ -f ".claude/skills/review/SKILL.md" ]] || { echo "FAIL: .claude/skills/review/SKILL.md missing"; exit 1; }
grep -q "plan-quality" .claude/skills/review/SKILL.md \
  || { echo "FAIL: review/SKILL.md missing plan-quality logging substep"; exit 1; }
grep -q "plan-quality: SCOPE-VIOLATION" .claude/skills/review/SKILL.md \
  || { echo "FAIL: review/SKILL.md plan-quality block missing SCOPE-VIOLATION entry format"; exit 1; }

# 7. YAML frontmatter still parses for proj-plan-writer
python3 - <<'PY'
import sys
try:
    import yaml
except ImportError:
    print("WARN: PyYAML not available — frontmatter parse check skipped")
    sys.exit(0)

with open(".claude/agents/proj-plan-writer.md", "r", encoding="utf-8") as f:
    body = f.read()
if not body.startswith("---\n"):
    print("FAIL: proj-plan-writer.md has no YAML frontmatter")
    sys.exit(1)
end = body.find("\n---\n", 4)
if end == -1:
    print("FAIL: proj-plan-writer.md frontmatter unterminated")
    sys.exit(1)
try:
    fm = yaml.safe_load(body[4:end])
except yaml.YAMLError as e:
    print(f"FAIL: proj-plan-writer.md frontmatter YAML parse error: {e}")
    sys.exit(1)
if fm.get("model") != "opus":
    print(f"FAIL: proj-plan-writer.md frontmatter model is {fm.get('model')!r}, expected 'opus'")
    sys.exit(1)
print("OK: proj-plan-writer.md frontmatter YAML parses + model is opus")
PY

echo "PASS: migration 049 verified"
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing. SKIP_HAND_EDITED emissions from Step 1 or Step 2 will cause verify failures 1 or 2 — resolve by applying the Manual-Apply-Guide section corresponding to the skipped step, then re-run verify.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "049"
- append `{ "id": "049", "applied_at": "{ISO8601}", "description": "proj-plan-writer reclassified to opus+GENERATES_CODE across agent frontmatter (model + xhigh comment), model-selection.md row, and agent-design.md technique section. plan-quality logging added to /write-plan Post-Dispatch Audit, /execute-plan Batch Failure Handling, /review Step 5.6 — all three skills now write `.learnings/log.md` entries under the shared `plan-quality` category, feeding the /reflect + /consolidate pipeline with end-to-end plan-quality signal from planning through execution through review." }` to `applied[]`

---

## Post-Apply — `.learnings/log.md` Category Note

This migration does NOT create the `plan-quality` category header in `.learnings/log.md`. The category comes into existence the first time any of the three instrumented skills (`/write-plan`, `/execute-plan`, `/review`) encounters the trigger condition (loopback / HARD-FAIL / batch fail / scope violation) and writes its first entry. Entries use the standard `.learnings/log.md` heading form `### {date} — {category}: {summary}` (per `CLAUDE.md` §Self-Improvement), so the `plan-quality` category self-registers on first write — no migration-time category header is needed.

Subsequent `/reflect` + `/consolidate` passes cluster `plan-quality` entries the same way they cluster `correction` / `failure` / `gotcha` / `agent-candidate` / `environment` entries today — by category prefix match on the `###` heading.

---

## Idempotency

Re-running after success: every step's sentinel passes, so every step emits `SKIP` and exits 0 without writing. No `.bak-049` files are created on re-run (the `if not os.path.exists(backup)` guard ensures backups are written only once).

- Step 1 — proj-plan-writer.md contains `model: opus` + `# xhigh: GENERATES_CODE` → SKIP (idempotency tier)
- Step 2 — model-selection.md contains the idempotency row → SKIP
- Step 3 — `.claude/references/techniques/agent-design.md` contains `GENERATES_CODE vs MULTI_STEP_SYNTHESIS` → SKIP
- Step 4 — `.claude/skills/write-plan/SKILL.md` contains both `<!-- plan-quality-log -->` marker AND `plan-quality: {LOOPBACK-1|LOOPBACK-2|HARD-FAIL}` content sentinel → SKIP
- Step 5 — `.claude/skills/execute-plan/SKILL.md` contains both marker AND `plan-quality: BATCH-FAIL` sentinel → SKIP
- Step 6 — `.claude/skills/review/SKILL.md` contains both marker AND `plan-quality: SCOPE-VIOLATION` sentinel → SKIP

Running on a partially hand-edited project (e.g. agent frontmatter hand-edited, model-selection.md still stock): each step independently evaluates its sentinels and either PATCHes, SKIPs, or emits SKIP_HAND_EDITED. The migration does not depend on all-or-nothing state.

---

## Rollback

```bash
set -euo pipefail

# Step 1 + Step 2: restore from .bak-049 if present, else git restore
for pair in \
  ".claude/agents/proj-plan-writer.md:.claude/agents/proj-plan-writer.md.bak-049" \
  ".claude/rules/model-selection.md:.claude/rules/model-selection.md.bak-049"; do
  target="${pair%%:*}"
  backup="${pair##*:}"
  if [[ -f "$backup" ]]; then
    mv "$backup" "$target"
    echo "RESTORED: $target from $backup"
  else
    git restore "$target" 2>/dev/null && echo "RESTORED: $target from git" || echo "WARN: no backup or git tracking for $target — manual restore needed"
  fi
done

# Steps 3–6: additive inserts — rollback strips the inserted block
python3 <<'PY'
import re

# Step 3: no reliable rollback for technique sync (appended content already integrated with surrounding
# text); recommend git restore if tracked:
print("NOTE: Step 3 rollback (.claude/references/techniques/agent-design.md) — use 'git restore' if tracked, else accept appended section as no-op")

# Steps 4-6: strip everything between `<!-- plan-quality-log -->` and the end of the inserted block
TARGETS = {
    ".claude/skills/write-plan/SKILL.md": re.compile(
        r"\n<!-- plan-quality-log -->\n\*\*Plan-quality logging:\*\*.*?feeding longitudinal trend detection without manual log discipline\. Category `plan-quality` is shared with `/execute-plan` batch-fail entries and `/review` scope-violation entries \(see those skills for sibling entry formats\)\.\n",
        re.DOTALL,
    ),
    ".claude/skills/execute-plan/SKILL.md": re.compile(
        r"\n<!-- plan-quality-log -->\n\*\*plan-quality logging on batch fail:\*\*.*?all feeding the `/reflect` \+ `/consolidate` pipeline under one category\.\n",
        re.DOTALL,
    ),
    ".claude/skills/review/SKILL.md": re.compile(
        r"<!-- plan-quality-log -->\n5\.6 \*\*plan-quality logging on scope findings:\*\*.*?the `/reflect` \+ `/consolidate` pipeline has ground-truth signal on scope discipline without manual triage\.\n\n",
        re.DOTALL,
    ),
}

for path, pattern in TARGETS.items():
    try:
        with open(path, "r", encoding="utf-8") as f:
            body = f.read()
    except FileNotFoundError:
        print(f"SKIP: {path} not present")
        continue
    new_body, n = pattern.subn("", body)
    if n == 0:
        print(f"NOOP: {path} — no plan-quality block to strip (already rolled back?)")
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_body)
        print(f"STRIPPED: {path} plan-quality logging block removed ({n} match)")
PY

# Reset bootstrap-state.json last_migration to 048 if currently at 049
python3 <<'PY'
import json, sys
try:
    with open(".claude/bootstrap-state.json", "r", encoding="utf-8") as f:
        state = json.load(f)
except FileNotFoundError:
    sys.exit(0)
if state.get("last_migration") == "049":
    state["last_migration"] = "048"
    state["applied"] = [a for a in state.get("applied", []) if a.get("id") != "049"]
    with open(".claude/bootstrap-state.json", "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    print("ROLLED BACK: bootstrap-state.json last_migration reset to 048")
else:
    print(f"NOOP: bootstrap-state.json last_migration is {state.get('last_migration')!r}, not 049")
PY
```

---

## Manual-Apply-Guide

Operators reach this section via the `SKIP_HAND_EDITED` / `ANCHOR MISSING` guidance lines emitted by the automated steps above. Each subsection below holds the verbatim target content for one step — copy directly into the corresponding file when automation skipped the patch.

### §Step-1 — `proj-plan-writer.md` frontmatter (Step 1 destructive)

Automation skipped this step because the frontmatter matches neither the baseline (`model: sonnet` + `# xhigh: MULTI_STEP_SYNTHESIS`) nor the idempotency target (`model: opus` + `# xhigh: GENERATES_CODE`). A `.claude/agents/proj-plan-writer.md.bak-049` backup was written (if absent) to preserve the pre-hand-edit state.

**What to change by hand:**

1. Open `.claude/agents/proj-plan-writer.md`.
2. Locate the YAML frontmatter (between the first two `---` lines at the top of the file).
3. Find the `model:` line. If it reads anything other than `model: opus`, change it to:
   ```yaml
   model: opus
   ```
4. Find the classification-justification comment line (format: `# {effort-level}: {CLASSIFICATION_TOKEN}`). If the comment token is anything other than `GENERATES_CODE`, change it to:
   ```yaml
   # xhigh: GENERATES_CODE
   ```
   The effort prefix (`xhigh:`) must remain consistent with the `effort:` field above; if your effort field reads `effort: high`, use `# high: GENERATES_CODE` instead (the token is what matters for `/audit-model-usage` — the effort prefix follows whatever effort level your project uses).
5. Save. Do NOT touch any other frontmatter fields, the body, STEP 0 section, or any project-specific customizations — those are precisely what the SKIP_HAND_EDITED path exists to preserve.
6. Re-run the migration (`/migrate-bootstrap` or the standalone Step 1 heredoc) to confirm the idempotency sentinel now matches.

**Target frontmatter form (first 12 lines, verbatim):**

```yaml
---
name: proj-plan-writer
description: >
  Use when breaking a design or spec into concrete, ordered, verifiable
  implementation tasks. Takes spec + codebase context, produces dependency-ordered
  task list packed into dispatch-unit batch files for focused agent dispatch.
model: opus
effort: xhigh
# xhigh: GENERATES_CODE
maxTurns: 100
color: blue
---
```

Any frontmatter fields your project added beyond these (e.g. custom `memory:`, extra `skills:` list, hand-tuned `maxTurns:`, extra comments documenting why the agent is classified this way) should be preserved alongside the two canonical changes.

### §Step-2 — `model-selection.md` agent row (Step 2 destructive)

Automation skipped this step because the `proj-plan-writer` row in `.claude/rules/model-selection.md` matches neither the baseline nor the idempotency target. A `.claude/rules/model-selection.md.bak-049` backup was written (if absent).

**What to change by hand:**

1. Open `.claude/rules/model-selection.md`.
2. Locate the Agent Classification Table (under the heading `## Agent Classification Table`).
3. Find the row for `proj-plan-writer`. If its model/effort/class columns read anything other than `opus | xhigh | GENERATES_CODE`, replace the row with:
   ```markdown
   | proj-plan-writer | opus | xhigh | GENERATES_CODE |
   ```
4. Leave all other rows untouched.
5. Save.
6. Re-run the migration to confirm the idempotency sentinel now matches.

**Full target row (verbatim, column alignment matches adjacent rows in the stock table):**

```markdown
| proj-plan-writer | opus | xhigh | GENERATES_CODE |
```

If your project customized the table with additional columns (e.g. a `Notes` column), preserve those columns when swapping the row — only the three classification cells change.

### §Step-3 — `agent-design.md` classification-criterion section (Step 3 additive, typically no Manual-Apply needed)

Step 3 is additive and normally auto-fetches the updated section from the bootstrap repo. If your project's bootstrap repo has NOT yet merged the Batch 05a updates (the fetched sentinel `GENERATES_CODE vs MULTI_STEP_SYNTHESIS` is absent from the remote), wait for the bootstrap-repo PR to merge and re-run. If you need to apply by hand (e.g. offline), append this section to `.claude/references/techniques/agent-design.md` just before the `## Sources` section:

```markdown
## GENERATES_CODE vs MULTI_STEP_SYNTHESIS — Classification Criterion

When an agent produces **novel structured artifacts** (batch files, plans, code), it is GENERATES_CODE regardless of whether it "reasons" about requirements. When an agent **synthesizes existing knowledge** from multiple sources into a finding or recommendation, it is MULTI_STEP_SYNTHESIS.

**Orchestrator-shape criterion:** If the agent's output directly populates another agent's dispatch brief (plan-writer → execute-plan workers), it is GENERATES_CODE — output errors cascade. If the agent's output is consumed as reference (researcher → code-writer context), it is MULTI_STEP_SYNTHESIS.

**proj-plan-writer:** GENERATES_CODE (batch files drive downstream dispatches — wrong plan = cascading errors; opus correct).
**proj-researcher:** MULTI_STEP_SYNTHESIS (produces findings as reference, not direct dispatch input; orchestrator-workers pattern — worker role; sonnet correct per benchmark evidence: Sonnet leads Opus by 5.5pt on knowledge-synthesis tasks).
```

### §Step-4 — `/write-plan` Post-Dispatch Audit plan-quality logging block (Step 4 additive)

Step 4 only emits `ANCHOR MISSING` if the HARD-FAIL paragraph in `/write-plan/SKILL.md` has been hand-edited away. If this happens, append the following block manually immediately after the Post-Dispatch Audit Step 6 (HARD-FAIL paragraph) and before the `Rationale:` line:

```markdown
<!-- plan-quality-log -->
**Plan-quality logging:** After any loopback (attempt 1, attempt 2) OR HARD-FAIL, append a structured entry to `.learnings/log.md` under the `plan-quality` category:
```
### {date} — plan-quality: {LOOPBACK-1|LOOPBACK-2|HARD-FAIL}
Batch: {batch file name(s) that violated merge criteria}
Violation: {which merge criteria failed — same-agent+same-layer / disjoint-deps / combined-tasks-cap / context-budget / files-cap}
Agent: proj-plan-writer
```
One entry per loopback event — attempt 1 + attempt 2 + HARD-FAIL produce 3 separate entries if the audit escalates through all tiers. This surfaces plan-quality signal to the `/reflect` + `/consolidate` pipeline automatically, feeding longitudinal trend detection without manual log discipline. Category `plan-quality` is shared with `/execute-plan` batch-fail entries and `/review` scope-violation entries (see those skills for sibling entry formats).
```

### §Step-5 — `/execute-plan` Batch Failure Handling plan-quality logging block (Step 5 additive)

Step 5 only emits `ANCHOR MISSING` if the `- NEVER collapse multiple failed tasks back into one retry batch` bullet in `/execute-plan/SKILL.md` has been hand-edited away. If this happens, append the following block manually immediately after that bullet (or its hand-edited replacement):

```markdown
<!-- plan-quality-log -->
**plan-quality logging on batch fail:** every batch that returns a partial-success map with one or more FAIL entries → append a structured entry to `.learnings/log.md` under the `plan-quality` category:
```
### {date} — plan-quality: BATCH-FAIL
Batch: {batch-NN-{summary}.md}
Task: {NN.M — first failing task ID in the partial-success map}
Verification: {exact command from batch header Verification: field}
Agent: {agent from batch header Agent: field}
```
One entry per failing batch (not per failing task) — if two tasks in the same batch fail, one log entry covers the batch with `Task:` pointing at the first failure. Solo-retry failures ALSO log an entry (use the solo-retry batch identifier `batch-NN-{summary}-retry-{M}`). Category `plan-quality` is shared with `/write-plan` post-dispatch-audit loopback entries and `/review` scope-violation entries (see those skills for sibling entry formats). This creates end-to-end plan-quality signal from planning (Post-Dispatch Audit loopbacks) through execution (batch fails) through review (scope violations) — all feeding the `/reflect` + `/consolidate` pipeline under one category.
```

### §Step-6 — `/review` Step 5.6 plan-quality logging substep (Step 6 additive)

Step 6 only emits `ANCHOR MISSING` if the `6. Present review results to user` line in `/review/SKILL.md` has been renumbered or hand-edited. If this happens, insert the following substep manually immediately before the "Present review results to user" step (whatever its current number is):

```markdown
<!-- plan-quality-log -->
5.6 **plan-quality logging on scope findings:** if the review report contains any finding about files changed OUTSIDE the listed batch scope (scope-lock violation per `.claude/rules/agent-scope-lock.md`) OR any missing-from-plan edit (file touched that no task listed in its `#### Files` section) — append a structured entry to `.learnings/log.md` under the `plan-quality` category, one per distinct offending file:
```
### {date} — plan-quality: SCOPE-VIOLATION
File: {absolute or project-relative file path}
Finding: {scope-lock-violation | missing-from-plan}
Review: {.claude/reports/review-{timestamp}.md path}
```
Detection: grep the review report for the phrases `scope-lock violation`, `outside listed scope`, `not listed in batch`, or `missing from plan`. Each match → one log entry keyed on the file path cited in the finding. Zero matches → skip this substep silently. Category `plan-quality` is shared with `/write-plan` post-dispatch-audit entries and `/execute-plan` batch-fail entries (see those skills for sibling entry formats). This means `/review` auto-logs scope-creep incidents during post-execution review, closing the planning → execution → review loop so the `/reflect` + `/consolidate` pipeline has ground-truth signal on scope discipline without manual triage.
```

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are generated output, not source of truth. To update the bootstrap repo's installed copies:

1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the destructive patches operate on the same stock baseline that Batch 05a produced).
2. Do NOT directly edit `.claude/agents/proj-plan-writer.md`, `.claude/rules/model-selection.md`, `.claude/references/techniques/agent-design.md`, `.claude/skills/write-plan/SKILL.md`, `.claude/skills/execute-plan/SKILL.md`, or `.claude/skills/review/SKILL.md` in the bootstrap repo — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."
