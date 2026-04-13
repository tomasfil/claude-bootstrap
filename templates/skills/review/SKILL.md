---
name: review
description: >
  Use when completing a task, before committing, or to verify code quality.
  Dispatches proj-code-reviewer agent for thorough review.
allowed-tools: Agent Read Write
model: opus
effort: high
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
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
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
6. Present review results to user
7. Issues found → fix → re-review

### Anti-Hallucination
- Only reference rules that exist
- Only cite lines that exist
