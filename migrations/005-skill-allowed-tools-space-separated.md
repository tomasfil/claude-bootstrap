# Migration 005 — Skill allowed-tools space-separated format

> Convert skill `allowed-tools` frontmatter from non-standard comma-separated form to spec-compliant space-separated form. Comma form breaks with `Bash(git add *)` patterns (commas inside parens collide with separator). Note: agent `tools:` is correctly comma-separated per spec — leave agents alone, only skills change.

---

## Metadata

```yaml
id: "005"
breaking: false
affects: [skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Claude Code skill frontmatter spec (https://code.claude.com/docs/en/skills) accepts `allowed-tools` as either a space-separated string OR a YAML list. The official example uses space-separated form:

```yaml
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *)
```

Bootstrap versions prior to this migration emitted comma-separated form (`allowed-tools: Agent, Read, Write, Edit`), which is NOT part of the spec. Comma form works by accident for bare tool names but breaks the moment a pattern like `Bash(git add *)` is introduced: commas inside the parens collide with the separator.

An earlier draft of this migration converted to YAML list form. That form is also spec-valid but verbose (one line per tool). This migration lands on the simpler canonical space-separated single-line form.

Handles both input shapes:
- Comma-separated (pre-migration bootstrap): `allowed-tools: Agent, Read, Write`
- YAML list (if earlier migration draft was applied): `allowed-tools:\n  - Agent\n  - Read\n  - Write`

Both convert to: `allowed-tools: Agent Read Write`.

**Scope:** skill files only (`.claude/skills/*/SKILL.md`). Agent `tools:` field is separately defined as COMMA-separated per Claude Code sub-agents spec (https://code.claude.com/docs/en/sub-agents) — do NOT touch agent files. The inconsistency between skill `allowed-tools:` (space) and agent `tools:` (comma) is in the official spec.

---

## Changes

1. **Convert all skills** — walk `.claude/skills/*/SKILL.md`; rewrite `allowed-tools:` values that use comma-separated form OR YAML list form into space-separated single-line form. Skip files already in that form.
2. **Sync `techniques/agent-design.md`** — fetch updated technique file from bootstrap repo (FORMAT difference paragraph + space-separated skill example). Idempotent: compares fetched copy to local before overwriting.
3. **State update** — `last_migration` → "005".

---

## Actions

### Prerequisites

```bash
set -euo pipefail
[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }

if [[ ! -d ".claude/skills" ]]; then
  echo "SKIP: no .claude/skills directory — nothing to convert"
  SKILLS_DIR=0
else
  SKILLS_DIR=1
fi
```

### Step 1 — Convert skill allowed-tools to space-separated single line

Idempotency: files already in space-separated single-line form (inline value, no commas, no following `  - ` list items) → skip. Splitter is paren-depth-aware so `Bash(git add *), Read` splits into `Bash(git add *)` + `Read`, not three fragments.

```bash
[[ "$SKILLS_DIR" -eq 0 ]] && { echo "SKIP step 1: no skills to convert"; } || python3 <<'PY'
import glob, os, re, sys

SKILL_GLOB = '.claude/skills/*/SKILL.md'


def split_respecting_parens(value):
    """Split on commas NOT inside (...). Used for allowed-tools values like
    'Bash(git add *), Read, Write'."""
    parts = []
    depth = 0
    buf = []
    for ch in value:
        if ch == '(':
            depth += 1
            buf.append(ch)
        elif ch == ')':
            depth = max(0, depth - 1)
            buf.append(ch)
        elif ch == ',' and depth == 0:
            parts.append(''.join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    tail = ''.join(buf).strip()
    if tail:
        parts.append(tail)
    return [p for p in parts if p]


def extract_frontmatter(text):
    """Return (fm_lines, body_start_index) for a file opening with '---\\n...\\n---\\n'.
    Returns (None, 0) if no frontmatter."""
    if not text.startswith('---\n') and not text.startswith('---\r\n'):
        return None, 0
    lines = text.split('\n')
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            return lines[1:i], i + 1
    return None, 0


def convert_file(path):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    fm_lines, body_start = extract_frontmatter(text)
    if fm_lines is None:
        return 'NO_FRONTMATTER'

    # Find allowed-tools: line
    at_idx = None
    for i, line in enumerate(fm_lines):
        if re.match(r'^\s*allowed-tools:\s*', line):
            at_idx = i
            break
    if at_idx is None:
        return 'NO_ALLOWED_TOOLS'

    at_line = fm_lines[at_idx]
    m = re.match(r'^(\s*)allowed-tools:\s*(.*)$', at_line)
    indent = m.group(1)
    value = m.group(2).strip()

    tools = None
    list_end_idx = at_idx  # inclusive last index of the allowed-tools block

    if value == '':
        # YAML list form — collect following '  - item' lines
        items = []
        j = at_idx + 1
        while j < len(fm_lines):
            lm = re.match(r'^(\s+)-\s+(.*)$', fm_lines[j])
            if not lm:
                break
            items.append(lm.group(2).strip())
            j += 1
        if not items:
            # Empty value, no list items — leave untouched
            return 'SKIP'
        tools = items
        list_end_idx = j - 1
    else:
        # Inline value. Could be space-separated (already correct) OR comma-separated.
        if ',' not in value:
            # Space-separated single-line form — already canonical, skip.
            return 'SKIP'
        tools = split_respecting_parens(value)
        if not tools:
            return 'SKIP'

    # Build replacement: single line 'allowed-tools: A B C'
    new_line = indent + 'allowed-tools: ' + ' '.join(tools)
    new_fm_lines = fm_lines[:at_idx] + [new_line] + fm_lines[list_end_idx + 1:]
    body = '\n'.join(text.split('\n')[body_start:])
    new_text = '---\n' + '\n'.join(new_fm_lines) + '\n---\n' + body
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(new_text)
    return 'CONVERTED'


any_fail = False
for path in sorted(glob.glob(SKILL_GLOB)):
    try:
        result = convert_file(path)
    except Exception as e:
        print(f'[ERROR] {path}: {e}')
        any_fail = True
        continue
    if result == 'CONVERTED':
        print(f'[CONVERTED] {path}')
    elif result == 'SKIP':
        print(f'[SKIP] {path} (already space-separated or nothing to convert)')
    elif result == 'NO_ALLOWED_TOOLS':
        print(f'[SKIP] {path} (no allowed-tools field)')
    elif result == 'NO_FRONTMATTER':
        print(f'[SKIP] {path} (no YAML frontmatter)')

sys.exit(1 if any_fail else 0)
PY
```

### Step 2 — Sync `techniques/agent-design.md` from bootstrap repo

Per `.claude/rules/general.md`: technique updates must sync to child projects. This changeset modified `techniques/agent-design.md` (added FORMAT difference paragraph in SCOPE block; converted skill example `allowed-tools` to space-separated). Idempotent: fetches to a `.new` tempfile, compares to existing, only replaces on diff.

```bash
set -euo pipefail

if [[ ! -d "techniques" ]]; then
  echo "SKIP: no techniques/ directory — project did not copy techniques at bootstrap"
else
  BOOTSTRAP_REPO=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['bootstrap_repo'])" 2>/dev/null || echo "tomasfil/claude-bootstrap")

  if command -v gh >/dev/null 2>&1; then
    if ! gh api "repos/${BOOTSTRAP_REPO}/contents/techniques/agent-design.md" --jq '.content' 2>/dev/null | base64 -d > techniques/agent-design.md.new; then
      echo "ERROR: gh fetch of techniques/agent-design.md from ${BOOTSTRAP_REPO} failed"
      rm -f techniques/agent-design.md.new
      exit 1
    fi
  elif command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "https://raw.githubusercontent.com/${BOOTSTRAP_REPO}/main/techniques/agent-design.md" -o techniques/agent-design.md.new; then
      echo "ERROR: curl fetch of techniques/agent-design.md from ${BOOTSTRAP_REPO} failed"
      rm -f techniques/agent-design.md.new
      exit 1
    fi
  else
    echo "ERROR: neither gh nor curl available — cannot sync techniques/agent-design.md"
    exit 1
  fi

  # Idempotency: skip if identical to existing
  if [[ -f techniques/agent-design.md ]] && cmp -s techniques/agent-design.md techniques/agent-design.md.new; then
    rm techniques/agent-design.md.new
    echo "SKIP: techniques/agent-design.md already up to date"
  else
    mv techniques/agent-design.md.new techniques/agent-design.md
    echo "UPDATED: techniques/agent-design.md"
  fi
fi
```

### Step 3 — Update bootstrap-state.json

```bash
python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '005'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '005') or a == '005' for a in applied):
    applied.append({
        'id': '005',
        'applied_at': state['last_applied'],
        'description': 'skill allowed-tools space-separated format — convert comma or YAML-list form to spec-compliant single-line space-separated form'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=005')
PY
```

---

## Verify

```bash
set +e
fail=0

# 1. No skill file has a comma-separated allowed-tools value
if [[ -d ".claude/skills" ]]; then
  comma_offenders=$(grep -rlE '^allowed-tools:[[:space:]]*[A-Za-z][^$]*,' .claude/skills --include='SKILL.md' 2>/dev/null || true)
  if [[ -z "$comma_offenders" ]]; then
    echo "PASS: no comma-separated allowed-tools remain in .claude/skills"
  else
    echo "FAIL: comma-separated allowed-tools still present:"
    echo "$comma_offenders"
    fail=1
  fi

  # 2. No skill file has YAML-list allowed-tools (allowed-tools: followed by blank, then '  - item')
  list_offenders=$(python3 - <<'PY'
import glob, re
bad = []
for p in sorted(glob.glob('.claude/skills/*/SKILL.md')):
    with open(p, encoding='utf-8') as f:
        lines = f.read().split('\n')
    for i, line in enumerate(lines):
        m = re.match(r'^(\s*)allowed-tools:\s*$', line)
        if m and i + 1 < len(lines) and re.match(r'^\s+-\s+', lines[i + 1]):
            bad.append(p)
            break
for p in bad:
    print(p)
PY
)
  if [[ -z "$list_offenders" ]]; then
    echo "PASS: no YAML-list allowed-tools remain in .claude/skills"
  else
    echo "FAIL: YAML-list allowed-tools still present:"
    echo "$list_offenders"
    fail=1
  fi
else
  echo "SKIP: no .claude/skills directory"
fi

# 3. techniques/agent-design.md contains the FORMAT difference paragraph
if [[ -f techniques/agent-design.md ]]; then
  if grep -q "FORMAT difference" techniques/agent-design.md 2>/dev/null; then
    echo "PASS: techniques/agent-design.md has FORMAT difference paragraph"
  else
    echo "WARN: techniques/agent-design.md present but missing FORMAT difference paragraph (sync may have skipped)"
  fi
else
  echo "SKIP: no techniques/agent-design.md in project"
fi

# 4. State file updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "005" ]]; then
  echo "PASS: last_migration = 005"
else
  echo "FAIL: last_migration = $last (expected 005)"
  fail=1
fi

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 005 verification: ALL PASS" || { echo "Migration 005 verification: FAILURES — state NOT updated"; exit 1; }
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## Rules for migration scripts

- **Idempotent** — Step 1 skips files already in space-separated single-line form; re-running is a safe no-op. Handles both comma-separated and YAML-list inputs (so projects that ran an earlier draft of this migration converge to the same canonical form).
- **Glob skill filenames, never hardcode** — script walks `.claude/skills/*/SKILL.md` via glob; new skills added post-migration are handled on next run.
- **Read-before-write** — every file is read and parsed before rewrite; untouched if no conversion needed.
- **Paren-depth-aware splitter** — `split_respecting_parens` correctly handles `Bash(git add *), Read` as two tokens, not three.
- **Agents untouched** — migration operates ONLY on `.claude/skills/*/SKILL.md`. Agent `tools:` field uses comma-separated form per Claude Code spec; do NOT modify `.claude/agents/*.md` in this migration.
- **Abort on error** — `set -euo pipefail`; Step 3 state update only runs after Steps 1 and 2 succeed.
- **Technique sync** — Step 2 fetches updated `techniques/agent-design.md` from bootstrap repo per `.claude/rules/general.md` rule ("technique update = sync step in migration"). Idempotent via `cmp -s` compare-before-replace. Projects without `techniques/` directory are skipped cleanly.

### Required: register in migrations/index.json

Add to the `migrations` array in `migrations/index.json`:

```json
{
  "id": "005",
  "file": "005-skill-allowed-tools-space-separated.md",
  "description": "Convert skill allowed-tools frontmatter from non-standard comma-separated form to spec-compliant space-separated form. Comma form breaks with Bash(git add *) patterns. Agent tools field is unchanged (correctly comma-separated per spec).",
  "breaking": false
}
```

---

## State Update

On success:
- `last_migration` → "005"
- append `{ "id": "005", "applied_at": "<ISO8601>", "description": "skill allowed-tools space-separated format — convert comma or YAML-list form to spec-compliant single-line space-separated form" }` to `applied[]`

---

## Rollback

Not automatic. Restore `.claude/skills/*/SKILL.md` from git or companion repo at `~/.claude-configs/{project}`.
