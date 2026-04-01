# Module 05 — Create /reflect Skill

> The self-improvement engine. Reviews learnings, evolves agents, audits rules, manages plugins.

---

## Idempotency

```
IF exists → READ, EXTRACT project-specific content, REGENERATE with current template + extracted knowledge
IF missing → CREATE
IF obsolete/superseded → DELETE
```

## Create Skill

```bash
mkdir -p .claude/skills/reflect
```

Write `.claude/skills/reflect/SKILL.md`:

```yaml
---
name: reflect
description: >
  Self-improvement skill. Use when asked to review learnings, improve the
  development environment, audit configuration, evolve agents, check for
  plugin updates, or optimize the .claude/ setup. Run periodically to
  promote learnings and keep the environment sharp.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Grep, Glob, Bash
model: opus
effort: high
---
```

```markdown
## /reflect — Self-Improvement Protocol

### Step 1: Dispatch Agent
Dispatch `reflector` agent w/ paths:
- `.learnings/log.md` — pending entries
- `.learnings/instincts/` — instinct files (if exists)
- `.learnings/observations.jsonl` — tool usage patterns
- `.learnings/agent-usage.log` — agent usage data
- `CLAUDE.md` — rules + conventions
- `.claude/rules/` — standards
- `.claude/agents/` — agents + descriptions
- `.claude/references/techniques/INDEX.md` — read index → pick relevant techniques for evaluating proposals
- User memory: `~/.claude/projects/` (project-specific MEMORY.md)

Read all sources → analyze learnings → check agent usage → validate file sizes → return grouped proposals.

> **Fallback:** `.learnings/instincts/` missing → use `log.md` only for instinct analysis.
> **Fallback:** `.claude/references/techniques/` missing → skip technique refs, use general knowledge.

### Step 2: Present Proposals (main thread)
Group proposed changes by category:

**Rules changes:**
- [ ] Add rule: {rule} to {file} — because: {reason}
- [ ] Update rule: {old} -> {new} in {file}

**Agent changes:**
- [ ] Create agent: {name} — triggered by {pattern} appearing {N} times
- [ ] Retire agent: {name} — unused in last {N} sessions
- [ ] Improve agent: {name} — {what to change}

**CLAUDE.md changes:**
- [ ] Add gotcha: {gotcha}
- [ ] Update convention: {convention}
- [ ] Move content to @import: {what}

**Learnings promotion:**
- [ ] Promote: {learning} -> {destination}
- [ ] Dismiss: {learning} — reason: {why}

Wait for user approval | modification | rejection per proposal.

### Step 3: Apply Approved Changes (main thread)
1. Update CLAUDE.md, rules, agents as approved
2. Mark promoted entries in `.learnings/log.md` → `promoted` w/ destination
3. Mark dismissed entries → `dismissed` w/ reason
4. New skills | agents created → update UserPromptSubmit hook in `.claude/settings.json`

### Step 4: Instinct Health Report
IF `.learnings/instincts/` exists → analyze + report:
- **Total count** + **confidence distribution** (histogram | ranges)
- **Domain breakdown** — count per domain tag
- **Prune candidates** — confidence <0.3 → propose removal
- **Promotion candidates** — confidence 0.8+ → propose promotion to `.claude/rules/`

IF missing → skip step.

### Report
Print summary:
- Learnings: {N} promoted, {M} dismissed, {P} pending
- Rules: {N} added, {M} updated
- Agents: {N} created, {M} retired, {P} improved
- CLAUDE.md: {N} changes applied
- File sizes: within budget? (CLAUDE.md <120, rules <40, agents <500)
- Instincts: {total} total, {prune} prune, {promote} promote (omit if no instincts dir)

### Gotchas
- `.learnings/instincts/` may not exist — check before reading
- Single-occurrence corrections → DO NOT promote to rules; require 2+ similar entries
- Agent usage data may be empty if SubagentStop hook unwired — check first
- Routing hook in settings.json must update when creating new skills | agents

### Anti-Hallucination
- READ before modifying — verify `.learnings/log.md` entries exist before marking promoted | dismissed
- Confirm paths exist before writing (e.g., `.learnings/instincts/` dir)
- Count log entries via `grep -c` — never estimate
- Proposing agent changes → verify agent file exists on disk first
- NEVER claim rule added | updated w/o reading target file to confirm edit landed

### Final Step: Update Tracking
After reflection:
- Write current entry count (`grep -c '^##\+ [0-9]\{4\}-' .learnings/log.md`) → `.learnings/.last-reflect-lines`
Ensures SessionStart hook knows when reflect last ran.
```

## Companion Repo Integration

If the user chose git_strategy "companion" in Module 01, add this to the end of the skill:

```markdown
### Auto-Export to Companion
After applying changes, automatically sync to companion repo:
1. Run the sync-config.sh export script
2. Print: "Changes synced to companion repo at ~/.claude-configs/{project}/"
3. Remind user: "Run `/sync push` to push companion repo to remote for multi-machine sync"
```

## Checkpoint

```
✅ Module 05 complete — /reflect skill created
```
