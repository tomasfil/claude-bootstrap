---
name: reflect
description: >
  Use when asked to review learnings, improve the development environment,
  audit configuration, evolve agents, or optimize .claude/ setup.
  Run when SessionStart reports REFLECT_DUE=true. Dispatches proj-reflector.
allowed-tools: Agent Read Write
model: opus
effort: high
# Skill Class: main-thread — dispatches proj-reflector, interactive proposal approval
---

## /reflect — Self-Improvement Protocol

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Learning analysis + proposals: `proj-reflector`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Step 1: Dispatch reflector
Dispatch agent via `subagent_type="proj-reflector"` w/ paths:
- `.learnings/log.md` — pending entries
- `.learnings/instincts/` — instinct files (if exists)
- `.learnings/observations.jsonl` — tool usage patterns
- `.learnings/agent-usage.log` — agent usage data
- `CLAUDE.md` — rules + conventions
- `.claude/rules/` — standards
- `.claude/agents/` — agents + descriptions
- For each `proj-code-writer-*` + `proj-test-writer-*` agent: check evolution heuristics:
  1. Line count (`wc -l`) — >500 = evolution candidate
  2. Classification tree branches — 3+ top-level framework branches = candidate
  3. Framework-specific corrections in `.learnings/log.md` — 3+ for same framework
  4. Dispatch count from `.learnings/agent-usage.log` — 10+ dispatches = mature enough
  5. Sub-specialists: check version drift (project manifest versions vs agent's Stack section)
  6. Sub-specialist research staleness — reference files older than 90 days
- `.claude/references/techniques/INDEX.md` — pick relevant techniques for evaluation
- User memory: `~/.claude/projects/` (project-specific MEMORY.md)
- Write proposals to `.claude/reports/reflect-proposals.md`
- Return path + summary

Fallbacks:
- `.learnings/instincts/` missing → use `log.md` only
- `.claude/references/techniques/` missing → skip technique refs

### Step 2: Present Proposals (main thread)
Read proposals → group by category:
- **Rules changes**: add/update rule in {file} — reason
- **Agent changes**: create/retire/improve agent — reason
- **Agent evolution candidates** (detect only — user runs `/evolve-agents`):
  evolve/update {name} — reason → recommend `/evolve-agents`
- **CLAUDE.md changes**: add gotcha, update convention, move to @import
- **Learnings promotion**: promote/dismiss — reason

Wait for user approval per proposal.

### Step 3: Apply Approved Changes (main thread)
1. Update `CLAUDE.md`, rules, agents as approved
2. Mark promoted entries in `.learnings/log.md` → `promoted` w/ destination
3. Mark dismissed entries → `dismissed` w/ reason
4. New skills/agents → update `settings.json` routing if needed

### Step 4: Instinct Health Report
IF `.learnings/instincts/` exists → analyze:
- Total count, confidence distribution, domain breakdown
- Prune candidates (confidence <0.3), promotion candidates (confidence 0.8+ → `.claude/rules/`)

IF missing → skip.

### Step 4b: CMM Broken-Tools Catalog Update (auto — post-dispatch)

Runs only when `.claude/cmm-baseline.md` exists AND `codebase-memory-mcp` registered in `.mcp.json`. Skip entirely otherwise.

1. Scan `.learnings/log.md` entries since last `/reflect` run (delimiter: `.learnings/.last-reflect-lines` byte offset) for lines matching regex `cmm\.\w+` in `failure | gotcha | correction` categories
2. Extract unique cmm tool names + one-line failure summary per tool
3. Read existing `.claude/cmm-baseline.md` `## Known-broken tools` section — collect already-listed tool names to avoid duplicates
4. For each cmm tool NOT already in baseline: present to user as a proposed addition:
   ```
   Proposed cmm-baseline broken-tool addition:
     tool: cmm.{name}
     summary: {one-line cluster summary}
     evidence: {N} learnings entries since last reflect
     proposed line: - cmm.{name}: {summary}  # learned {date}, fallback: {suggest or TBD}
   [approve / reject / defer]
   ```
5. Approved → Edit `.claude/cmm-baseline.md` directly, append line to `## Known-broken tools` section in the proposed format
6. Rejected → no change, log rejection reason in `.learnings/log.md` as `gotcha: cmm broken-tool proposal rejected — {reason}`
7. Deferred → no change, no log entry, re-propose next `/reflect` run

Proposal-only workflow — user confirms each addition individually. Never auto-applies. Never auto-deletes existing entries.

Skip silently when baseline file absent OR cmm not registered. No error, no user-facing message.

### Report
```
Learnings: {N} promoted, {M} dismissed, {P} pending
Rules: {N} added, {M} updated
Agents: {N} created, {M} retired, {P} improved
CLAUDE.md: {N} changes
File sizes: within budget? (CLAUDE.md <120, rules <40, agents <500)
Instincts: {total}, {prune}, {promote} (omit if no instincts dir)
```

### Update Tracking
Write entry count → `.learnings/.last-reflect-lines`

### Gotchas
- `.learnings/instincts/` may not exist — check before reading
- Single-occurrence corrections → DO NOT promote; require 2+ similar
- Agent usage data may be empty if hook unwired — check first
- Reflect proposes evolution — NEVER auto-splits; user runs `/evolve-agents`

### Anti-Hallucination
- READ before modifying — verify log entries exist before marking
- Confirm paths exist before writing
- Count entries via `grep -c` — never estimate
- Proposing agent changes → verify agent file exists first
- NEVER claim rule added w/o reading target file to confirm

### Companion Repo Integration
If `git_strategy == "companion"`:
- After applying changes → run `sync-config.sh export`
- Print: "Changes synced to companion repo"
- Remind: "Run `/sync push` to push to remote"
