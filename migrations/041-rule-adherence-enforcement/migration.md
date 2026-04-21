# Migration 041 — Rule adherence enforcement (M6 + M3 + M2 hook stack)

> Transport the Opus-4.7-calibrated main-thread orchestrator enforcement stack to client projects. Upgrades `orchestrator-nudge.sh` to the M6 structural JSON `permissionDecision:"deny"` form on investigation-shaped Grep/Glob; adds M3 per-turn rule reminder (`orchestrator-rule-reminder.sh` on UserPromptSubmit); adds M2 per-session counter (`investigation-counter.sh` on PostToolUse Grep|Glob with N=2 block directive + `investigation-counter-reset.sh` on UserPromptSubmit); patches `.claude/rules/main-thread-orchestrator.md` with a FIRST ACTION / Anti-Patterns header block and a tightened Quick-Fix Carve-Out criterion 2; wires the 3 new hooks into `.claude/settings.json`. Sentinel-guarded per step so re-runs on already-patched projects no-op.

---

## Metadata

```yaml
id: "041"
breaking: false
affects: [hooks, rules, settings]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Advisory-only PreToolUse hooks proved insufficient for rule adherence on long main-thread sessions under Opus 4.7. Three compounding failure modes surfaced in the field:

1. **CLAUDE.md context decay.** `@import .claude/rules/main-thread-orchestrator.md` loads at session start, but the rule's effective attention weight decays as the conversation history grows. On multi-hour sessions the main thread begins treating `Grep` / `Glob` / multi-file `Read` as acceptable "quick check" actions despite the always-loaded doctrine forbidding it. Stderr advisory nudges from `orchestrator-nudge.sh` were consumed by the agentic loop as informational text, not as binding constraint — the model would read the nudge, acknowledge it in internal reasoning, and proceed with the investigation anyway.

2. **Carve-out rationalization paths.** The Quick-Fix Carve-Out criterion 2 ("target file + location already known (user-provided path OR in-context from prior agent return)") was interpreted permissively: any path mentioned anywhere upstream in the conversation — a weeks-old agent summary, a file quoted in a design discussion, a path appearing in a tool error message — was rationalized as "in-context from prior agent return". This opened a path to bypass the carve-out's intent (main edits only a file the user just handed over OR a file THIS turn's agent dispatch returned), turning the carve-out into a general-purpose edit permit.

3. **Opus 4.6 / 4.7 stop-regression (upstream #24327).** Bare `exit 2` in a PreToolUse hook, which was the documented block signal, stopped reliably halting tool execution in Opus 4.6 and regressed further in 4.7. The agentic loop would read the stderr reason, treat `exit 2` as an informational failure, and continue to the next tool call. The only reliable structural deny form that survives the 4.7 agentic loop is JSON `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}` emitted on stdout with `exit 0`. The `permissionDecision:"deny"` field is parsed by the Claude Code harness as a structural constraint before the tool call reaches the model, so the model cannot rationalize past it.

**Why PostToolUse for edit tools is not the answer.** Upstream issues #37210 / #33106 document that `permissionDecision:"deny"` on PreToolUse for `Edit` / `Write` / `MultiEdit` / `NotebookEdit` fires but does not consistently halt the edit — the write path commits before the deny takes effect on some platforms. Advisory stderr on the edit branch is the best available channel for those tools. The Grep / Glob branch of the same hook is not affected by this upstream bug and reliably blocks at PreToolUse with the JSON form.

**Why PostToolUse counter on top of PreToolUse deny.** The PreToolUse deny on Grep/Glob only fires on **investigation-shaped** patterns (CamelCase, regex metacharacters, `**` globs, alternation). A main thread determined to investigate can sidestep the pattern heuristic by issuing plain-literal Grep calls (`foo`, `handler`, `process`). The PostToolUse counter closes that gap: every Grep/Glob on main — pattern-shape irrelevant — increments a per-session counter, and at N=2 the counter emits `decision:"block"` with a concrete dispatch directive in `additionalContext`, which the 4.7 agentic loop treats as a structural command. The counter resets at each UserPromptSubmit so each turn starts with a fresh budget.

**Why UserPromptSubmit per-turn reminder.** The M3 layer injects a compact (~50-token) orchestrator rule reminder into every turn's system context via UserPromptSubmit stdout. Unlike the `@import` in CLAUDE.md — which decays in attention weight over a long conversation — the UserPromptSubmit stdout is freshly appended each turn, so the rule stays at the top of the context window for that turn's reasoning. This is the M3 enforcement layer in the rule-adherence stack (M6 structural deny = PreToolUse; M2 counter = PostToolUse; M3 rule reminder = UserPromptSubmit).

**Subagent exemption is load-bearing.** Every one of the new enforcement paths must exempt dispatched sub-agents (researchers, code-writers, reviewers) because those agents legitimately use Grep / Glob / Edit / Write in their own scope. Without the exemption, the main-thread doctrine would block the very agents the main thread dispatches to work around its own restrictions. The exemption is implemented via the `agent_id` field in the hook stdin JSON — if `agent_id` is non-empty, the hook exits 0 silently without evaluating the deny / counter / reminder logic.

---

## Changes

| File | Change |
|---|---|
| `.claude/hooks/orchestrator-nudge.sh` | M6 upgrade: structural JSON `permissionDecision:"deny"` on investigation-shaped Grep/Glob; advisory stderr kept on Edit/Write/MultiEdit/NotebookEdit (deny form broken upstream for edit tools); sub-agent exemption via `agent_id`; fail-open on every parse error |
| `.claude/hooks/orchestrator-rule-reminder.sh` | NEW: per-turn compact rule reminder on UserPromptSubmit; stateless; `session_id` consumed (reserved for future use); exit 0 always |
| `.claude/hooks/investigation-counter.sh` | NEW: per-session per-turn Grep/Glob counter on PostToolUse; at N=2 emits `decision:"block"` + `hookSpecificOutput.additionalContext` dispatch directive; sub-agent exemption via `agent_id`; counter file at `/tmp/cc-inv-count-${SESSION_ID}` |
| `.claude/hooks/investigation-counter-reset.sh` | NEW: turn-boundary reset for the counter on UserPromptSubmit; `rm -f /tmp/cc-inv-count-${SESSION_ID}`; exit 0 always |
| `.claude/rules/main-thread-orchestrator.md` | M3 rule patch: insert `## FIRST ACTION` + `## Anti-Patterns on Main (hard rules)` block at file top (before `# Main Thread Orchestrator Doctrine`); tighten Quick-Fix Carve-Out criterion 2 ("user-supplied file path in THIS message OR file explicitly returned by Agent call THIS turn — NOT 'mentioned anywhere in context'"); update Enforcement section to describe the M6/M2/M3 hook triple; remove the old mid-file `## Anti-Patterns on Main` block (superseded by the top-of-file version) |
| `.claude/settings.json` | Register 3 new hook entries: PostToolUse matcher `Grep\|Glob` → `investigation-counter.sh`; UserPromptSubmit → `orchestrator-rule-reminder.sh`; UserPromptSubmit → `investigation-counter-reset.sh`. All existing entries preserved. |

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -f ".claude/settings.json" ]] || { echo "ERROR: .claude/settings.json missing — run full bootstrap first"; exit 1; }
[[ -d ".claude/hooks" ]] || { echo "ERROR: .claude/hooks/ missing — run full bootstrap first"; exit 1; }
[[ -f ".claude/rules/main-thread-orchestrator.md" ]] || { echo "ERROR: .claude/rules/main-thread-orchestrator.md missing — run full bootstrap first (migration 036 adds this rule)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Upgrade `.claude/hooks/orchestrator-nudge.sh` (M6)

Sentinel: the target file already contains the literal string `permissionDecision`. If present → SKIP. Otherwise → write the full upgraded body via quoted heredoc, chmod +x, verify with `bash -n`.

```bash
set -euo pipefail

HOOK=".claude/hooks/orchestrator-nudge.sh"

if [[ -f "$HOOK" ]] && grep -q "permissionDecision" "$HOOK"; then
  echo "SKIP: $HOOK already M6-upgraded (permissionDecision sentinel present)"
else
  cat > "$HOOK" <<'SH'
#!/usr/bin/env bash
# orchestrator-nudge.sh — PreToolUse: advisory nudge + structural JSON deny for investigation-shaped Grep/Glob
# Edit/Write/MultiEdit/NotebookEdit: advisory stderr only (deny form broken per #37210/#33106).
# Grep/Glob on main thread: deny JSON (exit 0 + JSON stdout) when investigation-shaped pattern.
# Subagent contexts: skip all enforcement (agent_id present).
# Fail-open: any parse error → exit 0 silently.
set -euo pipefail

INPUT=$(cat)

# Parse all needed fields in one python3 call; output: tool_name|agent_id|pattern
PARSED=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    tool_name = d.get("tool_name", "") or ""
    agent_id  = d.get("agent_id", "") or ""
    ti        = d.get("tool_input", {}) or {}
    pattern   = ti.get("pattern", "") or ""
    print(tool_name + "|" + agent_id + "|" + pattern)
except Exception:
    print("||")
' 2>/dev/null || printf '||')

TOOL_NAME="${PARSED%%|*}"
REST="${PARSED#*|}"
AGENT_ID="${REST%%|*}"
PATTERN="${REST#*|}"

# Subagent check: skip enforcement entirely
if [[ -n "$AGENT_ID" ]]; then
    exit 0
fi

# Investigation-shaped heuristic for Grep/Glob
is_investigation_shaped() {
    local pat="$1"
    python3 - "$pat" </dev/null 2>/dev/null <<'PYEOF'
import sys, re
pat = sys.argv[1]

# Deny heuristics run FIRST: regex metacharacters or CamelCase symbols
deny_checks = [
    (r"\.\*",              ".*"),
    (r"\\b",               r"\b"),
    (r"\\w",               r"\w"),
    (r"\\s",               r"\s"),
    (r"\|",                "alternation"),
    (r"[A-Z][a-z]+[A-Z]", "CamelCase"),
]
for pattern, _ in deny_checks:
    if re.search(pattern, pat):
        sys.exit(0)  # investigation-shaped → deny

# Allow-list: simple extension globs, path globs, plain lowercase/digit literals (no wildcards)
# Plain-literal excludes uppercase to avoid false-allowing CamelCase symbol names
allow_patterns = [
    r"^\*\*?/[\w.*/-]+$",      # **/path/*.ext style
    r"^\*\.[\w]+$",             # *.ext style
    r"^[a-z0-9_./-]+$",        # plain literal path/filename: lowercase only, no wildcards
]
for ap in allow_patterns:
    if re.fullmatch(ap, pat):
        sys.exit(1)  # allow (not investigation-shaped)

# Default: treat as investigation-shaped (deny)
sys.exit(0)
PYEOF
    return $?
}

case "$TOOL_NAME" in
  Grep|Glob)
    if is_investigation_shaped "$PATTERN"; then
        # Structural JSON deny for investigation-shaped patterns on main thread
        printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"STOP. Dispatch proj-quick-check: Agent({description: '\''<your question>'\'', subagent_type: '\''proj-quick-check'\'', prompt: '\''<question>'\''})  Per .claude/rules/main-thread-orchestrator.md Tier 2."}}'
    else
        printf >&2 '%s\n' "[orchestrator-nudge] Main-thread investigation? Dispatch proj-quick-check (fast haiku, text return) for factual lookups; escalate to proj-researcher (sonnet, findings file) on incomplete / multi-source / cross-file synthesis. Multiple sequential quick-checks OK — orchestrator decides depth. Sub-agents: this nudge targets main, ignore. Rule: .claude/rules/main-thread-orchestrator.md"
    fi
    ;;
  Edit|Write|MultiEdit|NotebookEdit)
    printf >&2 '%s\n' "[orchestrator-nudge] Main-thread edit? Quick-fix carve-out applies only when ALL hold: (1) single file, (2) <=10 lines changed, (3) target + location already known, (4) mechanically obvious (typo/version/config/one-line-swap), (5) zero cross-file impact. Any criterion fails -> dispatch proj-code-writer-{lang} via /code-write /tdd /execute-plan. Sub-agents: this nudge targets main, ignore. Rule: .claude/rules/main-thread-orchestrator.md"
    ;;
esac

exit 0
SH
  chmod +x "$HOOK"
  bash -n "$HOOK" || { echo "FAIL: $HOOK failed syntax check"; exit 1; }
  echo "WROTE: $HOOK (M6 upgrade applied)"
fi
```

### Step 2 — Create `.claude/hooks/orchestrator-rule-reminder.sh` (M3)

Sentinel: target file exists. If present → SKIP. Otherwise → write body, chmod +x, verify.

```bash
set -euo pipefail

HOOK=".claude/hooks/orchestrator-rule-reminder.sh"

if [[ -f "$HOOK" ]]; then
  echo "SKIP: $HOOK already present"
else
  cat > "$HOOK" <<'SH'
#!/usr/bin/env bash
# orchestrator-rule-reminder.sh — UserPromptSubmit per-turn rule reminder
# Injects compact orchestrator rule reminder into each turn context.
# Defeats CLAUDE.md context decay on long sessions.
# Exit 0 always. Advisory only — never blocks.
set -euo pipefail

INPUT=$(cat)

# Consume session_id (for future use); fail-open on parse error
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("session_id", ""))
except Exception:
    print("")
' 2>/dev/null || printf '')

printf '%s\n' "ORCHESTRATOR RULE: Investigation → dispatch Agent(proj-quick-check) FIRST. No Grep|Glob on main. Quick-fix carve-out: single known file, ≤10 lines, mechanically obvious, user-supplied path THIS message only."

exit 0
SH
  chmod +x "$HOOK"
  bash -n "$HOOK" || { echo "FAIL: $HOOK failed syntax check"; exit 1; }
  echo "WROTE: $HOOK"
fi
```

### Step 3 — Create `.claude/hooks/investigation-counter.sh` (M2)

Sentinel: target file exists. If present → SKIP. Otherwise → write body, chmod +x, verify.

```bash
set -euo pipefail

HOOK=".claude/hooks/investigation-counter.sh"

if [[ -f "$HOOK" ]]; then
  echo "SKIP: $HOOK already present"
else
  cat > "$HOOK" <<'SH'
#!/usr/bin/env bash
# investigation-counter.sh — PostToolUse Grep/Glob counter + N=2 block directive
# Counts main-thread Grep/Glob calls per session turn via /tmp counter file.
# At N=2: emit decision:block directive telling Claude to dispatch Agent instead.
# Subagent exemption: agent_id present → skip counter entirely.
# Fail-open: parse error → attempt increment with fallback session, continue.
set -euo pipefail

INPUT=$(cat)

# Parse session_id and agent_id in one python3 call; output: session_id|agent_id
PARSED=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    session_id = d.get("session_id", "") or "default"
    agent_id   = d.get("agent_id", "") or ""
    print(session_id + "|" + agent_id)
except Exception:
    print("default|")
' 2>/dev/null || printf 'default|')

SESSION_ID="${PARSED%%|*}"
AGENT_ID="${PARSED#*|}"

# Sanitize SESSION_ID: strip whitespace, default if empty
SESSION_ID="${SESSION_ID//[[:space:]]/}"
[[ -z "$SESSION_ID" ]] && SESSION_ID="default"

# Subagent check: skip counter for subagents
if [[ -n "$AGENT_ID" ]]; then
    exit 0
fi

COUNTER_FILE="/tmp/cc-inv-count-${SESSION_ID}"

# Read current count (default 0 if file absent)
CURRENT=0
if [[ -f "$COUNTER_FILE" ]]; then
    RAW=$(cat "$COUNTER_FILE" 2>/dev/null || printf '0')
    RAW="${RAW//[[:space:]]/}"
    # Validate: only digits; default 0 if not
    if [[ "$RAW" =~ ^[0-9]+$ ]]; then
        CURRENT="$RAW"
    fi
fi

NEW_COUNT=$(( CURRENT + 1 ))
printf '%s' "$NEW_COUNT" > "$COUNTER_FILE"

if [[ "$NEW_COUNT" -ge 2 ]]; then
    printf '%s' '{"decision":"block","reason":"2 Grep/Glob calls on main thread this turn.","hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"STOP. 2 Grep/Glob calls on main thread this turn. Per .claude/rules/main-thread-orchestrator.md Tier 2: dispatch Agent({description: '\''<question>'\'', subagent_type: '\''proj-quick-check'\'', prompt: '\''<question>'\''}) now. Do NOT run another Grep|Glob."}}'
fi

exit 0
SH
  chmod +x "$HOOK"
  bash -n "$HOOK" || { echo "FAIL: $HOOK failed syntax check"; exit 1; }
  echo "WROTE: $HOOK"
fi
```

### Step 4 — Create `.claude/hooks/investigation-counter-reset.sh` (M2 turn-boundary reset)

Sentinel: target file exists. If present → SKIP. Otherwise → write body, chmod +x, verify.

```bash
set -euo pipefail

HOOK=".claude/hooks/investigation-counter-reset.sh"

if [[ -f "$HOOK" ]]; then
  echo "SKIP: $HOOK already present"
else
  cat > "$HOOK" <<'SH'
#!/usr/bin/env bash
# investigation-counter-reset.sh — UserPromptSubmit turn-boundary counter reset
# Resets the per-session investigation counter at each turn start.
# Without this, investigation-counter.sh accumulates across turns.
# Exit 0 always. Fail-open on parse error.
set -euo pipefail

INPUT=$(cat)

# Parse session_id from stdin JSON; fallback to "default"
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    v = d.get("session_id", "") or "default"
    print(v)
except Exception:
    print("default")
' 2>/dev/null || printf 'default')

# Strip whitespace; default if empty
SESSION_ID="${SESSION_ID//[[:space:]]/}"
[[ -z "$SESSION_ID" ]] && SESSION_ID="default"

rm -f "/tmp/cc-inv-count-${SESSION_ID}"

exit 0
SH
  chmod +x "$HOOK"
  bash -n "$HOOK" || { echo "FAIL: $HOOK failed syntax check"; exit 1; }
  echo "WROTE: $HOOK"
fi
```

### Step 5 — Patch `.claude/rules/main-thread-orchestrator.md` (M3 rule delta)

Sentinel: target file contains a line beginning with `## FIRST ACTION`. If present → SKIP (already patched). Otherwise → Python-based in-place edit that:

1. Inserts `## FIRST ACTION` + `## Anti-Patterns on Main (hard rules)` block at the TOP of the file (before the existing `# Main Thread Orchestrator Doctrine` heading).
2. Rewrites Quick-Fix Carve-Out criterion 2 from the old permissive form to the tightened form.
3. Replaces the `## Enforcement` section with the M6/M2/M3-aware description.
4. Removes the old mid-file `## Anti-Patterns on Main` block if present (superseded by the new top-of-file block).

Atomic: backup to `.bak-041` on first effective run, write the patched file, re-read to verify the sentinel is now present. Any failure → restore from backup + exit 1.

```bash
set -euo pipefail

RULE=".claude/rules/main-thread-orchestrator.md"
BACKUP=".claude/rules/main-thread-orchestrator.md.bak-041"

if grep -q '^## FIRST ACTION' "$RULE"; then
  echo "SKIP: $RULE already patched (^## FIRST ACTION sentinel present)"
else
  python3 - <<'PY'
import re
import shutil
import sys

RULE = ".claude/rules/main-thread-orchestrator.md"
BACKUP = ".claude/rules/main-thread-orchestrator.md.bak-041"

with open(RULE, "r", encoding="utf-8") as f:
    text = f.read()

# --- 1. Insert FIRST ACTION + Anti-Patterns top block before the H1 ---
TOP_BLOCK = """## FIRST ACTION
Investigation request → dispatch Agent(proj-quick-check) FIRST. Never Read|Grep|Glob first.

## Anti-Patterns on Main (hard rules)
- Grep|Glob for investigation → ALWAYS dispatch Agent (M6 hook will deny if attempted)
- Reading 3+ files to understand something → ALWAYS dispatch Agent
- Multi-file pattern search → ALWAYS dispatch Agent
- Bash grep/rg as substitute → ALWAYS dispatch Agent (same rule, different tool)
- "I'll just quickly check" requiring search → ALWAYS dispatch Agent

"""

H1_RE = re.compile(r"^# Main Thread Orchestrator Doctrine", re.MULTILINE)
m = H1_RE.search(text)
if not m:
    print(f"FAIL: could not locate '# Main Thread Orchestrator Doctrine' heading in {RULE}")
    sys.exit(1)

# Prepend TOP_BLOCK immediately before the H1
text = text[:m.start()] + TOP_BLOCK + text[m.start():]

# --- 2. Tighten Quick-Fix Carve-Out criterion 2 ---
OLD_CRIT2 = "2. Target file + location already known (user-provided path OR in-context from prior agent return) — NO discovery needed"
NEW_CRIT2 = "2. User-supplied file path in THIS message OR file explicitly returned by Agent call THIS turn — NOT \"mentioned anywhere in context\""
if OLD_CRIT2 in text:
    text = text.replace(OLD_CRIT2, NEW_CRIT2, 1)
else:
    # If the exact old form is absent, check whether the new form is already present (partial prior edit)
    if NEW_CRIT2 not in text:
        print(f"FAIL: neither old nor new criterion 2 text found in {RULE}; aborting rule patch")
        sys.exit(1)

# --- 3. Replace the Enforcement section with M6/M2/M3-aware description ---
NEW_ENFORCEMENT = """## Enforcement
- Structural PreToolUse hook `.claude/hooks/orchestrator-nudge.sh` on `Grep|Glob`: investigation-shaped patterns → JSON `permissionDecision:"deny"` (M6). PostToolUse counter `.claude/hooks/investigation-counter.sh` on `Grep|Glob`: N=2 → `decision:"block"` + dispatch directive (M2). Per-turn rule reminder `.claude/hooks/orchestrator-rule-reminder.sh` on `UserPromptSubmit` (M3). Hook for Edit|Write|MultiEdit|NotebookEdit: advisory stderr (exit 0, never blocks).
- `@import .claude/rules/main-thread-orchestrator.md` in `CLAUDE.md` (always loaded on main thread).
- Review-time catch: `/review` flags turns violating tier discipline.
- `.learnings/log.md` logs every observed violation under `correction` category → feeds `/reflect` for doctrine tightening."""

ENFORCEMENT_RE = re.compile(
    r"^## Enforcement\n.*?(?=^## |\Z)",
    re.MULTILINE | re.DOTALL,
)
if ENFORCEMENT_RE.search(text):
    text = ENFORCEMENT_RE.sub(NEW_ENFORCEMENT + "\n", text, count=1)
else:
    # Append if section is absent (defensive — the rule should always have one)
    text = text.rstrip() + "\n\n" + NEW_ENFORCEMENT + "\n"

# --- 4. Remove the old mid-file ## Anti-Patterns on Main block (superseded by top-of-file version) ---
# Literal string find, not regex — the new top-of-file heading is "## Anti-Patterns on Main (hard rules)\n"
# (with the "(hard rules)" suffix before "\n"), so content.find("## Anti-Patterns on Main\n") matches
# ONLY the OLD occurrence. Safer than DOTALL + negative-lookahead regex which fails when "hard rules"
# appears anywhere after the heading (it always does — the new top block contains it).
OLD_HEADER = "## Anti-Patterns on Main\n"
idx = text.find(OLD_HEADER)
if idx != -1:
    # Find end of section: next "## " heading or end-of-file
    end = text.find("\n## ", idx + len(OLD_HEADER))
    if end == -1:
        end = len(text)
    else:
        end += 1  # keep the \n before the next heading
    text = text[:idx] + text[end:]
# Idempotency: second run returns -1 from find, no-op.

# --- Write with backup ---
import os
if not os.path.exists(BACKUP):
    shutil.copy2(RULE, BACKUP)
    print(f"BACKUP: {BACKUP}")

with open(RULE, "w", encoding="utf-8") as f:
    f.write(text)

# --- Verify sentinel ---
with open(RULE, "r", encoding="utf-8") as f:
    check = f.read()
if "^## FIRST ACTION".replace("^", "") not in check:
    print(f"FAIL: sentinel check post-write failed; restoring from {BACKUP}")
    shutil.copy2(BACKUP, RULE)
    sys.exit(1)
# Use a literal check anchored at start-of-line
if not re.search(r"^## FIRST ACTION", check, re.MULTILINE):
    print(f"FAIL: post-write sentinel '^## FIRST ACTION' not found; restoring from {BACKUP}")
    shutil.copy2(BACKUP, RULE)
    sys.exit(1)

print(f"PATCHED: {RULE}")
PY
fi
```

### Step 6 — Merge 3 new hook entries into `.claude/settings.json`

Each entry is added only if absent. Detection keys:

- PostToolUse: look for an entry with `matcher == "Grep|Glob"` AND an inner hook whose `command` contains `investigation-counter.sh`. Absent → append to `hooks.PostToolUse`.
- UserPromptSubmit: look for an inner hook whose `command` contains `orchestrator-rule-reminder.sh`. Absent → append a new entry to `hooks.UserPromptSubmit`.
- UserPromptSubmit: look for an inner hook whose `command` contains `investigation-counter-reset.sh`. Absent → append a new entry to `hooks.UserPromptSubmit`.

JSONC abort: if the settings file contains `//` line comments, exit with a manual-patch message — `json.load` cannot parse JSONC, and silently stripping comments would lose the user's annotations.

Backup to `.bak-041` on first effective write. JSON round-trip validation post-write; restore on failure.

```bash
set -euo pipefail

python3 - <<'PY'
import json
import os
import re
import shutil
import sys

SETTINGS = ".claude/settings.json"
BACKUP = ".claude/settings.json.bak-041"

# JSONC detection: line-starting // (after optional whitespace) indicates JSONC comments
# json.load cannot parse JSONC; abort with a manual-patch message so the user preserves comments.
with open(SETTINGS, "r", encoding="utf-8") as f:
    raw = f.read()

# Look for line comments OUTSIDE strings. Conservative heuristic: any occurrence of `//` at
# line start after whitespace is JSONC; stricter string-aware parse is overkill for this gate.
if re.search(r'(?m)^\s*//', raw):
    print("ABORT: .claude/settings.json contains JSONC // line comments. json.load cannot parse JSONC.")
    print("Manual patch required: add these three hook entries and re-run verification.")
    print("  1. hooks.PostToolUse: append")
    print('     { "matcher": "Grep|Glob", "hooks": [{ "type": "command", "command": "bash \\"$CLAUDE_PROJECT_DIR/.claude/hooks/investigation-counter.sh\\"" }] }')
    print("  2. hooks.UserPromptSubmit: append")
    print('     { "hooks": [{ "type": "command", "command": "bash \\"$CLAUDE_PROJECT_DIR/.claude/hooks/orchestrator-rule-reminder.sh\\"" }] }')
    print("  3. hooks.UserPromptSubmit: append")
    print('     { "hooks": [{ "type": "command", "command": "bash \\"$CLAUDE_PROJECT_DIR/.claude/hooks/investigation-counter-reset.sh\\"" }] }')
    sys.exit(1)

try:
    data = json.loads(raw)
except Exception as e:
    print(f"FAIL: {SETTINGS} did not parse as JSON: {e}")
    sys.exit(1)

hooks = data.setdefault("hooks", {})

def inner_has_script(entry, script_name):
    if not isinstance(entry, dict):
        return False
    inner = entry.get("hooks") or []
    if not isinstance(inner, list):
        return False
    for h in inner:
        if isinstance(h, dict):
            cmd = h.get("command", "")
            if isinstance(cmd, str) and script_name in cmd:
                return True
    return False

changes = []

# ── 1. PostToolUse: Grep|Glob → investigation-counter.sh ─────────────────
post = hooks.setdefault("PostToolUse", [])
already_post = any(
    isinstance(e, dict)
    and e.get("matcher", "") == "Grep|Glob"
    and inner_has_script(e, "investigation-counter.sh")
    for e in post
)
if already_post:
    print("SKIP: PostToolUse Grep|Glob → investigation-counter.sh already present")
else:
    post.append({
        "matcher": "Grep|Glob",
        "hooks": [{
            "type": "command",
            "command": 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/investigation-counter.sh"'
        }]
    })
    changes.append("PostToolUse Grep|Glob → investigation-counter.sh")

# ── 2. UserPromptSubmit → orchestrator-rule-reminder.sh ─────────────────
ups = hooks.setdefault("UserPromptSubmit", [])
already_reminder = any(inner_has_script(e, "orchestrator-rule-reminder.sh") for e in ups)
if already_reminder:
    print("SKIP: UserPromptSubmit → orchestrator-rule-reminder.sh already present")
else:
    ups.append({
        "hooks": [{
            "type": "command",
            "command": 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/orchestrator-rule-reminder.sh"'
        }]
    })
    changes.append("UserPromptSubmit → orchestrator-rule-reminder.sh")

# ── 3. UserPromptSubmit → investigation-counter-reset.sh ────────────────
already_reset = any(inner_has_script(e, "investigation-counter-reset.sh") for e in ups)
if already_reset:
    print("SKIP: UserPromptSubmit → investigation-counter-reset.sh already present")
else:
    ups.append({
        "hooks": [{
            "type": "command",
            "command": 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/investigation-counter-reset.sh"'
        }]
    })
    changes.append("UserPromptSubmit → investigation-counter-reset.sh")

if not changes:
    print("SKIP: settings.json already has all 3 new hook entries")
    sys.exit(0)

# Backup on first effective write
if not os.path.exists(BACKUP):
    shutil.copy2(SETTINGS, BACKUP)
    print(f"BACKUP: {BACKUP}")

# Write + round-trip validate
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

for c in changes:
    print(f"PATCHED: {c}")
PY
```

### Rules for migration scripts

- **Read-before-write** — every step reads the target file (or checks its presence) before modifying
- **Idempotent** — per-step sentinel gates (`permissionDecision` in hook 12; file-exists for hooks 14/15/16; `^## FIRST ACTION` in rule file; matcher+script pair in settings.json). Re-runs on already-applied projects emit SKIP lines and exit 0
- **Self-contained** — every hook body is inlined via quoted heredoc (`<<'SH'`); no remote fetch; no reference to gitignored paths beyond the in-project `.claude/` write targets; no technique sync
- **Abort on error** — `set -euo pipefail` on every bash block; Python scripts `sys.exit(1)` on parse/walk/round-trip failure; post-write parse failure triggers restore from `.bak-041` before the script exits
- **Python JSON round-trip, not regex-on-JSON** — settings.json merge uses `json.load` / `json.dumps`; no `sed` / `awk` / regex substitution on the JSON file. JSONC detection aborts with a manual-patch message rather than lossy comment-strip
- **Quoted heredoc sentinel** — `<<'SH'` (single-quoted) so every `$VAR`, `$(...)`, `${...}` inside hook bodies stays literal at migration-apply time; the literal string `$CLAUDE_PROJECT_DIR` written into settings.json is the hook shell's variable, not the migration script's
- **Per-step backups, distinct suffixes** — rule file backup `.bak-041`; settings.json backup `.bak-041`. Both are `shutil.copy2`-created on first effective run only, never overwritten on subsequent runs

### Required: register in migrations/index.json

Main thread applies this entry — do not attempt to edit `migrations/index.json` from inside the migration script. Append to the `migrations` array:

```json
{
  "id": "041",
  "file": "041-rule-adherence-enforcement/migration.md",
  "description": "Transport the Opus-4.7-calibrated main-thread orchestrator enforcement stack to client projects. Upgrades .claude/hooks/orchestrator-nudge.sh to the M6 structural JSON permissionDecision:\"deny\" form on investigation-shaped Grep/Glob (bare exit 2 regressed under Opus 4.6/4.7 per upstream #24327; Edit/Write branch kept as advisory stderr because deny is broken upstream for edit tools per #37210/#33106). Adds M3 per-turn rule reminder (.claude/hooks/orchestrator-rule-reminder.sh on UserPromptSubmit) to defeat CLAUDE.md context decay on long sessions. Adds M2 per-session Grep/Glob counter (.claude/hooks/investigation-counter.sh on PostToolUse Grep|Glob with N=2 decision:\"block\" directive) plus turn-boundary reset (.claude/hooks/investigation-counter-reset.sh on UserPromptSubmit). Every new enforcement path exempts sub-agents via the agent_id stdin field. Patches .claude/rules/main-thread-orchestrator.md with a FIRST ACTION + Anti-Patterns block at file top, tightens Quick-Fix Carve-Out criterion 2 (user-supplied path THIS message OR agent-returned THIS turn — not 'mentioned anywhere in context'), and updates the Enforcement section to describe the M6/M2/M3 hook triple. Wires the 3 new hooks into .claude/settings.json via Python json round-trip merge (JSONC aborts with a manual-patch message). Sentinel-guarded per step so re-runs on already-patched projects are no-ops. bootstrap-state.json advances to last_migration=041.",
  "breaking": false
}
```

---

## Verify

```bash
set -euo pipefail

# Hook scripts present + executable + pass shellcheck (if available) + bash -n syntax check
for hook in orchestrator-nudge.sh orchestrator-rule-reminder.sh investigation-counter.sh investigation-counter-reset.sh; do
  path=".claude/hooks/$hook"
  [[ -f "$path" ]] || { echo "FAIL: $path missing"; exit 1; }
  [[ -x "$path" ]] || { echo "FAIL: $path not executable"; exit 1; }
  bash -n "$path" || { echo "FAIL: $path failed bash -n syntax check"; exit 1; }
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$path" || { echo "FAIL: $path failed shellcheck"; exit 1; }
  fi
done

# settings.json parses
python3 -c "import json; json.load(open('.claude/settings.json'))" \
  || { echo "FAIL: .claude/settings.json did not parse as JSON"; exit 1; }

# Sentinels
grep -q "permissionDecision" .claude/hooks/orchestrator-nudge.sh \
  || { echo "FAIL: orchestrator-nudge.sh missing M6 permissionDecision sentinel"; exit 1; }
grep -q "investigation-counter" .claude/settings.json \
  || { echo "FAIL: settings.json missing investigation-counter wiring"; exit 1; }
grep -q "orchestrator-rule-reminder" .claude/settings.json \
  || { echo "FAIL: settings.json missing orchestrator-rule-reminder wiring"; exit 1; }
grep -q "investigation-counter-reset" .claude/settings.json \
  || { echo "FAIL: settings.json missing investigation-counter-reset wiring"; exit 1; }
grep -q '^## FIRST ACTION' .claude/rules/main-thread-orchestrator.md \
  || { echo "FAIL: main-thread-orchestrator.md missing FIRST ACTION sentinel"; exit 1; }

# Functional smoke tests — M6 deny on investigation-shaped Grep
set +e
OUT=$(printf '%s' '{"tool_name":"Grep","tool_input":{"pattern":"FooBarService"}}' | bash .claude/hooks/orchestrator-nudge.sh 2>/dev/null)
EC=$?
set -e
[[ $EC -eq 0 ]] || { echo "FAIL: orchestrator-nudge CamelCase Grep expected exit 0, got $EC"; exit 1; }
printf '%s' "$OUT" | grep -q '"permissionDecision":"deny"' \
  || { echo "FAIL: orchestrator-nudge CamelCase Grep did not emit JSON deny"; exit 1; }

# M6 subagent exemption
set +e
OUT=$(printf '%s' '{"tool_name":"Grep","tool_input":{"pattern":"FooBarService"},"agent_id":"sub-1"}' | bash .claude/hooks/orchestrator-nudge.sh 2>/dev/null)
EC=$?
set -e
[[ $EC -eq 0 ]] || { echo "FAIL: orchestrator-nudge subagent exemption expected exit 0, got $EC"; exit 1; }
[[ -z "$OUT" ]] || { echo "FAIL: orchestrator-nudge subagent exemption expected empty stdout, got $OUT"; exit 1; }

# M3 rule reminder emits ORCHESTRATOR RULE line
OUT=$(printf '%s' '{"session_id":"verify","prompt":"x"}' | bash .claude/hooks/orchestrator-rule-reminder.sh 2>/dev/null)
printf '%s' "$OUT" | grep -q '^ORCHESTRATOR RULE:' \
  || { echo "FAIL: orchestrator-rule-reminder did not emit ORCHESTRATOR RULE line"; exit 1; }

# M2 counter N=2 behavior
rm -f /tmp/cc-inv-count-verify-041
printf '%s' '{"tool_name":"Grep","session_id":"verify-041"}' | bash .claude/hooks/investigation-counter.sh >/dev/null 2>&1
[[ "$(cat /tmp/cc-inv-count-verify-041 2>/dev/null)" == "1" ]] \
  || { echo "FAIL: M2 counter first hit did not produce counter=1"; exit 1; }
OUT=$(printf '%s' '{"tool_name":"Grep","session_id":"verify-041"}' | bash .claude/hooks/investigation-counter.sh 2>/dev/null)
printf '%s' "$OUT" | grep -q '"decision":"block"' \
  || { echo "FAIL: M2 counter second hit did not emit decision:block"; exit 1; }

# M2 subagent exemption (counter should not increment)
BEFORE=$(cat /tmp/cc-inv-count-verify-041)
printf '%s' '{"tool_name":"Grep","session_id":"verify-041","agent_id":"sub-1"}' | bash .claude/hooks/investigation-counter.sh >/dev/null 2>&1
AFTER=$(cat /tmp/cc-inv-count-verify-041)
[[ "$BEFORE" == "$AFTER" ]] \
  || { echo "FAIL: M2 subagent exemption — counter changed from $BEFORE to $AFTER"; exit 1; }

# Counter reset removes the file
printf '%s' '{"session_id":"verify-041","prompt":"x"}' | bash .claude/hooks/investigation-counter-reset.sh >/dev/null 2>&1
[[ ! -f /tmp/cc-inv-count-verify-041 ]] \
  || { echo "FAIL: M2 counter reset did not remove /tmp/cc-inv-count-verify-041"; exit 1; }

# Cleanup
rm -f /tmp/cc-inv-count-verify-041 /tmp/cc-inv-count-default

echo "PASS: migration 041 verified"
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "041"
- append `{ "id": "041", "applied_at": "{ISO8601}", "description": "Rule adherence enforcement stack — M6 JSON permissionDecision:deny on investigation-shaped Grep/Glob; M3 per-turn rule reminder on UserPromptSubmit; M2 per-session Grep/Glob counter on PostToolUse with N=2 decision:block directive + turn-boundary reset; rule file patched with FIRST ACTION header and tightened Quick-Fix Carve-Out criterion 2; 3 new hook entries wired into settings.json; every new enforcement path exempts sub-agents via agent_id" }` to `applied[]`

---

## Idempotency

Re-running after success: every step's sentinel passes, so every step emits SKIP and exits 0 without writing.

- Step 1 — `grep -q "permissionDecision" .claude/hooks/orchestrator-nudge.sh` → present → SKIP
- Step 2 — `[[ -f .claude/hooks/orchestrator-rule-reminder.sh ]]` → present → SKIP
- Step 3 — `[[ -f .claude/hooks/investigation-counter.sh ]]` → present → SKIP
- Step 4 — `[[ -f .claude/hooks/investigation-counter-reset.sh ]]` → present → SKIP
- Step 5 — `grep -q '^## FIRST ACTION' .claude/rules/main-thread-orchestrator.md` → present → SKIP
- Step 6 — Python merge walks every entry, finds all 3 target (matcher+script) pairs present, prints three SKIP lines and exits 0 without writing

No backups are created on the re-run (every `shutil.copy2` to `.bak-041` is gated on `not os.path.exists(BACKUP)` AND on at least one effective write — the second gate is covered by the early SKIP return before the backup block).

**Dogfood / self-apply note.** Running this migration on the bootstrap repo itself — where `.claude/hooks/orchestrator-nudge.sh` already contains `permissionDecision`, all three new hook files already exist, `.claude/rules/main-thread-orchestrator.md` already has `^## FIRST ACTION` at the top, and `.claude/settings.json` already has all 3 new entries — will emit 6 SKIP lines (one per step) and exit 0. No files modified. No backups written. `git status` after a dry-run on this repo must show a clean tree. This is the correct behavior: the repo is already in target state from the prior direct edit session that motivated the migration. The migration exists to propagate that target state to every downstream client project.

Running on a partially-hand-edited project (e.g. M6 hook already upgraded but M2 counter hooks missing): the patcher rewrites only what is missing, leaves the already-patched parts alone, and reports per-step WROTE / SKIP lines accurately.

---

## Rollback

Restore per-file backups created by Step 5 and Step 6. The newly-created hook files from Steps 2/3/4 must be deleted (they did not exist pre-migration).

```bash
set -euo pipefail

# Remove newly-created hooks (Steps 2, 3, 4)
rm -f .claude/hooks/orchestrator-rule-reminder.sh
rm -f .claude/hooks/investigation-counter.sh
rm -f .claude/hooks/investigation-counter-reset.sh

# Restore pre-M6 orchestrator-nudge.sh from git (no .bak file — Step 1 wrote fresh content)
git restore .claude/hooks/orchestrator-nudge.sh 2>/dev/null || {
  echo "WARN: no git tracking for .claude/hooks/orchestrator-nudge.sh — reinstall advisory-only version manually if needed"
}

# Restore rule file from Step 5 backup if present, else git
if [[ -f .claude/rules/main-thread-orchestrator.md.bak-041 ]]; then
  mv .claude/rules/main-thread-orchestrator.md.bak-041 .claude/rules/main-thread-orchestrator.md
else
  git restore .claude/rules/main-thread-orchestrator.md 2>/dev/null || {
    echo "WARN: no backup and no git tracking for main-thread-orchestrator.md — reapply the pre-041 rule content manually"
  }
fi

# Restore settings.json from Step 6 backup if present, else git
if [[ -f .claude/settings.json.bak-041 ]]; then
  mv .claude/settings.json.bak-041 .claude/settings.json
else
  git restore .claude/settings.json 2>/dev/null || {
    echo "WARN: no backup and no git tracking for settings.json — strip the 3 new hook entries manually"
  }
fi
```

Note: rollback reintroduces the pre-041 advisory-only main-thread enforcement — CLAUDE.md-decay-prone on long sessions, unprotected against investigation-shaped Grep/Glob from main under Opus 4.7. Prefer `git restore` over `.bak-041` where the project tracks `.claude/`; most bootstrapped projects gitignore `.claude/`, so the `.bak-041` fallback covers that case. The 3 newly-created hook files are not in git (they did not exist pre-migration), so `rm -f` is the only path for them.
