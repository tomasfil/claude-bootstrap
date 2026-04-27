# Migration 057 — Multi-Rollout Rule File (Mode A Only)

<!-- migration-id: 057-multi-rollout-rule -->

> Adds `.claude/rules/multi-rollout.md` (and `templates/rules/multi-rollout.md` source-of-truth) carrying Mode A invariants (2/3/4/5/8) for sequential-degraded multi-rollout dispatch. Adds `multi-rollout.md` STEP 0 force-read bullet to `proj-plan-writer` and globbed `proj-code-writer-*` agent bodies. Mode B (parallel rollouts) + worktree-dependent invariants (1/6/7) explicitly OUT OF SCOPE per user decision 2026-04-27 (worktree EXPERIMENTAL on win32 — GitHub #40164 + #43038 open). Invariant 8 (`LOOP_INTERACTION_EXCLUSIVE`) preserves canonical-4 invariant from `loopback-budget.md` by classifying writer re-dispatches inside `/review` eval-opt loop as Tier-B at the classification layer (not the loopback-annotation layer). Rule is landable without parallel mechanism — sequential mode delivers tier classification, selection precedence, ALL_ROLLOUTS_FAILED terminal state, and LOOP_INTERACTION_EXCLUSIVE classification rule on day 1. Per-step three-tier detection (idempotency sentinel / baseline anchor / SKIP_HAND_EDITED + `.bak-057` backup + `## Manual-Apply-Guide` pointer); 4-state outer idempotency. Companion export with divergence guard. Self-contained heredocs for all embedded content per `general.md`.

---

## Metadata

```yaml
id: "057"
breaking: false
affects: [rules, agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Why

Field-observed deep-think on workflow improvements (2026-04-27, gap-resolution-1-1-3 rule reframe + cross-loop guard bundle) identified that the multi-rollout dispatch pattern (Tier-C parallel code-writer rollouts for high-uncertainty tasks) had no rule file in `.claude/rules/` — leaving tier classification, selection precedence, ALL_ROLLOUTS_FAILED handling, and the cross-loop interaction guard (writer re-dispatched from `/review` eval-opt loop) entirely undocumented. Without a rule file, the conventions exist only in the deep-think spec; agents do not load them in STEP 0; convention drifts on next plan iteration.

The original rule design (deepen-1-3) bundled 8 invariants together, including 3 invariants (1, 6, 7) that hard-BLOCK on platform features that are EXPERIMENTAL or UNDOCUMENTED on the primary dev platform (win32):
- Invariant 1 (rollout isolation via `isolation: "worktree"`) — broken on win32 per GitHub #40164 (false-positive "not in git repository") + #43038 (Warp terminal crash)
- Invariant 6 (pre-warm cache discipline via `cache_control` injection) — Claude Code harness exposure UNDOCUMENTED
- Invariant 7 (temperature-diversity advisory) — `temperature:` parameter UNDOCUMENTED in Agent tool call syntax

Bundling these as hard blockers made the entire rule non-operational on win32 — zero value delivered. The user decision 2026-04-27 (per gap-resolution-1-1-3 SG-1) reframes scope: ship v1 with Mode A (sequential degraded) only — invariants 2, 3, 4, 5, 8 — which is platform-agnostic, worktree-free, temperature-agnostic, and operational on win32 immediately. Mode B + invariants 1/6/7 are deferred to a separate deep-think session that re-evaluates the temperature + worktree gating decisions; they are NOT carried forward into this migration.

Invariant 8 (`LOOP_INTERACTION_EXCLUSIVE`) is the cross-loop guard that prevents compound nesting between the multi-rollout fan-out (Tier-C) and the `/review` eval-opt CONVERGENCE-QUALITY loop introduced by migration 056. Writer re-dispatches from the eval-opt loop are targeted corrections (specific findings from reviewer), NOT explorative multi-attempts — running N rollouts of a post-review fix would compound to up to N × cap_review dispatches per original task (worst case N=3 × 3 = 9 dispatches; with test-first up to 45). Invariant 8 forces those re-dispatches to Tier-B (3 rollouts max, modest correction-grade diversity) at the classification layer — NOT as a 5th canonical loopback label, preserving the `loopback-budget.md` canonical-4 invariant. The `<!-- LOOP_INTERACTION_EXCLUSIVE -->` HTML comment already shipped in `/review` Step 7 (migration 056) is the machine-readable marker; this migration adds the rule file that authoritatively defines the constraint.

The rule is landable WITHOUT the parallel mechanism: sequential degraded mode delivers tier classification (Tier-A=1, Tier-B=3, Tier-C=5), selection precedence (PASS > smallest_diff > coverage > lint), ALL_ROLLOUTS_FAILED terminal state with `.learnings/log.md plan-quality` log format extending the `<!-- plan-quality-log -->` block from `/review`, and LOOP_INTERACTION_EXCLUSIVE classification — all on day 1, on every platform, with no upstream blocker dependencies.

---

## Changes

| File | Change | Tier |
|---|---|---|
| `.claude/rules/multi-rollout.md` | CREATE rule file with Mode A invariants (2/3/4/5/8) — sentinel `<!-- multi-rollout-v1-installed -->` | Additive (new file; existence-guarded) |
| `templates/rules/multi-rollout.md` | CREATE template source-of-truth — same content as `.claude/rules/` | Additive (new file; existence-guarded) |
| `.claude/agents/proj-plan-writer.md` | Insert `multi-rollout.md` STEP 0 force-read bullet after `open-questions-discipline.md` bullet | Destructive (three-tier; per-file sentinel `multi-rollout-step0-installed`) |
| `templates/agents/proj-plan-writer.md` | Same change applied to template | Destructive (three-tier; same sentinel) |
| `.claude/agents/proj-code-writer-*.md` (glob) | Insert `multi-rollout.md (if present)` STEP 0 force-read bullet after `max-quality.md` bullet | Destructive (per-file three-tier; per-file sentinel `multi-rollout-step0-installed`) |
| `templates/agents/proj-code-writer-*.md` (glob) | Same change applied to templates (glob) | Destructive (per-file three-tier; same sentinel) |

---

## Apply

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: .claude/rules/ missing\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: .claude/agents/ missing\n"; exit 1; }
[[ -d "templates/rules" ]] || { printf "ERROR: templates/rules/ missing — bootstrap repo source-of-truth required\n"; exit 1; }
[[ -d "templates/agents" ]] || { printf "ERROR: templates/agents/ missing\n"; exit 1; }
[[ -f ".claude/agents/proj-plan-writer.md" ]] || { printf "ERROR: proj-plan-writer agent missing — install via /migrate-bootstrap or full bootstrap\n"; exit 1; }
[[ -f "templates/agents/proj-plan-writer.md" ]] || { printf "ERROR: templates/agents/proj-plan-writer.md missing\n"; exit 1; }

# At least one proj-code-writer-* specialist must exist (glob non-empty)
shopt -s nullglob
livewriters=( .claude/agents/proj-code-writer-*.md )
tmplwriters=( templates/agents/proj-code-writer-*.md )
shopt -u nullglob
if [[ ${#livewriters[@]} -eq 0 ]]; then
  printf "WARN: no .claude/agents/proj-code-writer-*.md specialists found — STEP 0 force-read bullet will only land on proj-plan-writer\n"
fi
if [[ ${#tmplwriters[@]} -eq 0 ]]; then
  printf "WARN: no templates/agents/proj-code-writer-*.md specialists found — STEP 0 force-read bullet will only land on plan-writer template\n"
fi

command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
command -v grep >/dev/null 2>&1 || { printf "ERROR: grep required\n"; exit 1; }
```

### Idempotency check (whole-migration)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Whole-migration idempotency: if rule files exist with the v1 sentinel AND every patched
# agent body carries the STEP 0 sentinel, the migration is a no-op. Per-step state is
# checked again inside each step.

ALL_PATCHED=1

# Rule files
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  if [[ ! -f "$rulefile" ]] || ! grep -q "<!-- multi-rollout-v1-installed -->" "$rulefile" 2>/dev/null; then
    ALL_PATCHED=0
    break
  fi
done

# Plan-writer agents
if [[ "$ALL_PATCHED" -eq 1 ]]; then
  for agent in .claude/agents/proj-plan-writer.md templates/agents/proj-plan-writer.md; do
    if [[ ! -f "$agent" ]] || ! grep -q "<!-- multi-rollout-step0-installed -->" "$agent" 2>/dev/null; then
      ALL_PATCHED=0
      break
    fi
  done
fi

# Code-writer agents (glob — both .claude/ and templates/)
if [[ "$ALL_PATCHED" -eq 1 ]]; then
  shopt -s nullglob
  for agent in .claude/agents/proj-code-writer-*.md templates/agents/proj-code-writer-*.md; do
    if ! grep -q "<!-- multi-rollout-step0-installed -->" "$agent" 2>/dev/null; then
      ALL_PATCHED=0
      break
    fi
  done
  shopt -u nullglob
fi

if [[ "$ALL_PATCHED" -eq 1 ]]; then
  printf "SKIP: migration 057 already applied (rule file + STEP 0 bullets present in all targets)\n"
  exit 0
fi

printf "Applying migration 057: multi-rollout rule file (Mode A only) + STEP 0 force-read bullets\n"
```

### Step A — Create `.claude/rules/multi-rollout.md` and `templates/rules/multi-rollout.md`

Additive (new file). Existence-guarded — if the file already exists with the v1 sentinel, SKIP. Otherwise write the file inline via heredoc. Content is byte-identical between `.claude/rules/` and `templates/rules/`.

```bash
#!/usr/bin/env bash
set -euo pipefail

write_rule_file() {
  local target="$1"

  if [[ -f "$target" ]] && grep -q "<!-- multi-rollout-v1-installed -->" "$target" 2>/dev/null; then
    printf "SKIP_ALREADY_APPLIED: %s already contains multi-rollout-v1 rule\n" "$target"
    return 0
  fi

  cat > "$target" <<'RULE_EOF'
# Multi-Rollout Rule (v1 — Mode A Sequential Degraded only)

## Rule
Multi-rollout dispatch (Tier-C parallel code-writer rollouts) operates per the invariants below. v1 ships **Mode A — Sequential Degraded** only. Mode B (parallel) + worktree-dependent Invariants 1/6/7 are OUT OF SCOPE per user decision 2026-04-27 (see `## Out of Scope (v1)`). Sequential mode satisfies `agent-scope-lock.md` single-writer file ownership by design — each rollout completes before the next starts.

## Scope
Applies to:
- `proj-plan-writer` during plan generation (assigns Tier per Invariant 3)
- `/execute-plan` during dispatched execution (reads Tier from batch header; respects classification)
- `proj-code-writer-{lang}` when invoked under Tier-C batches (sequential rollout fan-out)
- `/review` eval-opt CONVERGENCE-QUALITY loop (Invariant 8 — writer re-dispatches forced to Tier-B)

Loaded by force-read in STEP 0 of `proj-plan-writer` and `proj-code-writer-{lang}` (added in Batch 03 of the workflow-improvements migration set).

---

## Invariant 2 — Tier Classification

Concrete rollout count per tier:

| Tier | Rollouts (N) | Use case |
|---|---|---|
| Tier-A | 1 | Single-writer task; standard dispatch; SINGLE-RETRY governs failure |
| Tier-B | 3 | Targeted correction (e.g. `/review` eval-opt fix re-dispatch); modest diversity for refinement |
| Tier-C | 5 | Explorative diversity; high-uncertainty implementation; full rollout fan-out |

Annotation (Mode A): `<!-- RESOURCE-BUDGET: ceiling=5, tier=C, mode=sequential -->`.

Source: `deepen-1-3-multi-rollout-rule.md` (referenced by spec).

---

## Invariant 3 — Tier Classification Ownership

- `proj-plan-writer` assigns `Tier:` field at plan-generation time per Invariant 2.
- `Tier:` MUST appear in the batch header of every plan batch.
- `/execute-plan` reads `Tier:` from the batch header and dispatches accordingly.
- Tier override forbidden inside `/execute-plan` — must be set at planning time.
- Exception: Invariant 8 (`LOOP_INTERACTION_EXCLUSIVE`) overrides Tier classification mechanically inside `/review` eval-opt loop — see Invariant 8.
- A batch missing the `Tier:` field defaults to Tier-A; plan-writer SHOULD emit explicit `Tier: A` rather than rely on default.

---

## Invariant 4 — Selection Precedence

When multiple rollouts complete (sequential or parallel), select the winning rollout by ranked precedence:

1. **PASS** — `proj-verifier` returns PASS. Any rollout that PASSes ranks above any that FAILs.
2. **smallest_diff** — among PASS rollouts, smallest unified diff wins (computed via `git diff --stat`; sum of additions + deletions).
3. **coverage** — tertiary tie-breaker when multiple PASS rollouts produce similar diff sizes (within ~10% of each other); higher test coverage wins.
4. **lint** — final tie-breaker; fewer lint warnings wins.

Mode A (sequential): first rollout that PASSes is accepted immediately + remaining rollouts are NOT dispatched (early-exit). If first rollout FAILs, dispatch next rollout w/ different `angle:` prompt variation; continue up to N. Selection precedence applies among PASS results only — sequential mode typically yields ≤1 PASS rollout, so precedence is most relevant when multiple rollouts complete (e.g. all N exhausted before PASS, then no winner — see Invariant 5).

---

## Invariant 5 — ALL_ROLLOUTS_FAILED Terminal State + Log Format

**Definition:** every rollout `1..N` returns FAIL from `proj-verifier`. No PASS achieved within rollout budget. This is a distinct terminal state — NOT a retry trigger; the orchestrator surfaces this to the user + logs to `plan-quality` category for `/reflect` + `/consolidate` analysis.

**ALL_ROLLOUTS_FAILED log format:**

When all N rollouts fail verification, append to `.learnings/log.md`:

```
### {date} — plan-quality: ALL_ROLLOUTS_FAILED
Batch: {batch-name from batch header}
N: {number of rollouts attempted}
Mode: {sequential-degraded | parallel}
Tier: C
Angles: {comma-separated list of angle values used, e.g. "correctness-first, edge-case-focused, idiomatic-refactor"}
Failures: {N rollout failure summaries, one per line, format: "  rollout-{k}: {first FAIL finding from verifier}"}
Plan: {path to plan file}
```

This format uses the same `plan-quality` category and heading structure as the `<!-- plan-quality-log -->` block in `/review` (review/SKILL.md) and the `SCOPE-VIOLATION` format established there — same `### {date} — plan-quality: {TYPE}` header, same `File:` / `Finding:` / `Review:` field pattern extended for rollout context.

The `Failures:` multi-line field contains one summary per rollout. The `/reflect` + `/consolidate` pipeline keys on the `plan-quality` category header — this format is machine-recognizable by those skills without modification.

Do NOT emit `ALL_ROLLOUTS_FAILED` as a raw `echo` — write to `.learnings/log.md` via bash heredoc append (consistent with existing plan-quality-log pattern in execute-plan near the `<!-- SINGLE-RETRY -->` annotation).

---

## Invariant 8 — LOOP_INTERACTION_EXCLUSIVE

**Rule:** A writer agent dispatched by the `/review` eval-opt CONVERGENCE-QUALITY loop is automatically classified **Tier-B** regardless of the task's original tier classification.

**Rationale and scope:**
The `/review` eval-opt loop fires when the reviewer returns `REQUEST CHANGES` and re-dispatches the code-writer to fix specific findings. This re-dispatch is a targeted correction (specific issues from reviewer findings), NOT an explorative multi-attempt. Running N rollouts of a post-review fix:
  (a) adds 2–4× cost with near-zero quality benefit (the fix is constrained, not explorative)
  (b) can compound with the outer multi-rollout fan-out to produce up to N × cap_review dispatches per original task (worst case: N=3 × CONVERGENCE-QUALITY cap=3 = 9 dispatches; with test-first: up to 45 dispatches)
  (c) violates the semantic boundary between "explorative diversity" (multi-rollout purpose) and "targeted correction" (eval-opt purpose)

**Mechanical guard:**
In the `/review` skill Step 7 writer re-dispatch block:

```
<!-- LOOP_INTERACTION_EXCLUSIVE: writer dispatched from /review eval-opt loop is Tier-B.
     Multi-rollout (Tier-C) MUST NOT activate for this dispatch regardless of batch header.
     Rationale: targeted correction, not explorative diversity — see multi-rollout.md Inv. 8 -->
```

The writer dispatch call MUST include `Tier: B` in the injected context block OR the skill body MUST NOT include the batch header's `Tier:` field in the dispatch context (defaulting to Tier-B behavior per execute-plan's dispatch protocol).

**NOT a loopback annotation label:** `LOOP_INTERACTION_EXCLUSIVE` is a classification guard, not a canonical loopback label. It does not participate in `<!-- RESOURCE-BUDGET: ... -->` or `<!-- CONVERGENCE-QUALITY: ... -->` annotations. It is an inline prose comment that documents the tier override decision. `loopback-budget.md` canonical-4 is preserved: no 5th label is introduced. SINGLE-RETRY's semantic exclusivity (loopback-budget.md line 56) is not violated because this guard operates at the tier-classification layer, not the loopback-annotation layer.

**Cross-reference:** `/review` SKILL.md Step 7 writer re-dispatch block MUST include the `<!-- LOOP_INTERACTION_EXCLUSIVE -->` comment. The implementation migration (multi-rollout + eval-opt) MUST add this comment as part of Step 7 replacement.

---

## Cross-References

- `loopback-budget.md` — canonical-4 labels (LOOPBACK-AUDIT, SINGLE-RETRY, CONVERGENCE-QUALITY, RESOURCE-BUDGET) + Composed Forms grammar; this rule preserves canonical-4 (Invariant 8 is classification, not a loopback label).
- `main-thread-orchestrator.md` — Tier 2 dispatch (multi-rollout fan-out occurs inside dispatched code-writer, not on main); Quick-Fix Carve-Out (single-line edits remain on main, never enter rollout pipeline).
- `agent-scope-lock.md` — Mode A (sequential) satisfies single-writer file ownership by design; Mode B parallel requires worktree isolation (BLOCKED-PENDING — see Out of Scope).
- `wave-iterated-parallelism.md` — `RESOURCE-BUDGET` annotation grammar reused for rollout budget (`ceiling=5, tier=C, mode=sequential`).
- `.claude/skills/review/SKILL.md` — Step 7 eval-opt loop is the LOOP_INTERACTION_EXCLUSIVE consumer; injects `Tier: B` into writer re-dispatch.

---

## Out of Scope (v1)

The following items are deferred per user scope decision 2026-04-27. Re-evaluation requires a fresh deep-think session — do NOT carry forward without that.

1. **Mode B (parallel rollouts)** — concurrent dispatch of N rollouts. Requires `isolation: "worktree"` production-verified on target platform. Current state: BLOCKED-PENDING worktree on win32 (#40164, #43038 open).
2. **Invariant 1 (Rollout Isolation Mode)** — worktree-vs-sequential mode selection logic. v1 hardcodes sequential; mode-selection logic deferred.
3. **Invariant 6 (Pre-warm cache discipline)** — `cache_control` injection for shared-prefix cache amortization across N parallel rollouts. Requires Claude Code harness exposure of `cache_control` parameter (UNDOCUMENTED as of 2026-04-27).
4. **Invariant 7 (Temperature-diversity advisory)** — T≥0.5 elevation for parallel rollout output diversity. Requires harness exposure of `temperature:` Agent tool parameter (UNDOCUMENTED). Mode A uses prompt-angle variation instead — temperature-agnostic.
5. **Worktree dependency** — all worktree-dependent invariants (1, 6 partial, 7 partial) deferred until upstream bugs (#39886, #40164, #43038) close + platform-verification test passes.

User decision 2026-04-27: ship v1 with Mode A only — operational on win32 immediately; defer Mode B + parallel-only invariants until a separate deep-think session re-evaluates the temperature + worktree gating decisions.

<!-- multi-rollout-v1-installed -->
RULE_EOF

  printf "WROTE: %s\n" "$target"
}

write_rule_file ".claude/rules/multi-rollout.md"
write_rule_file "templates/rules/multi-rollout.md"
```

### Step B — Patch `proj-plan-writer` STEP 0 force-read bullet

Three-tier detection per file. Inserts `multi-rollout.md` STEP 0 bullet immediately after the `open-questions-discipline.md` bullet. Anchor differs from code-writer specialists (which use `max-quality.md` as anchor — see Step C).

- **Tier 1 idempotency sentinel**: `<!-- multi-rollout-step0-installed -->` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline anchor**: bullet line `- \`.claude/rules/open-questions-discipline.md\` (if present — open questions surfacing + disposition vocabulary)` present AND `multi-rollout.md` NOT yet in STEP 0 list → safe `PATCHED`
- **Tier 3 neither**: file customized post-bootstrap → `SKIP_HAND_EDITED` + `.bak-057` backup + pointer to `## Manual-Apply-Guide §Step-B`

```bash
#!/usr/bin/env bash
set -euo pipefail

patch_plan_writer() {
  local target="$1"

  python3 - "$target" <<'PY'
import sys
from pathlib import Path

target = Path(sys.argv[1])
backup = Path(str(target) + ".bak-057")

POST_057_SENTINEL = "<!-- multi-rollout-step0-installed -->"
BASELINE_ANCHOR = "- `.claude/rules/open-questions-discipline.md` (if present — open questions surfacing + disposition vocabulary)"
NEW_BULLET = "- `.claude/rules/multi-rollout.md` (if present — multi-rollout invariants for tier classification + selection precedence + LOOP_INTERACTION_EXCLUSIVE classification rule)"

if not target.exists():
    print(f"SKIP_NOT_PRESENT: {target} does not exist (skipping)")
    sys.exit(0)

content = target.read_text(encoding="utf-8")

if POST_057_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {target} STEP 0 already carries multi-rollout bullet (057-B)")
    sys.exit(0)

# Idempotency: if the new bullet text is already present (without sentinel), still treat as applied
if NEW_BULLET in content:
    # Just append the sentinel comment after the bullet
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    new_content = content.replace(NEW_BULLET, NEW_BULLET + " " + POST_057_SENTINEL, 1)
    target.write_text(new_content, encoding="utf-8")
    print(f"PATCHED: {target} bullet present, sentinel appended (057-B)")
    sys.exit(0)

if BASELINE_ANCHOR not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {target} STEP 0 force-read list customized post-bootstrap — open-questions-discipline.md anchor absent. Manual application required. See migrations/057-multi-rollout-rule.md §Manual-Apply-Guide §Step-B. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

REPLACEMENT = BASELINE_ANCHOR + "\n" + NEW_BULLET + " " + POST_057_SENTINEL
new_content = content.replace(BASELINE_ANCHOR, REPLACEMENT, 1)

target.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {target} multi-rollout STEP 0 bullet inserted after open-questions-discipline.md (057-B)")
PY
}

patch_plan_writer ".claude/agents/proj-plan-writer.md"
patch_plan_writer "templates/agents/proj-plan-writer.md"
```

### Step C — Patch globbed `proj-code-writer-*` STEP 0 force-read bullets

Three-tier detection per file. Inserts `multi-rollout.md (if present)` STEP 0 bullet immediately after the `max-quality.md` bullet. Globs ALL `proj-code-writer-*.md` agents in both `.claude/agents/` and `templates/agents/` per `general.md` migration discipline ("Migrations must glob agent filenames — never hardcode `code-writer-{lang}.md`").

- **Tier 1 idempotency sentinel**: `<!-- multi-rollout-step0-installed -->` present → `SKIP_ALREADY_APPLIED`
- **Tier 2 baseline anchor**: bullet line `- \`.claude/rules/max-quality.md\` (doctrine — output completeness > token efficiency; full scope; calibrated effort)` present AND `multi-rollout.md` NOT yet in STEP 0 list → safe `PATCHED`
- **Tier 3 neither**: file customized post-bootstrap → `SKIP_HAND_EDITED` + `.bak-057` backup + pointer to `## Manual-Apply-Guide §Step-C`

```bash
#!/usr/bin/env bash
set -euo pipefail

patch_code_writer() {
  local target="$1"

  python3 - "$target" <<'PY'
import sys
from pathlib import Path

target = Path(sys.argv[1])
backup = Path(str(target) + ".bak-057")

POST_057_SENTINEL = "<!-- multi-rollout-step0-installed -->"
BASELINE_ANCHOR = "- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)"
NEW_BULLET = "- `.claude/rules/multi-rollout.md` (if present — multi-rollout invariants for tier classification + selection precedence + LOOP_INTERACTION_EXCLUSIVE classification rule)"

if not target.exists():
    print(f"SKIP_NOT_PRESENT: {target} does not exist (skipping)")
    sys.exit(0)

content = target.read_text(encoding="utf-8")

if POST_057_SENTINEL in content:
    print(f"SKIP_ALREADY_APPLIED: {target} STEP 0 already carries multi-rollout bullet (057-C)")
    sys.exit(0)

# Idempotency: if the new bullet text is already present (without sentinel), append sentinel
if NEW_BULLET in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    new_content = content.replace(NEW_BULLET, NEW_BULLET + " " + POST_057_SENTINEL, 1)
    target.write_text(new_content, encoding="utf-8")
    print(f"PATCHED: {target} bullet present, sentinel appended (057-C)")
    sys.exit(0)

if BASELINE_ANCHOR not in content:
    if not backup.exists():
        backup.write_text(content, encoding="utf-8")
    print(f"SKIP_HAND_EDITED: {target} STEP 0 force-read list customized post-bootstrap — max-quality.md anchor absent. Manual application required. See migrations/057-multi-rollout-rule.md §Manual-Apply-Guide §Step-C. Backup at {backup}.")
    sys.exit(0)

if not backup.exists():
    backup.write_text(content, encoding="utf-8")

REPLACEMENT = BASELINE_ANCHOR + "\n" + NEW_BULLET + " " + POST_057_SENTINEL
new_content = content.replace(BASELINE_ANCHOR, REPLACEMENT, 1)

target.write_text(new_content, encoding="utf-8")
print(f"PATCHED: {target} multi-rollout STEP 0 bullet inserted after max-quality.md (057-C)")
PY
}

shopt -s nullglob
for agent in .claude/agents/proj-code-writer-*.md templates/agents/proj-code-writer-*.md; do
  patch_code_writer "$agent"
done
shopt -u nullglob
```

### Step D — Companion export with divergence guard

Per `general.md` migration discipline + the canonical companion-export pattern from migration 056: companion export uses LIVE `.claude/` copy (not template) to preserve client customizations. Divergence guard compares `.claude/` vs `templates/`; if diverged, WARN + still export `.claude/` (client's customization is authoritative for companion mirror).

```bash
#!/usr/bin/env bash
set -euo pipefail

LIVE_RULE=".claude/rules/multi-rollout.md"
TMPL_RULE="templates/rules/multi-rollout.md"
LIVE_PLAN_WRITER=".claude/agents/proj-plan-writer.md"
TMPL_PLAN_WRITER="templates/agents/proj-plan-writer.md"

# Resolve companion directory
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"

# Guard: confirm migration patch was applied to LIVE copy (not template only)
if ! grep -q "<!-- multi-rollout-v1-installed -->" "$LIVE_RULE" 2>/dev/null; then
  printf "SKIP companion export: sentinel missing from %s — re-run migration Step A\n" "$LIVE_RULE"
  exit 0
fi
if ! grep -q "<!-- multi-rollout-step0-installed -->" "$LIVE_PLAN_WRITER" 2>/dev/null; then
  printf "SKIP companion export: sentinel missing from %s — re-run migration Step B\n" "$LIVE_PLAN_WRITER"
  exit 0
fi

# Divergence guard for rule file
if [[ -f "$TMPL_RULE" ]] && ! diff -q "$LIVE_RULE" "$TMPL_RULE" >/dev/null 2>&1; then
  printf "WARN: %s diverges from %s\n" "$LIVE_RULE" "$TMPL_RULE"
  printf "      This is expected if you have project-specific customizations.\n"
  printf "      Exporting the LIVE copy (.claude/) to companion — NOT the template.\n"
fi

# Divergence guard for plan-writer agent
if [[ -f "$TMPL_PLAN_WRITER" ]] && ! diff -q "$LIVE_PLAN_WRITER" "$TMPL_PLAN_WRITER" >/dev/null 2>&1; then
  printf "WARN: %s diverges from %s\n" "$LIVE_PLAN_WRITER" "$TMPL_PLAN_WRITER"
  printf "      Exporting the LIVE copy (.claude/) to companion — NOT the template.\n"
fi

if [[ -d "$COMPANION_DIR" ]]; then
  mkdir -p "$COMPANION_DIR/.claude/rules" "$COMPANION_DIR/.claude/agents"
  cp "$LIVE_RULE" "$COMPANION_DIR/.claude/rules/multi-rollout.md"
  cp "$LIVE_PLAN_WRITER" "$COMPANION_DIR/.claude/agents/proj-plan-writer.md"

  # Glob-copy code-writer specialists
  shopt -s nullglob
  for agent in .claude/agents/proj-code-writer-*.md; do
    if grep -q "<!-- multi-rollout-step0-installed -->" "$agent" 2>/dev/null; then
      cp "$agent" "$COMPANION_DIR/.claude/agents/$(basename "$agent")"
    fi
  done
  shopt -u nullglob

  # Verify companion sentinels landed
  if grep -q "<!-- multi-rollout-v1-installed -->" "$COMPANION_DIR/.claude/rules/multi-rollout.md" 2>/dev/null \
     && grep -q "<!-- multi-rollout-step0-installed -->" "$COMPANION_DIR/.claude/agents/proj-plan-writer.md" 2>/dev/null; then
    printf "Companion export: PASS (live multi-rollout rule + plan-writer + code-writer-* exported)\n"
  else
    printf "WARN: Companion export wrote files but sentinels missing — check write permissions on %s\n" "$COMPANION_DIR"
  fi
else
  printf "Companion export: SKIP (no companion dir at %s — project may not use companion sync)\n" "$COMPANION_DIR"
fi
```

### Step E — Migration verification self-test

Verifies that:
1. Rule file present with v1 sentinel in BOTH `.claude/rules/` and `templates/rules/`
2. All 5 Mode A invariants present (2/3/4/5/8)
3. Out-of-scope invariants (1/6/7) NOT present as active invariants — they may appear under `## Out of Scope (v1)` documentation but not as active sections
4. STEP 0 bullet present in plan-writer (live + template) and globbed code-writer specialists

```bash
#!/usr/bin/env bash
# Migration 057 — Self-test
set -euo pipefail

printf "=== Migration 057 self-test ===\n"

# Test 1: rule file exists with v1 sentinel in both copies
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  if [[ ! -f "$rulefile" ]]; then
    printf "FAIL: %s missing\n" "$rulefile"
    exit 1
  fi
  if ! grep -q "<!-- multi-rollout-v1-installed -->" "$rulefile"; then
    printf "FAIL: %s missing v1 sentinel\n" "$rulefile"
    exit 1
  fi
  printf "PASS: %s present with v1 sentinel\n" "$rulefile"
done

# Test 2: all 5 Mode A invariant headings present (2/3/4/5/8)
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  for inv in "Invariant 2 — Tier Classification" "Invariant 3 — Tier Classification Ownership" "Invariant 4 — Selection Precedence" "Invariant 5 — ALL_ROLLOUTS_FAILED Terminal State" "Invariant 8 — LOOP_INTERACTION_EXCLUSIVE"; do
    if ! grep -q "$inv" "$rulefile"; then
      printf "FAIL: %s missing '%s'\n" "$rulefile" "$inv"
      exit 1
    fi
  done
  printf "PASS: %s carries all 5 Mode A invariant headings (2/3/4/5/8)\n" "$rulefile"
done

# Test 3: out-of-scope invariants (1/6/7) NOT present as active invariant sections
# (They may appear under "## Out of Scope (v1)" documentation, but NOT as "## Invariant N — ..." headings.)
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  for forbidden in "^## Invariant 1 —" "^## Invariant 6 —" "^## Invariant 7 —"; do
    if grep -qE "$forbidden" "$rulefile"; then
      printf "FAIL: %s contains forbidden active-invariant heading '%s' (must be Out of Scope only)\n" "$rulefile" "$forbidden"
      exit 1
    fi
  done
  printf "PASS: %s does not carry active Invariant 1/6/7 sections (Out of Scope only)\n" "$rulefile"
done

# Test 4: ALL_ROLLOUTS_FAILED log format includes plan-quality category header
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  if ! grep -q "plan-quality: ALL_ROLLOUTS_FAILED" "$rulefile"; then
    printf "FAIL: %s missing 'plan-quality: ALL_ROLLOUTS_FAILED' log format header\n" "$rulefile"
    exit 1
  fi
  printf "PASS: %s carries plan-quality log format header\n" "$rulefile"
done

# Test 5: STEP 0 bullet present in plan-writer (live + template)
for agent in .claude/agents/proj-plan-writer.md templates/agents/proj-plan-writer.md; do
  if ! grep -q "<!-- multi-rollout-step0-installed -->" "$agent"; then
    printf "FAIL: %s missing multi-rollout-step0-installed sentinel\n" "$agent"
    exit 1
  fi
  if ! grep -q ".claude/rules/multi-rollout.md" "$agent"; then
    printf "FAIL: %s missing multi-rollout.md STEP 0 bullet text\n" "$agent"
    exit 1
  fi
  printf "PASS: %s carries multi-rollout STEP 0 bullet + sentinel\n" "$agent"
done

# Test 6: STEP 0 bullet present in globbed code-writer specialists
shopt -s nullglob
LIVE_WRITERS=( .claude/agents/proj-code-writer-*.md )
TMPL_WRITERS=( templates/agents/proj-code-writer-*.md )
shopt -u nullglob

for agent in "${LIVE_WRITERS[@]}" "${TMPL_WRITERS[@]}"; do
  if ! grep -q "<!-- multi-rollout-step0-installed -->" "$agent"; then
    printf "FAIL: %s missing multi-rollout-step0-installed sentinel\n" "$agent"
    exit 1
  fi
  if ! grep -q ".claude/rules/multi-rollout.md" "$agent"; then
    printf "FAIL: %s missing multi-rollout.md STEP 0 bullet text\n" "$agent"
    exit 1
  fi
  printf "PASS: %s carries multi-rollout STEP 0 bullet + sentinel\n" "$agent"
done

printf "PASS: Migration 057 self-test complete (rule file v1 + STEP 0 bullets across plan-writer + %d code-writer-* specialists)\n" "${#LIVE_WRITERS[@]}"
```

### Step F — Update bootstrap-state.json

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '057'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '057') or a == '057' for a in applied):
    applied.append({
        'id': '057',
        'applied_at': state['last_applied'],
        'description': 'Multi-rollout rule file (Mode A only) — adds .claude/rules/multi-rollout.md with invariants 2/3/4/5/8 (Tier classification, ownership, selection precedence, ALL_ROLLOUTS_FAILED terminal state, LOOP_INTERACTION_EXCLUSIVE classification rule). Adds STEP 0 force-read bullet to proj-plan-writer and globbed proj-code-writer-*.md agents. Mode B (parallel rollouts) + Invariants 1/6/7 (worktree, pre-warm, temperature) explicitly OUT OF SCOPE per user decision 2026-04-27 — operational on win32 immediately.'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=057')
PY

printf "MIGRATION 057 APPLIED\n"
```

### Rules for migration scripts

- **Read-before-write** — every destructive step reads the target file, runs three-tier detection, and only writes on the safe-patch tier. Destructive writes always create `.bak-057` backup before overwrite (per `.claude/rules/general.md` Migration Preservation Discipline).
- **Idempotent** — re-running prints `SKIP_ALREADY_APPLIED` per step and `SKIP: migration 057 already applied` at the top when all sentinels are present in rule files + plan-writer + globbed code-writer specialists across both `.claude/` and `templates/`.
- **Self-contained** — full multi-rollout rule body content + STEP 0 bullet text are inlined via single-quoted heredocs (`<<'RULE_EOF'`, `<<'PY'`) so `${...}` and `` ` `` characters in embedded content ship verbatim. No external fetch.
- **No gitignored-path fetch** — migration body is fully inlined; no fetch from bootstrap repo at runtime.
- **Glob-based agent enumeration** — Step C globs `proj-code-writer-*.md` in both `.claude/agents/` and `templates/agents/` per `general.md` discipline ("Migrations must glob agent filenames — never hardcode `code-writer-{lang}.md`"). Sub-specialists created by `/evolve-agents` automatically receive the same STEP 0 bullet.
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on failure.
- **Scope lock** — touches only: `.claude/rules/multi-rollout.md`, `templates/rules/multi-rollout.md`, `.claude/agents/proj-plan-writer.md`, `templates/agents/proj-plan-writer.md`, globbed `.claude/agents/proj-code-writer-*.md`, globbed `templates/agents/proj-code-writer-*.md`, `.claude/bootstrap-state.json`. No skill body edits, no hook changes, no settings edits, no other agent body changes. `migrations/index.json` is appended BY MAIN THREAD outside this migration body (per `.claude/rules/agent-scope-lock.md`).

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. Rule file present with v1 sentinel in both copies
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  if grep -q "<!-- multi-rollout-v1-installed -->" "$rulefile" 2>/dev/null; then
    printf "PASS: %s carries multi-rollout-v1-installed sentinel\n" "$rulefile"
  else
    printf "FAIL: %s missing multi-rollout-v1-installed sentinel\n" "$rulefile"
    fail=1
  fi
done

# 2. Rule file body contains all 5 Mode A invariant headings (2/3/4/5/8)
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  for inv in "Invariant 2 — Tier Classification" "Invariant 3 — Tier Classification Ownership" "Invariant 4 — Selection Precedence" "Invariant 5 — ALL_ROLLOUTS_FAILED Terminal State" "Invariant 8 — LOOP_INTERACTION_EXCLUSIVE"; do
    if grep -q "$inv" "$rulefile" 2>/dev/null; then
      printf "PASS: %s carries '%s'\n" "$rulefile" "$inv"
    else
      printf "FAIL: %s missing '%s'\n" "$rulefile" "$inv"
      fail=1
    fi
  done
done

# 3. Out-of-scope invariants 1/6/7 NOT present as active sections
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  for forbidden in "^## Invariant 1 —" "^## Invariant 6 —" "^## Invariant 7 —"; do
    if grep -qE "$forbidden" "$rulefile" 2>/dev/null; then
      printf "FAIL: %s contains forbidden active-invariant heading matching '%s' (Mode A only — 1/6/7 are Out of Scope)\n" "$rulefile" "$forbidden"
      fail=1
    else
      printf "PASS: %s does not carry active Invariant heading matching '%s'\n" "$rulefile" "$forbidden"
    fi
  done
done

# 4. Out of Scope section present
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  if grep -q "^## Out of Scope (v1)" "$rulefile" 2>/dev/null; then
    printf "PASS: %s carries Out of Scope (v1) section\n" "$rulefile"
  else
    printf "FAIL: %s missing Out of Scope (v1) section\n" "$rulefile"
    fail=1
  fi
done

# 5. ALL_ROLLOUTS_FAILED log format header present
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  if grep -q "plan-quality: ALL_ROLLOUTS_FAILED" "$rulefile" 2>/dev/null; then
    printf "PASS: %s carries plan-quality: ALL_ROLLOUTS_FAILED log format header\n" "$rulefile"
  else
    printf "FAIL: %s missing plan-quality: ALL_ROLLOUTS_FAILED log format header\n" "$rulefile"
    fail=1
  fi
done

# 6. proj-plan-writer STEP 0 bullet + sentinel
for agent in .claude/agents/proj-plan-writer.md templates/agents/proj-plan-writer.md; do
  if grep -q "<!-- multi-rollout-step0-installed -->" "$agent" 2>/dev/null; then
    printf "PASS: %s carries multi-rollout-step0-installed sentinel\n" "$agent"
  else
    printf "FAIL: %s missing multi-rollout-step0-installed sentinel\n" "$agent"
    fail=1
  fi
  if grep -q ".claude/rules/multi-rollout.md" "$agent" 2>/dev/null; then
    printf "PASS: %s carries multi-rollout.md STEP 0 bullet text\n" "$agent"
  else
    printf "FAIL: %s missing multi-rollout.md STEP 0 bullet text\n" "$agent"
    fail=1
  fi
done

# 7. Globbed proj-code-writer-* STEP 0 bullets + sentinels
shopt -s nullglob
LIVE_WRITERS=( .claude/agents/proj-code-writer-*.md )
TMPL_WRITERS=( templates/agents/proj-code-writer-*.md )
shopt -u nullglob

for agent in "${LIVE_WRITERS[@]}" "${TMPL_WRITERS[@]}"; do
  if grep -q "<!-- multi-rollout-step0-installed -->" "$agent" 2>/dev/null; then
    printf "PASS: %s carries multi-rollout-step0-installed sentinel\n" "$agent"
  else
    printf "FAIL: %s missing multi-rollout-step0-installed sentinel\n" "$agent"
    fail=1
  fi
  if grep -q ".claude/rules/multi-rollout.md" "$agent" 2>/dev/null; then
    printf "PASS: %s carries multi-rollout.md STEP 0 bullet text\n" "$agent"
  else
    printf "FAIL: %s missing multi-rollout.md STEP 0 bullet text\n" "$agent"
    fail=1
  fi
done

# 8. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "057" ]]; then
  printf "PASS: last_migration = 057\n"
else
  printf "FAIL: last_migration = %s (expected 057)\n" "$last"
  fail=1
fi

printf -- "---\n"
if [[ $fail -eq 0 ]]; then
  printf "Migration 057 verification: ALL PASS\n"
  printf "\nOptional cleanup: remove .bak-057 backups once you've confirmed patches are correct:\n"
  printf "  find . -name '*.bak-057' -delete\n"
else
  printf "Migration 057 verification: FAILURES — state NOT updated\n"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix. `SKIP_HAND_EDITED` from any destructive step will cause the corresponding verify-step to FAIL — resolve by applying the relevant `## Manual-Apply-Guide` section, then re-run verify.

---

## State Update

On success:
- `last_migration` → `"057"`
- append `{ "id": "057", "applied_at": "<ISO8601>", "description": "Multi-rollout rule file (Mode A only) — adds .claude/rules/multi-rollout.md with invariants 2/3/4/5/8 (Tier classification, ownership, selection precedence, ALL_ROLLOUTS_FAILED terminal state, LOOP_INTERACTION_EXCLUSIVE classification rule). Adds STEP 0 force-read bullet to proj-plan-writer and globbed proj-code-writer-*.md agents. Mode B (parallel rollouts) + Invariants 1/6/7 (worktree, pre-warm, temperature) explicitly OUT OF SCOPE per user decision 2026-04-27 — operational on win32 immediately." }` to `applied[]`

---

## Idempotency

Re-running after success:
- Top-level — rule files carry v1 sentinel in both `.claude/` and `templates/`; all plan-writer + code-writer agents carry STEP 0 sentinel → `SKIP: migration 057 already applied`
- Step A (rule files) — `<!-- multi-rollout-v1-installed -->` present → per-file `SKIP_ALREADY_APPLIED`
- Step B (plan-writer) — `<!-- multi-rollout-step0-installed -->` present → per-file `SKIP_ALREADY_APPLIED`
- Step C (code-writer glob) — `<!-- multi-rollout-step0-installed -->` present → per-file `SKIP_ALREADY_APPLIED`
- Step D (companion export) — sentinel-guarded; runs only if patches applied
- Step E (self-test) — runs every time; passes deterministically against post-patch state
- Step F (`applied[]` dedup check, migration id == `'057'`) → no duplicate append

No backups are rewritten on re-run. Files that were `SKIP_HAND_EDITED` on first apply remain `SKIP_HAND_EDITED` on re-run (baseline anchors absent + post-migration sentinel absent) — manual merge per `## Manual-Apply-Guide` is still required.

---

## Rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

# Option A — restore from .bak-057 backups (written by destructive steps before overwrite)
for bak in \
  .claude/agents/proj-plan-writer.md.bak-057 \
  templates/agents/proj-plan-writer.md.bak-057; do
  if [[ -f "$bak" ]]; then
    orig="${bak%.bak-057}"
    mv "$bak" "$orig"
    printf "Restored: %s\n" "$orig"
  fi
done

# Glob-restore code-writer specialist backups
shopt -s nullglob
for bak in .claude/agents/proj-code-writer-*.md.bak-057 templates/agents/proj-code-writer-*.md.bak-057; do
  orig="${bak%.bak-057}"
  mv "$bak" "$orig"
  printf "Restored: %s\n" "$orig"
done
shopt -u nullglob

# Remove rule files (newly created by this migration — no backup needed; full removal IS the rollback)
for rulefile in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  if [[ -f "$rulefile" ]] && grep -q "<!-- multi-rollout-v1-installed -->" "$rulefile" 2>/dev/null; then
    rm "$rulefile"
    printf "Removed: %s\n" "$rulefile"
  fi
done

# Option B — tracked strategy (if files are committed to project repo)
# git restore .claude/agents/proj-plan-writer.md templates/agents/proj-plan-writer.md \
#             .claude/agents/proj-code-writer-*.md templates/agents/proj-code-writer-*.md
# git clean -f .claude/rules/multi-rollout.md templates/rules/multi-rollout.md

# Reset bootstrap-state.json
python3 <<'PY'
import json
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') == '057':
    state['last_migration'] = '056'
state['applied'] = [a for a in state.get('applied', []) if not (
    (isinstance(a, dict) and a.get('id') == '057') or a == '057'
)]
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State rolled back to last_migration=056')
PY
```

Notes:
- `.bak-057` restore is safe because each destructive step writes the backup before overwrite. Files that hit `SKIP_HAND_EDITED` (baseline anchor absent) wrote a backup before reporting the skip — the rollback restores the original content.
- After backup restore, the STEP 0 bullets + sentinels appended at insertion sites are gone (the entire pre-migration content is restored from backups). No manual sentinel removal needed.
- The rule files (`.claude/rules/multi-rollout.md`, `templates/rules/multi-rollout.md`) are newly created — full file removal IS the rollback. No backup file is written for these (no pre-migration content existed to back up).

---

## Manual-Apply-Guide

When a destructive step reports `SKIP_HAND_EDITED: <path>`, the migration detected that the target was customized post-bootstrap (baseline anchor absent + post-migration sentinel absent). Automatic patching is unsafe — content would be lost. This guide provides the verbatim new-content blocks plus merge instructions so you can manually integrate the changes while preserving your customizations.

**General procedure per skipped step**:
1. Open the target file.
2. Locate the section / block / anchor named in the merge instructions for that step.
3. Read the new content block below for that step.
4. Manually merge: preserve your project-specific additions (extra steps, custom comments, additional sections); incorporate the new content from the migration.
5. Save the file.
6. Append the post-migration sentinel where indicated (each section below specifies the exact sentinel string).
7. Run the verification snippet shown at the end of each subsection to confirm the patch landed correctly.
8. A `.bak-057` backup of the pre-migration file state exists at `<path>.bak-057`; use `diff <path>.bak-057 <path>` to see exactly what changed.

---

### §Step-A — Multi-rollout rule file (`.claude/rules/multi-rollout.md` + `templates/rules/multi-rollout.md`)

**Target**: NEW FILE — both `.claude/rules/multi-rollout.md` and `templates/rules/multi-rollout.md` did not exist before this migration. If automatic step A failed (rare — only happens if the target directories are missing or read-only), follow these manual steps.

**Context**: this is an additive (new file) operation. There is no pre-existing content to merge with. Manual application copies the verbatim block below into both target paths.

**New content (verbatim — full rule body)**:

```markdown
# Multi-Rollout Rule (v1 — Mode A Sequential Degraded only)

## Rule
Multi-rollout dispatch (Tier-C parallel code-writer rollouts) operates per the invariants below. v1 ships **Mode A — Sequential Degraded** only. Mode B (parallel) + worktree-dependent Invariants 1/6/7 are OUT OF SCOPE per user decision 2026-04-27 (see `## Out of Scope (v1)`). Sequential mode satisfies `agent-scope-lock.md` single-writer file ownership by design — each rollout completes before the next starts.

## Scope
Applies to:
- `proj-plan-writer` during plan generation (assigns Tier per Invariant 3)
- `/execute-plan` during dispatched execution (reads Tier from batch header; respects classification)
- `proj-code-writer-{lang}` when invoked under Tier-C batches (sequential rollout fan-out)
- `/review` eval-opt CONVERGENCE-QUALITY loop (Invariant 8 — writer re-dispatches forced to Tier-B)

Loaded by force-read in STEP 0 of `proj-plan-writer` and `proj-code-writer-{lang}` (added in Batch 03 of the workflow-improvements migration set).

---

## Invariant 2 — Tier Classification

Concrete rollout count per tier:

| Tier | Rollouts (N) | Use case |
|---|---|---|
| Tier-A | 1 | Single-writer task; standard dispatch; SINGLE-RETRY governs failure |
| Tier-B | 3 | Targeted correction (e.g. `/review` eval-opt fix re-dispatch); modest diversity for refinement |
| Tier-C | 5 | Explorative diversity; high-uncertainty implementation; full rollout fan-out |

Annotation (Mode A): `<!-- RESOURCE-BUDGET: ceiling=5, tier=C, mode=sequential -->`.

Source: `deepen-1-3-multi-rollout-rule.md` (referenced by spec).

---

## Invariant 3 — Tier Classification Ownership

- `proj-plan-writer` assigns `Tier:` field at plan-generation time per Invariant 2.
- `Tier:` MUST appear in the batch header of every plan batch.
- `/execute-plan` reads `Tier:` from the batch header and dispatches accordingly.
- Tier override forbidden inside `/execute-plan` — must be set at planning time.
- Exception: Invariant 8 (`LOOP_INTERACTION_EXCLUSIVE`) overrides Tier classification mechanically inside `/review` eval-opt loop — see Invariant 8.
- A batch missing the `Tier:` field defaults to Tier-A; plan-writer SHOULD emit explicit `Tier: A` rather than rely on default.

---

## Invariant 4 — Selection Precedence

When multiple rollouts complete (sequential or parallel), select the winning rollout by ranked precedence:

1. **PASS** — `proj-verifier` returns PASS. Any rollout that PASSes ranks above any that FAILs.
2. **smallest_diff** — among PASS rollouts, smallest unified diff wins (computed via `git diff --stat`; sum of additions + deletions).
3. **coverage** — tertiary tie-breaker when multiple PASS rollouts produce similar diff sizes (within ~10% of each other); higher test coverage wins.
4. **lint** — final tie-breaker; fewer lint warnings wins.

Mode A (sequential): first rollout that PASSes is accepted immediately + remaining rollouts are NOT dispatched (early-exit). If first rollout FAILs, dispatch next rollout w/ different `angle:` prompt variation; continue up to N. Selection precedence applies among PASS results only — sequential mode typically yields ≤1 PASS rollout, so precedence is most relevant when multiple rollouts complete (e.g. all N exhausted before PASS, then no winner — see Invariant 5).

---

## Invariant 5 — ALL_ROLLOUTS_FAILED Terminal State + Log Format

**Definition:** every rollout `1..N` returns FAIL from `proj-verifier`. No PASS achieved within rollout budget. This is a distinct terminal state — NOT a retry trigger; the orchestrator surfaces this to the user + logs to `plan-quality` category for `/reflect` + `/consolidate` analysis.

**ALL_ROLLOUTS_FAILED log format:**

When all N rollouts fail verification, append to `.learnings/log.md`:

​```
### {date} — plan-quality: ALL_ROLLOUTS_FAILED
Batch: {batch-name from batch header}
N: {number of rollouts attempted}
Mode: {sequential-degraded | parallel}
Tier: C
Angles: {comma-separated list of angle values used, e.g. "correctness-first, edge-case-focused, idiomatic-refactor"}
Failures: {N rollout failure summaries, one per line, format: "  rollout-{k}: {first FAIL finding from verifier}"}
Plan: {path to plan file}
​```

This format uses the same `plan-quality` category and heading structure as the `<!-- plan-quality-log -->` block in `/review` (review/SKILL.md) and the `SCOPE-VIOLATION` format established there — same `### {date} — plan-quality: {TYPE}` header, same `File:` / `Finding:` / `Review:` field pattern extended for rollout context.

The `Failures:` multi-line field contains one summary per rollout. The `/reflect` + `/consolidate` pipeline keys on the `plan-quality` category header — this format is machine-recognizable by those skills without modification.

Do NOT emit `ALL_ROLLOUTS_FAILED` as a raw `echo` — write to `.learnings/log.md` via bash heredoc append (consistent with existing plan-quality-log pattern in execute-plan near the `<!-- SINGLE-RETRY -->` annotation).

---

## Invariant 8 — LOOP_INTERACTION_EXCLUSIVE

**Rule:** A writer agent dispatched by the `/review` eval-opt CONVERGENCE-QUALITY loop is automatically classified **Tier-B** regardless of the task's original tier classification.

**Rationale and scope:**
The `/review` eval-opt loop fires when the reviewer returns `REQUEST CHANGES` and re-dispatches the code-writer to fix specific findings. This re-dispatch is a targeted correction (specific issues from reviewer findings), NOT an explorative multi-attempt. Running N rollouts of a post-review fix:
  (a) adds 2–4× cost with near-zero quality benefit (the fix is constrained, not explorative)
  (b) can compound with the outer multi-rollout fan-out to produce up to N × cap_review dispatches per original task (worst case: N=3 × CONVERGENCE-QUALITY cap=3 = 9 dispatches; with test-first: up to 45 dispatches)
  (c) violates the semantic boundary between "explorative diversity" (multi-rollout purpose) and "targeted correction" (eval-opt purpose)

**Mechanical guard:**
In the `/review` skill Step 7 writer re-dispatch block:

​```
<!-- LOOP_INTERACTION_EXCLUSIVE: writer dispatched from /review eval-opt loop is Tier-B.
     Multi-rollout (Tier-C) MUST NOT activate for this dispatch regardless of batch header.
     Rationale: targeted correction, not explorative diversity — see multi-rollout.md Inv. 8 -->
​```

The writer dispatch call MUST include `Tier: B` in the injected context block OR the skill body MUST NOT include the batch header's `Tier:` field in the dispatch context (defaulting to Tier-B behavior per execute-plan's dispatch protocol).

**NOT a loopback annotation label:** `LOOP_INTERACTION_EXCLUSIVE` is a classification guard, not a canonical loopback label. It does not participate in `<!-- RESOURCE-BUDGET: ... -->` or `<!-- CONVERGENCE-QUALITY: ... -->` annotations. It is an inline prose comment that documents the tier override decision. `loopback-budget.md` canonical-4 is preserved: no 5th label is introduced. SINGLE-RETRY's semantic exclusivity (loopback-budget.md line 56) is not violated because this guard operates at the tier-classification layer, not the loopback-annotation layer.

**Cross-reference:** `/review` SKILL.md Step 7 writer re-dispatch block MUST include the `<!-- LOOP_INTERACTION_EXCLUSIVE -->` comment. The implementation migration (multi-rollout + eval-opt) MUST add this comment as part of Step 7 replacement.

---

## Cross-References

- `loopback-budget.md` — canonical-4 labels (LOOPBACK-AUDIT, SINGLE-RETRY, CONVERGENCE-QUALITY, RESOURCE-BUDGET) + Composed Forms grammar; this rule preserves canonical-4 (Invariant 8 is classification, not a loopback label).
- `main-thread-orchestrator.md` — Tier 2 dispatch (multi-rollout fan-out occurs inside dispatched code-writer, not on main); Quick-Fix Carve-Out (single-line edits remain on main, never enter rollout pipeline).
- `agent-scope-lock.md` — Mode A (sequential) satisfies single-writer file ownership by design; Mode B parallel requires worktree isolation (BLOCKED-PENDING — see Out of Scope).
- `wave-iterated-parallelism.md` — `RESOURCE-BUDGET` annotation grammar reused for rollout budget (`ceiling=5, tier=C, mode=sequential`).
- `.claude/skills/review/SKILL.md` — Step 7 eval-opt loop is the LOOP_INTERACTION_EXCLUSIVE consumer; injects `Tier: B` into writer re-dispatch.

---

## Out of Scope (v1)

The following items are deferred per user scope decision 2026-04-27. Re-evaluation requires a fresh deep-think session — do NOT carry forward without that.

1. **Mode B (parallel rollouts)** — concurrent dispatch of N rollouts. Requires `isolation: "worktree"` production-verified on target platform. Current state: BLOCKED-PENDING worktree on win32 (#40164, #43038 open).
2. **Invariant 1 (Rollout Isolation Mode)** — worktree-vs-sequential mode selection logic. v1 hardcodes sequential; mode-selection logic deferred.
3. **Invariant 6 (Pre-warm cache discipline)** — `cache_control` injection for shared-prefix cache amortization across N parallel rollouts. Requires Claude Code harness exposure of `cache_control` parameter (UNDOCUMENTED as of 2026-04-27).
4. **Invariant 7 (Temperature-diversity advisory)** — T≥0.5 elevation for parallel rollout output diversity. Requires harness exposure of `temperature:` Agent tool parameter (UNDOCUMENTED). Mode A uses prompt-angle variation instead — temperature-agnostic.
5. **Worktree dependency** — all worktree-dependent invariants (1, 6 partial, 7 partial) deferred until upstream bugs (#39886, #40164, #43038) close + platform-verification test passes.

User decision 2026-04-27: ship v1 with Mode A only — operational on win32 immediately; defer Mode B + parallel-only invariants until a separate deep-think session re-evaluates the temperature + worktree gating decisions.

<!-- multi-rollout-v1-installed -->
```

NOTE: Triple-backticks in the verbatim block above are shown as `​```` (with zero-width space markers) to prevent the surrounding code-fence from breaking. When you copy the block, replace `​```` with plain ```` ``` ````.

**Merge instructions**:
1. Create the file `.claude/rules/multi-rollout.md` with the verbatim content above.
2. Create the file `templates/rules/multi-rollout.md` with the SAME verbatim content (byte-identical).
3. The sentinel `<!-- multi-rollout-v1-installed -->` is the LAST line of the file — confirm it is present.
4. Save both files.

**Verification**:
```bash
for f in .claude/rules/multi-rollout.md templates/rules/multi-rollout.md; do
  grep -q "<!-- multi-rollout-v1-installed -->" "$f" && printf "PASS sentinel: %s\n" "$f"
  grep -q "Invariant 8 — LOOP_INTERACTION_EXCLUSIVE" "$f" && printf "PASS Invariant 8: %s\n" "$f"
  grep -q "## Out of Scope (v1)" "$f" && printf "PASS Out-of-Scope section: %s\n" "$f"
done
```

---

### §Step-B — proj-plan-writer STEP 0 force-read bullet (`.claude/agents/proj-plan-writer.md` + `templates/agents/proj-plan-writer.md`)

**Target**: insert the `multi-rollout.md` STEP 0 force-read bullet immediately after the `open-questions-discipline.md` bullet in the plan-writer's STEP 0 force-read list.

**Context**: the migration detected that the file's STEP 0 force-read list has been customized post-bootstrap — the baseline anchor `- \`.claude/rules/open-questions-discipline.md\` (if present — open questions surfacing + disposition vocabulary)` is not present in stock form.

**Stock content to find** (the open-questions-discipline.md bullet):

```
- `.claude/rules/open-questions-discipline.md` (if present — open questions surfacing + disposition vocabulary)
```

**Replace with (verbatim — adds new bullet immediately after)**:

```
- `.claude/rules/open-questions-discipline.md` (if present — open questions surfacing + disposition vocabulary)
- `.claude/rules/multi-rollout.md` (if present — multi-rollout invariants for tier classification + selection precedence + LOOP_INTERACTION_EXCLUSIVE classification rule) <!-- multi-rollout-step0-installed -->
```

**Merge instructions**:
1. Open the target file (`.claude/agents/proj-plan-writer.md` AND `templates/agents/proj-plan-writer.md` — apply the same change to both).
2. Locate the STEP 0 force-read list (under `## STEP 0 — Load critical rules (MANDATORY first action)`).
3. Find the bullet that references `open-questions-discipline.md`. Insert a new bullet immediately after it, with the exact text shown in the replacement block above.
4. The sentinel `<!-- multi-rollout-step0-installed -->` is part of the new bullet (at end of line); do not add a separate sentinel.
5. Save the file.

**Verification**:
```bash
for f in .claude/agents/proj-plan-writer.md templates/agents/proj-plan-writer.md; do
  grep -q "<!-- multi-rollout-step0-installed -->" "$f" && printf "PASS sentinel: %s\n" "$f"
  grep -q ".claude/rules/multi-rollout.md" "$f" && printf "PASS bullet: %s\n" "$f"
done
```

---

### §Step-C — proj-code-writer-* STEP 0 force-read bullets (globbed)

**Target**: insert the `multi-rollout.md (if present)` STEP 0 force-read bullet immediately after the `max-quality.md` bullet in EACH `proj-code-writer-*.md` agent's STEP 0 force-read list. Apply to ALL specialists in BOTH `.claude/agents/proj-code-writer-*.md` and `templates/agents/proj-code-writer-*.md` globs.

**Context**: the migration detected that one or more code-writer agent's STEP 0 force-read list has been customized post-bootstrap — the baseline anchor `- \`.claude/rules/max-quality.md\` (doctrine — output completeness > token efficiency; full scope; calibrated effort)` is not present in stock form.

**Stock content to find** (the max-quality.md bullet):

```
- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)
```

**Replace with (verbatim — adds new bullet immediately after)**:

```
- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)
- `.claude/rules/multi-rollout.md` (if present — multi-rollout invariants for tier classification + selection precedence + LOOP_INTERACTION_EXCLUSIVE classification rule) <!-- multi-rollout-step0-installed -->
```

**Merge instructions**:
1. Glob ALL `proj-code-writer-*.md` agents in BOTH `.claude/agents/` and `templates/agents/`.
2. For each agent file: locate the STEP 0 force-read list (under `## STEP 0 — Load critical rules (MANDATORY first action)`).
3. Find the bullet that references `max-quality.md`. Insert a new bullet immediately after it, with the exact text shown in the replacement block above.
4. The sentinel `<!-- multi-rollout-step0-installed -->` is part of the new bullet (at end of line); do not add a separate sentinel.
5. Save each file.
6. Repeat for every specialist in the glob — bash, markdown, and any sub-specialists created by `/evolve-agents`.

**Verification** (run after applying to ALL globbed agents):
```bash
shopt -s nullglob
for f in .claude/agents/proj-code-writer-*.md templates/agents/proj-code-writer-*.md; do
  if grep -q "<!-- multi-rollout-step0-installed -->" "$f"; then
    printf "PASS sentinel: %s\n" "$f"
  else
    printf "FAIL sentinel: %s\n" "$f"
  fi
  if grep -q ".claude/rules/multi-rollout.md" "$f"; then
    printf "PASS bullet: %s\n" "$f"
  else
    printf "FAIL bullet: %s\n" "$f"
  fi
done
shopt -u nullglob
```

---

## Post-Apply — Bootstrap Repo Self-Update

This migration targets client projects. The bootstrap repo's own `.claude/` copies are
generated output, not source of truth. To update the bootstrap repo's installed copies:

1. Run `/migrate-bootstrap` against the bootstrap repo itself, OR re-run each step manually against the bootstrap repo's `.claude/` (the templates at `templates/rules/multi-rollout.md`, `templates/agents/proj-plan-writer.md`, and `templates/agents/proj-code-writer-*.md` are already in the target state after the paired bootstrap edits — Step A + Step B + Step C patch the templates directly alongside the live copies).
2. Do NOT directly edit any of those files in the bootstrap repo's `.claude/` directory — direct edits bypass the templates and create drift.

Reference: `.claude/rules/general.md` §Process — "NEVER write to this repo's `.claude/` as implementation work."

---

## Post-Migration (main-thread only per agent-scope-lock.md)

Append to `migrations/index.json`:
```json
{
  "id": "057",
  "file": "057-multi-rollout-rule.md",
  "title": "Multi-rollout rule file — Mode A operational invariants",
  "description": "Adds multi-rollout.md rule file with Mode A invariants (Tier classification, selection precedence, ALL_ROLLOUTS_FAILED terminal state, LOOP_INTERACTION_EXCLUSIVE classification rule). Adds STEP 0 force-read bullet to plan-writer and globbed code-writer agents. Mode B (parallel rollouts) explicitly out of scope; Invariants 1/6/7 (worktree, pre-warm, temperature) dropped per user scope decision.",
  "applies_to": "bootstrapped projects with multi-step plans (plan-writer + code-writers)",
  "added_date": "2026-04-27"
}
```
