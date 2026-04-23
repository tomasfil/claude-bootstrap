---
name: ci-triage
description: >
  Use when CI/CD pipeline fails, build breaks in CI, or asked to investigate
  automated test/build failures. Reads CI output, identifies root cause via proj-debugger.
allowed-tools: Agent Read Write Bash
model: opus
effort: xhigh
# Skill Class: main-thread — needs Bash for `gh run view`, dispatches proj-debugger
---

## /ci-triage — CI Failure Investigation

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Root-cause analysis: `proj-debugger`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Steps
1. Get CI output — user provides URL or paste, or fetch via gh:
   ```bash
   gh run view {run-id} --log-failed 2>/dev/null
   gh api repos/{owner}/{repo}/actions/runs/{run-id}/jobs --jq '.jobs[] | select(.conclusion=="failure")'
   ```
2. Parse failure: extract error messages, failing tests, exit codes
3. Classify: build error | test failure | lint error | deploy error | infra/timeout
4. Dispatch agent via `subagent_type="proj-debugger"` w/:
   - CI output (relevant section only, not full log)
   - Classification + hypothesis
   - Local reproduction command
   - Write diagnosis to `.claude/reports/ci-triage-{timestamp}.md`
   - Return path + summary
5. Read diagnosis → present to user w/ fix recommendation
6. Fix is clear → apply fix + verify locally before suggesting commit

### Anti-Hallucination
- Reproduce locally before claiming fix
- Never assume CI environment matches local — check for env-specific issues
- Only classify failures actually present in CI output
- CI output truncated → say so, don't fill in gaps
