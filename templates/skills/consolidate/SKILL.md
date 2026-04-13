---
name: consolidate
description: >
  Use when session start reports CONSOLIDATE_DUE=true, or when manually
  invoked. Reviews raw learnings, merges duplicates, resolves contradictions,
  promotes/prunes instincts. Dispatches proj-reflector.
allowed-tools: Agent Read Write
model: opus
effort: high
# Skill Class: main-thread — dispatches proj-reflector, interactive consolidation approval
---

## /consolidate — Learning Consolidation

Dispatch agent via `subagent_type="proj-reflector"` for analysis. Main thread applies approved changes.

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Learning cluster analysis: `proj-reflector`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Phase 1: Orient
Read: `.learnings/log.md`, `.learnings/instincts/`, `.learnings/patterns.md`, `MEMORY.md`

### Phase 2: Gather
Dispatch agent via `subagent_type="proj-reflector"` w/ all learnings paths:
- Scan corrections, decisions, recurring themes
- Cluster by domain (code-style | testing | git | debugging | security | architecture | tooling)
- Identify instinct candidates (2+ similar corrections)
- Identify reinforcements (+0.1) | contradictions (-0.05)
- Write analysis to `.claude/reports/consolidation-proposals.md`
- Return path + summary

### Phase 2b: Cluster Review Findings
Filter log: `category == review-finding`, `status == pending review`
Group by `Agent:` tag → cluster by `Pattern:` similarity
- Cluster w/ 2+ entries → promotion candidate (target: agent's Known Gotchas)
- Single-entry → flag as one-off, schedule for pruning

Output: promotion candidates + one-offs list

### Phase 3: Consolidate
Present proposals to user:
- New instincts (initial confidence 0.5)
- Existing instincts to reinforce | contradict
- Duplicates to merge; contradictions to resolve
- Review-finding promotions (from Phase 2b):
  Show: agent name, pattern, evidence count, proposed text
  Choices: promote to agent Known Gotchas | dismiss | defer
  If `/evolve-agents` flagged → surface recommendation (don't auto-execute)

Apply approved changes.

### Phase 4: Prune + Promote
- Confidence 0.8+ → propose promotion to `.claude/rules/`
- Confidence <0.3 → archive | remove
- Clear processed entries from `log.md`
- Keep instinct index lean

### Phase 5: Update Tracking
- `date +%s` → `.learnings/.last-dream`
- Reset `.learnings/.session-count` to 0
- Write entry count → `.learnings/.last-reflect-lines`

### Anti-Hallucination
- Only analyze entries that exist
- Never invent patterns
- Require 2+ similar before creating instinct
