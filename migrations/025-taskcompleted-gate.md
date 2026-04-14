# Migration 025 — TaskCompleted risk-aware completion gate

> Retrofit already-bootstrapped client projects with a `TaskCompleted` completion gate. Writes `.claude/hooks/gate-task-complete.sh` inline (self-contained heredoc, no remote fetch), merges a new top-level `TaskCompleted` event entry into `.claude/settings.json` via Python3, chmod +x the hook script. `TaskCompleted` is a standard Claude Code hook event (https://code.claude.com/docs/en/hooks) — NOT a PreToolUse matcher. Idempotent; sentinel-guarded on the literal `gate-task-complete.sh` substring in settings.json content.

---

## Metadata

```yaml
id: "025"
breaking: false
affects: [hooks, settings]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"025"`
- `breaking`: `false` — additive: adds a new hook script and a new top-level settings key. Existing hooks are not touched. Worst case for a user who does not want the gate: `TASKCOMPLETED_GATE_BYPASS=1` restores no-op behavior without removing the hook.
- `affects`: `[hooks, settings]` — writes `.claude/hooks/gate-task-complete.sh` and merges the `TaskCompleted` key into `.claude/settings.json`. No agents, modules, skills, or techniques changed.
- `requires_mcp_json`: `false` — no MCP dependency. Python3 required (already a project dependency; jq explicitly avoided since jq is project-optional).
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with `.claude/scripts/json-val.sh` and the nested `{ hooks: [...] }` settings.json structure the gate depends on.

---

## Problem

The plan-writer migration 024 introduces `#### Risk: {low|medium|high|critical}` markers and a `#### Failure Modes` sub-section on every medium+ task. That is upstream discipline — plans now carry risk labels. Downstream enforcement is missing: nothing stops an agent or a user from marking a medium/high/critical task `completed` without running verification (`/verify`, `/review`, or an explicit `verified:` marker in the task description). The harness accepts any `TaskUpdate(status="completed")` call without inspection, so the risk label is informational only.

Root cause: the bootstrap did not wire a `TaskCompleted` hook. `TaskCompleted` is a standard Claude Code hook event (documented at https://code.claude.com/docs/en/hooks) that fires on every task completion attempt with a top-level payload (`task_subject`, `task_description`, `task_id`, `transcript_path`). Registering a hook on this event and `exit 2` on block gives us a harness-level gate that cannot be bypassed silently — the completion attempt is rejected with a stderr diagnostic and the user has to either add verification evidence or explicitly set `TASKCOMPLETED_GATE_BYPASS=1`.

This migration retrofits already-bootstrapped client projects with `.claude/hooks/gate-task-complete.sh` and the corresponding `TaskCompleted` entry in `.claude/settings.json`. The bootstrap template (`modules/03-hooks.md`) is updated in the same change so fresh bootstraps produce the same wiring.

---

## Changes

- `.claude/hooks/gate-task-complete.sh` (client project, NEW):
  - Full bash body inlined via heredoc — no remote fetch.
  - Reads stdin JSON, extracts `task_subject` / `task_description` / `task_id` as top-level fields via `.claude/scripts/json-val.sh` — `TaskCompleted` payloads are flat (PreToolUse-style nesting does not apply). Field names passed BARE, without a leading `.` prefix — `json-val.sh` treats `.task_subject` as a nested-path traversal where the first segment is the empty string, which resolves to `''` and silently breaks the gate (reviewer-caught 2026-04-14).
  - Bypass guard: `TASKCOMPLETED_GATE_BYPASS=1` emits stderr warning and exits 0.
  - Risk parse: `grep -oiE 'risk: ?(low|medium|high|critical)'` on the combined subject + description.
  - Empty risk OR `low` risk → `exit 0` (fail-open for unknown, intentional allow for low).
  - Verification evidence scan on combined subject + description (`verified:|tests: ?pass|build: ?pass|/verify ran|/review ran`) → `exit 0` if any match.
  - Else → `printf` diagnostic to stderr and `exit 2` (canonical `TaskCompleted` block pattern — NO JSON stdout).
  - `chmod +x` after write.

- `.claude/settings.json` (client project, MERGE):
  - Add a new top-level `"TaskCompleted"` key to the `hooks` object with a single hook entry: `[{"hooks":[{"type":"command","command":"bash .claude/hooks/gate-task-complete.sh"}]}]`. No `matcher` field — `TaskCompleted` does not take a matcher.
  - Do NOT touch the existing `"PreToolUse"` array. Merge is key-level, not array-level.
  - Python3 used for the merge (not jq — jq is project-optional; Python3 is already a dependency for every other bootstrap operation).

Idempotency: sentinel guard on the literal substring `gate-task-complete.sh` in `.claude/settings.json` content. If the sentinel is already present (any hook command references the script), the migration logs `SKIP` and exits 0. Re-run produces zero modifications.

Bootstrap self-alignment: `modules/03-hooks.md` is updated in the same change to add item 10 to the hook-script dispatch prompt, the `TaskCompleted` entry to the Step 4 settings.json structure block, the Step 5 Verify Wiring smoke tests, and a Checkpoint line. Fresh bootstraps will generate the same wiring as this migration retrofits.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f ".claude/settings.json" ]] || { echo "ERROR: .claude/settings.json not present — run full bootstrap first"; exit 1; }
[[ -f ".claude/scripts/json-val.sh" ]] || { echo "ERROR: .claude/scripts/json-val.sh not present — run full bootstrap first"; exit 1; }

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for settings.json merge"; exit 1; }

# Sentinel: literal substring that marks the gate as wired in settings.json.
# Any hook command referencing this script proves the migration has been applied.
SENTINEL='gate-task-complete.sh'

if grep -qF "$SENTINEL" .claude/settings.json; then
  echo "SKIP: 025 already applied (sentinel '$SENTINEL' present in .claude/settings.json)"
  exit 0
fi

mkdir -p .claude/hooks
```

---

### Step A — Write `.claude/hooks/gate-task-complete.sh`

Self-contained heredoc. No remote fetch. Full bash body inlined verbatim — every line present, no elision, no "similar pattern follows". Payload field reads use BARE TOP-LEVEL names (`task_subject`, `task_description`, `task_id`) — `TaskCompleted` payloads are flat, and `json-val.sh` interprets `a.b.c` as nested dict traversal, NOT jq-style leading-dot prefix. A leading-dot path like `.task_subject` splits to `['', 'task_subject']` and the first `data.get('', '')` lookup returns `''`, silently breaking the gate. Bare names are the only correct form.

```bash
cat > .claude/hooks/gate-task-complete.sh <<'GATE_EOF'
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

# Extract TaskCompleted payload fields. All fields are TOP-LEVEL on the payload object.
# Pass BARE field names (no leading dot). .claude/scripts/json-val.sh treats `a.b.c` as
# nested dict traversal, so a leading-dot path like `.task_subject` splits to
# ['', 'task_subject'] and the first `data.get('', '')` lookup returns empty string —
# silently breaking the gate (every field empty → RISK empty → exit 0 on every call).
# .claude/scripts/json-val.sh returns empty string on missing field (never errors).
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
GATE_EOF

chmod +x .claude/hooks/gate-task-complete.sh

# Syntax check — hard fail if the heredoc produced malformed bash.
if ! bash -n .claude/hooks/gate-task-complete.sh; then
  echo "ERROR: .claude/hooks/gate-task-complete.sh failed bash -n syntax check"
  exit 1
fi

echo "WRITTEN: .claude/hooks/gate-task-complete.sh (chmod +x, bash -n OK)"
```

---

### Step B — Merge `TaskCompleted` entry into `.claude/settings.json`

Python3-based idempotent merge. Target key is `"TaskCompleted"` (NOT `"PreToolUse"`). Guards on the existing `gate-task-complete.sh` substring anywhere in a hook command to avoid double-insertion if a partial run added the script but the top-level check was somehow bypassed.

```bash
python3 - <<'PY_EOF'
import json
import sys

SETTINGS_PATH = ".claude/settings.json"
GATE_COMMAND = "bash .claude/hooks/gate-task-complete.sh"

with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
    s = json.load(f)

if "hooks" not in s or not isinstance(s["hooks"], dict):
    print(f"ERROR: {SETTINGS_PATH} missing 'hooks' object — cannot merge TaskCompleted key")
    sys.exit(1)

hooks = s["hooks"]

# Check every existing hook command for the gate script. If any reference already
# exists, log SKIP and exit 0 — the merge has already happened.
def contains_gate(hooks_dict):
    for event_key, entries in hooks_dict.items():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            for h in entry.get("hooks", []) or []:
                if not isinstance(h, dict):
                    continue
                cmd = h.get("command", "")
                if "gate-task-complete.sh" in cmd:
                    return True
    return False

if contains_gate(hooks):
    print(f"SKIP: gate-task-complete.sh already referenced in {SETTINGS_PATH}")
    sys.exit(0)

# Build the TaskCompleted entry. No matcher field — TaskCompleted is its own event,
# not a PreToolUse matcher. Single hook entry containing the command-type dispatch.
new_entry = {
    "hooks": [
        {
            "type": "command",
            "command": GATE_COMMAND,
        }
    ]
}

existing = hooks.get("TaskCompleted", [])
if not isinstance(existing, list):
    existing = []
existing.append(new_entry)
hooks["TaskCompleted"] = existing

with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
    json.dump(s, f, indent=2)
    f.write("\n")

print(f"MERGED: TaskCompleted entry added to {SETTINGS_PATH}")
PY_EOF

# Validate JSON is still parseable after merge.
python3 -c "import json; json.load(open('.claude/settings.json'))" || {
  echo "ERROR: .claude/settings.json failed JSON validation after merge"
  exit 1
}

echo "MERGED: .claude/settings.json TaskCompleted entry (valid JSON after merge)"
```

---

### Step C — Register in `migrations/index.json`

The migration runner (`/migrate-bootstrap`) discovers migrations via `migrations/index.json`, not the directory listing. An entry must be present in the array before this migration can be applied by a client project.

```json
{
  "id": "025",
  "file": "025-taskcompleted-gate.md",
  "description": "TaskCompleted risk-aware completion gate — writes .claude/hooks/gate-task-complete.sh inline (self-contained heredoc, full bash body, no remote fetch) and merges a new top-level 'TaskCompleted' event entry into .claude/settings.json via Python3 (idempotent; sentinel-guarded on literal 'gate-task-complete.sh' substring). Hook reads top-level payload fields (bare names task_subject / task_description / task_id — flat payload schema, no nested extraction; bare names required because json-val.sh treats a leading-dot path as nested-traversal with an empty first segment and returns empty), parses risk marker, blocks medium/high/critical tasks that lack verification evidence (verified: / tests: pass / build: pass / /verify ran / /review ran) via stderr + exit 2 (canonical TaskCompleted block pattern, NO JSON stdout). Bypass escape hatch: TASKCOMPLETED_GATE_BYPASS=1 environment variable. Pairs with migration 024 (plan-writer risk classification) to enforce verification discipline on every medium+ task at harness level.",
  "breaking": false
}
```

Add this entry to the `migrations` array in `migrations/index.json`, immediately after the `024` entry.

---

### Rules for migration scripts

- **Literal anchors only** — every `grep` match uses `grep -qF`. No regex `.*` patterns anywhere. Settings.json merge uses Python3 dict key lookup (exact-match by definition).
- **Idempotent** — literal-substring sentinel `gate-task-complete.sh` in `.claude/settings.json` gates every patch. Re-run produces zero modifications. Python3 merge also checks every existing hook command for the script reference as a second layer of idempotency.
- **Read-before-write** — Python3 loads the existing `.claude/settings.json` before merging; writes back via `json.dump(s, f, indent=2)`. Heredoc write to the hook script is unconditional (first run creates it), gated at the top by the sentinel check so a re-run never reaches the heredoc.
- **MINGW64-safe** — heredoc + `chmod +x` for the hook script; Python3 in-place rewrite for settings.json (atomic at the Python level, `json.dump` writes the full object). No `sed -i` in-place edits, no process substitution, no `readarray`.
- **Abort on error** — `set -euo pipefail` at the top. Missing prereqs → explicit `exit 1` with a manual-patch message; malformed JSON after merge → explicit `exit 1` with validation failure; malformed bash in heredoc → `bash -n` check → explicit `exit 1`. Partially patched files are never silently left behind.
- **Self-contained** — no remote fetches, no references to gitignored paths. The full hook body is inlined in the heredoc above. The Python3 merge block is inlined. No external scripts beyond the already-bootstrapped `.claude/scripts/json-val.sh` which the hook depends on at runtime (not at migration time).

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

SENTINEL='gate-task-complete.sh'
FAIL=0

# 1. Hook script exists and passes syntax check.
if [[ -f .claude/hooks/gate-task-complete.sh ]]; then
  if bash -n .claude/hooks/gate-task-complete.sh; then
    echo "PASS: .claude/hooks/gate-task-complete.sh exists and bash -n OK"
  else
    echo "FAIL: .claude/hooks/gate-task-complete.sh failed bash -n"
    FAIL=1
  fi
else
  echo "FAIL: .claude/hooks/gate-task-complete.sh not found after migration"
  FAIL=1
fi

# 2. settings.json parses as JSON and contains the sentinel.
if python3 -c "import json; json.load(open('.claude/settings.json'))" 2>/dev/null; then
  echo "PASS: .claude/settings.json is valid JSON"
else
  echo "FAIL: .claude/settings.json is not valid JSON after merge"
  FAIL=1
fi

if grep -qF "$SENTINEL" .claude/settings.json; then
  echo "PASS: .claude/settings.json contains sentinel '$SENTINEL'"
else
  echo "FAIL: .claude/settings.json missing sentinel '$SENTINEL' after merge"
  FAIL=1
fi

# 3. settings.json has a top-level TaskCompleted key (not a PreToolUse matcher).
python3 -c "
import json, sys
s = json.load(open('.claude/settings.json'))
hooks = s.get('hooks', {})
tc = hooks.get('TaskCompleted')
if not isinstance(tc, list) or not tc:
    print('FAIL: hooks.TaskCompleted missing or not a non-empty list')
    sys.exit(1)
cmds = []
for entry in tc:
    for h in entry.get('hooks', []):
        cmds.append(h.get('command',''))
if not any('gate-task-complete.sh' in c for c in cmds):
    print('FAIL: hooks.TaskCompleted does not dispatch gate-task-complete.sh')
    sys.exit(1)
# Confirm no matcher field — TaskCompleted takes no matcher.
for entry in tc:
    if 'matcher' in entry:
        print('FAIL: hooks.TaskCompleted entry has forbidden matcher field')
        sys.exit(1)
print('PASS: hooks.TaskCompleted wired to gate-task-complete.sh (no matcher field)')
" || FAIL=1

# 4. Fixture smoke tests — run the hook with 4 representative payloads and check exit codes.
#    All payloads use TOP-LEVEL JSON fields (task_subject, task_description, task_id,
#    transcript_path) per the TaskCompleted flat payload schema. No tool_input wrapper.

# Smoke 1: no risk marker at all → exit 0 (fail-open on unknown risk).
set +e
printf '%s' '{"task_subject":"T","task_description":"no risk marker","task_id":"t1","transcript_path":""}' | bash .claude/hooks/gate-task-complete.sh >/dev/null 2>&1
EC=$?
set -e
if [[ $EC -eq 0 ]]; then
  echo "PASS: smoke 1 (no risk marker) → exit 0"
else
  echo "FAIL: smoke 1 (no risk marker) → expected exit 0, got $EC"
  FAIL=1
fi

# Smoke 2: explicit risk: low → exit 0.
set +e
printf '%s' '{"task_subject":"T","task_description":"risk: low — done","task_id":"t1","transcript_path":""}' | bash .claude/hooks/gate-task-complete.sh >/dev/null 2>&1
EC=$?
set -e
if [[ $EC -eq 0 ]]; then
  echo "PASS: smoke 2 (risk: low) → exit 0"
else
  echo "FAIL: smoke 2 (risk: low) → expected exit 0, got $EC"
  FAIL=1
fi

# Smoke 3: risk: high, no verified marker → exit 2 (blocked).
set +e
printf '%s' '{"task_subject":"T","task_description":"risk: high — done","task_id":"t1","transcript_path":""}' | bash .claude/hooks/gate-task-complete.sh >/dev/null 2>&1
EC=$?
set -e
if [[ $EC -eq 2 ]]; then
  echo "PASS: smoke 3 (risk: high, no marker) → exit 2 (blocked)"
else
  echo "FAIL: smoke 3 (risk: high, no marker) → expected exit 2, got $EC"
  FAIL=1
fi

# Smoke 4: risk: high with verified: marker → exit 0 (allowed).
set +e
printf '%s' '{"task_subject":"T","task_description":"risk: high — done. verified: tests pass","task_id":"t1","transcript_path":""}' | bash .claude/hooks/gate-task-complete.sh >/dev/null 2>&1
EC=$?
set -e
if [[ $EC -eq 0 ]]; then
  echo "PASS: smoke 4 (risk: high + verified) → exit 0"
else
  echo "FAIL: smoke 4 (risk: high + verified) → expected exit 0, got $EC"
  FAIL=1
fi

# 5. Verify the index.json entry exists.
if grep -qF '"id": "025"' migrations/index.json; then
  echo "PASS: migrations/index.json contains 025 entry"
else
  echo "FAIL: migrations/index.json missing 025 entry"
  FAIL=1
fi

[[ $FAIL -eq 0 ]] || exit 1
```

Failure of any verify step → `/migrate-bootstrap` aborts and does NOT update `bootstrap-state.json`. Safe to retry after fixing the failure.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"025"`
- append `{ "id": "025", "applied_at": "<ISO8601>", "description": "TaskCompleted risk-aware completion gate" }` to `applied[]`

---

## Rollback

Reversible via literal-anchor deletion: remove the `TaskCompleted` top-level key from `.claude/settings.json` and delete `.claude/hooks/gate-task-complete.sh`. Easier: `git restore .claude/hooks/gate-task-complete.sh .claude/settings.json` from the pre-migration commit (if the client project tracks these paths; otherwise restore from companion repo snapshot via `/sync`). Alternatively, for an immediate runtime override without reverting files, export `TASKCOMPLETED_GATE_BYPASS=1` in the shell — the hook will emit a warning and exit 0 on every invocation until the variable is unset. No cascading dependencies — removing the gate restores the original uninspected-completion behavior without affecting any other hook, agent, or skill.
