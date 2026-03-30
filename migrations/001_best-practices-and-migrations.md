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
8. Turn-efficient agent design section in `techniques/agent-design.md` (pre-computed context, scope locks, verify-and-fix containment, search batching, tool call batching, meta-tools, turn budgets)
9. Turn optimization section in `techniques/prompt-engineering.md` (tool call batching, search planning, pre-computed context injection, scope locks, verify-and-fix containment, plan-then-act, meta-tools)
10. Migration system: `/migrate-bootstrap` skill + `.claude/bootstrap-state.json` tracking

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

### Step 5 — Fetch turn optimization content

These sections are 100+ lines each. Fetch from bootstrap repo rather than inlining.

**5a — Agent design turn optimization:**

```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/agent-design.md --jq '.content' | base64 -d > /tmp/agent-design-source.md
```

WebFetch fallback:

```
https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/techniques/agent-design.md
```

Extract "Turn-Efficient Agent Design" section → append to local `techniques/agent-design.md` BEFORE "## Agent File Size Guidelines". If that heading doesn't exist, append at end.

**5b — Prompt engineering turn optimization:**

```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/prompt-engineering.md --jq '.content' | base64 -d > /tmp/prompt-eng-source.md
```

WebFetch fallback:

```
https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/techniques/prompt-engineering.md
```

Extract "Turn Optimization" section → append to local `techniques/prompt-engineering.md` BEFORE "## See Also". If that heading doesn't exist, append at end.

### Step 6 — Create /migrate-bootstrap skill

```bash
mkdir -p .claude/skills/migrate-bootstrap
gh api repos/tomasfil/claude-bootstrap/contents/.claude/skills/migrate-bootstrap/SKILL.md --jq '.content' | base64 -d > .claude/skills/migrate-bootstrap/SKILL.md
```

WebFetch fallback:

```
https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/.claude/skills/migrate-bootstrap/SKILL.md
```

### Step 7 — Create/update bootstrap-state.json

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
