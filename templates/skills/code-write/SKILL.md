---
name: code-write
description: >
  Use when asked to implement, write, create, or modify code. Routes to the
  appropriate proj-code-writer-{lang} agent based on file type and scope. Dynamic
  discovery — globs .claude/agents/proj-code-writer-*.md for available specialists.
allowed-tools: Agent Read
model: opus
effort: high
paths: "modules/**,techniques/**,.claude/skills/**,.claude/agents/**,.claude/hooks/**"
# Skill Class: main-thread — dispatches proj-code-writer-{lang}, no inline code work
---

## /code-write — Implementation Dispatcher

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Code generation: `proj-code-writer-{lang}` (dynamic — discovered via glob of `.claude/agents/proj-code-writer-*.md`)

NOTE: Module 07 (Code Specialists) overrides this spec with the full routing version.
This placeholder applies contract + pre-flight + dispatch-map; Module 07 fills routing logic.

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Placeholder Behavior (until Module 07 completes)
1. Accept implementation request from user
2. Glob `.claude/agents/proj-code-writer-*.md` → list available specialists
3. If `agent-index.yaml` exists → read for scope/routing info
4. No specialists found → STOP per pre-flight gate. Tell user: "Run Module 07 (Code Specialists) to generate proj-code-writer-{lang} agents." NEVER fall back to inline.
5. Specialists found → read `scope:` field from matching agent frontmatter → dispatch via `subagent_type="proj-code-writer-{lang}"` best match w/ implementation request

### Post-Module 07 Behavior (filled by Module 07)
1. Read `.claude/skills/code-write/references/capability-index.md` → routing table
2. Read `.claude/skills/code-write/references/pipeline-traces.md` → change patterns
3. Classify request by: file extension, framework, architecture layer
4. Route to best-match via `subagent_type="proj-code-writer-{lang}"` (or sub-specialist if exists)
5. Multi-file changes spanning languages → dispatch multiple specialists sequentially
6. Each specialist must leave build passing

### Dynamic Discovery (always)
- Glob `.claude/agents/proj-code-writer-*.md` → find all specialists
- Read `scope:` from each → build routing table at dispatch time
- New specialists auto-discovered w/o skill changes

### Anti-Hallucination
- NEVER dispatch to agent that doesn't exist — glob first
- NEVER assume language from file content alone — check extension + project manifests
- No matching specialist → STOP per pre-flight gate. Tell user to run `/evolve-agents` to create the missing specialist. NEVER fall back to inline execution.
