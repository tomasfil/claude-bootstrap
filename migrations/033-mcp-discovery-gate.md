# Migration 033 — MCP Discovery Gate (PreToolUse hook + First-Tool Contract)

> Install `.claude/hooks/mcp-discovery-gate.sh` (project-level PreToolUse hook that mechanically blocks symbol-shaped Grep/Glob/Search when `codebase-memory-mcp` or `serena` is available in ANY MCP scope — project `.mcp.json`, user `~/.claude.json`, managed `managed-settings.json`, or a plugin-bundled server), wire it into `.claude/settings.json` via a new PreToolUse entry matching `Grep|Glob|Search`, and patch every `.claude/agents/proj-*.md` STEP 0 override paragraph (plus `code-writer-*.md` and `test-writer-*.md` sub-specialists via globs) to add the First-Tool Contract + Stale Index Recovery + Transparent Fallback clauses. Motivated by three field-observed post-032 sessions violating the `mcp-routing.md` Grep Ban even with the rule active — rules are declarative, and three post-rule violations prove rule-only enforcement is insufficient. Defense-in-depth: layer 1 rule (migration 032) defines the violation, layer 2 contract (this migration) warns the agent in STEP 0, layer 3 hook (this migration) blocks mechanically at PreToolUse.

---

## Metadata

```yaml
id: "033"
breaking: false
affects: [hooks, settings, agents]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

Fields:
- `id`: `"033"`
- `breaking`: `false` — additive hook creation, additive `settings.json` PreToolUse entry, exact-string agent prose replacement with NO-OP fallback on variants. No existing hook or settings entry is rewritten; the new PreToolUse entry is appended to the existing array and the agent prose patch only triggers on files that match the exact post-031 wording.
- `affects`: `[hooks, settings, agents]` — creates `.claude/hooks/mcp-discovery-gate.sh`, appends a PreToolUse entry to `.claude/settings.json`, rewrites the STEP 0 override paragraph in every `.claude/agents/proj-*.md` (plus sub-specialists via globs `.claude/agents/code-writer-*.md` and `.claude/agents/test-writer-*.md`).
- `requires_mcp_json`: `false` — the hook self-gates on multi-scope MCP availability at runtime (project `.mcp.json` → user `~/.claude.json` → managed `managed-settings.json` → plugin-bundled servers), so installing it on a project that has no MCP servers reachable from any scope is a silent no-op at tool-call time. Migration installs unconditionally so activating MCPs later (in any scope) does not require re-running.
- `min_bootstrap_version`: `"6.0"` — earliest bootstrap version with the `.claude/agents/`, `.claude/hooks/`, `.claude/settings.json` layout supported by this migration.

---

## Problem

Three field-observed sessions (post-migration-032, where the `mcp-routing.md` Grep Ban section was already active) violated the MCP-first discipline the rule defined:

1. **Main-thread `Grep` for a CamelCase type name on an indexed project.** Main thread searched for a type name via `Grep` and then `Read` on the match file, instead of `cmm.search_graph(name_pattern=<TypeName>, label="Class")` + `cmm.get_code_snippet(<qualified_name>)`. The graph was fresh. The Grep returned a correct text match but carried no caller/callee context, no inheritance edges, and would have silently missed renamed-but-not-yet-reindexed occurrences.

2. **Main-thread `Grep` symbol-name alternation on an indexed project.** Main thread searched for `Foo|Bar|Baz` style alternation of named types via `Grep` — same root cause as case 1 but with multiple symbols compounded into one pattern. Each symbol was an indexed graph node; `cmm.search_graph` on each in sequence (or a single `query_graph` over labeled nodes) was the correct path.

3. **Code-writer subagent running multiple `Search` calls on namespace/class declaration patterns.** A code-writer specialist dispatched with the STEP 0 force-read of `mcp-routing.md` ran multiple `Search` calls matching patterns like `namespace.*\.Constants\b|class Constants\b` despite the force-read. The subagent read the rule, then ran symbol-declaration searches on the text-search tool anyway.

Root cause is structural: rules are declarative. Correct behavior depends on agents (and the main thread) actually reading the rule AND obeying it. Three post-rule violations prove rule-only enforcement is insufficient — the declarative rule can be force-read, force-cited in the STEP 0 override paragraph, and still lose to the body-prose precedence on `Grep` / `Read` / `Glob` examples later in agent bodies, or to operator habit on the main thread.

### Multi-scope MCP availability — the `.mcp.json`-only gate fails open under user/managed-scope inheritance

A first attempt at this migration shipped a hook + STEP 0 contract that gated enforcement on `[[ -f .mcp.json ]]` — a single project-scope check. This was insufficient: Claude Code reads MCP server registrations from FIVE distinct scopes per the official docs (`https://code.claude.com/docs/en/mcp` and `https://code.claude.com/docs/en/settings`), and only ONE of those scopes is the project-local `.mcp.json` file:

1. **Project scope** — `./.mcp.json` at project root, key `mcpServers`. Checked into version control, shared with team. *(Original gate covered only this scope.)*
2. **User scope** — `~/.claude.json` (top-level `mcpServers` key). Stored in the user's home directory, private to the user, applies across all projects on the machine. Created by `claude mcp add --scope user <name>`.
3. **Local scope** — `~/.claude.json` (`projects.<absolute-path>.mcpServers`). Same physical file as user scope, but nested per-project under the project's path key. Default for `claude mcp add` with no `--scope` flag.
4. **Managed scope** — file-based `managed-settings.json` + `managed-mcp.json` at per-OS system paths (`/Library/Application Support/ClaudeCode/` on macOS, `/etc/claude-code/` on Linux/WSL, `C:\Program Files\ClaudeCode\` on Windows), plus a `managed-settings.d/*.json` drop-in directory merged alphabetically. Deployed by IT for organization-wide policy.
5. **Plugin scope** — plugins may bundle MCP servers via `.mcp.json` at the plugin root (or inline in `plugin.json`); plugin servers start automatically when the plugin is enabled and appear alongside manually configured servers.

The three observed violations all originated in sessions where `codebase-memory-mcp` and/or `serena` were registered exclusively at **user scope** (top-level `mcpServers` in `~/.claude.json`) — there was no project `.mcp.json` in any of the three projects. The shipped hook's `[[ -f .mcp.json ]] || exit 0` check therefore short-circuited to fail-open on the very first line of the availability gate, and the new PreToolUse entry never fired in any of the three sessions. Rules layer 1 (migration 032) and contract layer 2 (this migration's STEP 0 paragraph) both still held — but layer 3, the mechanical enforcement, was effectively disabled. The dev machine's own setup inherits cmm + serena from user scope, confirming that user-scope-only MCP installs are the dominant configuration shape for this tool's user base, not an edge case.

The fix in this revision of migration 033 is to widen the hook's availability check to cover all five scopes via a single `python3` invocation that walks the known config files in order and short-circuits on the first hit. Detection is fail-open on every parse error so a broken hook still cannot break unrelated tool use. The STEP 0 First-Tool Contract paragraph in every patched agent is also rewritten to use scope-agnostic phrasing — "if `codebase-memory-mcp` or `serena` is available in this session (registered in any MCP scope — project `.mcp.json`, user `~/.claude.json`, managed `managed-settings.json`, or a plugin-bundled server)" — so the contract no longer hard-codes the project-scope path and stays correct as Claude Code adds new scopes.

A second bug was discovered while validating the fix: the previous hook's `printf '%s' "$INPUT" | python3 - <<'PY'` pattern fails on MINGW64 / Git Bash because the heredoc takes precedence over the pipe as `python3 -`'s stdin, so the parsed JSON is always empty and the hook fails-open at the JSON-parse step. The corrected hook passes input via the `CLAUDE_HOOK_INPUT` environment variable instead, which is reliable across platforms and does not collide with the script heredoc. Without this fix, even the project-scope path of the original hook would have failed open on Windows.

### Defense-in-depth stack (unchanged)

The fix is still a **defense-in-depth stack** where each layer catches what the previous layer missed:

- **Layer 1 — Rule (migration 032, SHIPPED)**: `.claude/rules/mcp-routing.md` has `## CMM Freshness`, `## Grep Ban`, `## Permission-Seeking Ban`, `## Project Slug Convention`, `## Transparent Fallback` sections that define the violation and the recovery path. This is the semantic ground truth — everything else references back to it.

- **Layer 2 — Contract (this migration)**: Every `proj-*` agent's STEP 0 override paragraph is expanded from a single-clause propagation rule into a 5-clause contract: First-Tool Contract (MCP-first on named symbols, scope-agnostic availability check), Stale Index Recovery (silent reindex on drift, no permission-seek), Transparent Fallback (disclose MCP→text-search degradation in user-facing messages), plus the pre-existing propagation rule and the fallback carve-out for literal strings in non-code. The First-Tool Contract clause explicitly names the hook as the mechanical enforcement layer so a blocked `Grep` call is recognizable and the recovery path is obvious.

- **Layer 3 — Hook (this migration)**: `.claude/hooks/mcp-discovery-gate.sh` is a project-level PreToolUse hook wired to `Grep|Glob|Search`. It reads the tool call JSON on stdin (passed to python3 via `CLAUDE_HOOK_INPUT` env var, MINGW64-safe), checks MCP availability across all five scopes via a single python3 invocation, classifies the pattern via the same python3 regex pipeline, and blocks (exit 2 + `{"decision":"block","reason":"..."}` on stdout) when the pattern looks like a named symbol AND `codebase-memory-mcp` or `serena` is registered in any reachable scope. Fail-open on parse errors — a broken hook never breaks unrelated tool use. This is the mechanical enforcement the declarative rule could not provide.

All three layers are required to stop the regression. Layer 1 alone has been shipping since migration 032 and did not prevent the three post-rule violations. Layer 2 alone would be a descriptive upgrade to layer 1 and is still declarative. Layer 3 alone would catch symbol-shaped Greps but would not teach the agent why or where to route instead — the blocked call would surface as a hook error with no path forward. Layered together: the rule defines truth, the contract warns the agent at STEP 0 with the specific hook name so the block is recognizable, and the hook blocks mechanically with a reason message that cites the rule sections. The recovery path is unambiguous at every layer.

---

## Changes

1. **Creates** `.claude/hooks/mcp-discovery-gate.sh` — bash + python3 regex classifier, full canonical content written verbatim via heredoc, `chmod +x` applied. The script reads PreToolUse JSON on stdin into a shell variable, passes it to a single python3 invocation via the `CLAUDE_HOOK_INPUT` environment variable (avoids the MINGW64 heredoc/stdin collision), checks MCP availability across all five scopes Claude Code reads (project `.mcp.json`, user `~/.claude.json` top-level `mcpServers`, local `~/.claude.json` `projects.<cwd>.mcpServers`, managed `managed-settings.json` + `managed-mcp.json` per-OS + `managed-settings.d/*.json` drop-in, plugin `~/.claude/plugins/*/.mcp.json`), and classifies the pattern via python3 regex (CamelCase identifier, class/namespace/interface/struct/enum declaration, qualified type reference, I-prefixed interface, alternation with PascalCase token, type declaration search, function/method declaration search). Gates only when `codebase-memory-mcp` or `serena` is reachable in ANY scope. Exempts literal phrases (quoted text with whitespace, file-extension globs, URL/path literals, error-message prefixes, pure lowercase phrases, snake_case/kebab-case short identifiers, markdown heading anchors). Emits `{"decision":"block","reason":"..."}` on stdout + reason on stderr + exit 2 on block. Fail-open on every parse error (broken hook never breaks unrelated tool use). Single python3 spawn per call; measured ~140ms on Windows / Git Bash, well within the per-PreToolUse-call budget.
2. **Patches** `.claude/settings.json` to add a new PreToolUse entry matching `Grep|Glob|Search` wiring `bash .claude/hooks/mcp-discovery-gate.sh`. Idempotent python3 merge (load → walk existing PreToolUse array → check for the new command → append if absent → dump with indent=2). Detects both nested `{ "hooks": { "PreToolUse": [...] } }` and legacy top-level `{ "PreToolUse": [...] }` shapes.
3. **Patches** every `.claude/agents/proj-*.md` (plus sub-specialists via globs for `code-writer-*.md` and `test-writer-*.md`) STEP 0 override paragraph: exact-string replace of the single-paragraph post-031 form with the expanded 5-paragraph form containing First-Tool Contract + Stale Index Recovery + Transparent Fallback clauses plus the pre-existing propagation rule and the literal-strings carve-out. NO-OP per-file if the post-031 exact wording is not present (hand-edited body or pre-031 state); NO-OP agents are collected and reported at the end for manual review.
4. **Advances** `.claude/bootstrap-state.json` → `last_migration: "033"` + appends entry to `applied[]` with the ISO8601 UTC timestamp and description.

Idempotency table:

| Step | Sentinel | Skip condition |
|---|---|---|
| 2 (hook) | `.claude/hooks/mcp-discovery-gate.sh` file exists AND contains `# mcp-discovery-gate.sh — PreToolUse hook` | Hook already installed with the canonical body. |
| 3 (settings) | Any PreToolUse `hooks[].command` contains `mcp-discovery-gate.sh` | Wiring already present. |
| 4 (agents) | Per-file grep for `First-Tool Contract (when MCP available)` | Agent already patched. Unmatched OLD paragraph → NO-OP (report for manual review). |
| 5 (state) | `033` already in `applied[]` | State already advanced. |

Running twice is safe — every step prints `SKIP:` or `NO-OP:` for the already-applied path and exits 0.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { printf "ERROR: not a bootstrapped project — run full bootstrap first\n"; exit 1; }
[[ -d ".claude/agents" ]] || { printf "ERROR: no .claude/agents directory\n"; exit 1; }
[[ -f ".claude/settings.json" ]] || { printf "ERROR: .claude/settings.json missing\n"; exit 1; }
mkdir -p .claude/hooks
command -v python3 >/dev/null 2>&1 || { printf "ERROR: python3 required\n"; exit 1; }
printf "OK: prerequisites satisfied\n"
```

---

### Step 1 — Detect current state

Write detection results to `/tmp/mig033-state` so subsequent bash blocks (each a fresh shell) can source it.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig033-state"
HAS_HOOK_FILE=""
HAS_SETTINGS_WIRING=""
HAS_CONTRACT=""

if [[ -f ".claude/hooks/mcp-discovery-gate.sh" ]] && grep -q '^# mcp-discovery-gate.sh — PreToolUse hook' .claude/hooks/mcp-discovery-gate.sh 2>/dev/null; then
  HAS_HOOK_FILE="yes"
fi

# settings.json wiring detection via python3 — walk both nested and legacy shapes
if python3 - <<'PY' 2>/dev/null
import json, sys
with open('.claude/settings.json') as f:
    settings = json.load(f)
pre = []
if isinstance(settings.get('hooks'), dict) and isinstance(settings['hooks'].get('PreToolUse'), list):
    pre = settings['hooks']['PreToolUse']
elif isinstance(settings.get('PreToolUse'), list):
    pre = settings['PreToolUse']
already = any(
    'mcp-discovery-gate.sh' in (h.get('command', '') or '')
    for entry in pre
    for h in entry.get('hooks', [])
)
sys.exit(0 if already else 1)
PY
then
  HAS_SETTINGS_WIRING="yes"
fi

# Contract-paragraph detection: at least one proj-* agent already has the First-Tool Contract clause
if grep -lq 'First-Tool Contract (when MCP available)' .claude/agents/proj-*.md 2>/dev/null; then
  HAS_CONTRACT="yes"
fi

{
  printf 'HAS_HOOK_FILE=%q\n' "$HAS_HOOK_FILE"
  printf 'HAS_SETTINGS_WIRING=%q\n' "$HAS_SETTINGS_WIRING"
  printf 'HAS_CONTRACT=%q\n' "$HAS_CONTRACT"
} > "$STATE_FILE"

printf "STATE: HAS_HOOK_FILE=%s HAS_SETTINGS_WIRING=%s HAS_CONTRACT=%s\n" \
  "${HAS_HOOK_FILE:-no}" "${HAS_SETTINGS_WIRING:-no}" "${HAS_CONTRACT:-no}"
```

---

### Step 2 — Write the mcp-discovery-gate.sh hook script

Branch on `HAS_HOOK_FILE`:
- `HAS_HOOK_FILE=yes` → SKIP (canonical body already present; sentinel comment matches).
- Otherwise → back up any existing body to `.bak-033`, then write the canonical body via bash heredoc (boundary token `HOOK` to avoid collision with the `PY` and `JSON` boundaries inside). `chmod +x` afterward. Syntax-check with `bash -n` and verify the shebang on line 1.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig033-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig033-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

TARGET=".claude/hooks/mcp-discovery-gate.sh"

if [[ -n "${HAS_HOOK_FILE:-}" ]]; then
  printf "SKIP: %s already contains canonical body (sentinel comment present)\n" "$TARGET"
  exit 0
fi

if [[ -f "$TARGET" ]]; then
  cp "$TARGET" "$TARGET.bak-033"
  printf "BACKUP: %s → %s.bak-033\n" "$TARGET" "$TARGET"
fi

cat > "$TARGET" <<'HOOK'
#!/usr/bin/env bash
# mcp-discovery-gate.sh — PreToolUse hook: block symbol-shaped Grep/Glob/Search
# when cmm or serena MCP is available in ANY scope (project, user, local,
# managed, plugin). Routes the agent/main to the graph instead.
# Reads PreToolUse JSON on stdin. Emits JSON decision on stdout. Exits 2 to block.
# Fail-open on every error path (a broken hook must never break unrelated tool use).
set -euo pipefail

# Read PreToolUse JSON from stdin into a shell variable, then pass to python3
# via an environment variable. This avoids the MINGW64 heredoc/stdin collision:
# `printf ... | python3 - <<'PY'` sends the heredoc (script) to python3's stdin,
# NOT the piped INPUT — so the pipe is lost on MINGW64 / Git Bash. Env-var
# passing is reliable across platforms and does not collide with the script
# heredoc.
INPUT=$(cat)

# Single python3 invocation: parse tool input JSON, check MCP availability
# across all known scopes, classify pattern. Emits one of:
#   allow                   → exit 0
#   block|<trigger label>   → emit decision JSON on stdout + stderr reason + exit 2
RESULT=$(CLAUDE_HOOK_INPUT="$INPUT" python3 - <<'PY'
import sys, json, os, re, glob

def fail_open():
    print("allow")
    sys.exit(0)

# ── Parse PreToolUse JSON from CLAUDE_HOOK_INPUT env var ────────
raw = os.environ.get("CLAUDE_HOOK_INPUT", "")
if not raw:
    fail_open()
try:
    data = json.loads(raw)
except Exception:
    fail_open()
if not isinstance(data, dict):
    fail_open()

tool_name = data.get("tool_name") or ""
tool_input = data.get("tool_input") or {}

# Only gate Grep / Glob / Search — Read handled by user-level priming hook
if tool_name not in ("Grep", "Glob", "Search"):
    fail_open()

pattern = ""
if isinstance(tool_input, dict):
    pattern = tool_input.get("pattern") or tool_input.get("query") or ""
if not isinstance(pattern, str):
    pattern = str(pattern)
if not pattern:
    fail_open()

# ── MCP availability check (multi-scope) ────────────────────────
# Returns True if codebase-memory-mcp or serena is registered in any scope
# Claude Code reads: project, user, local, managed, plugin. Silent fail-open
# on every parse error — a broken hook must never break unrelated tool use.
#
# Scopes covered (per https://code.claude.com/docs/en/mcp and
# https://code.claude.com/docs/en/settings):
#
#   1. Project scope — ./.mcp.json (`mcpServers` key) at project root
#   2. User scope    — ~/.claude.json top-level `mcpServers` key
#   3. Local scope   — ~/.claude.json → `projects.<abs-path>.mcpServers`
#                      (stored per-project in the same ~/.claude.json file)
#   4. Managed scope — file-based managed-settings.json + managed-mcp.json
#                      per-OS system path, plus managed-settings.d/*.json
#                      drop-in directory (merged alphabetically)
#   5. Plugin scope  — plugins may bundle .mcp.json at plugin root; best-effort
#                      shallow scan under ~/.claude/plugins/*/.mcp.json
#
# NOT covered (unreachable or out-of-scope for a bash hook):
#   - Windows HKCU registry managed settings (requires reg.exe query)
#   - Server-managed remote fetch (requires auth + network)
#   - Plugins installed under non-standard roots
TARGET_SERVERS = ("codebase-memory-mcp", "serena")

def has_target(mcp_servers):
    if not isinstance(mcp_servers, dict):
        return False
    return any(name in mcp_servers for name in TARGET_SERVERS)

def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def mcp_available():
    cwd = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    home = os.path.expanduser("~")

    # 1. Project scope — ./.mcp.json
    d = load_json(os.path.join(cwd, ".mcp.json"))
    if d and has_target(d.get("mcpServers")):
        return True

    # 2. User scope + 3. Local scope — ~/.claude.json
    d = load_json(os.path.join(home, ".claude.json"))
    if d:
        # User scope: top-level "mcpServers"
        if has_target(d.get("mcpServers")):
            return True
        # Local scope: projects.<cwd>.mcpServers
        projects = d.get("projects") or {}
        if isinstance(projects, dict):
            # Build candidate keys for the current project. Claude Code may store
            # paths with native or forward-slash separators, absolute or realpath.
            candidates = {cwd, os.path.abspath(cwd)}
            try:
                candidates.add(os.path.realpath(cwd))
            except Exception:
                pass
            for c in list(candidates):
                candidates.add(c.replace("\\", "/"))
            for key, entry in projects.items():
                if key in candidates and isinstance(entry, dict):
                    if has_target(entry.get("mcpServers")):
                        return True

    # 4. Managed scope — file-based managed-settings.json + managed-mcp.json
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
            if d and has_target(d.get("mcpServers")):
                return True
        dropin = os.path.join(mdir, "managed-settings.d")
        if os.path.isdir(dropin):
            try:
                for f in sorted(os.listdir(dropin)):
                    if f.startswith(".") or not f.endswith(".json"):
                        continue
                    d = load_json(os.path.join(dropin, f))
                    if d and has_target(d.get("mcpServers")):
                        return True
            except Exception:
                pass

    # 5. Plugin scope — best-effort shallow scan of ~/.claude/plugins/*/.mcp.json
    plugin_root = os.path.join(home, ".claude", "plugins")
    if os.path.isdir(plugin_root):
        try:
            for plugin_mcp in glob.glob(os.path.join(plugin_root, "*", ".mcp.json")):
                d = load_json(plugin_mcp)
                if d and has_target(d.get("mcpServers")):
                    return True
        except Exception:
            pass

    return False

try:
    if not mcp_available():
        fail_open()
except Exception:
    fail_open()

# ── Exemptions (text search is correct) ─────────────────────────
# 1. Quoted phrase containing whitespace → literal string
if re.search(r'"[^"]*\s[^"]*"', pattern) or re.search(r"'[^']*\s[^']*'", pattern):
    print("allow"); sys.exit(0)
# 2. File-extension / path literal
if re.search(r'\.(md|json|yaml|yml|toml|ini|conf|cfg|env|log|txt|csv|xml|sh|ps1|bat)(\b|$)', pattern):
    print("allow"); sys.exit(0)
# 3. URL / absolute path literal
if re.search(r'https?://|file://|[a-zA-Z]:\\|/tmp/|/etc/|/usr/|\$HOME', pattern):
    print("allow"); sys.exit(0)
# 4. Error / log marker prefix
if re.search(r'(?i)\b(error|exception|failed|warning|unable|cannot|refused|timeout)[:\s]', pattern):
    print("allow"); sys.exit(0)
# 5. Pure lowercase phrase with whitespace
if re.fullmatch(r'[a-z0-9_\- ]+', pattern) and ' ' in pattern:
    print("allow"); sys.exit(0)
# 6. Short lowercase snake_case / kebab identifier
if re.fullmatch(r'[a-z][a-z0-9_\-]*', pattern) and len(pattern) <= 40:
    print("allow"); sys.exit(0)
# 7. Markdown heading anchor
if pattern.startswith('^#'):
    print("allow"); sys.exit(0)

# ── Symbol-shape triggers (block) ───────────────────────────────
triggers = [
    (r'\b[A-Z][a-z]+[A-Z][a-zA-Z0-9]*\b', "CamelCase identifier"),
    (r'\bI[A-Z][a-z][a-zA-Z0-9]+\b', "I-prefixed interface"),
    (r'\b(class|namespace|interface|struct|record|trait|impl|enum|type)\s+[A-Z]', "type declaration search"),
    (r'\b(def|fn|function|func|public|private|protected|internal|static)\s+[A-Za-z_]', "function / method declaration search"),
    (r'^\^?[A-Z][a-zA-Z0-9]{2,}\$?$', "bare PascalCase anchor"),
    (r'(\||^)\s*[A-Z][a-zA-Z0-9]{2,}\s*(\||$)', "alternation with PascalCase token"),
    (r'\b[A-Z][a-zA-Z0-9]*\.[A-Z][a-zA-Z0-9]*\b', "qualified type reference"),
]
for rx, label in triggers:
    if re.search(rx, pattern):
        print("block|" + label)
        sys.exit(0)

print("allow")
PY
)

case "$RESULT" in
  allow|"")
    exit 0
    ;;
  block\|*)
    TRIGGER="${RESULT#block|}"
    # Emit structured decision on stdout + reason on stderr + exit 2
    cat <<JSON
{"decision":"block","reason":"MCP-first discipline: pattern looks like a named symbol (${TRIGGER}). Use cmm.search_graph(name_pattern=...) or serena.find_symbol(name_path=...) first. Stale cmm graph → detect_changes → index_repository → retry (silent, no permission-seek, per max-quality.md §6). Grep fallback only after a fresh cmm search returns 0 hits, and MUST be disclosed per mcp-routing.md Transparent Fallback section. See .claude/rules/mcp-routing.md sections: CMM Freshness, Grep Ban, Permission-Seeking Ban, Transparent Fallback."}
JSON
    printf 'BLOCKED by mcp-discovery-gate: pattern matches %s — route through cmm/serena first. See .claude/rules/mcp-routing.md.\n' "$TRIGGER" >&2
    exit 2
    ;;
  *)
    # Unknown result → fail-open (defense in depth)
    exit 0
    ;;
esac
HOOK

chmod +x "$TARGET"

if ! bash -n "$TARGET"; then
  printf "ERROR: bash -n failed on %s — syntax error in generated hook\n" "$TARGET"
  exit 1
fi

if ! head -1 "$TARGET" | grep -q '^#!/usr/bin/env bash'; then
  printf "ERROR: %s missing '#!/usr/bin/env bash' shebang on line 1\n" "$TARGET"
  exit 1
fi

printf "WROTE: %s (bash syntax OK, shebang OK, executable)\n" "$TARGET"
```

---

### Step 3 — Patch settings.json (PreToolUse merge)

Idempotent python3 merge: load → detect shape (nested `{ "hooks": { "PreToolUse": [...] } }` or legacy top-level `{ "PreToolUse": [...] }`) → walk existing entries for any `hooks[].command` containing `mcp-discovery-gate.sh` → append new entry if absent → dump with `indent=2` + trailing newline.

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/tmp/mig033-state"
[[ -f "$STATE_FILE" ]] || { printf "ERROR: /tmp/mig033-state missing — Step 1 did not run\n"; exit 1; }
# shellcheck source=/dev/null
source "$STATE_FILE"

if [[ -n "${HAS_SETTINGS_WIRING:-}" ]]; then
  printf "SKIP: .claude/settings.json already wires mcp-discovery-gate.sh\n"
  exit 0
fi

python3 - <<'PY'
import json, sys
from pathlib import Path

path = Path('.claude/settings.json')
with path.open(encoding='utf-8') as f:
    settings = json.load(f)

# Determine shape — Claude Code standard is nested { "hooks": { "PreToolUse": [...] } }
# Fall back to top-level "PreToolUse" only if nested form is absent.
if isinstance(settings.get('hooks'), dict) and isinstance(settings['hooks'].get('PreToolUse'), list):
    pre = settings['hooks']['PreToolUse']
elif isinstance(settings.get('PreToolUse'), list):
    pre = settings['PreToolUse']
else:
    settings.setdefault('hooks', {}).setdefault('PreToolUse', [])
    pre = settings['hooks']['PreToolUse']

# Idempotency check
already = any(
    'mcp-discovery-gate.sh' in (h.get('command', '') or '')
    for entry in pre
    for h in entry.get('hooks', [])
)
if already:
    print("SKIP: settings.json already wires mcp-discovery-gate.sh")
    sys.exit(0)

pre.append({
    "matcher": "Grep|Glob|Search",
    "hooks": [
        {"type": "command", "command": "bash .claude/hooks/mcp-discovery-gate.sh"}
    ]
})

with path.open('w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print("PATCHED: settings.json PreToolUse += mcp-discovery-gate.sh entry")
PY

# Validate JSON after write
python3 -c "import json; json.load(open('.claude/settings.json'))" || {
  printf "ERROR: settings.json is not valid JSON after patch — restore from backup\n"
  exit 1
}
printf "VERIFIED: .claude/settings.json is valid JSON\n"
```

---

### Step 4 — Patch agent STEP 0 override paragraph (glob loop)

Exact-string python3 `replace()` per file. Agents whose prose does not match the exact post-031 wording print `NO-OP` and are left unchanged (reported for manual review). Already-patched files (detected via grep for `First-Tool Contract (when MCP available)`) print `SKIP`. This step globs both `proj-*.md` and `code-writer-*.md` + `test-writer-*.md` sub-specialists per `.claude/rules/general.md` (glob agent filenames, never hardcode).

```bash
#!/usr/bin/env bash
set -euo pipefail

NOOP_LIST=""
PATCHED_COUNT=0
SKIP_COUNT=0
NOOP_COUNT=0

for agent in .claude/agents/proj-*.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md; do
  [[ -f "$agent" ]] || continue

  if grep -q 'First-Tool Contract (when MCP available)' "$agent"; then
    printf "SKIP: %s — already patched (First-Tool Contract present)\n" "$agent"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi

  if ! grep -q 'route code discovery through its action→tool table BEFORE any' "$agent"; then
    printf "SKIP: %s — no post-031 STEP 0 override paragraph (pre-031 body or hand-edited)\n" "$agent"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi

  result=$(python3 - "$agent" <<'PY'
import sys
path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    text = f.read()
original = text

OLD = "If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config) AND route code discovery through its action\u2192tool table BEFORE any `Grep` / `Glob` / `Read`-first examples later in this file. Fall back to text search only when no MCP path fits."

NEW = """If `mcp-routing.md` is loaded, follow its propagation rules (tools:/allowed-tools: config) AND route code discovery through its action\u2192tool table BEFORE any `Grep` / `Glob` / `Read`-first examples later in this file.

**First-Tool Contract (when MCP available)**: If `codebase-memory-mcp` or `serena` is registered in ANY MCP scope reachable this session \u2014 project `.mcp.json`, user `~/.claude.json` (top-level `mcpServers` or `projects.<cwd>.mcpServers`), managed `managed-settings.json`, or a plugin-bundled server \u2014 your FIRST code-discovery tool call MUST be an `mcp__codebase-memory-mcp__*` or `mcp__serena__*` tool. Any `Grep` / `Glob` / `Search` on a named symbol (CamelCase identifier, `class`/`namespace`/`interface`/`struct`/`enum` declaration, qualified type reference, `I`-prefixed interface) before a successful MCP call = task failure. A project-level PreToolUse hook (`.claude/hooks/mcp-discovery-gate.sh`) enforces this mechanically across all scopes \u2014 if it blocks your `Grep`, reroute to `cmm.search_graph` / `serena.find_symbol` or justify the fallback in writing.

**Stale Index Recovery**: `cmm` does not auto-reindex on MCP startup. If `cmm.list_projects` shows a suspicious `nodeCount` OR `cmm.detect_changes` reports drift \u2192 run `cmm.detect_changes` \u2192 `cmm.index_repository` \u2192 retry the original query. **Silently, no permission-seek** (per `max-quality.md` \u00a76 \u2014 solvable blocker, resolve in-band).

**Transparent Fallback**: when an MCP path legitimately fails and you fall back to `Grep` / `Glob` / `Read` / `serena.search_for_pattern`, disclose it in the next user-facing message using the format `MCP\u2192fallback: {what was tried} \u2192 {why it failed} \u2192 {fallback path taken}`. Never silently degrade. Max-quality still applies to fallback paths.

Fall back to text search only when no MCP path fits (literal strings in non-code, config values, raw file reads of known paths)."""

text = text.replace(OLD, NEW)

if text == original:
    print(f"NO-OP: {path} (post-031 exact paragraph not found — hand-edited or variant body)")
    sys.exit(0)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
print(f"PATCHED: {path}")
PY
  )

  printf "%s\n" "$result"

  if printf "%s" "$result" | grep -q "^NO-OP:"; then
    NOOP_LIST="${NOOP_LIST} ${agent}"
    NOOP_COUNT=$((NOOP_COUNT + 1))
  elif printf "%s" "$result" | grep -q "^PATCHED:"; then
    PATCHED_COUNT=$((PATCHED_COUNT + 1))
  fi
done

printf "\nStep 4 summary: PATCHED=%d SKIP=%d NO-OP=%d\n" "$PATCHED_COUNT" "$SKIP_COUNT" "$NOOP_COUNT"

if [[ -n "$NOOP_LIST" ]]; then
  printf "\nNO-OP agents (manual review — STEP 0 paragraph did not match exact post-031 wording):%s\n" "$NOOP_LIST"
  printf "These agent files contain the 'route code discovery through its action→tool table' phrase but did not match the full exact paragraph. Manually expand the STEP 0 override paragraph to include the First-Tool Contract + Stale Index Recovery + Transparent Fallback clauses.\n"
fi
```

---

### Step 5 — Advance bootstrap-state.json

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
    (isinstance(a, dict) and a.get("id") == "033") or a == "033"
    for a in applied
)
if already:
    print("SKIP: 033 already in applied[]")
else:
    applied.append({
        "id": "033",
        "applied_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "description": "MCP discovery gate — PreToolUse hook + First-Tool Contract clause in agent STEP 0 override"
    })
    state["applied"] = applied
    state["last_migration"] = "033"
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)
    print("ADVANCED: bootstrap-state.json last_migration=033")
PY
```

---

### Rules for migration scripts

- **`set -euo pipefail`** at the top of every bash block. Failed prior steps do NOT advance `bootstrap-state.json` — Step 5 is separate and last.
- **No `sed -i`** for content mutations — use `python3` for all JSON edits and content replacements. MINGW64-safe: no process substitution outside the tool-name/pattern read in Step 2's hook body (which uses python3 for its JSON parsing).
- **Exact-string `replace()` only** — no regex `.*` patterns in Step 4 agent patches. Agents that don't match the exact post-031 strings print `NO-OP` and are left unchanged (reported for manual review). This prevents false-positive over-matching of hand-edited bodies.
- **Idempotent sentinel checks** — every step checks a sentinel before acting (Step 2: `# mcp-discovery-gate.sh — PreToolUse hook` comment in the file; Step 3: `mcp-discovery-gate.sh` literal in any existing PreToolUse command; Step 4: `First-Tool Contract (when MCP available)` per file; Step 5: `033` already in `applied[]`). Re-running prints `SKIP` or `NO-OP` and exits 0.
- **Read-before-write** — every file is opened, read into a string, modified, then written. No in-place clobber on the hook file (backed up to `.bak-033` if a prior body exists and the sentinel is absent).
- **Fail-fast on anchor drift** — Step 2 runs `bash -n` and a shebang check on the freshly-written hook; any failure exits 1 before state advance. Step 3 validates `settings.json` with `python3 -c "import json; json.load(open('.claude/settings.json'))"` after write. Failures prevent state advance.
- **State advance is last** — Step 5 only runs if all prior steps succeeded. Re-running after a partial failure is safe because every step is idempotent.
- **Glob agent filenames** — Step 4 iterates `.claude/agents/proj-*.md` plus `.claude/agents/code-writer-*.md` and `.claude/agents/test-writer-*.md` so sub-specialists created via `/evolve-agents` receive the same patch, per `.claude/rules/general.md`.

### Required: register in migrations/index.json

Every migration file MUST have a matching entry in `migrations/index.json`. Entry is added as part of this change set — the main thread verifies.

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL=0

# (a) hook exists + executable + shebang on line 1
if [[ -f ".claude/hooks/mcp-discovery-gate.sh" ]] && [[ -x ".claude/hooks/mcp-discovery-gate.sh" ]] && head -1 .claude/hooks/mcp-discovery-gate.sh | grep -q '^#!/usr/bin/env bash'; then
  printf "OK (a): .claude/hooks/mcp-discovery-gate.sh exists, executable, shebang on line 1\n"
else
  printf "FAIL (a): .claude/hooks/mcp-discovery-gate.sh missing, not executable, or missing shebang\n"
  FAIL=1
fi

# (b) bash -n syntax check
if bash -n .claude/hooks/mcp-discovery-gate.sh 2>/dev/null; then
  printf "OK (b): bash -n .claude/hooks/mcp-discovery-gate.sh passes\n"
else
  printf "FAIL (b): bash -n .claude/hooks/mcp-discovery-gate.sh reports syntax error\n"
  FAIL=1
fi

# (c) settings.json has PreToolUse entry wiring the hook
if python3 - <<'PY' 2>/dev/null
import json, sys
with open('.claude/settings.json') as f:
    settings = json.load(f)
pre = []
if isinstance(settings.get('hooks'), dict) and isinstance(settings['hooks'].get('PreToolUse'), list):
    pre = settings['hooks']['PreToolUse']
elif isinstance(settings.get('PreToolUse'), list):
    pre = settings['PreToolUse']
found = any(
    'mcp-discovery-gate.sh' in (h.get('command', '') or '')
    for entry in pre
    for h in entry.get('hooks', [])
)
sys.exit(0 if found else 1)
PY
then
  printf "OK (c): .claude/settings.json PreToolUse array wires mcp-discovery-gate.sh\n"
else
  printf "FAIL (c): .claude/settings.json PreToolUse array does NOT wire mcp-discovery-gate.sh\n"
  FAIL=1
fi

# (d) at least one proj-* agent has the First-Tool Contract clause
if grep -lq 'First-Tool Contract (when MCP available)' .claude/agents/proj-*.md 2>/dev/null; then
  printf "OK (d): at least one .claude/agents/proj-*.md has the First-Tool Contract clause\n"
else
  printf "FAIL (d): no .claude/agents/proj-*.md has the First-Tool Contract clause\n"
  FAIL=1
fi

# (e) bootstrap-state.json lists 033 + last_migration=033
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_033 = any((isinstance(a, dict) and a.get('id') == '033') or a == '033' for a in applied)
last = state.get('last_migration', '')
fail = 0
if not has_033:
    print("FAIL (e1): 033 not in applied[]")
    fail = 1
else:
    print("OK (e1): 033 in applied[]")
if last != '033':
    print(f"FAIL (e2): last_migration is '{last}', expected '033'")
    fail = 1
else:
    print("OK (e2): last_migration=033")
sys.exit(fail)
PY
[[ $? -eq 0 ]] || FAIL=1

# (f) smoke test: symbol-shaped pattern → blocked if MCP reachable in ANY scope, dormant otherwise.
# Multi-scope check mirrors the hook's own availability logic: project .mcp.json, user ~/.claude.json
# (top-level or projects.<cwd>.mcpServers), managed settings, plugin-bundled. Fail-open on errors.
MCP_REACHABLE=$(python3 - <<'PY' 2>/dev/null || printf 'no'
import os, sys, json, glob
TARGETS = ("codebase-memory-mcp", "serena")
def has_target(m):
    return isinstance(m, dict) and any(k in m for k in TARGETS)
def load_json(p):
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None
cwd = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
home = os.path.expanduser("~")
# 1. Project scope
d = load_json(os.path.join(cwd, ".mcp.json"))
if d and has_target(d.get("mcpServers")):
    print("yes"); sys.exit(0)
# 2+3. User/local scope in ~/.claude.json
d = load_json(os.path.join(home, ".claude.json"))
if d:
    if has_target(d.get("mcpServers")):
        print("yes"); sys.exit(0)
    projects = d.get("projects") or {}
    if isinstance(projects, dict):
        cands = {cwd, os.path.abspath(cwd)}
        try:
            cands.add(os.path.realpath(cwd))
        except Exception:
            pass
        for c in list(cands):
            cands.add(c.replace("\\", "/"))
        for key, entry in projects.items():
            if key in cands and isinstance(entry, dict) and has_target(entry.get("mcpServers")):
                print("yes"); sys.exit(0)
# 4. Managed scope
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
        if d and has_target(d.get("mcpServers")):
            print("yes"); sys.exit(0)
    dropin = os.path.join(mdir, "managed-settings.d")
    if os.path.isdir(dropin):
        try:
            for f in sorted(os.listdir(dropin)):
                if f.startswith(".") or not f.endswith(".json"):
                    continue
                d = load_json(os.path.join(dropin, f))
                if d and has_target(d.get("mcpServers")):
                    print("yes"); sys.exit(0)
        except Exception:
            pass
# 5. Plugin scope
plugin_root = os.path.join(home, ".claude", "plugins")
if os.path.isdir(plugin_root):
    try:
        for plugin_mcp in glob.glob(os.path.join(plugin_root, "*", ".mcp.json")):
            d = load_json(plugin_mcp)
            if d and has_target(d.get("mcpServers")):
                print("yes"); sys.exit(0)
    except Exception:
        pass
print("no")
PY
)

set +e
printf '%s' '{"tool_name":"Grep","tool_input":{"pattern":"FooBarService"}}' | bash .claude/hooks/mcp-discovery-gate.sh >/dev/null 2>&1
EC=$?
set -e
if [[ "$MCP_REACHABLE" == "yes" ]]; then
  if [[ $EC -eq 2 ]]; then
    printf "OK (f): smoke test FooBarService → exit 2 (blocked, MCP reachable in at least one scope)\n"
  else
    printf "FAIL (f): smoke test FooBarService → expected exit 2 (MCP reachable), got %d\n" "$EC"
    FAIL=1
  fi
else
  if [[ $EC -eq 0 ]]; then
    printf "OK (f): smoke test FooBarService → exit 0 (dormant, no MCP reachable in any scope)\n"
  else
    printf "FAIL (f): smoke test FooBarService → expected exit 0 (no MCP reachable), got %d\n" "$EC"
    FAIL=1
  fi
fi

# (g) smoke test: literal error phrase exempt → exit 0 regardless
set +e
printf '%s' '{"tool_name":"Grep","tool_input":{"pattern":"connection refused"}}' | bash .claude/hooks/mcp-discovery-gate.sh >/dev/null 2>&1
EC=$?
set -e
if [[ $EC -eq 0 ]]; then
  printf "OK (g): smoke test 'connection refused' → exit 0 (literal error phrase exempt)\n"
else
  printf "FAIL (g): smoke test 'connection refused' → expected exit 0, got %d\n" "$EC"
  FAIL=1
fi

if [[ $FAIL -eq 0 ]]; then
  printf "\nMigration 033 complete — all checks passed\n"
else
  printf "\nMigration 033 FAILED — %d check(s) above need attention\n" "$FAIL"
  exit 1
fi
```

Failure of any verify step → migration is not complete. Safe to re-run after fixing (all steps idempotent).

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"033"`
- append `{ "id": "033", "applied_at": "<ISO8601>", "description": "MCP discovery gate — PreToolUse hook + First-Tool Contract clause in agent STEP 0 override" }` to `applied[]`

---

## Rollback

Not rollback-able via migration runner. Restore from git if needed:

```bash
git checkout HEAD -- .claude/hooks/mcp-discovery-gate.sh .claude/settings.json .claude/agents/ .claude/bootstrap-state.json
```

If the project's `.claude/` directory is gitignored (companion strategy), restore from the companion repo under `~/.claude-configs/{project}/` instead:

```bash
# Companion restore — from ~/.claude-configs/{project}/
# cp ~/.claude-configs/{project}/.claude/hooks/mcp-discovery-gate.sh .claude/hooks/ 2>/dev/null || rm -f .claude/hooks/mcp-discovery-gate.sh
# cp ~/.claude-configs/{project}/.claude/settings.json .claude/settings.json
# cp -r ~/.claude-configs/{project}/.claude/agents/. .claude/agents/
# cp ~/.claude-configs/{project}/.claude/bootstrap-state.json .claude/bootstrap-state.json
```
