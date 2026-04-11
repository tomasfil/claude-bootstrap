# Migration 013 — MCP glob fix (drop tools: from write agents)

<!-- migration-id: 013-mcp-glob-fix -->

> Strip the `tools:` frontmatter line from all write agents so Claude Code inherits parent MCP tools; `proj-plan-writer` is intentionally excluded (MCP-free by design).

---

## Metadata

```yaml
id: "013"
breaking: false
affects: [agents, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Write agents bootstrapped via migrations 001–012 carry an explicit `tools:` frontmatter line (e.g. `tools: Read, Write, Edit, Grep, Glob, Bash`). Claude Code silently ignores `mcp__<server>__*` glob entries when a `tools:` list is present — any MCP access pattern added to a write agent has no effect. The fix is to remove the `tools:` line from all write agents so they inherit the parent session's full tool set including MCP access. Read-only agents already omit `tools:` (correct behavior). `proj-plan-writer` is intentionally MCP-free and must NOT be modified.

---

## Changes

1. Strips `tools:` frontmatter line from `.claude/agents/proj-debugger.md`.
2. Strips `tools:` frontmatter line from `.claude/agents/proj-tdd-runner.md`.
3. Strips `tools:` frontmatter line from all `.claude/agents/proj-code-writer-*.md` (glob — includes sub-specialists from `/evolve-agents`).
4. Strips `tools:` frontmatter line from all `.claude/agents/proj-test-writer-*.md` (glob — includes sub-specialists from `/evolve-agents`).
5. Skips `proj-plan-writer.md` (MCP-free by design — defensive check prints explicit notice).
6. Fetches updated `.claude/rules/mcp-routing.md` from bootstrap repo (reflects write-agent guidance).
7. Advances `.claude/bootstrap-state.json` → `last_migration: "013"` + appends `"013"` to `applied[]`.

Idempotent: if `proj-debugger.md` already has no `^tools:` line, prints `SKIP: already patched` and exits.

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

# Migration 001 must be applied — that's where tools: injection originated
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_001 = any(
    (isinstance(a, dict) and a.get('id') == '001') or a == '001'
    for a in applied
)
if not has_001:
    print("ERROR: migration 001 (initial bootstrap) not applied — cannot apply 013")
    sys.exit(1)
print("OK: migration 001 present in applied[]")
PY
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -f ".claude/agents/proj-debugger.md" ]] && \
   ! grep -q "^tools:" ".claude/agents/proj-debugger.md"; then
  printf "SKIP: already patched (proj-debugger.md has no tools: line)\n"
  exit 0
fi

printf "Applying migration 013: stripping tools: from write agents\n"
```

### Step 1 — Strip `tools:` from named write agents

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

strip_tools_line ".claude/agents/proj-debugger.md"
strip_tools_line ".claude/agents/proj-tdd-runner.md"
```

### Step 2 — Glob-strip `proj-code-writer-*.md` and `proj-test-writer-*.md`

```bash
#!/usr/bin/env bash
set -euo pipefail

strip_tools_line() {
  local file="$1"
  if ! grep -q "^tools:" "$file"; then
    printf "SKIP: %s — no tools: line present\n" "$file"
    return
  fi
  local tmp
  tmp="$(mktemp)"
  grep -v "^tools:" "$file" > "$tmp"
  mv "$tmp" "$file"
  printf "PATCHED: %s — tools: line removed\n" "$file"
}

shopt -s nullglob

for agent in .claude/agents/proj-code-writer-*.md; do
  strip_tools_line "$agent"
done

for agent in .claude/agents/proj-test-writer-*.md; do
  strip_tools_line "$agent"
done

shopt -u nullglob
```

### Step 3 — Defensive skip notice for `proj-plan-writer`

```bash
#!/usr/bin/env bash
set -euo pipefail

# proj-plan-writer is intentionally MCP-free — never strip its tools: line
if [[ -f ".claude/agents/proj-plan-writer.md" ]]; then
  printf "SKIP proj-plan-writer: MCP-free by design — tools: line retained\n"
fi
```

### Step 4 — Update `.claude/rules/mcp-routing.md` (inline — file is gitignored in bootstrap repo)

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

## Agent layer (write agents only)
Write agents: OMIT `tools:` entirely → inherit parent tools incl. MCP. `agent-scope-lock.md` enforces file-level scope restriction. Only add explicit `tools:` if the agent must be HARD-RESTRICTED from certain tools AND you are willing to maintain a literal (non-glob) MCP tool list.
Read-only agents: OMIT `tools:` entirely → inherit parent tools incl. MCP.

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

### Step 5 — Advance bootstrap state

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
    (isinstance(a, dict) and a.get('id') == '013') or a == '013'
    for a in applied
)
if already:
    print("SKIP: 013 already in applied[]")
    sys.exit(0)

state['last_migration'] = '013'
applied.append({
    'id': '013',
    'applied_at': datetime.now(timezone.utc).isoformat(),
    'description': 'MCP glob fix — drop tools: from write agents'
})
state['applied'] = applied

with open(path, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2)
    f.write('\n')

print("OK: bootstrap-state.json advanced to last_migration=013")
PY
```

---

## Verify

```bash
#!/usr/bin/env bash
set -euo pipefail

fail=0

# proj-debugger must have no tools: line
if [[ -f ".claude/agents/proj-debugger.md" ]] && grep -q "^tools:" ".claude/agents/proj-debugger.md"; then
  printf "FAIL: proj-debugger.md still has tools: line\n"
  fail=1
fi

# proj-tdd-runner must have no tools: line (if present)
if [[ -f ".claude/agents/proj-tdd-runner.md" ]] && grep -q "^tools:" ".claude/agents/proj-tdd-runner.md"; then
  printf "FAIL: proj-tdd-runner.md still has tools: line\n"
  fail=1
fi

# proj-plan-writer must still have its tools: line (MCP-free by design)
if [[ -f ".claude/agents/proj-plan-writer.md" ]] && ! grep -q "^tools:" ".claude/agents/proj-plan-writer.md"; then
  printf "FAIL: proj-plan-writer.md lost its tools: line — should have been skipped\n"
  fail=1
fi

# bootstrap-state.json must reflect 013
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
if state.get('last_migration') != '013':
    print("FAIL: last_migration != 013")
    sys.exit(1)
applied = state.get('applied', [])
has_013 = any(
    (isinstance(a, dict) and a.get('id') == '013') or a == '013'
    for a in applied
)
if not has_013:
    print("FAIL: 013 not in applied[]")
    sys.exit(1)
print("OK: bootstrap-state.json reflects 013")
PY

[[ "$fail" -eq 0 ]] || exit 1
printf "Verify OK\n"
```

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → `"013"`
- appends `{ "id": "013", "applied_at": "{ISO8601}", "description": "MCP glob fix — drop tools: from write agents" }` to `applied[]`

---

## Rollback

Not rollback-able automatically. To restore: re-add `tools: Read, Grep, Glob, Bash` (or the original tools list) to the frontmatter of each patched agent. Restore from git: `git checkout HEAD~1 -- .claude/agents/`.
