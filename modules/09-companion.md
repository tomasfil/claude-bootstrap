# Module 09 — Companion Repo

> Conditional on git_strategy == "companion" from Module 01.
> Sets up companion repo sync infrastructure — script, skill verification, first export, cold-start hook.
> If git_strategy is "track" or "ephemeral", SKIP entirely.

---

## Idempotency

```
IF git_strategy != "companion" → SKIP module. Print:
  "✅ Module 09 skipped — git_strategy is {strategy}, companion repo not needed"
IF ~/.claude-configs/{project}/ exists + sync-config.sh exists → verify /sync skill wiring, skip creation
IF sync-config.sh missing → dispatch code-writer-bash to create
IF companion dir exists but stale → run export to refresh
```

---

## Actions

### 0. Skip Check

```
IF git_strategy != "companion" → print skip message, STOP.
```

---

### 1. Dispatch: code-writer-bash (sync-config.sh)

Dispatch `code-writer-bash` agent (inline BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Create companion repo sync script",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT from Module 01, code-writer-bash section}

Write .claude/scripts/sync-config.sh — companion repo sync utility.
Shell standards: #!/usr/bin/env bash, set -euo pipefail, quote all vars, [[ ]] conditionals.

USAGE: bash .claude/scripts/sync-config.sh [init|export|import|status|push|pull] [project-name]

VARIABLES:
- ACTION=${1:-status}
- PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
- PROJECT_NAME=${2:-$(basename $PROJECT_ROOT)}
- COMPANION_DIR=$HOME/.claude-configs/$PROJECT_NAME

SYNC TARGETS (project-specific, machine-independent):
- Directories: .claude/{rules,skills,agents,hooks,scripts,specs,references}
- Files: .claude/settings.json, CLAUDE.md
- Learnings: .learnings/log.md

DO NOT SYNC (machine-specific):
- .claude/settings.local.json
- CLAUDE.local.md
- .learnings/agent-usage.log
- .claude/reports/

COMMANDS:

init:
  - mkdir -p $HOME/.claude-configs
  - cd $HOME/.claude-configs; git init if .git missing
  - Create README.md ('# Claude Code Configs'), .gitignore ('*.log', 'agent-usage.log')
  - git add -A && commit 'Initialize companion config repo'
  - mkdir -p $COMPANION_DIR
  - Print remote setup instructions

export:
  - mkdir -p $COMPANION_DIR/.claude $COMPANION_DIR/.learnings
  - For each sync dir: if exists in project, mkdir -p + cp -r to companion
  - For each sync file: if exists, cp to companion
  - For .learnings/log.md: if exists, cp to companion

import:
  - If $COMPANION_DIR missing → error + exit 1
  - Reverse of export: cp -r companion → project
  - mkdir -p as needed for each target

status:
  - If $COMPANION_DIR missing → report + exit 0
  - For each sync dir: diff -rq project vs companion, count changed files
  - Report per-dir sync status + total diffs

push:
  - cd $HOME/.claude-configs
  - git add -A; git diff --cached --quiet → 'Nothing to push' + exit 0
  - git commit -m 'Sync {PROJECT_NAME} configs {date}'
  - git push || warn no remote configured

pull:
  - cd $HOME/.claude-configs
  - git pull || warn pull failed

*:
  - Print usage + exit 1

Make file executable (chmod +x).
Write file to .claude/scripts/sync-config.sh. Return path + 1-line summary.
"
)
```

---

### 2. Verify /sync Skill

`/sync` skill created in Module 06. Verify wiring:

```bash
[[ -f ".claude/skills/sync/SKILL.md" ]] || echo "MISSING: /sync skill — should exist from Module 06"
```

If missing → create minimal `/sync` skill inline:

```bash
mkdir -p .claude/skills/sync
```

Write `.claude/skills/sync/SKILL.md`:

```yaml
---
name: sync
description: >
  Use when asked to sync config, backup settings, export/import claude setup,
  push/pull companion repo, check sync status, or restore config on new machine.
  Commands: /sync export, /sync import, /sync status, /sync init, /sync push, /sync pull.
---
```

```markdown
## /sync — Companion Repo Sync

Manage .claude/ config persistence across machines via companion repo at ~/.claude-configs/.

### Commands

| Command | Action |
|---------|--------|
| `/sync init` | Initialize companion repo at ~/.claude-configs/ |
| `/sync export` | Copy project .claude/ → companion |
| `/sync import` | Copy companion → project .claude/ |
| `/sync status` | Diff project vs companion |
| `/sync push` | git add + commit + push companion |
| `/sync pull` | git pull companion from remote |

### Step 1: Run sync-config.sh

```bash
bash .claude/scripts/sync-config.sh {command} {project-name}
```

Project name auto-detected from git root directory name.

### What Syncs
.claude/{rules,skills,agents,hooks,scripts,specs,references}/, .claude/settings.json, CLAUDE.md, .learnings/log.md

### What Does NOT Sync
.claude/settings.local.json, CLAUDE.local.md, .learnings/agent-usage.log, .claude/reports/
```

Verify description contains "Use when" trigger phrase.

---

### 3. Run First Export

```bash
# Ensure scripts dir exists
mkdir -p .claude/scripts

# Initialize companion repo
bash .claude/scripts/sync-config.sh init

# First export
bash .claude/scripts/sync-config.sh export
```

Verify export succeeded:

```bash
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
[[ -d "$HOME/.claude-configs/$PROJECT_NAME/.claude" ]] && echo "PASS: First export complete" || echo "FAIL: Export did not create companion directory"
```

---

### 4. Cold-Start Auto-Import Hook (user-level)

Solves chicken-and-egg: on new machine, `.claude/` is gitignored + missing → no hooks → no auto-import. User-level hook at `~/.claude/settings.json` bridges the gap.

**Ask the user:**

> Would you like me to add a cold-start auto-import hook to your user-level settings (`~/.claude/settings.json`)? This enables automatic config restoration on any machine that has your companion repo cloned. Without it, you'd need to manually run `bash ~/.claude-configs/{project}/sync-config.sh import` on first use.

**If user accepts:**

Read existing `~/.claude/settings.json` (if any). Merge the following SessionStart hook — preserve all existing hooks:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash -c 'P=$(basename \"$(git rev-parse --show-toplevel 2>/dev/null || pwd)\"); C=\"$HOME/.claude-configs/$P\"; if [ ! -f \".claude/settings.json\" ] && [ -d \"$C/.claude\" ]; then for d in rules skills agents hooks scripts specs references; do [ -d \"$C/.claude/$d\" ] && mkdir -p \".claude/$d\" && cp -r \"$C/.claude/$d/.\" \".claude/$d/\" 2>/dev/null; done; [ -f \"$C/.claude/settings.json\" ] && cp \"$C/.claude/settings.json\" .claude/settings.json 2>/dev/null; [ -f \"$C/CLAUDE.md\" ] && cp \"$C/CLAUDE.md\" CLAUDE.md 2>/dev/null; [ -f \"$C/.learnings/log.md\" ] && mkdir -p .learnings && cp \"$C/.learnings/log.md\" .learnings/log.md 2>/dev/null; echo \"Auto-imported .claude/ from companion repo\"; fi'"
      }
    ]
  }
}
```

Hook logic: if `.claude/settings.json` missing AND companion dir exists → copy all sync targets from companion → project. Runs on every session start, no-ops if `.claude/` already present.

**If user declines:** Note in checkpoint. User can always run manual import:

```bash
bash ~/.claude-configs/{project}/sync-config.sh import
```

---

## Checkpoint

```
✅ Module 09 complete — Companion repo sync configured
  sync-config.sh: created at .claude/scripts/sync-config.sh
  /sync skill: {created | verified from Module 06}
  Companion repo: ~/.claude-configs/{project-name}/
  First export: {complete | failed — reason}
  Cold-start hook: {installed in ~/.claude/settings.json | user declined}
  Multi-machine: run '/sync push' after changes, '/sync pull' on other machines
```
