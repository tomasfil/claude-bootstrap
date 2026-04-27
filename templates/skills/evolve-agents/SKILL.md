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
disable-model-invocation: true
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

After all 4 audit checks complete, the dispatched proj-researcher agent MUST write a persistent audit artifact via Bash heredoc:

```bash
mkdir -p .claude/reports
cat > .claude/reports/evolve-agents-audit-latest.md <<'AUDIT_EOF'
# /evolve-agents Audit — {ISO8601 timestamp}

## Version Drift Findings
{per-agent findings}

## Reference Staleness Findings
{per-reference findings}

## Missing-Pattern Findings
{per-agent findings from .learnings/log.md}

## Dispatch Frequency Findings
{per-agent usage counts from .learnings/agent-usage.log}

## Gate Complete
AUDIT_EOF
```

The trailing `## Gate Complete` heading is REQUIRED — Phase 3 pre-flight gate greps for it as the artifact integrity check. A missing or truncated artifact fails the gate.

### Phase 2: Detect New Frameworks
Compare Module 01 discovery (or re-scan project manifests) against existing agents:
- New language added since bootstrap → needs `proj-code-writer-{lang}`
- New framework added to existing language → may need sub-specialist

### Phase 3: Create New Specialists (if needed)
Same pipeline as Module 07:

Before dispatching, run the pre-flight gate (Bash):

```bash
ARTIFACT=".claude/reports/evolve-agents-audit-latest.md"
if [[ ! -f "$ARTIFACT" ]]; then
  echo "BLOCK: No audit artifact found. Run /evolve-agents Phase 1 first (or pass --skip-audit-gate)."
  exit 1
fi
if ! grep -q "^## Gate Complete" "$ARTIFACT"; then
  echo "BLOCK: Audit artifact missing Gate Token (truncated write?). Re-run Phase 1."
  exit 1
fi
STALE_AGENTS=$(find .claude/agents/ -type f \( -name 'proj-code-writer-*.md' -o -name 'proj-test-writer-*.md' \) -newer "$ARTIFACT" 2>/dev/null)
if [[ -n "$STALE_AGENTS" ]]; then
  echo "WARN: Agent files modified after audit artifact — consider re-running Phase 1:"
  echo "$STALE_AGENTS"
fi
```
<!-- evolve-agents-gate-installed -->

Gate PASS (no exit 1) → proceed to dispatch steps.

1. Dispatch agent via `subagent_type="proj-researcher"` → local deep-dive + web research for new framework
   Write to `.claude/skills/code-write/references/{lang}-{framework}-analysis.md`
2. Dispatch agent via `subagent_type="proj-researcher"` → web research (latest patterns, security, gotchas)
   Write to `.claude/skills/code-write/references/{lang}-{framework}-research.md`
3. Dispatch agent via `subagent_type="proj-code-writer-markdown"` → generate agent from research references
   Write to `.claude/agents/proj-code-writer-{lang}-{framework}.md`

   Dispatch prompt MUST include this block (triggers proj-code-writer-markdown Before Writing step 5):

   ```
   #### Reference Files
   Read these before writing:
   - `templates/skills/evolve-agents/references/agent-creation-brief.md` — agent conformance checklist + required sections; governs the generated agent's structure
   - `.claude/skills/code-write/references/markdown-analysis.md` — component classification table, tools whitelists, frontmatter field spec
   ```

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

---

## Deviations from spec

Backing spec: `.claude/specs/2026-04-01-evolve-agents.md` (per `covers-skill:` convention defined in `.claude/rules/spec-fidelity.md`).

The deployed skill diverges from the original spec in two documented respects. Both are classified INTENTIONAL per the 2026-04-27 deep-think (round-0-evidence.md + 1.3 E6 finding):

### Deviation 1 — v6 paradigm shift (audit + create-NEW, never split)

- **Spec form**: 2026-04-01 spec described an "audit + split" semantics — when an existing agent grew too large for its scope, the skill would split it into multiple narrower specialists.
- **Deployed form**: v6 paradigm — agents are born right-sized; the skill audits + creates NEW sub-specialists for new frameworks/languages but NEVER splits existing agents.
- **Rationale**: split semantics created two failure modes — (a) loss of accumulated `Known Gotchas` content during the split, and (b) a chicken-and-egg dispatch problem where the splitting agent needed to predict the future scope of its own children. Create-NEW with right-sized initial spec is the correct shape; split is retired.
- **Classification**: INTENTIONAL — present in the FIRST commit of evolve-agents/SKILL.md (2026-04-01); the spec was the inferior design and was superseded at implementation time without an explicit deviation note. Backfilled here per 1.3 E6 finding.

### Deviation 2 — Step 3 (user-approval gate) and Step 6 (wiring) absent

- **Spec form**: 2026-04-01 spec described 6 sequential steps including a user-approval gate at Step 3 (after Phase 1 audit, before Phase 3 creation) and a wiring step at Step 6 (post-creation, registers the new agent into all dispatch maps).
- **Deployed form**: 5 phases; no explicit user-approval gate phase; wiring is folded into Phase 4 (Update Index — regenerates `agent-index.yaml` and `capability-index.md`).
- **Rationale**: The user-approval gate at Step 3 is replaced by the more general Phase 3 pre-flight gate (added by migration 055; see `.claude/rules/evolve-agents-gate.md`) — the gate enforces freshness via persistent audit artifact rather than blocking on user input. Wiring is correctly absorbed into the index-regeneration phase because the index files ARE the wiring (skills + agents discover each other through these indices).
- **Classification**: INTENTIONAL — both gaps were design simplifications, not regressions. The pre-flight gate is a stronger discipline than a one-time approval prompt (it persists across re-runs); the index-regeneration is the wiring (no separate registration step needed).

<!-- evolve-agents-deviations-installed -->
