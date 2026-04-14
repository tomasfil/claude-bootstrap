# Migration 036 — Main Thread Orchestrator Doctrine

> Install main-thread orchestrator doctrine as an advisory-only enforcement stack in existing bootstrapped projects. Creates `.claude/rules/main-thread-orchestrator.md` (the doctrine: classify → dispatch → synthesize, tier 0–3 definitions, quick-fix carve-out, investigation escalation ladder, anti-patterns, rationale), creates `.claude/hooks/orchestrator-nudge.sh` (PreToolUse advisory nudge on `Edit|Write|MultiEdit|NotebookEdit|Grep|Glob` that emits a stderr reminder and exits 0 — NEVER blocks), merges a new PreToolUse matcher entry into `.claude/settings.json`, and appends an `@import .claude/rules/main-thread-orchestrator.md` line to the project's `CLAUDE.md` `@import` block so the doctrine is always in main-thread context. Motivated by a recurring observation in field sessions: main thread routinely bypasses `proj-quick-check` and `proj-researcher` for code investigation and routinely Edits/Writes files directly that should route through `proj-code-writer-{lang}`, bloating main-thread context on Opus and triggering compaction far earlier than necessary. The existing `skill-routing.md` and `general.md` rules tell main WHEN to dispatch but not WHAT the tiers are or WHEN a direct edit is acceptable — this migration installs the missing doctrine layer plus an advisory nudge hook that reminds main at the exact decision point (tool-call time), without ever blocking the tool call.

---

## Metadata

```yaml
id: "036"
breaking: false
affects: [rules, hooks, settings, claude-md]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"036"`
- `breaking`: `false` — additive everywhere. New rule file (does not exist before), new hook script (does not exist before), new settings.json array entry merged via sentinel-guarded Python (existing entries untouched), single new `@import` line appended to CLAUDE.md's existing `@import` block (or skipped if CLAUDE.md is hand-edited without an `@import` block — reported for manual review, never fail-hard). No existing file rewritten end-to-end.
- `affects`: `[rules, hooks, settings, claude-md]` — installs `.claude/rules/main-thread-orchestrator.md`, installs `.claude/hooks/orchestrator-nudge.sh`, merges into `.claude/settings.json`, patches `CLAUDE.md` `@import` block, advances `.claude/bootstrap-state.json` → `last_migration: "036"`.
- `requires_mcp_json`: `false` — doctrine applies regardless of MCP presence. The rule references MCP routing in the "Related" section but does not depend on it.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap release that ships the `.claude/hooks/` and `.claude/rules/` directory layout this migration patches.

---

## Problem

### The observed failure mode

Main-thread sessions on Opus routinely bypass the project's own lookup and research agents. Field observations across multiple sessions:

1. **Investigation bloat.** Main reads 3–5 files via `Read`, runs 1–2 `Grep` or `Glob` calls, and synthesizes an answer directly — consuming 5–15k tokens of main-thread context per question. The same answer from `proj-quick-check` (haiku, returns text + file:line evidence) would cost ~200–500 tokens of main-thread context.
2. **Direct-edit bloat.** Main opens a target file, reads surrounding context, reasons about the change, edits, verifies — all on main thread. A `proj-code-writer-{lang}` dispatch would do the same work in a fresh context and return a 1-line confirmation.
3. **Compaction acceleration.** The accumulated investigation and edit context pushes main past the compaction threshold far earlier than necessary, causing a cache-miss compaction round that cost the user multiple seconds of latency and a full re-cache of conversation history at the next turn.

### Why the existing rules don't cover it

`.claude/rules/skill-routing.md` tells main "before starting implementation, check if a skill applies" — but does not define tiers, does not specify a carve-out for quick fixes, and does not say when it is acceptable for main to edit directly.

`.claude/rules/general.md` has a "dispatch agents when specified" bullet — but it is one bullet in a long process-rules list, and it does not define the cost model for why dispatching matters.

No existing rule says:
- Main's default mode is orchestrator (classify → dispatch → synthesize).
- Investigation on main → `proj-quick-check` first, escalate to `proj-researcher` on incomplete return.
- Main may edit directly ONLY when the change is single-file, ≤10 lines, known-location, mechanically obvious, and zero cross-file impact.

Without a named doctrine, main defaults to "do it myself" because that is the path of least resistance — `Read`/`Grep`/`Edit` are right there in the tool list and there is zero friction to using them directly.

### Why an advisory nudge, not a hard block

A hard-block hook on `Edit|Write|MultiEdit` would break the quick-fix carve-out — genuine one-line typo fixes are faster on main than dispatched. A hard-block hook on `Grep|Glob` would break literal-string search in config files, commit messages, and non-code files. The user explicitly rejected a hard-block approach during the design discussion that motivated this migration: "I don't want hard block on main thread ... sometimes I want it to do quick fix."

An advisory nudge delivers the reminder at the exact decision point (PreToolUse, tool-call time) without blocking the tool. The reminder text appears in the next-turn context, main reads it, main judges whether the carve-out applies, main proceeds. False positives are cheap (one stderr line of noise); false negatives (main ignoring the nudge) self-correct over time via `.learnings/log.md` observations that feed `/reflect` for doctrine tightening.

---

## Changes

1. **Creates** `.claude/rules/main-thread-orchestrator.md` with the full orchestrator doctrine: Rule, Scope, Tier 0–3 definitions, Quick-Fix Carve-Out criteria, Investigation Escalation Ladder, Dispatch Prompt Quality requirements, Anti-Patterns on Main, Rationale, Related rules, Enforcement layers. Content is the canonical source — identical text to `modules/02-project-config.md` Step 3 item 11 so that re-running bootstrap produces the same file byte-for-byte.

2. **Creates** `.claude/hooks/orchestrator-nudge.sh` — PreToolUse advisory hook that reads the PreToolUse JSON on stdin, extracts `tool_name`, and emits a short stderr reminder matched to the tool class (`Edit|Write|MultiEdit|NotebookEdit` → carve-out reminder; `Grep|Glob` → investigation escalation reminder). Never blocks (exit 0 unconditionally). Fail-open on parse errors. Fires uniformly in every project including the bootstrap repo itself (no project-type carve-out — bootstrap dogfoods its own doctrine).

3. **Merges** a new `PreToolUse` matcher entry into `.claude/settings.json` — matcher `Edit|Write|MultiEdit|NotebookEdit|Grep|Glob`, command `bash .claude/hooks/orchestrator-nudge.sh`. Sentinel-guarded idempotency on `orchestrator-nudge.sh` substring in the file. Existing PreToolUse entries (guard-git, mcp-discovery-gate) are preserved exactly.

4. **Appends** `@import .claude/rules/main-thread-orchestrator.md` to the project's `CLAUDE.md` `@import` block. Located via python `split('@import', 1)` + last-import insertion. If `CLAUDE.md` has no `@import` block (hand-edited variant), the step prints a MANUAL-REVIEW report and skips — never fail-hard, never guess at placement.

5. **Advances** `.claude/bootstrap-state.json` → `last_migration: "036"` + appends entry to `applied[]` with ISO8601 UTC timestamp and description.

Idempotency table:

| Step | Sentinel | Skip condition |
|---|---|---|
| 2 (rule file) | `[[ -f .claude/rules/main-thread-orchestrator.md ]]` with `# Main Thread Orchestrator Doctrine` header | Rule file already installed with the canonical header. |
| 3 (hook script) | `[[ -f .claude/hooks/orchestrator-nudge.sh ]]` with `orchestrator-nudge.sh — PreToolUse advisory nudge` first-line comment | Hook script already installed with the canonical first-line comment. |
| 4 (settings.json) | `grep -qF 'orchestrator-nudge.sh' .claude/settings.json` | Hook already wired. |
| 5 (CLAUDE.md @import) | `grep -qF '@import .claude/rules/main-thread-orchestrator.md' CLAUDE.md` | `@import` already present. |
| 6 (state) | `036` already in `applied[]` in `.claude/bootstrap-state.json` | State already advanced. |

Running twice is safe — every step prints `SKIP:` for the already-applied path and exits 0.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]]  || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/rules" ]]                  || { printf "ERROR: .claude/rules/ missing — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/hooks" ]]                  || { printf "ERROR: .claude/hooks/ missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/settings.json" ]]          || { printf "ERROR: .claude/settings.json missing — run full bootstrap first\n"; exit 1; }
command -v python3 >/dev/null 2>&1        || { printf "ERROR: python3 required\n"; exit 1; }
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Detect current state

Write detection result to `/tmp/mig036-state` so subsequent bash blocks (each a fresh shell) can source it.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig036-state"
HAS_RULE=""
HAS_HOOK=""
HAS_SETTINGS=""
HAS_IMPORT=""

if [[ -f ".claude/rules/main-thread-orchestrator.md" ]] && \
   grep -qF '# Main Thread Orchestrator Doctrine' .claude/rules/main-thread-orchestrator.md 2>/dev/null; then
  HAS_RULE="yes"
fi

if [[ -f ".claude/hooks/orchestrator-nudge.sh" ]] && \
   grep -qF 'orchestrator-nudge.sh — PreToolUse advisory nudge' .claude/hooks/orchestrator-nudge.sh 2>/dev/null; then
  HAS_HOOK="yes"
fi

if grep -qF 'orchestrator-nudge.sh' .claude/settings.json 2>/dev/null; then
  HAS_SETTINGS="yes"
fi

if [[ -f "CLAUDE.md" ]] && grep -qF '@import .claude/rules/main-thread-orchestrator.md' CLAUDE.md 2>/dev/null; then
  HAS_IMPORT="yes"
fi

{
  printf 'HAS_RULE=%q\n'     "$HAS_RULE"
  printf 'HAS_HOOK=%q\n'     "$HAS_HOOK"
  printf 'HAS_SETTINGS=%q\n' "$HAS_SETTINGS"
  printf 'HAS_IMPORT=%q\n'   "$HAS_IMPORT"
} > "$STATE_FILE"

printf "STATE: HAS_RULE=%s HAS_HOOK=%s HAS_SETTINGS=%s HAS_IMPORT=%s\n" \
  "${HAS_RULE:-no}" "${HAS_HOOK:-no}" "${HAS_SETTINGS:-no}" "${HAS_IMPORT:-no}"
```

---

### Step 2 — Install `.claude/rules/main-thread-orchestrator.md`

Branch on `HAS_RULE`:
- `HAS_RULE=yes` → SKIP (sentinel header matches).
- Otherwise → write the canonical rule file content via Python heredoc (triple-quoted, single-quoted heredoc to preserve unicode em-dashes and arrows).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig036-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig036-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${HAS_RULE:-}" ]]; then
  printf "SKIP: .claude/rules/main-thread-orchestrator.md already contains canonical header\n"
  exit 0
fi

mkdir -p .claude/rules

python3 - <<'PY'
canonical = """# Main Thread Orchestrator Doctrine

## Rule
Main thread = orchestrator. Classifies requests, dispatches sub-agents, synthesizes agent returns, talks to user. Main does NOT investigate multi-file, search by pattern, or write production code — except the quick-fix carve-out below. This rule addresses main only; dispatched sub-agents SHOULD use their own tools within scope (a code-writer SHOULD Edit/Write; a researcher SHOULD Read/Grep/Glob). Source: Anthropic orchestrator-workers cookbook pattern — "the orchestrator stays lean because it's delegating the heavy lifting to workers with their own context space".

## Tiers

### Tier 0 — Direct (no tools, conversational)
Classification, synthesis of agent outputs, design discussion, user Q&A, effort/scope judgment calls. Zero tool calls from main. Matches the plurality of main-thread turns.

### Tier 1 — Main Read allowed (exact known path)
User handed a concrete path (`src/foo.ts:42`, `@file.md`, absolute path in the prompt) OR target is already in-context from a prior agent return. Single-file Read is fine; few-file Read on multiple pre-supplied paths is fine. NO Grep | Glob | search. NO "let me Read the surrounding files to understand".

### Tier 2 — Dispatch (investigation)
Any "where / how / find / which / what calls / trace / understand / map" question → dispatch, do not investigate on main.
- Default: `proj-quick-check` (haiku, fast, cheap, text return — no findings file). Use for factual lookups, symbol existence checks, single-point answers.
- Escalate to `proj-researcher` (sonnet, evidence-tracked, writes findings file) when the quick-check return is incomplete | needs multi-source synthesis | needs cross-file reasoning | needs external web research | will be consumed by a downstream code-writer dispatch.
- Multiple sequential `proj-quick-check` calls on related-but-separate sub-questions are fine. Parallel: multiple `Agent` calls in one message = parallel foreground dispatch.
- No hard dispatch-count limit. Orchestrator weighs dispatch latency (~5–15s per call) vs main-context bloat from direct reads. Anything involving search, correlation, or pattern recognition across files → dispatch always wins. A single Read of one unrelated file on a known path → Tier 1, direct.

### Tier 3 — Dispatch (code change)
Any Edit | Write | MultiEdit | NotebookEdit beyond the carve-out → route through `/code-write` | `/tdd` | `/execute-plan` | direct `proj-code-writer-{lang}` dispatch. Main does NOT write production code.

## Quick-Fix Carve-Out (Tier 3 exception — main may edit directly)
Main may edit directly when ALL of the following hold:
1. Single file, ≤ ~10 lines changed
2. Target file + location already known (user-provided path OR in-context from prior agent return) — NO discovery needed
3. Mechanically obvious: typo fix | version bump | config value change | one-line logic swap | single-use local rename | comment edit
4. Zero cross-file impact: no import changes, no type/API changes, no shared-contract touches
5. User signaled quick intent OR the fix is trivially mechanical (no judgment call required)

Any ONE criterion fails → Tier 3 dispatch, no exceptions. "Feels quick" is not a criterion. If you find yourself reasoning "it's just one more file" or "it's only slightly cross-file" → dispatch.

## Investigation Escalation Ladder
1. Start every investigation with `proj-quick-check` — it is the cheapest option with structured file:line evidence return.
2. Evaluate the return:
   - Complete answer + grounded in file:line evidence → done, synthesize for user.
   - Partial answer, needs deeper synthesis, cross-file reasoning, multi-source correlation, or a structured findings doc for a downstream dispatch → dispatch `proj-researcher` (do NOT Read the files yourself).
   - One sub-question answered, more sub-questions remain → dispatch more `proj-quick-check` calls (sequential OR parallel — multiple `Agent` calls in one message = parallel foreground, safe concurrency).
   - Completely wrong domain / missed the question → re-dispatch with a corrected brief. Never fall back to "I'll just Read it myself".
3. No hard dispatch-count limit. The orchestrator is trusted to judge depth vs. cost.

## Dispatch Prompt Quality (when you do dispatch)
Every dispatch prompt MUST include:
- **Objective**: the single concrete question, not "explore X"
- **Output format**: text return (quick-check) | findings file path (researcher) | structured fields
- **Scope bounds**: which directory | file glob | layer to inspect; hard "do not touch Y" if relevant
- **Return contract**: path + 1-line summary (<100 chars), OR text answer + file:line evidence for quick-check
- **Known context**: anything already-Read or already-known, to avoid duplicate work
Source: Anthropic multi-agent research system — "each subagent needs an objective, an output format, guidance on the tools and sources to use, and clear task boundaries".

## Anti-Patterns on Main
- Grep | Glob for investigation on main → ALWAYS Tier 2 dispatch
- Reading 3+ files to "understand" something → Tier 2 dispatch
- Editing >10 lines across multiple locations → Tier 3 dispatch
- "I'll just quickly check" when the check requires search → Tier 2 dispatch
- Main-thread deep code analysis when `proj-researcher` exists → Tier 2 dispatch
- Skipping dispatch "to save latency" — saves seconds, costs thousands of main-context tokens, triggers compaction earlier, costs the user far more
- Dispatching with a vague prompt ("look into X") when a sharp brief ("does class X call Y; file:line evidence") fits — vague prompts waste sub-agent turns

## Rationale
Main-thread context is the most expensive token budget in the system: Opus + long conversation history + compaction cost + user-facing latency on every read. Sub-agents run in fresh disposable contexts, return compressed summaries (text for quick-check, findings file for researcher), and leave main's context small. Over a long session, delegating converts expensive main-thread tokens into cheap disposable sub-agent tokens; the context-budget savings dominate per-call latency cost. The user sees faster end-to-end turns once compaction is avoided.

## Related
- `.claude/rules/skill-routing.md` — routing-time skill check (upstream: "before implementation, check if skill applies")
- `.claude/rules/max-quality.md` — §6 No Hedging: solvable → solve, don't ask; §5 Full Rule Compliance: dispatch agents actually dispatched
- `.claude/rules/agent-scope-lock.md` — downstream: once dispatched, agents stay in their listed files
- `.claude/rules/mcp-routing.md` — MCP tool routing for code discovery (applies inside Tier 2 dispatch)

## Enforcement
- Advisory PreToolUse hook `.claude/hooks/orchestrator-nudge.sh` on `Edit|Write|MultiEdit|NotebookEdit|Grep|Glob` → stderr reminder citing this rule. NEVER blocks (exit 0). Orchestrator reads the nudge and decides.
- `@import .claude/rules/main-thread-orchestrator.md` in `CLAUDE.md` (always loaded on main thread).
- Review-time catch: `/review` flags turns violating tier discipline.
- `.learnings/log.md` logs every observed violation under `correction` category → feeds `/reflect` for doctrine tightening.
"""

with open('.claude/rules/main-thread-orchestrator.md', 'w', encoding='utf-8') as f:
    f.write(canonical)

print("WROTE: .claude/rules/main-thread-orchestrator.md")
PY

if ! grep -qF '# Main Thread Orchestrator Doctrine' .claude/rules/main-thread-orchestrator.md; then
  printf "ERROR: rule-file write verification failed\n"
  exit 1
fi
printf "VERIFIED: .claude/rules/main-thread-orchestrator.md installed\n"
```

---

### Step 3 — Install `.claude/hooks/orchestrator-nudge.sh`

Branch on `HAS_HOOK`:
- `HAS_HOOK=yes` → SKIP (sentinel first-line comment matches).
- Otherwise → write the canonical hook content via heredoc (quoted `'HOOK_EOF'` so `$TOOL_NAME`, `$INPUT` etc. are preserved literally).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig036-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig036-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${HAS_HOOK:-}" ]]; then
  printf "SKIP: .claude/hooks/orchestrator-nudge.sh already contains canonical first-line comment\n"
  exit 0
fi

mkdir -p .claude/hooks

cat > .claude/hooks/orchestrator-nudge.sh <<'HOOK_EOF'
#!/usr/bin/env bash
# orchestrator-nudge.sh — PreToolUse advisory nudge (main-thread orchestrator doctrine)
# Reminds main thread to delegate to sub-agents per .claude/rules/main-thread-orchestrator.md.
# NEVER blocks. Exit 0 always. Sub-agent contexts: the reminder text says "ignore if sub-agent".
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin); print(d.get("tool_name",""))
except Exception:
  print("")
' 2>/dev/null || printf '')

case "$TOOL_NAME" in
  Edit|Write|MultiEdit|NotebookEdit)
    printf >&2 '%s\n' "[orchestrator-nudge] Main-thread edit? Quick-fix carve-out applies only when ALL hold: (1) single file, (2) <=10 lines changed, (3) target + location already known, (4) mechanically obvious (typo/version/config/one-line-swap), (5) zero cross-file impact. Any criterion fails -> dispatch proj-code-writer-{lang} via /code-write /tdd /execute-plan. Sub-agents: this nudge targets main, ignore. Rule: .claude/rules/main-thread-orchestrator.md"
    ;;
  Grep|Glob)
    printf >&2 '%s\n' "[orchestrator-nudge] Main-thread investigation? Dispatch proj-quick-check (fast haiku, text return) for factual lookups; escalate to proj-researcher (sonnet, findings file) on incomplete / multi-source / cross-file synthesis. Multiple sequential quick-checks OK — orchestrator decides depth. Sub-agents: this nudge targets main, ignore. Rule: .claude/rules/main-thread-orchestrator.md"
    ;;
esac

exit 0
HOOK_EOF

chmod +x .claude/hooks/orchestrator-nudge.sh

# Sentinel gap protection: on any verification failure below, rm the hook file
# so the next run's sentinel check (grep for canonical first-line comment) fails
# and Step 3 cleanly re-installs rather than SKIP-ing a broken hook.
fail_and_clean() {
  printf "%s\n" "$1"
  if [[ -n "${2:-}" ]]; then
    printf "got: %s\n" "$2"
  fi
  rm -f .claude/hooks/orchestrator-nudge.sh
  exit 1
}

if ! bash -n .claude/hooks/orchestrator-nudge.sh; then
  fail_and_clean "ERROR: orchestrator-nudge.sh has bash syntax errors"
fi

# Smoke tests — fail-closed on any unexpected exit code or missing stderr reminder
SMOKE_EDIT=$(printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"x.md"}}' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
if ! printf '%s' "$SMOKE_EDIT" | grep -qF 'carve-out'; then
  fail_and_clean "ERROR: Edit smoke test — stderr did not contain 'carve-out'" "$SMOKE_EDIT"
fi

SMOKE_GREP=$(printf '%s' '{"tool_name":"Grep","tool_input":{"pattern":"foo"}}' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
if ! printf '%s' "$SMOKE_GREP" | grep -qF 'proj-quick-check'; then
  fail_and_clean "ERROR: Grep smoke test — stderr did not contain 'proj-quick-check'" "$SMOKE_GREP"
fi

SMOKE_READ=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"x.md"}}' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
if [[ -n "$SMOKE_READ" ]]; then
  fail_and_clean "ERROR: Read smoke test — expected empty stderr (Read is Tier 1)" "$SMOKE_READ"
fi

SMOKE_BAD=$(printf 'not json' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
if [[ -n "$SMOKE_BAD" ]]; then
  fail_and_clean "ERROR: parse-error smoke test — expected empty stderr (fail-open)" "$SMOKE_BAD"
fi

printf "VERIFIED: .claude/hooks/orchestrator-nudge.sh installed + smoke tests pass\n"
```

---

### Step 4 — Merge `.claude/settings.json` PreToolUse entry

Branch on `HAS_SETTINGS`:
- `HAS_SETTINGS=yes` → SKIP (sentinel `orchestrator-nudge.sh` substring present).
- Otherwise → load settings.json, locate the `hooks.PreToolUse` array, append the new matcher entry, write back with 2-space indent.

Never touches any other entry. Preserves comments if the file was JSONC (python `json.load` strips comments — so we guard with a pre-check: if the file contains `//` comments, abort with a manual-patch message rather than silently stripping them).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig036-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig036-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${HAS_SETTINGS:-}" ]]; then
  printf "SKIP: .claude/settings.json already wires orchestrator-nudge.sh\n"
  exit 0
fi

# JSONC guard — abort if comments present (python json.load would strip them silently)
if grep -qE '^\s*//' .claude/settings.json 2>/dev/null; then
  printf "MANUAL REVIEW: .claude/settings.json contains // comments — cannot safely auto-patch with python json.load.\n"
  printf "  Action required: manually append this entry to the hooks.PreToolUse array:\n"
  printf '    { "matcher": "Edit|Write|MultiEdit|NotebookEdit|Grep|Glob", "hooks": [{ "type": "command", "command": "bash .claude/hooks/orchestrator-nudge.sh" }] }\n'
  exit 0
fi

python3 - <<'PY'
import json
import os
import tempfile

SETTINGS_FILE = ".claude/settings.json"
with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
pre_tool_use = hooks.setdefault("PreToolUse", [])

# Defensive check — skip if already present (belt-and-suspenders, Step 1 already checked the string)
already = any(
    isinstance(entry, dict)
    and any(
        isinstance(h, dict) and "orchestrator-nudge.sh" in h.get("command", "")
        for h in entry.get("hooks", [])
    )
    for entry in pre_tool_use
)

if already:
    print("SKIP: orchestrator-nudge.sh already wired (defensive check)")
else:
    pre_tool_use.append({
        "matcher": "Edit|Write|MultiEdit|NotebookEdit|Grep|Glob",
        "hooks": [
            {"type": "command", "command": "bash .claude/hooks/orchestrator-nudge.sh"}
        ]
    })
    # Atomic write: temp-file-then-rename. Prevents partial-write corruption on
    # mid-write crash (OOM, SIGKILL, disk-full). os.replace is atomic on POSIX +
    # Windows within the same filesystem.
    target_dir = os.path.dirname(os.path.abspath(SETTINGS_FILE))
    fd, tmpname = tempfile.mkstemp(prefix=".settings.", suffix=".json.tmp", dir=target_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump(settings, tmp, indent=2)
            tmp.write("\n")
        os.replace(tmpname, SETTINGS_FILE)
    except Exception:
        if os.path.exists(tmpname):
            os.unlink(tmpname)
        raise
    print("WIRED: PreToolUse Edit|Write|MultiEdit|NotebookEdit|Grep|Glob -> orchestrator-nudge.sh")
PY

# Verify settings.json still parses
python3 -c 'import json; json.load(open(".claude/settings.json"))' || {
  printf "ERROR: .claude/settings.json no longer parses as valid JSON after merge\n"
  exit 1
}

if ! grep -qF 'orchestrator-nudge.sh' .claude/settings.json; then
  printf "ERROR: orchestrator-nudge.sh not present in .claude/settings.json after merge\n"
  exit 1
fi
printf "VERIFIED: .claude/settings.json wires orchestrator-nudge.sh\n"
```

---

### Step 5 — Append `@import .claude/rules/main-thread-orchestrator.md` to `CLAUDE.md`

Branch on `HAS_IMPORT`:
- `HAS_IMPORT=yes` → SKIP.
- Otherwise → locate the last `@import` line in CLAUDE.md and insert the new `@import` immediately after it. If CLAUDE.md has no `@import` block, print a MANUAL-REVIEW report and skip (never guess at placement, never fail-hard).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig036-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig036-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${HAS_IMPORT:-}" ]]; then
  printf "SKIP: CLAUDE.md already imports main-thread-orchestrator.md\n"
  exit 0
fi

if [[ ! -f "CLAUDE.md" ]]; then
  printf "MANUAL REVIEW: CLAUDE.md not found at project root — cannot auto-patch.\n"
  printf "  Action required: when CLAUDE.md is created, add line: @import .claude/rules/main-thread-orchestrator.md\n"
  exit 0
fi

python3 - <<'PY'
import os
import sys
import tempfile

CLAUDE_MD = "CLAUDE.md"
with open(CLAUDE_MD, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.splitlines(keepends=False)

# Find last line starting with "@import"
last_import_idx = -1
for i, line in enumerate(lines):
    if line.lstrip().startswith("@import"):
        last_import_idx = i

if last_import_idx < 0:
    print("MANUAL REVIEW: CLAUDE.md has no @import block — cannot auto-patch.")
    print("  Action required: manually add line: @import .claude/rules/main-thread-orchestrator.md")
    sys.exit(0)

# Insert new @import immediately after the last existing one
new_line = "@import .claude/rules/main-thread-orchestrator.md"
lines.insert(last_import_idx + 1, new_line)

new_content = "\n".join(lines)
if content.endswith("\n"):
    new_content += "\n"

# Atomic write: temp-file-then-rename. Prevents partial-write corruption on
# mid-write crash. os.replace is atomic on POSIX + Windows within same filesystem.
target_dir = os.path.dirname(os.path.abspath(CLAUDE_MD)) or "."
fd, tmpname = tempfile.mkstemp(prefix=".CLAUDE.md.", suffix=".tmp", dir=target_dir)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as tmp:
        tmp.write(new_content)
    os.replace(tmpname, CLAUDE_MD)
except Exception:
    if os.path.exists(tmpname):
        os.unlink(tmpname)
    raise

print(f"APPENDED: @import line after line {last_import_idx + 1} in CLAUDE.md")
PY

if ! grep -qF '@import .claude/rules/main-thread-orchestrator.md' CLAUDE.md 2>/dev/null; then
  printf "NOTE: @import was not added (likely manual-review path). See python output above.\n"
  exit 0
fi
printf "VERIFIED: CLAUDE.md imports .claude/rules/main-thread-orchestrator.md\n"
```

---

### Step 6 — Advance `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import os
import tempfile
from datetime import datetime, timezone

STATE_FILE = ".claude/bootstrap-state.json"
with open(STATE_FILE, "r", encoding="utf-8") as f:
    state = json.load(f)

applied = state.get("applied", [])
already = any(
    (isinstance(a, dict) and a.get("id") == "036") or a == "036"
    for a in applied
)
if already:
    print("SKIP: 036 already in applied[]")
else:
    applied.append({
        "id": "036",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "Main thread orchestrator doctrine — install .claude/rules/main-thread-orchestrator.md (Tier 0-3 + quick-fix carve-out + investigation escalation ladder), install .claude/hooks/orchestrator-nudge.sh advisory PreToolUse hook, wire PreToolUse matcher in settings.json, append @import line to CLAUDE.md"
    })
    state["applied"] = applied
    state["last_migration"] = "036"
    # Atomic write: temp-file-then-rename. Prevents partial-write corruption on
    # mid-write crash. Critical for bootstrap-state.json — a truncated state
    # file would make /migrate-bootstrap re-run every migration on next launch.
    target_dir = os.path.dirname(os.path.abspath(STATE_FILE))
    fd, tmpname = tempfile.mkstemp(prefix=".bootstrap-state.", suffix=".json.tmp", dir=target_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump(state, tmp, indent=2)
            tmp.write("\n")
        os.replace(tmpname, STATE_FILE)
    except Exception:
        if os.path.exists(tmpname):
            os.unlink(tmpname)
        raise
    print("ADVANCED: bootstrap-state.json last_migration=036")
PY
```

---

## Rules for migration scripts

- **Sentinel-first idempotency** — every mutating step checks its sentinel first (rule-file canonical header, hook first-line comment, `orchestrator-nudge.sh` substring in settings.json, `@import` line in CLAUDE.md, `036` in `applied[]`) and exits 0 with `SKIP:` when already applied. Running twice is safe.
- **Fresh-shell-safe state passing** — `/tmp/mig036-state` is the only shared state between steps. Step 1 writes, later steps only read.
- **JSONC guard on settings.json** — if the settings.json file contains `//` comments, Step 4 aborts with a manual-patch message rather than silently stripping them via python `json.load`. Same concern applied to migration 025 TaskCompleted merge — preserved here.
- **Manual-review fallback on CLAUDE.md** — if CLAUDE.md has no `@import` block at all (hand-edited variant without any imports), Step 5 prints a MANUAL-REVIEW report and exits 0. Never guess at placement, never fail-hard.
- **No project-type carve-out in the hook** — the hook fires uniformly in every project, including the bootstrap repo itself. Main in the bootstrap repo is subject to the same tier discipline: dispatch `proj-code-writer-markdown` for `modules/` / `migrations/` / `templates/` edits beyond the quick-fix carve-out, dispatch `proj-quick-check` / `proj-researcher` for investigation. The bootstrap repo dogfoods its own doctrine.
- **Atomic writes via temp-file-then-rename** — Step 4 (settings.json), Step 5 (CLAUDE.md), Step 6 (bootstrap-state.json) each write via `tempfile.mkstemp` + `os.replace` rather than a direct `open("w")`. Prevents partial-write corruption on mid-write crash (OOM, SIGKILL, disk-full). `os.replace` is atomic on POSIX + Windows within the same filesystem.
- **Smoke-test sentinel gap closed in Step 3** — if Step 3 writes the hook file but any subsequent smoke test fails, the `fail_and_clean` helper `rm -f`s the hook file before exiting non-zero. This prevents a rerun from SKIP-ing Step 3 (via the first-line-comment sentinel) while the hook is still broken; the sentinel fails on next run and Step 3 cleanly re-installs.
- **Additive only** — no destructive rewrites. New file, new hook, merged settings entry, appended CLAUDE.md line. Rollback via `git checkout HEAD --` restores the pre-migration state byte-for-byte.
- **Python heredoc uses triple-quoted `"""..."""`** — the canonical rule file text contains backticks and emdashes but no triple-quote sequence, so `"""..."""` is safe. The heredoc is opened with `<<'PY'` (single-quoted) to preserve unicode characters exactly.
- **Hook content heredoc uses `<<'HOOK_EOF'`** — single-quoted to preserve `$TOOL_NAME`, `$INPUT` as literal text. ASCII-only inside the hook string (arrows written as `->`, `<=` instead of `≤`) so the heredoc survives any MINGW64 / CP-1252 re-encoding edge cases. The rule file itself keeps the unicode characters because it's read via a Python heredoc that we control end-to-end.

---

## Verify

```bash
# Final verification — every check must exit 0 on success

# 1. Rule file installed with canonical header
grep -qF '# Main Thread Orchestrator Doctrine' .claude/rules/main-thread-orchestrator.md \
  && printf "VERIFY 1: rule file header OK\n"

# 2. Rule file contains all five major sections
for section in '## Rule' '## Scope' '## Tiers' '## Quick-Fix Carve-Out' '## Investigation Escalation Ladder' '## Enforcement'; do
  grep -qF "$section" .claude/rules/main-thread-orchestrator.md \
    || { printf "FAIL: rule file missing section: %s\n" "$section"; exit 1; }
done
printf "VERIFY 2: rule file sections OK\n"

# 3. Hook script installed and syntax-valid
[[ -x .claude/hooks/orchestrator-nudge.sh ]] \
  && bash -n .claude/hooks/orchestrator-nudge.sh \
  && printf "VERIFY 3: hook script executable + syntax-valid\n"

# 4. Hook smoke tests — Edit
SMOKE_EDIT=$(printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"x.md"}}' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
printf '%s' "$SMOKE_EDIT" | grep -qF 'carve-out' \
  && printf "VERIFY 4a: Edit smoke test OK\n"

# 5. Hook smoke tests — Grep
SMOKE_GREP=$(printf '%s' '{"tool_name":"Grep","tool_input":{"pattern":"foo"}}' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
printf '%s' "$SMOKE_GREP" | grep -qF 'proj-quick-check' \
  && printf "VERIFY 4b: Grep smoke test OK\n"

# 6. Hook smoke tests — Read (Tier 1, no nudge)
SMOKE_READ=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"x.md"}}' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
[[ -z "$SMOKE_READ" ]] && printf "VERIFY 4c: Read smoke test OK (no nudge for Tier 1)\n"

# 7. Hook smoke tests — parse error (fail-open)
SMOKE_BAD=$(printf 'not json' | bash .claude/hooks/orchestrator-nudge.sh 2>&1 >/dev/null || true)
[[ -z "$SMOKE_BAD" ]] && printf "VERIFY 4d: parse-error fail-open OK\n"

# 8. settings.json valid + wires orchestrator-nudge
python3 -c 'import json; json.load(open(".claude/settings.json"))' \
  && grep -qF 'orchestrator-nudge.sh' .claude/settings.json \
  && printf "VERIFY 5: settings.json valid + wires orchestrator-nudge\n"

# 9. CLAUDE.md imports the rule (may be MANUAL-REVIEW path — check but don't fail)
if grep -qF '@import .claude/rules/main-thread-orchestrator.md' CLAUDE.md 2>/dev/null; then
  printf "VERIFY 6: CLAUDE.md imports main-thread-orchestrator.md\n"
else
  printf "VERIFY 6: CLAUDE.md does NOT import main-thread-orchestrator.md — may be MANUAL-REVIEW path; check Step 5 output\n"
fi

# 10. bootstrap-state.json advanced
python3 -c '
import json
s = json.load(open(".claude/bootstrap-state.json"))
assert s["last_migration"] == "036", f"last_migration={s[\"last_migration\"]}, expected 036"
assert any((isinstance(a, dict) and a.get("id") == "036") or a == "036" for a in s.get("applied", [])), "036 missing from applied[]"
print("VERIFY 7: bootstrap-state.json advanced to 036")
'
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"036"`
- append `{ "id": "036", "applied_at": "{ISO8601}", "description": "Main thread orchestrator doctrine — install .claude/rules/main-thread-orchestrator.md + .claude/hooks/orchestrator-nudge.sh + settings.json PreToolUse wiring + CLAUDE.md @import" }` to `applied[]`

---

## Post-Apply

After this migration runs successfully, the new doctrine is loaded into every main-thread context via three paths:

1. **CLAUDE.md `@import`** — the doctrine rule file is always loaded on main thread via the project's CLAUDE.md memory system.
2. **Advisory PreToolUse hook** — on every `Edit|Write|MultiEdit|NotebookEdit|Grep|Glob` call from main, the hook emits a short stderr reminder that lands in the next-turn context. The reminder is advisory only — it never blocks — and the orchestrator reads it + decides whether the carve-out applies.
3. **Review catch** — `/review` is aware of the tier structure via the rule file (force-reads it through STEP 0 propagation if the reviewer's force-read list is updated; even without that, CLAUDE.md @import gets it into main context at review time).

The orchestrator doctrine takes effect immediately on the next main-thread tool call or session start that reads the updated CLAUDE.md — no restart required. Sub-agents do NOT need to behave differently because the rule is for main; the hook still fires on sub-agent tool calls (Claude Code hooks are project-wide, not main-only), but the reminder text explicitly says "sub-agents: this nudge targets main, ignore" so sub-agents read + dismiss it without behavior change. Sub-agent stderr pollution is bounded: at most one stderr line per matched tool call per sub-agent, acceptable until a future migration adds sub-agent context detection.

**SGAP-1 Post-Apply note (self-governance applicability).** If this migration is being run against the bootstrap repo itself (via `/migrate-bootstrap` targeting the bootstrap repo's own `.claude/`), the bootstrap repo's own `.claude/rules/main-thread-orchestrator.md` + `.claude/hooks/orchestrator-nudge.sh` + `.claude/settings.json` entry will be installed in place. This is the intended behavior for the bootstrap repo's self-governance workflow — the bootstrap repo dogfoods its own migrations. The hook fires uniformly in the bootstrap repo: main-thread Edits to `modules/` / `migrations/` / `templates/` / `.claude/rules/` receive the same nudge as any client project. The bootstrap repo is not exempt from its own doctrine — main dispatches `proj-code-writer-markdown` for non-carve-out edits and `proj-quick-check` / `proj-researcher` for investigation, same as any client project. The `CLAUDE.md` `NEVER write to this repo's .claude/ as implementation work` rule still holds: `.claude/` is generated output, updated via `modules/` + `/migrate-bootstrap`, never by direct edit.

---

## Rollback

Not rollback-able via migration runner. Restore from git if needed:

```bash
# Removes the installed rule file + hook + settings.json entry + CLAUDE.md @import + state advance
git checkout HEAD -- .claude/rules/main-thread-orchestrator.md .claude/hooks/orchestrator-nudge.sh .claude/settings.json CLAUDE.md .claude/bootstrap-state.json 2>/dev/null || true
# If any of those files did not exist before this migration, they may now be untracked — remove manually:
[[ -f .claude/rules/main-thread-orchestrator.md ]] && rm -i .claude/rules/main-thread-orchestrator.md
[[ -f .claude/hooks/orchestrator-nudge.sh ]] && rm -i .claude/hooks/orchestrator-nudge.sh
```

If the project's `.claude/` directory is gitignored (companion strategy), restore from the companion repo under `~/.claude-configs/{project}/` instead:

```bash
# Companion restore — from ~/.claude-configs/{project}/
# cp ~/.claude-configs/{project}/.claude/rules/main-thread-orchestrator.md .claude/rules/ 2>/dev/null || rm -i .claude/rules/main-thread-orchestrator.md
# cp ~/.claude-configs/{project}/.claude/hooks/orchestrator-nudge.sh .claude/hooks/ 2>/dev/null || rm -i .claude/hooks/orchestrator-nudge.sh
# cp ~/.claude-configs/{project}/.claude/settings.json .claude/settings.json
# cp ~/.claude-configs/{project}/CLAUDE.md CLAUDE.md
# cp ~/.claude-configs/{project}/.claude/bootstrap-state.json .claude/bootstrap-state.json
```

Rollback is fully reversible — additive-only changes, no data migration, no schema changes, no external state.
