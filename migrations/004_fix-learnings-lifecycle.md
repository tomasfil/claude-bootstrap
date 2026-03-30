# Migration: Fix Learnings Lifecycle

> Fix broken learnings/reflect/consolidate lifecycle — tracking files never updated, /consolidate skill missing, detect-env off-by-one, .last-dream init wrong

---

```yaml
id: "004"
name: "Fix Learnings Lifecycle"
description: >
  The learnings lifecycle (reflect/consolidate/dream) had multiple bugs causing
  CONSOLIDATE_DUE and REFLECT_DUE to fire every session forever. Root causes:
  missing /consolidate skill, stale /reflect skill without tracking update,
  .last-dream initialized to "never" instead of "0", off-by-one in session counting.
base_commit: "233f5cb"
date: "2026-03-30"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| modify | `.claude/hooks/detect-env.sh` | Fix off-by-one in session count check |
| modify | `.claude/skills/reflect/SKILL.md` | Sync with current template: reflector agent dispatch, instinct health, tracking update |
| add | `.claude/skills/consolidate/SKILL.md` | Create missing /consolidate skill |
| modify | `.learnings/.last-dream` | Fix value if set to "never" |
| modify | `CLAUDE.md` | Remove references to skills that don't exist |

---

## Actions

### Step 1 — Fix detect-env.sh off-by-one

Read `.claude/hooks/detect-env.sh`. Find the session count increment block. Replace:

```bash
COUNT=$(cat "$SESSION_COUNT_FILE" 2>/dev/null | tr -d '\r' || echo 0)
echo $((COUNT + 1)) > "$SESSION_COUNT_FILE"
```

With:

```bash
COUNT=$(cat "$SESSION_COUNT_FILE" 2>/dev/null | tr -d '\r' || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$SESSION_COUNT_FILE"
```

This ensures the consolidate check (`if [ "$COUNT" -ge 5 ]`) uses the post-increment value.

### Step 2 — Fix .last-dream if invalid

Read `.learnings/.last-dream`. If it contains `never` or any non-numeric value, replace with `0`:

```bash
CONTENT=$(cat .learnings/.last-dream 2>/dev/null | tr -d '\r')
if ! [[ "$CONTENT" =~ ^[0-9]+$ ]]; then
  echo "0" > .learnings/.last-dream
fi
```

### Step 3 — Replace /reflect skill

Create or replace `.claude/skills/reflect/SKILL.md` with the following content:

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
Dispatch the `reflector` agent with paths to:
- `.learnings/log.md` — pending review entries
- `.learnings/instincts/` — current instinct files (if directory exists)
- `.learnings/observations.jsonl` — tool usage patterns (file churn, command patterns)
- `.learnings/agent-usage.log` — agent usage data
- `CLAUDE.md` — current rules and conventions
- `.claude/rules/` — current standards
- `.claude/agents/` — current agents and descriptions
- User memory at `~/.claude/projects/` (project-specific MEMORY.md)

The agent reads all sources, analyzes learnings, checks agent usage patterns, validates file sizes, and returns grouped proposals.

> **Fallback:** If the `reflector` agent doesn't exist, perform the work on the main thread.
> **Fallback:** If `.learnings/instincts/` doesn't exist, fall back to `log.md` only for instinct analysis.

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

### Step 4 — Create /consolidate skill

```bash
mkdir -p .claude/skills/consolidate
```

Create `.claude/skills/consolidate/SKILL.md` with this content:

```yaml
---
name: consolidate
description: >
  Consolidate learnings into instincts and clean up the learning system. Use when
  session start reports CONSOLIDATE_DUE=true, or when manually invoked. Reviews raw
  learnings, merges duplicates, resolves contradictions, promotes/prunes instincts.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Grep, Glob
model: opus
effort: medium
---
```

```markdown
## /consolidate — Learning Consolidation

Dispatch the `reflector` agent for heavy analysis. Main thread applies approved changes.

### Phase 1: Orient
Read current state:
- `.learnings/log.md` — raw corrections and discoveries
- `.learnings/instincts/` — existing instinct files
- `.learnings/patterns.md` — recurring patterns
- MEMORY.md — auto-memory index

### Phase 2: Gather
Dispatch `reflector` agent with all learnings paths. Agent:
- Scans for corrections, decisions, recurring themes
- Clusters entries by domain (code-style, testing, git, debugging, security, architecture, tooling)
- Identifies entries that should become instincts (2+ similar corrections)
- Identifies instincts to reinforce (+0.1) or contradict (-0.05)

### Phase 3: Consolidate
Present reflector's proposals to user:
- New instincts to create (with initial confidence 0.5)
- Existing instincts to reinforce or contradict
- Duplicate entries to merge
- Contradictions to resolve

Apply approved changes.

### Phase 4: Prune & Promote
- High-confidence instincts (0.8+) — propose promotion to `.claude/rules/`
- Low-confidence instincts (<0.3) — archive or remove
- Clear processed entries from `log.md` (move to archive)
- Keep instinct index lean

### Phase 5: Update Tracking
- Run `date +%s` and write the output (Unix epoch seconds) to `.learnings/.last-dream`
- Reset `.learnings/.session-count` to 0
- Write current entry count (`grep -c '^##\+ [0-9]\{4\}-' .learnings/log.md`) to `.learnings/.last-reflect-lines`

### Anti-Hallucination
- Only analyze entries that actually exist in the files
- Don't invent patterns not present in the data
- Don't create instincts from single occurrences — require 2+ similar entries
```

### Step 5 — Clean up CLAUDE.md skill references

Read `CLAUDE.md`. In the "Skill Automation" or "Active dev" section, if it lists any of these skills that don't exist on disk, remove them: `spec`, `module-write`, `check-consistency`, `write-ticket`, `ci-triage`.

Check which of those actually exist in `.claude/skills/` first — only remove references to skills with no corresponding directory.

### Step 6 — Update routing hook

Add `/consolidate` to the UserPromptSubmit skill routing hook in `.claude/settings.json`.
Find the routing hook echo command and add:
```
- /consolidate → consolidate learnings into instincts, clean up learning system
```

### Step 7 — Wire + sync

1. Verify `.claude/skills/consolidate/SKILL.md` exists
2. Verify `.claude/skills/reflect/SKILL.md` has "Update Tracking" section
3. Verify `.claude/hooks/detect-env.sh` uses post-increment `$COUNT`
4. Verify `.learnings/.last-dream` contains a numeric value

---

## Verify

- [ ] `.claude/skills/consolidate/SKILL.md` exists and has valid YAML frontmatter
- [ ] `.claude/skills/reflect/SKILL.md` contains "Update Tracking" or "last-reflect-lines"
- [ ] `.claude/hooks/detect-env.sh` has `COUNT=$((COUNT + 1))` before the file write
- [ ] `.learnings/.last-dream` contains only digits (no "never")
- [ ] `.claude/settings.json` routing hook mentions `/consolidate`
- [ ] `settings.json` parses as valid JSON

---

Migration complete: `004` — Fix learnings lifecycle (consolidate skill, reflect tracking, detect-env off-by-one, .last-dream init)
