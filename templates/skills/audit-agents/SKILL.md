---
name: audit-agents
description: >
  Use when auditing agents for missing force-read blocks, MCP tool propagation
  issues, skill anti-patterns, or rule file gaps. Dispatches
  proj-consistency-checker with a widened audit brief.
allowed-tools: Agent Read
model: opus
effort: xhigh
# Skill Class: main-thread — dispatches proj-consistency-checker, interactive report review
---

## /audit-agents — Agent Rules + MCP Propagation Audit

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Audit report: `proj-consistency-checker`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Scope
Validates that every sub-agent reliably loads critical rules + MCP tools propagate
correctly. Does NOT auto-patch — produces a report; user decides on fixes.

### Dispatch

Dispatch agent via `subagent_type="proj-consistency-checker"` w/ audit task brief:

- **A1 — STEP 0 force-read presence**: for every `.claude/agents/*.md` (exclude
  `references/` subtree), verify body contains marker `STEP 0 — Load critical rules`.
  Report agents missing the marker w/ `file:line` evidence (line = frontmatter close).
- **A2 — Rule file existence**: parse every `.claude/rules/<name>.md` reference
  inside STEP 0 blocks. Verify each referenced file exists in `.claude/rules/`.
  Report dangling refs w/ source agent + rule path.
- **A3 — MCP tool propagation**: if `.mcp.json` exists — parse `mcpServers` keys.
  For every agent w/ an explicit `tools:` line, verify one `mcp__<server>__*` entry
  exists per server key. Report missing entries w/ agent + missing server name.
  No `.mcp.json` → skip A3 w/ INFO.
- **A4 — Skill anti-pattern**: scan every `.claude/skills/*/SKILL.md` frontmatter
  `allowed-tools:` value. FAIL if any value contains `mcp__*` (skills must not
  name MCP tools directly — MCPs belong on agents). Report offenders w/ file:line.
- **A5 — CLAUDE.md imports**: verify `CLAUDE.md` exists at project root and
  `@import`s `general.md` + `skill-routing.md`. If `.mcp.json` present, also
  verify `@import .claude/rules/mcp-routing.md`. Report missing imports.
- **A6 — cmm index status**: if `.mcp.json` configures a cmm-compatible MCP
  (serena, code-context, etc.), verify repo is indexed (server-specific probe
  or presence of index artifacts). Absent cmm MCP → skip w/ WARN.

### A7: effort:xhigh justification presence check
For each `.claude/agents/*.md`:
  IF frontmatter contains `effort: xhigh`:
    Verify the immediately following line matches `^# xhigh: `  (any text after the colon).
    FAIL if no such line exists.
    WARN if line matches `^# xhigh: INHERITED_DEFAULT` (tracked debt marker).
  Do NOT validate the token vocabulary against an enum — presence-only check.

For each `.claude/skills/*/SKILL.md`:
  IF frontmatter contains `effort: xhigh`:
    Check `# Skill Class:` comment for "dispatch", "orchestrat", or "synthesis" keywords.
    IF present → self-justified, no additional check required.
    ELSE → require `^# xhigh: ` comment line; FAIL if absent.

Output: append A7 section to the audit report markdown.

### Output

Agent writes YAML-ish report to `.claude/reports/audit-agents-{timestamp}.md`
via Bash heredoc. Format:

```yaml
audit: agent-rules-mcp
timestamp: {ISO8601}
checks:
  A1_force_read:   {PASS|FAIL|SKIP}
  A2_rule_exists:  {PASS|FAIL|SKIP}
  A3_mcp_tools:    {PASS|FAIL|SKIP}
  A4_skill_mcp:    {PASS|FAIL|SKIP}
  A5_claude_md:    {PASS|FAIL|SKIP}
  A6_cmm_index:    {PASS|WARN|SKIP}
  A7_effort_high_justified: {PASS|FAIL|WARN|SKIP}
findings:
  - check: A1
    severity: FAIL
    evidence: "{file}:{line}"
    detail: "{what's missing}"
```

Return: report path + 1-line summary (PASS count / FAIL count / WARN count).
Agent does NOT auto-patch — reports only. Main thread presents findings to user.

### After the agent returns

Read the report. Surface any FAIL entries to the user with file:line evidence
and a one-line fix recommendation per category:
- A1 FAIL → run `/migrate-bootstrap` (re-applies migration 011 STEP 0 retrofit)
- A2 FAIL → create missing rule file or remove dangling reference from STEP 0 block
- A3 FAIL → run `/migrate-bootstrap` (re-applies migration 001 MCP propagation)
- A4 FAIL → remove `mcp__*` from skill `allowed-tools:` — MCP belongs in agents
- A5 FAIL → add missing `@import` lines to CLAUDE.md
- A6 WARN → index the repo (cmm/serena) or ignore if MCP unused
- A7 FAIL → add `# xhigh: <TOKEN>` justification comment immediately after `effort: xhigh` in agent frontmatter, or add it after `effort: xhigh` in skill frontmatter when `# Skill Class:` lacks "dispatch"/"orchestrat"/"synthesis" keywords; run `/migrate-bootstrap` if migration 029 is pending
- A7 WARN → `INHERITED_DEFAULT` is tracked debt; revisit classification per `techniques/agent-design.md` Skill Class → Model Binding

Do NOT auto-patch. User approves fixes.

### Anti-hallucination
Only cite files that exist; only report line numbers via actual grep output;
uncertain check → SKIP not FAIL; no speculation about MCP servers not declared
in `.mcp.json`.
