# Migration: Self-Improvement Failure Hook

> Add PostToolUse hook that auto-logs Bash command failures to .learnings/log.md and rewrite CLAUDE.md Self-Improvement section from post-hoc to pre-action gate.

---

```yaml
# --- Migration Metadata ---
id: "010"
name: "Self-Improvement Failure Hook"
description: >
  Add PostToolUse hook that auto-logs Bash command failures to .learnings/log.md
  and rewrite CLAUDE.md Self-Improvement section from post-hoc to pre-action gate.
  Closes the feedback loop — Claude never self-logged because instructions were
  end-of-response and had no enforcement.
base_commit: "91a6fa3"
date: "2026-03-31"
breaking: false
```

---

## Changes

| Action | Path | Summary |
|--------|------|---------|
| add | `.claude/hooks/log-failures.sh` | PostToolUse hook — auto-logs Bash failures |
| modify | `.claude/settings.json` | Add PostToolUse Bash matcher for log-failures.sh |
| modify | `CLAUDE.md` | Rewrite Self-Improvement section (pre-action gate) |
| modify | `.learnings/log.md` | Ensure file exists with header |

---

## Actions

### Step 1 — Create `.claude/hooks/log-failures.sh`

Fetch from bootstrap repo or create with this content:

````bash
#!/usr/bin/env bash
# log-failures.sh — PostToolUse hook for Bash
# Auto-logs non-zero exit code failures to .learnings/log.md
# Outputs reminder to Claude to diagnose before retrying

set -euo pipefail

INPUT=$(cat)

# Extract fields from PostToolUse JSON
if command -v jq >/dev/null 2>&1; then
  EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0')
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
  OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.output // ""')
else
  EXIT_CODE=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_response.exit_code")
  CMD=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_input.command")
  OUTPUT=$(echo "$INPUT" | bash .claude/scripts/json-val.sh "tool_response.output")
fi

# Only log failures (non-zero exit)
[[ "$EXIT_CODE" == "0" || -z "$EXIT_CODE" ]] && exit 0

# Skip expected/trivial failures
case "$CMD" in
  grep\ *|rg\ *|diff\ *|git\ diff\ --quiet*|test\ *|\[\ *|\[\[\ *)
    exit 0 ;;
  *"command -v"*|*"which "*)
    exit 0 ;;
  *"git diff --quiet"*)
    exit 0 ;;
esac
if [[ "$CMD" =~ \|\|\ *(true|echo|exit|:) ]] || [[ "$CMD" =~ 2\>/dev/null$ ]]; then
  exit 0
fi

# Truncate output to 500 chars
TRUNCATED="${OUTPUT:0:500}"
[[ ${#OUTPUT} -gt 500 ]] && TRUNCATED="${TRUNCATED}... (truncated)"

# Truncate command to 200 chars
CMD_SHORT="${CMD:0:200}"

# Sanitize — prevent heredoc injection (backticks + subshells in cmd/output)
CMD_SAFE="${CMD_SHORT//\`/\'}"
CMD_SAFE="${CMD_SAFE//\$/\$}"
OUT_SAFE="${TRUNCATED//\`/\'}"
OUT_SAFE="${OUT_SAFE//\$/\$}"

# Build log entry
DATE=$(date -u +%Y-%m-%d)
LOG_FILE=".learnings/log.md"
mkdir -p .learnings

# Create log file with header if missing
if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" << 'HEADER'
# Learnings Log

> Corrections, discoveries, and patterns. Managed by Self-Improvement triggers in CLAUDE.md.
> Run `/reflect` to promote pending entries to rules/CLAUDE.md or instincts.

---

HEADER
fi

# Append failure entry (printf — no subshell injection risk)
printf '\n### %s — failure: Bash exit code %s\nStatus: pending review\n\n**Command:** `%s`\n**Exit code:** %s\n**Output:**\n```\n%s\n```\n' \
  "$DATE" "$EXIT_CODE" "$CMD_SAFE" "$EXIT_CODE" "$OUT_SAFE" >> "$LOG_FILE"

# Output reminder to Claude's context
echo "FAILURE_LOGGED: exit $EXIT_CODE from '${CMD_SHORT:0:80}' → .learnings/log.md. Diagnose root cause before retrying."

exit 0
````

Make executable:
```bash
chmod +x .claude/hooks/log-failures.sh
```

### Step 2 — Add hook to `.claude/settings.json`

Read `.claude/settings.json`. Add a new entry to the `"PostToolUse"` array (create the array if it doesn't exist):

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash .claude/hooks/log-failures.sh"
    }
  ]
}
```

This must coexist with any existing PostToolUse entries (e.g., `observe.sh` on `"Edit|Write|Bash"`, `auto-format.sh` on `"Edit|Write"`). Add it as a new object in the array, don't replace existing entries.

**Idempotency:** If a PostToolUse entry with `"bash .claude/hooks/log-failures.sh"` already exists in settings.json, skip this step.

### Step 3 — Update CLAUDE.md Self-Improvement section

Find the `## Self-Improvement` section in `CLAUDE.md`. Replace everything from `## Self-Improvement` up to (but not including) the next `##` heading with:

```markdown
## Self-Improvement
BEFORE fixing any error or continuing after user correction:
1. Append to `.learnings/log.md`: `### {date} — {category}: {summary}` + details
2. THEN proceed with fix/task

Categories: correction | failure | gotcha | agent-candidate | environment
Hook auto-logs Bash failures (exit≠0) → manual log only: corrections, gotchas, agent-candidates
Recurs this session → update `.claude/rules/` immediately
2 failed fix attempts → search web
```

If `## Self-Improvement` section is not found, append it before the last section of CLAUDE.md.

### Step 4 — Ensure `.learnings/log.md` exists

```bash
mkdir -p .learnings
```

If `.learnings/log.md` doesn't exist, create it with the standard header:

```markdown
# Learnings Log

> Corrections, discoveries, and patterns. Managed by Self-Improvement triggers in CLAUDE.md.
> Run `/reflect` to promote pending entries to rules/CLAUDE.md or instincts.

---

```

### Step 5 — Wire + sync

1. Verify `.claude/settings.json` is valid JSON: `python3 -c "import json; json.load(open('.claude/settings.json'))"` (or `python` / `py` on Windows)
2. Verify `.claude/hooks/log-failures.sh` exists and is executable
3. Verify `.learnings/log.md` exists

---

## Verify

- [ ] `.claude/hooks/log-failures.sh` exists and is executable
- [ ] `.claude/settings.json` parses as valid JSON
- [ ] `.claude/settings.json` has PostToolUse entry with matcher `"Bash"` pointing to `log-failures.sh`
- [ ] `CLAUDE.md` contains `BEFORE fixing` in Self-Improvement section
- [ ] `.learnings/log.md` exists with header
- [ ] Existing PostToolUse hooks (observe.sh, auto-format.sh) still present in settings.json

---

Migration complete: `010` — Self-improvement feedback loop via PostToolUse failure hook
