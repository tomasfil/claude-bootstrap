# Migration 032 — MCP Freshness Discipline + Grep Ban + Transparent Fallback

> Append 5 sections to `.claude/rules/mcp-routing.md` (CMM Freshness pre-flight, Grep Ban on indexed projects, Permission-Seeking Ban, Project Slug Convention, Transparent Fallback) + remove the redundant `cmm project key = full path` bullet from `## Gotchas` (now promoted to its own section). Motivated by field observation of Grep-first-on-named-symbol and permission-seeking-on-stale-index anti-patterns.

---

## Metadata

```yaml
id: "032"
breaking: false
affects: [rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"032"`
- `breaking`: `false` — additive content merge + one-line delete via exact-string match; existing sections untouched.
- `affects`: `[rules]` — only `.claude/rules/mcp-routing.md` (and `.claude/bootstrap-state.json` for state advance).
- `requires_mcp_json`: `false` — the new sections describe MCP discipline but apply universally; non-MCP projects read them as dormant guidance (same pattern as the Lead-With Order / Action→Tool sections from 031).
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the `.claude/rules/` layout supported by this migration.

---

## Problem

Two field-observed failure modes exposed recurring MCP anti-patterns that the existing `.claude/rules/mcp-routing.md` described but did not enforce:

1. **Grep-first discovery on a named symbol in an indexed project.** A recent downstream session hunting a C# service registration error used `Grep` to find the offending type name and then `Read` to inspect the DI wiring file, instead of `cmm.search_graph(name_pattern=<TypeName>)` + `cmm.get_code_snippet(<qualified_name>)`. Named-type lookup on an indexed project is the graph's purpose — `Grep` returned text matches with no structural context, no callers, no cross-reference edges, and silently missed occurrences that a `search_graph` label query would have caught. The routing rule existed but was descriptive, not enforcing: it did not explicitly forbid the anti-pattern, so the body-prose precedence on `Grep`/`Read`/`Glob` examples later in agent files won by default.

2. **Permission-seeking on a stale cmm index.** A second session correctly detected that a cmm project was stale (nodeCount far below the live source size) but then asked the user "want me to reindex, or continue with Grep+Read?" instead of silently running `cmm.detect_changes` → `cmm.index_repository` → retry. After the user manually triggered the reindex, the graph grew roughly 8x, confirming the staleness hypothesis — but the permission round-trip cost a conversational turn and broke flow. Per `max-quality.md` §6 *No Hedging*: a stale index on a running MCP server is a solvable blocker; solving it is not a permission-gated action.

The root cause behind both failures is a property of the cmm server's startup behaviour: the server does not auto-reindex on MCP startup — it loads the last on-disk graph and serves it regardless of source drift. Client-side pre-flight (`cmm.list_projects` + `cmm.detect_changes` + optional `cmm.index_repository`) is the only freshness guarantee available to Claude. Therefore the rule file must (a) require the pre-flight on the first cmm tool call of a session, (b) ban `Grep` on named symbols when the graph is available and fresh, (c) forbid permission-seeking on the solvable staleness path, (d) document the path-slug project-naming convention explicitly (so `project not found` errors become a lookup step via `list_projects`, not a fall-through to `Grep`), and (e) require transparent fallback disclosure whenever a legitimate MCP→text-search degradation occurs (so the user can judge confidence on the answer).

Migration 032 makes the rule enforcing instead of descriptive by appending 5 new first-class sections to `.claude/rules/mcp-routing.md` and promoting the previously-buried `cmm project key = full path` bullet from `## Gotchas` to its own `## Project Slug Convention` section.

---

## Changes

1. **Appends** 5 new sections to `.claude/rules/mcp-routing.md`: `## CMM Freshness`, `## Grep Ban`, `## Permission-Seeking Ban`, `## Project Slug Convention`, `## Transparent Fallback`. Append position: before `## Decision Shortcuts` if that header is present, otherwise at the end of the file.
2. **Removes** the redundant `- cmm project key = full path with \`-\` instead of \`/\` ...` bullet from the `## Gotchas` section (the convention is now a first-class section).
3. **Advances** `.claude/bootstrap-state.json` → `last_migration: "032"` + appends entry to `applied[]`.

Idempotency: Step 2 grep-checks `^## CMM Freshness` as the sentinel for "already applied"; Step 3 grep-checks for the `cmm project key = full path` literal before attempting the delete. Running twice is safe — both content steps print `SKIP` and exit 0, and Step 4 detects 032 already in `applied[]` and skips.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/rules/mcp-routing.md" ]] || { printf "ERROR: .claude/rules/mcp-routing.md missing — run migration 031 or full bootstrap first\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Detect current state

Write detection results to `/tmp/mig032-state` so subsequent bash blocks (each a fresh shell) can source it.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig032-state"
HAS_CMM_FRESHNESS=""
HAS_STALE_GOTCHA=""

if grep -q '^## CMM Freshness' .claude/rules/mcp-routing.md 2>/dev/null; then
  HAS_CMM_FRESHNESS="yes"
fi
if grep -Fq "cmm project key = full path" .claude/rules/mcp-routing.md 2>/dev/null; then
  HAS_STALE_GOTCHA="yes"
fi

{
  printf 'HAS_CMM_FRESHNESS=%q\n' "$HAS_CMM_FRESHNESS"
  printf 'HAS_STALE_GOTCHA=%q\n' "$HAS_STALE_GOTCHA"
} > "$STATE_FILE"

printf "STATE: HAS_CMM_FRESHNESS=%s HAS_STALE_GOTCHA=%s\n" \
  "${HAS_CMM_FRESHNESS:-no}" "${HAS_STALE_GOTCHA:-no}"
```

---

### Step 2 — Append 5 new sections (idempotent)

Branch on `HAS_CMM_FRESHNESS`:
- `HAS_CMM_FRESHNESS=yes` → SKIP (already applied on a previous run).
- Otherwise → read `mcp-routing.md`, insert the 5-section block before `## Decision Shortcuts` via Python `split('## Decision Shortcuts', 1)`; if that header is absent, append the block to the end with a blank-line separator.

The 5-section block is embedded verbatim in a Python raw-string heredoc (no 3-space indent — that indent was a modules/02 heredoc artifact). After the write, the step verifies with `grep -q '^## CMM Freshness' .claude/rules/mcp-routing.md` → error if not found.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig032-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig032-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${HAS_CMM_FRESHNESS:-}" ]]; then
  printf "SKIP: mcp-routing.md already contains '## CMM Freshness' section — Step 2 already applied\n"
  exit 0
fi

python3 - <<'PY'
canonical = r"""## CMM Freshness (pre-flight when codebase-memory-mcp present)
Before symbol exploration on an indexed project:
1. First cmm tool call this session → `cmm.list_projects` → verify target project exists + read `nodeCount`
2. Stale heuristic: `nodeCount < 200` on a non-trivial repo OR `cmm.detect_changes` reports drift → treat as stale
3. Stale detected → run `cmm.detect_changes` → `cmm.index_repository` → retry original query. **NO permission-seek** (per `max-quality.md` §6 — solvable blocker, resolve silently)
4. Fresh index + 0 hits on a named symbol → THEN serena / Grep fallback is justified
Note: cmm server does NOT auto-reindex on MCP startup; it loads the last on-disk graph. Client-side pre-flight is the only freshness guarantee.

## Grep Ban (indexed projects)
Grep / Glob on a **named** type / class / function / method / interface in an indexed project = RULE VIOLATION unless BOTH conditions hold:
- cmm graph confirmed fresh this session (list_projects check passed OR index_repository ran this session), AND
- `cmm.search_graph(name_pattern=<Name>)` returned 0 hits on the fresh graph
Exempt (text search is correct): literal strings in non-code (logs, config values, README prose, error messages, commit messages), raw reads of known file paths, files outside the indexed source tree.
Rationale: Grep bypasses the cross-reference graph, returns no structural context (no callers, callees, inheritance), costs more tokens on large result sets, silently misses renamed/reformatted occurrences that `search_graph` catches by label.

## Permission-Seeking Ban
Never ask the user "reindex or fall back to grep?" — a stale index on a running MCP server is a **solvable blocker**. Run `cmm.detect_changes` → `cmm.index_repository` → retry, silently. Reindex cost is seconds to ~1 minute cold build; a permission round-trip costs user attention and breaks flow. Per `max-quality.md` §6: *if the task is solvable, solve it*.

## Project Slug Convention
cmm indexes projects by **path-slug**: the project's full absolute path with `/` and `\` replaced by `-` (e.g. `C-Users-Alice-src-MyProject`), NOT the bare folder name. If `cmm.search_graph` returns "project not found":
1. Call `mcp__codebase-memory-mcp__list_projects` → get the full slug list
2. Match the target by suffix (e.g. `*-MyProject`)
3. Use the full slug in every subsequent cmm call this session
This is a naming convention of the cmm server, not a bug. `list_projects` is the single resolver.

## Transparent Fallback (when MCP path fails)
When you DO fall back from an MCP path to Grep / Glob / Read / serena text search, state it **explicitly** in the next user-facing message. The user must know which tool class served the answer so they can calibrate confidence. Format:
`MCP→fallback: {what was tried} → {why it failed} → {fallback path taken}`
Examples:
- `cmm.search_graph(FooService) on fresh 772-node graph → 0 hits → serena.find_symbol fallback`
- `cmm.get_code_snippet(Foo.Bar) → "symbol not in graph" after reindex → Read fallback on known path`
- `cmm server unreachable (connection refused) → Grep fallback, reduced confidence`
If the MCP path is genuinely **unsolvable** (server down, project not indexable on this platform, known-broken tool on this repo per Gotchas section) → state it is unsolvable + the specific reason. Never silently degrade. Max-quality discipline still applies to fallback paths — completeness, verification, no elision — but the tool-class disclosure is mandatory.
"""

with open('.claude/rules/mcp-routing.md') as f:
    existing = f.read()

parts = existing.split('## Decision Shortcuts', 1)
if len(parts) == 2:
    before, after = parts
    # Ensure exactly one blank line between the appended block and the Decision Shortcuts header
    new_text = before.rstrip() + '\n\n' + canonical + '\n## Decision Shortcuts' + after
    mode = "inserted-before-decision-shortcuts"
else:
    new_text = existing.rstrip() + '\n\n' + canonical
    mode = "appended-at-end"

with open('.claude/rules/mcp-routing.md', 'w') as f:
    f.write(new_text)

print(f"APPENDED: 5 sections ({mode}) → .claude/rules/mcp-routing.md")
PY

if ! grep -q '^## CMM Freshness' .claude/rules/mcp-routing.md; then
  printf "ERROR: append verification failed — mcp-routing.md does not contain '## CMM Freshness' after Step 2\n"
  exit 1
fi
printf "VERIFIED: mcp-routing.md contains '## CMM Freshness' section\n"
```

---

### Step 3 — Remove redundant Gotchas bullet (idempotent)

Branch on `HAS_STALE_GOTCHA`:
- `HAS_STALE_GOTCHA=""` (not set) → SKIP (already removed on a previous run, or never present).
- Otherwise → read `mcp-routing.md`, use Python exact-string `replace()` to remove the full bullet line (leading `- ` + trailing newline). If the exact-match produces no change, print `NO-OP: bullet wording did not match` and exit 0 (non-fatal).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig032-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig032-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -z "${HAS_STALE_GOTCHA:-}" ]]; then
  printf "SKIP: no 'cmm project key = full path' bullet present — Step 3 already applied or never needed\n"
  exit 0
fi

python3 - <<'PY'
target = "- cmm project key = full path with `-` instead of `/` (e.g. `C-Users-Alice-src-MyProj`), not the bare folder name. If `search_graph` returns \"project not found\", try `mcp__codebase-memory-mcp__list_projects` first.\n"

with open('.claude/rules/mcp-routing.md') as f:
    text = f.read()

new_text = text.replace(target, "")
if new_text == text:
    print("NO-OP: bullet wording did not match — leave file untouched (project may have a hand-edited variant; manual review recommended)")
else:
    with open('.claude/rules/mcp-routing.md', 'w') as f:
        f.write(new_text)
    print("REMOVED: 'cmm project key = full path' bullet from .claude/rules/mcp-routing.md")
PY
```

---

### Step 4 — Advance bootstrap-state.json

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
from datetime import datetime, timezone

STATE_FILE = ".claude/bootstrap-state.json"
with open(STATE_FILE) as f:
    state = json.load(f)

applied = state.get("applied", [])
already = any(
    (isinstance(a, dict) and a.get("id") == "032") or a == "032"
    for a in applied
)
if already:
    print("SKIP: 032 already in applied[]")
else:
    applied.append({
        "id": "032",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "MCP freshness discipline — cmm pre-flight + grep ban + permission-seek ban + project slug convention + transparent fallback"
    })
    state["applied"] = applied
    state["last_migration"] = "032"
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    print("ADVANCED: bootstrap-state.json last_migration=032")
PY
```

---

### Rules for migration scripts

- **Exact-string `replace()` only** — no regex `.*` patterns in Step 3 bullet removal. NO-OP on anchor drift, reported to stdout, non-fatal exit.
- **Append-only content merge** — Step 2 never overwrites existing `mcp-routing.md` content; it only inserts a new block before `## Decision Shortcuts` (or appends to the end if that header is absent). Existing sections are preserved byte-for-byte.
- **Idempotent** — every step checks a sentinel before acting (Step 2: `^## CMM Freshness`; Step 3: `cmm project key = full path` literal; Step 4: `032` in `applied[]`). Re-running prints `SKIP` and exits 0.
- **Read-before-write** — every file opened, read into a Python string, modified, then written. No in-place clobber, no `sed -i`.
- **MINGW64-safe** — no `sed -i`, no process substitution, no `readarray`. Uses `python3` for all string manipulations and JSON edits.
- **Abort on error** — `set -euo pipefail` at the top of every bash block. Failed prior steps do NOT advance `bootstrap-state.json` — Step 4 is separate and last.
- **Glob-free** — this migration touches one rule file by literal path; there are no agent glob loops to worry about.

### Required: register in migrations/index.json

Every migration file MUST have a matching entry in `migrations/index.json`. Entry is added as part of this change set — the main thread verifies.

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

# (a) CMM Freshness section present
if grep -q '^## CMM Freshness' .claude/rules/mcp-routing.md; then
  printf "OK: mcp-routing.md has '## CMM Freshness' section\n"
else
  printf "FAIL: mcp-routing.md missing '## CMM Freshness' section\n"
  FAIL=1
fi

# (b) Grep Ban section present
if grep -q '^## Grep Ban' .claude/rules/mcp-routing.md; then
  printf "OK: mcp-routing.md has '## Grep Ban' section\n"
else
  printf "FAIL: mcp-routing.md missing '## Grep Ban' section\n"
  FAIL=1
fi

# (c) Transparent Fallback section present
if grep -q '^## Transparent Fallback' .claude/rules/mcp-routing.md; then
  printf "OK: mcp-routing.md has '## Transparent Fallback' section\n"
else
  printf "FAIL: mcp-routing.md missing '## Transparent Fallback' section\n"
  FAIL=1
fi

# (d) redundant Gotchas bullet removed
if grep -Fq "cmm project key = full path" .claude/rules/mcp-routing.md; then
  printf "FAIL: redundant 'cmm project key = full path' bullet still present in Gotchas\n"
  FAIL=1
else
  printf "OK: redundant Gotchas bullet removed\n"
fi

# (e) bootstrap-state.json lists 032
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_032 = any((isinstance(a, dict) and a.get('id') == '032') or a == '032' for a in applied)
last = state.get('last_migration', '')
fail = 0
if not has_032:
    print("FAIL: 032 not in applied[]")
    fail = 1
else:
    print("OK: 032 in applied[]")
if last != '032':
    print(f"FAIL: last_migration is '{last}', expected '032'")
    fail = 1
else:
    print("OK: last_migration=032")
sys.exit(fail)
PY
[[ $? -eq 0 ]] || FAIL=1

if [[ $FAIL -eq 0 ]]; then
  printf "\nMigration 032 complete — all checks passed\n"
else
  printf "\nMigration 032 FAILED — %d check(s) above need attention\n" "$FAIL"
  exit 1
fi
```

Failure of any verify step → migration is not complete. Safe to re-run after fixing (all steps idempotent).

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"032"`
- append `{ "id": "032", "applied_at": "<ISO8601>", "description": "MCP freshness discipline — cmm pre-flight + grep ban + permission-seek ban + project slug convention + transparent fallback" }` to `applied[]`

---

## Rollback

Not rollback-able via migration runner. Restore from git if needed:

```bash
# Restore mcp-routing.md and bootstrap-state.json from git
git checkout HEAD -- .claude/rules/mcp-routing.md .claude/bootstrap-state.json
```

If the project's `.claude/` directory is gitignored (companion strategy), restore from the companion repo under `~/.claude-configs/{project}/` instead:

```bash
# Companion restore — from ~/.claude-configs/{project}/
# cp ~/.claude-configs/{project}/.claude/rules/mcp-routing.md .claude/rules/mcp-routing.md
# cp ~/.claude-configs/{project}/.claude/bootstrap-state.json .claude/bootstrap-state.json
```
