---
name: debug
description: >
  Use when encountering a bug, test failure, unexpected behavior, or error.
  Dispatches proj-quick-check for triage, then proj-debugger for root cause analysis.
allowed-tools: Agent Read Write
model: opus
effort: xhigh
# Skill Class: main-thread — multi-dispatch orchestrator, interactive synthesis
---

## /debug — Systematic Investigation

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Phase 1 triage: `proj-quick-check`
- Phase 2 root-cause: `proj-debugger`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Phase 1: Triage
Dispatch agent via `subagent_type="proj-quick-check"` w/ error message/symptom.
Read text response → determine severity + likely area.

### Phase 2: Deep investigation
Dispatch agent via `subagent_type="proj-debugger"` w/:
- Symptom description + proj-quick-check findings
- Error output, affected files
- Write diagnosis to `.claude/reports/debug-{timestamp}.md`
- Return path + summary

Debugger follows 4 phases:
1. **Reproduce**: identify symptom, find minimal reproduction, capture exact error
2. **Locate**: read error, trace call stack, identify divergence point
3. **Diagnose**: why wrong result, which assumption violated, classify error type. Check `.learnings/log.md` for similar past issues
4. **Fix**: write reproducing test (TDD red), fix root cause, verify pass, run regression

### Anti-Hallucination
- DO NOT propose fix before Locate phase complete
- DO NOT guess root cause — trace actual execution
- After 2 failed fix attempts → search web for known issues
- Log to `.learnings/log.md` if pattern discovered
