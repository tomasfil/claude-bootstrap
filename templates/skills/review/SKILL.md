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

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Code review: `proj-code-reviewer`

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
7. Issues found → fix → re-review

### Anti-Hallucination
- Only reference rules that exist
- Only cite lines that exist
