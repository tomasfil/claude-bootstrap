# Module 05 — Create /reflect Skill

> The self-improvement engine. Reviews learnings, evolves agents, audits rules, manages plugins.

---

## Idempotency

```
IF .claude/skills/reflect/SKILL.md exists AND has customizations → PRESERVE
IF exists AND matches old template → UPDATE
IF missing → CREATE
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

Execute these steps in order. Present ALL proposed changes for user approval before applying.

### Step 1: Read Current State
1. Read `.learnings/log.md` — note entries with status `pending review`
2. Read `.learnings/agent-usage.log` — note which agents are used, which aren't
3. Read `CLAUDE.md` — note current rules, conventions, gotchas
4. Read all files in `.claude/rules/` — note current standards
5. Read all files in `.claude/agents/` — note current agents and their descriptions

### Step 2: Analyze Learnings
For each `pending review` entry in `.learnings/log.md`:
- **Correction entries**: Should this become a rule in code-standards? A gotcha in CLAUDE.md? Or is it too specific to promote?
- **Failure entries**: Is the root cause documented? Should a rule prevent recurrence?
- **Agent-candidate entries**: Has this pattern appeared 2+ times? If yes, create an agent.
- **Gotcha entries**: Should this be added to CLAUDE.md Gotchas section?

### Step 3: Analyze Agent Usage
From `.learnings/agent-usage.log`:
- Which agents are used frequently? → Keep, maybe improve
- Which agents are never used? → Consider retiring or improving description
- Are there agent-candidates in learnings that appear 2+ times? → Create new agent

### Step 4: Check File Sizes
- CLAUDE.md must be < 120 lines. If over, move content to rules/ or use @import.
- Rule files should be < 40 lines each. If over, split by concern.
- Agent files should be < 500 lines. If over, use reference files.

### Step 5: Mine Session History (optional, if user agrees)
Read recent session logs at `~/.claude/projects/` for patterns:
- Repeated mistakes across sessions
- Commands that frequently fail
- Patterns that could be automated

### Step 6: Check Plugin Recommendations
1. Read `~/.claude/plugins/installed_plugins.json`
2. Check if any installed methodology plugins could be replaced by project-local skills
3. Check if any recommended connector plugins are missing (LSP, MCP servers)

### Step 7: Propose Changes
Group all proposed changes:

**Rules changes:**
- [ ] Add rule: {rule} to {file} — because: {reason}
- [ ] Update rule: {old} → {new} in {file}

**Agent changes:**
- [ ] Create agent: {name} — triggered by {pattern} appearing {N} times
- [ ] Retire agent: {name} — unused in last {N} sessions
- [ ] Improve agent: {name} — {what to change}

**CLAUDE.md changes:**
- [ ] Add gotcha: {gotcha}
- [ ] Update convention: {convention}
- [ ] Move content to @import: {what}

**Learnings promotion:**
- [ ] Promote: {learning} → {destination}
- [ ] Dismiss: {learning} — reason: {why}

### Step 8: Wait for User Approval
Present all changes grouped above. Wait for user to approve, modify, or reject.

### Step 9: Apply Approved Changes
1. Update CLAUDE.md, rules, agents as approved
2. Mark promoted entries in `.learnings/log.md` as `promoted` with destination
3. Mark dismissed entries as `dismissed` with reason
4. If git_strategy is "companion": auto-export to companion repo

### Step 10: Update Skill Routing
If new skills or agents were created, update the UserPromptSubmit hook prompt in `.claude/settings.json` to include them.

### Report
Print summary:
- Learnings: {N} promoted, {M} dismissed, {P} still pending
- Rules: {N} added, {M} updated
- Agents: {N} created, {M} retired, {P} improved
- CLAUDE.md: {N} changes applied
- File sizes: all within budget? (CLAUDE.md <120, rules <40, agents <500)
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
