---
id: "000"
name: initial
description: Full bootstrap baseline — all 18 modules via orchestrator
base_commit: b62234495a16899b38abb926bd4bb03d6656b0af
date: 2026-03-30
breaking: false
---

# Migration 000 — Initial Bootstrap Baseline

> Represents full bootstrap install. NEVER applied as actions — stamped automatically
> during retrofit detection (existing project) | after fresh full bootstrap completes.

---

## Changes

- Full bootstrap via `claude-bootstrap.md` orchestrator (all 18 modules): CLAUDE.md, `.claude/settings.json`, rules, hooks, skills, agents, `.learnings/`

---

## Actions

### Step 1 — Run full orchestrator

Execute all 18 modules in `claude-bootstrap.md` sequentially. Each module produces `✅ Module N complete — {summary}`.

### Step 2 — Create bootstrap state

Write `.claude/bootstrap-state.json`:

```json
{
  "bootstrap_repo": "tomasfil/claude-bootstrap",
  "last_migration": "000",
  "last_applied": "{ISO-8601 timestamp}",
  "applied": [
    { "id": "000", "applied_at": "{ISO-8601 timestamp}", "commit": "b622344" }
  ]
}
```

Fields:
- `bootstrap_repo` — source repo for migration tracking
- `last_migration` — highest applied migration id
- `last_applied` — timestamp of most recent migration apply
- `applied[]` — ordered list; each entry: id + timestamp + short commit hash

---

## Verify

```bash
# Core files exist
[[ -f "CLAUDE.md" ]] && echo "✓ CLAUDE.md" || echo "✗ CLAUDE.md missing"
[[ -f ".claude/settings.json" ]] && echo "✓ settings.json" || echo "✗ settings.json missing"

# Settings has hooks
grep -q '"hooks"' .claude/settings.json && echo "✓ hooks configured" || echo "✗ hooks missing"

# Skills + agents exist
ls .claude/skills/*/SKILL.md >/dev/null 2>&1 && echo "✓ skills present" || echo "✗ no skills"
ls .claude/agents/*.md >/dev/null 2>&1 && echo "✓ agents present" || echo "✗ no agents"

# Bootstrap state recorded
[[ -f ".claude/bootstrap-state.json" ]] && echo "✓ bootstrap-state.json" || echo "✗ bootstrap-state.json missing"
grep -q '"000"' .claude/bootstrap-state.json && echo "✓ migration 000 recorded" || echo "✗ migration 000 not recorded"
```
