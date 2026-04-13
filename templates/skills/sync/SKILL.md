---
name: sync
description: >
  Use when syncing .claude/ config to companion repo or importing from it.
  Push/pull config between project and ~/.claude-configs/{project}/.
user-invocable: true
argument-hint: "[export|import|push|pull|status]"
allowed-tools: Bash Read
model: sonnet
effort: low
# Skill Class: main-thread — inline bash script delegate, no agent dispatch
---

# /sync — Companion Repo Sync

Export or import .claude/ config between project and companion repo.

## Actions

### Determine direction

- `/sync export` (default) — project `.claude/` → companion repo, then git commit
- `/sync import` — companion repo → project `.claude/`

### Variables

```
PROJECT_DIR=<git root of current project>
PROJECT_NAME=<basename of PROJECT_DIR>
COMPANION_DIR=~/.claude-configs/$PROJECT_NAME
```

### Export (project → companion)

1. Verify companion dir exists: `[ -d "$COMPANION_DIR/.git" ]`. If not, `mkdir -p "$COMPANION_DIR" && cd "$COMPANION_DIR" && git init`
2. Sync files (nested layout: companion/.claude/ mirrors project/.claude/):
   ```bash
   rsync -av --delete --exclude='.git' .claude/ "$COMPANION_DIR/.claude/"
   rsync -av --delete --exclude='.git' .learnings/ "$COMPANION_DIR/.learnings/"
   cp CLAUDE.md "$COMPANION_DIR/" 2>/dev/null
   cp CLAUDE.local.md "$COMPANION_DIR/" 2>/dev/null
   ```
   If rsync unavailable, use `cp -r` with manual cleanup of deleted files.
3. Commit in companion: `cd ~/.claude-configs && git add "$PROJECT_NAME/" && git commit -m "sync: $PROJECT_NAME $(date +%Y-%m-%d)"`
4. Push: `git push -q 2>/dev/null`
5. Report what changed: `git diff --stat HEAD~1 HEAD`

### Import (companion → project)

1. Verify companion exists and has content at `$COMPANION_DIR/.claude/`
2. Sync files (reverse direction):
   ```bash
   rsync -av --delete "$COMPANION_DIR/.claude/" .claude/ --exclude='settings.local.json'
   rsync -av --delete "$COMPANION_DIR/.learnings/" .learnings/
   cp "$COMPANION_DIR/CLAUDE.md" . 2>/dev/null
   cp "$COMPANION_DIR/CLAUDE.local.md" . 2>/dev/null
   ```
3. Report what was imported

### Output

```
Synced {direction}: {N} files, companion at {COMPANION_DIR}
```
