---
name: brainstorm
description: >
  Use when asked to design, plan, explore, think through, or brainstorm a
  feature, component, or change. Always brainstorm before implementing
  non-trivial changes. Absorbs /spec — when requirements clear, skips
  exploration and produces spec directly. Dispatches proj-researcher.
  For problems needing multi-pass adversarial gap-hunting (spans ≥2
  architectural layers, unclear constraints, iterative refinement until
  no HIGH-severity critiques remain) → use /deep-think instead.
allowed-tools: Agent Read Write
model: opus
effort: xhigh
# Skill Class: main-thread — interactive clarification + research dispatch + spec write
---

## /brainstorm — Design Before Build

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Research: `proj-researcher`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Decision Tree
- Requirements clear + well-defined → skip to Step 5 (spec output)
- Requirements unclear | complex | multiple approaches → full exploration
- Problem spans ≥2 architectural layers OR needs adversarial gap-hunting → use `/deep-think` instead

### Full Exploration Flow
1. Clarify request — one question per message, prefer multiple choice
2. Dispatch agent via `subagent_type="proj-researcher"` w/:
   - Exploration scope (architecture, patterns, prior art)
   - Write findings to `.claude/specs/{branch}/{date}-{topic}-research.md`
   - Return path + summary
3. Read research findings
3.5 Triage open questions (force, before approaches):
   - Read `## Open Questions` section from research findings
   - Present each question verbatim w/ disposition classification
   - `USER_DECIDES` → BLOCK on Step 4 until user resolves; no approach proposal until cleared
   - `AGENT_RECOMMENDS` → state recommended default + rationale; user vetoes next turn if wanted
   - `AGENT_DECIDED` → state transparently in handoff message (evidence-grounded, low-consequence)
   - Silent disposition (skipping an item, collapsing to a hidden default) = rule violation
   - If research findings have no `## Open Questions` section (legacy researcher output) → extract candidate questions from Summary / Patterns / Recommendations prose + classify manually
4. Propose 2-3 approaches w/ trade-offs + recommendation. Present section by section — get approval after each
5. Save spec → `.claude/specs/{branch}/{date}-{topic}-spec.md`. Specs use compressed telegraphic notation
6. Transition → invoke `/write-plan`

### Knowledge Base
Read `.claude/references/techniques/INDEX.md` (if exists) → pick relevant technique files. Starting-point knowledge, not definitive.

### DO NOT
- Write code until user approves design
- Propose against imagined codebase — ground in researcher findings

### Spec Output Format
```
# {Topic} Spec
## Problem / Goal
## Constraints
## Approach (approved)
## Components (files, interfaces, data flow)
## Open Questions
{triaged items w/ disposition: USER_DECIDES | AGENT_RECOMMENDS | AGENT_DECIDED; resolved items preserved for traceability}
- id: {OQ-short-slug}
  question: {one sentence}
  disposition: {USER_DECIDES | AGENT_RECOMMENDS | AGENT_DECIDED}
  evidence: {file:line OR URL OR "no evidence — user input required"}
  recommendation: {required iff AGENT_RECOMMENDS}
  resolution: {filled when resolved — e.g., "user chose option B" | "agent decision confirmed" | "deferred to /write-plan"}
```

### Anti-Hallucination
- Verify all referenced files/components exist before including in proposals
- Don't reference APIs, patterns, or frameworks not present in the project
