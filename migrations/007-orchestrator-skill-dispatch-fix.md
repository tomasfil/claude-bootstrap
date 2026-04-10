# Migration 007 — Orchestrator Skill Dispatch Fix

> Reclassify main-thread vs forkable orchestrator skills, enforce frontmatter contract (no `context: fork` on interactive orchestrators), inject pre-flight gate, audit agent tool whitelists per role table, and promote `/test-fork` as a permanent diagnostic.

---

## Metadata

```yaml
id: "007"
breaking: false
affects: [skills, agents, techniques]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Three root causes combine to make orchestrator skills perform work inline on the main thread instead of dispatching to named `proj-*` agents:

1. **`agent: general-purpose` in skill frontmatter** — when `context: fork` fires, the skill forks to the built-in `general-purpose` catch-all, which has access to ALL tools (Serena, Bash, Write, Edit, MCP). The forked agent completes the entire task inline-in-fork, indistinguishable from "no dispatch happened." `proj-researcher`, `proj-code-writer-*`, etc. are never invoked.

2. **Forked subagents CANNOT use `AskUserQuestion` and have no multi-turn back-channel** ([issue #18721](https://github.com/anthropics/claude-code/issues/18721)). Interactive orchestrators (brainstorm, write-plan, execute-plan, debug, etc.) require clarification from the user and multi-step dispatch with synthesis between rounds. A fork is one-way — the parent cannot resume the subagent thread. Any orchestrator that needs AskUserQuestion or multi-step dispatch **MUST run on the main thread** with no `context: fork`.

3. **Permissive `allowed-tools`** on orchestrator skills (`Edit`, `Bash`, `Grep`, `Glob`, `mcp__*`) invites inline work — Claude reaches for the closest available tool rather than dispatching.

Note: `context: fork` itself works correctly as of Claude Code 2.1+ ([issue #17283](https://github.com/anthropics/claude-code/issues/17283) closed/completed). The mechanism is sound; the targets and tool surfaces were wrong. Forkable analytical skills (single bounded task, no user interaction) SHOULD use `context: fork` + `agent: proj-<specialist>`.

Root cause documented in spec `.claude/specs/2026-04-10-orchestrator-skill-dispatch-hardening.md`.

---

## Changes

1. **Re-fetches `.claude/references/techniques/agent-design.md`** from bootstrap repo — new `## Skill Dispatch Reliability` section covers classification table, frontmatter contract, and agent tool audit table. (Client-project technique location per `modules/02-project-config.md`; NOT `techniques/` at project root.)
2. **Rewrites orchestrator skill frontmatter** — removes `context: fork` + `agent: general-purpose`, sets `allowed-tools: Agent Read Write` (drops Edit, Bash, Grep, Glob, mcp__* from main-thread orchestrators).
3. **Injects pre-flight gate** at top of every dispatching skill body — hard STOP if required `proj-*` agent missing; no inline fallback.
4. **Removes inline escape-hatch prose** (`"fall back.*inline"`, `"perform the work.*main thread"`, `"if.*agents.*not.*exist.*inline"`).
5. **Audits agent tool whitelists** for all `.claude/agents/proj-*.md` per role table — read-only roles lose their `tools:` line (MCP inheritance via omit); `proj-code-writer-markdown` loses `Bash`; `proj-plan-writer` loses `Edit` and `Bash`; debugger/tdd-runner keep `Bash`.
6. **Installs `/test-fork` skill** if missing — permanent diagnostic probe that confirms fork mechanism works after Claude Code upgrades.
7. **Regenerates `agent-index.yaml`** post-audit so index reflects actual post-migration tool restrictions.
8. **Advances `bootstrap-state.json`** → `last_migration: "007"`.

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/skills" ]] || { echo "ERROR: no .claude/skills directory"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl required"; exit 1; }
```

### Step 1 — Re-fetch `.claude/references/techniques/agent-design.md`

Reads `bootstrap_repo` from `.claude/bootstrap-state.json`. Converts GitHub repo URL to raw form for curl. Safe to re-run — always fetches fresh. Target path is `.claude/references/techniques/agent-design.md` per `modules/02-project-config.md` — the canonical client-project location for technique references. (Do NOT write to `techniques/` at the project root — that is the bootstrap repo layout, not the client layout.)

```bash
BOOTSTRAP_REPO=$(python3 -c "
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
repo = state.get('bootstrap_repo', '')
if not repo:
    print('ERROR: bootstrap_repo not set in bootstrap-state.json', file=sys.stderr)
    sys.exit(1)
# Convert https://github.com/{owner}/{repo} to raw form
repo = repo.rstrip('/')
if 'github.com' in repo:
    parts = repo.replace('https://github.com/', '')
    print(f'https://raw.githubusercontent.com/{parts}/main')
else:
    print(repo)
")

echo "Bootstrap repo raw base: $BOOTSTRAP_REPO"
mkdir -p .claude/references/techniques
curl -fsSL "${BOOTSTRAP_REPO}/techniques/agent-design.md" -o .claude/references/techniques/agent-design.md
echo "DONE: fetched .claude/references/techniques/agent-design.md"
```

### Step 2 — Rewrite skill frontmatter

Detects main-thread orchestrators by the presence of `agent: general-purpose` OR (`context: fork` paired with `allowed-tools` containing `Agent`). Removes `context: fork`, removes `agent: general-purpose`, narrows `allowed-tools` to `Agent Read Write` (preserving any extra read-only tools like `Grep`, `Glob`). Idempotent: skips files with neither flag.

```bash
python3 <<'PY'
import os, re, glob

def parse_frontmatter(content):
    """Return (frontmatter_str, body_str) or (None, content) if no frontmatter."""
    m = re.match(r'^(---\n)(.*?\n)(---\n)(.*)', content, re.DOTALL)
    if not m:
        return None, content
    return m.group(1) + m.group(2) + m.group(3), m.group(4)

def get_fm_field(fm, key):
    m = re.search(rf'^{re.escape(key)}:\s*(.+)$', fm, re.MULTILINE)
    return m.group(1).strip() if m else ''

def set_fm_field(fm, key, value):
    """Replace or remove a frontmatter field. value=None removes the line."""
    if value is None:
        return re.sub(rf'^{re.escape(key)}:.*\n?', '', fm, flags=re.MULTILINE)
    if re.search(rf'^{re.escape(key)}:', fm, re.MULTILINE):
        return re.sub(rf'^{re.escape(key)}:.*$', f'{key}: {value}', fm, flags=re.MULTILINE)
    # Append before closing ---
    return fm.rstrip('\n').rstrip('-').rstrip('\n') + f'\n{key}: {value}\n---\n'

targets = sorted(set(
    glob.glob('.claude/skills/**/*.md', recursive=True) +
    glob.glob('.claude/skills/*.md')
))

modified = 0
skipped = 0

for path in targets:
    with open(path, encoding='utf-8') as f:
        content = f.read()

    fm, body = parse_frontmatter(content)
    if fm is None:
        skipped += 1
        continue

    agent_val = get_fm_field(fm, 'agent')
    context_val = get_fm_field(fm, 'context')
    allowed_tools = get_fm_field(fm, 'allowed-tools')

    # Detect main-thread orchestrators needing fix:
    # Either has agent: general-purpose, or context: fork with Agent in allowed-tools
    is_bad_fork = agent_val == 'general-purpose'
    is_fork_orchestrator = context_val == 'fork' and 'Agent' in allowed_tools

    if not is_bad_fork and not is_fork_orchestrator:
        skipped += 1
        continue

    new_fm = fm

    # Remove context: fork line
    new_fm = re.sub(r'^context:.*\n?', '', new_fm, flags=re.MULTILINE)

    # Remove agent: general-purpose line
    new_fm = re.sub(r'^agent:.*\n?', '', new_fm, flags=re.MULTILINE)

    # Narrow allowed-tools: keep Agent + Read/Write/Grep/Glob (read-only extras)
    # Remove inline-work tools: Edit, Bash, Skill, mcp__*, and anything not in safe set
    safe_tools = {'Agent', 'Read', 'Write', 'Grep', 'Glob'}
    current_tools = re.split(r'[\s,]+', allowed_tools)
    new_tools = [t for t in current_tools if t in safe_tools]
    # Ensure Agent is always present for dispatch skills
    if 'Agent' not in new_tools:
        new_tools.insert(0, 'Agent')
    # Write is reasonable default for orchestrators that save specs/plans
    if 'Write' not in new_tools:
        new_tools.append('Write')
    new_tools_str = ' '.join(new_tools)
    new_fm = re.sub(r'^allowed-tools:.*$', f'allowed-tools: {new_tools_str}', new_fm, flags=re.MULTILINE)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_fm + body)
    print(f"  REWRITE: {path} (was: context={context_val!r} agent={agent_val!r} tools={allowed_tools!r})")
    modified += 1

print(f"Step 2 complete: modified={modified}, skipped={skipped}")
PY
```

### Step 3 — Inject pre-flight gate

For every skill containing dispatch markers (presence of `` subagent_type= `` patterns or `## Dispatch Map`), insert the pre-flight block immediately after the first `# /skill-name` title line. Idempotent: skips if `Pre-flight (REQUIRED before any other step)` already present.

```bash
python3 <<'PY'
import re, glob

PRE_FLIGHT = """
## Pre-flight (REQUIRED before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or create via /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.
"""

targets = sorted(set(
    glob.glob('.claude/skills/**/*.md', recursive=True) +
    glob.glob('.claude/skills/*.md')
))

injected = 0
skipped_present = 0
skipped_no_dispatch = 0

for path in targets:
    with open(path, encoding='utf-8') as f:
        content = f.read()

    # Idempotency
    if 'Pre-flight (REQUIRED before any other step)' in content:
        skipped_present += 1
        continue

    # Only inject into skills that dispatch agents
    has_dispatch = 'subagent_type=' in content or '## Dispatch Map' in content
    if not has_dispatch:
        skipped_no_dispatch += 1
        continue

    # Split off frontmatter
    fm_match = re.match(r'^(---\n.*?\n---\n)(.*)', content, re.DOTALL)
    if not fm_match:
        skipped_no_dispatch += 1
        continue

    frontmatter, body = fm_match.group(1), fm_match.group(2)

    # Find first # title line in body
    lines = body.split('\n')
    title_idx = None
    for i, line in enumerate(lines):
        if re.match(r'^#\s+', line):
            title_idx = i
            break

    if title_idx is None:
        skipped_no_dispatch += 1
        continue

    # Insert after title line (and any immediately following blank lines)
    insert_idx = title_idx + 1
    while insert_idx < len(lines) and lines[insert_idx].strip() == '':
        insert_idx += 1

    new_lines = lines[:insert_idx] + PRE_FLIGHT.split('\n') + lines[insert_idx:]
    new_body = '\n'.join(new_lines)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(frontmatter + new_body)
    print(f"  INJECT: {path}")
    injected += 1

print(f"Step 3 complete: injected={injected}, already_present={skipped_present}, no_dispatch={skipped_no_dispatch}")
PY
```

### Step 4 — Remove inline escape-hatch prose

Greps skill bodies for escape-hatch patterns; removes matching lines using python3 for safe handling. Reports removed line count per file. Idempotent: re-run finds nothing.

```bash
python3 <<'PY'
import re, glob

# Patterns that indicate inline fallback branches — remove these lines
ESCAPE_PATTERNS = [
    re.compile(r'if\b.{0,60}\bagent.{0,40}\bnot exist.{0,60}\b(do|perform)\b.{0,60}\binline\b', re.IGNORECASE),
    re.compile(r'\bfall\s*back\b.{0,60}\binline\b', re.IGNORECASE),
    re.compile(r'\bfallback\b.{0,60}\bmain[-\s]?thread\b', re.IGNORECASE),
    re.compile(r'\bfall\s*back\b.{0,60}\bmain[-\s]?thread\b', re.IGNORECASE),
    re.compile(r'\bperform\b.{0,60}\bwork\b.{0,60}\bmain\s+thread\b', re.IGNORECASE),
    re.compile(r'\bexecute\b.{0,40}\binline\b', re.IGNORECASE),
    re.compile(r'\bdo\s+it\b.{0,60}\binline\b', re.IGNORECASE),
    re.compile(r'\bno\b.{0,30}\bagents?\b.{0,40}\b(exist|found)\b.{0,80}\binline\b', re.IGNORECASE),
    re.compile(r'\bno\s+matching\s+specialist\b.{0,60}\binline\b', re.IGNORECASE),
    re.compile(r'\bif\b.{0,40}\bno\s+specialists?\s+found\b.{0,80}\binline\b', re.IGNORECASE),
]

targets = sorted(set(
    glob.glob('.claude/skills/**/*.md', recursive=True) +
    glob.glob('.claude/skills/*.md')
))

total_removed = 0

for path in targets:
    with open(path, encoding='utf-8') as f:
        lines = f.readlines()

    kept = []
    removed = []
    for line in lines:
        if any(p.search(line) for p in ESCAPE_PATTERNS):
            removed.append(line.rstrip())
        else:
            kept.append(line)

    if removed:
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(kept)
        print(f"  REMOVED {len(removed)} line(s) from {path}:")
        for r in removed:
            print(f"    - {r}")
        total_removed += len(removed)

print(f"Step 4 complete: total escape-hatch lines removed={total_removed}")
PY
```

### Step 5 — Audit agent tool whitelists

Globs `.claude/agents/proj-*.md` (never hardcoded filenames). Classifies each agent by name pattern. Applies role-table rules:
- **Read-only roles** (`proj-researcher`, `proj-quick-check`, `proj-verifier`, `proj-consistency-checker`, `proj-reflector`, `proj-code-reviewer`): remove `tools:` line entirely — inherits MCP via omit (per migration 001).
- **`proj-code-writer-markdown`**: remove `Bash` from `tools:`; preserve ALL `mcp__*` entries (MUST NOT undo migration 001 MCP injection).
- **`proj-plan-writer`**: remove `Edit` and `Bash` if present.
- **`proj-debugger`, `proj-tdd-runner`**: keep `Bash` (heredoc writers per agent-design.md).
- **`proj-code-writer-{lang}` (non-markdown), `proj-test-writer-*`**: keep full toolset unchanged.

```bash
python3 <<'PY'
import re, glob, os

READ_ONLY_NAMES = {
    'proj-researcher', 'proj-quick-check', 'proj-verifier',
    'proj-consistency-checker', 'proj-reflector', 'proj-code-reviewer',
}

def parse_frontmatter(content):
    m = re.match(r'^(---\n)(.*?\n)(---\n)(.*)', content, re.DOTALL)
    if not m:
        return None, None, content
    return m.group(1) + m.group(2) + m.group(3), m.group(2), m.group(4)

def get_agent_name(fm_body):
    m = re.search(r'^name:\s*(.+)$', fm_body, re.MULTILINE)
    return m.group(1).strip() if m else ''

def get_tools_line(fm_body):
    m = re.search(r'^tools:\s*(.+)$', fm_body, re.MULTILINE)
    return m.group(1).strip() if m else None

agents = sorted(glob.glob('.claude/agents/proj-*.md'))
if not agents:
    print("No proj-*.md agent files found — skip Step 5")
    import sys; sys.exit(0)

modified = 0
skipped = 0

for path in agents:
    with open(path, encoding='utf-8') as f:
        content = f.read()

    fm_full, fm_body, body = parse_frontmatter(content)
    if fm_full is None:
        print(f"  SKIP (no frontmatter): {path}")
        skipped += 1
        continue

    name = get_agent_name(fm_body)
    tools_val = get_tools_line(fm_body)
    changed = False
    new_fm = fm_full

    if name in READ_ONLY_NAMES:
        # Remove tools: line entirely
        if tools_val is not None:
            new_fm = re.sub(r'^tools:.*\n?', '', new_fm, flags=re.MULTILINE)
            print(f"  REMOVE tools: from {path} (read-only role)")
            changed = True
        else:
            print(f"  OK (no tools: line): {path}")

    elif name == 'proj-code-writer-markdown':
        if tools_val is not None:
            # Split on comma+space, remove Bash, preserve mcp__* entries
            tool_list = [t.strip() for t in tools_val.split(',') if t.strip()]
            new_list = [t for t in tool_list if t != 'Bash']
            if len(new_list) != len(tool_list):
                new_tools_str = ', '.join(new_list)
                new_fm = re.sub(r'^tools:.*$', f'tools: {new_tools_str}', new_fm, flags=re.MULTILINE)
                print(f"  REMOVE Bash from tools: in {path}")
                changed = True
            else:
                print(f"  OK (Bash not present): {path}")
        else:
            print(f"  OK (no tools: line): {path}")

    elif name == 'proj-plan-writer':
        if tools_val is not None:
            tool_list = [t.strip() for t in tools_val.split(',') if t.strip()]
            new_list = [t for t in tool_list if t not in ('Edit', 'Bash')]
            if len(new_list) != len(tool_list):
                new_tools_str = ', '.join(new_list)
                new_fm = re.sub(r'^tools:.*$', f'tools: {new_tools_str}', new_fm, flags=re.MULTILINE)
                print(f"  REMOVE Edit/Bash from tools: in {path}")
                changed = True
            else:
                print(f"  OK (Edit/Bash not present): {path}")
        else:
            print(f"  OK (no tools: line): {path}")

    else:
        # proj-debugger, proj-tdd-runner, proj-code-writer-{lang}, proj-test-writer-* — keep as-is
        print(f"  KEEP unchanged: {path} ({name})")
        skipped += 1
        continue

    if changed:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_fm + body)
        modified += 1
    else:
        skipped += 1

print(f"Step 5 complete: modified={modified}, skipped/unchanged={skipped}")
PY
```

### Step 6 — Install `/test-fork` skill

Installs `.claude/skills/test-fork/SKILL.md` if missing. Content is inlined here — does NOT fetch from bootstrap repo because the bootstrap repo's local file uses bare `agent: quick-check`; client projects need `agent: proj-quick-check`. If skill already exists, skips.

```bash
SKILL_PATH=".claude/skills/test-fork/SKILL.md"

if [[ -f "$SKILL_PATH" ]]; then
  echo "SKIP: $SKILL_PATH already exists"
else
  mkdir -p ".claude/skills/test-fork"
  cat > "$SKILL_PATH" <<'SKILL_EOF'
---
name: test-fork
description: Diagnostic probe — verifies context:fork dispatches to a named custom agent. Run after migration 007 to confirm fork mechanism works in this project.
context: fork
agent: proj-quick-check
allowed-tools: Bash
model: haiku
effort: low
disable-model-invocation: true
---
# /test-fork — Fork Dispatch Probe

Run exactly ONE Bash command and return its output verbatim. Do nothing else.

```bash
echo "FORK_PROBE pid=$$ ppid=$PPID time=$(date +%s) host=$(hostname)"
```

Expected outcome (PASS): the agent reports that Bash is not available — proves the fork happened to `proj-quick-check` whose tool whitelist refused Bash. The restriction message IS the success signal.

If PASS: fork dispatch is working. If FAIL (Bash actually executes): the fork fell through to main-thread context — diagnose immediately.
SKILL_EOF
  echo "INSTALLED: $SKILL_PATH"
fi
```

### Step 7 — Regenerate `agent-index.yaml`

Reads all `.claude/agents/proj-*.md` frontmatters post-audit, writes fresh `.claude/agents/agent-index.yaml`. Runs AFTER Step 5 so the index reflects the audited tool restrictions.

```bash
python3 <<'PY'
import re, glob, os

INDEX_PATH = '.claude/agents/agent-index.yaml'

def parse_fm_fields(content):
    """Extract key:value pairs from YAML frontmatter."""
    m = re.match(r'^---\n(.*?\n)---\n', content, re.DOTALL)
    if not m:
        return {}
    fields = {}
    for line in m.group(1).splitlines():
        kv = re.match(r'^(\w[\w-]*):\s*(.+)$', line)
        if kv:
            fields[kv.group(1)] = kv.group(2).strip()
    return fields

agents = sorted(glob.glob('.claude/agents/proj-*.md'))
if not agents:
    print("No proj-*.md agent files found — skip Step 7")
    import sys; sys.exit(0)

# Read existing index to discover format (preserve structure if present)
existing_header = ''
if os.path.exists(INDEX_PATH):
    with open(INDEX_PATH, encoding='utf-8') as f:
        first_line = f.readline().strip()
    if first_line.startswith('#'):
        existing_header = first_line + '\n'

lines = [existing_header + 'agents:\n'] if existing_header else ['agents:\n']

for path in agents:
    with open(path, encoding='utf-8') as f:
        content = f.read()
    fields = parse_fm_fields(content)
    name = fields.get('name', os.path.basename(path).replace('.md', ''))
    description = fields.get('description', '')
    model = fields.get('model', '')
    effort = fields.get('effort', '')
    tools_val = fields.get('tools', 'OMIT')
    color = fields.get('color', '')

    lines.append(f'  - name: {name}\n')
    lines.append(f'    file: {os.path.basename(path)}\n')
    if description:
        # Escape quotes for YAML
        desc_escaped = description.replace('"', '\\"')
        lines.append(f'    description: "{desc_escaped}"\n')
    if model:
        lines.append(f'    model: {model}\n')
    if effort:
        lines.append(f'    effort: {effort}\n')
    if color:
        lines.append(f'    color: {color}\n')
    lines.append(f'    tools: {tools_val}\n')

os.makedirs(os.path.dirname(INDEX_PATH), exist_ok=True)
with open(INDEX_PATH, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print(f"Step 7 complete: agent-index.yaml regenerated with {len(agents)} agent(s)")
PY
```

### Step 8 — Update `bootstrap-state.json`

Advances `last_migration` to `"007"` and appends an entry to `applied[]`. Idempotent: skips append if id `"007"` already in `applied`.

```bash
python3 <<'PY'
import json, datetime

STATE_PATH = '.claude/bootstrap-state.json'
with open(STATE_PATH, encoding='utf-8') as f:
    state = json.load(f)

state['last_migration'] = '007'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'

applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '007') or a == '007' for a in applied):
    applied.append({
        'id': '007',
        'applied_at': state['last_applied'],
        'description': 'orchestrator skill dispatch fix — main-thread vs forkable classification, pre-flight gate, agent tool audit'
    })

with open(STATE_PATH, 'w', encoding='utf-8') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=007')
PY
```

---

### Rules for migration scripts

- **Glob agent filenames, never hardcode** — `for agent in .claude/agents/proj-*.md; do ... done`; same for skills via `glob.glob('.claude/skills/**/*.md', recursive=True)`.
- **Read-before-write** every modification — python3 reads full file content before rewrite.
- **Idempotent** — every step is detect-then-act; presence checks before modifications; re-running on already-migrated project is a no-op.
- **Self-contained** — Step 1 is the ONLY remote fetch. It reads the tracked file `techniques/agent-design.md` from the bootstrap repo and writes it to the client-project location `.claude/references/techniques/agent-design.md`. No fetch from gitignored `.claude/` paths.
- **Technique sync** — Step 1 re-fetches `techniques/agent-design.md` into `.claude/references/techniques/agent-design.md` because the new `## Skill Dispatch Reliability` section does not auto-propagate to child projects bootstrapped before this migration.
- **Client vs bootstrap layout** — the bootstrap repo stores techniques at root `techniques/`; client projects store them at `.claude/references/techniques/` (see `modules/02-project-config.md` Step 5). Migrations MUST write to the client location, never the root.
- **Abort on error** — `set -euo pipefail` in prerequisites; python3 blocks exit non-zero on failure.
- **MCP preservation** — Step 5 `proj-code-writer-markdown` branch only removes `Bash`; all `mcp__*` entries are preserved to avoid undoing migration 001.

### Required: register in migrations/index.json

Add an entry to the `migrations` array:

```json
{
  "id": "007",
  "file": "007-orchestrator-skill-dispatch-fix.md",
  "description": "Fix orchestrator skill dispatch — reclassify main-thread vs forkable, enforce frontmatter contract (no context:fork on orchestrators), inject pre-flight gate, audit agent tool whitelists per role table, promote /test-fork as permanent diagnostic.",
  "breaking": false
}
```

---

## Verify

```bash
set +e
fail=0

shopt -s globstar nullglob
SKILLS=()
for f in .claude/skills/**/*.md .claude/skills/*.md; do
  [[ -f "$f" ]] && SKILLS+=("$f")
done
shopt -u globstar nullglob

# 1. .claude/references/techniques/agent-design.md exists and contains Skill Dispatch Reliability section
if [[ -f ".claude/references/techniques/agent-design.md" ]] && grep -q "Skill Dispatch Reliability" .claude/references/techniques/agent-design.md; then
  echo "PASS: .claude/references/techniques/agent-design.md has Skill Dispatch Reliability section"
else
  echo "FAIL: .claude/references/techniques/agent-design.md missing or lacks Skill Dispatch Reliability section"
  fail=1
fi

# 2. No skill contains agent: general-purpose
gp=$(grep -rEn '^agent:\s*general-purpose' .claude/skills/ 2>/dev/null || true)
if [[ -n "$gp" ]]; then
  echo "FAIL: agent: general-purpose still present in skill(s):"
  echo "$gp"
  fail=1
else
  echo "PASS: no skill has agent: general-purpose"
fi

# 3. No main-thread orchestrator has context: fork + inline-capable tools (Edit or Bash)
bad_fork=0
for f in "${SKILLS[@]}"; do
  if head -20 "$f" | grep -q "^context: fork"; then
    if head -20 "$f" | grep -Eq "^allowed-tools:.*\b(Edit|Bash)\b"; then
      echo "FAIL: stale fork+inline-tool in $f"
      bad_fork=1
    fi
  fi
done
if [[ $bad_fork -eq 0 ]]; then
  echo "PASS: no skill has context:fork paired with Edit or Bash in allowed-tools"
else
  fail=1
fi

# 4. Every skill with a Dispatch Map also has the pre-flight gate
missing_preflight=0
for f in "${SKILLS[@]}"; do
  if grep -q "## Dispatch Map" "$f" || grep -q "subagent_type=" "$f"; then
    if ! grep -q "Pre-flight (REQUIRED before any other step)" "$f"; then
      echo "FAIL: missing pre-flight gate in $f"
      missing_preflight=1
    fi
  fi
done
if [[ $missing_preflight -eq 0 ]]; then
  echo "PASS: all dispatching skills have pre-flight gate"
else
  fail=1
fi

# 5. Read-only agents have no tools: line
readonly_agents=(proj-researcher proj-quick-check proj-verifier proj-consistency-checker proj-reflector proj-code-reviewer)
for agent_name in "${readonly_agents[@]}"; do
  agent_file=".claude/agents/${agent_name}.md"
  if [[ -f "$agent_file" ]]; then
    if head -20 "$agent_file" | grep -Eq "^tools:\s*\S+"; then
      echo "FAIL: $agent_file has tools: line (should be omitted for read-only role)"
      fail=1
    else
      echo "PASS: $agent_file has no tools: line (correct for read-only role)"
    fi
  fi
done

# 6. proj-code-writer-markdown does NOT have Bash; still has mcp__ entries if any exist
MARKDOWN_WRITER=".claude/agents/proj-code-writer-markdown.md"
if [[ -f "$MARKDOWN_WRITER" ]]; then
  if head -20 "$MARKDOWN_WRITER" | grep -E "^tools:" | grep -q "\bBash\b"; then
    echo "FAIL: $MARKDOWN_WRITER still contains Bash in tools:"
    fail=1
  else
    echo "PASS: $MARKDOWN_WRITER does not contain Bash in tools:"
  fi
  # Warn (not fail) if mcp__ entries were accidentally removed
  if grep -q "mcp__" "$MARKDOWN_WRITER"; then
    echo "PASS: $MARKDOWN_WRITER retains mcp__* entries"
  else
    echo "INFO: $MARKDOWN_WRITER has no mcp__* entries (acceptable if project has no MCP servers)"
  fi
fi

# 7. proj-plan-writer does NOT have Edit or Bash in tools:
PLAN_WRITER=".claude/agents/proj-plan-writer.md"
if [[ -f "$PLAN_WRITER" ]]; then
  if head -20 "$PLAN_WRITER" | grep -E "^tools:" | grep -Eq "\b(Edit|Bash)\b"; then
    echo "FAIL: $PLAN_WRITER has Edit or Bash in tools: (forbidden per role table)"
    fail=1
  else
    echo "PASS: $PLAN_WRITER tools: has no Edit or Bash"
  fi
fi

# 8. proj-debugger and proj-tdd-runner still have Bash
for agent_name in proj-debugger proj-tdd-runner; do
  agent_file=".claude/agents/${agent_name}.md"
  if [[ -f "$agent_file" ]]; then
    if head -20 "$agent_file" | grep -E "^tools:" | grep -q "\bBash\b"; then
      echo "PASS: $agent_file retains Bash (required for heredoc writes)"
    else
      echo "FAIL: $agent_file is missing Bash in tools: (heredoc writer requires it)"
      fail=1
    fi
  fi
done

# 9. test-fork skill exists and targets proj-quick-check
if [[ -f ".claude/skills/test-fork/SKILL.md" ]]; then
  if grep -q "agent: proj-quick-check" ".claude/skills/test-fork/SKILL.md"; then
    echo "PASS: test-fork/SKILL.md exists and targets proj-quick-check"
  else
    echo "FAIL: test-fork/SKILL.md exists but agent is not proj-quick-check"
    fail=1
  fi
else
  echo "FAIL: .claude/skills/test-fork/SKILL.md not found"
  fail=1
fi

# 10. agent-index.yaml exists and is valid YAML
if [[ -f ".claude/agents/agent-index.yaml" ]]; then
  if python3 -c "import yaml; yaml.safe_load(open('.claude/agents/agent-index.yaml'))" 2>/dev/null; then
    echo "PASS: agent-index.yaml exists and is valid YAML"
  else
    echo "FAIL: agent-index.yaml exists but is not valid YAML"
    fail=1
  fi
else
  echo "FAIL: .claude/agents/agent-index.yaml not found"
  fail=1
fi

# 11. bootstrap-state.json last_migration == "007"
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null || echo "ERROR")
if [[ "$last" == "007" ]]; then
  echo "PASS: last_migration = 007"
else
  echo "FAIL: last_migration = $last (expected 007)"
  fail=1
fi

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 007 verification: ALL PASS" || { echo "Migration 007 verification: FAILURES — state may not reflect complete migration"; exit 1; }
```

Failure of any verify step → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after fixing.

---

## State Update

Migration runner updates `.claude/bootstrap-state.json` on success:
- `last_migration` → "007"
- append `{ "id": "007", "applied_at": "{ISO8601}", "description": "orchestrator skill dispatch fix — main-thread vs forkable classification, pre-flight gate, agent tool audit" }` to `applied[]`

---

## Rollback

Not automatically reversible. Changes are confined to:
- `.claude/skills/**/*.md` (frontmatter rewrites + pre-flight injections)
- `.claude/agents/proj-*.md` (tools: line modifications)
- `.claude/agents/agent-index.yaml` (regenerated)
- `.claude/references/techniques/agent-design.md` (re-fetched)
- `.claude/bootstrap-state.json` (state advance)

Restore from git: `git checkout -- .claude/skills/ .claude/agents/ .claude/references/techniques/agent-design.md .claude/bootstrap-state.json`

If `.claude/` is gitignored, restore from companion repo at `~/.claude-configs/{project}` or re-bootstrap from `modules/05`, `06`, `07` with the pre-007 module files.
