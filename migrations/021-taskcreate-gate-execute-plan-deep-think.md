# Migration 021 — TaskCreate gate for /execute-plan and /deep-think

> Inject a `TaskCreate` / `TaskUpdate` observability gate into `.claude/skills/execute-plan/SKILL.md` and `.claude/skills/deep-think/SKILL.md` so long-running multi-phase orchestrator skills create a harness-level task entry on start, update status per phase/batch, and close it on completion or abort. Idempotent per-file; safe to re-run.

---

## Metadata

```yaml
id: "021"
breaking: false
affects: [skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"021"`
- `breaking`: `false` — additive patches, no existing behavior removed
- `affects`: `[skills]` — touches two skill files only (no agents, modules, hooks, or techniques)
- `requires_mcp_json`: `false` — `TaskCreate` / `TaskUpdate` are harness-provided deferred tools, not MCP
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the `/deep-think` skill (migration 017)

---

## Problem

The `/execute-plan` and `/deep-think` skills are the two longest-running main-thread orchestrators in the bootstrap. `/execute-plan` dispatches multiple batches sequentially over the lifetime of a plan run (tens of minutes to multiple sessions). `/deep-think` cycles through 7 phases with an adversarial critic loop that can re-enter Phase 1 up to 3 times and Phase 4 up to 5 times. Both are opaque to the harness task list — neither creates a harness-level task entry on start, so the user cannot observe "deep-think on topic X in progress" or "execute-plan on plan Y, batch 3/7" in the task list, and a mid-run abort leaves no trace.

The harness exposes `TaskCreate` and `TaskUpdate` as deferred tools (loaded on demand via `ToolSearch("select:TaskCreate,TaskUpdate")`). The bootstrap did not wire them into these skills. Retrofitting the gate makes both skills observable, surfaces aborts in the harness task list, and lets `/reflect` and `/consolidate` correlate learning-log entries with the task that produced them.

Root cause: the two skills were authored before the `TaskCreate` / `TaskUpdate` deferred tools were available, and neither was updated when those tools shipped. This migration applies the shared `TASKCREATE_GATE_BLOCK` contract (defined in `modules/06-skills.md`) to both skills and makes the change idempotent via a literal-string sentinel check.

---

## Changes

- `.claude/skills/execute-plan/SKILL.md`:
  - Insert a new Step 0 (TaskCreate gate) at the start of the `### Steps` section, immediately before the existing Step 1 (`Read master plan`).
  - Append a new Step 4 (TaskCreate closeout) inside the `### Post-Execution (MANDATORY)` section, after the existing `NEVER say "ready to commit"` line area, wiring the success-path `TaskUpdate(status="completed")` and the abort-path `TaskUpdate(status="in_progress" + BLOCKED)` calls.
- `.claude/skills/deep-think/SKILL.md`:
  - Insert a new `## TaskCreate Gate (TASKCREATE_GATE_BLOCK)` section immediately after the `## Iteration State Initialization` section's closing code fence, before `## Phase 0`.
  - Add one-line `TaskUpdate(status="in_progress", description="Phase N: <name>")` markers at the top of each phase body: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5, Phase 6.
  - Add the closeout `TaskUpdate(status="completed")` marker at the top of `## Phase 7 — Handoff` (Phase 7 is the handoff-only phase — completion fires as Phase 7 begins).

Idempotency: every patch is gated by a literal-string `grep -q 'ToolSearch("select:TaskCreate,TaskUpdate")'` sentinel check against the target file. If the sentinel is already present the patch is skipped with a `SKIP` log line. A second run produces zero modifications. **No regex with `.*` anywhere** (per `.learnings/log.md:10-11` — sed anchors must be literal).

Bootstrap self-alignment: the shared `TASKCREATE_GATE_BLOCK` definition lives in `modules/06-skills.md` immediately after `PRE_FLIGHT_GATE_BLOCK`. Client-project bootstrap refreshes from that module will regenerate both skill files with the gate in place; this migration brings already-bootstrapped client projects forward without a full refresh.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

# Verify both target skill files exist. If either is missing, the project predates
# the skill ship and this migration is not applicable to that skill — print SKIP
# per-file but continue. We only hard-fail if BOTH are missing (nothing to do).
EXECUTE_PLAN=".claude/skills/execute-plan/SKILL.md"
DEEP_THINK=".claude/skills/deep-think/SKILL.md"

if [[ ! -f "$EXECUTE_PLAN" && ! -f "$DEEP_THINK" ]]; then
  echo "SKIP: neither execute-plan nor deep-think skill present — migration not applicable"
  exit 0
fi

# Sentinel: literal string that marks the gate as applied. Must match exactly.
SENTINEL='ToolSearch("select:TaskCreate,TaskUpdate")'
```

---

### Step A — Patch `.claude/skills/execute-plan/SKILL.md`

Target: insert Step 0 after the literal `### Steps` heading, and append Step 4 inside `### Post-Execution (MANDATORY)` after the literal `NEVER say "ready to commit" without /review first.` line.

```bash
if [[ ! -f "$EXECUTE_PLAN" ]]; then
  echo "SKIP: $EXECUTE_PLAN not found"
else
  if grep -qF "$SENTINEL" "$EXECUTE_PLAN"; then
    echo "SKIP: 021 already applied to $EXECUTE_PLAN (sentinel present)"
  else
    # Verify the literal anchors exist before patching. If either anchor is
    # missing, the file has drifted from the bootstrap template — bail with a
    # clear error rather than corrupt it.
    if ! grep -qF "### Steps" "$EXECUTE_PLAN"; then
      echo "ERROR: anchor '### Steps' not found in $EXECUTE_PLAN — manual patch required"
      exit 1
    fi
    if ! grep -qF 'NEVER say "ready to commit" without `/review` first.' "$EXECUTE_PLAN"; then
      echo "ERROR: anchor for Post-Execution closing line not found in $EXECUTE_PLAN — manual patch required"
      exit 1
    fi

    # --- Patch 1: insert Step 0 block immediately after the literal '### Steps' heading.
    # Use awk with a literal-string match (index()) — not regex — to avoid any
    # accidental pattern interpretation of the anchor.
    TMP_A="$(mktemp)"
    awk '
      BEGIN { inserted = 0 }
      {
        print
        if (!inserted && $0 == "### Steps") {
          print "0. **TaskCreate gate** (TASKCREATE_GATE_BLOCK — makes the execute-plan run observable in the harness task list)."
          print "   Run `ToolSearch(\"select:TaskCreate,TaskUpdate\")` to load the TaskCreate / TaskUpdate schemas on demand."
          print "   If the ToolSearch returns matching tools:"
          print "     - Call `TaskCreate(subject=f\"execute-plan: {plan-basename}\", description=f\"Execute plan {plan-path} — {batch-count} batches\")` where `{plan-basename}` = the plan filename without directory, `{plan-path}` = the full path passed as argument (resolved from `.claude/specs/{branch}/` or user reply), `{batch-count}` = number of `batch-*.md` files discovered during Pre-Flight Audit Step 1 (if Pre-Flight Audit has not yet run, glob the batch files now to compute the count — this is safe: Pre-Flight Audit also runs this glob)."
          print "     - Then call `TaskUpdate(taskId=<returned-id>, status=\"in_progress\")`."
          print "     - Remember the returned taskId in conversation state for the remainder of this skill run — referenced again in `### Post-Execution (MANDATORY)` step 4."
          print "     - Set `TASK_TRACKING=true`."
          print "   If ToolSearch returns no schemas OR TaskCreate raises InputValidationError:"
          print "     - Set `TASK_TRACKING=false`."
          print "     - Print one warning line: `TaskCreate unavailable — continuing without harness task tracking`."
          print "     - Continue to step 1 without creating any task entry."
          print "   Do NOT fail the skill run on ToolSearch failure; the gate is observability, not a blocker."
          inserted = 1
        }
      }
    ' "$EXECUTE_PLAN" > "$TMP_A"
    mv "$TMP_A" "$EXECUTE_PLAN"

    # --- Patch 2: append Step 4 (closeout) inside '### Post-Execution (MANDATORY)'.
    # Anchor is the existing line '3. Only after review passes → tell user ready to `/commit`'
    # — insert the new Step 4 immediately after it, BEFORE the blank line and the
    # 'NEVER say ...' closing line. Literal match via index().
    TMP_B="$(mktemp)"
    awk '
      BEGIN { inserted = 0 }
      {
        print
        if (!inserted && $0 == "3. Only after review passes → tell user ready to `/commit`") {
          print "4. **TaskCreate closeout** (TASKCREATE_GATE_BLOCK step 3/4):"
          print "   If `TASK_TRACKING=true` (set in Steps step 0):"
          print "     - On successful completion (all batches passed, `/review` clean, user told \"ready to commit\"):"
          print "       Call `TaskUpdate(taskId=<id>, status=\"completed\")`. The harness task list closes the entry."
          print "     - On abort / error / user-cancel / hard-fail (any batch fails solo retry, Pre-Flight Audit hard-rejects, user stops the run mid-batch, or `/review` surfaces issues that block progress):"
          print "       Call `TaskUpdate(taskId=<id>, status=\"in_progress\", description=<original-description> + \"\\n\\nBLOCKED: {reason}\")`"
          print "       where `{reason}` is a one-sentence description of the failure (e.g. `\"batch-03 sub-task 03.2 failed solo retry — SCOPE EXPANSION\"`, `\"user cancelled after batch-02 checkpoint\"`, `\"Pre-Flight Audit rejected plan: unmerged batches 01+02\"`). Do NOT mark the task `completed` on abort — leaving it `in_progress` with a BLOCKED suffix surfaces the failure in the harness task list instead of silently closing it."
          print "   If `TASK_TRACKING=false` → skip this step entirely (no task entry exists to close)."
          inserted = 1
        }
      }
    ' "$EXECUTE_PLAN" > "$TMP_B"
    mv "$TMP_B" "$EXECUTE_PLAN"

    # Verify sentinel now present.
    if grep -qF "$SENTINEL" "$EXECUTE_PLAN"; then
      echo "PATCHED: $EXECUTE_PLAN — Step 0 gate + Post-Execution closeout"
    else
      echo "ERROR: $EXECUTE_PLAN patch completed but sentinel missing — manual review required"
      exit 1
    fi
  fi
fi
```

---

### Step B — Patch `.claude/skills/deep-think/SKILL.md`

Target: insert a `## TaskCreate Gate (TASKCREATE_GATE_BLOCK)` section after the literal `## Iteration State Initialization` section (specifically after the literal closing line `Create \`{base_path}\` directory before Phase 0 ...`), add per-phase `TaskUpdate` markers at the top of each phase body (Phases 1–6), and add the closeout marker at the top of `## Phase 7 — Handoff`.

Six phase anchors are patched in one awk pass. Each phase heading is a literal string (`## Phase N — <Name>`); awk matches exact lines via `==`, not regex.

```bash
if [[ ! -f "$DEEP_THINK" ]]; then
  echo "SKIP: $DEEP_THINK not found"
else
  if grep -qF "$SENTINEL" "$DEEP_THINK"; then
    echo "SKIP: 021 already applied to $DEEP_THINK (sentinel present)"
  else
    # Verify every literal anchor exists before patching.
    REQUIRED_ANCHORS=(
      "## Iteration State Initialization"
      "## Phase 0 — Evidence-First Local Scan"
      "## Phase 1 — Parallel Divergent Ideation"
      "## Phase 2 — Evaluator Scoring + Clustering + Shortlist"
      "## Phase 3 — Deepen Top-N (Reflexion-style)"
      "## Phase 4 — Adversarial Gap Hunt"
      "## Phase 5 — Gap Resolution Loop"
      "## Phase 6 — Dual-Artifact Synthesis"
      "## Phase 7 — Handoff"
    )
    for anchor in "${REQUIRED_ANCHORS[@]}"; do
      if ! grep -qF "$anchor" "$DEEP_THINK"; then
        echo "ERROR: anchor '$anchor' not found in $DEEP_THINK — manual patch required"
        exit 1
      fi
    done

    # Anchor line that marks the END of the Iteration State Initialization section.
    # This is the literal paragraph right before the '---' separator and '## Phase 0'.
    INIT_END='Create `{base_path}` directory before Phase 0 via the Write tool (no bash `mkdir` — use Write with a placeholder `README.md` if directory creation needed, or rely on Write tool auto-creating parents).'
    if ! grep -qF "$INIT_END" "$DEEP_THINK"; then
      echo "ERROR: iteration-state end anchor not found in $DEEP_THINK — manual patch required"
      exit 1
    fi

    TMP="$(mktemp)"
    awk '
      BEGIN {
        gate_inserted = 0
        init_end_seen = 0
      }
      {
        print

        # Insert the TaskCreate Gate section AFTER the iteration-state end
        # paragraph AND the following blank line AND the "---" separator. We
        # track state: after seeing the init-end line we wait for the next "---"
        # and inject the gate section right after it (replacing its trailing
        # blank line with our section header).
        if (!gate_inserted && init_end_seen == 0 && $0 == "Create `{base_path}` directory before Phase 0 via the Write tool (no bash `mkdir` — use Write with a placeholder `README.md` if directory creation needed, or rely on Write tool auto-creating parents).") {
          init_end_seen = 1
          next_sep_wanted = 1
        }
        if (next_sep_wanted == 1 && $0 == "---") {
          # Emit the gate section. Awk has already printed the "---" above; we
          # follow with a blank line + section + blank line + another "---" so
          # the next "## Phase 0" remains below its own separator.
          print ""
          print "## TaskCreate Gate (TASKCREATE_GATE_BLOCK)"
          print ""
          print "Make the deep-think run observable in the harness task list before entering Phase 0. This gate runs ONCE per skill invocation, after iteration state is set and before any dispatch."
          print ""
          print "Run `ToolSearch(\"select:TaskCreate,TaskUpdate\")` to load the TaskCreate / TaskUpdate schemas on demand."
          print ""
          print "If the ToolSearch returns matching tools:"
          print "- Compute `{phase_count}` = 7 (Phases 0 through 6 fully execute; Phase 7 is handoff-only). If `--no-critic` was passed, note `phase_count=5` (Phases 4 and 5 skipped)."
          print "- Compute `{persona_count}` = 5 by default, or 3 if `--quick` was passed, or whatever override comes from `references/personas.md`."
          print "- Call `TaskCreate(subject=f\"deep-think: {topic_slug}\", description=f\"Deep-think on {topic} — {phase_count} phases, {persona_count} personas\")`."
          print "- Then call `TaskUpdate(taskId=<returned-id>, status=\"in_progress\", description=f\"Phase 0: Evidence-First Local Scan\")`."
          print "- Remember the returned taskId in conversation state (`deepthink_task_id`) for the remainder of this skill run — it is referenced at the start of every subsequent phase and in the Phase 6 closeout."
          print "- Set `TASK_TRACKING=true`."
          print ""
          print "If ToolSearch returns no schemas OR TaskCreate raises InputValidationError:"
          print "- Set `TASK_TRACKING=false`."
          print "- Print one warning line: `TaskCreate unavailable — continuing without harness task tracking`."
          print "- Continue to Phase 0 without creating any task entry."
          print ""
          print "Do NOT fail the skill run on ToolSearch failure; the gate is observability, not a blocker. On any mid-run abort / user-cancel / hard-fail (T7 structural flaw, critic cap reached, dispatch budget exhausted, user stop at Phase 2 gate, etc.), call `TaskUpdate(taskId=<id>, status=\"in_progress\", description=f\"Phase {N}: {phase-name}\\n\\nBLOCKED: {reason}\")` instead of marking completed — leaving the status in_progress with a BLOCKED suffix surfaces the failure in the harness task list."
          print ""
          print "---"
          gate_inserted = 1
          next_sep_wanted = 0
        }

        # Per-phase TaskUpdate markers: inject one-line marker at the top of
        # each phase body (immediately AFTER the "## Phase N — ..." heading,
        # printing a blank line + marker + blank line so the existing body
        # spacing is preserved).
        if ($0 == "## Phase 1 — Parallel Divergent Ideation") {
          print ""
          print "(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status=\"in_progress\", description=\"Phase 1: Parallel Divergent Ideation\")`"
        }
        if ($0 == "## Phase 2 — Evaluator Scoring + Clustering + Shortlist") {
          print ""
          print "(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status=\"in_progress\", description=\"Phase 2: Evaluator Scoring + Clustering + Shortlist\")`"
        }
        if ($0 == "## Phase 3 — Deepen Top-N (Reflexion-style)") {
          print ""
          print "(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status=\"in_progress\", description=\"Phase 3: Deepen Top-N (Reflexion-style)\")`"
        }
        if ($0 == "## Phase 4 — Adversarial Gap Hunt") {
          print ""
          print "(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status=\"in_progress\", description=\"Phase 4: Adversarial Gap Hunt\")`"
        }
        if ($0 == "## Phase 5 — Gap Resolution Loop") {
          print ""
          print "(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status=\"in_progress\", description=\"Phase 5: Gap Resolution Loop\")`"
        }
        if ($0 == "## Phase 6 — Dual-Artifact Synthesis") {
          print ""
          print "(TASK_TRACKING=true) `TaskUpdate(taskId=<id>, status=\"in_progress\", description=\"Phase 6: Dual-Artifact Synthesis\")`"
        }
        if ($0 == "## Phase 7 — Handoff") {
          print ""
          print "(TASK_TRACKING=true) **TaskCreate closeout** — call `TaskUpdate(taskId=<id>, status=\"completed\")`. This is the successful-completion closeout call for the deep-think run. After this call, the harness task list closes the entry. If the run is aborting mid-Phase-7 for any reason (user cancels handoff, artifacts missing, verification checklist failure deferred from Phase 6), call `TaskUpdate(taskId=<id>, status=\"in_progress\", description=<original-description> + \"\\n\\nBLOCKED: {reason}\")` instead — never mark the task completed on abort."
        }
      }
    ' "$DEEP_THINK" > "$TMP"
    mv "$TMP" "$DEEP_THINK"

    if grep -qF "$SENTINEL" "$DEEP_THINK"; then
      echo "PATCHED: $DEEP_THINK — gate section + 6 per-phase markers + Phase 7 closeout"
    else
      echo "ERROR: $DEEP_THINK patch completed but sentinel missing — manual review required"
      exit 1
    fi
  fi
fi
```

---

### Step C — Register in `migrations/index.json`

The migration runner (`/migrate-bootstrap`) discovers migrations via `migrations/index.json`, not the directory listing. An entry must be present in the array before this migration can be applied by a client project.

```json
{
  "id": "021",
  "file": "021-taskcreate-gate-execute-plan-deep-think.md",
  "description": "TaskCreate observability gate for /execute-plan and /deep-think — idempotent awk patches inject a ToolSearch-loaded TaskCreate/TaskUpdate call-site into both SKILL.md files: Step 0 + closeout in execute-plan, post-Iteration-State gate section + per-phase markers (Phase 1-6) + Phase 7 closeout in deep-think. Sentinel-guarded (literal 'ToolSearch(\"select:TaskCreate,TaskUpdate\")'), re-run safe, no regex with '.*' anywhere. Backed by the shared TASKCREATE_GATE_BLOCK definition newly added to modules/06-skills.md.",
  "breaking": false
}
```

Add this entry to the `migrations` array in `migrations/index.json`, immediately after the `020` entry.

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` / `awk` match uses `grep -qF` or `awk` exact-string equality (`$0 == "..."`). No regex `.*` patterns. Anchor drift detection fails fast with a clear error.
- **Idempotent** — literal-string sentinel `ToolSearch("select:TaskCreate,TaskUpdate")` gates every patch. Re-run produces zero modifications.
- **Read-before-write** — each patch block reads the file, verifies all anchors, then writes to a temp file before `mv` replacing.
- **MINGW64-safe** — uses `mktemp` + `mv` (no `sed -i` in-place edits, which have known MINGW64 quirks). No process substitution. No `readarray`.
- **Abort on error** — `set -euo pipefail` at the top. Missing anchors → explicit `exit 1` with a manual-patch message; partially patched files are never silently left behind.
- **Self-contained** — no remote fetches, no references to gitignored paths. The gate block content is inlined here in full.

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

SENTINEL='ToolSearch("select:TaskCreate,TaskUpdate")'
FAIL=0

for f in .claude/skills/execute-plan/SKILL.md .claude/skills/deep-think/SKILL.md; do
  if [[ ! -f "$f" ]]; then
    echo "SKIP-VERIFY: $f not present (skill not installed in this project)"
    continue
  fi
  if grep -qF "$SENTINEL" "$f"; then
    echo "PASS: $f contains sentinel"
  else
    echo "FAIL: $f missing sentinel after migration"
    FAIL=1
  fi
done

# Verify the index.json entry exists.
if grep -qF '"id": "021"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 021 entry"
else
  echo "FAIL: migrations/index.json missing 021 entry"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || exit 1
```

Failure of any verify step → `/migrate-bootstrap` aborts and does NOT update `bootstrap-state.json`. Safe to retry after fixing the failure.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"021"`
- append `{ "id": "021", "applied_at": "<ISO8601>", "description": "TaskCreate gate for /execute-plan and /deep-think" }` to `applied[]`

---

## Rollback

Reversible via literal-anchor deletion: remove the Step 0 block + Step 4 block from `.claude/skills/execute-plan/SKILL.md` and the `## TaskCreate Gate (TASKCREATE_GATE_BLOCK)` section + 7 TaskUpdate marker lines from `.claude/skills/deep-think/SKILL.md`. Easier: `git restore .claude/skills/execute-plan/SKILL.md .claude/skills/deep-think/SKILL.md` from the pre-migration commit. No cascading dependencies — removing the gate restores the original observability-free behavior without affecting any other skill, agent, or rule.
