# Module 15 — Companion Repo Sync

> Set up persistent private storage for .claude/ configs.
> ONLY runs when git_strategy == "companion" (selected in Module 01).
> If git_strategy is "track" or "ephemeral", SKIP this module entirely.

---

## Skip Check

```
IF git_strategy != "companion" → SKIP this module. Print:
  "✅ Module 15 skipped — git_strategy is {strategy}, companion repo not needed"
```

## 1. Create Sync Script

Write `.claude/scripts/sync-config.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# sync-config.sh — Export/import .claude/ config to/from companion repo
# Usage: bash .claude/scripts/sync-config.sh [export|import|status|init] [project-name]

ACTION="${1:-status}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PROJECT_NAME="${2:-$(basename "$PROJECT_ROOT")}"
COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"

# Directories to sync (project-specific, machine-independent)
SYNC_DIRS="rules skills agents hooks scripts specs"
SYNC_FILES=".claude/settings.json"
SYNC_ROOT_FILES="CLAUDE.md"
SYNC_LEARNINGS=".learnings/log.md"

# Files to NOT sync (machine-specific or session-specific)
# .claude/settings.local.json, CLAUDE.local.md, .learnings/agent-usage.log

case "$ACTION" in
  init)
    echo "Initializing companion repo at $HOME/.claude-configs/..."
    mkdir -p "$HOME/.claude-configs"
    cd "$HOME/.claude-configs"
    if [ ! -d ".git" ]; then
      git init
      echo "# Claude Code Configs" > README.md
      echo "*.log" > .gitignore
      echo "agent-usage.log" >> .gitignore
      git add -A && git commit -m "Initialize companion config repo"
      echo "✅ Companion repo initialized at $HOME/.claude-configs/"
      echo ""
      echo "To enable multi-machine sync, add a remote:"
      echo "  cd ~/.claude-configs && git remote add origin <your-private-repo-url>"
    else
      echo "Companion repo already initialized."
    fi
    mkdir -p "$COMPANION_DIR"
    echo "Project directory created: $COMPANION_DIR"
    ;;

  export)
    echo "Exporting $PROJECT_NAME → $COMPANION_DIR..."
    mkdir -p "$COMPANION_DIR/.claude" "$COMPANION_DIR/.learnings"

    # Sync directories
    for dir in $SYNC_DIRS; do
      if [ -d "$PROJECT_ROOT/.claude/$dir" ]; then
        mkdir -p "$COMPANION_DIR/.claude/$dir"
        cp -r "$PROJECT_ROOT/.claude/$dir/." "$COMPANION_DIR/.claude/$dir/"
      fi
    done

    # Sync .claude files
    for file in $SYNC_FILES; do
      if [ -f "$PROJECT_ROOT/$file" ]; then
        cp "$PROJECT_ROOT/$file" "$COMPANION_DIR/$file"
      fi
    done

    # Sync root files
    for file in $SYNC_ROOT_FILES; do
      if [ -f "$PROJECT_ROOT/$file" ]; then
        cp "$PROJECT_ROOT/$file" "$COMPANION_DIR/$file"
      fi
    done

    # Sync learnings (only log.md, not agent-usage.log)
    if [ -f "$PROJECT_ROOT/$SYNC_LEARNINGS" ]; then
      mkdir -p "$COMPANION_DIR/.learnings"
      cp "$PROJECT_ROOT/$SYNC_LEARNINGS" "$COMPANION_DIR/$SYNC_LEARNINGS"
    fi

    echo "✅ Exported to $COMPANION_DIR"
    ;;

  import)
    if [ ! -d "$COMPANION_DIR" ]; then
      echo "❌ No companion config found at $COMPANION_DIR"
      echo "Run: bash .claude/scripts/sync-config.sh init"
      exit 1
    fi

    echo "Importing $COMPANION_DIR → $PROJECT_NAME..."

    # Restore directories
    for dir in $SYNC_DIRS; do
      if [ -d "$COMPANION_DIR/.claude/$dir" ]; then
        mkdir -p "$PROJECT_ROOT/.claude/$dir"
        cp -r "$COMPANION_DIR/.claude/$dir/." "$PROJECT_ROOT/.claude/$dir/"
      fi
    done

    # Restore .claude files
    for file in $SYNC_FILES; do
      if [ -f "$COMPANION_DIR/$file" ]; then
        mkdir -p "$(dirname "$PROJECT_ROOT/$file")"
        cp "$COMPANION_DIR/$file" "$PROJECT_ROOT/$file"
      fi
    done

    # Restore root files
    for file in $SYNC_ROOT_FILES; do
      if [ -f "$COMPANION_DIR/$file" ]; then
        cp "$COMPANION_DIR/$file" "$PROJECT_ROOT/$file"
      fi
    done

    # Restore learnings
    if [ -f "$COMPANION_DIR/$SYNC_LEARNINGS" ]; then
      mkdir -p "$PROJECT_ROOT/.learnings"
      cp "$COMPANION_DIR/$SYNC_LEARNINGS" "$PROJECT_ROOT/$SYNC_LEARNINGS"
    fi

    echo "✅ Imported from $COMPANION_DIR"
    ;;

  status)
    if [ ! -d "$COMPANION_DIR" ]; then
      echo "No companion config at $COMPANION_DIR"
      exit 0
    fi

    echo "Companion repo status for $PROJECT_NAME:"
    echo "  Location: $COMPANION_DIR"
    echo ""

    # Compare files
    DIFFS=0
    for dir in $SYNC_DIRS; do
      if [ -d "$PROJECT_ROOT/.claude/$dir" ] && [ -d "$COMPANION_DIR/.claude/$dir" ]; then
        CHANGED=$(diff -rq "$PROJECT_ROOT/.claude/$dir" "$COMPANION_DIR/.claude/$dir" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$CHANGED" -gt 0 ]; then
          echo "  ⚠️  .claude/$dir: $CHANGED files differ"
          DIFFS=$((DIFFS + CHANGED))
        else
          echo "  ✅ .claude/$dir: in sync"
        fi
      fi
    done

    if [ "$DIFFS" -eq 0 ]; then
      echo ""
      echo "All files in sync."
    else
      echo ""
      echo "$DIFFS files differ. Run '/sync export' to update companion."
    fi
    ;;

  push)
    cd "$HOME/.claude-configs"
    git add -A
    git diff --cached --quiet 2>/dev/null && echo "Nothing to push." && exit 0
    git commit -m "Sync $PROJECT_NAME configs $(date -u +%Y-%m-%d)"
    git push 2>/dev/null && echo "✅ Pushed to remote" || echo "⚠️ No remote configured. Run: cd ~/.claude-configs && git remote add origin <url>"
    ;;

  pull)
    cd "$HOME/.claude-configs"
    git pull 2>/dev/null && echo "✅ Pulled from remote" || echo "⚠️ Pull failed — check remote configuration"
    ;;

  *)
    echo "Usage: sync-config.sh [init|export|import|status|push|pull] [project-name]"
    exit 1
    ;;
esac
```

Make executable: `chmod +x .claude/scripts/sync-config.sh`

## 2. Create /sync Skill

```bash
mkdir -p .claude/skills/sync
```

Write `.claude/skills/sync/SKILL.md`:

```yaml
---
name: sync
description: >
  Sync .claude/ config to/from companion repo. Use when asked to save config,
  backup settings, export/import claude setup, sync to another machine, or
  check sync status. Commands: /sync export, /sync import, /sync status,
  /sync init, /sync push, /sync pull.
---
```

```markdown
## /sync — Companion Repo Sync

Manage .claude/ config persistence across machines via a private companion repo.

### Commands

| Command | What it does |
|---------|-------------|
| `/sync init` | Initialize companion repo at ~/.claude-configs/ (first time) |
| `/sync export` | Copy project .claude/ → companion repo |
| `/sync import` | Copy companion repo → project .claude/ |
| `/sync status` | Show diff between project and companion |
| `/sync push` | Git commit + push companion repo to remote |
| `/sync pull` | Git pull companion repo from remote |

### What syncs
- .claude/rules/, skills/, agents/, hooks/, scripts/, specs/
- .claude/settings.json
- CLAUDE.md
- .learnings/log.md

### What does NOT sync (machine-specific)
- .claude/settings.local.json
- CLAUDE.local.md
- .learnings/agent-usage.log

### Usage

Run the appropriate command:
```bash
bash .claude/scripts/sync-config.sh {command} {project-name}
```

Project name is auto-detected from git root directory name.

### Auto-Sync
The SessionStart hook automatically imports from companion if .claude/ is missing.
The /reflect skill automatically exports after applying changes.
```

## 3. Register User-Level Auto-Import Hook

This is the KEY piece that solves the chicken-and-egg problem. The hook lives at the USER level (`~/.claude/settings.json`), not the project level. So it works even when `.claude/` is gitignored and missing.

Check if user-level settings.json exists and has hooks:

```bash
if [ -f "$HOME/.claude/settings.json" ]; then
  echo "User settings exist — will merge auto-import hook"
else
  echo "Creating user settings with auto-import hook"
fi
```

The auto-import logic is ALREADY baked into `detect-env.sh` (Module 04). It checks for companion config on every SessionStart and imports if `.claude/` is missing. This works because:

1. For "track" projects: detect-env.sh is in `.claude/hooks/` which is committed → always available
2. For "companion" projects: detect-env.sh is in `.claude/hooks/` which was previously imported from companion → available after first import
3. For FIRST TIME on new machine: user needs to run `bash ~/.claude-configs/{project}/sync-config.sh import` once, OR have the user-level hook

To handle the true cold-start (first time on a brand new machine), suggest the user add this to their `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash -c 'P=$(basename \"$(git rev-parse --show-toplevel 2>/dev/null || pwd)\"); C=\"$HOME/.claude-configs/$P\"; if [ ! -f \".claude/settings.json\" ] && [ -d \"$C/.claude\" ]; then for d in rules skills agents hooks scripts specs; do [ -d \"$C/.claude/$d\" ] && mkdir -p \".claude/$d\" && cp -r \"$C/.claude/$d/.\" \".claude/$d/\" 2>/dev/null; done; [ -f \"$C/.claude/settings.json\" ] && cp \"$C/.claude/settings.json\" .claude/settings.json 2>/dev/null; [ -f \"$C/CLAUDE.md\" ] && cp \"$C/CLAUDE.md\" CLAUDE.md 2>/dev/null; [ -f \"$C/.learnings/log.md\" ] && mkdir -p .learnings && cp \"$C/.learnings/log.md\" .learnings/log.md 2>/dev/null; echo \"⚡ Auto-imported .claude/ from companion repo\"; fi'"
      }
    ]
  }
}
```

**Ask the user**: "Would you like me to add the auto-import hook to your user-level settings (~/.claude/settings.json)? This enables automatic config restoration on any machine that has your companion repo."

## 4. Run First Sync

```bash
# Initialize companion repo if needed
bash .claude/scripts/sync-config.sh init

# Run first export
bash .claude/scripts/sync-config.sh export
```

## Checkpoint

```
✅ Module 15 complete — Companion repo sync configured
  Companion repo: ~/.claude-configs/{project-name}/
  /sync skill: created
  sync-config.sh: created
  First export: complete
  User-level hook: {installed / user declined / skipped}

  Multi-machine sync: Run '/sync push' after changes, '/sync pull' on other machines
  Auto-restore: SessionStart hook imports from companion if .claude/ is missing
```
