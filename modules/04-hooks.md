# Step 4 — Create .claude/settings.json (Hooks)

> **Mode C**: If settings.json exists, read it first. Merge new hooks — preserve existing customizations.

## CRITICAL: Hooks receive JSON on stdin

There is NO `$CLAUDE_TOOL_INPUT` environment variable. All hook scripts must read stdin.

## Create json-val.sh (Portable jq Replacement)

Create `.claude/scripts/json-val.sh` — uses Python3 (no jq dependency):

```bash
#!/usr/bin/env bash
# json-val.sh — extract a value from JSON on stdin
# Usage: echo '{"key":"val"}' | json-val.sh key
set -euo pipefail
KEY="$1"
python3 -c "
import sys, json
data = json.load(sys.stdin)
keys = '${KEY}'.split('.')
val = data
for k in keys:
    if isinstance(val, dict):
        val = val.get(k, '')
    else:
        val = ''
        break
print(val if val is not None else '')
"
```

`chmod +x .claude/scripts/json-val.sh`

## Hook Event Lifecycle

| Event | When | stdin | Use Cases |
|-------|------|-------|-----------|
| **SessionStart** | Session begins | `{session_id, cwd}` | Env detection, startup tasks |
| **Notification** | Claude sends notification | `{message, title}` | Custom notification routing |
| **UserPromptSubmit** | User sends prompt | `{prompt}` | Prompt validation/enrichment |
| **PreToolUse** | Before tool execution | `{tool_name, tool_input}` | Guard/block dangerous ops |
| **PostToolUse** | After tool execution | `{tool_name, tool_input, tool_output}` | Auto-format, logging |
| **SubagentStop** | Subagent finishes | `{agent_name, task, result}` | Usage tracking |
| **Stop** | Claude stops responding | `{stop_reason, message}` | Quality checks |

Also available: **PreCompact** (preserve context before compaction), **PostToolUseFailure**, **InstructionsLoaded**, **SessionEnd**, **SubagentStart**, and others.

## Hook Types

- **command**: Shell script (most common)
- **prompt**: Inject text into Claude's context
- **http**: POST to a URL
- **agent**: Run a subagent

## Hook Exit Codes

- `exit 0` — success, proceed (stdout JSON parsed as output)
- `exit 1` — non-blocking error, action STILL PROCEEDS (stderr shown in verbose mode only)
- `exit 2` — **BLOCK** the action (stderr shown to user as error)

**WARNING**: Security hooks MUST use `exit 2` to block. `exit 1` only logs — it does NOT prevent the action.

## Create guard-git.sh (Security Critical)

Create `.claude/scripts/guard-git.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT=$(cat)
TOOL=$(echo "$INPUT" | "$SCRIPT_DIR/json-val.sh" tool_name)

if [[ "$TOOL" != "Bash" ]]; then
  exit 0
fi

CMD=$(echo "$INPUT" | "$SCRIPT_DIR/json-val.sh" tool_input.command)

# Block dangerous git operations
if echo "$CMD" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+-f\b'; then
  echo "BLOCKED: git push --force is prohibited. Use --force-with-lease instead." >&2
  exit 2
fi

if echo "$CMD" | grep -qE 'git\s+push\s+(origin\s+)?(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master. Use a feature branch + PR." >&2
  exit 2
fi

if echo "$CMD" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard can destroy work. Use git stash or git reset --soft." >&2
  exit 2
fi

exit 0
```

`chmod +x .claude/scripts/guard-git.sh`

## settings.json Structure

Create `.claude/settings.json`:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": ".claude/scripts/detect-env.sh"
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|Write|Edit",
        "type": "command",
        "command": ".claude/scripts/guard-git.sh"
      }
    ],
    "SubagentStop": [
      {
        "type": "command",
        "command": ".claude/scripts/track-agent.sh"
      }
    ]
  }
}
```

## Always Add: SubagentStop Tracking Hook

Create `.claude/scripts/track-agent.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT=$(cat)
AGENT=$(echo "$INPUT" | "$SCRIPT_DIR/json-val.sh" agent_name)
TASK=$(echo "$INPUT" | "$SCRIPT_DIR/json-val.sh" task)
RESULT=$(echo "$INPUT" | "$SCRIPT_DIR/json-val.sh" result)

LOG=".learnings/agent-usage.log"
mkdir -p "$(dirname "$LOG")"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $AGENT | $TASK | $RESULT" >> "$LOG"
exit 0
```

`chmod +x .claude/scripts/track-agent.sh`

## Always Add: SessionStart Environment Detection

Create `.claude/scripts/detect-env.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

OS=$(uname -s)
SHELL_NAME=$(basename "${SHELL:-unknown}")
NODE_VER=$(node --version 2>/dev/null || echo "not installed")
PYTHON_VER=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "not installed")

# Detect package manager
PKG_MGR="unknown"
[ -f "bun.lockb" ] && PKG_MGR="bun"
[ -f "pnpm-lock.yaml" ] && PKG_MGR="pnpm"
[ -f "yarn.lock" ] && PKG_MGR="yarn"
[ -f "package-lock.json" ] && PKG_MGR="npm"
[ -f "Cargo.lock" ] && PKG_MGR="cargo"
[ -f "go.sum" ] && PKG_MGR="go"
[ -f "Pipfile.lock" ] && PKG_MGR="pipenv"
[ -f "poetry.lock" ] && PKG_MGR="poetry"

cat <<ENVEOF
{"output":"Environment: OS=$OS, Shell=$SHELL_NAME, Node=$NODE_VER, Python=$PYTHON_VER, PackageManager=$PKG_MGR"}
ENVEOF
exit 0
```

`chmod +x .claude/scripts/detect-env.sh`

## Optional Hooks — Ask the User

STOP and ask which optional hooks to add:

1. **Auto-format on save** — PostToolUse hook that runs formatter after Write/Edit
2. **SQL block guard** — PreToolUse hook that checks for raw SQL in Bash commands
3. **Read-only directory guard** — PreToolUse hook blocking writes to specified paths
4. **Prompt-based quality hook** — prompt hook on Stop to check response quality

### Auto-Format Hook Template (if selected)

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT=$(cat)
TOOL=$(echo "$INPUT" | "$SCRIPT_DIR/json-val.sh" tool_name)
[[ "$TOOL" == "Write" || "$TOOL" == "Edit" ]] || exit 0
FILE=$(echo "$INPUT" | "$SCRIPT_DIR/json-val.sh" tool_input.file_path)
# Run project formatter on the file
{format_command} "$FILE" 2>/dev/null || true
exit 0
```

### Prompt-Based Hook Template (if selected)

Add to settings.json under the appropriate event:
```json
{
  "type": "prompt",
  "prompt": "Before finishing: verify your response addresses the user's actual question, includes error handling, and follows project conventions from code-standards.md."
}
```

**WARNING**: Do NOT add a UserPromptSubmit hook for correction detection — it triggers on every prompt and is too aggressive.

## Required Events in settings.json

Verify these three are present: **SessionStart**, **PreToolUse**, **SubagentStop**.

## Checkpoint

Print: `Step 4 complete — .claude/settings.json created with hooks`
Print: `Scripts: json-val.sh, guard-git.sh, detect-env.sh, track-agent.sh`
