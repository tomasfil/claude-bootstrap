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
