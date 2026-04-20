---
name: tdd
description: >
  Use when implementing a feature or bugfix where writing tests first improves
  confidence. Red-green-refactor cycle with test-driven development.
allowed-tools: Agent Read Write
model: opus
effort: high
# Skill Class: main-thread — dispatches proj-tdd-runner, synthesizes results
---

## /tdd — Red-Green-Refactor

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Red-Green-Refactor cycle: `proj-tdd-runner`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Steps
Dispatch agent via `subagent_type="proj-tdd-runner"` w/:
- Feature/behavior specification from user
- Test conventions path: `.claude/rules/code-standards-{lang}.md`
- Build command: {build_command}
- Test single command: {test_single_command}
- Test suite command: {test_suite_command}
- Write results to `.claude/reports/tdd-{timestamp}.md`
- Return path + summary

### TDD Cycle (within agent)
- **RED** — write test describing expected behavior → run → must FAIL
- **GREEN** — write minimum code to pass → run → must PASS
- **REFACTOR** — clean up w/ tests green → run after each step
- Repeat per behavior/scenario

### Anti-Hallucination
- Read existing tests first → match conventions
- Test passes immediately → not testing new behavior, rethink
- Verify types/methods referenced in tests actually exist (LSP or Grep)
