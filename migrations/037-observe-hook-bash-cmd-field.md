# Migration 037 — observe.sh Bash cmd field retrofit

> Rewrite `.claude/hooks/observe.sh` in-place so Bash tool events capture the actual command in a `cmd` field instead of emitting empty-field JSONL — restores semantic content for the `proj-reflector` / `/consolidate` clustering pipeline.

---

## Metadata

```yaml
id: "037"
breaking: false
affects: [hooks]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

`.claude/hooks/observe.sh` fires on every PostToolUse (matcher: `Edit|Write|Bash`) and appends one JSONL record per tool event to `.learnings/observations.jsonl`. The `proj-reflector` agent + `/consolidate` pipeline scan this file for "Hot files" (Edit/Write clusters) and "Common commands" (Bash clusters) patterns during session reflection.

Pre-fix observe.sh — present in every client project bootstrapped before the observe.sh in-place fix on 2026-04-10 — has a single codepath that writes **every** tool event (Edit, Write, AND Bash) as:

```
{"ts":"...","tool":"Bash","file":""}
```

The `file` field is always empty for Bash events because Bash `tool_input` has no `file_path` — it has `command`. The old script never read `tool_input.command`, never emitted a `cmd` field, and emitted `"file":""` instead. Edit + Write telemetry is correct in the old version (both tools DO carry `file_path`, so `"file":"..."` has real content).

Effect on the reflection pipeline:
- Every Bash observation carries zero semantic payload — only `ts` + `tool_name` + an empty string
- `proj-reflector` reads the file, sees no usable content for the "Common commands" cluster, correctly reports **"telemetry-only, no semantic content for clustering"** and skips Bash pattern extraction
- Edit/Write "Hot files" clustering still works on the old hook — only Bash telemetry is broken
- Reflection runs on a truncated signal set; command-usage patterns (repeated `git status` → `git diff` loops, repeated test-runner invocations worth an alias) never surface

No previous migration touched `observe.sh`. `/migrate-bootstrap` never regenerates the hook on already-bootstrapped projects — pre-fix client projects keep the broken version until a migration explicitly rewrites it. This migration is that rewrite.

Scope limit: historical `.learnings/observations.jsonl` entries are **not** touched. Broken records age out naturally via the existing 10MB rotation in observe.sh; rewriting history would destroy the signal used by any ongoing reflection runs and is unnecessary — once the hook emits `cmd` fields going forward, new observations immediately carry semantic content and clustering becomes productive again.

---

## Changes

- Rewrites `.claude/hooks/observe.sh` in-place with the correct version from `modules/03-hooks.md` (the bootstrap source of truth, identical to the copy at `.claude/hooks/observe.sh` in the bootstrap repo).
- Backs up the prior version to `.claude/hooks/observe.sh.bak-037` — preserves a recoverable copy of whatever the project had before.
- Idempotent via sentinel `grep -q '"cmd":"%s"' .claude/hooks/observe.sh` — skips rewrite if the Bash branch already writes the `cmd` field (the fixed `printf` format string is present only in the corrected version).
- Self-contained — full 48-line hook body inlined via quoted heredoc. No remote fetch, no gitignored-path reference.
- Leaves historical `.learnings/observations.jsonl` untouched — old broken entries age out via the 10MB rotation that was already part of observe.sh.
- `chmod +x` on the rewritten hook (heredoc loses exec bit on some platforms).

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/hooks" ]] || { echo "ERROR: .claude/hooks missing — run full bootstrap first"; exit 1; }
```

### Step 1 — Detect prior version

Three branches: hook missing (create fresh), hook present-but-buggy (rewrite), hook already fixed (skip). The sentinel is the `printf` format string `"cmd":"%s"` — it is only present in the fixed version's Bash branch.

```bash
HOOK=".claude/hooks/observe.sh"

if [[ ! -f "$HOOK" ]]; then
  echo "NOTE: $HOOK missing — will create fresh (Module 03 may not have run)"
  NEEDS_REWRITE=1
elif grep -q '"cmd":"%s"' "$HOOK"; then
  echo "SKIP: $HOOK already writes cmd field for Bash events"
  NEEDS_REWRITE=0
else
  echo "REWRITE: $HOOK present but lacks cmd field for Bash events"
  NEEDS_REWRITE=1
fi
```

### Step 2 — Backup and rewrite

Back up the old hook (if any) and write the corrected version via heredoc. The heredoc uses a **quoted** sentinel (`'OBSERVE_SH'`) so `$VAR`, `$(...)`, `${...}`, `$TS`, `$TOOL`, `$INPUT`, `$CMD_ESC`, `$FILE_ESC` and every other shell expansion inside the hook body stays **literal** and is NOT interpolated at migration-apply time. Forgetting the quotes would destroy the hook.

```bash
if [[ "$NEEDS_REWRITE" -eq 1 ]]; then
  if [[ -f "$HOOK" ]]; then
    cp "$HOOK" "$HOOK.bak-037"
    echo "BACKUP: $HOOK.bak-037"
  fi

  cat > "$HOOK" <<'OBSERVE_SH'
#!/usr/bin/env bash
# observe.sh — PostToolUse hook (matcher: Edit|Write|Bash)
# Captures tool usage JSONL for the instinct observation pipeline.
# Rotates .learnings/observations.jsonl at 10MB.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SCRIPT_DIR="$PROJECT_DIR/.claude/scripts"

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | bash "$SCRIPT_DIR/json-val.sh" "tool_name" 2>/dev/null || printf 'unknown')

[[ "$TOOL" != "Edit" && "$TOOL" != "Write" && "$TOOL" != "Bash" ]] && exit 0

OBS_FILE="$PROJECT_DIR/.learnings/observations.jsonl"
mkdir -p "$PROJECT_DIR/.learnings"

# Rotate at 10MB
if [[ -f "$OBS_FILE" ]]; then
  SIZE=$(stat -c%s "$OBS_FILE" 2>/dev/null || stat -f%z "$OBS_FILE" 2>/dev/null || printf '0')
  if [[ "$SIZE" -gt 10485760 ]]; then
    mv "$OBS_FILE" "$OBS_FILE.$(date +%Y%m%d%H%M%S).bak"
  fi
fi

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ "$TOOL" == "Bash" ]]; then
  CMD=$(printf '%s' "$INPUT" | bash "$SCRIPT_DIR/json-val.sh" "tool_input.command" 2>/dev/null || printf '')
  # Skip read-only commands
  case "$CMD" in
    ls\ *|ls|cat\ *|pwd|pwd\ *|echo\ *|head\ *|tail\ *|wc\ *|which\ *|type\ *|file\ *)
      exit 0 ;;
  esac
  CMD_SHORT="${CMD:0:200}"
  # Escape for JSON: backslash + double quote
  CMD_ESC="${CMD_SHORT//\\/\\\\}"
  CMD_ESC="${CMD_ESC//\"/\\\"}"
  printf '{"ts":"%s","tool":"%s","cmd":"%s"}\n' "$TS" "$TOOL" "$CMD_ESC" >> "$OBS_FILE"
else
  FILE=$(printf '%s' "$INPUT" | bash "$SCRIPT_DIR/json-val.sh" "tool_input.file_path" 2>/dev/null || printf '')
  FILE_ESC="${FILE//\\/\\\\}"
  FILE_ESC="${FILE_ESC//\"/\\\"}"
  printf '{"ts":"%s","tool":"%s","file":"%s"}\n' "$TS" "$TOOL" "$FILE_ESC" >> "$OBS_FILE"
fi

exit 0
OBSERVE_SH

  chmod +x "$HOOK"
  echo "REWROTE: $HOOK"
fi
```

### Step 3 — Smoke test the rewritten hook

Feed the hook a synthesized Bash tool event and an Edit tool event on stdin (mimicking PostToolUse invocation). Verify:
- Hook exits 0 on both events
- The new Bash-event JSONL line contains `"cmd":"git status"` (NOT `"file":""`)
- The new Edit-event JSONL line contains `"file":"foo.md"`

Clean up the two smoke-test entries after verification so they do not pollute real telemetry.

```bash
OBS_FILE=".learnings/observations.jsonl"
mkdir -p .learnings

# Record pre-test line count so we can truncate the test rows after verification.
PRE_COUNT=0
[[ -f "$OBS_FILE" ]] && PRE_COUNT=$(wc -l < "$OBS_FILE" | tr -d ' ')
[[ "$PRE_COUNT" =~ ^[0-9]+$ ]] || PRE_COUNT=0

# Bash fixture — must produce a "cmd" field
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
  | bash .claude/hooks/observe.sh \
  || { echo "FAIL: hook non-zero on Bash fixture"; exit 1; }

# Edit fixture — must produce a "file" field
printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"foo.md"}}' \
  | bash .claude/hooks/observe.sh \
  || { echo "FAIL: hook non-zero on Edit fixture"; exit 1; }

# Verify the last two lines
[[ -f "$OBS_FILE" ]] || { echo "FAIL: $OBS_FILE not written"; exit 1; }
LAST2=$(tail -n 2 "$OBS_FILE")
BASH_LINE=$(printf '%s\n' "$LAST2" | sed -n '1p')
EDIT_LINE=$(printf '%s\n' "$LAST2" | sed -n '2p')

printf '%s' "$BASH_LINE" | grep -q '"tool":"Bash"' \
  || { echo "FAIL: Bash smoke line missing tool=Bash: $BASH_LINE"; exit 1; }
printf '%s' "$BASH_LINE" | grep -q '"cmd":"git status"' \
  || { echo "FAIL: Bash smoke line missing cmd=git status: $BASH_LINE"; exit 1; }
if printf '%s' "$BASH_LINE" | grep -q '"file":""'; then
  echo "FAIL: Bash smoke line still emits empty file field (old buggy format): $BASH_LINE"
  exit 1
fi

printf '%s' "$EDIT_LINE" | grep -q '"tool":"Edit"' \
  || { echo "FAIL: Edit smoke line missing tool=Edit: $EDIT_LINE"; exit 1; }
printf '%s' "$EDIT_LINE" | grep -q '"file":"foo.md"' \
  || { echo "FAIL: Edit smoke line missing file=foo.md: $EDIT_LINE"; exit 1; }

# Truncate the two smoke-test rows — keep the file as it was pre-test
TMP_OBS=$(mktemp)
head -n "$PRE_COUNT" "$OBS_FILE" > "$TMP_OBS"
mv "$TMP_OBS" "$OBS_FILE"

echo "PASS: observe.sh smoke test (Bash cmd + Edit file)"
```

### Step 4 — Idempotency

Re-running this migration after success:
- Step 1 sees `"cmd":"%s"` sentinel in the hook → `NEEDS_REWRITE=0`
- Step 2 is skipped entirely — no backup overwrite, no rewrite
- Step 3 smoke test still runs against the already-fixed hook → still passes

Safe to re-run indefinitely. The `.bak-037` backup is written **only** on the first rewrite and is never touched again by subsequent runs (because Step 2 is skipped).

### Rules for migration scripts

- **Read-before-write** — Step 1 reads the existing hook and checks the `cmd` sentinel before any modification
- **Idempotent** — sentinel-guarded rewrite (`"cmd":"%s"`), safe to re-run; backup file suffixed with migration id (`.bak-037`) so it does not collide with other migrations' backups
- **Self-contained** — full 48-line hook inlined via quoted heredoc; no remote fetch; no reference to gitignored paths beyond the in-project `.claude/hooks/` write target
- **Abort on error** — `set -euo pipefail` throughout; smoke test hard-fails the migration on any regression (non-zero exit, missing `cmd` field, lingering empty `file` field)
- **Quoted heredoc sentinel** — `<<'OBSERVE_SH'` (single-quoted) so every `$VAR`, `$(...)`, `${...}` inside the hook body stays literal at migration-apply time

### Required: register in migrations/index.json

Main thread applies this entry — do not attempt to edit `migrations/index.json` from inside the migration script. Append to the `migrations` array:

```json
{
  "id": "037",
  "file": "037-observe-hook-bash-cmd-field.md",
  "description": "Rewrite .claude/hooks/observe.sh in-place so Bash tool events capture the command in a cmd field instead of emitting empty-field JSONL — restores semantic content for the proj-reflector / consolidate clustering pipeline.",
  "breaking": false
}
```

---

## Verify

```bash
set -euo pipefail

HOOK=".claude/hooks/observe.sh"
OBS_FILE=".learnings/observations.jsonl"

# Hook exists and is executable
[[ -x "$HOOK" ]] || { echo "FAIL: $HOOK missing or not executable"; exit 1; }

# Fix sentinel present — Bash branch writes cmd field
grep -q '"cmd":"%s"' "$HOOK" || { echo "FAIL: cmd field printf format missing from $HOOK"; exit 1; }

# Edit/Write branch still writes file field (fix did not regress Edit/Write path)
grep -q '"file":"%s"' "$HOOK" || { echo "FAIL: file field printf format missing from $HOOK (Edit/Write regression)"; exit 1; }

# Bash branch reads tool_input.command — the semantic field the bug omitted
grep -q 'tool_input.command' "$HOOK" || { echo "FAIL: $HOOK does not read tool_input.command"; exit 1; }

# Shell standards: shebang + set -euo pipefail
head -n 1 "$HOOK" | grep -q '^#!/usr/bin/env bash' || { echo "FAIL: $HOOK missing bash shebang"; exit 1; }
grep -q '^set -euo pipefail' "$HOOK" || { echo "FAIL: $HOOK missing set -euo pipefail"; exit 1; }

# Runtime smoke test — Bash fixture
mkdir -p .learnings
PRE_COUNT=0
[[ -f "$OBS_FILE" ]] && PRE_COUNT=$(wc -l < "$OBS_FILE" | tr -d ' ')
[[ "$PRE_COUNT" =~ ^[0-9]+$ ]] || PRE_COUNT=0

printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
  | bash "$HOOK" \
  || { echo "FAIL: hook non-zero on Bash fixture"; exit 1; }

printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"foo.md"}}' \
  | bash "$HOOK" \
  || { echo "FAIL: hook non-zero on Edit fixture"; exit 1; }

[[ -f "$OBS_FILE" ]] || { echo "FAIL: $OBS_FILE not written by hook"; exit 1; }
LAST2=$(tail -n 2 "$OBS_FILE")
BASH_LINE=$(printf '%s\n' "$LAST2" | sed -n '1p')
EDIT_LINE=$(printf '%s\n' "$LAST2" | sed -n '2p')

printf '%s' "$BASH_LINE" | grep -q '"tool":"Bash"' \
  || { echo "FAIL: verify Bash line missing tool=Bash: $BASH_LINE"; exit 1; }
printf '%s' "$BASH_LINE" | grep -q '"cmd":"git status"' \
  || { echo "FAIL: verify Bash line missing cmd=git status: $BASH_LINE"; exit 1; }
if printf '%s' "$BASH_LINE" | grep -q '"file":""'; then
  echo "FAIL: verify Bash line still emits empty file field (old buggy format): $BASH_LINE"
  exit 1
fi

printf '%s' "$EDIT_LINE" | grep -q '"tool":"Edit"' \
  || { echo "FAIL: verify Edit line missing tool=Edit: $EDIT_LINE"; exit 1; }
printf '%s' "$EDIT_LINE" | grep -q '"file":"foo.md"' \
  || { echo "FAIL: verify Edit line missing file=foo.md: $EDIT_LINE"; exit 1; }

# Cleanup smoke-test rows
TMP_OBS=$(mktemp)
head -n "$PRE_COUNT" "$OBS_FILE" > "$TMP_OBS"
mv "$TMP_OBS" "$OBS_FILE"

echo "PASS: migration 037 verified"
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "037"
- append `{ "id": "037", "applied_at": "{ISO8601}", "description": "observe.sh Bash cmd field retrofit — restore semantic content in Bash observations for the reflection pipeline" }` to `applied[]`

---

## Rollback

Restore the backup:

```bash
mv .claude/hooks/observe.sh.bak-037 .claude/hooks/observe.sh
```

Note: the `.bak-037` backup contains the **buggy** pre-fix version, so rollback reintroduces empty-field Bash telemetry and breaks the reflector's "Common commands" clustering again. Historical `.learnings/observations.jsonl` entries are unchanged in either direction — rollback does not restore any observations. Git history of this repo (+ git history of the client project, if committed) is the preferred recovery path; `.bak-037` is a last-resort local fallback only.
