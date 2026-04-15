# Migration 038 — CMM Proactive Bootstrap + Zero-Drift Policy

> Proactive per-session cmm zero-drift enforcement: installs `.claude/hooks/cmm-index-startup.sh` (SessionStart startup-matcher hook) + `/cmm-baseline` skill + `.claude/rules/mcp-routing.md` hook-aware rule sections. Closes three failure modes — (A) first-time index never runs until a symbol query forces it, (B) silent partial indexing presents as "fresh", (C) stale graph on re-opened sessions. Fail-open on every error path — a broken hook never blocks session start.

---

## Metadata

```yaml
id: "038"
breaking: false
affects: [hooks, skills, modules, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"038"`
- `breaking`: `false` — additive install. Hook is new, skill is new, rule sections are appended before existing `## Decision Shortcuts` anchor, `.gitignore` exception is appended idempotently, `settings.json` SessionStart hook entry is appended idempotently (no existing key rewritten).
- `affects`: `[hooks, skills, modules, rules]` — creates `.claude/hooks/cmm-index-startup.sh`, creates `.claude/skills/cmm-baseline/SKILL.md` + `.claude/skills/cmm-baseline/references/framework-catalog.md`, patches `.claude/rules/mcp-routing.md`, patches `.claude/skills/consolidate/SKILL.md` + `.claude/skills/reflect/SKILL.md`, patches `.claude/agents/proj-reflector.md`, patches `.claude/settings.json`, patches `.gitignore`. Advances `.claude/bootstrap-state.json` → `last_migration: "038"`.
- `requires_mcp_json`: `false` — migration installs unconditionally. Hook self-gates at runtime on multi-scope cmm availability (walks project `.mcp.json`, user `~/.claude.json` top-level + `projects.<cwd>.mcpServers`, managed `managed-settings.json` / `managed-mcp.json` / `managed-settings.d/*.json`, plugin `~/.claude/plugins/*/.mcp.json`). When cmm is not registered in any scope the hook emits `CMM: not registered` and exits 0 — an explicit dormant-state signal. Installing on a project that has no cmm registration is a visible but harmless no-op at SessionStart. Installing unconditionally means activating cmm later (in any scope) does not require re-running this migration.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the `.claude/rules/mcp-routing.md` layout + `.claude/settings.json` nested-hooks schema this migration patches.

---

## Problem

Three failure modes motivated this migration on top of the existing migration 031/032/033/034 MCP discipline stack:

### Failure mode A — first-time bootstrap leaves cmm graph empty

After running the full bootstrap on a new project, the cmm graph for the project is empty until the first symbol query forces a reactive Claude-mediated index. Between bootstrap end and first query, every discovery tool call that should have routed through cmm falls back to text search (the graph is empty, so `search_graph` returns zero hits, so the `Grep Ban` exemption fires). The project silently operates in degraded routing mode for one full session. Observed pattern: a brand-new bootstrap session shows `CMM_STATE` missing entirely because no hook fires on first run, while the main thread runs `Grep` on every named symbol for the entire session before anyone notices the cmm graph was never populated.

### Failure mode B — silent partial indexing presents as "fresh"

cmm runs tree-sitter at a published 75-89% accuracy tier on some languages. A partial index populates the graph — `list_projects` reports non-trivial `nodeCount`, `index_status` returns `"ready"` — but the graph is missing framework-specific symbols (decorator-based routes, macro-expanded code, source-generated files). Main-thread routing passes the `CMM Freshness` check from migration 032 (non-trivial nodeCount, no `detect_changes` drift), so every subsequent `search_graph` call returns zero hits on the missing symbols and routes to the `Grep Ban` exemption silently. The partial index *looks* healthy. The user never learns the graph was wrong.

### Failure mode C — stale graph on re-opened session

cmm server does not auto-reindex on MCP startup — it loads the last on-disk graph. A session re-opened days after the last commit inherits a stale graph: file references point to symbols at their old line numbers, new symbols are missing entirely, renamed symbols still appear under their old names. Migration 032's `CMM Freshness` rule requires a pre-flight `list_projects` + drift check before the first cmm tool call, but this is a soft rule enforced at agent STEP 0 read-time — the main thread at SessionStart has no equivalent enforcement. A user who opens a session, asks a code question, and receives a confident answer from the stale graph has no signal that the answer references code that no longer exists.

### Fix — proactive zero-drift hook + skill + rule updates

Three coordinated components:

1. **`.claude/hooks/cmm-index-startup.sh`** — SessionStart startup-matcher hook that runs at every session start. Checks cmm registration across all 5 MCP scopes, checks CLI availability, reads `.claude/cmm-baseline.md` if present, compares git SHA + node/edge counts against live `index_status`, triggers a full reindex on any drift (zero-drift policy: (a) SHA mismatch, (b) node/edge count mismatch, (c) `index_status.status != "ready"`, (d) any baseline sentinel missing from `search_graph` probe, (e) baseline age >7 days for slow-moving projects). Fail-open on every error path: a broken hook never blocks session start. Emits structured `CMM_STATE` / `CMM_DRIFT` / `CMM_FIRST_INDEX` / `CMM_HOOK_FAILED` lines to stdout (shown to Claude as session context) and diagnostics to stderr (not shown per hooks spec).

2. **`/cmm-baseline` skill** — main-thread skill that seeds / refreshes / checks / verifies `.claude/cmm-baseline.md`. Baseline is the committed source of truth for healthy cmm graph state: node/edge counts, per-label counts, framework blind spots, sentinels (stable symbols the reindex must always find), known-broken tools (upstream + project-specific), routing overrides. Consumed by the hook for drift detection, by Claude for framework-blind-spot avoidance, and by `/consolidate` Phase 6 + `/reflect` Step 4b for correctness gating.

3. **`.claude/rules/mcp-routing.md` hook-aware sections** — the existing `CMM Freshness` section replaces its manual pre-flight checklist with a hook-state-aware decision tree (hook ran + fresh → proceed; hook ran + `CMM_HOOK_FAILED` → manual probe; hook did not run → fall back to old manual pre-flight). Six new sections add hook + baseline doctrine: `Index Timing Expectations`, `Known-Broken Tools`, `Framework Blind Spots`, `Serena initial_instructions Gate`, `Zero-Drift Policy`, `Sentinel Symbol Probe`.

The skill + hook + rule + consolidate-gate + reflect-broken-tools-proposal + reflector-pattern-7 are installed together. Partial install is forbidden — the rule sections reference the hook, the hook reads the baseline, the baseline is seeded by the skill, the consolidate gate invokes the skill's `verify-sentinels` command, the reflect step proposes additions to the baseline's `## Known-broken tools` section. All components are mutually reinforcing.

### Defense-in-depth stack (after migration 038)

- **Layer 1 — Rule (migration 032, SHIPPED)**: `.claude/rules/mcp-routing.md` sections `CMM Freshness`, `Grep Ban`, `Permission-Seeking Ban`, `Project Slug Convention`, `Transparent Fallback` define the routing discipline for a known-available MCP.
- **Layer 2 — Contract (migration 033, SHIPPED)**: Every `.claude/agents/proj-*.md` STEP 0 override paragraph has the First-Tool Contract + Stale Index Recovery + Transparent Fallback clauses.
- **Layer 3 — PreToolUse Hook (migration 033, SHIPPED)**: `.claude/hooks/mcp-discovery-gate.sh` mechanically blocks symbol-shaped Grep/Glob/Search at tool-call time when cmm or serena is reachable.
- **Layer 4 — Inventory (migration 034, SHIPPED)**: `.claude/hooks/detect-env.sh` emits `Deferred MCPs: ...` inventory at SessionStart; `## Deferred MCP Discovery` rule section mandates `ToolSearch select:` before any deferred MCP tool invocation.
- **Layer 5 — Proactive freshness (this migration)**: SessionStart startup-matcher hook enforces zero-drift cmm state at every session start with reindex on drift. Baseline skill seeds + verifies the committed source-of-truth file. Rule sections codify hook-aware pre-flight + sentinel probe + framework blind-spot avoidance. Consolidate Phase 6 + reflect Step 4b + proj-reflector Pattern 7 close the correctness-gate loop across the `/reflect` and `/consolidate` cadence.

All five layers are required. Layers 1-4 did not prevent the new failure modes because they all operate reactively — at the first cmm tool call or on symbol-shaped text search. Failure mode A happens upstream of any tool call: the graph is empty, and no layer in the existing stack fires until the main thread attempts a cmm query. Layer 5 closes the gap with a SessionStart hook that populates the graph before the first tool call and asserts drift-free state on every session open.

---

## Changes

1. **Creates** `.claude/hooks/cmm-index-startup.sh` — SessionStart startup-matcher hook body (Multi-scope cmm registration walker + CLI check + baseline presence check + FIRST_INDEX path + DRIFT_CHECK path with 5 drift triggers + fail-open ERR trap). Sentinel comment `cmm-index-startup sentinel` in the header for idempotent detection. chmod +x required.
2. **Creates** `.claude/skills/cmm-baseline/SKILL.md` — main-thread skill body with `init` / `refresh` / `check` / `verify-sentinels` commands. YAML frontmatter sentinel `^name: cmm-baseline`.
3. **Creates** `.claude/skills/cmm-baseline/references/framework-catalog.md` — detection-signal → blind-spot catalog consumed by `/cmm-baseline init` for framework auto-detection. Sentinel header `# Framework Catalog`.
4. **Patches** `.gitignore` — appends exception line `!.claude/cmm-baseline.md` so the baseline is always committed regardless of `git_strategy`. Sentinel: exact-line grep for `!.claude/cmm-baseline.md`.
5. **Patches** `.claude/settings.json` — appends SessionStart matcher `startup` entry with command `bash .claude/hooks/cmm-index-startup.sh` and timeout `600`. Sentinel: substring grep for `cmm-index-startup.sh`.
6. **Patches** `.claude/rules/mcp-routing.md` — replaces existing `## CMM Freshness` section body with hook-aware 5-step decision tree + inserts six new sections (`Index Timing Expectations`, `Known-Broken Tools`, `Framework Blind Spots`, `Serena initial_instructions Gate`, `Zero-Drift Policy`, `Sentinel Symbol Probe`) before `## Decision Shortcuts`. Sentinel: `## Zero-Drift Policy` header grep.
7. **Patches** `.claude/skills/consolidate/SKILL.md` — appends `### Phase 6: CMM Baseline Correctness Gate (auto — post-dispatch)` after existing `### Phase 5: Update Tracking` section. Sentinel: `Phase 6: CMM Baseline Correctness Gate` header grep.
8. **Patches** `.claude/skills/reflect/SKILL.md` — appends `### Step 4b: CMM Broken-Tools Catalog Update (auto — post-dispatch)` after existing `### Step 4: Instinct Health Report` section. Sentinel: `Step 4b: CMM Broken-Tools Catalog Update` header grep.
9. **Patches** `.claude/agents/proj-reflector.md` — appends `### Pattern 7 — CMM broken-tool detection (only when codebase-memory-mcp registered)` + `### CMM Broken-Tool Proposals` Output Format section. Sentinel: `Pattern 7 — CMM broken-tool detection` header grep.
10. **Seeds baseline** (conditional, informational) — if cmm is registered in any scope, prompts the user to run `/cmm-baseline init` manually (the skill requires MCP tool calls that cannot run inside a migration script).
11. **Advances** `.claude/bootstrap-state.json` → `last_migration: "038"` + appends entry to `applied[]` with ISO8601 UTC timestamp and description.

### Idempotency table

| Step | Sentinel | Skip condition |
|---|---|---|
| 2 (hook) | `grep -q 'cmm-index-startup sentinel' .claude/hooks/cmm-index-startup.sh` | Hook file already contains sentinel comment. |
| 3 (skill) | `grep -q '^name: cmm-baseline' .claude/skills/cmm-baseline/SKILL.md` | Skill YAML frontmatter already present. |
| 4 (catalog) | `grep -q '^# Framework Catalog' .claude/skills/cmm-baseline/references/framework-catalog.md` | Catalog file already exists with header. |
| 5 (gitignore) | `grep -qxF '!.claude/cmm-baseline.md' .gitignore` | Exception line already present. |
| 6 (settings) | `grep -q 'cmm-index-startup.sh' .claude/settings.json` | Hook already registered in settings.json. |
| 7 (rule sections) | `grep -q '^## Zero-Drift Policy' .claude/rules/mcp-routing.md` | New rule sections already appended. |
| 8 (consolidate) | `grep -q '^### Phase 6: CMM Baseline Correctness Gate' .claude/skills/consolidate/SKILL.md` | Phase 6 already appended. |
| 9 (reflect) | `grep -q '^### Step 4b: CMM Broken-Tools Catalog Update' .claude/skills/reflect/SKILL.md` | Step 4b already appended. |
| 10 (proj-reflector) | `grep -q '^### Pattern 7 — CMM broken-tool detection' .claude/agents/proj-reflector.md` | Pattern 7 already appended. |
| 13 (state) | `038` already in `applied[]` in `.claude/bootstrap-state.json` | State already advanced. |

Running twice is safe — every step prints `SKIP:` for the already-applied path and exits 0.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]]      || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/settings.json" ]]             || { printf "ERROR: .claude/settings.json missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/rules/mcp-routing.md" ]]      || { printf "ERROR: .claude/rules/mcp-routing.md missing — run migration 031 or full bootstrap first\n"; exit 1; }
[[ -f ".claude/skills/consolidate/SKILL.md" ]] || { printf "ERROR: .claude/skills/consolidate/SKILL.md missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/skills/reflect/SKILL.md" ]]     || { printf "ERROR: .claude/skills/reflect/SKILL.md missing — run full bootstrap first\n"; exit 1; }
[[ -f ".claude/agents/proj-reflector.md" ]]    || { printf "ERROR: .claude/agents/proj-reflector.md missing — run full bootstrap first\n"; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
command -v bash    >/dev/null 2>&1 || { printf "ERROR: bash required\n"; exit 1; }
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Detect current state

Write detection results to `/tmp/mig038-state` so subsequent bash blocks (each a fresh shell) can source it.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"

HAS_HOOK=""
HAS_SKILL=""
HAS_CATALOG=""
HAS_GITIGNORE_EXCEPTION=""
HAS_HOOK_IN_SETTINGS=""
HAS_RULE_SECTIONS=""
HAS_CONSOLIDATE_PHASE6=""
HAS_REFLECT_STEP4B=""
HAS_REFLECTOR_PATTERN7=""
CMM_REGISTERED_PROJECT=""

if [[ -f .claude/hooks/cmm-index-startup.sh ]] && grep -q 'cmm-index-startup sentinel' .claude/hooks/cmm-index-startup.sh 2>/dev/null; then
  HAS_HOOK="yes"
fi
if [[ -f .claude/skills/cmm-baseline/SKILL.md ]] && grep -q '^name: cmm-baseline' .claude/skills/cmm-baseline/SKILL.md 2>/dev/null; then
  HAS_SKILL="yes"
fi
if [[ -f .claude/skills/cmm-baseline/references/framework-catalog.md ]] && grep -q '^# Framework Catalog' .claude/skills/cmm-baseline/references/framework-catalog.md 2>/dev/null; then
  HAS_CATALOG="yes"
fi
if grep -qxF '!.claude/cmm-baseline.md' .gitignore 2>/dev/null; then
  HAS_GITIGNORE_EXCEPTION="yes"
fi
if grep -q 'cmm-index-startup.sh' .claude/settings.json 2>/dev/null; then
  HAS_HOOK_IN_SETTINGS="yes"
fi
if grep -q '^## Zero-Drift Policy' .claude/rules/mcp-routing.md 2>/dev/null; then
  HAS_RULE_SECTIONS="yes"
fi
if grep -q '^### Phase 6: CMM Baseline Correctness Gate' .claude/skills/consolidate/SKILL.md 2>/dev/null; then
  HAS_CONSOLIDATE_PHASE6="yes"
fi
if grep -q '^### Step 4b: CMM Broken-Tools Catalog Update' .claude/skills/reflect/SKILL.md 2>/dev/null; then
  HAS_REFLECT_STEP4B="yes"
fi
if grep -q '^### Pattern 7 — CMM broken-tool detection' .claude/agents/proj-reflector.md 2>/dev/null; then
  HAS_REFLECTOR_PATTERN7="yes"
fi
if [[ -f .mcp.json ]] && grep -q 'codebase-memory-mcp' .mcp.json 2>/dev/null; then
  CMM_REGISTERED_PROJECT="yes"
fi

{
  printf 'HAS_HOOK=%q\n'                  "$HAS_HOOK"
  printf 'HAS_SKILL=%q\n'                 "$HAS_SKILL"
  printf 'HAS_CATALOG=%q\n'               "$HAS_CATALOG"
  printf 'HAS_GITIGNORE_EXCEPTION=%q\n'   "$HAS_GITIGNORE_EXCEPTION"
  printf 'HAS_HOOK_IN_SETTINGS=%q\n'      "$HAS_HOOK_IN_SETTINGS"
  printf 'HAS_RULE_SECTIONS=%q\n'         "$HAS_RULE_SECTIONS"
  printf 'HAS_CONSOLIDATE_PHASE6=%q\n'    "$HAS_CONSOLIDATE_PHASE6"
  printf 'HAS_REFLECT_STEP4B=%q\n'        "$HAS_REFLECT_STEP4B"
  printf 'HAS_REFLECTOR_PATTERN7=%q\n'    "$HAS_REFLECTOR_PATTERN7"
  printf 'CMM_REGISTERED_PROJECT=%q\n'    "$CMM_REGISTERED_PROJECT"
} > "$STATE_FILE"

printf "STATE: HAS_HOOK=%s HAS_SKILL=%s HAS_CATALOG=%s HAS_GITIGNORE_EXCEPTION=%s HAS_HOOK_IN_SETTINGS=%s HAS_RULE_SECTIONS=%s HAS_CONSOLIDATE_PHASE6=%s HAS_REFLECT_STEP4B=%s HAS_REFLECTOR_PATTERN7=%s CMM_REGISTERED_PROJECT=%s\n" \
  "${HAS_HOOK:-no}" \
  "${HAS_SKILL:-no}" \
  "${HAS_CATALOG:-no}" \
  "${HAS_GITIGNORE_EXCEPTION:-no}" \
  "${HAS_HOOK_IN_SETTINGS:-no}" \
  "${HAS_RULE_SECTIONS:-no}" \
  "${HAS_CONSOLIDATE_PHASE6:-no}" \
  "${HAS_REFLECT_STEP4B:-no}" \
  "${HAS_REFLECTOR_PATTERN7:-no}" \
  "${CMM_REGISTERED_PROJECT:-no}"
```

---

### Step 2 — Install `.claude/hooks/cmm-index-startup.sh`

Branch on `HAS_HOOK`:
- `HAS_HOOK=yes` → SKIP (sentinel comment present).
- Otherwise → `mkdir -p .claude/hooks`, write full hook body via quoted heredoc `<<'CMM_HOOK_SH'`, `chmod +x`, verify with `bash -n`.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/hooks/cmm-index-startup.sh"

if [[ -n "${HAS_HOOK:-}" ]]; then
  printf "SKIP: %s already contains 'cmm-index-startup sentinel' comment\n" "$TARGET"
  exit 0
fi

mkdir -p .claude/hooks

cat > "$TARGET" <<'CMM_HOOK_SH'
#!/usr/bin/env bash
# cmm-index-startup sentinel
# cmm-index-startup.sh — SessionStart startup-matcher hook.
# Enforces zero-drift policy for codebase-memory-mcp (cmm).
# Emits structured CMM_* lines to stdout (shown to Claude as session context).
# Writes diagnostics to stderr (not shown to Claude per hooks spec).
# Fail-open on every error path — NEVER exits 2, NEVER blocks session start.
# chmod +x required (run: chmod +x .claude/hooks/cmm-index-startup.sh)
set -euo pipefail

# Fail-open ERR trap: any unexpected error emits CMM_HOOK_FAILED and exits 0.
trap 'printf "CMM_HOOK_FAILED: unexpected error — exit %s\n" "$?" >&2; exit 0' ERR

# ---------------------------------------------------------------------------
# STEP 1 — cmm registered check (multi-scope walk via inline Python3).
# Reuses the same load_json / mcp_available / 5-scope walker pattern as
# mcp-discovery-gate.sh (migration 033). Inline — NOT a shared helper.
# Uses CLAUDE_PROJECT_DIR or os.getcwd() for project root resolution.
# ---------------------------------------------------------------------------

CMM_REGISTERED=$(python3 - <<'PY'
import sys, json, os, glob

def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def has_cmm(mcp_servers):
    if not isinstance(mcp_servers, dict):
        return False
    return "codebase-memory-mcp" in mcp_servers

def cmm_registered():
    cwd = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    home = os.path.expanduser("~")

    # Scope 1: project .mcp.json
    d = load_json(os.path.join(cwd, ".mcp.json"))
    if d and has_cmm(d.get("mcpServers")):
        return True

    # Scope 2 + 3: user ~/.claude.json (top-level mcpServers + projects.<cwd>)
    d = load_json(os.path.join(home, ".claude.json"))
    if d:
        if has_cmm(d.get("mcpServers")):
            return True
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
                    if has_cmm(entry.get("mcpServers")):
                        return True

    # Scope 4: managed settings (org-provisioned)
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
            if d and has_cmm(d.get("mcpServers")):
                return True
        dropin = os.path.join(mdir, "managed-settings.d")
        if os.path.isdir(dropin):
            try:
                for f in sorted(os.listdir(dropin)):
                    if f.startswith(".") or not f.endswith(".json"):
                        continue
                    d = load_json(os.path.join(dropin, f))
                    if d and has_cmm(d.get("mcpServers")):
                        return True
            except Exception:
                pass

    # Scope 5: plugin-bundled .mcp.json files
    plugin_root = os.path.join(home, ".claude", "plugins")
    if os.path.isdir(plugin_root):
        try:
            for plugin_mcp in glob.glob(os.path.join(plugin_root, "*", ".mcp.json")):
                d = load_json(plugin_mcp)
                if d and has_cmm(d.get("mcpServers")):
                    return True
        except Exception:
            pass

    return False

try:
    if cmm_registered():
        print("true")
    else:
        print("false")
except Exception:
    print("false")
PY
)

if [[ "${CMM_REGISTERED}" != "true" ]]; then
    printf "CMM: not registered\n"
    exit 0
fi

# ---------------------------------------------------------------------------
# STEP 2 — CLI availability check.
# ---------------------------------------------------------------------------

if ! command -v codebase-memory-mcp >/dev/null 2>&1; then
    printf "CMM_CLI_MISSING=true — reactive Claude-mediated index will run at first query\n"
    exit 0
fi

# ---------------------------------------------------------------------------
# STEP 3 — Baseline presence check.
# Windows/MINGW64: git rev-parse --show-toplevel returns Unix-style path;
# cmm v0.5.7 normalizes paths internally so no pwd -W conversion needed.
# ---------------------------------------------------------------------------

REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
BASELINE_FILE="${REPO_PATH}/.claude/cmm-baseline.md"

if [[ ! -f "${BASELINE_FILE}" ]]; then
    MODE="FIRST_INDEX"
else
    MODE="DRIFT_CHECK"
fi

# ---------------------------------------------------------------------------
# Helper: derive project slug from repo path.
# cmm path-slug: full abs path with / and \ replaced by -.
# ---------------------------------------------------------------------------
derive_slug() {
    local rp="$1"
    # Replace both / and \ with -; strip leading -
    printf '%s' "${rp}" | python3 -c "
import sys
p = sys.stdin.read().strip()
p = p.replace('\\\\', '-').replace('/', '-')
p = p.lstrip('-')
print(p)
"
}

# ---------------------------------------------------------------------------
# Helper: parse a YAML frontmatter scalar from baseline file.
# Usage: parse_baseline_field <file> <field>
# Reads lines between first --- and second --- delimiters.
# ---------------------------------------------------------------------------
parse_baseline_field() {
    local file="$1"
    local field="$2"
    awk -v key="${field}" '
        /^---$/ { fm_count++; next }
        fm_count == 1 && /^[a-z_]+:/ {
            split($0, a, /: */); if (a[1] == key) { print a[2]; exit }
        }
        fm_count >= 2 { exit }
    ' "${file}"
}

# ---------------------------------------------------------------------------
# Helper: write minimal .claude/cmm-baseline.md (FIRST_INDEX path).
# Preserves no sections — this is a fresh write.
# ---------------------------------------------------------------------------
write_baseline_first() {
    local file="$1"
    local slug="$2"
    local nodes="$3"
    local edges="$4"
    local file_count="$5"
    local ref="$6"
    local now
    now=$(python3 -c "import datetime; print(datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))")

    cat > "${file}" <<BASELINE
---
project_slug: ${slug}
nodes: ${nodes}
edges: ${edges}
file_count: ${file_count}
last_indexed_ref: ${ref}
last_index_mode: full
last_indexed_at: ${now}
---

# CMM Baseline

Generated: ${now}
Managed by: /cmm-baseline skill + .claude/hooks/cmm-index-startup.sh

## Sentinels
# Add stable symbol names here — hook probes each on every session start.
# Example: - MyEntryPointClass  # entry point

## Framework blind spots
# Empirical — do NOT trust these cmm queries for listed Node types.
# Example: - Route: unreliable for attribute-routing frameworks

## Known-broken tools
# Upstream issues or empirical. Example: - cmm.search_code: upstream #250

## Routing overrides
# Project-specific. Example: # Blazor .razor -> text grep fallback
BASELINE
}

# ---------------------------------------------------------------------------
# Helper: update hook-managed YAML frontmatter fields in baseline file,
# preserving all markdown body sections (sentinels, blind-spots, etc.).
# Fields updated: nodes, edges, last_indexed_ref, last_indexed_at.
# ---------------------------------------------------------------------------
update_baseline_counts() {
    local file="$1"
    local nodes="$2"
    local edges="$3"
    local ref="$4"
    python3 - "${file}" "${nodes}" "${edges}" "${ref}" <<'PY'
import sys, re

path, nodes, edges, ref = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
import datetime
now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

def replace_field(text, key, value):
    pattern = re.compile(r'^(' + re.escape(key) + r':)[ \t]*.*$', re.MULTILINE)
    return pattern.sub(r'\g<1> ' + value, text)

content = replace_field(content, "nodes", nodes)
content = replace_field(content, "edges", edges)
content = replace_field(content, "last_indexed_ref", ref)
content = replace_field(content, "last_indexed_at", now)
content = replace_field(content, "last_index_mode", "full")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("ok")
PY
}

# ---------------------------------------------------------------------------
# Helper: parse index_status JSON output for nodes, edges, status.
# Accepts the raw CLI stdout. Uses python3 for JSON parse.
# ---------------------------------------------------------------------------
parse_index_status() {
    local raw="$1"
    local field="$2"
    printf '%s' "${raw}" | python3 -c "
import sys, json
try:
    raw = sys.stdin.read()
    d = json.loads(raw)
    # Tolerate both top-level and nested under 'result' or 'content'
    if isinstance(d, dict):
        v = d.get('${field}') or d.get('result', {}).get('${field}') if isinstance(d.get('result'), dict) else d.get('${field}')
        print(v if v is not None else '')
    else:
        print('')
except Exception:
    print('')
" 2>/dev/null || printf ''
}

# ---------------------------------------------------------------------------
# STEP 4a — FIRST_INDEX mode.
# ---------------------------------------------------------------------------

if [[ "${MODE}" == "FIRST_INDEX" ]]; then
    printf "CMM_FIRST_INDEX=true — running full index (blocking)\n"

    INDEX_OUTPUT=""
    if ! INDEX_OUTPUT=$(codebase-memory-mcp cli index_repository "{\"repo_path\":\"${REPO_PATH}\",\"mode\":\"full\"}" 2>&1); then
        printf "CMM_HOOK_FAILED: first_index_failed — CLI returned non-zero\n" >&2
        exit 0
    fi

    SLUG=$(derive_slug "${REPO_PATH}")

    STATUS_OUTPUT=""
    STATUS_OUTPUT=$(codebase-memory-mcp cli index_status "{\"project\":\"${SLUG}\"}" 2>/dev/null || printf '{}')

    CURRENT_NODES=$(parse_index_status "${STATUS_OUTPUT}" "nodeCount")
    CURRENT_EDGES=$(parse_index_status "${STATUS_OUTPUT}" "edgeCount")
    CURRENT_FILE_COUNT=$(parse_index_status "${STATUS_OUTPUT}" "fileCount")
    CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || printf "")

    # get_graph_schema for schema awareness (best-effort; non-fatal if CLI form differs)
    codebase-memory-mcp cli get_graph_schema "{\"project\":\"${SLUG}\"}" >/dev/null 2>&1 || true

    mkdir -p "${REPO_PATH}/.claude"
    write_baseline_first \
        "${BASELINE_FILE}" \
        "${SLUG}" \
        "${CURRENT_NODES:-0}" \
        "${CURRENT_EDGES:-0}" \
        "${CURRENT_FILE_COUNT:-0}" \
        "${CURRENT_SHA:-unknown}"

    printf "CMM_STATE: first_index=true nodes=%s edges=%s ref=%s\n" \
        "${CURRENT_NODES:-0}" "${CURRENT_EDGES:-0}" "${CURRENT_SHA:-unknown}"
    exit 0
fi

# ---------------------------------------------------------------------------
# STEP 4b — DRIFT_CHECK mode (zero-drift policy).
# ---------------------------------------------------------------------------

# Parse baseline scalar fields (YAML frontmatter, grep/awk, no python yaml parser)
BASELINE_SLUG=$(parse_baseline_field "${BASELINE_FILE}" "project_slug")
BASELINE_NODES=$(parse_baseline_field "${BASELINE_FILE}" "nodes")
BASELINE_EDGES=$(parse_baseline_field "${BASELINE_FILE}" "edges")
BASELINE_SHA=$(parse_baseline_field "${BASELINE_FILE}" "last_indexed_ref")

# Fall back to derived slug if baseline doesn't have one yet
if [[ -z "${BASELINE_SLUG}" ]]; then
    BASELINE_SLUG=$(derive_slug "${REPO_PATH}")
fi

CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || printf "")

# Run index_status to get live counts
LIVE_STATUS_OUTPUT=""
LIVE_STATUS_OUTPUT=$(codebase-memory-mcp cli index_status "{\"project\":\"${BASELINE_SLUG}\"}" 2>/dev/null || printf '{}')

LIVE_NODES=$(parse_index_status "${LIVE_STATUS_OUTPUT}" "nodeCount")
LIVE_EDGES=$(parse_index_status "${LIVE_STATUS_OUTPUT}" "edgeCount")
LIVE_INDEX_STATUS=$(parse_index_status "${LIVE_STATUS_OUTPUT}" "status")

# ---------------------------------------------------------------------------
# Drift detection — zero drift tolerance, run all 4 checks.
# ---------------------------------------------------------------------------

DRIFT_REASON=""

# (a) git SHA mismatch
if [[ -n "${CURRENT_SHA}" && -n "${BASELINE_SHA}" && "${CURRENT_SHA}" != "${BASELINE_SHA}" ]]; then
    DRIFT_REASON="sha_mismatch"
fi

# (b) node count mismatch
if [[ -z "${DRIFT_REASON}" && -n "${LIVE_NODES}" && -n "${BASELINE_NODES}" && "${LIVE_NODES}" != "${BASELINE_NODES}" ]]; then
    DRIFT_REASON="node_count_mismatch"
fi

# (b) edge count mismatch
if [[ -z "${DRIFT_REASON}" && -n "${LIVE_EDGES}" && -n "${BASELINE_EDGES}" && "${LIVE_EDGES}" != "${BASELINE_EDGES}" ]]; then
    DRIFT_REASON="edge_count_mismatch"
fi

# (c) index_status != "ready"
if [[ -z "${DRIFT_REASON}" && -n "${LIVE_INDEX_STATUS}" && "${LIVE_INDEX_STATUS}" != "ready" ]]; then
    DRIFT_REASON="index_not_ready:${LIVE_INDEX_STATUS}"
fi

# (d) Sentinel probe — only if sentinels section is non-empty
SENTINEL_DRIFT_NAME=""
if [[ -z "${DRIFT_REASON}" ]]; then
    # Extract sentinel lines from baseline body (lines starting with "- " after ## Sentinels)
    SENTINELS=$(awk '
        /^## Sentinels/ { in_section=1; next }
        in_section && /^## / { in_section=0 }
        in_section && /^- / {
            sub(/^- /, ""); sub(/ *#.*/, ""); sub(/^[ \t]+|[ \t]+$/, ""); print
        }
    ' "${BASELINE_FILE}" | grep -v '^$' || true)

    if [[ -n "${SENTINELS}" ]]; then
        while IFS= read -r sentinel; do
            [[ -z "${sentinel}" ]] && continue
            PROBE_OUTPUT=""
            PROBE_OUTPUT=$(codebase-memory-mcp cli search_graph \
                "{\"project\":\"${BASELINE_SLUG}\",\"name_pattern\":\"${sentinel}\"}" \
                2>/dev/null || printf '[]')
            # If output is empty array or empty string, sentinel missing
            NORMALIZED=$(printf '%s' "${PROBE_OUTPUT}" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
if not raw or raw == '[]' or raw == 'null':
    print('empty')
else:
    try:
        d = json.loads(raw)
        if isinstance(d, list) and len(d) == 0:
            print('empty')
        elif isinstance(d, dict) and not d:
            print('empty')
        else:
            print('found')
    except Exception:
        print('found')
" 2>/dev/null || printf 'found')
            if [[ "${NORMALIZED}" == "empty" ]]; then
                SENTINEL_DRIFT_NAME="${sentinel}"
                DRIFT_REASON="sentinel_missing:${sentinel}"
                break
            fi
        done <<< "${SENTINELS}"
    fi
fi

# (e) Age-based staleness — even with matching SHA + counts, force sanity probe
#     on slow-moving projects where the graph could have silently rotted.
#     Parses last_indexed_at from baseline YAML frontmatter; fail-open on any
#     parse error (age check errors must never block session start).
if [[ -z "${DRIFT_REASON}" ]]; then
    BASELINE_AGE_DAYS=$(python3 - "${BASELINE_FILE}" <<'PY' 2>/dev/null || printf '0'
import sys, re, datetime
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    m = re.search(r'^last_indexed_at:\s*(\S+)\s*$', content, re.MULTILINE)
    if not m:
        print(0)
        sys.exit(0)
    ts_raw = m.group(1).rstrip("Z")
    ts = datetime.datetime.fromisoformat(ts_raw)
    age = (datetime.datetime.utcnow() - ts).days
    print(age if age >= 0 else 0)
except Exception:
    print(0)
PY
)
    # Clamp to int; any non-numeric value treated as 0 (fail-open)
    if ! [[ "${BASELINE_AGE_DAYS}" =~ ^[0-9]+$ ]]; then
        BASELINE_AGE_DAYS=0
    fi
    if [[ "${BASELINE_AGE_DAYS}" -gt 7 ]]; then
        DRIFT_REASON="baseline_age_${BASELINE_AGE_DAYS}_days"
    fi
fi

# ---------------------------------------------------------------------------
# No drift path.
# ---------------------------------------------------------------------------

if [[ -z "${DRIFT_REASON}" ]]; then
    printf "CMM_STATE: nodes=%s edges=%s ref=%s fresh=true\n" \
        "${BASELINE_NODES:-?}" "${BASELINE_EDGES:-?}" "${CURRENT_SHA:-unknown}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Drift detected — full reindex.
# ---------------------------------------------------------------------------

printf "CMM_DRIFT: reason=%s baseline_sha=%s current_sha=%s baseline_nodes=%s current_nodes=%s\n" \
    "${DRIFT_REASON}" \
    "${BASELINE_SHA:-unknown}" \
    "${CURRENT_SHA:-unknown}" \
    "${BASELINE_NODES:-?}" \
    "${LIVE_NODES:-?}"

printf "CMM: running full reindex (blocking)\n" >&2

REINDEX_OUTPUT=""
if ! REINDEX_OUTPUT=$(codebase-memory-mcp cli index_repository \
    "{\"repo_path\":\"${REPO_PATH}\",\"mode\":\"full\"}" 2>&1); then
    printf "CMM_HOOK_FAILED: drift_reindex_failed — CLI returned non-zero\n" >&2
    exit 0
fi

# Re-read status after reindex
NEW_STATUS_OUTPUT=""
NEW_STATUS_OUTPUT=$(codebase-memory-mcp cli index_status \
    "{\"project\":\"${BASELINE_SLUG}\"}" 2>/dev/null || printf '{}')

NEW_NODES=$(parse_index_status "${NEW_STATUS_OUTPUT}" "nodeCount")
NEW_EDGES=$(parse_index_status "${NEW_STATUS_OUTPUT}" "edgeCount")

# get_graph_schema for schema awareness (best-effort)
codebase-memory-mcp cli get_graph_schema "{\"project\":\"${BASELINE_SLUG}\"}" >/dev/null 2>&1 || true

# Update baseline YAML frontmatter counts; preserve all markdown body sections.
UPDATE_RESULT=""
UPDATE_RESULT=$(update_baseline_counts \
    "${BASELINE_FILE}" \
    "${NEW_NODES:-0}" \
    "${NEW_EDGES:-0}" \
    "${CURRENT_SHA:-unknown}" \
    2>&1) || {
    printf "CMM_HOOK_FAILED: baseline_update_failed — %s\n" "${UPDATE_RESULT}" >&2
    exit 0
}

# Sentinel drift: log to .learnings/log.md (trigger d only).
if [[ "${DRIFT_REASON}" == sentinel_missing:* ]]; then
    MISSING_SENTINEL="${DRIFT_REASON#sentinel_missing:}"
    LOG_DATE=$(date -u +%Y-%m-%d 2>/dev/null || printf "unknown-date")
    printf "### %s — correction: cmm sentinel missing: %s\n" \
        "${LOG_DATE}" "${MISSING_SENTINEL}" \
        >> "${REPO_PATH}/.learnings/log.md" 2>/dev/null || true
fi

printf "CMM_STATE: reindexed=true nodes=%s edges=%s ref=%s fresh=true\n" \
    "${NEW_NODES:-0}" "${NEW_EDGES:-0}" "${CURRENT_SHA:-unknown}"
exit 0
CMM_HOOK_SH

chmod +x "$TARGET"

if ! bash -n "$TARGET"; then
  printf "ERROR: bash -n syntax check failed on %s after write\n" "$TARGET"
  exit 1
fi

if ! grep -q 'cmm-index-startup sentinel' "$TARGET"; then
  printf "ERROR: sentinel comment missing from %s after write\n" "$TARGET"
  exit 1
fi

printf "INSTALLED: %s (chmod +x, bash -n passed, sentinel present)\n" "$TARGET"
```

---

### Step 3 — Install `.claude/skills/cmm-baseline/SKILL.md`

Branch on `HAS_SKILL`:
- `HAS_SKILL=yes` → SKIP (skill YAML frontmatter already present).
- Otherwise → `mkdir -p .claude/skills/cmm-baseline`, write SKILL.md via quoted heredoc `<<'CMM_SKILL_MD'`, verify YAML parses.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/skills/cmm-baseline/SKILL.md"

if [[ -n "${HAS_SKILL:-}" ]]; then
  printf "SKIP: %s already contains '^name: cmm-baseline' YAML frontmatter\n" "$TARGET"
  exit 0
fi

mkdir -p .claude/skills/cmm-baseline

cat > "$TARGET" <<'CMM_SKILL_MD'
---
name: cmm-baseline
description: >
  Use when managing the CMM per-project baseline. Run /cmm-baseline init at
  bootstrap completion, /cmm-baseline refresh after large refactors, /cmm-baseline
  check for read-only drift report, /cmm-baseline verify-sentinels for correctness gate.
  Writes .claude/cmm-baseline.md — the committed source of truth for healthy cmm graph state.
model: sonnet
effort: medium
allowed-tools: Read Write Edit Bash Grep Glob
user-invocable: true
argument-hint: init | refresh | check | verify-sentinels
---

# cmm-baseline

Manage the per-project CMM baseline file `.claude/cmm-baseline.md`. The baseline is
the **committed source of truth** for a healthy `codebase-memory-mcp` graph state:
node/edge counts, per-label counts, framework blind spots, sentinels, known-broken
tools, and routing overrides.

The baseline is consumed by three layers:

1. `.claude/hooks/cmm-index-startup.sh` — SessionStart hook reads baseline, compares
   git SHA + node/edge counts, triggers full reindex on any drift (zero-drift policy).
2. `/cmm-baseline verify-sentinels` — correctness gate; asserts every sentinel symbol
   is present in the current graph.
3. Claude (main thread + sub-agents) — consults baseline for framework blind spots and
   routing overrides before running symbol queries against unreliable Node types.

This skill runs on the main thread only. It is **not forkable** — framework detection
and multi-file inspection require full main-thread tool access.

---

## STEP 0 — Force-Reads (mandatory first action)

Before any command runs, Read these rule files in parallel:

- `.claude/rules/general.md`
- `.claude/rules/max-quality.md`
- `.claude/rules/mcp-routing.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`

If a force-read file does not exist on the current project, note it and continue —
do not stop.

---

## Pre-Flight (runs for every command)

1. Check `.mcp.json` at project root. If missing OR it does not contain
   `codebase-memory-mcp` under `mcpServers`:
   ```
   STOP with error: "cmm-baseline requires codebase-memory-mcp registered in .mcp.json.
   Register the server first (see modules/08-verification.md MCP setup section) and retry."
   ```
2. Check `.claude/agents/proj-researcher.md` exists. If missing, framework detection
   falls back to direct project-file inspection (manifest parsing without dispatch).
   Continue; do not stop.
3. Confirm `mcp__codebase-memory-mcp__*` tool schemas are loaded in this session. If
   the deferred-tools contract applies, call:
   ```
   ToolSearch select:mcp__codebase-memory-mcp__index_repository,mcp__codebase-memory-mcp__index_status,mcp__codebase-memory-mcp__get_graph_schema,mcp__codebase-memory-mcp__search_graph,mcp__codebase-memory-mcp__list_projects
   ```
   BEFORE invoking any cmm tool. Missing schemas fail the command — load them.

---

## Command: `/cmm-baseline init`

First-time seed of `.claude/cmm-baseline.md`. Runs a full index, detects frameworks,
picks sentinels, writes the baseline, self-checks.

### Steps

1. **Pre-flight** (above).

2. **Run full index.** Invoke `mcp__codebase-memory-mcp__index_repository` with
   `repo_path` = absolute project root and `mode` = `"full"`. Block until the call
   returns. Timing expectations:
   - Tiny repo (<1k nodes): <1s
   - Medium repo (~50k LOC): ~6s
   - Large repo (~10k nodes, ~200k LOC C#): ~20-60s
   - Giant repo (monorepo, 75k files): ~3min
   If the call fails, report the error and stop. Do not write a partial baseline.

3. **Read the resulting graph state.**
   - Call `mcp__codebase-memory-mcp__list_projects` to resolve the cmm path-slug for
     the current working directory (slug = full absolute path with `/` and `\`
     replaced by `-`). Match by suffix against the returned list.
   - Call `mcp__codebase-memory-mcp__index_status` with `{"project": "<slug>"}` —
     extract `nodes`, `edges`, `file_count`, `status`.
   - Call `mcp__codebase-memory-mcp__get_graph_schema` with `{"project": "<slug>"}` —
     extract per-label node counts.
   - If `status != "ready"`, report the discrepancy and stop.

4. **Detect frameworks.** Inspect project manifest files:
   - `*.csproj`, `*.sln`, `Directory.Packages.props` — parse `<PackageReference Include="...">`
     entries for known framework signals.
   - `package.json` — parse `dependencies` and `devDependencies` for framework signals.
   - `pyproject.toml`, `requirements.txt`, `Pipfile`, `setup.py` — parse Python deps.
   - `Cargo.toml` — parse Rust crates.
   - `Gemfile` — parse Ruby gems.
   - `go.mod` — parse Go modules.
   - `composer.json` — parse PHP packages.
   For each detected manifest, look up matching entries in
   `references/framework-catalog.md`. Record hits as `(framework_name, blind_spot_label,
   fallback_pattern)` tuples. Unknown frameworks → no blind-spot entry; not an error.

5. **Pick sentinels.** Select 3-5 stable symbols the reindex must always find:
   - Priority 1: canonical entry-point names present in the graph — `Program`, `main`,
     `App`, `Application`, `index`, `Startup`. Call
     `mcp__codebase-memory-mcp__search_graph` with `name_pattern=<name>` for each
     candidate; include only matches that return ≥1 hit.
   - Priority 2: known framework base classes from detected frameworks (e.g. if
     FastEndpoints detected, `Endpoint` base symbol). Query the same way.
   - Priority 3: top 3 symbols by `Method` label count — query
     `mcp__codebase-memory-mcp__query_graph` with a Cypher that orders methods by
     cross-reference count descending, returning the top 3 names. Pick names that
     survive typical refactors (framework-exposed methods, public API surface).
   - Cap the final list at 5 sentinels. Fewer is fine; zero is a hard error —
     report "no stable sentinels found, graph may be near-empty" and stop.

6. **Populate routing overrides (conditional).** For each framework blind-spot,
   emit a line of the form:
   ```
   # {Node_label} queries unreliable under {framework} -> prefer {fallback_pattern}
   ```
   Do NOT hardcode specific MCP server names in overrides — use generic descriptions
   ("LSP-based parsers", "graph-indexed tools") when referring to tool classes.

7. **Write `.claude/cmm-baseline.md`.** Use the template below (YAML frontmatter
   + markdown body). All fields are mandatory except `Routing overrides` which may
   be empty when no framework blind-spots were detected.

   ```markdown
   ---
   project_slug: {cmm_path_slug}
   last_indexed_ref: {git_sha_or_empty_if_not_git}
   last_index_mode: full
   last_indexed_at: {ISO8601_UTC}
   nodes: {N}
   edges: {E}
   file_count: {F}
   nodes_per_file: {N/F_two_decimals}
   ---

   # CMM Baseline
   Generated: {ISO8601_UTC} | Managed by: /cmm-baseline + .claude/hooks/cmm-index-startup.sh

   ## Per-label counts
   {label_1}: {count_1}
   {label_2}: {count_2}
   ...

   ## Sentinels
   - {sentinel_1}  # {why stable — e.g., "entry point", "framework base class", "stable public API"}
   - {sentinel_2}  # {reason}
   ...

   ## Framework blind spots
   - {Node_label}: {X/Y coverage}  # {framework} — use {fallback}
   ...

   ## Known-broken tools
   - cmm.{tool}: {reason}  # fallback: {alternative}
   ...

   ## Routing overrides
   # {pattern_description} -> prefer {tool} over {default}
   ...
   ```

8. **Self-check.** Run `/cmm-baseline verify-sentinels` as the final step. Any
   missing sentinel → revert the baseline write (or leave the broken baseline in
   place with a warning), report the failure, and stop. All present → report success
   with summary `baseline seeded: nodes=N edges=E sentinels=K frameworks=M`.

---

## Command: `/cmm-baseline refresh`

Force full reindex + rebaseline. Preserves user-managed sections by default.

### Steps

1. **Pre-flight.**

2. **Parse existing baseline** at `.claude/cmm-baseline.md`. Read the YAML frontmatter
   fields and the four body sections (`Sentinels`, `Framework blind spots`,
   `Known-broken tools`, `Routing overrides`). If the file is missing, report
   "no baseline found — run /cmm-baseline init first" and stop.

3. **Run full index** via `mcp__codebase-memory-mcp__index_repository(mode="full")`.
   Block until complete. Same timing expectations as `init`.

4. **Re-read graph state** — `index_status` + `get_graph_schema` — extract fresh
   counts and per-label counts.

5. **Update YAML frontmatter fields.** Replace `nodes`, `edges`, `file_count`,
   `nodes_per_file`, `last_indexed_ref` (fresh `git rev-parse HEAD` if this is a
   git repo), `last_indexed_at` (current ISO8601 UTC). Leave `project_slug` and
   `last_index_mode: full` unchanged.

6. **Update `## Per-label counts` body section** with fresh counts.

7. **Preserve user-managed sections** — `Sentinels`, `Framework blind spots`,
   `Known-broken tools`, `Routing overrides` — UNLESS the user passed `--full-regen`
   as an argument. With `--full-regen`:
   - Clear all four user-managed sections.
   - Re-run framework detection (step 4 of `init`).
   - Re-pick sentinels (step 5 of `init`).
   - Re-populate routing overrides (step 6 of `init`).

8. **Write the updated baseline file.**

9. **Self-check** via `/cmm-baseline verify-sentinels`. Report success with summary
   `baseline refreshed: nodes=N (was M) edges=E (was F) ref=<sha>`.

---

## Command: `/cmm-baseline check`

Read-only drift report. Never writes.

### Steps

1. **Pre-flight.**

2. **Parse existing baseline.** Missing → report "no baseline" and stop.

3. **Read current graph state** — `index_status` + `get_graph_schema`. Do NOT run
   `index_repository`.

4. **Compare** against baseline:
   - `last_indexed_ref` vs current `git rev-parse HEAD` (if git repo)
   - `nodes` vs current `index_status.nodes`
   - `edges` vs current `index_status.edges`
   - Per-label counts — any label in baseline missing from current, or any current
     label missing from baseline, or any count delta ≥ 10% of baseline value

5. **Report drift to the user** as a structured summary:
   ```
   CMM drift report for {project_slug}
     baseline:  nodes={N}  edges={E}  ref={SHA}  labels={K}
     current:   nodes={M}  edges={F}  ref={SHA}  labels={L}
     deltas:    nodes={+/-dN}  edges={+/-dE}  sha={changed|same}
     label deltas (if any): {label}: {baseline_count}->{current_count}
     recommendation: {fresh | drift — run /cmm-baseline refresh | stale — reindex required}
   ```
   Do NOT write any file. Do NOT run any mutation. Exit with the report.

---

## Command: `/cmm-baseline verify-sentinels`

Correctness gate. Asserts every sentinel from the baseline is currently present in
the cmm graph. Runs after any reindex (self-check) or on demand.

### Steps

1. **Pre-flight.**

2. **Parse baseline** `## Sentinels` section. Empty or missing → report "no sentinels
   defined in baseline" and exit success (nothing to verify).

3. **For each sentinel**, call `mcp__codebase-memory-mcp__search_graph` with
   `name_pattern=<sentinel_name>` and whatever label constraint is recorded in the
   baseline comment (fallback: no label constraint).
   - ≥1 hit → mark PASS
   - 0 hits → mark FAIL, record the sentinel name + line reference

4. **If ANY sentinel failed**:
   - Append a line to `.learnings/log.md` in the format:
     ```
     ### {YYYY-MM-DD} — correction: cmm sentinel missing after reindex: {sentinel_name}
     - Project: {project_slug}
     - Expected label: {label_from_baseline}
     - Reindex ref: {current_git_sha}
     - Baseline ref: {baseline_last_indexed_ref}
     - Recommended action: /cmm-baseline refresh (or investigate structural drift)
     ```
   - Report the failure to the user: which sentinels are missing, the recommended
     action (`/cmm-baseline refresh --full-regen` is appropriate when the project
     underwent a large refactor; a plain refresh when only counts drifted).
   - Exit with a non-zero status indication (report the failure; do not silently pass).

5. **All present** → report `verify-sentinels PASS: {K} sentinels verified
   (nodes={N} edges={E} ref={SHA})`. Exit success.

---

## Reference material

`references/framework-catalog.md` — generic catalog of framework blind spots
keyed by detection signal (package name, manifest path). Content hygiene:
**zero third-party MCP server names**. Use generic tool-class descriptions only.

---

## Failure modes + recovery

| Symptom | Cause | Recovery |
|---|---|---|
| Pre-flight STOP: cmm not registered | `.mcp.json` missing codebase-memory-mcp | Register the server, retry |
| `index_repository` hangs >10min | Pathological repo, tooling bug | Cancel, check index_status, file upstream bug report |
| Sentinel self-check FAIL after init | Picked unstable symbols | Re-run with more conservative picks (entry points only) |
| `verify-sentinels` FAIL on existing baseline | Refactor removed the symbol | Run `/cmm-baseline refresh --full-regen` to re-pick sentinels |
| `check` reports drift but `refresh` produces identical counts | cmm graph already fresh | Harmless; baseline already matches current state |
| `list_projects` returns no matching slug | Project never indexed or slug mismatch | Run `/cmm-baseline init` first |

---

## Rationale

- **Why committed to git**: team members share the healthy-state definition, reducing
  "works for me" drift in distributed teams.
- **Why sentinels**: exact node/edge counts fluctuate on every commit; sentinels are
  semantic guarantees that survive normal refactors.
- **Why main-thread only**: framework detection + file inspection need full tool
  access; sub-agent forks add latency for no quality gain on this workload.
- **Why zero-drift policy**: partial indexes are silent correctness bugs
  (tree-sitter 75-89% accuracy tier on some languages); fresh full index is cheap
  enough to demand on every session start via the SessionStart hook.
CMM_SKILL_MD

if ! python3 -c "
import sys, yaml
with open('$TARGET', 'r', encoding='utf-8') as f:
    content = f.read()
parts = content.split('---', 2)
if len(parts) < 3:
    sys.exit('frontmatter not found')
data = yaml.safe_load(parts[1])
if data.get('name') != 'cmm-baseline':
    sys.exit('name field mismatch: ' + str(data.get('name')))
print('ok')
" 2>&1; then
  printf "WARN: YAML parse check failed (python yaml may be unavailable — falling back to grep)\n" >&2
fi

if ! grep -q '^name: cmm-baseline' "$TARGET"; then
  printf "ERROR: '^name: cmm-baseline' sentinel missing from %s after write\n" "$TARGET"
  exit 1
fi

printf "INSTALLED: %s\n" "$TARGET"
```

---

### Step 4 — Install `.claude/skills/cmm-baseline/references/framework-catalog.md`

Branch on `HAS_CATALOG`:
- `HAS_CATALOG=yes` → SKIP (catalog header present).
- Otherwise → `mkdir -p .claude/skills/cmm-baseline/references`, write catalog via quoted heredoc.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/skills/cmm-baseline/references/framework-catalog.md"

if [[ -n "${HAS_CATALOG:-}" ]]; then
  printf "SKIP: %s already contains '# Framework Catalog' header\n" "$TARGET"
  exit 0
fi

mkdir -p .claude/skills/cmm-baseline/references

cat > "$TARGET" <<'CMM_CATALOG_MD'
# Framework Catalog — CMM Blind Spots

Generic catalog of framework-specific blind spots in graph-indexed / LSP-based
code memory tools. Used by `/cmm-baseline init` to populate the per-project
`.claude/cmm-baseline.md` `## Framework blind spots` and `## Routing overrides`
sections.

**Content hygiene**: this file contains ZERO third-party MCP server / product names.
When a blind spot exists because "LSP-based parsers don't handle X", the catalog
says exactly that — generic tool-class descriptions only. Fallback entries reference
tool classes ("graph-indexed tools", "text search with glob scope"), never specific
products.

Detection signal → blind spot mapping. Per-signal entries include:
- Package / file signal
- Blind-spot label (which cmm `Node` type becomes unreliable)
- Reason (why the blind spot exists)
- Fallback pattern (what to do instead)
- Evidence tier (empirical = observed in the field, documented = upstream-confirmed)

---

## C# / .NET

Detection files: `*.csproj`, `*.sln`, `Directory.Packages.props`, `global.json`.

### FastEndpoints
- Package signal: `FastEndpoints` in `<PackageReference>`
- Blind spot: `Route` node type — coverage empirically 2/37 on real projects
- Reason: attribute-based route registration hidden behind compile-time source
  generators; LSP-based parsers skip generated partial declarations
- Fallback: traverse `INHERITS` edges from the project's `EndpointBase`-style
  class (each endpoint type subclasses the base); enumerate subclasses via
  graph-indexed `INHERITS` query, then read each endpoint's `Configure` /
  `HandleAsync` method
- Evidence tier: empirical

### ASP.NET Minimal API
- File signal: `Program.cs` containing `MapGet` / `MapPost` / `MapPut` / `MapDelete` calls
- Blind spot: `Route` node type — route definitions live in top-level statements,
  not as discoverable methods
- Reason: minimal API route registration is imperative top-level code; no named
  symbol to index as a route
- Fallback: text search with file glob scoped to `Program.cs` and startup modules
- Evidence tier: empirical

### ASP.NET MVC / WebAPI (classic)
- Package signal: `Microsoft.AspNetCore.Mvc` in `<PackageReference>`
- Blind spot: attribute-routed controllers — `[Route]` / `[HttpGet]` / `[HttpPost]`
  bindings may not be indexed as `Route` nodes
- Reason: attributes are metadata on `Controller` methods; parsers vary on whether
  they promote attribute-routed methods into a dedicated Route label
- Fallback: find subclasses of `ControllerBase` / `Controller` via graph `INHERITS`
  query, inspect each action method for the attribute pattern
- Evidence tier: empirical

### Blazor
- Package signal: `Microsoft.AspNetCore.Components` in `<PackageReference>`
- File signal: `*.razor` files
- Blind spot: `.razor` markup files — NOT parseable by LSP-based parsers at all
- Reason: Razor is a hybrid markup + C# syntax requiring a dedicated compiler pass;
  general-purpose LSP-based tools skip these files
- Fallback: text search scoped via `paths_include_glob="**/*.razor"`; for
  code-behind `.razor.cs` partial classes, normal symbol lookup works
- Evidence tier: empirical

### Source generators
- File signal: `*.g.cs` files in `obj/` directories
- Blind spot: generated code is excluded by default in most index configurations
- Reason: source-generated files are build artifacts, not source of truth
- Fallback: never reference generated code directly; query the generator's input
  attributes / source classes instead
- Evidence tier: documented

### gRPC / protobuf (C#)
- Package signal: `Grpc.Tools` in `<PackageReference>`
- Blind spot: `*.proto`-generated classes may not be in the graph
- Reason: `.proto` compilation is a build-time generator; the generated
  `*.g.cs` files are typically excluded
- Fallback: read the `*.proto` file directly; match service / message names
  against call sites in text search
- Evidence tier: documented

---

## TypeScript / JavaScript

Detection files: `package.json`, `tsconfig.json`, `yarn.lock`, `pnpm-lock.yaml`.

### Next.js (app router)
- Package signal: `next` in `package.json` dependencies; presence of `app/`
  directory containing `page.tsx` / `layout.tsx` files
- Blind spot: route tree — filesystem-based, not symbol-based
- Reason: Next.js app router infers routes from directory structure at build time;
  no named symbol represents a route
- Fallback: file-tree traversal under `app/**/page.tsx`; text search for specific
  route paths
- Evidence tier: documented

### Next.js (pages router)
- Package signal: `next` in dependencies; presence of `pages/` directory
- Blind spot: same as app router — filesystem-based routes
- Fallback: file-tree traversal under `pages/**/*.{ts,tsx,js,jsx}`
- Evidence tier: documented

### Express
- Package signal: `express` in `package.json` dependencies
- Blind spot: `Route` node type for `app.get` / `app.post` / `router.use` chains
- Reason: Express routes are registered via imperative method calls, not declarative
  definitions; some parsers track call sites but do not promote them into a Route label
- Fallback: call-site detection via graph `CALLS` edges from `Router` / `app`
  symbols; text search on `.get|.post|.put|.delete|.patch` methods
- Evidence tier: empirical

### React component libraries
- Package signal: `react`, `react-dom` in dependencies
- Blind spot: JSX usage sites — components rendered via JSX syntax are NOT tracked
  as `CALLS` edges in typical call graphs
- Reason: JSX is desugared to `React.createElement` calls at compile time; pre-sugar
  AST-based parsers miss the usage relationship
- Fallback: text search for `<ComponentName` patterns with glob scoped to `.tsx` / `.jsx`
- Evidence tier: empirical

### Vue single-file components
- File signal: `*.vue` files
- Blind spot: `.vue` markup templates — mixed script / template / style syntax not
  parseable by LSP-based tools without a dedicated Vue language server
- Fallback: text search scoped via `paths_include_glob="**/*.vue"`
- Evidence tier: documented

### Svelte components
- File signal: `*.svelte` files
- Blind spot: `.svelte` files — same hybrid-syntax problem as Vue / Razor
- Fallback: text search scoped via `paths_include_glob="**/*.svelte"`
- Evidence tier: documented

### NestJS
- Package signal: `@nestjs/core` in dependencies
- Blind spot: decorator-based controllers — `@Controller`, `@Get`, `@Post` decorators
  may not be promoted into a Route label
- Fallback: find classes decorated with `@Controller` via text search or graph
  `INHERITS` from base classes; map methods by decorator name
- Evidence tier: empirical

---

## Python

Detection files: `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile`, `Pipfile.lock`.

### Django
- Package signal: `Django` / `django` in deps
- Blind spot: URL patterns in `urls.py` — list comprehensions of `path(...)` calls
  are imperative, no Route symbols
- Reason: Django's `urlpatterns` is a runtime list; AST parsers may track call sites
  but cannot build a Route table without executing the module
- Fallback: text search on `urlpatterns` variable; AST-level parse of
  `path('...', view)` calls within `urls.py` files
- Evidence tier: documented

### Flask
- Package signal: `Flask` / `flask` in deps
- Blind spot: `@app.route` decorator-bound routes may not be promoted into Route nodes
- Reason: decorator detection varies by parser; some tools track the decorator but
  do not correlate it to a Route label
- Fallback: text search on `@app.route` / `@blueprint.route` patterns with glob scope
- Evidence tier: empirical

### FastAPI
- Package signal: `fastapi` in deps
- Blind spot: same as Flask — `@app.get` / `@app.post` / `@router.get` decorators
- Fallback: same pattern — text search on the decorator forms
- Evidence tier: empirical

### SQLAlchemy
- Package signal: `SQLAlchemy` / `sqlalchemy` in deps
- Blind spot: declarative model relationships — `relationship(...)` / `ForeignKey(...)`
  parameters are string-typed in many patterns, undetectable by static analysis
- Fallback: text search on `relationship(` / `ForeignKey(` patterns
- Evidence tier: documented

---

## Ruby

Detection file: `Gemfile`, `Gemfile.lock`, `*.gemspec`.

### Rails
- Gem signal: `rails` in Gemfile
- Blind spot: `config/routes.rb` — DSL-based route definitions using `resources`,
  `get`, `post` methods at module level
- Reason: Rails routing is a DSL evaluated at boot; no named symbol corresponds
  to a route
- Fallback: text search or AST parse of `config/routes.rb`
- Evidence tier: documented

### Sinatra
- Gem signal: `sinatra` in Gemfile
- Blind spot: inline `get '/path' do ... end` blocks — same imperative DSL problem
- Fallback: text search on `get |post|put|delete` method calls at top level
- Evidence tier: documented

---

## Rust

Detection file: `Cargo.toml`, `Cargo.lock`.

### Axum
- Crate signal: `axum` in `[dependencies]`
- Blind spot: route definitions via `Router::new().route("/path", handler)` chains —
  imperative call sites, no declarative Route symbols
- Fallback: graph `CALLS` edges from `Router::route` to handler functions; text
  search for `.route("..."` patterns
- Evidence tier: empirical

### Actix Web
- Crate signal: `actix-web` in `[dependencies]`
- Blind spot: macro-based route definitions — `#[get("/path")]` attribute macros
  are expanded at compile time, pre-expansion parsers miss the route binding
- Fallback: text search on `#[get(` / `#[post(` / `#[route(` patterns
- Evidence tier: empirical

### Rocket
- Crate signal: `rocket` in `[dependencies]`
- Blind spot: same macro-expansion problem as Actix — `#[get("/path")]`
- Fallback: same — text search on the macro attribute patterns
- Evidence tier: empirical

---

## Go

Detection file: `go.mod`, `go.sum`.

### Gin
- Module signal: `github.com/gin-gonic/gin` in `go.mod`
- Blind spot: route registration via `r.GET("/path", handler)` chains — imperative
  call sites
- Fallback: call-site detection via graph `CALLS` edges from router methods; text
  search on `.GET|.POST|.PUT|.DELETE` method invocations
- Evidence tier: empirical

### Echo
- Module signal: `github.com/labstack/echo` in `go.mod`
- Blind spot: same as Gin — `e.GET` / `e.POST` imperative call sites
- Fallback: same
- Evidence tier: empirical

### Fiber
- Module signal: `github.com/gofiber/fiber` in `go.mod`
- Blind spot: same imperative call-site pattern as Gin / Echo
- Fallback: same
- Evidence tier: empirical

### gRPC (Go)
- Module signal: `google.golang.org/grpc` in `go.mod`
- Blind spot: generated `*.pb.go` files may be excluded from indexing
- Fallback: read the `.proto` file directly; correlate service / method names
  against registration calls in `main` or server setup code
- Evidence tier: documented

---

## PHP

Detection file: `composer.json`, `composer.lock`.

### Laravel
- Package signal: `laravel/framework` in composer deps
- Blind spot: `routes/web.php` / `routes/api.php` — facade-style DSL calls
- Fallback: text search on `Route::get|post|put|delete|patch` patterns with
  glob scoped to `routes/*.php`
- Evidence tier: documented

### Symfony
- Package signal: `symfony/symfony` or `symfony/framework-bundle` in composer deps
- Blind spot: annotation-based routing (`@Route` in docblock comments) or
  attribute-based routing (`#[Route]` in PHP 8+)
- Fallback: text search on `@Route(` / `#[Route(` patterns
- Evidence tier: documented

---

## Generic blind spots (all languages)

These patterns cause silent gaps regardless of language — include them in every
project's baseline `## Framework blind spots` section when the pattern is present.

- **Attribute / decorator-based routing** — any language using attributes,
  decorators, annotations, or macros to register routes. Tree-sitter-level parsers
  often miss the attribute → symbol correlation. Fallback: text search on the
  attribute pattern.

- **Macro-expanded code** — Rust `macro_rules!`, C/C++ `#define`, Lisp macros,
  Elixir macros. Graphs are built from pre-expansion AST; expanded identifiers
  are invisible. Fallback: read the macro definition to understand the expansion;
  text search on the expansion output.

- **Source-generated code** — `*.g.cs`, `*.pb.go`, `*_pb2.py`, protobuf outputs,
  OpenAPI / GraphQL code generators, Swagger client generators. Typically
  excluded by index configurations. Fallback: never reference generated code;
  query the generator's input (`.proto`, `.graphql`, schema files) instead.

- **String-interpolated identifiers** — `getattr(obj, 'method_' + name)`,
  `eval("..." + name)`, reflection-based dispatch. Undetectable by static analysis.
  Fallback: text search on the interpolation pattern; document the runtime binding
  in the baseline `## Routing overrides` section.

- **Reflection / dynamic dispatch** — C# `MethodInfo.Invoke`, Java `Method.invoke`,
  Python `getattr` / `__getattr__`, Ruby `method_missing`. `CALLS` edges are
  silently missing for these invocations. Fallback: grep for the reflection API
  call site; manually trace possible targets.

- **Plugin / extension architectures** — any system loading code at runtime via
  `LoadFrom` / `dlopen` / `importlib.import_module`. Static graphs cannot see
  across the dynamic-load boundary. Fallback: enumerate the plugin manifest /
  directory; index each plugin as a separate project if graph traversal is needed.

- **Template engines** — Jinja2, Handlebars, Liquid, ERB, Mustache, HTML-embedded
  scripts (`.ejs`, `.pug`, `.haml`). LSP-based parsers typically skip these files
  entirely. Fallback: text search with glob scoped to the template extension.

- **DSL-style configuration** — Ruby `Rakefile`, Groovy `build.gradle`, Python
  `setup.py` / `conftest.py`, any imperative-configuration file. Structure is
  semantic to the runner, not to a symbol graph. Fallback: read the file as a
  whole; treat the DSL as opaque.

---

## Usage by `/cmm-baseline init`

1. Detect manifest files present at project root.
2. For each manifest, extract package / dependency names.
3. Match names against the catalog entries above (case-insensitive substring match
   on the signal).
4. For each match, emit a `## Framework blind spots` entry in the baseline with:
   `{Node_label}: {coverage_if_known}/{total_if_known}  # {framework} — use {fallback}`
5. For each match with a fallback that implies a routing change, emit a
   `## Routing overrides` entry:
   `# {Node_label} queries unreliable under {framework} -> prefer {fallback}`

Unknown frameworks produce no blind-spot entries — they are not an error. The
baseline grows organically as `/reflect` promotes learnings into additional
catalog entries.
CMM_CATALOG_MD

if ! grep -q '^# Framework Catalog' "$TARGET"; then
  printf "ERROR: '# Framework Catalog' sentinel missing from %s after write\n" "$TARGET"
  exit 1
fi

printf "INSTALLED: %s\n" "$TARGET"
```

---

### Step 5 — Patch `.gitignore`

Branch on `HAS_GITIGNORE_EXCEPTION`:
- `HAS_GITIGNORE_EXCEPTION=yes` → SKIP.
- Otherwise → if `.gitignore` exists and contains `.claude/` line, insert `!.claude/cmm-baseline.md` immediately after it. If `.claude/` line not present, append `!.claude/cmm-baseline.md` at end of file. If `.gitignore` does not exist, create it with the single exception line.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".gitignore"
EXCEPTION="!.claude/cmm-baseline.md"

if [[ -n "${HAS_GITIGNORE_EXCEPTION:-}" ]]; then
  printf "SKIP: %s already contains '%s'\n" "$TARGET" "$EXCEPTION"
  exit 0
fi

python3 - <<'PY'
import os

target = ".gitignore"
exception = "!.claude/cmm-baseline.md"

if not os.path.exists(target):
    with open(target, "w", encoding="utf-8") as f:
        f.write(exception + "\n")
    print("CREATED: " + target + " with " + exception)
    raise SystemExit(0)

with open(target, "r", encoding="utf-8") as f:
    lines = f.read().splitlines()

# Look for an existing ".claude/" line (exact match or bare glob form)
insert_after = -1
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped in (".claude/", ".claude", "/.claude/", "/.claude"):
        insert_after = i
        break

if insert_after >= 0:
    new_lines = lines[:insert_after + 1] + [exception] + lines[insert_after + 1:]
    with open(target, "w", encoding="utf-8") as f:
        f.write("\n".join(new_lines) + ("\n" if lines and lines[-1] != "" else ""))
    print("INSERTED: " + exception + " after '.claude/' line in " + target)
else:
    with open(target, "a", encoding="utf-8") as f:
        if lines and lines[-1] != "":
            f.write("\n")
        f.write(exception + "\n")
    print("APPENDED: " + exception + " at end of " + target)
PY

if ! grep -qxF "$EXCEPTION" "$TARGET"; then
  printf "ERROR: '%s' missing from %s after write\n" "$EXCEPTION" "$TARGET"
  exit 1
fi

printf "PATCHED: %s contains '%s'\n" "$TARGET" "$EXCEPTION"
```

---

### Step 6 — Register hook in `.claude/settings.json`

Branch on `HAS_HOOK_IN_SETTINGS`:
- `HAS_HOOK_IN_SETTINGS=yes` → SKIP.
- Otherwise → python3 `json.load` + merge + `json.dump` pattern. Appends `{"matcher": "startup", "hooks": [{"type": "command", "command": "bash .claude/hooks/cmm-index-startup.sh", "timeout": 600}]}` to `hooks.SessionStart` array. Creates `SessionStart` array if missing. Guards against JSONC `//` comments (python `json.load` fails on them — emits manual-patch instruction and exits 0 non-fatally).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/settings.json"

if [[ -n "${HAS_HOOK_IN_SETTINGS:-}" ]]; then
  printf "SKIP: %s already contains 'cmm-index-startup.sh' entry\n" "$TARGET"
  exit 0
fi

# Guard against JSONC // comments
if grep -qE '^\s*//' "$TARGET" 2>/dev/null; then
  printf "WARN: %s contains JSONC-style // comments — python json.load will fail\n" "$TARGET" >&2
  printf "Manual patch instruction:\n" >&2
  printf "  1. Open %s\n" "$TARGET" >&2
  printf "  2. Locate the 'SessionStart' array under 'hooks'\n" >&2
  printf "  3. Append: { \"matcher\": \"startup\", \"hooks\": [{ \"type\": \"command\", \"command\": \"bash .claude/hooks/cmm-index-startup.sh\", \"timeout\": 600 }] }\n" >&2
  printf "  4. Save and re-run this migration or proceed without the hook registration\n" >&2
  exit 0
fi

python3 - <<'PY'
import json, sys

TARGET = ".claude/settings.json"

with open(TARGET, "r", encoding="utf-8") as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])

# Idempotency: bail if any entry already references cmm-index-startup.sh
already = False
def walk(node):
    global already
    if already:
        return
    if isinstance(node, dict):
        for k, v in node.items():
            if isinstance(v, str) and "cmm-index-startup.sh" in v:
                already = True
                return
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)
walk(session_start)

if already:
    print("SKIP: cmm-index-startup.sh already referenced in settings.json")
    sys.exit(0)

entry = {
    "matcher": "startup",
    "hooks": [
        {
            "type": "command",
            "command": "bash .claude/hooks/cmm-index-startup.sh",
            "timeout": 600
        }
    ]
}
session_start.append(entry)

with open(TARGET, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("APPENDED: cmm-index-startup.sh SessionStart startup-matcher hook → " + TARGET)
PY

if ! python3 -c "import json; json.load(open('$TARGET'))" 2>/dev/null; then
  printf "ERROR: %s does not parse as valid JSON after patch\n" "$TARGET"
  exit 1
fi

if ! grep -q 'cmm-index-startup.sh' "$TARGET"; then
  printf "ERROR: 'cmm-index-startup.sh' sentinel missing from %s after patch\n" "$TARGET"
  exit 1
fi

printf "PATCHED: %s registered cmm-index-startup.sh SessionStart hook\n" "$TARGET"
```

---

### Step 7 — Patch `.claude/rules/mcp-routing.md`

Branch on `HAS_RULE_SECTIONS`:
- `HAS_RULE_SECTIONS=yes` → SKIP (Zero-Drift Policy header already present).
- Otherwise → apply two operations: (a) replace the existing `## CMM Freshness` section body with the hook-aware 5-step decision tree; (b) insert six new sections before `## Decision Shortcuts` (or at end of file if that header is absent).

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/rules/mcp-routing.md"

if [[ -n "${HAS_RULE_SECTIONS:-}" ]]; then
  printf "SKIP: %s already contains '## Zero-Drift Policy' section\n" "$TARGET"
  exit 0
fi

python3 - <<'PY'
import re, sys

TARGET = ".claude/rules/mcp-routing.md"

with open(TARGET, "r", encoding="utf-8") as f:
    content = f.read()

# ---------------------------------------------------------------------------
# (a) Replace the existing ## CMM Freshness section body with the hook-aware
#     5-step decision tree. Match from "## CMM Freshness" header up to (but
#     not including) the next "## " header, preserving everything else.
# ---------------------------------------------------------------------------

new_cmm_freshness = """## CMM Freshness (pre-flight when codebase-memory-mcp present)
Before symbol exploration on an indexed project:
1. First cmm tool call this session -> check if `cmm-index-startup.sh` ran this session (SessionStart stdout shows `CMM_STATE` or `CMM_HOOK_FAILED` line)
2. Hook ran + fresh -> proceed, no manual check needed
3. Hook ran + `CMM_HOOK_FAILED` -> run `list_projects` + baseline sentinel probe manually before trusting results
4. Hook did NOT run (`CMM_CLI_MISSING`, hook disabled, or non-hook environment) -> fall back to `list_projects` + baseline nodes match + sentinel probe
5. Baseline file present -> check nodes match; if mismatch -> reindex silently (permission-seeking ban applies)
Note: cmm server does NOT auto-reindex on MCP startup; it loads the last on-disk graph. Hook-enforced pre-flight is the primary freshness guarantee; manual pre-flight is fallback.
"""

pattern = re.compile(
    r"^## CMM Freshness[^\n]*\n.*?(?=^## |\Z)",
    re.MULTILINE | re.DOTALL,
)
if pattern.search(content):
    content = pattern.sub(new_cmm_freshness, content, count=1)
    print("REPLACED: ## CMM Freshness section body")
else:
    # CMM Freshness not present — prepend it. Unusual but survivable.
    content = new_cmm_freshness + "\n" + content
    print("PREPENDED: ## CMM Freshness section (anchor not found)")

# ---------------------------------------------------------------------------
# (b) Insert six new sections before ## Decision Shortcuts. If that header
#     is absent, append at end of file with a blank-line separator.
# ---------------------------------------------------------------------------

new_sections = """## Index Timing Expectations
Upstream-published benchmarks — calibrate wait-time, investigate if >2x these:

| Scale | Example | Expected time |
|---|---|---|
| Tiny (<1k nodes) | markdown-only, tiny scripts | <1s |
| Medium (~49k LOC) | typical app service | ~6s |
| Large (~10k nodes, ~200k LOC) | mature service repo | ~20-60s |
| Giant (75k files, 28M LOC) | monorepo | ~3min |

Source: upstream README. Operations >2x suggest pathological condition — investigate, don't wait silently.

## Known-Broken Tools
Generic upstream issues (project-specific broken tools live in `.claude/cmm-baseline.md`):

- `cmm.search_code` — upstream #250, rg invoked without path, returns 0. Fallback: `serena.search_for_pattern` + `paths_include_glob`
- `cmm.trace_path` — empirically broken on large graphs (no upstream issue filed). Fallback: `cmm.query_graph` w/ explicit `CALLS` pattern
- `cmm.get_architecture` — stub, returns counts only. Fallback: `cmm.get_graph_schema` for label counts; `cmm.query_graph` for structure
- `cmm.query_graph` Cypher features broken upstream #237-242, #252: `DISTINCT`, `labels()`, `WITH DISTINCT`, label alternation `A|B`, `count(DISTINCT x)`, `toInteger()`. Fallback: rewrite without `DISTINCT`, explicit label match, aggregate client-side
- Project-specific broken tools: `.claude/cmm-baseline.md` `## Known-broken tools` section

## Framework Blind Spots
Generic pattern: if project baseline lists a Node type as blind-spot, do NOT query against it — consult baseline routing overrides.

Examples (generic, no project-specific names):
- Attribute/decorator-based routing frameworks -> Route Node type unreliable; use `INHERITS` to framework base class
- Markup-template files (templating languages, component files) -> text-based parsers may error or skip; text search w/ path glob fallback
- Source-generated code (`*.g.cs`, protobuf outputs, `*_pb.py`) -> excluded by default, never reference
- Macro-expanded code -> not in pre-expansion AST

Project-specific entries: `.claude/cmm-baseline.md` `## Framework blind spots` section.

## Serena initial_instructions Gate
First `serena.*` tool call per session MUST be `mcp__serena__initial_instructions`. Call immediately after receiving task — critically informs available operations. Analogous to cmm `list_projects` pre-flight.

## Zero-Drift Policy
`cmm-index-startup.sh` hook enforces zero drift at session start. Any git SHA change OR node/edge count mismatch OR missing sentinel -> unconditional full reindex. No percentage threshold, no "good enough".
Hook emits:
- `CMM_STATE: fresh=true` on success (no drift)
- `CMM_DRIFT: reason=<trigger>` on reindex-triggered
- `CMM_HOOK_FAILED: <reason>` on error (session continues — fail-open)

Five drift triggers: (a) `current_sha != baseline_sha`; (b) `index_status` nodes|edges != baseline; (c) `index_status.status != "ready"`; (d) any baseline sentinel missing from `search_graph` probe; (e) baseline age > 7 days (slow-moving project staleness probe).

## Sentinel Symbol Probe
After any `cmm.index_repository` call (hook-triggered or Claude-mediated): verify baseline sentinels via `cmm.search_graph(name_pattern=<sentinel>)` for each listed sentinel. Missing sentinel -> fail loudly, log to `.learnings/log.md`, recommend `/cmm-baseline refresh`. All present -> proceed.

"""

parts = content.split("## Decision Shortcuts", 1)
if len(parts) == 2:
    before, after = parts
    content = before.rstrip() + "\n\n" + new_sections + "## Decision Shortcuts" + after
    print("INSERTED: 6 new sections before ## Decision Shortcuts")
else:
    content = content.rstrip() + "\n\n" + new_sections
    print("APPENDED: 6 new sections at end of file (## Decision Shortcuts anchor absent)")

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(content)
PY

for header in \
    '## CMM Freshness' \
    '## Index Timing Expectations' \
    '## Known-Broken Tools' \
    '## Framework Blind Spots' \
    '## Serena initial_instructions Gate' \
    '## Zero-Drift Policy' \
    '## Sentinel Symbol Probe'; do
  if ! grep -qF "$header" "$TARGET"; then
    printf "ERROR: '%s' sentinel missing from %s after patch\n" "$header" "$TARGET"
    exit 1
  fi
done

printf "PATCHED: %s — CMM Freshness replaced + 6 new sections added\n" "$TARGET"
```

---

### Step 8 — Patch `.claude/skills/consolidate/SKILL.md` — Phase 6

Branch on `HAS_CONSOLIDATE_PHASE6`:
- `HAS_CONSOLIDATE_PHASE6=yes` → SKIP.
- Otherwise → append Phase 6 section after the existing `### Phase 5: Update Tracking` block. Uses python3 split on the `### Anti-Hallucination` header (next section after Phase 5) to find the insertion point; falls back to end-of-file append.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/skills/consolidate/SKILL.md"

if [[ -n "${HAS_CONSOLIDATE_PHASE6:-}" ]]; then
  printf "SKIP: %s already contains 'Phase 6: CMM Baseline Correctness Gate'\n" "$TARGET"
  exit 0
fi

python3 - <<'PY'
TARGET = ".claude/skills/consolidate/SKILL.md"

new_section = """### Phase 6: CMM Baseline Correctness Gate (auto — post-dispatch)

Runs only when `codebase-memory-mcp` registered in `.mcp.json` AND `.claude/cmm-baseline.md` exists. Skip entirely otherwise — no output, no user message.

1. Invoke `/cmm-baseline verify-sentinels` via the Skill tool
2. All sentinels present -> silent, no user-facing message, proceed to exit
3. Missing sentinel(s) -> append to `.learnings/log.md`:
   ```
   ### {YYYY-MM-DD} — gotcha: sentinel rot detected
   cmm-baseline sentinel(s) missing from fresh graph: {names}
   trigger: /consolidate post-dispatch correctness gate
   action: /cmm-baseline refresh recommended
   ```
4. Missing sentinel(s) -> tell user: "CMM baseline sentinel rot detected — run `/cmm-baseline refresh` to rebaseline"

Rationale: sentinels are the only reliable post-index completeness signal. `/consolidate` runs at 5+ sessions / 24h elapsed — the right cadence for catching slow structural rot without user intervention.

Gate short-circuits when either precondition missing. Never auto-runs `/cmm-baseline refresh` — proposal only, user approves.

"""

with open(TARGET, "r", encoding="utf-8") as f:
    content = f.read()

# Insert before ### Anti-Hallucination (next section after Phase 5).
# Fallback: append at end of file with a blank-line separator.
anchor = "### Anti-Hallucination"
if anchor in content:
    parts = content.split(anchor, 1)
    new_content = parts[0].rstrip() + "\n\n" + new_section + anchor + parts[1]
    mode = "inserted-before-anti-hallucination"
else:
    new_content = content.rstrip() + "\n\n" + new_section
    mode = "appended-at-end"

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(new_content)

print("PATCHED: " + TARGET + " (" + mode + ")")
PY

if ! grep -q '^### Phase 6: CMM Baseline Correctness Gate' "$TARGET"; then
  printf "ERROR: 'Phase 6: CMM Baseline Correctness Gate' sentinel missing from %s after patch\n" "$TARGET"
  exit 1
fi

printf "PATCHED: %s — Phase 6 added\n" "$TARGET"
```

---

### Step 9 — Patch `.claude/skills/reflect/SKILL.md` — Step 4b

Branch on `HAS_REFLECT_STEP4B`:
- `HAS_REFLECT_STEP4B=yes` → SKIP.
- Otherwise → append Step 4b section after the existing `### Step 4: Instinct Health Report` block. Uses python3 split on the `### Report` header to find the insertion point; falls back to end-of-file append.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/skills/reflect/SKILL.md"

if [[ -n "${HAS_REFLECT_STEP4B:-}" ]]; then
  printf "SKIP: %s already contains 'Step 4b: CMM Broken-Tools Catalog Update'\n" "$TARGET"
  exit 0
fi

python3 - <<'PY'
TARGET = ".claude/skills/reflect/SKILL.md"

new_section = """### Step 4b: CMM Broken-Tools Catalog Update (auto — post-dispatch)

Runs only when `.claude/cmm-baseline.md` exists AND `codebase-memory-mcp` registered in `.mcp.json`. Skip entirely otherwise.

1. Scan `.learnings/log.md` entries since last `/reflect` run (delimiter: `.learnings/.last-reflect-lines` byte offset) for lines matching regex `cmm\\.\\w+` in `failure | gotcha | correction` categories
2. Extract unique cmm tool names + one-line failure summary per tool
3. Read existing `.claude/cmm-baseline.md` `## Known-broken tools` section — collect already-listed tool names to avoid duplicates
4. For each cmm tool NOT already in baseline: present to user as a proposed addition:
   ```
   Proposed cmm-baseline broken-tool addition:
     tool: cmm.{name}
     summary: {one-line cluster summary}
     evidence: {N} learnings entries since last reflect
     proposed line: - cmm.{name}: {summary}  # learned {date}, fallback: {suggest or TBD}
   [approve / reject / defer]
   ```
5. Approved -> Edit `.claude/cmm-baseline.md` directly, append line to `## Known-broken tools` section in the proposed format
6. Rejected -> no change, log rejection reason in `.learnings/log.md` as `gotcha: cmm broken-tool proposal rejected — {reason}`
7. Deferred -> no change, no log entry, re-propose next `/reflect` run

Proposal-only workflow — user confirms each addition individually. Never auto-applies. Never auto-deletes existing entries.

Skip silently when baseline file absent OR cmm not registered. No error, no user-facing message.

"""

with open(TARGET, "r", encoding="utf-8") as f:
    content = f.read()

anchor = "### Report"
if anchor in content:
    parts = content.split(anchor, 1)
    new_content = parts[0].rstrip() + "\n\n" + new_section + anchor + parts[1]
    mode = "inserted-before-report"
else:
    new_content = content.rstrip() + "\n\n" + new_section
    mode = "appended-at-end"

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(new_content)

print("PATCHED: " + TARGET + " (" + mode + ")")
PY

if ! grep -q '^### Step 4b: CMM Broken-Tools Catalog Update' "$TARGET"; then
  printf "ERROR: 'Step 4b: CMM Broken-Tools Catalog Update' sentinel missing from %s after patch\n" "$TARGET"
  exit 1
fi

printf "PATCHED: %s — Step 4b added\n" "$TARGET"
```

---

### Step 10 — Patch `.claude/agents/proj-reflector.md` — Pattern 7

Branch on `HAS_REFLECTOR_PATTERN7`:
- `HAS_REFLECTOR_PATTERN7=yes` → SKIP.
- Otherwise → append `### Pattern 7 — CMM broken-tool detection` section after the existing Process list + append `### CMM Broken-Tool Proposals` entry to the Output Format section.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/agents/proj-reflector.md"

if [[ -n "${HAS_REFLECTOR_PATTERN7:-}" ]]; then
  printf "SKIP: %s already contains 'Pattern 7 — CMM broken-tool detection'\n" "$TARGET"
  exit 0
fi

python3 - <<'PY'
TARGET = ".claude/agents/proj-reflector.md"

pattern7_section = """### Pattern 7 — CMM broken-tool detection (only when codebase-memory-mcp registered)

Runs only when both conditions hold:
- `.claude/cmm-baseline.md` exists
- `codebase-memory-mcp` registered in `.mcp.json` (or any MCP scope reachable this session)

Skip silently when either condition is absent — no output, no proposal section, no error.

Procedure:
1. Scan `.learnings/log.md` for lines matching regex `cmm\\.(\\w+)` inside entries in `failure | gotcha | correction` categories
2. Cluster matches by tool name. For each tool mentioned >=2 times w/ similar failure mode, produce a proposal entry
3. Read `.claude/cmm-baseline.md` `## Known-broken tools` section — skip any tool name already listed there
4. Format each surviving proposal as:
   ```
   - cmm.{tool}: {cluster summary}  # fallback: {if obvious from learnings, else TBD}
   ```
5. Include all proposals in agent output under a dedicated `### CMM Broken-Tool Proposals` section (see Output Format below)
6. Cite the matching `.learnings/log.md` entries as evidence for each proposal (>=2 citations required — matches the recurrence threshold from Anti-Hallucination section)

Proposal-only — agent never edits `.claude/cmm-baseline.md` directly. The `/reflect` skill Step 4b applies approved entries on the main thread.

"""

broken_tool_proposals_block = """### CMM Broken-Tool Proposals
(Omit this section entirely when cmm not registered OR `.claude/cmm-baseline.md` absent.)

- cmm.{tool}: {cluster summary}  # fallback: {suggestion or TBD}
  - Evidence: {quoted log entries, >=2 required}
  - Already listed in baseline? {yes = skip | no = propose}

"""

with open(TARGET, "r", encoding="utf-8") as f:
    content = f.read()

# --- Insert Pattern 7 immediately before the "## Output Format" header ---
output_format_anchor = "## Output Format"
if output_format_anchor in content:
    parts = content.split(output_format_anchor, 1)
    content = parts[0].rstrip() + "\n\n" + pattern7_section + output_format_anchor + parts[1]
    mode_1 = "inserted-before-output-format"
else:
    content = content.rstrip() + "\n\n" + pattern7_section
    mode_1 = "appended-pattern7-at-end"

# --- Insert CMM Broken-Tool Proposals block before "### Health" in Output Format ---
health_anchor = "### Health"
if health_anchor in content:
    parts = content.split(health_anchor, 1)
    content = parts[0].rstrip() + "\n\n" + broken_tool_proposals_block + health_anchor + parts[1]
    mode_2 = "inserted-before-health"
else:
    # Fallback: append proposals block at end
    content = content.rstrip() + "\n\n" + broken_tool_proposals_block
    mode_2 = "appended-proposals-at-end"

with open(TARGET, "w", encoding="utf-8") as f:
    f.write(content)

print("PATCHED: " + TARGET + " (pattern7=" + mode_1 + ", proposals=" + mode_2 + ")")
PY

if ! grep -q '^### Pattern 7 — CMM broken-tool detection' "$TARGET"; then
  printf "ERROR: 'Pattern 7 — CMM broken-tool detection' sentinel missing from %s after patch\n" "$TARGET"
  exit 1
fi
if ! grep -q '^### CMM Broken-Tool Proposals' "$TARGET"; then
  printf "ERROR: 'CMM Broken-Tool Proposals' sentinel missing from %s after patch\n" "$TARGET"
  exit 1
fi

printf "PATCHED: %s — Pattern 7 + CMM Broken-Tool Proposals added\n" "$TARGET"
```

---

### Step 11 — Seed baseline (conditional, informational only)

This step prints an instruction to the user. The `/cmm-baseline init` skill requires MCP tool calls (`index_repository`, `list_projects`, `index_status`, `get_graph_schema`, `search_graph`) that cannot execute inside a migration shell script — MCP tools run only from a live Claude Code session. The migration produces the prompt; the user must invoke the skill manually once the migration finishes.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig038-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig038-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${CMM_REGISTERED_PROJECT:-}" ]]; then
  printf "CMM registered in .mcp.json — run /cmm-baseline init manually to seed .claude/cmm-baseline.md with full-index counts, sentinels, framework blind spots. The first SessionStart after this migration will also trigger a proactive FIRST_INDEX via the installed hook; running /cmm-baseline init explicitly gives you the richer baseline (framework detection + sentinel picking) that the hook cannot do on its own.\n"
elif [[ -f .mcp.json ]]; then
  printf "cmm not registered in project .mcp.json (but other MCP servers present) — skipping baseline seed. To enable: add codebase-memory-mcp to .mcp.json mcpServers then run /cmm-baseline init.\n"
else
  printf "No .mcp.json — cmm not configured at project scope. Hook is installed and will self-gate at runtime (checking user + managed + plugin scopes). To enable baseline seeding: create .mcp.json with codebase-memory-mcp + run /cmm-baseline init.\n"
fi
```

---

### Step 12 — Smoke test

```bash
#!/usr/bin/env bash
set -euo pipefail

FAILED=0

# Hook syntax
if bash -n .claude/hooks/cmm-index-startup.sh 2>/dev/null; then
  printf "PASS: .claude/hooks/cmm-index-startup.sh bash -n syntax ok\n"
else
  printf "FAIL: .claude/hooks/cmm-index-startup.sh bash -n failed\n"
  FAILED=1
fi

# Hook executable
if [[ -x .claude/hooks/cmm-index-startup.sh ]]; then
  printf "PASS: .claude/hooks/cmm-index-startup.sh is executable\n"
else
  printf "FAIL: .claude/hooks/cmm-index-startup.sh is not executable (chmod +x needed)\n"
  FAILED=1
fi

# Settings JSON parses
if python3 -c "import json; json.load(open('.claude/settings.json'))" 2>/dev/null; then
  printf "PASS: .claude/settings.json parses as valid JSON\n"
else
  printf "FAIL: .claude/settings.json does not parse as valid JSON\n"
  FAILED=1
fi

# Hook registered in settings
if grep -q 'cmm-index-startup.sh' .claude/settings.json; then
  printf "PASS: cmm-index-startup.sh registered in settings.json\n"
else
  printf "FAIL: cmm-index-startup.sh not registered in settings.json\n"
  FAILED=1
fi

# Skill file present and well-formed
if [[ -f .claude/skills/cmm-baseline/SKILL.md ]] && grep -q '^name: cmm-baseline' .claude/skills/cmm-baseline/SKILL.md; then
  printf "PASS: .claude/skills/cmm-baseline/SKILL.md present with name: cmm-baseline\n"
else
  printf "FAIL: .claude/skills/cmm-baseline/SKILL.md missing or malformed\n"
  FAILED=1
fi

# Catalog reference present
if [[ -f .claude/skills/cmm-baseline/references/framework-catalog.md ]] && grep -q '^# Framework Catalog' .claude/skills/cmm-baseline/references/framework-catalog.md; then
  printf "PASS: framework-catalog.md present\n"
else
  printf "FAIL: framework-catalog.md missing or malformed\n"
  FAILED=1
fi

# Gitignore exception
if grep -qxF '!.claude/cmm-baseline.md' .gitignore; then
  printf "PASS: .gitignore contains '!.claude/cmm-baseline.md' exception\n"
else
  printf "FAIL: .gitignore missing '!.claude/cmm-baseline.md' exception\n"
  FAILED=1
fi

# Rule sections
for header in \
    '## Zero-Drift Policy' \
    '## Index Timing Expectations' \
    '## Known-Broken Tools' \
    '## Framework Blind Spots' \
    '## Serena initial_instructions Gate' \
    '## Sentinel Symbol Probe'; do
  if grep -qF "$header" .claude/rules/mcp-routing.md; then
    printf "PASS: %s present in mcp-routing.md\n" "$header"
  else
    printf "FAIL: %s missing from mcp-routing.md\n" "$header"
    FAILED=1
  fi
done

# Consolidate Phase 6
if grep -q '^### Phase 6: CMM Baseline Correctness Gate' .claude/skills/consolidate/SKILL.md; then
  printf "PASS: consolidate Phase 6 present\n"
else
  printf "FAIL: consolidate Phase 6 missing\n"
  FAILED=1
fi

# Reflect Step 4b
if grep -q '^### Step 4b: CMM Broken-Tools Catalog Update' .claude/skills/reflect/SKILL.md; then
  printf "PASS: reflect Step 4b present\n"
else
  printf "FAIL: reflect Step 4b missing\n"
  FAILED=1
fi

# proj-reflector Pattern 7
if grep -q '^### Pattern 7 — CMM broken-tool detection' .claude/agents/proj-reflector.md; then
  printf "PASS: proj-reflector Pattern 7 present\n"
else
  printf "FAIL: proj-reflector Pattern 7 missing\n"
  FAILED=1
fi

# Baseline file (only asserted if cmm registered — otherwise this is a no-op)
if grep -q 'codebase-memory-mcp' .mcp.json 2>/dev/null; then
  if [[ -f .claude/cmm-baseline.md ]]; then
    printf "PASS: .claude/cmm-baseline.md present (seeded)\n"
  else
    printf "INFO: .claude/cmm-baseline.md NOT yet present — run /cmm-baseline init or restart session to trigger proactive FIRST_INDEX via hook\n"
  fi
fi

if [[ $FAILED -ne 0 ]]; then
  printf "\nSMOKE TEST FAILED — review output above\n"
  exit 1
fi

printf "\nALL SMOKE TESTS PASSED\n"
```

---

### Step 13 — Advance `.claude/bootstrap-state.json`

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
    (isinstance(a, dict) and a.get("id") == "038") or a == "038"
    for a in applied
)
if already:
    print("SKIP: 038 already in applied[]")
else:
    applied.append({
        "id": "038",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "CMM proactive bootstrap + zero-drift policy — SessionStart startup-matcher hook, /cmm-baseline skill, framework catalog, hook-aware mcp-routing rule sections, consolidate Phase 6 + reflect Step 4b + proj-reflector Pattern 7 correctness gates, .gitignore exception"
    })
    state["applied"] = applied
    state["last_migration"] = "038"
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)
    print("ADVANCED: bootstrap-state.json last_migration=038")
PY
```

---

## Rules for migration scripts

- **Quoted heredocs for all inlined file bodies** — the hook body, skill body, and catalog body are written via `<<'CMM_HOOK_SH'` / `<<'CMM_SKILL_MD'` / `<<'CMM_CATALOG_MD'` (single-quoted) so no shell expansion occurs inside the heredoc. The inlined bodies contain `$(...)`, `${...}`, backticks, and `\\` escape sequences — all must be passed through verbatim.
- **Fresh-shell-safe state passing** — `/tmp/mig038-state` is the shared state file between steps. Each step sources the file at top. Step 1 writes the file; later steps only read.
- **Sentinel-first idempotency** — every mutating step checks its sentinel first (cmm-index-startup sentinel comment for the hook, `^name: cmm-baseline` for the skill, `^# Framework Catalog` for the catalog, exact line `!.claude/cmm-baseline.md` for gitignore, `cmm-index-startup.sh` substring for settings.json, `## Zero-Drift Policy` header for the rule, `### Phase 6:` / `### Step 4b:` / `### Pattern 7 —` for the skill/agent patches, `038` in `applied[]` for state) and exits 0 with `SKIP:` when already applied. Running twice is safe.
- **Fail-open on conditional steps** — Step 11 (baseline seed prompt) never fails; it emits a user instruction regardless of cmm registration state.
- **JSON merge with JSONC guard** — Step 6 guards against JSONC `//` comments in settings.json. Python `json.load` fails on JSONC; the migration detects the pattern and emits a manual-patch instruction + exits 0 non-fatally.
- **Post-patch verification** — every mutating step re-checks its sentinel after the write and exits 1 if the sentinel is still missing (belt-and-suspenders — file wrote but sentinel grep fails means the write was malformed).

---

## Post-Apply

After this migration runs successfully, the next SessionStart will emit one of these `CMM_*` lines in the hook output (visible to Claude as session context):

- `CMM: not registered` — cmm is not registered in any scope. Hook exits immediately. All other migration 038 components are still installed but dormant.
- `CMM_CLI_MISSING=true — reactive Claude-mediated index will run at first query` — cmm is registered but the `codebase-memory-mcp` CLI is not on PATH. Hook exits; reactive index will run at first query.
- `CMM_FIRST_INDEX=true — running full index (blocking)` — cmm is registered, CLI is available, no baseline file present. Hook runs a full index, writes minimal `.claude/cmm-baseline.md`, emits `CMM_STATE: first_index=true nodes=N edges=E ref=SHA`, exits 0. After first successful bootstrap: run `/cmm-baseline init` manually to replace the minimal baseline with the richer framework-detected + sentinel-populated form.
- `CMM_STATE: nodes=N edges=E ref=SHA fresh=true` — baseline present, all drift checks passed (SHA match, counts match, status=ready, sentinels found, age<=7 days). No action taken.
- `CMM_DRIFT: reason=<trigger> ...` followed by `CMM_STATE: reindexed=true nodes=N edges=E ref=SHA fresh=true` — drift detected, full reindex ran, baseline updated with new counts (user-managed sections preserved), sentinel-missing drift also logged to `.learnings/log.md`.
- `CMM_HOOK_FAILED: <reason>` (on stderr) — any error path. Hook exits 0 (fail-open) — session start is never blocked. File an issue with the reason string so the hook can be hardened. Manual `/cmm-baseline init` or `/cmm-baseline refresh` is the recommended recovery.

The `/cmm-baseline` skill is now callable via `Skill(skill: "cmm-baseline", args: "init")` from main-thread orchestrators, or directly by the user as `/cmm-baseline init | refresh | check | verify-sentinels`. The `/consolidate` skill Phase 6 + `/reflect` skill Step 4b will self-gate on cmm registration and silently skip on projects without cmm.

### Action items for the user (post-migration)

1. **If cmm is registered**: run `/cmm-baseline init` to seed the rich baseline (framework detection, sentinel picking, per-label counts). The hook-triggered `FIRST_INDEX` writes a minimal baseline — `/cmm-baseline init` replaces it with the full version.
2. **Commit `.claude/cmm-baseline.md`** to the project git repo once seeded. The `.gitignore` exception ensures it is tracked regardless of `git_strategy`.
3. **Inspect SessionStart output** on the next session start. Confirm a `CMM_*` line appears; report any `CMM_HOOK_FAILED` reason strings as an issue.
4. **If `.gitignore` was hand-edited after the migration inserted the exception line**, re-verify the exception line is still present with `grep -qxF '!.claude/cmm-baseline.md' .gitignore`.

---

## Rollback

Not automatically reversed by the migration runner. Restore from git if needed:

```bash
git checkout HEAD -- \
    .claude/settings.json \
    .claude/rules/mcp-routing.md \
    .claude/skills/consolidate/SKILL.md \
    .claude/skills/reflect/SKILL.md \
    .claude/agents/proj-reflector.md \
    .claude/bootstrap-state.json \
    .gitignore \
    migrations/index.json
rm -f .claude/hooks/cmm-index-startup.sh
rm -rf .claude/skills/cmm-baseline/
# Optional — remove the seeded baseline to force a fresh FIRST_INDEX on next session start
# rm -f .claude/cmm-baseline.md
```

If the project's `.claude/` directory is gitignored (companion strategy), restore from the companion repo under `~/.claude-configs/{project}/` instead:

```bash
# Companion restore — from ~/.claude-configs/{project}/
# cp ~/.claude-configs/{project}/.claude/settings.json .claude/settings.json
# cp ~/.claude-configs/{project}/.claude/rules/mcp-routing.md .claude/rules/mcp-routing.md
# cp ~/.claude-configs/{project}/.claude/skills/consolidate/SKILL.md .claude/skills/consolidate/SKILL.md
# cp ~/.claude-configs/{project}/.claude/skills/reflect/SKILL.md .claude/skills/reflect/SKILL.md
# cp ~/.claude-configs/{project}/.claude/agents/proj-reflector.md .claude/agents/proj-reflector.md
# cp ~/.claude-configs/{project}/.claude/bootstrap-state.json .claude/bootstrap-state.json
# rm -f .claude/hooks/cmm-index-startup.sh
# rm -rf .claude/skills/cmm-baseline/
```

Rollback is fully reversible — no data migration, no schema changes, no external state. The `.claude/cmm-baseline.md` file may be retained after rollback if desired; the hook is not reinstalled, but the baseline file remains harmless as a committed artifact that future migrations can consume.
