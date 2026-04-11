# Migration 014 — plan-writer MCP access (drop tools: from proj-plan-writer)

<!-- migration-id: 014-plan-writer-mcp-access -->

> Strip the `tools:` frontmatter line from `proj-plan-writer.md` so it inherits parent MCP tools; update `mcp-routing.md` to the absolute all-agents rule.

---

## Metadata

```yaml
id: "014"
breaking: false
affects: [agents, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Migration 013 intentionally excluded `proj-plan-writer` from the `tools:` strip with the rationale "MCP-free by design". That rationale was stale — it confused *scope-lock* (agent-scope-lock.md restricts which *files* plan-writer may edit) with *tool access* (which tools it may invoke). `proj-plan-writer` has no reason to be blocked from MCP tools; it needs full tool inheritance like every other agent. The `tools:` line also prevents `mcp__*` glob entries from taking effect if any are ever added. Additionally, `mcp-routing.md` still carried the migration-013 wording ("write agents only") rather than the updated absolute rule ("ALL agents").

---

## Changes

1. Strips `tools:` frontmatter line from `.claude/agents/proj-plan-writer.md`.
2. Updates `.claude/rules/mcp-routing.md` to absolute all-agents rule (inline heredoc — file is gitignored in bootstrap repo, cannot fetch remotely).
3. Advances `.claude/bootstrap-state.json` → `last_migration: "014"` + appends `"014"` to `applied[]`.

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

# Migration 013 must be applied — this migration is an addendum to it
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_013 = any(
    (isinstance(a, dict) and a.get('id') == '013') or a == '013'
    for a in applied
)
if not has_013:
    print("ERROR: migration 013 (MCP glob fix) not applied — cannot apply 014")
    sys.exit(1)
print("OK: migration 013 present in applied[]")
PY
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".claude/agents/proj-plan-writer.md" ]] && \
   ! grep -q "^tools:" ".claude/agents/proj-plan-writer.md"; then
  printf "SKIP: already patched (proj-plan-writer.md has no tools: line)\n"
  exit 0
fi

printf "Applying migration 014: stripping tools: from proj-plan-writer\n"
```

### Step 1 — Strip `tools:` from `proj-plan-writer.md`

```bash
#!/usr/bin/env bash
set -euo pipefail

strip_tools_line() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    printf "SKIP: %s not found\n" "$file"
    return
  fi
  if ! grep -q "^tools:" "$file"; then
    printf "SKIP: %s — no tools: line present\n" "$file"
    return
  fi
  # Write to temp then replace (atomic, avoids clobbering on error)
  local tmp
  tmp="$(mktemp)"
  grep -v "^tools:" "$file" > "$tmp"
  mv "$tmp" "$file"
  printf "PATCHED: %s — tools: line removed\n" "$file"
}

strip_tools_line ".claude/agents/proj-plan-writer.md"
```

### Step 2 — Update `.claude/rules/mcp-routing.md` (inline — file is gitignored in bootstrap repo)

`.claude/rules/mcp-routing.md` is gitignored in the bootstrap repo, so we cannot fetch it remotely. Inline the updated rule content via heredoc and replace only if content differs (idempotent).

```bash
#!/usr/bin/env bash
set -euo pipefail

DEST=".claude/rules/mcp-routing.md"
TMPFILE="$(mktemp)"

cat > "$TMPFILE" <<'RULE_EOF'
# MCP Routing

## Rule
MCP tools route through sub-agents — NEVER skill `allowed-tools:`.

## Skill layer (NEVER add mcp__* here)
`allowed-tools:` controls skill's own invocation permissions — does NOT cascade to
dispatched agents. Adding `mcp__*` to a skill's `allowed-tools:` is always wrong.

## Agent layer (all agents)
ALL agents (read-only, write, planning): OMIT `tools:` entirely → inherit parent tools incl. MCP.
Theoretical exception: hard-restricted agent → literal (non-glob) tool list. Currently unused by any agent in this project.

## When .mcp.json changes
Run `/migrate-bootstrap` (triggers migration-001 re-check) or `/audit-agents`
to validate MCP propagation across all agents.

## Routing table
If MCPs present, the routing table below is the single source for tool→action mappings.
Populate per project during bootstrap or when new MCP servers are added.
Note: Claude Code silently ignores glob entries in agent `tools:` — list literal tool names only, or OMIT `tools:` entirely for inheritance.

| MCP Server | Example tool | Use for |
|------------|--------------|---------|
| {server}   | mcp__{server}__{tool_name} | {description — fill from .mcp.json} |
RULE_EOF

if [[ -f "$DEST" ]] && cmp -s "$TMPFILE" "$DEST"; then
  printf "SKIP: %s already up to date\n" "$DEST"
  rm "$TMPFILE"
else
  mv "$TMPFILE" "$DEST"
  printf "UPDATED: %s\n" "$DEST"
fi
```

### Step 3 — Advance bootstrap state

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json, sys
from datetime import datetime, timezone

path = '.claude/bootstrap-state.json'
with open(path, 'r', encoding='utf-8') as f:
    state = json.load(f)

applied = state.get('applied', [])

# Idempotent: skip if already present
already = any(
    (isinstance(a, dict) and a.get('id') == '014') or a == '014'
    for a in applied
)
if already:
    print("SKIP: 014 already in applied[]")
    sys.exit(0)

state['last_migration'] = '014'
applied.append({
    'id': '014',
    'applied_at': datetime.now(timezone.utc).isoformat(),
    'description': 'plan-writer MCP access — drop tools: from proj-plan-writer, absolute all-agents rule in mcp-routing.md'
})
state['applied'] = applied

with open(path, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2)
    f.write('\n')

print("OK: bootstrap-state.json advanced to last_migration=014")
PY
```

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0

# proj-plan-writer must have no tools: line
if [[ -f ".claude/agents/proj-plan-writer.md" ]] && grep -q "^tools:" ".claude/agents/proj-plan-writer.md"; then
  printf "FAIL: proj-plan-writer.md still has tools: line\n"
  fail=1
fi

# mcp-routing.md must contain the absolute all-agents rule wording
if [[ -f ".claude/rules/mcp-routing.md" ]] && ! grep -q "ALL agents" ".claude/rules/mcp-routing.md"; then
  printf "FAIL: mcp-routing.md missing 'ALL agents' rule wording\n"
  fail=1
fi

# bootstrap-state.json must reflect 014
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') != '014':
    print("FAIL: last_migration != 014")
    sys.exit(1)
applied = state.get('applied', [])
has_014 = any(
    (isinstance(a, dict) and a.get('id') == '014') or a == '014'
    for a in applied
)
if not has_014:
    print("FAIL: 014 not in applied[]")
    sys.exit(1)
print("OK: bootstrap-state.json reflects 014")
PY

[[ "$fail" -eq 0 ]] || exit 1
printf "Verify OK\n"
```

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"014"`
- appends `{ "id": "014", "applied_at": "{ISO8601}", "description": "plan-writer MCP access — drop tools: from proj-plan-writer, absolute all-agents rule in mcp-routing.md" }` to `applied[]`

---

## Rollback

Re-add `tools: Read, Write, Grep, Glob` to `.claude/agents/proj-plan-writer.md` frontmatter manually. Not auto-reversible. For companion/gitignored projects, restore from `~/.claude-configs/{project}/`.
