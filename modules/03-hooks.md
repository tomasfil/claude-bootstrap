# Module 03 — Hooks & Scripts

> Generate hook scripts and settings.json via code-writer-bash agent dispatch.
> Main thread = pure orchestrator. All script/config generation by code-writer-bash agent.

---

## Idempotency

Per script: read existing → update if different from template. Create if missing.
settings.json: merge hooks — never overwrite custom config.

Foundation agents: already created in Module 01. This module dispatches code-writer-bash via
inline prompts (BOOTSTRAP_DISPATCH_PROMPT) since agent .md files aren't loaded mid-session
(claude-code#6497).

## Actions

### 1. Prepare Discovery Context

Read Module 01 output (conversation context). Compile dispatch inputs:
- OS + shell (for path separators, uname detection)
- git_strategy (track | companion | ephemeral — determines sync-companion.sh behavior)
- auto_format preference (yes | no — determines auto-format.sh creation)
- Detected formatters list (prettier, dotnet, black, gofmt, rustfmt, etc.)
- read-only-dirs list

Create directories:
```bash
mkdir -p .claude/scripts .claude/hooks
```

### 2. Dispatch: json-val.sh

Dispatch code-writer-bash via inline prompt (BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Create json-val.sh utility",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT — code-writer-bash}

Task: Write .claude/scripts/json-val.sh — portable JSON value extractor.
All hook scripts depend on this. Uses Python3 with fallback chain (python3 → python → py).

Requirements:
- Reads JSON from stdin, extracts field by name (first argument)
- Support dot-notation for nested fields: 'a.b.c'
- Try python3, python, py in order (cross-platform)
- Print empty string on missing field (never error)
- set -euo pipefail, #!/usr/bin/env bash

Template:
  FIELD='$1'; INPUT=$(cat)
  For each python cmd: echo '$INPUT' | '$cmd' -c 'import sys,json; data=json.load(sys.stdin); val=data; [nested traversal]; print(val if val is not None else '')'

chmod +x .claude/scripts/json-val.sh
Write to .claude/scripts/json-val.sh. Return ONLY: path + 1-line summary <100 chars."
)
```

### 3. Dispatch: All Hook Scripts (single dispatch, multiple files)

Dispatch code-writer-bash via inline prompt (BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Create all hook scripts",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT — code-writer-bash}

Task: Write all hook scripts below. Each as separate .sh file in .claude/hooks/.
chmod +x each after writing. All scripts: #!/usr/bin/env bash + set -euo pipefail.
All scripts use .claude/scripts/json-val.sh for JSON extraction.

Scripts to create:

1. .claude/hooks/detect-env.sh (SessionStart)
   Purpose: inject environment context into every session.
   Content:
   - OS detection via uname -s (Linux|macOS|Windows via MINGW/MSYS/CYGWIN)
   - Shell, branch, uncommitted count, project name
   - Branch-aware hints (main→create feature branch, hotfix→minimal changes, release→bugfixes only)
   - Companion auto-import: if .claude/settings.json missing but ~/.claude-configs/{project}/.claude/ exists,
     copy .claude/, .learnings/, CLAUDE.md, CLAUDE.local.md from companion
   - Docker detection (docker info test)
   - Spec cleanup: find .claude/specs -mtime +30 -type f -delete 2>/dev/null || true
   - Session maintenance checks:
     * Increment .learnings/.session-count
     * CONSOLIDATE_DUE=true if session_count>=5 AND 24h since .learnings/.last-dream
     * REFLECT_DUE=true if 3+ new entries in .learnings/log.md since .learnings/.last-reflect-lines
     (count entries via grep -c '^##+ [0-9]{4}-')

2. .claude/hooks/guard-git.sh (PreToolUse — matcher: Bash)
   Purpose: block dangerous git operations. Exit 2 = block.
   Content:
   - Extract tool_name via json-val.sh → only check Bash tool calls
   - Allow companion repo operations (sync-config.sh, claude-configs)
   - Block: git push --force/-f (suggest --force-with-lease)
   - Block: git push to main/master (suggest feature branch)
   - Block: git push while ON main/master branch
   - Block: git reset --hard (suggest git stash or git checkout)
   - Exit 0 for all non-matching commands

3. .claude/hooks/track-agent.sh (SubagentStop)
   Purpose: log agent usage for /reflect analysis.
   Content:
   - Extract agent_type + agent_id via json-val.sh
   - Append timestamped entry to .learnings/agent-usage.log
   - Format: ISO8601 | type={type} | id={id}

4. .claude/hooks/stop-verify.sh (Stop)
   Purpose: nudge verification before claiming done.
   Content:
   - Extract stop_reason (default: end_turn) — use jq if available
   - Only fire on end_turn
   - If uncommitted changes exist (git diff not quiet): echo reminder to verify/run /verify

5. .claude/hooks/sync-companion.sh (Stop — conditional)
   {if git_strategy == companion}:
   Purpose: sync .claude/ to umbrella companion repo on session end. Zero tokens.
   Content:
   - COMPANION_ROOT="$HOME/.claude-configs"
   - PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
   - COMPANION="$COMPANION_ROOT/$PROJECT_NAME"
   - Skip if [[ ! -d "$COMPANION_ROOT/.git" ]] — exit 0
   - Abort if [[ -d "$COMPANION/.git" ]] — echo "sync-companion: nested .git at $COMPANION, run /migrate-bootstrap (migration 006)" >&2; exit 1
   - NEVER run `git init` inside "$COMPANION" — umbrella is the only repo
   - mkdir -p "$COMPANION/.claude" "$COMPANION/.learnings"
   - rsync (preferred) or cp -r fallback:
       .claude/       → "$COMPANION/.claude/"
       .learnings/    → "$COMPANION/.learnings/"
   - Copy (if exist): CLAUDE.md, CLAUDE.local.md → "$COMPANION/"
   - Stage + commit via umbrella ONLY, path-scoped to this project:
       git -C "$COMPANION_ROOT" add -- "$PROJECT_NAME"
       git -C "$COMPANION_ROOT" diff --cached --quiet -- "$PROJECT_NAME" && exit 0
       git -C "$COMPANION_ROOT" commit -q -m "sync $PROJECT_NAME: $(date -Iseconds)" -- "$PROJECT_NAME"
       git -C "$COMPANION_ROOT" push -q 2>/dev/null || true
   - NEVER `cd "$COMPANION"` and run `git add -A` — creates nested repo
   {if git_strategy != companion}:
   Create stub: #!/usr/bin/env bash + exit 0

6. .claude/hooks/pre-compact.sh (PreCompact)
   Purpose: save working state before context compaction.
   Content:
   - Write .claude/compact-state.md with: timestamp, modified files (git diff --name-only),
     staged files (git diff --cached --name-only), current branch

7. .claude/hooks/log-failures.sh (PostToolUse — matcher: Bash)
   Purpose: auto-log non-zero exit code failures to .learnings/log.md.
   Content:
   - Extract exit_code, command, output (jq preferred, json-val.sh fallback)
   - Skip exit_code==0 or empty
   - Skip expected failures: grep/rg (exit 1=no match), git diff --quiet, test/[/[[,
     command -v/which, commands with || (true|echo|exit|:), commands ending 2>/dev/null
   - Truncate output to 500 chars, command to 200 chars
   - Sanitize backticks + $ in output
   - Create .learnings/log.md with header if missing
   - Append: ### {date} — failure: Bash exit code {N} + command + output
   - Echo to Claude context: FAILURE_LOGGED message with diagnose-before-retry nudge

8. .claude/hooks/observe.sh (PostToolUse — matcher: Edit|Write|Bash)
   Purpose: capture tool usage for instinct observation pipeline.
   Content:
   - Extract tool_name → only process Edit, Write, Bash
   - 10MB cap on .learnings/observations.jsonl → rotate on exceed
   - Bash: extract command (skip read-only: ls/cat/pwd/echo/head/tail/wc/which/type/file),
     truncate to 200 chars, write JSONL w/ ts+tool+cmd
   - Edit/Write: extract file_path, write JSONL w/ ts+tool+file

9. .claude/hooks/auto-format.sh (PostToolUse — matcher: Edit|Write)
   {if auto_format == yes}:
   Purpose: language-agnostic auto-format after file writes.
   Content — detect formatters at RUNTIME, not hardcoded per-extension:
     ext="${{file##*.}}"
     if command -v prettier >/dev/null 2>&1 && [[ "$ext" =~ ^(ts|tsx|js|jsx|json|css|html|md)$ ]]; then
       prettier --write "$file"
     elif command -v dotnet >/dev/null 2>&1 && [[ "$ext" == "cs" ]]; then
       dotnet format --include "$file"
     elif command -v black >/dev/null 2>&1 && [[ "$ext" == "py" ]]; then
       black "$file"
     elif command -v autopep8 >/dev/null 2>&1 && [[ "$ext" == "py" ]]; then
       autopep8 --in-place "$file"
     elif command -v ruff >/dev/null 2>&1 && [[ "$ext" == "py" ]]; then
       ruff format "$file"
     elif command -v gofmt >/dev/null 2>&1 && [[ "$ext" == "go" ]]; then
       gofmt -w "$file"
     elif command -v rustfmt >/dev/null 2>&1 && [[ "$ext" == "rs" ]]; then
       rustfmt "$file"
     fi
   All formatter calls: append 2>/dev/null || true (never fail hook)
   {if auto_format == no}: skip this script entirely

Write all files. chmod +x each. Return ONLY: all paths + 1-line summary <100 chars."
)
```

### 4. Dispatch: settings.json

Dispatch code-writer-bash via inline prompt (BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Create settings.json with all hooks",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT — code-writer-bash}

Task: Write .claude/settings.json with all hooks wired.

CRITICAL FORMAT: Every hook event entry MUST use nested { 'hooks': [...] } format.
Flat format { 'type': 'command', ... } directly in array = INVALID.

Structure:

{
  'hooks': {
    'SessionStart': [
      { 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/detect-env.sh' }] }
    ],
    'PreToolUse': [
      { 'matcher': 'Bash', 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/guard-git.sh' }] }
    ],
    'SubagentStop': [
      { 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/track-agent.sh' }] }
    ],
    'Stop': [
      { 'hooks': [
        { 'type': 'command', 'command': 'bash .claude/hooks/stop-verify.sh' },
        { 'type': 'command', 'command': 'bash .claude/hooks/sync-companion.sh' }
      ]}
    ],
    'PreCompact': [
      { 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/pre-compact.sh' }] }
    ],
    'PostToolUse': [
      { 'matcher': 'Edit|Write|Bash', 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/observe.sh' }] },
      { 'matcher': 'Bash', 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/log-failures.sh' }] }
      {if auto_format: , { 'matcher': 'Edit|Write', 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/auto-format.sh' }] } }
    ],
    'UserPromptSubmit': [
      { 'hooks': [{ 'type': 'command', 'command': 'echo \'SKILL CHECK: Before starting work, evaluate if a skill from the Skill tool applies. Skills orchestrate agents — do not bypass.\'' }] }
    ]
  }
}

Requirements:
- settings.json: ONLY hooks + structural config — no model defaults, no attribution, no schema URLs
- UserPromptSubmit: ~30 tokens, command-type echo (NOT prompt-type — prompt-type blocks normal messages)
- If .claude/settings.json already exists: READ it, MERGE hooks (add missing, update changed, preserve custom)
- Validate JSON after writing: python3 -c 'import json; json.load(open(\".claude/settings.json\"))'

Write to .claude/settings.json. Return ONLY: path + 1-line summary <100 chars."
)
```

Verify: `python3 -c "import json; json.load(open('.claude/settings.json'))"` succeeds.

### 5. Verify Wiring

Main thread checks (no dispatch needed):

```bash
# All hook scripts exist + executable
ls -la .claude/hooks/*.sh
ls -la .claude/scripts/json-val.sh

# settings.json valid JSON
python3 -c "import json; json.load(open('.claude/settings.json'))"

# UserPromptSubmit is minimal (~30 tokens, not 2500)
python3 -c "
import json
s = json.load(open('.claude/settings.json'))
cmd = s['hooks']['UserPromptSubmit'][0]['hooks'][0]['command']
assert 'SKILL CHECK' in cmd, 'Missing SKILL CHECK nudge'
assert len(cmd) < 200, f'UserPromptSubmit too long: {len(cmd)} chars'
print(f'UserPromptSubmit: {len(cmd)} chars — OK')
"
```

## Checkpoint

```
✅ Module 03 complete — Hooks + settings.json created:
  - SessionStart: env detection + companion auto-import + maintenance + spec cleanup
  - PreToolUse Bash: git guard (blocks force push, push to main, hard reset)
  - SubagentStop: agent usage tracking
  - Stop: verification nudge + companion sync ({if companion})
  - PreCompact: state preservation
  - PostToolUse Bash: failure logging → .learnings/log.md
  - PostToolUse Edit|Write|Bash: observation capture
  {- PostToolUse Edit|Write: auto-format (if enabled)}
  - UserPromptSubmit: 30-token skill nudge
  - settings.json: all hooks wired, valid JSON
```
