# Module 04 — Create Hooks & Skill Routing

> Create `.claude/settings.json` with hooks and the skill auto-routing system.
> This module makes the bootstrap SELF-CONTAINED — no external plugin dependencies for workflow.

---

## Idempotency

```
IF .claude/settings.json exists → READ, MERGE hooks (upgrade existing, add missing, remove obsolete)
IF helper scripts exist → UPDATE if they differ from current template
IF missing → CREATE all
```

## Why Separate Script Files (not inline hooks)

Each hook script MUST be a separate `.sh` file, NOT inlined into `settings.json` as a one-liner.

**Reasons:**
- **Maintainability:** A 200-character bash one-liner in a JSON string is unreadable and impossible to debug. A separate `.sh` file has syntax highlighting, proper formatting, and comments.
- **Reusability:** Scripts can be tested independently (`bash .claude/hooks/guard-git.sh < test-input.json`).
- **Idempotency:** `/reflect` and future bootstrap re-runs can update script files without parsing JSON-embedded bash.
- **Debuggability:** When a hook fails, `bash -x .claude/hooks/guard-git.sh` shows exactly what happened. Inline hooks give you a wall of escaped quotes.

**Anti-pattern (DO NOT DO THIS):**
```json
"command": "bash -c 'input=$(cat); cmd=$(echo \"$input\" | bash scripts/json-val.sh tool_input.command); if echo \"$cmd\" | grep -qE \"git\\s+push\"; then echo BLOCKED >&2; exit 2; fi'"
```

**Correct pattern:**
```json
"command": "bash .claude/hooks/guard-git.sh"
```

## Create Directories

```bash
mkdir -p .claude/scripts .claude/hooks
```

## 1. Create Helper Script: `.claude/scripts/json-val.sh`

Portable JSON value extractor. Uses Python3 with fallback chain. All hooks use this.

```bash
#!/usr/bin/env bash
# json-val.sh — Extract a value from JSON on stdin
# Usage: cat input.json | bash .claude/scripts/json-val.sh "field_name"
set -euo pipefail

FIELD="$1"
INPUT=$(cat)

# Try python3, then python, then py (Windows)
for cmd in python3 python py; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "$INPUT" | "$cmd" -c "
import sys, json
data = json.load(sys.stdin)
# Support nested fields with dot notation: 'a.b.c'
val = data
for key in '$FIELD'.split('.'):
    if isinstance(val, dict):
        val = val.get(key, '')
    else:
        val = ''
        break
print(val if val is not None else '')
" 2>/dev/null && exit 0
  fi
done

echo ""
```

Make executable: `chmod +x .claude/scripts/json-val.sh`

## 2. Create Hook: `.claude/hooks/detect-env.sh`

SessionStart hook — injects environment context into every session.

```bash
#!/usr/bin/env bash
# detect-env.sh — SessionStart hook
# Outputs environment context for Claude to use

OS="unknown"
case "$(uname -s 2>/dev/null)" in
  Linux*)  OS="Linux" ;;
  Darwin*) OS="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) OS="Windows" ;;
  *) OS="$(uname -s 2>/dev/null || echo Windows)" ;;
esac

SHELL_NAME=$(basename "${SHELL:-bash}")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Branch-aware hints
BRANCH_HINT=""
case "$BRANCH" in
  main|master)   BRANCH_HINT="⚠️ On main branch — create a feature branch before making changes" ;;
  hotfix/*)      BRANCH_HINT="🔥 Hotfix branch — focus on the fix, minimal changes only" ;;
  release/*)     BRANCH_HINT="📦 Release branch — only bugfixes and version bumps" ;;
  feature/*)     BRANCH_HINT="🔧 Feature branch — normal development" ;;
esac

# Auto-import from companion repo (if .claude/ is missing but companion exists)
COMPANION_DIR="$HOME/.claude-configs/$PROJECT_NAME"
if [ ! -f "$PROJECT_ROOT/.claude/settings.json" ] && [ -d "$COMPANION_DIR/.claude" ]; then
  echo "⚡ Auto-importing .claude/ from companion repo at $COMPANION_DIR..."

  # Restore directories
  for dir in rules skills agents hooks scripts specs; do
    if [ -d "$COMPANION_DIR/.claude/$dir" ]; then
      mkdir -p "$PROJECT_ROOT/.claude/$dir"
      cp -r "$COMPANION_DIR/.claude/$dir/." "$PROJECT_ROOT/.claude/$dir/" 2>/dev/null || true
    fi
  done

  # Restore files
  [ -f "$COMPANION_DIR/.claude/settings.json" ] && cp "$COMPANION_DIR/.claude/settings.json" "$PROJECT_ROOT/.claude/settings.json" 2>/dev/null || true
  [ -f "$COMPANION_DIR/CLAUDE.md" ] && cp "$COMPANION_DIR/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null || true

  # Restore learnings
  if [ -f "$COMPANION_DIR/.learnings/log.md" ]; then
    mkdir -p "$PROJECT_ROOT/.learnings"
    cp "$COMPANION_DIR/.learnings/log.md" "$PROJECT_ROOT/.learnings/log.md" 2>/dev/null || true
  fi

  echo "✅ Companion config imported. All project settings restored."
fi

# Check key tools
DOCKER=$(command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && echo "running" || echo "not available")

cat <<EOF
Environment:
  OS: $OS
  Shell: $SHELL_NAME
  Project: $PROJECT_NAME
  Branch: $BRANCH $BRANCH_HINT
  Uncommitted files: $UNCOMMITTED
  Docker: $DOCKER
EOF
```

Make executable: `chmod +x .claude/hooks/detect-env.sh`

### Session Maintenance Checks

The SessionStart hook also checks if maintenance tasks are due. Add these checks to the end of `detect-env.sh`:

```bash
# Check consolidate/reflect conditions
SESSION_COUNT_FILE=".learnings/.session-count"
LAST_DREAM_FILE=".learnings/.last-dream"
LAST_REFLECT_FILE=".learnings/.last-reflect-lines"
LOG_FILE=".learnings/log.md"

# Increment session count
mkdir -p .learnings
COUNT=$(cat "$SESSION_COUNT_FILE" 2>/dev/null || echo 0)
echo $((COUNT + 1)) > "$SESSION_COUNT_FILE"

# Check consolidate conditions (5+ sessions AND 24h since last)
if [ "$COUNT" -ge 5 ]; then
  LAST_DREAM=$(cat "$LAST_DREAM_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  ELAPSED=$(( NOW - LAST_DREAM ))
  if [ "$ELAPSED" -gt 86400 ]; then
    echo "CONSOLIDATE_DUE=true"
  fi
fi

# Check reflect conditions (3+ new learning entries since last reflect)
# Count actual entries (## or ### dated headers), not raw line count
if [ -f "$LOG_FILE" ]; then
  CURRENT_ENTRIES=$(grep -c '^##\+ [0-9]\{4\}-' "$LOG_FILE" 2>/dev/null || echo 0)
  LAST_ENTRIES=$(cat "$LAST_REFLECT_FILE" 2>/dev/null || echo 0)
  NEW_ENTRIES=$(( CURRENT_ENTRIES - LAST_ENTRIES ))
  if [ "$NEW_ENTRIES" -ge 3 ]; then
    echo "REFLECT_DUE=true"
  fi
fi
```

When these checks fire, Claude sees the output in the session context. Add corresponding instructions to the CLAUDE.md template (Module 02):
```
If SessionStart reports CONSOLIDATE_DUE=true, run /consolidate before starting work.
If SessionStart reports REFLECT_DUE=true, run /reflect before starting work.
```

## 3. Create Hook: `.claude/hooks/guard-git.sh`

PreToolUse hook — blocks dangerous git operations.

```bash
#!/usr/bin/env bash
# guard-git.sh — PreToolUse hook for Bash tool
# Exit code 2 = block the tool call

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_name")

# Only check Bash tool calls
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_input.command")

# Allow companion repo operations (sync-config.sh push/pull operates on ~/.claude-configs/)
if echo "$CMD" | grep -qE 'sync-config\.sh|claude-configs'; then
  exit 0
fi

# Allow pushes that explicitly target a non-main/master branch or a different repo
# Block force push (in the PROJECT repo)
if echo "$CMD" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+.*-f\b'; then
  echo "❌ BLOCKED: Force push is not allowed. Use --force-with-lease if you must."
  exit 2
fi

# Block push to main/master (in the PROJECT repo)
if echo "$CMD" | grep -qE 'git\s+push\s+.*\b(main|master)\b|git\s+push\s+-u\s+(origin\s+)?(main|master)'; then
  echo "❌ BLOCKED: Direct push to main/master is not allowed. Use a feature branch."
  exit 2
fi

# Block push from main branch (in the PROJECT repo)
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  if echo "$CMD" | grep -qE 'git\s+push\b'; then
    echo "❌ BLOCKED: You are on $CURRENT_BRANCH. Create a feature branch first."
    exit 2
  fi
fi

# Block hard reset
if echo "$CMD" | grep -qE 'git\s+reset\s+--hard'; then
  echo "⚠️ BLOCKED: git reset --hard discards work. Use git stash or git checkout <file> instead."
  exit 2
fi

exit 0
```

Make executable: `chmod +x .claude/hooks/guard-git.sh`

## 4. Create Hook: `.claude/hooks/track-agent.sh`

SubagentStop hook — logs agent usage for /reflect analysis.

```bash
#!/usr/bin/env bash
# track-agent.sh — SubagentStop hook
# Logs agent usage to .learnings/agent-usage.log

set -euo pipefail

INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "agent_type")
AGENT_ID=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "agent_id")

mkdir -p .learnings

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | type=$AGENT_TYPE | id=$AGENT_ID" >> .learnings/agent-usage.log
```

Make executable: `chmod +x .claude/hooks/track-agent.sh`

## 4b. Create Hook: `.claude/hooks/stop-verify.sh`

Stop hook — nudges Claude to verify work before claiming done.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Stop hook: nudge Claude to verify work before claiming done
INPUT=$(cat)
STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // "end_turn"' 2>/dev/null || echo "end_turn")

if [[ "$STOP_REASON" == "end_turn" ]]; then
  if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    exit 0
  fi
  echo "STOP_HOOK: You have uncommitted changes. Before claiming done, consider: did you verify the changes work? Run /verify if you haven't already."
fi
```

Make executable: `chmod +x .claude/hooks/stop-verify.sh`

## 5. Create `.claude/settings.json`

Create with ONLY the deterministic hooks — hooks that don't depend on what modules 05-18 create.

The **skill routing hook** (UserPromptSubmit) is NOT created here. It is generated in Module 14 (verification) AFTER all skills and agents have been created, by scanning what actually exists.

⚠️ **Schema requirement:** Every hook event entry MUST use the nested `{ "hooks": [...] }` format.
The flat format `{ "type": "command", ... }` directly in the array will fail validation.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/detect-env.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/guard-git.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/track-agent.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/stop-verify.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/pre-compact.sh"
          }
        ]
      }
    ]
  }
}
```

**IMPORTANT:** If `.claude/settings.json` already exists, MERGE the hooks — don't overwrite existing hooks that may have been customized. Add missing hooks only.

**NOTE:** The `UserPromptSubmit` skill routing hook is generated by Module 14 AFTER all
skills and agents are created. It uses `"type": "command"` with `echo` (NOT `"type": "prompt"`).
Prompt-type hooks are evaluated by a small fast model that misinterprets routing instructions
and blocks normal messages. Command-type echo hooks simply prepend text — they never block.

## 5b. PreCompact Hook (state preservation)

Fires before context compaction. Writes critical state to disk so it survives compression.

Create `.claude/hooks/pre-compact.sh`:

```bash
#!/usr/bin/env bash
# pre-compact.sh — PreCompact hook
# Saves working state before context is compressed

set -euo pipefail

STATE_FILE=".claude/compact-state.md"

{
  echo "# Compact State — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  echo "## Modified Files"
  git diff --name-only 2>/dev/null || echo "(not a git repo)"
  echo ""
  echo "## Staged Files"
  git diff --cached --name-only 2>/dev/null || echo "(none)"
  echo ""
  echo "## Current Branch"
  git branch --show-current 2>/dev/null || echo "(unknown)"
} > "$STATE_FILE"

exit 0
```

Add to settings.json template in the hooks section — add a PreCompact entry:
```json
"PreCompact": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/pre-compact.sh"
      }
    ]
  }
]
```

## 5c. Stop Hook — Session Summary (optional)

Fires when Claude's response completes. Can capture session learnings.
Note: The Stop hook fires frequently (every response), so keep it lightweight.
Only log when significant work was done.

Create `.claude/hooks/session-summary.sh`:

```bash
#!/usr/bin/env bash
# session-summary.sh — Stop hook (optional)
# Lightweight session tracking — only logs when files were changed

set -euo pipefail

# Only log if files were modified since last check
CHANGED=$(git diff --name-only 2>/dev/null | wc -l)
[ "$CHANGED" -eq 0 ] && exit 0

# Increment session work counter
COUNTER=".learnings/.session-work-count"
mkdir -p .learnings
COUNT=$(cat "$COUNTER" 2>/dev/null || echo 0)
echo $((COUNT + 1)) > "$COUNTER"

exit 0
```

Mark this hook as **optional** — some users may find it noisy.

## 5d. PostToolUse Observation Hook (instinct system)

Captures tool usage patterns for the instinct learning system.
Fires on Edit, Write, and Bash tool uses — lightweight, must not delay tool execution.

Create `.claude/hooks/observe.sh`:

```bash
#!/usr/bin/env bash
# observe.sh — PostToolUse hook
# Captures tool usage for instinct system observation pipeline

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_name" 2>/dev/null || echo "unknown")

# Only observe write-type tools
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" && "$TOOL" != "Bash" ]] && exit 0

# Skip if observations file exceeds 10MB
OBS_FILE=".learnings/observations.jsonl"
mkdir -p .learnings
if [ -f "$OBS_FILE" ] && [ $(stat -f%z "$OBS_FILE" 2>/dev/null || stat -c%s "$OBS_FILE" 2>/dev/null || echo 0) -gt 10485760 ]; then
  # Rotate: archive and start fresh
  mv "$OBS_FILE" "$OBS_FILE.$(date +%Y%m%d).bak"
fi

# Extract tool-specific fields
if [[ "$TOOL" == "Bash" ]]; then
  CMD=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_input.command" 2>/dev/null || echo "")
  # Skip low-signal read-only commands
  [[ "$CMD" =~ ^(ls|cat|pwd|echo|head|tail|wc|which|type|file)( |$) ]] && exit 0
  # Truncate long commands to 200 chars
  CMD="${CMD:0:200}"
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"tool\":\"$TOOL\",\"cmd\":\"$CMD\"}" >> "$OBS_FILE"
else
  FILE=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_input.file_path" 2>/dev/null || echo "")
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"tool\":\"$TOOL\",\"file\":\"$FILE\"}" >> "$OBS_FILE"
fi

exit 0
```

Add to settings.json template:
```json
"PostToolUse": [
  {
    "matcher": "Edit|Write|Bash",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/observe.sh"
      }
    ]
  }
]
```

Important guardrails:
- 10MB cap with daily rotation prevents unbounded growth
- Filter: only Edit, Write, Bash (skip Read events — too noisy)
- Bash captures `cmd` field (truncated to 200 chars); Edit/Write capture `file` field
- Low-signal read-only commands (`ls`, `cat`, `pwd`, etc.) are skipped for Bash
- Never let Claude read raw JSONL directly — use /reflect to analyze

## 6. Optional: Auto-Format Hook

Only add if user said "yes" to auto-format in Module 01 discovery.

Create `.claude/hooks/auto-format.sh`:

```bash
#!/usr/bin/env bash
# auto-format.sh — PostToolUse hook
# Auto-formats files after Edit/Write operations

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_name")

# Only format after Edit or Write
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0

FILE=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_input.file_path")
[ -z "$FILE" ] && exit 0

# Format based on extension
case "$FILE" in
  *.cs)     dotnet format --include "$FILE" 2>/dev/null || true ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.html)
            npx prettier --write "$FILE" 2>/dev/null || true ;;
  *.py)     python3 -m black "$FILE" 2>/dev/null || true ;;
  *.go)     gofmt -w "$FILE" 2>/dev/null || true ;;
  *.rs)     rustfmt "$FILE" 2>/dev/null || true ;;
esac

exit 0
```

Add to settings.json:
```json
"PostToolUse": [
  {
    "hooks": [
      {
        "type": "command",
        "matcher": "Edit|Write",
        "command": "bash .claude/hooks/auto-format.sh"
      }
    ]
  }
]
```

## Checkpoint

```
✅ Module 04 complete — Hooks created:
  - SessionStart: env detection + companion auto-import + maintenance checks
  - PreToolUse: git guard (blocks force push, push to main, hard reset)
  - SubagentStop: agent usage tracking
  - Stop: verification nudge (reminds to verify before claiming done)
  - PreCompact: state preservation before context compaction
  - UserPromptSubmit: deferred to Module 14 (needs full skill inventory)
  {- PostToolUse: auto-format (if enabled)}
```
