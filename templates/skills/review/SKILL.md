---
name: review
description: >
  Use when completing a task, before committing, or to verify code quality.
  Dispatches proj-code-reviewer agent for thorough review.
allowed-tools: Agent Read Write
model: opus
effort: xhigh
# Skill Class: main-thread — dispatches proj-code-reviewer, interactive fix loop
---

## /review — Request Code Review

## Pre-flight (REQUIRED — before any other step)

**Blocking agents** (STOP if missing — review cannot proceed without these):
- `proj-code-reviewer` — If `.claude/agents/proj-code-reviewer.md` does NOT exist → STOP.
  Tell user: "Required agent proj-code-reviewer missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

**Optional agents** (WARN if missing — review proceeds; eval-opt fix loop degrades gracefully):
- `proj-code-writer-{lang}` — If no `.claude/agents/proj-code-writer-*.md` exists →
  WARN: "No code-writer specialist found. /review will run but the eval-opt fix loop
  (Step 7) will skip automatic fix dispatch. Run /evolve-agents to create a specialist."
  Continue with Step 1.

## Dispatch Map
- Code review: `proj-code-reviewer`
- Fix dispatch (eval-opt loop): `proj-code-writer-{lang}` (OPTIONAL — dynamic glob;
  non-blocking; gracefully absent)

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Steps
1. `git diff` — identify changed files
2. Read `.claude/references/techniques/INDEX.md` (if exists) → pick relevant technique files
3. Dispatch agent via `subagent_type="proj-code-reviewer"` w/:
   - Changed files list + change summary
   - Applicable code standards from `.claude/rules/`
   - Relevant technique ref paths
   - Write review to `.claude/reports/review-{timestamp}.md`
   - Return path + summary
4. Read review report
5. Files in `.claude/` (agents/skills/rules): flag full-sentence prose, missing RCCF, articles/filler → severity WARNING
5.5 Open Questions Discipline check (main-thread structural grep — `.claude/rules/open-questions-discipline.md` line 44)

Main thread performs this check after reviewer returns, before presenting results to user.

Glob — find recent research + spec files in current branch's spec dir:
  recent=$(find .claude/specs/{branch}/ -maxdepth 2 \( -name "*-research.md" -o -name "*-spec.md" \) -mtime -7 2>/dev/null)

For each {file}:
  (a) research findings (`*-research.md`): check `grep -q "## Open Questions" {file}`. Absent → WARNING: "research findings {file} missing `## Open Questions` section (contract violation — open-questions-discipline.md Research Output Contract)".
  (b) spec files (`*-spec.md`): check `grep -q "## Open Questions" {file}`. Absent → WARNING: "spec {file} missing `## Open Questions` section — orchestrator may have bypassed triage (open-questions-discipline.md Orchestrator Obligation)".
  (c) spec files WITH section: check `grep -qE "USER_DECIDES|AGENT_RECOMMENDS|AGENT_DECIDED" {file}`. Zero disposition labels → WARNING: "spec {file} has `## Open Questions` section but entries lack disposition classification (USER_DECIDES|AGENT_RECOMMENDS|AGENT_DECIDED)".

Append findings to review report under heading `### Open Questions Discipline`. Zero findings → report "Open Questions discipline: no issues detected across {N} recent research/spec files". If no recent files exist (greenfield work, no research phase) → skip silently.

Rationale: structural grep — not LLM judgment. Catches the drift pattern where orchestrator writes spec/plan without surfacing open questions. Does NOT catch subtle judgment calls (those are inherent to the problem class and caught by orchestrator discipline, not review).

<!-- plan-quality-log -->
5.6 **plan-quality logging on scope findings:** if the review report contains any finding about files changed OUTSIDE the listed batch scope (scope-lock violation per `.claude/rules/agent-scope-lock.md`) OR any missing-from-plan edit (file touched that no task listed in its `#### Files` section) — append a structured entry to `.learnings/log.md` under the `plan-quality` category, one per distinct offending file:
```
### {date} — plan-quality: SCOPE-VIOLATION
File: {absolute or project-relative file path}
Finding: {scope-lock-violation | missing-from-plan}
Review: {.claude/reports/review-{timestamp}.md path}
```
Detection: grep the review report for the phrases `scope-lock violation`, `outside listed scope`, `not listed in batch`, or `missing from plan`. Each match → one log entry keyed on the file path cited in the finding. Zero matches → skip this substep silently. Category `plan-quality` is shared with `/write-plan` post-dispatch-audit entries and `/execute-plan` batch-fail entries (see those skills for sibling entry formats). This means `/review` auto-logs scope-creep incidents during post-execution review, closing the planning → execution → review loop so the `/reflect` + `/consolidate` pipeline has ground-truth signal on scope discipline without manual triage.

5.7 **Wave Protocol Discipline check** (per `.claude/rules/wave-iterated-parallelism.md` § Enforcement)

Main thread performs this check after reviewer returns, before presenting results to user. Scope: every reviewed agent body containing `### Wave Protocol`.

For each agent body in the review scope (`.claude/agents/*.md`) that contains `### Wave Protocol`:
  (a) **Wave 1 parallelism** — verify Wave 1 reads were issued as one batched parallel message, not serial. Detection: scan the wave block for "Wave 1" + "batch ALL" / "in one parallel message" / "batch reads in one parallel message" instructional language; if Wave 1 instructions describe sequential reads ("Read A, then Read B"), flag as serial. WARNING: "Wave 1 in {agent} reads serially — must batch in one parallel message".
  (b) **Shape declaration** — verify wave block contains explicit `TASK_SHAPE:` record line (e.g. `Record: TASK_SHAPE: SINGLE_LAYER | WAVE_CAP: 2`). Absent → WARNING: "wave block in {agent} missing TASK_SHAPE/WAVE_CAP record".
  (c) **GAP item format** — if the wave block contains `GAP:` example lines: verify each carries `(target: ...)` field. Missing target field → WARNING: "GAP item in {agent} missing `(target:)` field — required by GAP Dedup Requirement".
  (d) **Escalation log format** — if `Shape upgraded` appears in the wave block: verify both `{trigger:` AND `{evidence:` placeholder fields appear in the log line. Missing either → WARNING: "escalation log in {agent} missing `{trigger:}` or `{evidence:}` field — must use amended placeholder per wave-iterated-parallelism.md § Shape Escalation".

Append findings to review report under heading `### Wave Protocol Discipline`. Zero findings → report `Wave protocol discipline: no issues detected`. No agent bodies in scope contain `### Wave Protocol` → skip this substep silently (greenfield review or content not yet retrofitted).

Rationale: structural grep — not LLM judgment. Catches the drift pattern where wave block instructions describe `### Wave Protocol` heading but omit the parallel-batch instruction (Wave 1 shows multiple reads must be in ONE message), drop the shape declaration, or use the pre-amended condensed `{evidence}` form. `/review` is the enforcement layer per `.claude/rules/wave-iterated-parallelism.md` § Enforcement.
<!-- Wave 1 shows multiple reads -->

6. Present review results to user
7. Evaluator-optimizer loop <!-- CONVERGENCE-QUALITY: cap=3, signal=APPROVE -->

   **Pre-flight gate (before loop):**
   - `proj-code-reviewer` absent → STOP (blocking — already enforced by pre-flight gate above)
   - `proj-code-writer-{lang}` absent → WARN only (non-blocking — loop degrades to manual path below)
   - `loopback-budget.md` absent → WARN: "migration 050 required for CONVERGENCE-QUALITY annotation"

   **Loop state:** `iter=0`

   **Loop body** (repeat while `verdict == FIX_REQUIRED` AND `iter < 3`):
   a. Increment: `iter=$((iter + 1))`
   b. Parse `flagged_files:` from the reviewer's handoff block at end of report:
      ```bash
      REPORT_FILE=".claude/reports/review-{timestamp}.md"  # path returned by reviewer
      # Extract handoff block (HTML comment sentinels)
      HANDOFF=$(sed -n '/<!-- handoff-v1-start -->/,/<!-- handoff-v1-end -->/p' "$REPORT_FILE" | grep -v '<!--')
      # Extract verdict (single line: "verdict: FIX_REQUIRED" or "verdict: APPROVE")
      VERDICT=$(printf '%s\n' "$HANDOFF" | grep '^verdict:' | awk '{print $2}')
      # Extract severity class
      SEVERITY=$(printf '%s\n' "$HANDOFF" | grep '^severity_class:' | awk '{print $2}')
      # Extract flagged files list (YAML list items: "  - path/to/file.md")
      FLAGGED=$(printf '%s\n' "$HANDOFF" | grep '^\s*-\s' | sed 's/^\s*-\s*//')
      ```
      If handoff block is absent (model error, instruction drift): fall through to manual path;
      do NOT attempt prose fallback extraction (absent handoff = no scope-locked file list;
      dispatching writer without scope = scope-lock violation per agent-scope-lock.md).
   c. If `VERDICT == APPROVE` → exit loop (done)
   d. If `VERDICT == FIX_REQUIRED` AND `SEVERITY == MUST_FIX`:
      - If no `proj-code-writer-{lang}` specialist exists → **manual path**: present findings to user;
        offer to re-review after manual fix; EXIT loop
      - If specialist(s) exist:
        - Detect `{lang}` from flagged file extensions using filename-suffix primary detection:
          ```bash
          # Build extension → specialist mapping from available agents (filename-suffix primary)
          # No scope: field is present on any proj-code-writer-*.md agent — do NOT read frontmatter
          declare -A EXT_TO_WRITER
          for agent in .claude/agents/proj-code-writer-*.md; do
            lang=$(basename "$agent" .md | sed 's/proj-code-writer-//')
            case "$lang" in
              bash)       EXT_TO_WRITER[sh]="$lang"; EXT_TO_WRITER[bash]="$lang" ;;
              markdown)   EXT_TO_WRITER[md]="$lang" ;;
              python)     EXT_TO_WRITER[py]="$lang" ;;
              typescript) EXT_TO_WRITER[ts]="$lang" ;;
              csharp)     EXT_TO_WRITER[cs]="$lang" ;;
              *)          EXT_TO_WRITER["$lang"]="$lang" ;;
            esac
          done

          # Collect distinct writer names needed for flagged files
          declare -A DISPATCH_LANGS
          while IFS= read -r fpath; do
            [[ -z "$fpath" ]] && continue
            ext="${fpath##*.}"
            writer="${EXT_TO_WRITER[$ext]:-}"
            [[ -n "$writer" ]] && DISPATCH_LANGS["$writer"]="1"
          done <<< "$FLAGGED"
          ```
        - For each detected `{lang}` in `DISPATCH_LANGS` (sequential — one writer per language):
          <!-- LOOP_INTERACTION_EXCLUSIVE: writer dispatched from /review eval-opt loop is Tier-B.
               Multi-rollout (Tier-C) MUST NOT activate for this dispatch regardless of batch header.
               Rationale: targeted correction, not explorative diversity.
               See multi-rollout.md Invariant 8. -->
          - Confirm `.claude/agents/proj-code-writer-{lang}.md` exists (skip if absent)
          - Dispatch `proj-code-writer-{lang}` via `subagent_type="proj-code-writer-{lang}"` with:
            - Scope: ONLY files in `$FLAGGED` matching this lang's extensions
              (treat as `#### Files` equivalent — scope-lock contract)
            - Context: full review report path + MUST FIX findings extracted from report
            - Tier: B (override — Invariant 8 of multi-rollout.md; do NOT pass Tier: C)
            - If writer returns `SCOPE EXPANSION NEEDED` → surface to user immediately;
              EXIT loop; do NOT re-dispatch reviewer
          - If `DISPATCH_LANGS` is empty (no specialist matches any flagged extension) →
            **manual path**: present review findings to user; offer to re-review after
            manual fix; EXIT loop
        - Re-dispatch `proj-code-reviewer` with same inputs as Step 3 + loop_turn injected:
          `"This is review iteration {iter} of 3. loop_turn: {iter}."`
        - Read new review report; update `VERDICT` + `SEVERITY` from new handoff block
   e. If `VERDICT == FIX_REQUIRED` AND `SEVERITY != MUST_FIX` (SHOULD_FIX or STYLE only) →
      present findings to user; EXIT loop (loop only fires on MUST_FIX)

   **Loop exit — iter == 3 AND verdict still `FIX_REQUIRED`:**
   Present final state to user: "3 review iterations reached without APPROVE — manual
   intervention required. Final review: {report_path}. Remaining issues: {FLAGGED files}."

<!-- review-eval-opt-loop-installed -->

### Anti-Hallucination
- Only reference rules that exist
- Only cite lines that exist
- Per `multi-rollout.md` Invariant 8, any code-writer dispatched from this skill's eval-opt
  loop (Step 7) is Tier-B regardless of the original task's tier. Multi-rollout (Tier-C)
  MUST NOT activate for eval-opt loop writer dispatches. The `<!-- LOOP_INTERACTION_EXCLUSIVE -->`
  comment in Step 7 is the machine-readable marker of this constraint. If `multi-rollout.md`
  exists in `.claude/rules/`, it is authoritative. If absent (migration 057 not yet applied),
  the inline comment governs.
