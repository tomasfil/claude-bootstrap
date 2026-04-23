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
  recent=$(find .claude/specs/{branch}/ -maxdepth 2 -name "*-research.md" -o -name "*-spec.md" -mtime -7 2>/dev/null)

For each {file}:
  (a) research findings (`*-research.md`): check `grep -q "## Open Questions" {file}`. Absent → WARNING: "research findings {file} missing `## Open Questions` section (contract violation — open-questions-discipline.md Research Output Contract)".
  (b) spec files (`*-spec.md`): check `grep -q "## Open Questions" {file}`. Absent → WARNING: "spec {file} missing `## Open Questions` section — orchestrator may have bypassed triage (open-questions-discipline.md Orchestrator Obligation)".
  (c) spec files WITH section: check `grep -qE "USER_DECIDES|AGENT_RECOMMENDS|AGENT_DECIDED" {file}`. Zero disposition labels → WARNING: "spec {file} has `## Open Questions` section but entries lack disposition classification (USER_DECIDES|AGENT_RECOMMENDS|AGENT_DECIDED)".

Append findings to review report under heading `### Open Questions Discipline`. Zero findings → report "Open Questions discipline: no issues detected across {N} recent research/spec files". If no recent files exist (greenfield work, no research phase) → skip silently.

Rationale: structural grep — not LLM judgment. Catches the drift pattern where orchestrator writes spec/plan without surfacing open questions. Does NOT catch subtle judgment calls (those are inherent to the problem class and caught by orchestrator discipline, not review).
6. Present review results to user
7. Issues found → fix → re-review

### Anti-Hallucination
- Only reference rules that exist
- Only cite lines that exist
