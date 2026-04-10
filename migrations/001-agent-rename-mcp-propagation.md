# Migration 001 — Agent Rename + MCP Propagation

> Rename all project agents to `proj-*` prefix to avoid built-in `Explore`/`general-purpose` capture, and fix MCP tool propagation by removing `tools:` whitelists from read-only agents + injecting `mcp__<server>__*` entries into write agents.

---

## Metadata

```yaml
id: "001"
breaking: false
affects: [agents, skills, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Two bootstrap-wide bugs found in v6.0:

1. **MCP propagation silently broken.** Every custom agent's `tools:` frontmatter is a strict whitelist in Claude Code. Specifying any `tools:` list excludes all `mcp__*` tools. Bootstrap-generated agents all declared explicit `tools:` → zero MCP access from subagents. `techniques/agent-design.md` previously documented "default: inherit" but never warned that specifying `tools:` breaks MCP propagation.

2. **Built-in `Explore` captures "researcher" dispatches.** Claude Code ships built-in subagent types `Explore` and `general-purpose` that cannot be disabled via config. The custom `researcher` agent description semantically overlapped with built-in `Explore`, and orchestrator skills dispatched via prose ("dispatch the researcher agent") instead of literal `subagent_type="researcher"`. Result: main thread picked built-in `Explore`, stripping MCP access and bypassing project memory.

Reference: brainstorm + plan at `.claude/specs/2026-04-10-agent-rename-mcp-propagation-plan.md` in the bootstrap repo.

---

## Changes

1. **Rename all project agents to `proj-*` prefix** — `.claude/agents/researcher.md` → `.claude/agents/proj-researcher.md`, etc. Prevents semantic overlap with built-ins.
2. **Remove `tools:` line from read-only agents** (proj-researcher, proj-quick-check, proj-verifier, proj-consistency-checker, proj-reflector, proj-code-reviewer) → inherit parent tools incl. MCP.
3. **Inject `mcp__<server>__*` entries into write agents' `tools:` line** (proj-debugger, proj-tdd-runner, proj-plan-writer, proj-code-writer-*, proj-test-writer-*) — one glob entry per server detected in `.mcp.json`.
4. **Update skill files** — replace old agent names with `proj-*` in backtick + `subagent_type=` contexts.
5. **Update `.claude/agents/agent-index.yaml`** if present.
6. **Re-fetch `techniques/agent-design.md`** from bootstrap repo — it now contains MCP Tool Propagation + Agent Dispatch Policy sections.
7. **Update `.claude/bootstrap-state.json`** — `last_migration` → "001".

Note: `project-code-reviewer` → `proj-code-reviewer` (drops redundant "project-" prefix).

---

## Actions

### Prerequisites

```bash
set -euo pipefail
[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: no .claude/agents directory"; exit 1; }
```

### Step 1 — Detect MCP servers from .mcp.json

```bash
MCP_SERVERS=""
if [[ -f ".mcp.json" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    MCP_SERVERS=$(python3 -c "import json; d=json.load(open('.mcp.json')); print(' '.join(d.get('mcpServers',{}).keys()))" 2>/dev/null || echo "")
  elif command -v node >/dev/null 2>&1; then
    MCP_SERVERS=$(node -e "const d=require('./.mcp.json'); console.log(Object.keys(d.mcpServers||{}).join(' '))" 2>/dev/null || echo "")
  elif command -v jq >/dev/null 2>&1; then
    MCP_SERVERS=$(jq -r '.mcpServers | keys | join(" ")' .mcp.json 2>/dev/null || echo "")
  fi
  echo "MCP servers detected: ${MCP_SERVERS:-(none — parser unavailable)}"
else
  echo "No .mcp.json found — skipping MCP injection"
fi
```

### Step 2 — Rename map + classification

```bash
declare -A RENAME_MAP=(
  ["researcher"]="proj-researcher"
  ["quick-check"]="proj-quick-check"
  ["debugger"]="proj-debugger"
  ["verifier"]="proj-verifier"
  ["reflector"]="proj-reflector"
  ["consistency-checker"]="proj-consistency-checker"
  ["tdd-runner"]="proj-tdd-runner"
  ["code-writer-markdown"]="proj-code-writer-markdown"
  ["code-writer-bash"]="proj-code-writer-bash"
  ["test-writer"]="proj-test-writer"
  ["project-code-reviewer"]="proj-code-reviewer"
  ["plan-writer"]="proj-plan-writer"
)

# Read-only agents (no tools: line after rename — inherit MCP from parent)
READ_ONLY="researcher quick-check verifier consistency-checker reflector project-code-reviewer"

inject_mcp() {
  local file="$1"
  [[ -z "${MCP_SERVERS}" ]] && return 0
  grep -q "^tools:" "$file" || return 0
  grep -q "mcp__" "$file" && return 0  # already injected

  local mcp_entries=""
  for server in $MCP_SERVERS; do
    mcp_entries="${mcp_entries}, mcp__${server}__*"
  done
  # Append to end of tools: line (handles single-line list form)
  sed -i "/^tools:/ s|$|${mcp_entries}|" "$file"
}

is_read_only() {
  local name="$1"
  for ro in $READ_ONLY; do
    [[ "$name" == "$ro" ]] && return 0
  done
  return 1
}
```

### Step 3 — Rename named agents (core 12 from rename map)

```bash
# GLOB — never hardcode per general.md migration rule
for agent_file in .claude/agents/*.md; do
  [[ -f "$agent_file" ]] || continue

  current_name=$(grep "^name:" "$agent_file" | head -1 | awk '{print $2}')
  [[ -z "$current_name" ]] && continue
  [[ "$current_name" == proj-* ]] && continue  # already renamed — idempotent skip

  new_name="${RENAME_MAP[$current_name]:-}"
  [[ -z "$new_name" ]] && continue  # not in map — skip

  new_file=".claude/agents/${new_name}.md"
  [[ -f "$new_file" ]] && { echo "SKIP: ${new_file} already exists"; continue; }

  if is_read_only "$current_name"; then
    # read-only: rename file + name field + strip tools: line
    sed "s/^name: ${current_name}$/name: ${new_name}/" "$agent_file" | grep -v "^tools:" > "$new_file"
    echo "RENAMED (read-only, tools stripped): ${current_name} -> ${new_name}"
  else
    # write agent: rename + inject MCP
    sed "s/^name: ${current_name}$/name: ${new_name}/" "$agent_file" > "$new_file"
    inject_mcp "$new_file"
    echo "RENAMED (write, MCP injected if applicable): ${current_name} -> ${new_name}"
  fi

  rm "$agent_file"
done
```

### Step 4 — Rename specialist agents (code-writer-*, test-writer-* not already handled)

```bash
# Any remaining code-writer-* / test-writer-* not already in rename map
# (e.g., code-writer-csharp, test-writer-python from Module 07)
for pattern in "code-writer-" "test-writer-"; do
  for agent_file in .claude/agents/${pattern}*.md; do
    [[ -f "$agent_file" ]] || continue
    filename=$(basename "$agent_file" .md)
    [[ "$filename" == proj-* ]] && continue  # already renamed

    current_name="$filename"
    new_name="proj-${filename}"
    new_file=".claude/agents/${new_name}.md"
    [[ -f "$new_file" ]] && { echo "SKIP: ${new_file} already exists"; continue; }

    sed "s/^name: ${current_name}$/name: ${new_name}/" "$agent_file" > "$new_file"
    inject_mcp "$new_file"
    rm "$agent_file"
    echo "RENAMED specialist: ${current_name} -> ${new_name}"
  done
done
```

### Step 5 — Update skill files (references to renamed agents)

```bash
# Glob all skill files — include both flat and nested layouts
shopt -s globstar nullglob
for skill_file in .claude/skills/**/SKILL.md .claude/skills/*.md; do
  [[ -f "$skill_file" ]] || continue

  for old_name in "${!RENAME_MAP[@]}"; do
    new_name="${RENAME_MAP[$old_name]}"
    # Backtick-wrapped references: `old-name` -> `new-name`
    sed -i "s/\`${old_name}\`/\`${new_name}\`/g" "$skill_file"
    # Explicit subagent_type: subagent_type="old-name" -> subagent_type="new-name"
    sed -i "s/subagent_type=\"${old_name}\"/subagent_type=\"${new_name}\"/g" "$skill_file"
    sed -i "s/subagent_type: \"${old_name}\"/subagent_type: \"${new_name}\"/g" "$skill_file"
    # Agent: old-name lines
    sed -i "s/^Agent: ${old_name}$/Agent: ${new_name}/" "$skill_file"
  done

  # code-writer-* / test-writer-* specialists (glob patterns inside skills)
  sed -i 's|`code-writer-\([a-z0-9-]*\)`|`proj-code-writer-\1`|g' "$skill_file"
  sed -i 's|`test-writer-\([a-z0-9-]*\)`|`proj-test-writer-\1`|g' "$skill_file"
  sed -i 's|subagent_type="code-writer-\([a-z0-9-]*\)"|subagent_type="proj-code-writer-\1"|g' "$skill_file"
  sed -i 's|subagent_type="test-writer-\([a-z0-9-]*\)"|subagent_type="proj-test-writer-\1"|g' "$skill_file"

  echo "UPDATED skill: $skill_file"
done
shopt -u globstar nullglob
```

### Step 6 — Update agent-index.yaml (if exists)

```bash
if [[ -f ".claude/agents/agent-index.yaml" ]]; then
  for old_name in "${!RENAME_MAP[@]}"; do
    new_name="${RENAME_MAP[$old_name]}"
    sed -i "s/name: ${old_name}$/name: ${new_name}/" .claude/agents/agent-index.yaml
    sed -i "s/parent: ${old_name}$/parent: ${new_name}/" .claude/agents/agent-index.yaml
  done
  # Specialist patterns
  sed -i 's|name: code-writer-\([a-z0-9-]*\)|name: proj-code-writer-\1|g' .claude/agents/agent-index.yaml
  sed -i 's|name: test-writer-\([a-z0-9-]*\)|name: proj-test-writer-\1|g' .claude/agents/agent-index.yaml
  sed -i 's|parent: code-writer-\([a-z0-9-]*\)|parent: proj-code-writer-\1|g' .claude/agents/agent-index.yaml
  echo "UPDATED agent-index.yaml"
fi
```

### Step 7 — Sync updated technique file from bootstrap repo

```bash
# Per general.md: "technique update = sync step in migration"
# Bootstrap v6 agent-design.md now contains MCP Tool Propagation + Agent Dispatch Policy
BOOTSTRAP_REPO=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['bootstrap_repo'])" 2>/dev/null || echo "tomasfil/claude-bootstrap")

mkdir -p .claude/references/techniques
if command -v gh >/dev/null 2>&1; then
  gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/agent-design.md" \
    --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
else
  curl -sSL "https://raw.githubusercontent.com/${BOOTSTRAP_REPO}/main/techniques/agent-design.md" \
    -o .claude/references/techniques/agent-design.md
fi
echo "UPDATED .claude/references/techniques/agent-design.md from ${BOOTSTRAP_REPO}"
```

### Step 8 — Update bootstrap-state.json

```bash
python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '001'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '001') or a == '001' for a in applied):
    applied.append({'id': '001', 'applied_at': state['last_applied'], 'description': 'agent rename + MCP propagation'})
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=001')
PY
```

---

## Verify

```bash
# Re-derive MCP_SERVERS for verify block (Step 1's var may not persist across blocks)
MCP_SERVERS=""
if [[ -f ".mcp.json" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    MCP_SERVERS=$(python3 -c "import json; d=json.load(open('.mcp.json')); print(' '.join(d.get('mcpServers',{}).keys()))" 2>/dev/null || echo "")
  elif command -v node >/dev/null 2>&1; then
    MCP_SERVERS=$(node -e "const d=require('./.mcp.json'); console.log(Object.keys(d.mcpServers||{}).join(' '))" 2>/dev/null || echo "")
  elif command -v jq >/dev/null 2>&1; then
    MCP_SERVERS=$(jq -r '.mcpServers | keys | join(" ")' .mcp.json 2>/dev/null || echo "")
  fi
fi

set +e
fail=0

# 1. No old unprefixed agents remain
for old in researcher quick-check debugger verifier reflector consistency-checker \
           tdd-runner plan-writer code-writer-markdown code-writer-bash \
           test-writer project-code-reviewer; do
  if [[ -f ".claude/agents/${old}.md" ]]; then
    echo "FAIL: old agent still exists: ${old}.md"
    fail=1
  fi
done

# 2. Core proj-* agents exist (only check those that were present before)
for new in proj-researcher proj-quick-check proj-debugger proj-verifier \
           proj-reflector proj-consistency-checker proj-tdd-runner \
           proj-plan-writer proj-code-writer-markdown proj-code-writer-bash; do
  if [[ -f ".claude/agents/${new}.md" ]]; then
    echo "PASS: ${new}.md"
  else
    echo "WARN: ${new}.md missing (may not have existed before migration)"
  fi
done

# 3. Read-only agents must NOT have tools: line
for ro in proj-researcher proj-quick-check proj-verifier proj-consistency-checker proj-reflector proj-code-reviewer; do
  [[ -f ".claude/agents/${ro}.md" ]] || continue
  if grep -q "^tools:" ".claude/agents/${ro}.md"; then
    echo "FAIL: ${ro}.md still has tools: line (must inherit)"
    fail=1
  else
    echo "PASS: ${ro}.md no tools: line"
  fi
done

# 4. Write agents must have tools: line
for wa in proj-debugger proj-tdd-runner proj-plan-writer proj-code-writer-markdown proj-code-writer-bash; do
  [[ -f ".claude/agents/${wa}.md" ]] || continue
  if grep -q "^tools:" ".claude/agents/${wa}.md"; then
    echo "PASS: ${wa}.md has tools:"
  else
    echo "FAIL: ${wa}.md missing tools:"
    fail=1
  fi
done

# 5. If MCP configured: write agents must have mcp__ entries
if [[ -f ".mcp.json" && -n "${MCP_SERVERS:-}" ]]; then
  for wa in proj-code-writer-markdown proj-code-writer-bash proj-debugger; do
    [[ -f ".claude/agents/${wa}.md" ]] || continue
    if grep -q "mcp__" ".claude/agents/${wa}.md"; then
      echo "PASS: ${wa}.md has MCP entries"
    else
      echo "FAIL: ${wa}.md missing MCP entries (mcp servers: ${MCP_SERVERS})"
      fail=1
    fi
  done
fi

# 6. Skills should have no old unprefixed dispatches
old_regex="subagent_type=\"(researcher|quick-check|debugger|verifier|reflector|consistency-checker|tdd-runner|plan-writer|code-writer-markdown|code-writer-bash|test-writer|project-code-reviewer)\""
bad=$(grep -rEn "$old_regex" .claude/skills/ 2>/dev/null || true)
if [[ -n "$bad" ]]; then
  echo "FAIL: old subagent_type references in skills:"
  echo "$bad"
  fail=1
else
  echo "PASS: no old subagent_type refs in skills"
fi

# 7. Technique file has new sections
grep -q "## MCP Tool Propagation" .claude/references/techniques/agent-design.md && echo "PASS: MCP Tool Propagation present" || { echo "FAIL: MCP Tool Propagation missing"; fail=1; }
grep -q "## Agent Dispatch Policy" .claude/references/techniques/agent-design.md && echo "PASS: Agent Dispatch Policy present" || { echo "FAIL: Agent Dispatch Policy missing"; fail=1; }

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 001 verification: ALL PASS" || { echo "Migration 001 verification: FAILURES — state NOT updated"; exit 1; }
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → "001"
- append `{ "id": "001", "applied_at": "<ISO8601>", "description": "agent rename + MCP propagation" }` to `applied[]`

---

## Rollback

Not automatic. Restore from git (all changes are in `.claude/agents/`, `.claude/skills/`, `.claude/references/techniques/agent-design.md`, `.claude/bootstrap-state.json`). If `.claude/` is gitignored, restore from companion repo or re-bootstrap.
