# Bash Content Analysis — claude-bootstrap

> Local analysis of shell scripts + JSON configs in this repo.
> Source of truth for proj-code-writer-bash.
> Last analyzed: 2026-04-10.

---

## Script Inventory

```yaml
location: .claude/hooks/
scripts:
  - auto-format.sh          # PostToolUse Edit|Write — auto-format saved files
  - detect-env.sh           # SessionStart — env context + maintenance checks
  - guard-git.sh            # PreToolUse Bash — block dangerous git ops (exit 2)
  - log-failures.sh         # PostToolUse Bash — log non-zero Bash exits to .learnings/log.md
  - observe.sh              # PostToolUse Edit|Write|Bash — JSONL event stream
  - pre-compact.sh          # PreCompact — preserve state across compaction
  - stop-verify.sh          # Stop — nudge verification before claiming done
  - sync-companion.sh       # Stop — sync .claude/ to companion repo
  - track-agent.sh          # SubagentStop — log agent usage

utilities:
  - .claude/scripts/json-val.sh   # portable JSON field extractor (bash builtins fallback when jq absent)

configs:
  - .claude/settings.json         # hooks, permissions, MCP (nested hook format)
```

---

## Component Types

### 1. Hook Script

```yaml
type: hook_script
path: .claude/hooks/{name}.sh
naming: kebab-case.sh, descriptive verb-first
shebang: "#!/usr/bin/env bash"
safety: "set -euo pipefail" (line 2 mandatory)
lifecycle_events:
  - SessionStart         # fires on session begin — emit env context, maintenance checks
  - UserPromptSubmit     # fires on user message — inject nudges/reminders via stdout
  - PreToolUse           # fires before tool call — matcher filters (Bash, Edit|Write); exit 2 = BLOCK + stderr msg
  - PostToolUse          # fires after tool call — matcher filters; observe/log
  - PreCompact           # fires before context compaction — write state to disk
  - SubagentStop         # fires when subagent completes — track usage
  - Stop                 # fires on end_turn — verification nudge, companion sync
input: JSON on stdin via `input=$(cat)` — NEVER env vars
input_extraction:
  - preferred: "jq -r '.tool_name // \"\"'"  # if jq available
  - fallback: "bash $SCRIPT_DIR/json-val.sh tool_name"  # portable bash builtins
  - common_paths:
      - tool_name                # which tool fired
      - tool_input.command       # Bash cmd
      - tool_input.file_path     # Edit/Write path
      - tool_response.exit_code  # Bash result code
      - tool_response.output     # Bash stdout/stderr
      - stop_reason              # Stop hook
exit_codes:
  0: continue (allow tool call | normal completion)
  2: BLOCK (PreToolUse only) — stderr message shown to Claude
  other: non-blocking failure (logged but not surfaced)
output_channels:
  stdout: plain text injected into Claude context (nudges, reminders)
  stderr: only for PreToolUse block messages (exit 2)
  side_effects: write to .learnings/, .claude/reports/ transient logs
length_target: 30-100 lines
```

### 2. Utility Script

```yaml
type: utility_script
path: .claude/scripts/{name}.sh
example: json-val.sh — portable bash JSON extractor
pattern: pure function, stdin in → stdout out, no side effects
shebang: "#!/usr/bin/env bash"
safety: "set -euo pipefail"
no_global_state: use `local` in functions
```

### 3. JSON Config Writer

```yaml
type: json_config
path: .claude/settings.json | .mcp.json | .claude/agents/agent-index.yaml
format: strict JSON or strict YAML
settings_hooks_schema: >
  Nested array format — NEVER flat:
  {
    "hooks": {
      "PreToolUse": [
        { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash ..." }] }
      ]
    }
  }
matcher_values: tool name(s) pipe-separated regex ("Bash", "Edit|Write", or omit for all)
validation:
  - "python3 -m json.tool < file.json" (portable)
  - "jq . file.json" (if jq available)
  - "bash -n script.sh" (shell syntax)
```

---

## json-val.sh Usage Pattern

Every hook that needs JSON field extraction follows this pattern:

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPT_DIR="$PROJECT_DIR/.claude/scripts"
INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | bash "$SCRIPT_DIR/json-val.sh" "tool_name" 2>/dev/null || printf 'unknown')
```

Prefer jq when available, fall back to json-val.sh for portability:

```bash
if command -v jq >/dev/null 2>&1; then
  EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0')
else
  EXIT_CODE=$(echo "$INPUT" | bash "$SCRIPT_DIR/json-val.sh" "tool_response.exit_code")
fi
```

---

## Idempotency Patterns

- `mkdir -p` (never `mkdir` alone — fails if exists)
- Append-only logs: rotate at size threshold (`observe.sh` rotates at 10MB)
- File creation with header check: `[[ ! -f "$LOG_FILE" ]] && cat > "$LOG_FILE" << 'EOF' ... EOF`
- State files under `.learnings/` (`.session-count`, `.last-dream`, `.last-reflect-lines`)
- Backup via timestamped suffix: `mv "$FILE" "$FILE.$(date +%Y%m%d%H%M%S).bak"`

---

## Exit Code Conventions

| Code | Meaning | Use case |
|------|---------|----------|
| 0 | success — continue | all hooks default |
| 2 | BLOCK | PreToolUse only — prints stderr, blocks tool call |
| other | non-blocking failure | logged; treated as 0 for flow |

PreToolUse exit 2 pattern:
```bash
if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push.*(--force|-f\b)'; then
  printf 'BLOCKED: Force push is not allowed.\n' >&2
  exit 2
fi
```

---

## Settings.json Nested Hook Schema

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/log-failures.sh" }
        ]
      }
    ]
  }
}
```

Critical: the inner `hooks` array is REQUIRED. Flat arrays `[{ "type": "command", ... }]` at the top level break.

---

## Cross-Platform Gotchas (Windows MINGW64)

- Use `uname -s` → case-match `MINGW*|MSYS*|CYGWIN*` → set `OS=Windows`
- Paths: forward slashes work in bash even on Windows — NEVER backslashes in scripts
- Line endings: Unix LF in scripts (not CRLF) — git should have `eol=lf` for `.sh`
- `stat` flags differ: `stat -c%s` (Linux/MINGW) vs `stat -f%z` (macOS) — fallback chain:
  ```bash
  SIZE=$(stat -c%s "$F" 2>/dev/null || stat -f%z "$F" 2>/dev/null || printf '0')
  ```
- `date +%s` for epoch seconds works everywhere; `date -u +%Y-%m-%dT%H:%M:%SZ` for ISO UTC
- `find -mtime +30` works everywhere; avoid `-printf` (not in BSD find)

---

## Sanitization Patterns

Log-writing hooks MUST sanitize user-controlled input to prevent heredoc injection:

```bash
CMD_SAFE="${CMD_SHORT//\`/\'}"       # backticks → single quotes
CMD_SAFE="${CMD_SAFE//\$/\$}"        # literal dollar (no change but defensive)
```

Use `printf '%s' "$VAR"` over `echo "$VAR"` — `echo` may interpret `-e`, backslash escapes on some shells.

---

## Skip-Conditions Pattern

Hooks that log tool output typically skip trivial/expected failures:

```bash
case "$CMD" in
  grep\ *|rg\ *|diff\ *|test\ *|\[\ *|\[\[\ *)
    exit 0 ;;
  *"command -v"*|*"which "*)
    exit 0 ;;
esac
if [[ "$CMD" =~ \|\|\ *(true|echo|exit|:) ]] || [[ "$CMD" =~ 2\>/dev/null$ ]]; then
  exit 0
fi
```

Rationale: grep exit 1 on no-match is normal; `cmd 2>/dev/null` and `|| true` patterns intentionally suppress errors.

---

## References

- `modules/03-hooks.md` → hook lifecycle + installation
- `.claude/rules/shell-standards.md` → canonical shell conventions
- `.claude/agents/proj-code-writer-bash.md` → canonical bash writer agent
- Claude Code hooks spec: https://code.claude.com/docs/en/hooks
