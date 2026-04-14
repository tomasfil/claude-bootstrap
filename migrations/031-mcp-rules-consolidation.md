# Migration 031 — Consolidate mcp-tool-routing.md into mcp-routing.md

> Merge the standalone `.claude/rules/mcp-tool-routing.md` (action→tool table) into `.claude/rules/mcp-routing.md`, delete the now-redundant file, strip its `@import` from `CLAUDE.md`, and patch every `proj-*` agent's STEP 0 force-read block + override prose to the single-clause form.

---

## Metadata

```yaml
id: "031"
breaking: false
affects: [rules, agents, CLAUDE.md, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"031"`
- `breaking`: `false` — no structural renames; agent bodies and rule files are updated in-place with exact-string substitutions. Projects that never ran migration 018 (no `mcp-tool-routing.md`, no two-clause prose) are handled: agent-prose patches print `NO-OP` for any file that does not match the 018-era patterns, and state advances normally.
- `affects`: `[rules, agents, CLAUDE.md, techniques]` — `.claude/rules/mcp-routing.md` (content merge), `.claude/rules/mcp-tool-routing.md` (deleted), `CLAUDE.md` (`@import` line removed), every `.claude/agents/proj-*.md` and sub-specialist globs (prose patch), `.claude/references/techniques/agent-design.md` (refreshed).
- `requires_mcp_json`: `false` — this migration runs everywhere. Projects without `.mcp.json` may still have a `mcp-tool-routing.md` file (if they ran migration 018 at a time when they had MCPs) or may not. Steps detect and skip appropriately. Agent prose patching runs on ALL projects regardless of MCP state — it is a pure string substitution that matches the OLD two-clause form and replaces it with the NEW single-clause form. Migration always advances state.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the `.claude/agents/`, `.claude/rules/` layout supported by this migration.

---

## Problem

Migration 018 split MCP concerns into two rule files:
- `.claude/rules/mcp-routing.md` — propagation rules (whether agents inherit MCP tools via `tools:` frontmatter).
- `.claude/rules/mcp-tool-routing.md` — action→tool routing table (which MCP tool to call for which code-discovery action).

The split was a minimal surgical patch at the time: `mcp-routing.md` already existed (added in migration 011) and covered only propagation; 018 added the action→tool table as a second file rather than extending the first. In practice, the split proved artifactual:

1. **Semantically, one rule owns both concerns.** Propagation (how tools reach agents) and routing (which tool for which action) are the same policy domain. Splitting them meant every agent had to reference two files in STEP 0 — a fragile two-bullet contract where either bullet could go stale independently.

2. **Manual consolidation in the field revealed a concrete failure mode**: when a project merges the two files by hand, the agents' STEP 0 force-read blocks still cite `mcp-tool-routing.md` (a file that no longer exists) alongside `mcp-routing.md`, and the override prose uses the two-clause form (`If mcp-routing.md is loaded … If mcp-tool-routing.md is loaded …`). The second clause is semantically dead — it references a deleted file. Any agent run after consolidation loads a non-existent rule reference and applies dead override logic. 13 agents per bootstrapped project are in this state.

3. **Bootstrap templates have already been updated** (companion batch applied before this migration): all 13 agent templates in `templates/agents/` have had their STEP 0 force-read blocks and override prose patched to the single-clause form; `modules/02-project-config.md` Step 3 item 5 now embeds the full merged `mcp-routing.md` content and Step 6 (conditional `mcp-tool-routing.md` generation) has been deleted. New bootstraps produce only `mcp-routing.md`. This migration is the client-project retrofit path.

Migration 031 reverses the content-level effects of migration 018 in already-bootstrapped projects: it merges the action→tool table back into `mcp-routing.md`, deletes the now-redundant `mcp-tool-routing.md`, strips the dead `@import` from `CLAUDE.md`, and patches every agent file in-place using exact-string Python substitutions.

---

## Changes

1. **Merges** action→tool content (Lead-With Order, Action→Tool table, Gotchas, Decision Shortcuts sections) from `.claude/rules/mcp-tool-routing.md` into `.claude/rules/mcp-routing.md` via Python section parser (append-only; skip if already merged — pre-merged field case).
2. **Deletes** `.claude/rules/mcp-tool-routing.md`.
3. **Strips** `@import .claude/rules/mcp-tool-routing.md` from `CLAUDE.md` via Python regex removal.
4. **Patches** every `.claude/agents/proj-*.md` (plus sub-specialists via globs for `code-writer-*.md` and `test-writer-*.md`) STEP 0 force-read block: removes the `mcp-tool-routing.md` bullet, rewords the `mcp-routing.md` bullet to mention "action→tool routing table".
5. **Patches** every agent's override prose paragraph: two-clause form (`If mcp-routing.md … If mcp-tool-routing.md …`) → single-clause form (`If mcp-routing.md … AND route code discovery …`).
6. **Patches** Section 2 "Before Writing (MANDATORY)" Pre-Work step in `.claude/agents/proj-code-writer-*.md` and `.claude/agents/proj-test-writer-*.md` (where present): rewrites the mcp-tool-routing.md reference to reference the consolidated mcp-routing.md action→tool table instead.
7. **Fetches** refreshed `techniques/agent-design.md` from the bootstrap repo → `.claude/references/techniques/agent-design.md` (client-project layout per `.claude/rules/general.md`; NOT `techniques/` at project root).
8. **Advances** `.claude/bootstrap-state.json` → `last_migration: "031"` + appends entry to `applied[]`.

Idempotency: every step detects the already-applied state via sentinel grep and skips with a `SKIP:` log line. Running twice is safe. The pre-merged case (project that already merged the two files by hand) is explicitly handled — Step 2 detects `## Action → Tool` already present in `mcp-routing.md` and skips content merge while still running Steps 3-8.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: no .claude/agents directory\n"; exit 1; }
[[ -d ".claude/rules" ]] || { printf "ERROR: no .claude/rules directory\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }

# Migration 018 must be applied — 031 reverses 018's file split.
# Projects that skipped 018 (pre-018 bootstrap, no mcp-tool-routing.md ever created) still
# pass this check IF 018 was auto-skipped with a state-advance. If 018 is genuinely absent,
# the content-merge step will detect no mcp-tool-routing.md and use the inline heredoc fallback.
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_018 = any(
    (isinstance(a, dict) and a.get('id') == '018') or a == '018'
    for a in applied
)
if not has_018:
    print("ERROR: migration 018 not applied — cannot apply 031 (consolidates what 018 created). Apply 018 first, then 031.")
    sys.exit(1)
print("OK: migration 018 present in applied[]")
PY
```

---

### Step 1 — Detect current state

Write detection results to `/tmp/mig031-state` so subsequent bash blocks (each a fresh shell) can source it.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig031-state"
HAS_TOOL_ROUTING=""
HAS_ROUTING=""
HAS_MERGED=""

[[ -f ".claude/rules/mcp-tool-routing.md" ]] && HAS_TOOL_ROUTING="yes"
[[ -f ".claude/rules/mcp-routing.md" ]] && HAS_ROUTING="yes"

if [[ -n "$HAS_ROUTING" ]] && grep -q '^## Action → Tool' .claude/rules/mcp-routing.md 2>/dev/null; then
  HAS_MERGED="yes"
fi

{
  printf 'HAS_TOOL_ROUTING=%q\n' "$HAS_TOOL_ROUTING"
  printf 'HAS_ROUTING=%q\n' "$HAS_ROUTING"
  printf 'HAS_MERGED=%q\n' "$HAS_MERGED"
} > "$STATE_FILE"

printf "STATE: HAS_TOOL_ROUTING=%s HAS_ROUTING=%s HAS_MERGED=%s\n" \
  "${HAS_TOOL_ROUTING:-no}" "${HAS_ROUTING:-no}" "${HAS_MERGED:-no}"
```

---

### Step 2 — Merge content into mcp-routing.md (append-only, idempotent)

Branch on state from Step 1:
- `HAS_MERGED=yes` → SKIP (pre-merged case: already consolidated manually or by prior migration run). Proceed to Step 3.
- `HAS_TOOL_ROUTING=yes` AND `HAS_ROUTING=yes` AND `HAS_MERGED=no` → extract four sections from `mcp-tool-routing.md` via Python section parser, append to `mcp-routing.md`.
- `HAS_TOOL_ROUTING=no` AND `HAS_ROUTING=yes` AND `HAS_MERGED=no` → `mcp-tool-routing.md` was never created (non-MCP project that ran 018 body-prose only) or was already deleted. Append canonical action-table content from inline heredoc.
- `HAS_ROUTING=no` → ERROR (should not happen on a bootstrapped project — `mcp-routing.md` is a Module 02 Step 3 mandatory rule file).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig031-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig031-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -z "${HAS_ROUTING:-}" ]]; then
  printf "ERROR: .claude/rules/mcp-routing.md not found — project does not appear to be bootstrapped correctly\n"
  exit 1
fi

if [[ -n "${HAS_MERGED:-}" ]]; then
  printf "SKIP: mcp-routing.md already contains '## Action → Tool' section — content merge not needed\n"
  exit 0
fi

if [[ -n "${HAS_TOOL_ROUTING:-}" ]]; then
  # Extract sections from mcp-tool-routing.md and append to mcp-routing.md
  python3 - <<'PY'
import re, sys

with open('.claude/rules/mcp-tool-routing.md') as f:
    source = f.read()

# Split on ## headers, collect target sections
sections = re.split(r'^(## .+)$', source, flags=re.MULTILINE)

# sections is: [preamble, "## Header1", "body1", "## Header2", "body2", ...]
# Build a dict of header -> full block (header + body)
TARGET_SECTIONS = {
    '## Lead-With Order',
    '## Action \u2192 Tool',
    '## Gotchas',
    '## Decision Shortcuts',
}

collected = []
i = 0
# First element is preamble (may contain override directive prose — collect it too
# only if it contains a recognizable override instruction line)
preamble = sections[0] if sections else ''
# Check if preamble has override directive content (e.g. "OVERRIDES" or "Policy OVERRIDES")
if 'OVERRIDES' in preamble and preamble.strip():
    collected.append(preamble.rstrip())

i = 1
while i < len(sections) - 1:
    header = sections[i]
    body = sections[i + 1]
    # Match any of the target section headers (exact or with trailing space)
    for target in TARGET_SECTIONS:
        if header.strip() == target.rstrip():
            collected.append(header + body.rstrip())
            break
    i += 2

if not collected:
    print("ERROR: no target sections (Lead-With Order / Action → Tool / Gotchas / Decision Shortcuts) found in mcp-tool-routing.md", file=sys.stderr)
    sys.exit(1)

with open('.claude/rules/mcp-routing.md') as f:
    existing = f.read()

append_block = '\n\n' + '\n\n'.join(collected)
with open('.claude/rules/mcp-routing.md', 'w') as f:
    f.write(existing.rstrip() + append_block + '\n')

print(f"APPENDED: {len(collected)} section(s) from mcp-tool-routing.md → mcp-routing.md")
PY

else
  # No mcp-tool-routing.md present — append canonical content from heredoc.
  # This is the same content now embedded in modules/02-project-config.md Step 3 item 5.
  printf "APPEND: mcp-tool-routing.md absent — appending canonical action-table content from inline heredoc\n"
  python3 - <<'PY'
canonical = r"""
## Lead-With Order (token-saving — applies when cmm + serena present)
1. `cmm.search_graph` + `cmm.query_graph` → compact discovery
2. `cmm.get_code_snippet` → once qualified name is known
3. `serena.find_referencing_symbols` → scoped via `relative_path` when callers needed
4. `serena.find_symbol` → for name-path precision

## Action → Tool
| Action | Tool |
|---|---|
| Find symbol by name | `cmm.search_graph(name_pattern, label)` |
| Read symbol source | `cmm.get_code_snippet(qualified_name)` |
| File overview | `serena.get_symbols_overview(path, depth=1)` — depth=1 mandatory |
| Find CALLERS | `serena.find_referencing_symbols` |
| Find CALLEES | `cmm.query_graph("MATCH (m:Method)-[:CALLS]->(t) WHERE m.name = $n RETURN t")` |
| Find subclasses | `cmm.query_graph` on `INHERITS` edges |
| Text/regex search | `serena.search_for_pattern` + `paths_include_glob` scope |
| Semantic concept search | `cmm.search_graph(semantic_query=[keywords])` |
| Graph schema | `cmm.get_graph_schema` |
| Edit: replace body | `serena.replace_symbol_body` |
| Edit: insert before/after | `serena.insert_before_symbol` / `insert_after_symbol` |
| Edit: rename | `serena.rename_symbol` |
| Edit: safe delete | `serena.safe_delete_symbol` |

## Gotchas
- `serena.get_symbols_overview` default `depth=0` → returns only Namespace. Always pass `depth=1`+.
- `serena.search_for_pattern` without `paths_include_glob` → thousands of tokens. Always scope.
- cmm is read-only — all mutations via serena edit tools.
- cmm's `trace_path` + `search_code` are known-broken on some projects — fall back to `query_graph` + `serena.search_for_pattern`.
- MCP tool schemas are DEFERRED in forked skill contexts — call `ToolSearch "select:<tool>"` first before invoking.
- cmm project key = full path with `-` instead of `/` (e.g. `C-Users-Alice-src-MyProj`), not the bare folder name. If `search_graph` returns "project not found", try `mcp__codebase-memory-mcp__list_projects` first.

## Decision Shortcuts
- "Who calls X?" → `serena.find_referencing_symbols`
- "What does X call?" → `cmm.query_graph` CALLS edges
- "Show me X's code" → `cmm.get_code_snippet`
- "Find classes like Y" → `cmm.search_graph(name_pattern, label="Class")`
- "Grep literal" → `serena.search_for_pattern` + glob scope
- "Rename / edit symbol" → serena edit tools only

Non-MCP projects: above Lead-With / Action→Tool / Gotchas / Decision Shortcuts
sections are dormant (no cmm/serena to route to). The propagation rules (Rule /
Skill layer / Agent layer / When .mcp.json changes) still apply verbatim."""

with open('.claude/rules/mcp-routing.md') as f:
    existing = f.read()

with open('.claude/rules/mcp-routing.md', 'w') as f:
    f.write(existing.rstrip() + '\n' + canonical + '\n')

print("APPENDED: canonical action-table content (heredoc) → mcp-routing.md")
PY
fi

# Verify merge succeeded
if ! grep -q '^## Action → Tool' .claude/rules/mcp-routing.md; then
  printf "ERROR: merge verification failed — mcp-routing.md does not contain '## Action → Tool' after append\n"
  exit 1
fi
printf "VERIFIED: mcp-routing.md contains '## Action → Tool' section\n"
```

---

### Step 3 — Delete standalone mcp-tool-routing.md

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig031-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig031-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${HAS_TOOL_ROUTING:-}" && -f ".claude/rules/mcp-tool-routing.md" ]]; then
  rm ".claude/rules/mcp-tool-routing.md"
  printf "DELETED: .claude/rules/mcp-tool-routing.md\n"
else
  printf "SKIP: .claude/rules/mcp-tool-routing.md already absent\n"
fi
```

---

### Step 4 — Strip @import from CLAUDE.md

Idempotent Python regex removal. If the line is not present, print SKIP and exit 0.

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -f "CLAUDE.md" ]]; then
  python3 - <<'PY'
import re
with open('CLAUDE.md') as f:
    text = f.read()
new_text = re.sub(r'^@import\s+\.claude/rules/mcp-tool-routing\.md\s*\n', '', text, flags=re.MULTILINE)
if new_text == text:
    print("SKIP: CLAUDE.md does not import mcp-tool-routing.md")
else:
    with open('CLAUDE.md', 'w') as f:
        f.write(new_text)
    print("STRIPPED: @import .claude/rules/mcp-tool-routing.md from CLAUDE.md")
PY
else
  printf "SKIP: CLAUDE.md not found\n"
fi
```

---

### Step 5 — Patch agent files (glob for sub-specialists)

Uses exact-string Python `replace()` calls — no regex — to avoid over-matching. Agents whose prose does not match the 018-era exact patterns (hand-edited post-018 or pre-018 bodies) print `NO-OP` and are not modified. NO-OP agents are collected and reported at the end for manual review.

Three edits per file where applicable:
- **Edit A1**: STEP 0 force-read block — remove `mcp-tool-routing.md` bullet, reword `mcp-routing.md` bullet to mention "action→tool routing table".
- **Edit A2**: override prose — two-clause → single-clause form.
- **Edit A3**: Pre-Work step — only in `proj-code-writer-*.md` and `proj-test-writer-*.md` (two known variant strings).

```bash
#!/usr/bin/env bash
set -euo pipefail

NOOP_LIST=""

for agent in .claude/agents/proj-*.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md; do
  [[ -f "$agent" ]] || continue

  if ! grep -q "mcp-tool-routing.md" "$agent"; then
    printf "SKIP: %s — no mcp-tool-routing.md reference (already patched or pre-018 body)\n" "$agent"
    continue
  fi

  result=$(python3 - "$agent" <<'PY'
import sys
path = sys.argv[1]
with open(path) as f:
    text = f.read()
original = text

# Edit A1: force-read block — delete mcp-tool-routing.md bullet + reword mcp-routing.md bullet.
# Two-bullet form written by migration 018:
old_block = (
    "- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)\n"
    "- `.claude/rules/mcp-tool-routing.md` (if present — authoritative action\u2192tool routing; overrides any Grep/Glob/Read-first examples later in this file)"
)
new_block = "- `.claude/rules/mcp-routing.md` (if present — MCP propagation rules + action\u2192tool routing table; overrides any Grep/Glob/Read-first examples later in this file)"
text = text.replace(old_block, new_block)

# Edit A2: override prose — two-clause → single-clause.
old_prose = (
    "If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config). "
    "If `mcp-tool-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples "
    "later in this file \u2014 route through MCP tools per that rule\u2019s action\u2192tool table before falling back to text search."
)
new_prose = (
    "If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config) "
    "AND route code discovery through its action\u2192tool table BEFORE any `Grep` / `Glob` / `Read`-first "
    "examples later in this file. Fall back to text search only when no MCP path fits."
)
text = text.replace(old_prose, new_prose)

# Edit A2 alternate: handle straight-quote / em-dash variants written by some 018 runs
old_prose_alt = (
    "If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config). "
    "If `mcp-tool-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples "
    "later in this file -- route through MCP tools per that rule's action->tool table before falling back to text search."
)
if old_prose_alt in text:
    text = text.replace(old_prose_alt, new_prose)

# Edit A2 alternate 2: compact form used in some generated agents
old_prose_compact = (
    "If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config). "
    "If `mcp-tool-routing.md` is loaded, it OVERRIDES any Grep / Glob / Read-first examples later in this file \u2014 "
    "route through MCP tools per that rule\u2019s action\u2192tool table before falling back to text search."
)
if old_prose_compact in text:
    text = text.replace(old_prose_compact, new_prose)

# Edit A3: Pre-Work step — variant 1 (with "Lead-With Order" reference)
old_prework_1 = (
    "1. If `.claude/rules/mcp-tool-routing.md` loaded: use MCP tools per routing table for code discovery "
    "BEFORE Grep/Read (see that rule\u2019s Lead-With Order)"
)
new_prework = (
    "1. If `.claude/rules/mcp-routing.md` action\u2192tool table populated (MCP project): use MCP tools per "
    "routing table for code discovery BEFORE Grep/Read (see that rule\u2019s Lead-With Order)"
)
text = text.replace(old_prework_1, new_prework)

# Edit A3: Pre-Work step — variant 2 (without "Lead-With Order" reference)
old_prework_2 = (
    "1. If `.claude/rules/mcp-tool-routing.md` loaded: use MCP tools per routing table for code discovery BEFORE Grep/Read"
)
new_prework_2 = (
    "1. If `.claude/rules/mcp-routing.md` action\u2192tool table populated (MCP project): use MCP tools per routing table for code discovery BEFORE Grep/Read"
)
if old_prework_2 in text and old_prework_1 not in original:
    text = text.replace(old_prework_2, new_prework_2)

if text == original:
    print(f"NO-OP: {path} (no matching 018-era patterns — hand-edited or custom body)")
    sys.exit(0)

with open(path, 'w') as f:
    f.write(text)
print(f"PATCHED: {path}")
PY
  )

  printf "%s\n" "$result"

  if printf "%s" "$result" | grep -q "^NO-OP:"; then
    NOOP_LIST="${NOOP_LIST} ${agent}"
  fi
done

if [[ -n "$NOOP_LIST" ]]; then
  printf "\nNO-OP AGENTS (manual review recommended):%s\n" "$NOOP_LIST"
  printf "These agent files reference mcp-tool-routing.md but did not match 018-era exact patterns.\n"
  printf "Manually update STEP 0 force-read block + override prose to single-clause form.\n"
fi
```

---

### Step 6 — Fetch refreshed techniques/agent-design.md

Destination: `.claude/references/techniques/` — the client-project layout. NOT `techniques/` at project root (which is the bootstrap repo layout). This follows `.claude/rules/general.md` migration rules and CLAUDE.md Gotchas.

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p .claude/references/techniques

# Resolve bootstrap repo (env var → state file → canonical default)
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json')).get('bootstrap_repo','tomasfil/claude-bootstrap'))" 2>/dev/null || printf "tomasfil/claude-bootstrap")}"
printf "Using bootstrap repo: %s\n" "$BOOTSTRAP_REPO"

if ! command -v gh >/dev/null 2>&1; then
  printf "WARN: gh not available — skipping agent-design.md sync\n"
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  printf "WARN: gh not authenticated — skipping agent-design.md sync\n"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/agent-design.md" --jq '.content' 2>/dev/null | base64 -d > "$TMP"; then
  printf "WARN: failed to fetch techniques/agent-design.md from %s — skipping sync\n" "$BOOTSTRAP_REPO"
  exit 0
fi

if [[ ! -s "$TMP" ]]; then
  printf "WARN: fetched agent-design.md is empty — skipping sync\n"
  exit 0
fi

TARGET=".claude/references/techniques/agent-design.md"

if [[ -f "$TARGET" ]] && cmp -s "$TARGET" "$TMP"; then
  printf "SKIP: %s already current (matches upstream)\n" "$TARGET"
else
  mv "$TMP" "$TARGET"
  trap - EXIT
  printf "WROTE: %s\n" "$TARGET"
fi
```

---

### Step 7 — Advance bootstrap-state.json

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
    (isinstance(a, dict) and a.get("id") == "031") or a == "031"
    for a in applied
)
if already:
    print("SKIP: 031 already in applied[]")
else:
    applied.append({
        "id": "031",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "Consolidate mcp-tool-routing.md into mcp-routing.md"
    })
    state["applied"] = applied
    state["last_migration"] = "031"
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    print("ADVANCED: bootstrap-state.json last_migration=031")
PY
```

---

### Rules for migration scripts

- **Glob agent filenames, never hardcode** — `for agent in .claude/agents/proj-code-writer-*.md; do ... done` covers sub-specialists created via `/evolve-agents`.
- **Exact-string `replace()` only** — no regex `.*` patterns in agent patches. Agents that don't match the exact 018-era strings print `NO-OP` and are left unchanged (reported for manual review). This prevents false-positive over-matching of hand-edited bodies.
- **Append-only merge** — Step 2 never overwrites `mcp-routing.md` content; it only appends. Existing project-specific empirical content (routing table rows added post-bootstrap) is preserved.
- **Idempotent** — every step checks sentinel before acting. Re-running twice prints `SKIP` for every step and exits 0.
- **Read-before-write** — every file opened, read into string, modified, then written. No in-place clobber.
- **MINGW64-safe** — no `sed -i`, no process substitution, no `readarray`. Uses `python3` for all string manipulations.
- **Abort on error** — `set -euo pipefail` at the top of every bash block. Failed steps do NOT advance `bootstrap-state.json` (Step 7 is separate and last).
- **Technique sync destination** — `.claude/references/techniques/` (client layout), NOT `techniques/` at project root (bootstrap repo layout).

### Required: register in migrations/index.json

Every migration file MUST have a matching entry in `migrations/index.json`. Entry is shown in the Process section below and has been added as part of this change set.

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

# (a) mcp-tool-routing.md absent
if [[ ! -f ".claude/rules/mcp-tool-routing.md" ]]; then
  printf "OK: .claude/rules/mcp-tool-routing.md absent\n"
else
  printf "FAIL: .claude/rules/mcp-tool-routing.md still present\n"
  FAIL=1
fi

# (b) mcp-routing.md contains Action → Tool header
if [[ -f ".claude/rules/mcp-routing.md" ]] && grep -q '^## Action → Tool' .claude/rules/mcp-routing.md; then
  printf "OK: mcp-routing.md has '## Action → Tool' section\n"
else
  printf "FAIL: mcp-routing.md missing '## Action → Tool' section\n"
  FAIL=1
fi

# (c) no agent file references mcp-tool-routing.md
OFFENDERS=$(grep -l "mcp-tool-routing" .claude/agents/*.md 2>/dev/null || true)
if [[ -n "$OFFENDERS" ]]; then
  printf "FAIL: these agent files still reference mcp-tool-routing.md:\n%s\n" "$OFFENDERS"
  FAIL=1
else
  printf "OK: no agent file references mcp-tool-routing.md\n"
fi

# (d) CLAUDE.md does not import mcp-tool-routing.md
if [[ -f "CLAUDE.md" ]] && grep -q "mcp-tool-routing" CLAUDE.md; then
  printf "FAIL: CLAUDE.md still references mcp-tool-routing.md\n"
  FAIL=1
else
  printf "OK: CLAUDE.md clean (no mcp-tool-routing.md reference)\n"
fi

# (e) bootstrap-state.json lists 031 in applied[] and as last_migration
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_031 = any((isinstance(a, dict) and a.get('id') == '031') or a == '031' for a in applied)
last = state.get('last_migration', '')
fail = 0
if not has_031:
    print("FAIL: 031 not in applied[]")
    fail = 1
else:
    print("OK: 031 in applied[]")
if last != '031':
    print(f"FAIL: last_migration is '{last}', expected '031'")
    fail = 1
else:
    print("OK: last_migration=031")
sys.exit(fail)
PY
[[ $? -eq 0 ]] || FAIL=1

if [[ $FAIL -eq 0 ]]; then
  printf "\nMigration 031 complete — all checks passed\n"
else
  printf "\nMigration 031 FAILED — %d check(s) above need attention\n" "$FAIL"
  exit 1
fi
```

Failure of any verify step → migration is not complete. Safe to re-run after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"031"`
- append `{ "id": "031", "applied_at": "<ISO8601>", "description": "Consolidate mcp-tool-routing.md into mcp-routing.md" }` to `applied[]`

---

## Rollback

Not rollback-able via migration runner. Restore from git if needed:

```bash
# Restore deleted mcp-tool-routing.md and original mcp-routing.md from git
git checkout HEAD -- .claude/rules/mcp-tool-routing.md .claude/rules/mcp-routing.md

# Restore agent files
git checkout HEAD -- .claude/agents/

# Restore CLAUDE.md
git checkout HEAD -- CLAUDE.md
```

If the project's `.claude/` directory is gitignored (companion strategy), restore from the companion repo instead:

```bash
# Companion restore — from ~/.claude-configs/{project}/
# cp -r ~/.claude-configs/{project}/.claude/rules/mcp-tool-routing.md .claude/rules/
# etc.
```
