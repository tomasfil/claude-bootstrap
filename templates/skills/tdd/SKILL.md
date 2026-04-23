---
name: tdd
description: >
  Use when implementing a feature or bugfix where writing tests first improves
  confidence. Red-green-refactor cycle with test-driven development.
allowed-tools: Agent Read Write
model: opus
effort: xhigh
# Skill Class: main-thread — three-phase orchestrator, dispatches proj-quick-check + proj-tdd-runner + /review
---

## /tdd — Red-Green-Refactor

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

Agent existence check list:
- `proj-quick-check` — required for Phase 1 triage
- `proj-tdd-runner` — required for Phase 2 TDD cycle

## Dispatch Map
- Triage: `proj-quick-check`
- Red-Green-Refactor cycle: `proj-tdd-runner`
- Post-TDD review: `/review` (via Skill tool, STATUS: GREEN only)

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Steps

#### Phase 1 — Triage (proj-quick-check)

Dispatch `subagent_type="proj-quick-check"` w/ a 4-field structured brief to determine whether the feature is already test-covered before entering the TDD cycle.

Brief fields (triage agent must return these exact keys):
- `TEST_FILE_EXISTS`: `yes|no` — does any test file plausibly cover the feature's module/component?
- `FEATURE_IN_TESTS`: `yes|no` — does any existing test reference the specific feature / behavior / symbol?
- `COVERAGE_SIGNAL`: `full|partial|none` — context enrichment only (NOT used in stop condition)
- `TEST_FILE_PATH`: `<path>|null` — path to most-relevant existing test file, or null

Binary stop condition (TRIVIALLY_COVERED):
- `TEST_FILE_EXISTS=yes AND FEATURE_IN_TESTS=yes` → emit advisory: "Feature already tested at {TEST_FILE_PATH}. TRIVIALLY_COVERED. Proceed with Phase 2 only if adding new behavior beyond what existing tests assert." → exit skill.
- Any other combination → proceed to Phase 2.

Note: `COVERAGE_SIGNAL` is context enrichment for the user (shown in advisory output when relevant), NOT part of the stop condition. Do not gate Phase 2 on coverage strength.

#### Phase 2 — TDD cycle (proj-tdd-runner)

Dispatch `subagent_type="proj-tdd-runner"` w/:
- Feature/behavior specification from user
- Test conventions path: `.claude/rules/code-standards-{lang}.md`
- Build command: {build_command}
- Test single command: {test_single_command}
- Test suite command: {test_suite_command}
- Write results to `.claude/reports/tdd-{timestamp}.md`
- Return path + summary

**Return contract**: proj-tdd-runner MUST emit `STATUS: GREEN` (all tests pass, refactor clean) OR `STATUS: RED` (tests failing or skipped) as the FIRST LINE of its return summary. Phase 3 routes on this exact token — no prose parsing, no inference.

#### Phase 3 — Review (/review via Skill tool, GREEN only)

Parse first line of Phase 2 return summary:
- `STATUS: GREEN` → invoke `/review` via Skill tool to run code-reviewer over the TDD changes before handoff to user.
- `STATUS: RED` → skip /review. Report RED status + TDD report path to user. Do NOT invoke /review on failing code — reviewer findings are meaningless against broken tests.

### TDD Cycle (within Phase 2 agent)
- **RED** — write test describing expected behavior → run → must FAIL
- **GREEN** — write minimum code to pass → run → must PASS
- **REFACTOR** — clean up w/ tests green → run after each step
- Repeat per behavior/scenario

### Anti-Hallucination
- Read existing tests first → match conventions
- Test passes immediately → not testing new behavior, rethink
- Verify types/methods referenced in tests actually exist (LSP or Grep)
- Phase 1 triage must use structured 4-field return; never synthesize field values without file:line evidence
- Phase 3 routing is strict string match on `STATUS: GREEN` — do NOT invoke /review on ambiguous / missing status line
