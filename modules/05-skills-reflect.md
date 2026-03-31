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
---
```

```markdown
## /reflect — Self-Improvement Protocol

### Step 1: Dispatch Agent
Dispatch the `reflector` agent with paths to:
- `.learnings/log.md` — pending review entries
- `.learnings/instincts/` — current instinct files (if directory exists)
- `.learnings/observations.jsonl` — tool usage patterns (file churn, command patterns)
- `.learnings/agent-usage.log` — agent usage data
- `CLAUDE.md` — current rules and conventions
- `.claude/rules/` — current standards
- `.claude/agents/` — current agents and descriptions
- `.claude/references/techniques/INDEX.md` — read index, pick relevant technique files for evaluating improvement proposals
- User memory at `~/.claude/projects/` (project-specific MEMORY.md)

The agent reads all sources, analyzes learnings, checks agent usage patterns, validates file sizes, and returns grouped proposals.

> **Fallback:** If the `reflector` agent doesn't exist, perform the work on the main thread.
> **Fallback:** If `.learnings/instincts/` doesn't exist, fall back to `log.md` only for instinct analysis.
> **Fallback:** If `.claude/references/techniques/` doesn't exist, skip technique references — reflector uses general knowledge.

### Step 2: Present Proposals (main thread)
Present all proposed changes grouped by category:

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

Wait for user to approve, modify, or reject each proposal.

### Step 3: Apply Approved Changes (main thread)
1. Update CLAUDE.md, rules, agents as approved
2. Mark promoted entries in `.learnings/log.md` as `promoted` with destination
3. Mark dismissed entries as `dismissed` with reason
4. If new skills or agents were created, update the UserPromptSubmit hook in `.claude/settings.json`

### Step 4: Instinct Health Report
If `.learnings/instincts/` exists, analyze and report:
- **Total instinct count** and **confidence distribution** (histogram or ranges)
- **Domain breakdown** — count per domain tag
- **Prune candidates** — list instincts with confidence <0.3, propose removal
- **Promotion candidates** — list instincts with confidence 0.8+, propose promotion to `.claude/rules/`

If `.learnings/instincts/` does not exist, skip this step.

### Report
Print summary:
- Learnings: {N} promoted, {M} dismissed, {P} still pending
- Rules: {N} added, {M} updated
- Agents: {N} created, {M} retired, {P} improved
- CLAUDE.md: {N} changes applied
- File sizes: all within budget? (CLAUDE.md <120, rules <40, agents <500)
- Instincts: {total} total, {prune} to prune, {promote} to promote (omit if no instincts directory)

### Gotchas
- `.learnings/instincts/` may not exist yet — check before reading
- Don't promote single-occurrence corrections to rules — require 2+ similar entries
- Agent usage data may be empty if SubagentStop hook wasn't wired — check first
- Routing hook in settings.json must be updated when creating new skills/agents

### Anti-Hallucination
- Read files before modifying — verify `.learnings/log.md` entries exist before marking them promoted/dismissed
- Confirm file paths exist before writing (e.g., `.learnings/instincts/` directory)
- Count log entries by reading the file, not estimating — use `grep -c` for accuracy
- When proposing agent changes, verify the agent file exists on disk first
- Never claim a rule was added/updated without reading the target file to confirm the edit landed

### Final Step: Update Tracking
After reflection completes:
- Write the current entry count (`grep -c '^##\+ [0-9]\{4\}-' .learnings/log.md`) to `.learnings/.last-reflect-lines`
This ensures the SessionStart hook knows when reflect last ran.
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
