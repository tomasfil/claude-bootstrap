## Migration 011 — Agent rules audit + STEP 0 force-read retrofit

> Retrofit existing client projects with `mcp-routing.md` rule, updated `agent-design.md` technique, `STEP 0 — Load critical rules` force-read block in every sub-agent, and `/audit-agents` skill. Delegates MCP re-injection to migration 001. Dispatches `/audit-agents` for post-retrofit validation.

---

## Metadata

```yaml
id: "011"
breaking: false
affects: [agents, skills, techniques, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Rule propagation to sub-agents was unreliable across `@import` chains — rules loaded into `CLAUDE.md` via `@import` did not consistently surface inside forked sub-agents, so cross-cutting policies (MCP routing, token efficiency, skill routing) could silently fail to reach the agent that needed them. The fix is a first-class force-read pattern: every sub-agent body begins with a `STEP 0 — Load critical rules` block that explicitly `Read`s critical rules before any task-specific work, landing the content as conversation messages rather than relying on system-prompt inheritance.

New bootstraps (via updated `modules/05-core-agents.md` + `modules/07-code-specialists.md`) already generate the STEP 0 block. Existing projects need a retrofit:

1. Fetch the updated `techniques/agent-design.md` (now includes the `§ Force-Read Directive Pattern` + `§ MCP Tool Usage Patterns` sections) into the canonical client path.
2. Write `.claude/rules/mcp-routing.md` if absent.
3. Ensure `CLAUDE.md` `@import`s the new rule.
4. Inject the STEP 0 block into every existing `.claude/agents/proj-*.md` file (excluding `references/` subdir).
5. Write `.claude/skills/audit-agents/SKILL.md` so Claude can validate the retrofit end-to-end.
6. Dispatch `/audit-agents` after the migration completes (final echo; no banner parser).

MCP tool re-injection is explicitly out of scope — that belongs to migration 001. This migration refuses to run until 001 is applied.

Spec: `.claude/specs/main/2026-04-11-mcp-routing-audit-spec.md` § "v2 Migration 010" (renumbered to 011 to avoid ID collision w/ `010-plan-writer-dispatch-units.md`).

---

## Changes

1. **Delegate check** — refuse to run if migration 001 not in `bootstrap-state.json` `applied[]`.
2. **Technique sync** — fetch updated `techniques/agent-design.md` from bootstrap repo → `.claude/references/techniques/agent-design.md` (cmp-guarded).
3. **Rule write** — idempotent write of `.claude/rules/mcp-routing.md` (marker `# MCP Routing`).
4. **CLAUDE.md import** — insert `@import .claude/rules/mcp-routing.md` after existing `@import` lines if missing. Skip if no CLAUDE.md.
5. **STEP 0 retrofit** — glob `.claude/agents/proj-*.md` (sub-specialist-safe; `*.md` does not recurse into `references/`). For each file missing marker `STEP 0 — Load critical rules`, inject the verbatim block immediately after the frontmatter closing `---`.
6. **Audit skill write** — idempotent write of `.claude/skills/audit-agents/SKILL.md` (marker `name: audit-agents`).
7. **Final echo** — plain `echo "NEXT ACTION: invoke /audit-agents to validate force-read + MCP propagation across all agents."` — no banner, Claude reads output in context.
8. **State advance** — `last_migration: "011"`.

Idempotent: every step detects its marker and prints `SKIP: already applied`.

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/rules" ]] || { echo "ERROR: no .claude/rules directory"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: no .claude/agents directory"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Delegate MCP re-injection to migration 001

Migration 011 does not touch agent `tools:` allowlists. MCP propagation is migration 001's responsibility. If 001 has not been applied on this project, abort immediately with guidance — do NOT silently re-do 001's work.

Parses `.claude/bootstrap-state.json`'s `applied[]` array and looks for an entry shaped `{"id":"001", ...}`. Accepts legacy bare-string form `"001"` for older state files.

```bash
set -euo pipefail

python3 <<'PY'
import json, sys

# Required applied[] entry shape: {"id":"001", ...}
REQUIRED_ID = "001"

with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)

applied = state.get('applied', [])
has_001 = any(
    (isinstance(a, dict) and a.get("id") == REQUIRED_ID) or a == REQUIRED_ID
    for a in applied
)

if not has_001:
    print("ERROR: migration 001 must be applied first — run /migrate-bootstrap")
    sys.exit(1)

print("OK: migration 001 present in applied[] — proceeding")
PY
```

### Step 2 — Sync `techniques/agent-design.md` from bootstrap repo

Fetches the updated technique file (now containing `§ Force-Read Directive Pattern` + `§ MCP Tool Usage Patterns`) into the **canonical client layout** `.claude/references/techniques/agent-design.md` — NOT `techniques/` at project root (see migration 008 for the path-fix rationale).

Idempotent: fetch to `.new` tempfile, `cmp -s` against existing, replace only on diff.

```bash
set -euo pipefail

TECH_DIR=".claude/references/techniques"
mkdir -p "$TECH_DIR"

BOOTSTRAP_REPO=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['bootstrap_repo'])" 2>/dev/null || printf "%s" "tomasfil/claude-bootstrap")

RAW_BASE=$(python3 <<PY
repo = "${BOOTSTRAP_REPO}".rstrip('/')
if 'github.com' in repo:
    parts = repo.replace('https://github.com/', '')
    print(f'https://raw.githubusercontent.com/{parts}/main')
else:
    print(f'https://raw.githubusercontent.com/{repo}/main')
PY
)

dest="${TECH_DIR}/agent-design.md"
tmp="${dest}.new"

if command -v gh >/dev/null 2>&1; then
  if ! gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/agent-design.md" --jq '.content' 2>/dev/null | base64 -d > "$tmp"; then
    rm -f "$tmp"
    echo "ERROR: gh fetch of techniques/agent-design.md failed"
    exit 1
  fi
elif command -v curl >/dev/null 2>&1; then
  if ! curl -fsSL "${RAW_BASE}/techniques/agent-design.md" -o "$tmp"; then
    rm -f "$tmp"
    echo "ERROR: curl fetch of techniques/agent-design.md failed"
    exit 1
  fi
else
  echo "ERROR: neither gh nor curl available — cannot sync technique"
  exit 1
fi

if [[ ! -s "$tmp" ]]; then
  rm -f "$tmp"
  echo "ERROR: fetched agent-design.md is empty"
  exit 1
fi

if [[ -f "$dest" ]] && cmp -s "$dest" "$tmp"; then
  rm "$tmp"
  echo "SKIP: ${dest} already up to date"
else
  mv "$tmp" "$dest"
  echo "UPDATED: ${dest}"
fi
```

### Step 3 — Write `.claude/rules/mcp-routing.md`

Idempotent: skip if file exists AND contains marker `# MCP Routing`. Otherwise write the full rule content (same content as the one embedded in `modules/02-project-config.md` Step 3 by the Batch A2 edit).

```bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/rules/mcp-routing.md"
marker = "# MCP Routing"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        if marker in f.read():
            print(f"SKIP: {path} already present")
            sys.exit(0)

content = """# MCP Routing

## Rule
MCP tools route through sub-agents — NEVER skill `allowed-tools:`.

## Skill layer (NEVER add mcp__* here)
`allowed-tools:` controls skill's own invocation permissions — does NOT cascade to
dispatched agents. Adding `mcp__*` to a skill's `allowed-tools:` is always wrong.

## Agent layer (write agents only)
Write agents that need MCP access: keep `tools:` list + add `mcp__<server>__*` per
`.mcp.json` `mcpServers` keys. One glob entry per server key.
Read-only agents: OMIT `tools:` entirely → inherit parent tools incl. MCP.

## When .mcp.json changes
Run `/migrate-bootstrap` (triggers migration-001 re-check) or `/audit-agents`
to validate MCP propagation across all agents.

## Routing table
If MCPs present, the routing table below is the single source for tool→action mappings.
Populate per project during bootstrap or when new MCP servers are added.

| MCP Server | Glob | Use for |
|------------|------|---------|
| {server}   | mcp__<server>__* | {description — fill from .mcp.json} |
"""

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"WROTE: {path}")
PY
```

### Step 4 — Ensure `CLAUDE.md` imports the new rule

If `CLAUDE.md` exists and does not already contain `@import .claude/rules/mcp-routing.md`, insert the import line after the last existing `@import` line. Skip entirely if `CLAUDE.md` is absent (some projects keep all context in `.claude/`).

```bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = "CLAUDE.md"
import_line = "@import .claude/rules/mcp-routing.md"

if not os.path.isfile(path):
    print(f"SKIP: {path} not present")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if import_line in content:
    print(f"SKIP: {path} already imports mcp-routing.md")
    sys.exit(0)

lines = content.split("\n")
last_import_idx = -1
for i, line in enumerate(lines):
    if line.lstrip().startswith("@import"):
        last_import_idx = i

if last_import_idx >= 0:
    lines.insert(last_import_idx + 1, import_line)
    action = f"inserted after line {last_import_idx + 1}"
else:
    # No existing @import lines — insert near top, after first heading if any.
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("# "):
            insert_at = i + 1
            break
    lines.insert(insert_at, import_line)
    action = f"inserted at line {insert_at} (no prior @import lines)"

with open(path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print(f"PATCHED: {path} — {action}")
PY
```

### Step 5 — Retrofit STEP 0 force-read block into every sub-agent

Globs `.claude/agents/proj-*.md` using shell glob patterns that cover sub-specialists created by `/evolve-agents` (e.g. `proj-code-writer-bash.md`, `proj-test-writer-python.md`). The `*.md` shell glob does NOT recurse into `.claude/agents/references/` subdir, so that exclusion is implicit — but the loop also guards with an explicit `references/` path check as defense in depth.

For each agent missing the marker `STEP 0 — Load critical rules`, inject the verbatim force-read block immediately after the frontmatter closing `---` (the second `---` in the file — the one that closes YAML frontmatter opened by the first `---`).

Idempotent: every re-run detects the marker and prints `SKIP: already patched`.

```bash
set -euo pipefail

python3 <<'PY'
import glob, os, sys

MARKER = "STEP 0 — Load critical rules"

STEP0_BLOCK = """## STEP 0 — Load critical rules (MANDATORY first action)

Before any task-specific work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
- `.claude/rules/code-standards-{your primary lang}.md` (if present)

Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

---

"""

# Collect candidate agent files. Shell-level *.md does not descend into
# references/, but we re-check path components anyway.
patterns = [
    ".claude/agents/proj-code-writer-*.md",
    ".claude/agents/proj-test-writer-*.md",
    ".claude/agents/proj-*.md",
]
seen = set()
candidates = []
for pat in patterns:
    for p in sorted(glob.glob(pat)):
        norm = os.path.normpath(p).replace("\\", "/")
        if "references/" in norm:
            continue
        if norm in seen:
            continue
        seen.add(norm)
        candidates.append(norm)

patched = 0
skipped_already = 0
skipped_noframe = 0

for path in candidates:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if MARKER in content:
        skipped_already += 1
        continue

    # Locate frontmatter closing ---. File must START with --- on line 1.
    lines = content.split("\n")
    if not lines or lines[0].strip() != "---":
        print(f"WARN: {path} — no YAML frontmatter opener; left unchanged")
        skipped_noframe += 1
        continue

    close_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            close_idx = i
            break

    if close_idx is None:
        print(f"WARN: {path} — no YAML frontmatter closer; left unchanged")
        skipped_noframe += 1
        continue

    # Insert the STEP 0 block immediately after the frontmatter closer.
    # Pattern: split on close_idx, rebuild with block inserted on the line
    # after the closing ---.
    before = "\n".join(lines[: close_idx + 1])
    after = "\n".join(lines[close_idx + 1 :])
    # Ensure exactly one blank line between frontmatter and the block,
    # and preserve existing body.
    new_content = before + "\n\n" + STEP0_BLOCK + after.lstrip("\n")

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"PATCHED: {path}")
    patched += 1

print(f"SUMMARY: patched={patched} skipped_already={skipped_already} skipped_noframe={skipped_noframe} total_candidates={len(candidates)}")
PY
```

### Step 6 — Write `.claude/skills/audit-agents/SKILL.md`

Idempotent: skip if file exists AND contains marker `name: audit-agents`. Otherwise `mkdir -p` the skill directory and write the full SKILL.md body. Main-thread orchestrator class (like `/verify`, `/reflect`) — dispatches `proj-consistency-checker` with the A1–A6 audit task brief.

```bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/skills/audit-agents/SKILL.md"
marker = "name: audit-agents"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        if marker in f.read():
            print(f"SKIP: {path} already present")
            sys.exit(0)

content = """---
name: audit-agents
description: >
  Use when auditing agents for missing force-read blocks, MCP tool propagation
  issues, skill anti-patterns, or rule file gaps. Dispatches
  proj-consistency-checker with a widened audit brief.
allowed-tools: Agent Read
model: opus
effort: high
# Skill Class: main-thread — dispatches proj-consistency-checker, interactive report review
---

## /audit-agents — Agent Rules + MCP Propagation Audit

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Audit report: `proj-consistency-checker`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Scope
Validates that every sub-agent reliably loads critical rules + MCP tools propagate
correctly. Does NOT auto-patch — produces a report; user decides on fixes.

### Dispatch

Dispatch agent via `subagent_type="proj-consistency-checker"` w/ audit task brief:

- **A1 — STEP 0 force-read presence**: for every `.claude/agents/*.md` (exclude
  `references/` subtree), verify body contains marker `STEP 0 — Load critical rules`.
  Report agents missing the marker w/ `file:line` evidence (line = frontmatter close).
- **A2 — Rule file existence**: parse every `.claude/rules/<name>.md` reference
  inside STEP 0 blocks. Verify each referenced file exists in `.claude/rules/`.
  Report dangling refs w/ source agent + rule path.
- **A3 — MCP tool propagation**: if `.mcp.json` exists — parse `mcpServers` keys.
  For every agent w/ an explicit `tools:` line, verify one `mcp__<server>__*` entry
  exists per server key. Report missing entries w/ agent + missing server name.
  No `.mcp.json` → skip A3 w/ INFO.
- **A4 — Skill anti-pattern**: scan every `.claude/skills/*/SKILL.md` frontmatter
  `allowed-tools:` value. FAIL if any value contains `mcp__*` (skills must not
  name MCP tools directly — MCPs belong on agents). Report offenders w/ file:line.
- **A5 — CLAUDE.md imports**: verify `CLAUDE.md` exists at project root and
  `@import`s `general.md` + `skill-routing.md`. If `.mcp.json` present, also
  verify `@import .claude/rules/mcp-routing.md`. Report missing imports.
- **A6 — cmm index status**: if `.mcp.json` configures a cmm-compatible MCP
  (serena, code-context, etc.), verify repo is indexed (server-specific probe
  or presence of index artifacts). Absent cmm MCP → skip w/ WARN.

### Output

Agent writes YAML-ish report to `.claude/reports/audit-agents-{timestamp}.md`
via Bash heredoc. Format:

```yaml
audit: agent-rules-mcp
timestamp: {ISO8601}
checks:
  A1_force_read:   {PASS|FAIL|SKIP}
  A2_rule_exists:  {PASS|FAIL|SKIP}
  A3_mcp_tools:    {PASS|FAIL|SKIP}
  A4_skill_mcp:    {PASS|FAIL|SKIP}
  A5_claude_md:    {PASS|FAIL|SKIP}
  A6_cmm_index:    {PASS|WARN|SKIP}
findings:
  - check: A1
    severity: FAIL
    evidence: "{file}:{line}"
    detail: "{what's missing}"
```

Return: report path + 1-line summary (PASS count / FAIL count / WARN count).
Agent does NOT auto-patch — reports only. Main thread presents findings to user.

### After the agent returns

Read the report. Surface any FAIL entries to the user with file:line evidence
and a one-line fix recommendation per category:
- A1 FAIL → run `/migrate-bootstrap` (re-applies migration 011 STEP 0 retrofit)
- A2 FAIL → create missing rule file or remove dangling reference from STEP 0 block
- A3 FAIL → run `/migrate-bootstrap` (re-applies migration 001 MCP propagation)
- A4 FAIL → remove `mcp__*` from skill `allowed-tools:` — MCP belongs in agents
- A5 FAIL → add missing `@import` lines to CLAUDE.md
- A6 WARN → index the repo (cmm/serena) or ignore if MCP unused

Do NOT auto-patch. User approves fixes.

### Anti-hallucination
Only cite files that exist; only report line numbers via actual grep output;
uncertain check → SKIP not FAIL; no speculation about MCP servers not declared
in `.mcp.json`.
"""

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"WROTE: {path}")
PY
```

### Step 7 — Update `bootstrap-state.json` + final echo

```bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '011'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '011') or a == '011' for a in applied):
    applied.append({
        'id': '011',
        'applied_at': state['last_applied'],
        'description': 'agent rules audit — retrofit STEP 0 force-read + write mcp-routing.md + write /audit-agents skill'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=011')
PY

echo "NEXT ACTION: invoke /audit-agents to validate force-read + MCP propagation across all agents."
```

### Rules for migration scripts

- **Glob agent filenames, never hardcode** — Step 5 globs `proj-code-writer-*.md`, `proj-test-writer-*.md`, `proj-*.md` so sub-specialists created by `/evolve-agents` receive the retrofit.
- **Read-before-write** — every patch step reads the target file, detects its marker, and only writes on change.
- **Idempotent** — re-running prints `SKIP: already applied` for each already-patched target. Running twice is a no-op.
- **Self-contained** — Step 2 fetches only tracked files from the bootstrap repo (`techniques/agent-design.md`). No fetch from gitignored paths.
- **Technique sync destination** — `.claude/references/techniques/agent-design.md` (client layout), NOT `techniques/` at project root (bootstrap repo layout). See migration 008 for the path-fix rationale.
- **Delegate, don't duplicate** — Step 1 refuses to run if migration 001 is absent. This migration does NOT touch agent `tools:` allowlists; MCP re-injection is 001's job.
- **No multi-line sed** — all multi-line edits go through python3 heredocs. Sed multi-line is fragile on Windows bash.
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on failure. Any failure → `/migrate-bootstrap` does NOT update state.
- **Scope lock** — only touches the targets above + `bootstrap-state.json`. No agent renames, no skill rewrites beyond `audit-agents`, no unrelated cleanup.

### Required: register in migrations/index.json

Add an entry to the `migrations` array:

```json
{
  "id": "011",
  "file": "011-agent-rules-audit.md",
  "description": "Retrofit existing client projects with mcp-routing.md rule + updated agent-design.md technique + STEP 0 force-read block in every sub-agent + /audit-agents skill. Delegates MCP re-injection to migration 001.",
  "breaking": false
}
```

---

## Verify

```bash
set +e
fail=0

# 1. mcp-routing.md rule file present
if [[ -f ".claude/rules/mcp-routing.md" ]] && grep -q '^# MCP Routing' .claude/rules/mcp-routing.md; then
  echo "PASS: .claude/rules/mcp-routing.md present"
else
  echo "FAIL: .claude/rules/mcp-routing.md missing or lacks header"
  fail=1
fi

# 2. audit-agents skill file present
if [[ -f ".claude/skills/audit-agents/SKILL.md" ]] && grep -q 'name: audit-agents' .claude/skills/audit-agents/SKILL.md; then
  echo "PASS: .claude/skills/audit-agents/SKILL.md present"
else
  echo "FAIL: .claude/skills/audit-agents/SKILL.md missing or lacks name marker"
  fail=1
fi

# 3. CLAUDE.md imports mcp-routing.md — only checked if CLAUDE.md exists
if [[ -f "CLAUDE.md" ]]; then
  if grep -q '@import .claude/rules/mcp-routing.md' CLAUDE.md; then
    echo "PASS: CLAUDE.md imports mcp-routing.md"
  else
    echo "FAIL: CLAUDE.md missing @import .claude/rules/mcp-routing.md"
    fail=1
  fi
else
  echo "SKIP: CLAUDE.md not present — @import check skipped"
fi

# 4. Every non-reference sub-agent contains the STEP 0 marker
missing_step0=0
total_agents=0
for agent in .claude/agents/proj-*.md; do
  [[ -f "$agent" ]] || continue
  case "$agent" in
    *references/*) continue ;;
  esac
  total_agents=$((total_agents + 1))
  if ! grep -q 'STEP 0 — Load critical rules' "$agent"; then
    echo "  missing STEP 0: $agent"
    missing_step0=$((missing_step0 + 1))
  fi
done
if [[ "$total_agents" -eq 0 ]]; then
  echo "PASS: no proj-*.md agents to check (fresh project)"
elif [[ "$missing_step0" -eq 0 ]]; then
  echo "PASS: all $total_agents sub-agent(s) carry STEP 0 marker"
else
  echo "FAIL: $missing_step0 of $total_agents sub-agent(s) missing STEP 0 marker"
  fail=1
fi

# 5. State file updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "011" ]]; then
  echo "PASS: last_migration = 011"
else
  echo "FAIL: last_migration = $last (expected 011)"
  fail=1
fi

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 011 verification: ALL PASS" || { echo "Migration 011 verification: FAILURES — state NOT updated"; exit 1; }
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → "011"
- append `{ "id": "011", "applied_at": "<ISO8601>", "description": "agent rules audit — retrofit STEP 0 force-read + write mcp-routing.md + write /audit-agents skill" }` to `applied[]`

---

## Rollback

Not rollback-able. Restore from git if needed.

The migration is additive (inserts a block into agent bodies, writes new rule file, writes new skill file, adds an `@import` line to `CLAUDE.md`). No content is deleted from user files. If rollback is required:

```bash
# Tracked strategy (files committed to project repo)
git checkout -- .claude/agents/ .claude/rules/mcp-routing.md CLAUDE.md
rm -rf .claude/skills/audit-agents
git checkout -- .claude/references/techniques/agent-design.md

# Companion strategy — restore from companion repo snapshot
# cp -r ~/.claude-configs/<project>/.claude/agents/ ./.claude/
# cp    ~/.claude-configs/<project>/.claude/rules/mcp-routing.md ./.claude/rules/
# cp    ~/.claude-configs/<project>/CLAUDE.md ./
```

Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"010"` and remove the `011` entry from `applied[]`.
