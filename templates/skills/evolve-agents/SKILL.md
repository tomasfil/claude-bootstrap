---
name: evolve-agents
description: >
  Use when auditing agents for staleness, adding specialists for new frameworks,
  refreshing agent knowledge after dependency upgrades, or when /reflect
  recommends evolution. Post-bootstrap only — audit + create-new, NOT split.
  Dispatches proj-researcher and proj-code-writer-markdown.
allowed-tools: Agent Read Write
model: opus
effort: xhigh
# Skill Class: main-thread — multi-dispatch research + creation pipeline
---

## /evolve-agents — Agent Audit + New Specialist Creation

v6: agents are born right-sized. This skill audits + creates NEW, never splits.

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Phase 3 research: `proj-researcher` (local deep-dive + web research)
- Phase 3 agent generation: `proj-code-writer-markdown`
- Phase 5 refresh: `proj-researcher` + `proj-code-writer-markdown`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Phase 1: Audit Existing Specialists
For each `.claude/agents/proj-code-writer-*.md` + `proj-test-writer-*.md`:
1. **Version drift**: compare project manifest versions (`package.json`, `*.csproj`, `pyproject.toml`, `go.mod`, `Cargo.toml`) against agent's Role+Stack section
2. **Reference staleness**: reference files older than 90 days
3. **Missing patterns**: accumulated corrections in `.learnings/log.md` for this agent's scope
4. **Dispatch frequency**: `.learnings/agent-usage.log` — retire if unused for N sessions

### Phase 2: Detect New Frameworks
Compare Module 01 discovery (or re-scan project manifests) against existing agents:
- New language added since bootstrap → needs `proj-code-writer-{lang}`
- New framework added to existing language → may need sub-specialist

### Phase 3: Create New Specialists (if needed)
Same pipeline as Module 07:
1. Dispatch agent via `subagent_type="proj-researcher"` → local deep-dive + web research for new framework
   Write to `.claude/skills/code-write/references/{lang}-{framework}-analysis.md`
2. Dispatch agent via `subagent_type="proj-researcher"` → web research (latest patterns, security, gotchas)
   Write to `.claude/skills/code-write/references/{lang}-{framework}-research.md`
3. Dispatch agent via `subagent_type="proj-code-writer-markdown"` → generate agent from research references
   Write to `.claude/agents/proj-code-writer-{lang}-{framework}.md`

### Phase 4: Update Index
Read all agent frontmatter → regenerate `.claude/agents/agent-index.yaml`
Update `.claude/skills/code-write/references/capability-index.md`

### Phase 5: Refresh Stale Agents (if flagged in Phase 1)
- Re-dispatch via `subagent_type="proj-researcher"` for updated web research
- Dispatch via `subagent_type="proj-code-writer-markdown"` to update agent w/ new findings
- Preserve agent's accumulated Known Gotchas section

### Report
```
Audited: {N} agents
Stale: {list w/ reason}
Created: {list of new agents}
Refreshed: {list}
Retired: {list}
Index updated: yes/no
```

### Anti-Hallucination
- NEVER split existing agents — create NEW sub-specialists instead
- Verify agent files exist before modifying
- Verify framework actually exists in project before creating specialist
- Use glob for agent filenames — never hardcode specific names
