---
id: "001"
name: best-practices-and-migrations
description: Enhanced frontmatter, stop hook, turn optimization, migration system
base_commit: c8316eea69af30e1cec1db2b168c3f9e316ca574
date: 2026-03-30
breaking: false
---

# Migration 001 — Best Practices + Migration System

> Enhanced skill/agent frontmatter, stop-verify hook, turn optimization techniques,
> migration infrastructure w/ `/migrate-bootstrap` skill + state tracking.

---

## Changes

1. Enhanced YAML frontmatter rules 8-9 in `claude-bootstrap.md` — skills require `model`, `effort`, `allowed-tools`; orchestrator skills add `context: fork`, `agent`. Agents require `color`, add `memory: project` for stateful, `skills` for preloaded knowledge
2. New stop hook: `.claude/hooks/stop-verify.sh` — nudges verify before claiming done when uncommitted changes exist
3. Stop hook wired in `.claude/settings.json`
4. Agent frontmatter reference table added to `modules/10-agents.md`
5. Agent fields added: `color`, `memory`, `skills` to all base agent templates
6. Skill frontmatter reference table added to `modules/13-plugin-replacements.md`
7. Skill fields added: `context`, `agent`, `allowed-tools`, `model`, `effort` to all skill templates
8. Turn optimization techniques added to bootstrap reference docs (techniques/agent-design.md, techniques/prompt-engineering.md) — these are baked into generated agents during bootstrap, not distributed to client projects
9. Migration system: `/migrate-bootstrap` skill + `.claude/bootstrap-state.json` tracking

---

## Actions

### Step 1 — Create stop-verify hook

Create `.claude/hooks/stop-verify.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)
STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // "end_turn"' 2>/dev/null || echo "end_turn")
if [[ "$STOP_REASON" == "end_turn" ]]; then
  if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    exit 0
  fi
  echo "STOP_HOOK: You have uncommitted changes. Before claiming done, consider: did you verify the changes work? Run /verify if you haven't already."
fi
```

Make executable:

```bash
chmod +x .claude/hooks/stop-verify.sh
```

### Step 2 — Wire stop hook in settings.json

Read `.claude/settings.json`. Add `Stop` entry under `hooks`:

```json
"Stop": [{ "hooks": [{ "type": "command", "command": "bash .claude/hooks/stop-verify.sh" }] }]
```

Preserve existing hooks — additive only.

### Step 3 — Update agent frontmatter

For each `.claude/agents/*.md`, read file + add missing fields to YAML frontmatter:

| Agent | color | memory | skills |
|-------|-------|--------|--------|
| quick-check | gray | — | — |
| researcher | cyan | project | — |
| plan-writer | blue | — | — |
| debugger | red | project | — |
| verifier | green | — | — |
| reflector | magenta | project | — |
| consistency-checker | yellow | — | — |
| tdd-runner | green | — | — |

Rules:
- Add `color` to all agents
- Add `memory: project` only where table shows "project"
- Additive — never remove existing fields
- Skip agents not in table (leave unchanged)

### Step 4 — Update skill frontmatter

For each `.claude/skills/*/SKILL.md`, read file + add missing fields to YAML frontmatter.

**Orchestrator skills** (brainstorm, execute-plan, tdd, debug, review):
- Add `context: fork` + `agent: general-purpose`
- Add `model`, `effort`, `allowed-tools` if missing

**Non-orchestrator skills** (verify, commit, pr, write-plan, and others):
- Add `model`, `effort`, `allowed-tools` if missing
- Do NOT add `context` or `agent`

Rules:
- Additive — never remove existing fields
- Match `model` + `effort` to skill complexity (verify=sonnet/medium, commit=sonnet/low, review=opus/high, etc.)
- `allowed-tools` = minimal set needed for that skill

### Step 5 — Create /migrate-bootstrap skill

```bash
mkdir -p .claude/skills/migrate-bootstrap
```

Create `.claude/skills/migrate-bootstrap/SKILL.md` with this content:

````markdown
---
name: migrate-bootstrap
description: >
  Apply pending bootstrap migrations. Use when the bootstrap repo has been
  updated and you need to bring this project to the latest migration level.
  Also handles retrofit for pre-migration bootstrapped projects.
argument-hint: "[migration-id]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch
model: sonnet
effort: medium
---

## /migrate-bootstrap — Apply Pending Migrations

### Step 1: Read migration state

Read `.claude/bootstrap-state.json`.

**File exists:** extract `last_migration` + `applied[]`. Continue to Step 2.

**File missing — retrofit detection:**
- Check `.claude/settings.json` exists AND contains `"hooks"`
- Check `CLAUDE.md` exists AND contains bootstrap fingerprints (any of: "self-improvement", ".learnings/log.md", "Module")
- BOTH pass → project bootstrapped pre-migration. Create `.claude/bootstrap-state.json`:
```json
{
  "bootstrap_repo": "tomasfil/claude-bootstrap",
  "last_migration": "000",
  "last_applied": "{current ISO-8601 timestamp}",
  "applied": [
    { "id": "000", "applied_at": "{current ISO-8601 timestamp}", "commit": "b622344" }
  ]
}
```
- Conditions DON'T pass → not bootstrapped. Tell user: "Run the full bootstrap first by executing `claude-bootstrap.md`."

### Step 2: Fetch migration index

```bash
gh api repos/tomasfil/claude-bootstrap/contents/migrations --jq '[.[] | select(.name != "_template.md") | .name] | sort'
```

Fallback if `gh` unavailable — WebFetch:
```
https://api.github.com/repos/tomasfil/claude-bootstrap/contents/migrations
```
Filter out `_template.md`, sort by filename.

### Step 3: Identify pending migrations

Extract numeric IDs from filenames (e.g., `001_best-practices-and-migrations.md` → `"001"`).
Filter to IDs > `last_migration`. Sort ascending.
None pending → print "Already up to date at migration {last_migration}" and STOP.

### Step 4: Apply each pending migration in order

1. **Fetch** migration file: `gh api repos/tomasfil/claude-bootstrap/contents/migrations/{filename} --jq '.content' | base64 -d`
   Fallback: `https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/migrations/{filename}`
2. **If `breaking: true`** → warn user + STOP. Wait for explicit confirmation.
3. **Print** `## Changes` summary to user.
4. **Execute** `## Actions` — read-before-write for all file modifications.
5. **Run** `## Verify` — any check fails → STOP. Do NOT update state file.
6. **Update state**: append to `applied[]`, update `last_migration` + `last_applied`.
7. **Print** `✅ Migration {id} applied — {description}`

### Step 5: Report summary

```
✅ Migrations complete: applied {N} migrations ({id_list})
Current state: migration {last_migration}
```

### Gotchas
- Migrations apply in strict numeric order — never skip
- Retrofit requires BOTH `.claude/settings.json` w/ hooks AND `CLAUDE.md` w/ fingerprints
- Migration fails mid-apply → state NOT updated — safe to retry
- `.claude/bootstrap-state.json` always tracked — never gitignored
````

### Step 6 — Create/update bootstrap-state.json

Write `.claude/bootstrap-state.json`:

```json
{
  "bootstrap_repo": "tomasfil/claude-bootstrap",
  "last_migration": "001",
  "last_applied": "{ISO-8601 timestamp}",
  "applied": [
    { "id": "000", "applied_at": "{ISO-8601 timestamp}", "commit": "b622344" },
    { "id": "001", "applied_at": "{ISO-8601 timestamp}", "commit": "c8316ee" }
  ]
}
```

Replace `{ISO-8601 timestamp}` w/ current UTC time (e.g., `2026-03-30T12:00:00Z`).

If file already exists: read it, preserve existing `applied[]` entries, append 001 entry, update `last_migration` + `last_applied`.

---

## Verify

```bash
# Stop hook
[[ -f ".claude/hooks/stop-verify.sh" ]] && echo "✓ stop-verify.sh" || echo "✗ missing"
grep -q "Stop" .claude/settings.json && echo "✓ Stop hook wired" || echo "✗ Stop hook missing"

# Agent frontmatter updates
grep -l "color:" .claude/agents/*.md | wc -l  # should match agent count

# Skill frontmatter updates
grep -l "model:" .claude/skills/*/SKILL.md | wc -l  # should match skill count

# Migration skill
[[ -f ".claude/skills/migrate-bootstrap/SKILL.md" ]] && echo "✓ migrate-bootstrap skill" || echo "✗ missing"

# State file
[[ -f ".claude/bootstrap-state.json" ]] && echo "✓ state file" || echo "✗ missing"
grep -q '"001"' .claude/bootstrap-state.json && echo "✓ migration 001 recorded" || echo "✗ not recorded"
```

---

Migration complete: `001` — enhanced frontmatter, stop hook, turn optimization, migration system
