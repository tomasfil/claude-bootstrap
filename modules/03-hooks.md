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
   Purpose: inject environment context + run session-maintenance counters.
   Shell-standards compliant: #!/usr/bin/env bash, set -euo pipefail, quoted vars, [[ ]].
   **CRITICAL — bulletproof numeric reads.** This script runs on every SessionStart. Any
   failure renders the hook broken for the entire session. Two landmines to avoid:
   (a) `grep -c` prints `0` AND exits 1 on zero matches — with pipefail + `||` fallback
       INSIDE `$()`, the fallback output concatenates to grep's `0`, yielding `0\n0` which
       then breaks `$((...))` arithmetic with `syntax error: operand expected`. Verified
       real-world failure 2026-04-13 (blazedex project).
   (b) Empty / CRLF / non-numeric file content breaks `$((VAR - X))` arithmetic.
   Fix: NEVER put fallback inside `$()` for a numeric capture — use the canonical
   `VAR=$(cmd) || VAR=0` idiom OUTSIDE `$()`, then regex-validate the numeric value
   before arithmetic.

   Content (full spec — write exactly as shown, no elision, no "similar pattern"):
   ```bash
   #!/usr/bin/env bash
   # detect-env.sh — SessionStart hook
   # Outputs environment context + runs session maintenance checks.
   set -euo pipefail

   PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

   # OS detection
   OS="unknown"
   case "$(uname -s 2>/dev/null)" in
     Linux*)  OS="Linux" ;;
     Darwin*) OS="macOS" ;;
     MINGW*|MSYS*|CYGWIN*) OS="Windows" ;;
     *) OS="$(uname -s 2>/dev/null || printf 'Windows')" ;;
   esac

   SHELL_NAME=$(basename "${SHELL:-bash}")
   BRANCH=$(git branch --show-current 2>/dev/null) || BRANCH="unknown"
   [[ -n "$BRANCH" ]] || BRANCH="unknown"
   UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') || UNCOMMITTED=0
   [[ "$UNCOMMITTED" =~ ^[0-9]+$ ]] || UNCOMMITTED=0
   PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
   PROJECT_NAME=$(basename "$PROJECT_ROOT")

   # Branch-aware hints
   BRANCH_HINT=""
   case "$BRANCH" in
     main|master) BRANCH_HINT="— on main, create feature branch for non-trivial work" ;;
     hotfix/*)    BRANCH_HINT="— hotfix branch, minimal changes only" ;;
     release/*)   BRANCH_HINT="— release branch, bugfixes and version bumps only" ;;
     feature/*)   BRANCH_HINT="— feature branch, normal development" ;;
   esac

   # Docker availability
   DOCKER_STATUS="unavailable"
   if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
     DOCKER_STATUS="available"
   fi

   # Companion repo auto-import (nested layout: ~/.claude-configs/{project}/.claude/)
   COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"
   COMPANION_STATUS=""
   if [[ -d "$HOME/.claude-configs/.git" ]]; then
     if [[ ! -f "$PROJECT_DIR/.claude/settings.json" ]] && [[ -f "$COMPANION_DIR/.claude/settings.json" ]]; then
       mkdir -p "$PROJECT_DIR/.claude"
       cp -r "$COMPANION_DIR/.claude/"* "$PROJECT_DIR/.claude/" 2>/dev/null || true
       [[ -d "$COMPANION_DIR/.learnings" ]] && cp -r "$COMPANION_DIR/.learnings" "$PROJECT_DIR/" 2>/dev/null || true
       [[ -f "$COMPANION_DIR/CLAUDE.md" ]] && cp "$COMPANION_DIR/CLAUDE.md" "$PROJECT_DIR/" 2>/dev/null || true
       [[ -f "$COMPANION_DIR/CLAUDE.local.md" ]] && cp "$COMPANION_DIR/CLAUDE.local.md" "$PROJECT_DIR/" 2>/dev/null || true
       COMPANION_STATUS="COMPANION_IMPORTED=true"
     fi
   fi

   # Spec cleanup — delete specs older than 30 days
   if [[ -d "$PROJECT_DIR/.claude/specs" ]]; then
     find "$PROJECT_DIR/.claude/specs" -mtime +30 -type f -delete 2>/dev/null || true
   fi

   cat <<EOF
   Environment:
     OS: $OS
     Shell: $SHELL_NAME
     Project: $PROJECT_NAME
     Branch: $BRANCH $BRANCH_HINT
     Uncommitted files: $UNCOMMITTED
     Docker: $DOCKER_STATUS
   EOF

   [[ -n "$COMPANION_STATUS" ]] && printf '%s\n' "$COMPANION_STATUS"

   # --- Session maintenance: bulletproof numeric reads ---
   SESSION_COUNT_FILE="$PROJECT_DIR/.learnings/.session-count"
   LAST_DREAM_FILE="$PROJECT_DIR/.learnings/.last-dream"
   LAST_REFLECT_FILE="$PROJECT_DIR/.learnings/.last-reflect-lines"
   LOG_FILE="$PROJECT_DIR/.learnings/log.md"

   mkdir -p "$PROJECT_DIR/.learnings"

   # read_int: return a validated integer from a file, 0 on any failure/missing/garbage.
   # NEVER inline this as `VAR=$(cat f || printf 0)` — output concatenation corrupts the value.
   read_int() {
     local file="$1"
     local val=0
     if [[ -f "$file" ]]; then
       val=$(tr -d '\r\n ' < "$file" 2>/dev/null) || val=0
     fi
     [[ "$val" =~ ^[0-9]+$ ]] || val=0
     printf '%s' "$val"
   }

   # count_matches: return a validated match count, 0 on any failure/missing/zero-match.
   # grep -c prints "0" AND exits 1 on zero matches — that is the landmine.
   # `VAR=$(grep -c ...) || VAR=0` is the canonical fix: the `|| VAR=0` sits OUTSIDE
   # the command substitution, so the fallback does not concatenate to grep's stdout.
   count_matches() {
     local pattern="$1"
     local file="$2"
     local n=0
     [[ -f "$file" ]] || { printf '0'; return; }
     n=$(grep -cE "$pattern" "$file" 2>/dev/null) || n=0
     [[ "$n" =~ ^[0-9]+$ ]] || n=0
     printf '%s' "$n"
   }

   # Increment session count
   COUNT=$(read_int "$SESSION_COUNT_FILE")
   COUNT=$((COUNT + 1))
   printf '%s\n' "$COUNT" > "$SESSION_COUNT_FILE"

   # Consolidate: 5+ sessions AND 24h since last dream
   if [[ "$COUNT" -ge 5 ]]; then
     LAST_DREAM=$(read_int "$LAST_DREAM_FILE")
     NOW=$(date +%s)
     ELAPSED=$(( NOW - LAST_DREAM ))
     if [[ "$ELAPSED" -gt 86400 ]]; then
       printf 'CONSOLIDATE_DUE=true\n'
     fi
   fi

   # Reflect: 3+ new dated entries in log.md since last reflect
   CURRENT_ENTRIES=$(count_matches '^##+ [0-9]{4}-' "$LOG_FILE")
   LAST_ENTRIES=$(read_int "$LAST_REFLECT_FILE")
   NEW_ENTRIES=$(( CURRENT_ENTRIES - LAST_ENTRIES ))
   if [[ "$NEW_ENTRIES" -ge 3 ]]; then
     printf 'REFLECT_DUE=true\n'
   fi
   ```
   Verification: `chmod +x .claude/hooks/detect-env.sh`. Smoke test after writing:
   `bash .claude/hooks/detect-env.sh >/dev/null` must exit 0 even when `.learnings/` is empty.

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

3b. .claude/hooks/check-quality.sh (SubagentStop — Max Quality Doctrine Layer 3)
   Purpose: scan subagent final output for high-precision elision + effort-pad literals.
   Blocks subagent completion when a literal match fires; reviewer (Layer 6) catches the rest.
   Shell-standards compliant: #!/usr/bin/env bash, set -euo pipefail, cat stdin, [[ ]], quoted vars, no echo -e.

   Content (full spec — write exactly as shown, no elision):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # SubagentStop input includes last_assistant_message (string)
   INPUT=$(cat)
   MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')

   # Empty message → nothing to scan
   if [[ -z "$MSG" ]]; then
     exit 0
   fi

   # Self-block prevention: agent quoting doctrine files or the doctrine name itself
   # would false-positive every literal below. Skip scan in that case.
   if printf '%s' "$MSG" | grep -q -F -e '.claude/rules/max-quality.md' \
                                     -e '.claude/hooks/check-quality.sh' \
                                     -e 'Max Quality Doctrine'; then
     exit 0
   fi

   # High-precision elision literals (grep -E, case-insensitive)
   ELISION_RE='for brevity|\.\.\. ?\(omitted|pseudocode|abbreviated for|truncated for|similar pattern follows|etc\. \(more'

   # High-precision effort-pad literals (grep -E, case-insensitive)
   EFFORT_RE='significant time|complex effort|substantial effort|large undertaking'

   # NOTE — EXCLUDED from hook regex (delegated to Layer 6 proj-code-reviewer):
   #   TODO:          — cannot distinguish linked `TODO: #123` from bare unlinked `TODO:`
   #   \b(weeks?|days?)\b — collides w/ cron/retention/date content (7 days, 30 days, 24h elapsed)
   # Reviewer has context; regex does not. Keep hook high-precision.

   MATCH=$(printf '%s' "$MSG" | grep -oE -i -m1 "$ELISION_RE|$EFFORT_RE" || true)

   if [[ -n "$MATCH" ]]; then
     # decision:block feeds reason back to subagent; it must continue its task
     jq -n --arg r "Max-quality check failed: $MATCH. Provide full output without abbreviation or effort-padding." \
       '{decision:"block", reason:$r}'
     exit 0
   fi

   exit 0
   ```
   Verification: chmod +x .claude/hooks/check-quality.sh; jq required (already a project dep).

4. .claude/hooks/stop-verify.sh (Stop)
   Purpose: nudge verification before claiming done.
   Content:
   - Extract stop_reason (default: end_turn) — use jq if available
   - Only fire on end_turn
   - If uncommitted changes exist (git diff not quiet): echo reminder to verify/run /verify
   - **Max-quality nudge (append to existing echo text)**: ` MAX QUALITY: verify full scope, no elision, calibrated effort — run /review before /commit.`
   - **Constraint**: Stop hook input schema does NOT include `last_assistant_message` (verified 2026-04-11 via code.claude.com/docs/en/hooks). Fields available: session_id, transcript_path, cwd, permission_mode, hook_event_name, stop_reason. Output scanning on main thread would require tailing transcript_path JSONL on every end-of-turn — high cost, high blast radius. Therefore: NUDGE ONLY, no scan, no `decision:block`. Max-quality enforcement for main-thread output degrades to (a) CLAUDE.md @import of `.claude/rules/max-quality.md` for always-loaded doctrine context, (b) SubagentStop check-quality.sh for subagent output (where `last_assistant_message` IS available), (c) proj-code-reviewer completeness checks (Layer 6) for context-sensitive violations.

4b. .claude/hooks/prompt-nudge.sh (UserPromptSubmit — replaces inline echo)
   Purpose: skill-routing nudge on every prompt; conditional max-quality nudge on write/impl verbs.
   Shell-standards compliant. Exit 0 always (UserPromptSubmit nudges never block).

   Content (full spec — write exactly as shown, no elision):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   INPUT=$(cat)
   PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""')

   # Always-on skill routing nudge
   printf '%s\n' 'SKILL CHECK: Before starting work, evaluate if a skill from the Skill tool applies. Skills orchestrate agents — do not bypass.'

   # Conditional max-quality nudge on write/impl verbs (case-insensitive, word boundary)
   if printf '%s' "$PROMPT" | grep -qiE '\b(write|implement|create|generate|fix|build|refactor)\b'; then
     printf '%s\n' 'MAX QUALITY: full scope, no elision, calibrated effort, verify before claiming done.'
   fi

   exit 0
   ```
   Verification: chmod +x .claude/hooks/prompt-nudge.sh.

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
      { 'hooks': [
        { 'type': 'command', 'command': 'bash .claude/hooks/track-agent.sh' },
        { 'type': 'command', 'command': 'bash .claude/hooks/check-quality.sh' }
      ]}
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
      { 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/prompt-nudge.sh' }] }
    ]
  }
}

Requirements:
- settings.json: ONLY hooks + structural config — no model defaults, no attribution, no schema URLs
- UserPromptSubmit: command-type dispatch to prompt-nudge.sh (NOT prompt-type — prompt-type blocks normal messages). Script emits ~30-token skill nudge + conditional max-quality nudge on write/impl verbs.
- SubagentStop: both track-agent.sh (logging) AND check-quality.sh (Max Quality Doctrine Layer 3 literal scan) must be registered in the same hooks array
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

# UserPromptSubmit dispatches to prompt-nudge.sh (not inline echo)
python3 -c "
import json
s = json.load(open('.claude/settings.json'))
cmd = s['hooks']['UserPromptSubmit'][0]['hooks'][0]['command']
assert 'prompt-nudge.sh' in cmd, 'UserPromptSubmit should dispatch to prompt-nudge.sh'
assert len(cmd) < 200, f'UserPromptSubmit too long: {len(cmd)} chars'
print(f'UserPromptSubmit: {len(cmd)} chars — OK')
"

# SubagentStop wires both track-agent.sh AND check-quality.sh
python3 -c "
import json
s = json.load(open('.claude/settings.json'))
cmds = [h['command'] for entry in s['hooks']['SubagentStop'] for h in entry['hooks']]
assert any('track-agent.sh' in c for c in cmds), 'Missing track-agent.sh'
assert any('check-quality.sh' in c for c in cmds), 'Missing check-quality.sh (Max Quality Layer 3)'
print('SubagentStop: track-agent + check-quality — OK')
"
```

## Checkpoint

```
✅ Module 03 complete — Hooks + settings.json created:
  - SessionStart: env detection + companion auto-import + maintenance + spec cleanup
  - PreToolUse Bash: git guard (blocks force push, push to main, hard reset)
  - SubagentStop: agent usage tracking + Max Quality Doctrine Layer 3 literal scan (check-quality.sh)
  - Stop: verification nudge (incl. MAX QUALITY reminder) + companion sync ({if companion})
  - PreCompact: state preservation
  - PostToolUse Bash: failure logging → .learnings/log.md
  - PostToolUse Edit|Write|Bash: observation capture
  {- PostToolUse Edit|Write: auto-format (if enabled)}
  - UserPromptSubmit: prompt-nudge.sh — skill-check always + MAX QUALITY on write/impl verbs
  - settings.json: all hooks wired, valid JSON
```
