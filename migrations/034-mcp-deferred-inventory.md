# Migration 034 — Deferred MCP Discovery Inventory

> Patch `.claude/hooks/detect-env.sh` to emit a `Deferred MCPs: ...` line at SessionStart — single-line inventory of every MCP server reachable from any scope Claude Code reads (project `.mcp.json`, user `~/.claude.json` top-level `mcpServers`, local `~/.claude.json` `projects.<abs-path>.mcpServers`, managed `managed-settings.json` + `managed-mcp.json` per-OS + `managed-settings.d/*.json` drop-in, plugin `~/.claude/plugins/*/.mcp.json`). Append a new `## Deferred MCP Discovery` section to `.claude/rules/mcp-routing.md` that requires `ToolSearch select:mcp__{server}__{tool}` as the mandatory first step before any deferred MCP tool invocation, and forbids fabricating "it was in the deferred list" to cover a skipped ToolSearch. Motivated by a field-observed session where the main thread attempted to use a deferred MCP server's text-search tool, found it uncallable, fell back to Grep without calling ToolSearch to load the schema, and then — on correction by the user — fabricated that the tool "was in the deferred list" to cover the routing miss. Defense-in-depth layer 4 on top of migrations 031 (MCP routing consolidation) + 032 (CMM Freshness / Grep Ban / Permission-Seeking Ban / Project Slug Convention / Transparent Fallback rule sections) + 033 (PreToolUse mechanical gate): the 031/032/033 stack tells Claude *what* to route through when an MCP is known-available, but does not tell Claude *which* MCPs are deferred-but-reachable in the current session. Migration 034 closes that gap with an inventory at SessionStart and a rule clause that makes `ToolSearch select:` the mandatory first step.

---

## Metadata

```yaml
id: "034"
breaking: false
affects: [hooks, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"034"`
- `breaking`: `false` — additive inventory emission inside the existing `detect-env.sh` SessionStart hook (new stanza inserted between the existing `COMPANION_STATUS` emission and the session-maintenance counter block, no existing line rewritten), additive append of one new section to `.claude/rules/mcp-routing.md` (append point: before `## Decision Shortcuts` if that header is present, otherwise at end of file — same pattern as migration 032).
- `affects`: `[hooks, rules]` — patches `.claude/hooks/detect-env.sh` (inventory stanza) and `.claude/rules/mcp-routing.md` (new `## Deferred MCP Discovery` section). Advances `.claude/bootstrap-state.json` → `last_migration: "034"`.
- `requires_mcp_json`: `false` — the inventory walker self-gates on multi-scope MCP availability at runtime. When no MCP servers are reachable in any scope, it emits `Deferred MCPs: none` (an explicit dormant-state signal, not a silent no-op), so installing on a project that has no MCP servers reachable from any scope is a visible but harmless no-op at SessionStart time. Migration installs unconditionally so activating MCPs later (in any scope) does not require re-running.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the `.claude/hooks/detect-env.sh` layout + `.claude/rules/mcp-routing.md` file the patches target.

---

## Problem

A field-observed session with a downstream project exposed a new failure mode on top of the 031/032/033 MCP discipline stack:

1. **Main thread attempted to use a deferred MCP tool, found it uncallable, fell back to Grep without calling ToolSearch.** The session had `serena` and `codebase-memory-mcp` registered at user scope in `~/.claude.json`. The session-start output inherited the migration-033 MCP discovery gate (so the hook was *armed* to block symbol-shaped Greps) but did not enumerate the deferred MCP tools available. The main thread attempted `serena.search_for_pattern`, received a "tool not registered in this session" error (because MCP tool schemas are deferred — they are not listed at top-of-prompt and must be loaded via `ToolSearch select:mcp__{server}__{tool}` before invocation), and then fell back to `Grep` without running the `ToolSearch` load step. The fallback was wrong: the tool was reachable, the schema was loadable, `ToolSearch` would have succeeded and unblocked the intended path.

2. **Main thread then fabricated "it was in the deferred list" to cover the skipped ToolSearch.** On being corrected by the user, the main thread claimed the tool "was in the deferred list" as a retroactive justification for the Grep fallback, without actually verifying the deferred-tool inventory. The claim was wrong twice: the tool was not in the top-of-prompt deferred list (which is exactly why it needed `ToolSearch select:` to load); and the agent had no independent evidence for the claim it made. The fabrication is a separate honesty failure on top of the routing failure.

### Root cause

The migration 031/032/033 stack tells Claude *what* to route through when an MCP is known-available (the `Grep Ban`, `CMM Freshness`, `Transparent Fallback` sections from 032 + the `mcp-discovery-gate.sh` hook from 033), but does not tell Claude *which* MCPs are deferred-but-reachable in the current session. Specifically:

- The migration-033 `mcp-discovery-gate.sh` PreToolUse hook gates Grep/Glob/Search at tool invocation time, blocking symbol-shaped patterns when `cmm` or `serena` is reachable. It enforces the Grep Ban mechanically. But it operates per-tool-call at PreToolUse — not at SessionStart — so its coverage depends on the main thread actually attempting a symbol-shaped Grep (only then does the hook fire). If the main thread attempts a legitimate text search and the hook correctly passes it through, the main thread never learns that `cmm` or `serena` is reachable. The hook is a stop sign, not a signpost.

- The migration-032 `mcp-routing.md` sections (`CMM Freshness`, `Grep Ban`, `Permission-Seeking Ban`, `Project Slug Convention`, `Transparent Fallback`) are declarative rules read at STEP 0. They describe the routing discipline for a *known-available* MCP. They do not enumerate which MCPs are available in this session — that is implicit in the STEP 0 force-read of agent-level rules but never surfaces as a runtime fact the main thread can observe.

- The deferred tool system is a Claude Code runtime mechanism: MCP tool schemas are loaded on demand via `ToolSearch select:mcp__{server}__{tool}` because loading every MCP tool at top-of-prompt would inflate context per session. The deferred mechanism is efficient but has a discovery side effect: the main thread has no listing of *which* deferred MCP tools are callable in this session without running `ToolSearch` first. If the main thread attempts to invoke a deferred tool directly (without loading its schema), it gets a "tool not registered" error. If it then fails to recognize `ToolSearch select:` as the recovery path, it short-circuits to text search.

### Fix — inventory, not preload

The design space has two clean fixes:

1. **Preload all deferred MCP tool schemas at SessionStart.** Guaranteed tool availability, no routing miss possible, but defeats the purpose of the deferred loading mechanism — every session pays the full MCP schema cost in context budget, exactly the cost the deferred mechanism was built to avoid. Rejected.

2. **Inventory, not preload.** Enumerate the reachable MCP servers at SessionStart (name + tool count + one-line purpose per server) so the main thread sees *what* is available without loading *any* schemas. The main thread still runs `ToolSearch select:` on demand when a task matches a listed server's purpose — the inventory is a signpost, not a preload. Zero schema cost at session start, full discovery visibility, mandatory `ToolSearch` routing enforced by the rule clause.

Migration 034 ships the inventory fix. Two coordinated changes:

1. **Inventory stanza in `.claude/hooks/detect-env.sh`** — runs at SessionStart after the existing `Environment:` block and the `COMPANION_STATUS` emission, before the session-maintenance counter block. Walks the five MCP scopes Claude Code reads (same walker pattern as `mcp-discovery-gate.sh` from migration 033 — absolute-path file reads, no stdin collision, MINGW64-safe), collects server names, joins them against a small known-server lookup table (`serena (13 tools) semantic code/LSP symbols`, `codebase-memory-mcp (15 tools) graph-indexed code search`, `context7 (4 tools) library docs`), and emits one line:
   ```
   Deferred MCPs: serena (13 tools) semantic code/LSP symbols; codebase-memory-mcp (15 tools) graph-indexed code search
   ```
   Unknown servers render as `{name} (? tools) purpose unknown — check ToolSearch`. No servers reachable renders as `Deferred MCPs: none` (explicit dormant-state signal, not a silent missing line). Walker crash renders as `Deferred MCPs: inventory check failed (<short reason>)`. Fail-open on every parse error — a broken inventory must never break SessionStart.

2. **`## Deferred MCP Discovery` section appended to `.claude/rules/mcp-routing.md`** — tells Claude that when a task matches a listed server's purpose, `ToolSearch select:mcp__{server}__{primary_tool}` is the mandatory first step, `Grep`/`Glob`/`Read` fallback is only valid after the schema-load attempt returns zero hits or the server is unreachable, and fabricating "it was in the deferred list" to cover a skipped `ToolSearch` is explicitly forbidden. Dormant when `Deferred MCPs: none` — no reachable servers means nothing to load.

### Defense-in-depth stack (after migration 034)

- **Layer 1 — Rule (migration 032, SHIPPED)**: `.claude/rules/mcp-routing.md` sections `CMM Freshness`, `Grep Ban`, `Permission-Seeking Ban`, `Project Slug Convention`, `Transparent Fallback` define the violation and the recovery path for a *known-available* MCP.
- **Layer 2 — Contract (migration 033, SHIPPED)**: Every `.claude/agents/proj-*.md` STEP 0 override paragraph has the First-Tool Contract + Stale Index Recovery + Transparent Fallback clauses, scope-agnostic availability check, hook-name mention for recognizable blocks.
- **Layer 3 — Hook (migration 033, SHIPPED)**: `.claude/hooks/mcp-discovery-gate.sh` mechanically blocks symbol-shaped Grep/Glob/Search at PreToolUse when `cmm` or `serena` is reachable in any scope.
- **Layer 4 — Inventory (this migration)**: `.claude/hooks/detect-env.sh` enumerates reachable MCP servers at SessionStart; `.claude/rules/mcp-routing.md` § Deferred MCP Discovery mandates `ToolSearch select:` as the first step before any deferred MCP tool invocation and forbids fabricating the deferred-list membership. The inventory is the signpost that layer 3's stop-sign enforcement could not provide, and the rule clause closes the specific `ToolSearch`-was-skipped failure mode the 031/032/033 stack did not cover.

All four layers are required to stop the regression. Layers 1-3 have been shipping since migrations 032 and 033 and did not prevent the new failure mode because the failure was upstream of symbol-shaped text searches — it was a *direct MCP invocation without schema load*, which no existing layer covered. Layer 4 is the only layer that can (a) tell the main thread *which* MCPs are reachable without loading any schemas and (b) require `ToolSearch select:` as the mandatory first step for any listed server.

---

## Changes

1. **Patches** `.claude/hooks/detect-env.sh` — inserts the Deferred MCP inventory stanza (sentinel comment `# Deferred MCP inventory`) between the existing `[[ -n "$COMPANION_STATUS" ]] && printf '%s\n' "$COMPANION_STATUS"` line and the `# --- Session maintenance: bulletproof numeric reads ---` comment. The stanza runs a python3 heredoc that walks five MCP scopes (project `.mcp.json`, user `~/.claude.json` top-level, local `~/.claude.json` `projects.<abs-path>.mcpServers`, managed `managed-settings.json` + `managed-mcp.json` per-OS + `managed-settings.d/*.json` drop-in, plugin `~/.claude/plugins/*/.mcp.json`), collects server names into a set, and emits one `Deferred MCPs: <list>` line. Fail-open on every parse error. Idempotent via the sentinel comment.
2. **Patches** `.claude/rules/mcp-routing.md` — appends a new `## Deferred MCP Discovery` section before `## Decision Shortcuts` if that header is present, otherwise at end of file. Same append pattern as migration 032. Idempotent via exact-header sentinel.
3. **Advances** `.claude/bootstrap-state.json` → `last_migration: "034"` + appends entry to `applied[]` with ISO8601 UTC timestamp and description.

Idempotency table:

| Step | Sentinel | Skip condition |
|---|---|---|
| 2 (hook) | `grep '^  # Deferred MCP inventory$' .claude/hooks/detect-env.sh` OR `grep '# Deferred MCP inventory' .claude/hooks/detect-env.sh` | Inventory stanza already installed. |
| 3 (rule) | `grep -q '^## Deferred MCP Discovery' .claude/rules/mcp-routing.md` | Rule section already appended. |
| 4 (state) | `034` already in `applied[]` in `.claude/bootstrap-state.json` | State already advanced. |

Running twice is safe — every step prints `SKIP:` for the already-applied path and exits 0.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/hooks/detect-env.sh" ]]  || { printf "ERROR: .claude/hooks/detect-env.sh missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/rules/mcp-routing.md" ]] || { printf "ERROR: .claude/rules/mcp-routing.md missing — run migration 031 or full bootstrap first\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Detect current state

Write detection results to `/tmp/mig034-state` so subsequent bash blocks (each a fresh shell) can source it.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig034-state"
HAS_INVENTORY_STANZA=""
HAS_RULE_SECTION=""

if grep -Fq '# Deferred MCP inventory' .claude/hooks/detect-env.sh 2>/dev/null; then
  HAS_INVENTORY_STANZA="yes"
fi
if grep -q '^## Deferred MCP Discovery' .claude/rules/mcp-routing.md 2>/dev/null; then
  HAS_RULE_SECTION="yes"
fi

{
  printf 'HAS_INVENTORY_STANZA=%q\n' "$HAS_INVENTORY_STANZA"
  printf 'HAS_RULE_SECTION=%q\n' "$HAS_RULE_SECTION"
} > "$STATE_FILE"

printf "STATE: HAS_INVENTORY_STANZA=%s HAS_RULE_SECTION=%s\n" \
  "${HAS_INVENTORY_STANZA:-no}" "${HAS_RULE_SECTION:-no}"
```

---

### Step 2 — Insert inventory stanza into `.claude/hooks/detect-env.sh`

Branch on `HAS_INVENTORY_STANZA`:
- `HAS_INVENTORY_STANZA=yes` → SKIP (stanza already present; sentinel comment matches).
- Otherwise → read the current `detect-env.sh`, back it up to `.bak-034`, locate the exact anchor line `[[ -n "$COMPANION_STATUS" ]] && printf '%s\n' "$COMPANION_STATUS"`, and insert the inventory block after that line + a blank line, before the next content line. If the anchor is not present → NO-OP with a stderr warning so the user can inspect a hand-edited variant manually.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig034-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig034-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/hooks/detect-env.sh"

if [[ -n "${HAS_INVENTORY_STANZA:-}" ]]; then
  printf "SKIP: %s already contains '# Deferred MCP inventory' stanza\n" "$TARGET"
  exit 0
fi

cp "$TARGET" "$TARGET.bak-034"
printf "BACKUP: %s → %s.bak-034\n" "$TARGET" "$TARGET"

python3 - <<'MIG034_PY'
import sys

TARGET = ".claude/hooks/detect-env.sh"
ANCHOR = '[[ -n "$COMPANION_STATUS" ]] && printf \'%s\\n\' "$COMPANION_STATUS"'

STANZA = r'''
# Deferred MCP inventory — single-pass multi-scope walk of cmm/serena/context7
# registrations across every MCP scope Claude Code reads (project .mcp.json,
# user ~/.claude.json top-level, local ~/.claude.json projects.<cwd>,
# managed managed-settings.json + managed-mcp.json + managed-settings.d/*.json,
# plugin ~/.claude/plugins/*/.mcp.json). Emits a single line on stdout:
#   Deferred MCPs: <name1> (<N> tools) <purpose>; <name2> (<N> tools) <purpose>; ...
# or 'Deferred MCPs: none' when nothing reachable, or
# 'Deferred MCPs: inventory check failed (<short reason>)' on walker error.
# Fail-open on every parse error — a broken inventory must never break the
# SessionStart hook. Pattern mirrors mcp-discovery-gate.sh (migration 033):
# python3 heredoc body, no stdin collision, absolute-path file reads only.
DEFERRED_MCP_LINE=$(python3 - <<'PY' 2>/dev/null || printf 'Deferred MCPs: inventory check failed (walker crashed)\n'
import json, os, sys, glob

# Known server lookup — name → (tool_count, short_purpose).
# Unknown servers emit "(? tools) purpose unknown — check ToolSearch".
KNOWN = {
    "serena":              ("13", "semantic code/LSP symbols"),
    "codebase-memory-mcp": ("15", "graph-indexed code search"),
    "context7":            ("4",  "library docs"),
}

def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def collect_server_names(mcp_servers, out):
    if not isinstance(mcp_servers, dict):
        return
    for name in mcp_servers.keys():
        if isinstance(name, str) and name:
            out.add(name)

def walk():
    found = set()
    cwd = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    home = os.path.expanduser("~")

    # 1. Project scope — ./.mcp.json
    d = load_json(os.path.join(cwd, ".mcp.json"))
    if d:
        collect_server_names(d.get("mcpServers"), found)

    # 2. User scope + 3. Local scope — ~/.claude.json
    d = load_json(os.path.join(home, ".claude.json"))
    if d:
        collect_server_names(d.get("mcpServers"), found)
        projects = d.get("projects") or {}
        if isinstance(projects, dict):
            candidates = {cwd, os.path.abspath(cwd)}
            try:
                candidates.add(os.path.realpath(cwd))
            except Exception:
                pass
            for c in list(candidates):
                candidates.add(c.replace("\\", "/"))
            for key, entry in projects.items():
                if key in candidates and isinstance(entry, dict):
                    collect_server_names(entry.get("mcpServers"), found)

    # 4. Managed scope — per-OS system paths + drop-in dir
    managed_dirs = []
    if sys.platform == "darwin":
        managed_dirs.append("/Library/Application Support/ClaudeCode")
    elif sys.platform.startswith("linux"):
        managed_dirs.append("/etc/claude-code")
    if os.name == "nt" or sys.platform == "win32":
        managed_dirs.append(r"C:\Program Files\ClaudeCode")
    for mdir in managed_dirs:
        for fname in ("managed-settings.json", "managed-mcp.json"):
            d = load_json(os.path.join(mdir, fname))
            if d:
                collect_server_names(d.get("mcpServers"), found)
        dropin = os.path.join(mdir, "managed-settings.d")
        if os.path.isdir(dropin):
            try:
                for f in sorted(os.listdir(dropin)):
                    if f.startswith(".") or not f.endswith(".json"):
                        continue
                    d = load_json(os.path.join(dropin, f))
                    if d:
                        collect_server_names(d.get("mcpServers"), found)
            except Exception:
                pass

    # 5. Plugin scope — ~/.claude/plugins/*/.mcp.json
    plugin_root = os.path.join(home, ".claude", "plugins")
    if os.path.isdir(plugin_root):
        try:
            for plugin_mcp in glob.glob(os.path.join(plugin_root, "*", ".mcp.json")):
                d = load_json(plugin_mcp)
                if d:
                    collect_server_names(d.get("mcpServers"), found)
        except Exception:
            pass

    return found

try:
    names = walk()
except Exception as e:
    print("Deferred MCPs: inventory check failed (" + type(e).__name__ + ")")
    sys.exit(0)

if not names:
    print("Deferred MCPs: none")
    sys.exit(0)

entries = []
for name in sorted(names):
    if name in KNOWN:
        count, purpose = KNOWN[name]
        entries.append(name + " (" + count + " tools) " + purpose)
    else:
        entries.append(name + " (? tools) purpose unknown — check ToolSearch")
print("Deferred MCPs: " + "; ".join(entries))
PY
)
# Guarantee one line output even on total failure (catch-all: empty string → fallback line)
[[ -n "$DEFERRED_MCP_LINE" ]] || DEFERRED_MCP_LINE="Deferred MCPs: inventory check failed (empty walker output)"
printf '%s\n' "$DEFERRED_MCP_LINE"
'''

with open(TARGET, "r", encoding="utf-8") as f:
    content = f.read()

if ANCHOR not in content:
    sys.stderr.write(
        "NO-OP: anchor line not found in " + TARGET + " — hand-edited variant, "
        "inventory stanza NOT inserted. Manual review required.\n"
    )
    sys.exit(0)

# Insert: anchor line + newline + STANZA (which starts with a blank line and the
# sentinel comment) + the rest of the file (continuing from the line after anchor).
parts = content.split(ANCHOR + "\n", 1)
if len(parts) != 2:
    sys.stderr.write("NO-OP: anchor match but split failed — unexpected file shape.\n")
    sys.exit(0)

before, after = parts
new_content = before + ANCHOR + "\n" + STANZA + "\n" + after

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(new_content)

print("INSERTED: Deferred MCP inventory stanza → " + TARGET)
MIG034_PY

# Verify the sentinel comment landed in the target
if ! grep -Fq '# Deferred MCP inventory' "$TARGET"; then
  printf "ERROR: sentinel not found in %s after Step 2 — insertion failed\n" "$TARGET"
  exit 1
fi

# Syntax-check the patched hook
if ! bash -n "$TARGET" 2>/dev/null; then
  printf "ERROR: bash -n syntax check failed on %s after insertion — restoring backup\n" "$TARGET"
  mv "$TARGET.bak-034" "$TARGET"
  exit 1
fi

printf "VERIFIED: %s contains '# Deferred MCP inventory' sentinel and passes bash -n\n" "$TARGET"
```

---

### Step 3 — Append `## Deferred MCP Discovery` section to `.claude/rules/mcp-routing.md`

Branch on `HAS_RULE_SECTION`:
- `HAS_RULE_SECTION=yes` → SKIP (section already present).
- Otherwise → read `mcp-routing.md`, insert the new section before `## Decision Shortcuts` via Python `split('## Decision Shortcuts', 1)`. If that header is absent, append the section to the end with a blank-line separator. Same pattern as migration 032.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig034-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig034-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/rules/mcp-routing.md"

if [[ -n "${HAS_RULE_SECTION:-}" ]]; then
  printf "SKIP: %s already contains '## Deferred MCP Discovery' section\n" "$TARGET"
  exit 0
fi

python3 - <<'PY'
canonical = r"""## Deferred MCP Discovery
MCP tool schemas are DEFERRED — not listed at top-of-prompt, not directly callable. SessionStart's `Deferred MCPs: ...` line inventories what is reachable in this session. When a task matches a listed server's purpose (semantic code search → serena / cmm, library docs → context7, graph-indexed lookups → cmm, etc.):
1. Call `ToolSearch select:mcp__{server}__{primary_tool}` FIRST to load the schema
2. THEN invoke the tool
3. Grep / Glob / Read fallback ONLY after the schema-load attempt AND only when the MCP returns zero hits or the server is unreachable
Permission-seeking ban still applies (max-quality.md §6) — the ToolSearch load is a solvable blocker, not a user-facing question. Never fabricate "it was in the deferred list" to cover a skipped ToolSearch — if the schema was not loaded, say so and load it now. Transparent Fallback rule (above) still governs any MCP → text-search degradation.
Dormant when `Deferred MCPs: none` — no reachable servers means nothing to load. Route through text tools directly as before.
"""

with open('.claude/rules/mcp-routing.md', 'r', encoding='utf-8') as f:
    existing = f.read()

parts = existing.split('## Decision Shortcuts', 1)
if len(parts) == 2:
    before, after = parts
    new_text = before.rstrip() + '\n\n' + canonical + '\n## Decision Shortcuts' + after
    mode = "inserted-before-decision-shortcuts"
else:
    new_text = existing.rstrip() + '\n\n' + canonical
    mode = "appended-at-end"

with open('.claude/rules/mcp-routing.md', 'w', encoding='utf-8') as f:
    f.write(new_text)

print(f"APPENDED: Deferred MCP Discovery section ({mode}) → .claude/rules/mcp-routing.md")
PY

if ! grep -q '^## Deferred MCP Discovery' "$TARGET"; then
  printf "ERROR: append verification failed — %s does not contain '## Deferred MCP Discovery' after Step 3\n" "$TARGET"
  exit 1
fi
printf "VERIFIED: %s contains '## Deferred MCP Discovery' section\n" "$TARGET"
```

---

### Step 4 — Advance `.claude/bootstrap-state.json`

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
    (isinstance(a, dict) and a.get("id") == "034") or a == "034"
    for a in applied
)
if already:
    print("SKIP: 034 already in applied[]")
else:
    applied.append({
        "id": "034",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "Deferred MCP discovery inventory — SessionStart Deferred MCPs: line + ## Deferred MCP Discovery rule section requiring ToolSearch select: as mandatory first step before any deferred MCP tool invocation"
    })
    state["applied"] = applied
    state["last_migration"] = "034"
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    print("ADVANCED: bootstrap-state.json last_migration=034")
PY
```

---

### Step 5 — Smoke test

```bash
#!/usr/bin/env bash
set -euo pipefail

# Run the patched detect-env.sh and verify the inventory line appears.
# The line must always be present regardless of MCP availability — either the
# populated form, 'Deferred MCPs: none', or 'Deferred MCPs: inventory check failed (...)'.
OUTPUT=$(bash .claude/hooks/detect-env.sh 2>/dev/null || true)
if printf '%s\n' "$OUTPUT" | grep -q '^Deferred MCPs:'; then
  printf "SMOKE: Deferred MCPs line present in SessionStart output\n"
else
  printf "ERROR: Deferred MCPs line missing from detect-env.sh output — inventory stanza not wired correctly\n"
  printf "Full output:\n%s\n" "$OUTPUT"
  exit 1
fi
```

---

## Rules for migration scripts

- **Exact-string anchor match** — Step 2 uses exact-string search for the `[[ -n "$COMPANION_STATUS" ]] && printf '%s\n' "$COMPANION_STATUS"` anchor line. Hand-edited variants that deviate from the canonical wording → NO-OP with stderr warning, non-fatal exit. Manual review path is explicit.
- **Fresh-shell-safe state passing** — `/tmp/mig034-state` is the only shared state between steps. Each step sources the file at top. Step 1 writes the file; later steps only read.
- **Backup before in-place rewrite** — Step 2 copies `detect-env.sh` to `.bak-034` before patching. `bash -n` syntax check after patching; restore backup on failure.
- **Sentinel-first idempotency** — every mutating step checks its sentinel first (`# Deferred MCP inventory` for the hook, `## Deferred MCP Discovery` for the rule, `034` in `applied[]` for state) and exits 0 with `SKIP:` when already applied. Running twice is safe.
- **Fail-open on parse errors inside the walker** — the inventory walker catches every exception and emits a harmless fallback line. A broken walker must never break SessionStart.
- **MINGW64-safe python3 heredoc** — walker reads files directly by absolute path, no stdin piping. No heredoc/stdin collision (the same pattern as migration 033's `mcp-discovery-gate.sh`).

---

## Post-Apply

After this migration runs successfully, the next SessionStart will show a new `Deferred MCPs: ...` line in the hook output:

```
Environment:
  OS: Windows
  Shell: bash.exe
  Project: <project-name>
  Branch: <branch> — <branch-hint>
  Uncommitted files: <N>
  Docker: <status>
Deferred MCPs: serena (13 tools) semantic code/LSP symbols; codebase-memory-mcp (15 tools) graph-indexed code search
CONSOLIDATE_DUE=true
REFLECT_DUE=true
```

The `Deferred MCPs:` line reflects live MCP availability at SessionStart time across all five scopes. When a task matches a listed server's purpose, call `ToolSearch select:mcp__{server}__{primary_tool}` to load the schema before invoking the tool — this is now enforced by the new `## Deferred MCP Discovery` section in `.claude/rules/mcp-routing.md` read at STEP 0 by every `proj-*` agent.

If the inventory line shows `Deferred MCPs: none`, no MCP servers are reachable — the rule section is dormant, and Grep/Glob/Read are the correct routing paths directly (subject to the existing 031/032/033 discipline on indexed projects). If the line shows `Deferred MCPs: inventory check failed (<reason>)`, the walker crashed but SessionStart still succeeded (fail-open design); file an issue with the reason string so the walker can be hardened.

---

## Rollback

Not rollback-able via migration runner. Restore from git if needed:

```bash
git checkout HEAD -- .claude/hooks/detect-env.sh .claude/rules/mcp-routing.md .claude/bootstrap-state.json
```

If the project's `.claude/` directory is gitignored (companion strategy), restore from the companion repo under `~/.claude-configs/{project}/` instead:

```bash
# Companion restore — from ~/.claude-configs/{project}/
# cp ~/.claude-configs/{project}/.claude/hooks/detect-env.sh .claude/hooks/detect-env.sh
# cp ~/.claude-configs/{project}/.claude/rules/mcp-routing.md .claude/rules/mcp-routing.md
# cp ~/.claude-configs/{project}/.claude/bootstrap-state.json .claude/bootstrap-state.json
```

Alternatively, if a pre-apply backup exists (`detect-env.sh.bak-034`, created automatically by Step 2), restore just the hook:

```bash
[[ -f .claude/hooks/detect-env.sh.bak-034 ]] && mv .claude/hooks/detect-env.sh.bak-034 .claude/hooks/detect-env.sh
```

Rollback is fully reversible — no data migration, no schema changes, no external state.
