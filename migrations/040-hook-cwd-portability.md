# Migration 040 — Hook command CWD portability

> Patch `.claude/settings.json` so every hook command resolves the script via `$CLAUDE_PROJECT_DIR` instead of a relative `.claude/hooks/X.sh` path — prevents hook failure when the triggering Bash tool call uses `cd <subdir>`.

---

## Metadata

```yaml
id: "040"
breaking: false
affects: [settings, hooks]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Claude Code invokes every configured hook by spawning the `command` string through a shell. The shell inherits the **current working directory of the tool call that fired the hook**. For `PostToolUse:Bash` in particular, that CWD is whatever the user's Bash command left as the working directory — if the Bash tool input was `cd <subdir> && <cmd>`, the PostToolUse hook fires with `<subdir>` as CWD, not the project root.

Pre-fix `.claude/settings.json` (shipped by every bootstrap before this migration) registered 15 hook entries of the form:

```json
"command": "bash .claude/hooks/X.sh"
```

`bash .claude/hooks/X.sh` is a relative path. It only resolves when the hook fires with the project root as CWD. The moment a Bash tool call changes directory, every hook entry of this form emits:

```
bash: .claude/hooks/X.sh: No such file or directory
```

Claude Code reports this to the main thread as `PostToolUse:Bash hook error: ...` with "Failed with non-blocking status code" — the session continues, but the hook did not run. Telemetry is silently dropped for that tool call.

Field-observed session, 2026-04-20: a single `Bash(cd <subdir> && for f in *.md; do ...; done)` tool call caused both `observe.sh` (matcher `Edit|Write|Bash`) and `log-failures.sh` (matcher `Bash`) to fail with `No such file or directory`. Neither hook recorded the event. Silent observation loss is exactly the failure mode migration 037 fixed for `observe.sh` Bash cmd-field emission — here the same telemetry pipeline breaks for a different reason (CWD-dependent path resolution instead of missing field content).

Every hook currently installed by `modules/03-hooks.md` used the relative form. This migration promotes all of them to `$CLAUDE_PROJECT_DIR`-resolved absolute paths. Claude Code exports `CLAUDE_PROJECT_DIR` for every hook invocation (already used by each hook script's internal logic — see `modules/03-hooks.md` step 1 boilerplate: `PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"`). Resolving the script path via that env var at the `command` level makes the hook invocation CWD-independent.

New form:

```json
"command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/X.sh\""
```

The outer shell double-quotes around `$CLAUDE_PROJECT_DIR/.claude/hooks/X.sh` protect against spaces in the project path (Windows `C:\Users\...`, POSIX `My Documents`, etc.). In the JSON file, those inner `"` render as `\"`.

Paired bootstrap change: `modules/03-hooks.md` settings.json template block is updated in the same commit so new bootstraps emit the portable form directly; this migration brings already-bootstrapped projects forward without a full refresh.

---

## Changes

- Single-file edit: `.claude/settings.json` in-place. No other files touched, no agent/rule/module edits inside the migration, no technique sync.
- Python-based patcher (no regex on JSON): walk `hooks.<event>[*].hooks[*].command` via `json.load`, rewrite every value matching `^bash \.claude/hooks/([A-Za-z0-9._-]+)$` to `bash "$CLAUDE_PROJECT_DIR/.claude/hooks/\1"`. Unrecognized command forms are left untouched (scope limit — project may have custom hooks with absolute paths, different dispatch styles, or multi-argument invocations this migration does not claim to fix).
- Sentinel-guarded idempotency: if every `command` in the walked tree already contains `$CLAUDE_PROJECT_DIR`, the patcher prints `SKIP: already patched` and exits 0 without writing.
- Backup: `.claude/settings.json.bak-040` written via `shutil.copy2` on the first rewrite only (not on subsequent skip-already-applied runs). Existing `.bak-040` is never overwritten.
- JSON validation: `json.load` before rewrite; post-rewrite re-parse; any parse failure post-write triggers restore-from-backup + `sys.exit(1)` with a loud FAIL message.
- Self-contained: no remote fetch, no technique sync, no external scripts.

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f ".claude/settings.json" ]] || { echo "ERROR: .claude/settings.json missing — run full bootstrap first"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Detect, patch, validate

One Python block. Parses `.claude/settings.json`, walks every hook tree node, rewrites matching relative-path commands, writes the result, and validates the round-trip. Idempotent via sentinel check; fail-loud on post-write parse error with automatic backup restore.

```bash
python3 - <<'PY'
import json
import os
import re
import shutil
import sys

SETTINGS = ".claude/settings.json"
BACKUP = ".claude/settings.json.bak-040"
RELATIVE_RE = re.compile(r'^bash \.claude/hooks/([A-Za-z0-9._-]+)$')
SENTINEL = "$CLAUDE_PROJECT_DIR"


def walk_commands(data):
    """Yield (event, outer_idx, inner_idx, command) for every hook command."""
    hooks = data.get("hooks") or {}
    if not isinstance(hooks, dict):
        return
    for event, entries in hooks.items():
        if not isinstance(entries, list):
            continue
        for i, entry in enumerate(entries):
            if not isinstance(entry, dict):
                continue
            inner = entry.get("hooks") or []
            if not isinstance(inner, list):
                continue
            for j, h in enumerate(inner):
                if not isinstance(h, dict):
                    continue
                cmd = h.get("command")
                if isinstance(cmd, str):
                    yield event, i, j, cmd


# Parse + validate pre-rewrite
try:
    with open(SETTINGS, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"FAIL: {SETTINGS} did not parse as JSON: {e}")
    sys.exit(1)

# Collect matches and non-matches
to_rewrite = []  # (event, i, j, old_cmd, new_cmd)
non_matching = []  # (event, i, j, cmd) for commands that reference .claude/hooks/ but do not match the expected form
already_patched = []  # cmds already containing $CLAUDE_PROJECT_DIR

for event, i, j, cmd in walk_commands(data):
    m = RELATIVE_RE.match(cmd)
    if m:
        script = m.group(1)
        new_cmd = f'bash "{SENTINEL}/.claude/hooks/{script}"'
        to_rewrite.append((event, i, j, cmd, new_cmd))
    elif SENTINEL in cmd:
        already_patched.append((event, i, j, cmd))
    elif ".claude/hooks/" in cmd:
        non_matching.append((event, i, j, cmd))
    # else: command does not touch .claude/hooks/ at all — ignore

# Idempotency branch
if not to_rewrite:
    if non_matching:
        print("WARN: no relative-path hooks to patch, but these custom/unrecognized commands reference .claude/hooks/ and do NOT use $CLAUDE_PROJECT_DIR:")
        for event, i, j, cmd in non_matching:
            print(f"  {event}[{i}].hooks[{j}]: {cmd}")
        print("  (Left untouched by this migration — scope limit. Review manually if they must be CWD-portable.)")
    else:
        print("SKIP: already patched (every hook command uses $CLAUDE_PROJECT_DIR)")
    sys.exit(0)

# Apply rewrite
for event, i, j, old_cmd, new_cmd in to_rewrite:
    data["hooks"][event][i]["hooks"][j]["command"] = new_cmd
    print(f"PATCHED: {event}[{i}].hooks[{j}] {old_cmd} -> {new_cmd}")

# Backup before writing (only if backup does not already exist)
if not os.path.exists(BACKUP):
    shutil.copy2(SETTINGS, BACKUP)
    print(f"BACKUP: {BACKUP}")
else:
    print(f"BACKUP: {BACKUP} already exists — not overwritten")

# Write + validate round-trip
serialized = json.dumps(data, indent=2) + "\n"
with open(SETTINGS, "w", encoding="utf-8") as f:
    f.write(serialized)

try:
    with open(SETTINGS, "r", encoding="utf-8") as f:
        json.load(f)
except Exception as e:
    print(f"FAIL: post-write parse of {SETTINGS} failed: {e}")
    print(f"FAIL: restoring from {BACKUP}")
    shutil.copy2(BACKUP, SETTINGS)
    sys.exit(1)

print(f"PATCHED: {len(to_rewrite)} hook commands")

if non_matching:
    print("NOTE: the following commands reference .claude/hooks/ but did not match the expected relative form — left untouched (scope limit):")
    for event, i, j, cmd in non_matching:
        print(f"  {event}[{i}].hooks[{j}]: {cmd}")
PY
```

### Step 2 — Smoke test the patched JSON

Second Python block. Verifies the JSON parses and every `command` field that references `.claude/hooks/` now also contains `$CLAUDE_PROJECT_DIR`. Fails the migration if any `.claude/hooks/X.sh` reference remains without the env var.

```bash
python3 - <<'PY'
import json
import sys

SETTINGS = ".claude/settings.json"
SENTINEL = "$CLAUDE_PROJECT_DIR"

try:
    with open(SETTINGS, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"FAIL: {SETTINGS} did not parse post-write: {e}")
    sys.exit(1)

offenders = []
sentinel_hit = False

hooks = data.get("hooks") or {}
for event, entries in hooks.items():
    if not isinstance(entries, list):
        continue
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            continue
        inner = entry.get("hooks") or []
        if not isinstance(inner, list):
            continue
        for j, h in enumerate(inner):
            if not isinstance(h, dict):
                continue
            cmd = h.get("command")
            if not isinstance(cmd, str):
                continue
            if ".claude/hooks/" in cmd and SENTINEL not in cmd:
                offenders.append((event, i, j, cmd))
            if f'{SENTINEL}/.claude/hooks/' in cmd:
                sentinel_hit = True

if offenders:
    print("FAIL: these hook commands still reference .claude/hooks/ without $CLAUDE_PROJECT_DIR:")
    for event, i, j, cmd in offenders:
        print(f"  {event}[{i}].hooks[{j}]: {cmd}")
    sys.exit(1)

if not sentinel_hit:
    print("FAIL: no hook command contains $CLAUDE_PROJECT_DIR/.claude/hooks/ — sentinel check failed")
    sys.exit(1)

print("PASS: every .claude/hooks/ command uses $CLAUDE_PROJECT_DIR")
PY
```

### Rules for migration scripts

- **Read-before-write** — Step 1 parses the existing `.claude/settings.json` and inspects every hook command before any modification
- **Idempotent** — sentinel-guarded rewrite (`$CLAUDE_PROJECT_DIR` presence check), safe to re-run; backup file suffixed with migration id (`.bak-040`) so it does not collide with other migrations' backups, and the backup is not overwritten on re-runs
- **Self-contained** — all logic inlined via quoted heredoc (`<<'PY'`); no remote fetch; no reference to gitignored paths beyond the in-project `.claude/settings.json` write target; no technique sync (this migration does not modify techniques)
- **Abort on error** — `set -euo pipefail` on the wrapping bash; Python scripts `sys.exit(1)` on any parse, walk, or round-trip failure; post-write parse failure triggers restore from `.bak-040` before the script exits
- **Python JSON round-trip, not regex-on-JSON** — every parse uses `json.load`; every rewrite mutates the parsed Python dict; every write serializes via `json.dumps(data, indent=2) + "\n"`; no `sed`, `awk`, or regex substitution is ever applied to the JSON file directly
- **Quoted heredoc sentinel** — `<<'PY'` (single-quoted) so every `$VAR`, `$(...)`, `${...}` inside the Python block stays literal at migration-apply time; the literal string `$CLAUDE_PROJECT_DIR` written into the JSON is the hook shell's variable, not the migration script's

### Required: register in migrations/index.json

Main thread applies this entry — do not attempt to edit `migrations/index.json` from inside the migration script. Append to the `migrations` array:

```json
{
  "id": "040",
  "file": "040-hook-cwd-portability.md",
  "description": "Patch .claude/settings.json so every hook command resolves the script via $CLAUDE_PROJECT_DIR instead of a relative .claude/hooks/X.sh path — prevents hook failure when the triggering Bash tool call uses cd <subdir>. Pre-fix client projects had 15 hook entries with the fragile relative form; Claude Code hooks fire with the tool call's CWD, so any Bash tool call of the form `cd <subdir> && <cmd>` caused every PostToolUse hook to emit `bash: .claude/hooks/X.sh: No such file or directory` with non-blocking status, silently dropping telemetry for that turn. Fix: walk settings.json hooks tree via python json.load, rewrite every command matching `^bash \\.claude/hooks/([A-Za-z0-9._-]+)$` to `bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/\\1\"`, backup to .claude/settings.json.bak-040, validate JSON round-trip. Sentinel-guarded idempotent (SKIP if every command already contains $CLAUDE_PROJECT_DIR). Unrecognized custom hook forms are left untouched (scope limit). Pairs with a modules/03-hooks.md template update so new bootstraps emit the portable form directly. bootstrap-state.json advances to last_migration=040.",
  "breaking": false
}
```

---

## Verify

```bash
set -euo pipefail

SETTINGS=".claude/settings.json"

[[ -f "$SETTINGS" ]] || { echo "FAIL: $SETTINGS missing"; exit 1; }

# Assert: JSON parses
python3 -c "import json; json.load(open('$SETTINGS'))" \
  || { echo "FAIL: $SETTINGS did not parse as JSON"; exit 1; }

# Assert: every hook command touching .claude/hooks/ uses $CLAUDE_PROJECT_DIR
# Assert: at least one command contains $CLAUDE_PROJECT_DIR/.claude/hooks/ (proves migration applied OR project was already fully patched)
# Assert: every $CLAUDE_PROJECT_DIR/.claude/hooks/ occurrence is wrapped in "..." (shell quote integrity)
python3 - <<'PY'
import json
import re
import sys

SETTINGS = ".claude/settings.json"
SENTINEL = "$CLAUDE_PROJECT_DIR"
# Pattern: bash "$CLAUDE_PROJECT_DIR/.claude/hooks/X.sh"
# Must have opening double-quote immediately before $CLAUDE_PROJECT_DIR and closing double-quote after the .sh filename.
QUOTED_RE = re.compile(r'"\$CLAUDE_PROJECT_DIR/\.claude/hooks/[A-Za-z0-9._-]+\.sh"')
UNQUOTED_RE = re.compile(r'(?<!")\$CLAUDE_PROJECT_DIR/\.claude/hooks/')

with open(SETTINGS, "r", encoding="utf-8") as f:
    data = json.load(f)

offenders = []
unquoted = []
sentinel_hit = False

hooks = data.get("hooks") or {}
for event, entries in hooks.items():
    if not isinstance(entries, list):
        continue
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            continue
        inner = entry.get("hooks") or []
        if not isinstance(inner, list):
            continue
        for j, h in enumerate(inner):
            if not isinstance(h, dict):
                continue
            cmd = h.get("command")
            if not isinstance(cmd, str):
                continue
            if ".claude/hooks/" in cmd and SENTINEL not in cmd:
                offenders.append((event, i, j, cmd))
            if f'{SENTINEL}/.claude/hooks/' in cmd:
                sentinel_hit = True
                # Every sentinel occurrence in this command must be wrapped in double-quotes
                if UNQUOTED_RE.search(cmd) and not QUOTED_RE.search(cmd):
                    unquoted.append((event, i, j, cmd))

if offenders:
    print("FAIL: hook commands still use relative .claude/hooks/ paths without $CLAUDE_PROJECT_DIR:")
    for event, i, j, cmd in offenders:
        print(f"  {event}[{i}].hooks[{j}]: {cmd}")
    sys.exit(1)

if not sentinel_hit:
    print("FAIL: no hook command contains $CLAUDE_PROJECT_DIR/.claude/hooks/ (sentinel check failed)")
    sys.exit(1)

if unquoted:
    print("FAIL: $CLAUDE_PROJECT_DIR/.claude/hooks/ references are NOT wrapped in double-quotes (breaks on project paths with spaces):")
    for event, i, j, cmd in unquoted:
        print(f"  {event}[{i}].hooks[{j}]: {cmd}")
    sys.exit(1)

print("PASS: migration 040 verified")
PY
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "040"
- append `{ "id": "040", "applied_at": "{ISO8601}", "description": "Hook command CWD portability — every hook command resolves via $CLAUDE_PROJECT_DIR instead of relative .claude/hooks/X.sh; prevents silent hook failure when triggering Bash tool call uses cd <subdir>" }` to `applied[]`

---

## Idempotency

Re-running after success: the Python patcher walks every hook command, finds the `^bash \.claude/hooks/` regex matches zero commands (all already use the `$CLAUDE_PROJECT_DIR` form), confirms every `.claude/hooks/`-referencing command contains `$CLAUDE_PROJECT_DIR`, prints `SKIP: already patched (every hook command uses $CLAUDE_PROJECT_DIR)`, and exits 0. No write occurs, so the backup file `.bak-040` is not touched. The Step 2 smoke test and the Verify block both re-run cleanly on the already-patched file and print `PASS`.

Running on a partially hand-edited project (some commands use `$CLAUDE_PROJECT_DIR`, some still relative): the patcher rewrites only the relative ones, leaves the already-patched ones alone, and reports per-command PATCHED lines for the rewrites. The `.bak-040` backup is created on this first effective run and preserved across subsequent re-runs.

Running on a project with custom hooks whose command form this migration does not recognize (e.g. absolute paths, multi-argument invocations, non-bash interpreters): the patcher emits per-command WARN lines listing them and leaves them untouched. The Verify block fails only if a non-migration-owned command still uses the exact relative form `bash .claude/hooks/X.sh` without `$CLAUDE_PROJECT_DIR` — that failure is the correct signal that a hand-edit must be made.

---

## Rollback

Restore the backup:

```bash
mv .claude/settings.json.bak-040 .claude/settings.json
```

Note: the `.bak-040` backup contains the pre-fix settings.json with relative-path hook commands. Rollback reintroduces the CWD-fragile form — any Bash tool call using `cd <subdir>` will again cause every PostToolUse hook to fail with `bash: .claude/hooks/X.sh: No such file or directory` and silently drop telemetry for that turn. Prefer `git restore .claude/settings.json` if the project tracks `.claude/settings.json` (most bootstrapped projects gitignore it); `.bak-040` is a last-resort local fallback only.
