# Migration 035 — Tool Call Hygiene

> Append a new `## Tool Call Hygiene` section to `.claude/rules/token-efficiency.md` that codifies two call-site token-waste patterns observed in field session retrospectives. First: `cmm.search_graph(query=…)` in BM25 mode must always pass `limit ≤10` because unbounded `query=` calls return 100–500+ hits at roughly 10–15k tokens each and single-handedly blow a session's context budget; `name_pattern=` exact-match lookups are exempt because they are structurally bounded to small result sets. Second: large log, output, and fixture files must be pre-sized with `wc -l` and then read via scoped mechanisms — `Read offset=… limit=…`, shell `tail`, `head`, or `sed -n` — and NEVER via full-file `Read`, because even a failed oversized `Read` echoes its error payload into context. The motivating retrospective: one session issued two unbounded `cmm.search_graph(query=…)` calls returning 405 and 431 hits respectively and consumed roughly 25–30k tokens, then full-file read a 15k-token test output log, collectively accounting for roughly 40k of the session budget. The existing sections in `.claude/rules/token-efficiency.md` cover content compression for instructions, specs, and memory files — they do not cover call-site discipline. This migration closes the gap with a new section sitting alongside Scope, Rules, Why, and Output Carve-Out.

---

## Metadata

```yaml
id: "035"
breaking: false
affects: [rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"035"`
- `breaking`: `false` — additive append of one new `## Tool Call Hygiene` section to `.claude/rules/token-efficiency.md` (inserted before the existing `## Output Carve-Out` section via split-and-rejoin, falling back to end-of-file append if the anchor is absent; no existing line rewritten).
- `affects`: `[rules]` — patches one rule file (`.claude/rules/token-efficiency.md`) and advances `.claude/bootstrap-state.json` → `last_migration: "035"`.
- `requires_mcp_json`: `false` — the `cmm.search_graph` bullet is harmless inert reference text on projects without `codebase-memory-mcp` registered; the rule file is read by every agent regardless of MCP registration state, and the bullet is dormant guidance when the named tool is not reachable in the current session.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap release that ships `.claude/rules/token-efficiency.md`, which this migration patches.

---

## Problem

Two token-waste patterns at the tool call site — not at the content layer — were observed in a field session retrospective and dwarfed every other context cost in that session combined. Both patterns slip past the existing `token-efficiency.md` coverage because the existing sections govern *content compression* (how to write an instruction, rule, spec, or memory file), not *call-site discipline* (how to invoke a tool without blowing the session's context budget).

### Pattern 1 — `cmm.search_graph(query=…)` BM25 mode without `limit`

`codebase-memory-mcp`'s `search_graph` tool operates in two modes:

- `name_pattern=` — exact-match or glob lookup against indexed symbol names. Structurally bounded to small result sets (typically 1–20 hits for a well-chosen pattern).
- `query=` — BM25 full-text search across graph nodes (symbols, doc strings, file paths, comments). BM25 has no inherent result-size ceiling and returns everything above the relevance threshold, sorted by score.

When `query=` is called without `limit`, the server returns the full ranked set — frequently 100–500+ hits for any non-trivial query against a real codebase. Each hit carries roughly 10–15k tokens of payload (symbol body, surrounding context, cross-reference metadata). A single unbounded `query=` call can therefore consume 1M+ tokens of return payload, of which only the first 10–20 hits are ever useful for the task at hand.

**Observed numbers from the motivating session.** Two unbounded `cmm.search_graph(query=…)` calls returned 405 hits and 431 hits respectively, and together consumed roughly 25–30k tokens of the session's context budget (truncated at the transport layer, which is why the hit count was recorded rather than the full payload). A `limit=10` on each call would have reduced the total to roughly 1.5–3k tokens — a 10–20× reduction from a single-character parameter change.

**Fix.** Always pass `limit ≤10` on `cmm.search_graph(query=…)` calls. The `name_pattern=` mode is exempt because it is already structurally bounded; passing `limit` on a `name_pattern=` call is harmless but not required.

### Pattern 2 — Full-file `Read` on large log / output / fixture files

Large log, output, and fixture files — CI build logs, test run outputs, profiling dumps, captured network traces, serialized fixtures — routinely exceed 10k–20k tokens. A full-file `Read` on such a file sinks the entire content into the session context, usually to consume a single error message, a single failing test, or a single slow span that lives on one line out of hundreds.

**Observed numbers from the motivating session.** A single test-output log was read in full, contributing roughly 15k tokens to the session context. Only three lines were actually used to diagnose the failure. A `wc -l` pre-size followed by `tail -n 50` or a `Read offset=N limit=50` at the failing line would have reduced the cost to roughly 500 tokens — a 30× reduction.

**Secondary failure mode.** Even when a full-file `Read` fails because the file exceeds the tool's size limit, the error payload *itself* is echoed into context. The error message reports file size, line count, and often the first and last few lines of the file — not zero tokens, but a non-trivial fraction of what a scoped read would have cost. A failed full-file `Read` is therefore not a free retry: it already consumed context by the time the error surfaces.

**Fix.** Pre-size with `wc -l` (or an equivalent `ls -l` / `stat` for byte-size files) *before* reading any file that might be large. Then route the read through a scoped mechanism: `Read offset=… limit=…` for the primary file-reading tool, shell `tail` / `head` / `sed -n` / `awk 'NR>=M && NR<=N'` for shell-side scoping, or a grep + nearby-lines pattern when the file contains a known marker. Never full-file `Read` on an unsized log.

### Why this belongs in `token-efficiency.md`

The existing `token-efficiency.md` sections are scoped as follows:

- `## Scope` — lists which file types are subject to Claude-facing compression.
- `## NOT in scope` — lists human-facing files that should remain normal prose.
- `## Rules` — compression rules for writing instructions (strip articles, telegraphic form, symbols, merge short rules, imperative voice).
- `## Why` — token-savings rationale at the content layer.
- `## Output Carve-Out` — carves out generated implementation output from the compression rules.

Every section is about how to *write* an instruction, rule, or memory file such that the *stored content* is token-efficient. None of them govern how to *invoke a tool* such that the *returned payload* is token-efficient. The new `## Tool Call Hygiene` section closes that gap — it sits alongside the existing sections because the subject matter is token efficiency, but it applies at a different layer of the stack (call site, not content layer).

The two patterns could theoretically live in a separate rule file (`.claude/rules/tool-call-hygiene.md`) but that would fragment the rule set and make discovery harder. Placing them in `token-efficiency.md` means every agent that STEP-0-force-reads `token-efficiency.md` also gets the call-site rules for free — no additional force-read list edits, no additional CLAUDE.md `@import` edit, no coordination overhead with the agent template stack.

---

## Changes

1. **Appends** a new `## Tool Call Hygiene` section to `.claude/rules/token-efficiency.md`, inserted before the existing `## Output Carve-Out` section via Python `split('## Output Carve-Out', 1)`. If the `## Output Carve-Out` header is absent (hand-edited variant or future rule-file refactor that moved it), falls back to appending the new section at the end of the file with a blank-line separator. Same split-and-rejoin pattern as migration 034 Step 3. Sentinel-guarded idempotency on `^## Tool Call Hygiene`.
2. **Advances** `.claude/bootstrap-state.json` → `last_migration: "035"` + appends entry to `applied[]` with ISO8601 UTC timestamp and description.

Idempotency table:

| Step | Sentinel | Skip condition |
|---|---|---|
| 2 (rule) | `grep -q '^## Tool Call Hygiene' .claude/rules/token-efficiency.md` | Section already appended. |
| 3 (state) | `035` already in `applied[]` in `.claude/bootstrap-state.json` | State already advanced. |

Running twice is safe — every step prints `SKIP:` for the already-applied path and exits 0.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]]       || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/rules/token-efficiency.md" ]]  || { printf "ERROR: .claude/rules/token-efficiency.md missing — run full bootstrap first\n"; exit 1; }
command -v python3 >/dev/null 2>&1             || { printf "ERROR: python3 required\n"; exit 1; }
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Detect current state

Write detection result to `/tmp/mig035-state` so subsequent bash blocks (each a fresh shell) can source it.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig035-state"
HAS_SECTION=""

if grep -q '^## Tool Call Hygiene' .claude/rules/token-efficiency.md 2>/dev/null; then
  HAS_SECTION="yes"
fi

{
  printf 'HAS_SECTION=%q\n' "$HAS_SECTION"
} > "$STATE_FILE"

printf "STATE: HAS_SECTION=%s\n" "${HAS_SECTION:-no}"
```

---

### Step 2 — Append `## Tool Call Hygiene` section to `.claude/rules/token-efficiency.md`

Branch on `HAS_SECTION`:
- `HAS_SECTION=yes` → SKIP (section already present; sentinel header matches).
- Otherwise → read `token-efficiency.md`, insert the new section before `## Output Carve-Out` via Python `split('## Output Carve-Out', 1)`. If that header is absent, append the section to the end with a blank-line separator. Same pattern as migration 034 Step 3.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig035-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig035-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/rules/token-efficiency.md"

if [[ -n "${HAS_SECTION:-}" ]]; then
  printf "SKIP: %s already contains '## Tool Call Hygiene' section\n" "$TARGET"
  exit 0
fi

python3 - <<'PY'
canonical = """## Tool Call Hygiene
Token-efficiency violations at the tool call site — observed in field session retrospectives.
- `cmm.search_graph(query=…)` BM25 mode: ALWAYS pass `limit ≤10`. Unbounded `query=` returns 100–500+ hits × 10–15k tokens each = context-killer in one call. Exempt: `name_pattern=` exact-match lookups (structural, small result sets) — unbounded is fine there.
- Large log / output / fixture files: `wc -l` first → scoped read via `Read offset=… limit=…` or shell `tail` / `head` / `sed -n`. NEVER full-file `Read` on an unsized log. Failed oversized `Read` still echoes error payload into context — pre-size when uncertain.
"""

with open('.claude/rules/token-efficiency.md', 'r', encoding='utf-8') as f:
    existing = f.read()

parts = existing.split('## Output Carve-Out', 1)
if len(parts) == 2:
    before, after = parts
    new_text = before.rstrip() + '\n\n' + canonical + '\n## Output Carve-Out' + after
    mode = "inserted-before-output-carveout"
else:
    new_text = existing.rstrip() + '\n\n' + canonical
    mode = "appended-at-end"

with open('.claude/rules/token-efficiency.md', 'w', encoding='utf-8') as f:
    f.write(new_text)

print("APPENDED: Tool Call Hygiene section (" + mode + ") → .claude/rules/token-efficiency.md")
PY

if ! grep -q '^## Tool Call Hygiene' "$TARGET"; then
  printf "ERROR: append verification failed — %s does not contain '## Tool Call Hygiene' after Step 2\n" "$TARGET"
  exit 1
fi
printf "VERIFIED: %s contains '## Tool Call Hygiene' section\n" "$TARGET"
```

---

### Step 3 — Advance `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
from datetime import datetime, timezone

STATE_FILE = ".claude/bootstrap-state.json"
with open(STATE_FILE, "r", encoding="utf-8") as f:
    state = json.load(f)

applied = state.get("applied", [])
already = any(
    (isinstance(a, dict) and a.get("id") == "035") or a == "035"
    for a in applied
)
if already:
    print("SKIP: 035 already in applied[]")
else:
    applied.append({
        "id": "035",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "Tool call hygiene — append Tool Call Hygiene section to token-efficiency.md with cmm.search_graph query= limit ≤10 rule + large log scoped-read rule"
    })
    state["applied"] = applied
    state["last_migration"] = "035"
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    print("ADVANCED: bootstrap-state.json last_migration=035")
PY
```

---

## Rules for migration scripts

- **Sentinel-first idempotency** — every mutating step checks its sentinel first (`^## Tool Call Hygiene` header for the rule, `035` in `applied[]` for state) and exits 0 with `SKIP:` when already applied. Running twice is safe.
- **Fresh-shell-safe state passing** — `/tmp/mig035-state` is the only shared state between steps. Each step sources the file at top; Step 1 writes, later steps only read.
- **Split-and-rejoin anchor match** — Step 2 uses `split('## Output Carve-Out', 1)` for insertion. If the anchor is absent (hand-edited variant or future refactor), the step falls back to end-of-file append rather than failing hard. Mode is reported in the `APPENDED:` line so the operator can see which path ran.
- **Additive only** — no destructive rewrites. The new section is appended; no existing section is modified or removed. Rollback via `git checkout HEAD --` restores the pre-migration file byte-for-byte.
- **Python heredoc uses triple-quoted `"""..."""`** — the canonical section text contains backticks but no triple-quote sequence, so `"""..."""` is safe. The heredoc is opened with `<<'PY'` (single-quoted) to prevent shell expansion inside the Python body, preserving the unicode em-dashes (`—`) and ellipsis characters (`…`) exactly as written.

---

## Post-Apply

After this migration runs successfully, the new `## Tool Call Hygiene` section is loaded into every agent context via two paths: (1) the STEP 0 force-read list of every `proj-*` agent that cites `.claude/rules/token-efficiency.md`, and (2) the `CLAUDE.md` `@import .claude/rules/token-efficiency.md` directive if the project imports the rule from the project-root memory file. The new rules take effect immediately on the next agent dispatch or session start that reads the updated rule file — no restart required, no cache to flush, no downstream template regeneration needed. The next time an agent considers calling `cmm.search_graph(query=…)` or `Read` on an unsized log, the rule is in context and the expected discipline is visible.

**SGAP-1 Post-Apply note (self-governance applicability).** If this migration is being run against the bootstrap repo itself (via `/migrate-bootstrap` targeting the bootstrap repo's own `.claude/`), the bootstrap repo's own `.claude/rules/token-efficiency.md` will be updated in place. This is the intended behavior for the bootstrap repo's self-governance workflow — the bootstrap repo dogfoods its own migrations so that every rule change shipped to downstream projects is first validated against the bootstrap repo's own development workflow. The `CLAUDE.md` `NEVER write to this repo's .claude/ as implementation work` rule does not apply to `/migrate-bootstrap` runs because the migration is not implementation work — it is the canonical path for updating `.claude/` files from the `modules/` source of truth.

---

## Rollback

Not rollback-able via migration runner. Restore from git if needed:

```bash
git checkout HEAD -- .claude/rules/token-efficiency.md .claude/bootstrap-state.json
```

If the project's `.claude/` directory is gitignored (companion strategy), restore from the companion repo under `~/.claude-configs/{project}/` instead:

```bash
# Companion restore — from ~/.claude-configs/{project}/
# cp ~/.claude-configs/{project}/.claude/rules/token-efficiency.md .claude/rules/token-efficiency.md
# cp ~/.claude-configs/{project}/.claude/bootstrap-state.json .claude/bootstrap-state.json
```

Rollback is fully reversible — additive append only, no data migration, no schema changes, no external state.
