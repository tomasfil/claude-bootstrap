---
id: "003"
name: companion-repo-sync
description: Auto-sync .claude/ to companion repo on session stop, auto-import on session start
base_commit: 08534a5
date: 2026-03-30
breaking: false
---

# Migration 003 — Companion Repo Auto-Sync

> Adds a Stop hook that syncs `.claude/` to `~/.claude-configs/{project}/` with git commit+push.
> Updates SessionStart import to match companion repo layout (flat, not nested `.claude/`).
> No-op if `~/.claude-configs/` is not a git repo.

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| add | `.claude/hooks/sync-companion.sh` | Stop hook: export .claude/ → companion, commit+push |
| modify | `.claude/hooks/detect-env.sh` | Fix companion import to use flat layout |
| modify | `.claude/settings.json` | Wire sync-companion.sh into Stop hooks |

---

## Actions

### Step 1 — Create sync-companion.sh

Create `.claude/hooks/sync-companion.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Stop hook: sync .claude/ to companion repo (~/.claude-configs/{project}/)
# Runs silently on session stop — zero tokens, no Claude interaction

INPUT=$(cat)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")
COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"

# Skip if no companion repo
[[ -d "$HOME/.claude-configs/.git" ]] || exit 0
[[ -d "$COMPANION_DIR" ]] || mkdir -p "$COMPANION_DIR"

# Sync .claude/ → companion/.claude/ (nested layout matching existing projects)
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude='.git' "$PROJECT_ROOT/.claude/" "$COMPANION_DIR/.claude/"
  [[ -d "$PROJECT_ROOT/.learnings" ]] && rsync -a --delete "$PROJECT_ROOT/.learnings/" "$COMPANION_DIR/.learnings/"
else
  mkdir -p "$COMPANION_DIR/.claude"
  cp -r "$PROJECT_ROOT/.claude/"* "$COMPANION_DIR/.claude/" 2>/dev/null
  [[ -d "$PROJECT_ROOT/.learnings" ]] && cp -r "$PROJECT_ROOT/.learnings" "$COMPANION_DIR/" 2>/dev/null
fi

# Copy root config files
cp "$PROJECT_ROOT/CLAUDE.md" "$COMPANION_DIR/" 2>/dev/null || true
cp "$PROJECT_ROOT/CLAUDE.local.md" "$COMPANION_DIR/" 2>/dev/null || true

# Commit and push in companion repo
cd "$HOME/.claude-configs"
git add "$PROJECT_NAME/" 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -q -m "sync: $PROJECT_NAME $(date +%Y-%m-%d)" 2>/dev/null || true
  git push -q 2>/dev/null || true
fi

exit 0
```

Make executable: `chmod +x .claude/hooks/sync-companion.sh`

### Step 2 — Update detect-env.sh companion import

In `.claude/hooks/detect-env.sh`, update the companion auto-import block to use flat layout. The companion mirrors `.claude/` contents directly (not nested under `.claude/`):

- Check `$COMPANION_DIR/.claude/settings.json` exists (nested layout)
- Copy `$COMPANION_DIR/.claude/*` to `.claude/`
- Copy `$COMPANION_DIR/.learnings/` to `.learnings/`
- Copy `$COMPANION_DIR/CLAUDE.md` and `CLAUDE.local.md` to project root

If no companion import block exists yet, add one before the environment output. It should:
1. Set `COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"`
2. Check `[ ! -f ".claude/settings.json" ] && [ -f "$COMPANION_DIR/.claude/settings.json" ]`
3. `cp -r "$COMPANION_DIR/.claude/"* .claude/`
4. Copy `.learnings/`, `CLAUDE.md`, `CLAUDE.local.md`

### Step 3 — Wire into settings.json

Add `sync-companion.sh` to the Stop hooks array in `.claude/settings.json`:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/stop-verify.sh"
      },
      {
        "type": "command",
        "command": "bash .claude/hooks/sync-companion.sh"
      }
    ]
  }
]
```

---

## Verify

- [ ] `.claude/hooks/sync-companion.sh` exists and is executable
- [ ] `.claude/settings.json` Stop hooks array includes `sync-companion.sh`
- [ ] `bash .claude/hooks/sync-companion.sh <<< '{}'` runs without error (or exits cleanly if no companion)
- [ ] `settings.json` parses as valid JSON

---

Migration complete: `003` — Companion repo auto-sync on session stop
