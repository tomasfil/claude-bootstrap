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
       real-world failure on a downstream project (2026-04).
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
   # Additive-only per-target restore: copies only targets MISSING from project.
   # Never overwrites existing project files. Never copies machine-specific files.
   COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"
   COMPANION_STATUS=""
   if [[ -d "$HOME/.claude-configs/.git" ]]; then
     if [[ ! -f "$PROJECT_DIR/.claude/settings.json" ]] && [[ -f "$COMPANION_DIR/.claude/settings.json" ]]; then
       mkdir -p "$PROJECT_DIR/.claude"
       # Per-SYNC_DIR additive restore — matches sync scope exactly; never touches settings.local.json
       for d in rules skills agents hooks scripts specs references; do
         if [[ -d "$COMPANION_DIR/.claude/$d" ]] && [[ ! -d "$PROJECT_DIR/.claude/$d" ]]; then
           mkdir -p "$PROJECT_DIR/.claude/$d"
           cp -r "$COMPANION_DIR/.claude/$d/." "$PROJECT_DIR/.claude/$d/" 2>/dev/null || true
         fi
       done
       # settings.json: copy only if missing (never settings.local.json — machine-specific)
       if [[ -f "$COMPANION_DIR/.claude/settings.json" ]] && [[ ! -f "$PROJECT_DIR/.claude/settings.json" ]]; then
         cp "$COMPANION_DIR/.claude/settings.json" "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || true
       fi
       # .learnings/: copy only if missing
       if [[ -d "$COMPANION_DIR/.learnings" ]] && [[ ! -d "$PROJECT_DIR/.learnings" ]]; then
         cp -r "$COMPANION_DIR/.learnings" "$PROJECT_DIR/" 2>/dev/null || true
       fi
       # CLAUDE.md: copy only if missing
       if [[ -f "$COMPANION_DIR/CLAUDE.md" ]] && [[ ! -f "$PROJECT_DIR/CLAUDE.md" ]]; then
         cp "$COMPANION_DIR/CLAUDE.md" "$PROJECT_DIR/" 2>/dev/null || true
       fi
       # CLAUDE.local.md: NEVER restored — machine-specific, in DO NOT SYNC (modules/09:65)
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
   # NEVER inline the fallback inside the substitution — output concatenation corrupts the value.
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
   - rsync (preferred) or nuke-and-repave cp -r fallback:
       rsync: --exclude='.git' --exclude='settings.local.json' on export (settings.local.json is DO NOT SYNC)
       .claude/       → "$COMPANION/.claude/"    (rsync --delete | rm -rf + cp -r /.)
       .learnings/    → "$COMPANION/.learnings/" (rsync --delete | rm -rf + cp -r /.)
       Fallback (no rsync): nuke-and-repave — rm -rf "${COMPANION:?}/.claude/" then cp -r "$PROJECT_ROOT/.claude/." "$COMPANION/.claude/"
       Fallback cp -r: use trailing /. (not /*) to include dotfiles
       After fallback cp -r: rm -f "$COMPANION/.claude/settings.local.json" (machine-specific, DO NOT SYNC)
   - Copy (if exist): CLAUDE.md → "$COMPANION/"
   - NEVER copy CLAUDE.local.md — machine-specific, in DO NOT SYNC (modules/09:65)
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

10. .claude/hooks/gate-task-complete.sh (TaskCompleted — risk-aware completion gate)
   Purpose: block task completion on medium/high/critical risk tasks that lack verification evidence
   in their subject or description. `TaskCompleted` is a standard Claude Code hook event
   (https://code.claude.com/docs/en/hooks) — NOT a PreToolUse matcher. Payload fields are
   TOP-LEVEL (`.task_subject`, `.task_description`, `.task_id`, `.transcript_path`) — NOT nested under
   `tool_input`. Block semantics: write diagnostic to stderr and `exit 2` — NO JSON stdout
   (`decision:block` is the PreToolUse pattern, not TaskCompleted). Bypass escape hatch:
   `TASKCOMPLETED_GATE_BYPASS=1` environment variable emits a warning line to stderr and exits 0.
   Shell-standards compliant: #!/usr/bin/env bash, set -euo pipefail, cat stdin, [[ ]], quoted vars,
   printf over echo -e.

   Content (full spec — write exactly as shown, no elision, no "similar pattern follows"):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # TaskCompleted input: read full stdin JSON. Every task completion attempt fires this hook;
   # there is no tool_name guard (TaskCompleted is its own event, not a PreToolUse matcher).
   INPUT=$(cat)

   # Bypass escape hatch: TASKCOMPLETED_GATE_BYPASS=1 emits a warning and exits 0.
   # Use this for emergency overrides or automated runs where verification happens elsewhere.
   if [[ "${TASKCOMPLETED_GATE_BYPASS:-}" == "1" ]]; then
     printf '[gate-task-complete] bypass active (TASKCOMPLETED_GATE_BYPASS=1) — skipping risk + verification checks\n' >&2
     exit 0
   fi

   # Extract TaskCompleted payload fields. All fields are TOP-LEVEL — no tool_input nesting.
   # .claude/scripts/json-val.sh uses BARE field names (no leading dot — leading-dot paths
   # split to ['', 'name'] which resolve to empty string and silently break the gate).
   # The script interprets `a.b.c` as nested dict traversal, not a jq-style prefix.
   SUBJECT=$(printf '%s' "$INPUT" | bash .claude/scripts/json-val.sh 'task_subject' 2>/dev/null || printf '')
   DESCRIPTION=$(printf '%s' "$INPUT" | bash .claude/scripts/json-val.sh 'task_description' 2>/dev/null || printf '')
   TASK_ID=$(printf '%s' "$INPUT" | bash .claude/scripts/json-val.sh 'task_id' 2>/dev/null || printf '')

   # Parse risk marker from combined subject + description. Accepts case-insensitive variants:
   # `risk: low`, `Risk: High`, `risk:medium`, etc. First match wins.
   COMBINED="$SUBJECT $DESCRIPTION"
   RISK=$(printf '%s' "$COMBINED" | grep -oiE 'risk: ?(low|medium|high|critical)' | head -n1 | grep -oiE '(low|medium|high|critical)' | tr '[:upper:]' '[:lower:]' || true)

   # No risk marker OR explicit low risk → allow completion (fail-open on unknown,
   # intentional allow on low). The gate is informational discipline for medium+, not a
   # hard barrier on every task.
   if [[ -z "$RISK" || "$RISK" == "low" ]]; then
     exit 0
   fi

   # Verification evidence scan. Presence of any of these markers in the subject or
   # description proves the task author asserted verification before marking complete.
   # Patterns: `verified:`, `tests: pass`, `build: pass`, `/verify ran`, `/review ran`.
   if printf '%s' "$COMBINED" | grep -qiE 'verified:|tests: ?pass|build: ?pass|/verify ran|/review ran'; then
     exit 0
   fi

   # Medium/high/critical risk with no verification evidence → block.
   MESSAGE="[gate-task-complete] Task '$TASK_ID' risk=$RISK — verification evidence required before marking complete. Add 'verified: <how>' or 'tests: pass' / 'build: pass' / '/verify ran' / '/review ran' to the task description, or set TASKCOMPLETED_GATE_BYPASS=1 to override."
   printf '%s\n' "$MESSAGE" >&2
   exit 2
   ```
   Verification: chmod +x .claude/hooks/gate-task-complete.sh. Smoke-test fixtures (see Step 5
   Verify Wiring) confirm no-marker → exit 2 and with-marker → exit 0.

11. .claude/hooks/mcp-discovery-gate.sh (PreToolUse — matcher: Grep|Glob|Search)
   Purpose: block symbol-shaped Grep/Glob/Search when codebase-memory-mcp or serena is registered in any MCP scope (project .mcp.json, user ~/.claude.json top-level or projects.<cwd>.mcpServers, managed managed-settings.json, or a plugin-bundled server).
   Reads PreToolUse JSON on stdin, classifies via python3 regex, emits JSON decision + exit 2 on block.
   Fail-open on parse errors (broken hook never breaks unrelated tool use). See .claude/rules/mcp-routing.md.
   Layer 3 enforcement for the MCP-first discipline — layer 1 is the rule (mcp-routing.md Grep Ban),
   layer 2 is the STEP 0 First-Tool Contract clause in every proj-* agent, layer 3 is this hook
   mechanically blocking symbol-shaped Grep/Glob/Search at PreToolUse.

   Content (full spec — write exactly as shown, no elision, no "similar pattern follows"):
   ```bash
   #!/usr/bin/env bash
   # mcp-discovery-gate.sh — PreToolUse hook: block symbol-shaped Grep/Glob/Search
   # when cmm or serena MCP is available in ANY scope (project, user, local,
   # managed, plugin). Routes the agent/main to the graph instead.
   # Reads PreToolUse JSON on stdin. Emits JSON decision on stdout. Exits 2 to block.
   # Fail-open on every error path (a broken hook must never break unrelated tool use).
   set -euo pipefail

   # Read PreToolUse JSON from stdin into a shell variable, then pass to python3
   # via an environment variable. This avoids the MINGW64 heredoc/stdin collision:
   # `printf ... | python3 - <<'PY'` sends the heredoc (script) to python3's stdin,
   # NOT the piped INPUT — so the pipe is lost on MINGW64 / Git Bash. Env-var
   # passing is reliable across platforms and does not collide with the script
   # heredoc.
   INPUT=$(cat)

   # Single python3 invocation: parse tool input JSON, check MCP availability
   # across all known scopes, classify pattern. Emits one of:
   #   allow                   → exit 0
   #   block|<trigger label>   → emit decision JSON on stdout + stderr reason + exit 2
   RESULT=$(CLAUDE_HOOK_INPUT="$INPUT" python3 - <<'PY'
   import sys, json, os, re, glob

   def fail_open():
       print("allow")
       sys.exit(0)

   # ── Parse PreToolUse JSON from CLAUDE_HOOK_INPUT env var ────────
   raw = os.environ.get("CLAUDE_HOOK_INPUT", "")
   if not raw:
       fail_open()
   try:
       data = json.loads(raw)
   except Exception:
       fail_open()
   if not isinstance(data, dict):
       fail_open()

   tool_name = data.get("tool_name") or ""
   tool_input = data.get("tool_input") or {}

   # Only gate Grep / Glob / Search — Read handled by user-level priming hook
   if tool_name not in ("Grep", "Glob", "Search"):
       fail_open()

   pattern = ""
   if isinstance(tool_input, dict):
       pattern = tool_input.get("pattern") or tool_input.get("query") or ""
   if not isinstance(pattern, str):
       pattern = str(pattern)
   if not pattern:
       fail_open()

   # ── MCP availability check (multi-scope) ────────────────────────
   # Returns True if codebase-memory-mcp or serena is registered in any scope
   # Claude Code reads: project, user, local, managed, plugin. Silent fail-open
   # on every parse error — a broken hook must never break unrelated tool use.
   #
   # Scopes covered (per https://code.claude.com/docs/en/mcp and
   # https://code.claude.com/docs/en/settings):
   #
   #   1. Project scope — ./.mcp.json (`mcpServers` key) at project root
   #   2. User scope    — ~/.claude.json top-level `mcpServers` key
   #   3. Local scope   — ~/.claude.json → `projects.<abs-path>.mcpServers`
   #                      (stored per-project in the same ~/.claude.json file)
   #   4. Managed scope — file-based managed-settings.json + managed-mcp.json
   #                      per-OS system path, plus managed-settings.d/*.json
   #                      drop-in directory (merged alphabetically)
   #   5. Plugin scope  — plugins may bundle .mcp.json at plugin root; best-effort
   #                      shallow scan under ~/.claude/plugins/*/.mcp.json
   #
   # NOT covered (unreachable or out-of-scope for a bash hook):
   #   - Windows HKCU registry managed settings (requires reg.exe query)
   #   - Server-managed remote fetch (requires auth + network)
   #   - Plugins installed under non-standard roots
   TARGET_SERVERS = ("codebase-memory-mcp", "serena")

   def has_target(mcp_servers):
       if not isinstance(mcp_servers, dict):
           return False
       return any(name in mcp_servers for name in TARGET_SERVERS)

   def load_json(path):
       try:
           with open(path, "r", encoding="utf-8") as f:
               return json.load(f)
       except Exception:
           return None

   def mcp_available():
       cwd = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
       home = os.path.expanduser("~")

       # 1. Project scope — ./.mcp.json
       d = load_json(os.path.join(cwd, ".mcp.json"))
       if d and has_target(d.get("mcpServers")):
           return True

       # 2. User scope + 3. Local scope — ~/.claude.json
       d = load_json(os.path.join(home, ".claude.json"))
       if d:
           # User scope: top-level "mcpServers"
           if has_target(d.get("mcpServers")):
               return True
           # Local scope: projects.<cwd>.mcpServers
           projects = d.get("projects") or {}
           if isinstance(projects, dict):
               # Build candidate keys for the current project. Claude Code may store
               # paths with native or forward-slash separators, absolute or realpath.
               candidates = {cwd, os.path.abspath(cwd)}
               try:
                   candidates.add(os.path.realpath(cwd))
               except Exception:
                   pass
               for c in list(candidates):
                   candidates.add(c.replace("\\", "/"))
               for key, entry in projects.items():
                   if key in candidates and isinstance(entry, dict):
                       if has_target(entry.get("mcpServers")):
                           return True

       # 4. Managed scope — file-based managed-settings.json + managed-mcp.json
       managed_dirs = []
       if sys.platform == "darwin":
           managed_dirs.append("/Library/Application Support/ClaudeCode")
       elif sys.platform.startswith("linux"):
           managed_dirs.append("/etc/claude-code")
       if os.name == "nt" or sys.platform == "win32":
           managed_dirs.append(r"C:\Program Files\ClaudeCode")

       for mdir in managed_dirs:
           for fname in ("managed-settings.json", "managed-mcp.json"):
               d = load_json(os.path.join(mdir, fname))
               if d and has_target(d.get("mcpServers")):
                   return True
           dropin = os.path.join(mdir, "managed-settings.d")
           if os.path.isdir(dropin):
               try:
                   for f in sorted(os.listdir(dropin)):
                       if f.startswith(".") or not f.endswith(".json"):
                           continue
                       d = load_json(os.path.join(dropin, f))
                       if d and has_target(d.get("mcpServers")):
                           return True
               except Exception:
                   pass

       # 5. Plugin scope — best-effort shallow scan of ~/.claude/plugins/*/.mcp.json
       plugin_root = os.path.join(home, ".claude", "plugins")
       if os.path.isdir(plugin_root):
           try:
               for plugin_mcp in glob.glob(os.path.join(plugin_root, "*", ".mcp.json")):
                   d = load_json(plugin_mcp)
                   if d and has_target(d.get("mcpServers")):
                       return True
           except Exception:
               pass

       return False

   try:
       if not mcp_available():
           fail_open()
   except Exception:
       fail_open()

   # ── Exemptions (text search is correct) ─────────────────────────
   # 1. Quoted phrase containing whitespace → literal string
   if re.search(r'"[^"]*\s[^"]*"', pattern) or re.search(r"'[^']*\s[^']*'", pattern):
       print("allow"); sys.exit(0)
   # 2. File-extension / path literal
   if re.search(r'\.(md|json|yaml|yml|toml|ini|conf|cfg|env|log|txt|csv|xml|sh|ps1|bat)(\b|$)', pattern):
       print("allow"); sys.exit(0)
   # 3. URL / absolute path literal
   if re.search(r'https?://|file://|[a-zA-Z]:\\|/tmp/|/etc/|/usr/|\$HOME', pattern):
       print("allow"); sys.exit(0)
   # 4. Error / log marker prefix
   if re.search(r'(?i)\b(error|exception|failed|warning|unable|cannot|refused|timeout)[:\s]', pattern):
       print("allow"); sys.exit(0)
   # 5. Pure lowercase phrase with whitespace
   if re.fullmatch(r'[a-z0-9_\- ]+', pattern) and ' ' in pattern:
       print("allow"); sys.exit(0)
   # 6. Short lowercase snake_case / kebab identifier
   if re.fullmatch(r'[a-z][a-z0-9_\-]*', pattern) and len(pattern) <= 40:
       print("allow"); sys.exit(0)
   # 7. Markdown heading anchor
   if pattern.startswith('^#'):
       print("allow"); sys.exit(0)

   # ── Symbol-shape triggers (block) ───────────────────────────────
   triggers = [
       (r'\b[A-Z][a-z]+[A-Z][a-zA-Z0-9]*\b', "CamelCase identifier"),
       (r'\bI[A-Z][a-z][a-zA-Z0-9]+\b', "I-prefixed interface"),
       (r'\b(class|namespace|interface|struct|record|trait|impl|enum|type)\s+[A-Z]', "type declaration search"),
       (r'\b(def|fn|function|func|public|private|protected|internal|static)\s+[A-Za-z_]', "function / method declaration search"),
       (r'^\^?[A-Z][a-zA-Z0-9]{2,}\$?$', "bare PascalCase anchor"),
       (r'(\||^)\s*[A-Z][a-zA-Z0-9]{2,}\s*(\||$)', "alternation with PascalCase token"),
       (r'\b[A-Z][a-zA-Z0-9]*\.[A-Z][a-zA-Z0-9]*\b', "qualified type reference"),
   ]
   for rx, label in triggers:
       if re.search(rx, pattern):
           print("block|" + label)
           sys.exit(0)

   print("allow")
   PY
   )

   case "$RESULT" in
     allow|"")
       exit 0
       ;;
     block\|*)
       TRIGGER="${RESULT#block|}"
       # Emit structured decision on stdout + reason on stderr + exit 2
       cat <<JSON
   {"decision":"block","reason":"MCP-first discipline: pattern looks like a named symbol (${TRIGGER}). Use cmm.search_graph(name_pattern=...) or serena.find_symbol(name_path=...) first. Stale cmm graph → detect_changes → index_repository → retry (silent, no permission-seek, per max-quality.md §6). Grep fallback only after a fresh cmm search returns 0 hits, and MUST be disclosed per mcp-routing.md Transparent Fallback section. See .claude/rules/mcp-routing.md sections: CMM Freshness, Grep Ban, Permission-Seeking Ban, Transparent Fallback."}
   JSON
       printf 'BLOCKED by mcp-discovery-gate: pattern matches %s — route through cmm/serena first. See .claude/rules/mcp-routing.md.\n' "$TRIGGER" >&2
       exit 2
       ;;
     *)
       # Unknown result → fail-open (defense in depth)
       exit 0
       ;;
   esac
   ```
   Constraints: MINGW64-safe (python3 for JSON + regex, base64 round-trip on pattern to survive
   shell word-splitting), fail-open (parse errors → exit 0), read-only (no state files),
   python3 only dependency, ~30ms typical.
   Verification: chmod +x .claude/hooks/mcp-discovery-gate.sh; bash -n .claude/hooks/mcp-discovery-gate.sh.
   Smoke test: `printf '{"tool_name":"Grep","tool_input":{"pattern":"FooBarService"}}' | bash .claude/hooks/mcp-discovery-gate.sh`
   → exit 2 if cmm/serena is reachable in any MCP scope (project, user, managed, plugin), exit 0 if dormant.

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
      { 'matcher': 'Bash', 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/guard-git.sh' }] },
      // mcp-discovery-gate: mechanically enforces MCP-first discipline per .claude/rules/mcp-routing.md (Grep Ban / First-Tool Contract).
      { 'matcher': 'Grep|Glob|Search', 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/mcp-discovery-gate.sh' }] }
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
    ],
    'TaskCompleted': [
      { 'hooks': [{ 'type': 'command', 'command': 'bash .claude/hooks/gate-task-complete.sh' }] }
    ]
  }
}

Requirements:
- settings.json: ONLY hooks + structural config — no model defaults, no attribution, no schema URLs
- UserPromptSubmit: command-type dispatch to prompt-nudge.sh (NOT prompt-type — prompt-type blocks normal messages). Script emits ~30-token skill nudge + conditional max-quality nudge on write/impl verbs.
- SubagentStop: both track-agent.sh (logging) AND check-quality.sh (Max Quality Doctrine Layer 3 literal scan) must be registered in the same hooks array
- TaskCompleted: top-level key, NO `matcher` field (TaskCompleted is its own event type, not a PreToolUse matcher). Single hook entry dispatching gate-task-complete.sh. Merge into existing settings.json — do NOT touch the PreToolUse array.
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

# TaskCompleted gate: syntax check + settings wiring + 2 fixture smoke tests.
# Smoke tests use `set +e; EC=$?; set -e` + explicit `|| { FAIL; exit 1; }` so a wrong
# exit code surfaces as a hard failure. The earlier `; [[ $? -eq N ]] && echo OK` form
# silently passed on failure (no echo, no error) — do NOT reintroduce that pattern.
bash -n .claude/hooks/gate-task-complete.sh
grep -qF 'gate-task-complete.sh' .claude/settings.json && echo "TaskCompleted gate — OK"

set +e
printf '%s' '{"task_subject":"Fix bug","task_description":"risk: high — fixed","task_id":"t1","transcript_path":""}' | bash .claude/hooks/gate-task-complete.sh >/dev/null 2>&1
EC=$?
set -e
if [[ $EC -eq 2 ]]; then
  echo "smoke: no-marker (risk:high) → exit 2 OK"
else
  echo "FAIL: smoke no-marker (risk:high) → expected exit 2, got $EC" >&2
  exit 1
fi

set +e
printf '%s' '{"task_subject":"Fix bug","task_description":"risk: high — fixed. verified: tests pass","task_id":"t1","transcript_path":""}' | bash .claude/hooks/gate-task-complete.sh >/dev/null 2>&1
EC=$?
set -e
if [[ $EC -eq 0 ]]; then
  echo "smoke: with-marker (risk:high + verified) → exit 0 OK"
else
  echo "FAIL: smoke with-marker (risk:high + verified) → expected exit 0, got $EC" >&2
  exit 1
fi
```

## Checkpoint

```
✅ Module 03 complete — Hooks + settings.json created:
  - SessionStart: env detection + companion auto-import + maintenance + spec cleanup
  - PreToolUse Bash: git guard (blocks force push, push to main, hard reset)
  - PreToolUse Grep|Glob|Search: mcp-discovery-gate (blocks symbol-shaped patterns when codebase-memory-mcp or serena is reachable in any MCP scope — project .mcp.json, user ~/.claude.json, managed settings, or plugin-bundled; fail-open on parse errors)
  - SubagentStop: agent usage tracking + Max Quality Doctrine Layer 3 literal scan (check-quality.sh)
  - Stop: verification nudge (incl. MAX QUALITY reminder) + companion sync ({if companion})
  - PreCompact: state preservation
  - PostToolUse Bash: failure logging → .learnings/log.md
  - PostToolUse Edit|Write|Bash: observation capture
  {- PostToolUse Edit|Write: auto-format (if enabled)}
  - UserPromptSubmit: prompt-nudge.sh — skill-check always + MAX QUALITY on write/impl verbs
  - TaskCompleted: risk-aware completion gate (blocks medium+ tasks without verification evidence; bypass: TASKCOMPLETED_GATE_BYPASS=1)
  - settings.json: all hooks wired, valid JSON
```
