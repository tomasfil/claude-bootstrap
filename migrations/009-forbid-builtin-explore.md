# Migration 009 — Forbid built-in Explore/general-purpose agent fallback

> Patch always-loaded rule files (CLAUDE.md, .claude/rules/skill-routing.md, .claude/rules/general.md) to explicitly forbid built-in Explore/general-purpose/plugin agents. Strengthen AGENT_DISPATCH_POLICY_BLOCK inside all dispatching skills. Fixes Claude main thread falling back to built-in agents for code investigation.

---

## Metadata

```yaml
id: "009"
breaking: false
affects: [rules, claude-md, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Observed incident: user asked Claude to investigate a validation-mismatch bug in a C# project. Claude dispatched the built-in `Explore` agent for code exploration. User corrected ("You shouldn't ever be using built in explore agent..."). Claude then tried `Skill(debug)` — errored with `disable-model-invocation`. Claude then dispatched `proj-debugger` directly, skipping the `proj-quick-check` triage phase entirely.

Root cause: the "no built-in Explore" rule lived only inside skill bodies via `AGENT_DISPATCH_POLICY_BLOCK` — Claude only saw it AFTER invoking a skill. The always-loaded context (`CLAUDE.md`, `.claude/rules/*.md`) did not forbid built-in Explore at all, so Claude defaulted to its built-in habit BEFORE any skill was invoked. The in-skill rule was also silent on the `disable-model-invocation` fallback path.

Fix requires two layers. (1) Always-loaded rules (`CLAUDE.md`, `skill-routing.md`, `general.md`) get an explicit forbid clause so the constraint is visible before the first tool call. (2) `AGENT_DISPATCH_POLICY_BLOCK` in every dispatching skill gets an explicit `disable-model-invocation` fallback rule: STOP and ask the user to run the slash command manually — do not fall back to Explore.

---

## Changes

1. Patches `.claude/rules/skill-routing.md` — inserts a new `## Forbidden` section before `## Critical` (idempotent: skips if `## Forbidden` heading already present).
2. Patches `.claude/rules/general.md` — extends the `- Process:` bullet with `no built-in Explore/general-purpose/plugin agents (use proj-quick-check | proj-researcher)` immediately before `never background agents` (idempotent).
3. Patches `CLAUDE.md` — adds `no-builtin-explore` to the Behavior list after `never-background-agents`, and appends a new anti-pattern bullet after the permission-seeking bullet (idempotent).
4. Updates every `.claude/skills/*/SKILL.md` containing the old 3-line `AGENT_DISPATCH_POLICY_BLOCK` — replaces with the strengthened 6-line block. Globs ALL skills; does not hardcode any skill name.
5. Advances `.claude/bootstrap-state.json` → `last_migration: "009"`.

Idempotent: on re-run every step detects existing markers and prints `SKIP: already patched`.

---

## Actions

### Prerequisites

```bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/rules" ]] || { echo "ERROR: no .claude/rules directory"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Patch `.claude/rules/skill-routing.md`

Inserts the `## Forbidden` block immediately before `## Critical`. If `## Critical` is missing (user-customized file), appends to end of file.

```bash
python3 <<'PY'
import os, sys

path = ".claude/rules/skill-routing.md"
if not os.path.isfile(path):
    print(f"SKIP: {path} not present")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if "## Forbidden" in content:
    print(f"SKIP: {path} already contains ## Forbidden")
    sys.exit(0)

block = """## Forbidden
NEVER use built-in `Explore` / `general-purpose` / plugin agents for code exploration.
- Simple fact/lookup → proj-quick-check
- Deep multi-source investigation → proj-researcher
- Bug investigation → /debug (if disable-model-invocation blocks invocation → ask user to run /debug manually; do NOT fall back to Explore)
- Plain code reading → Read/Grep/Glob directly
Built-in agents bypass project evidence tracking + conventions = quality regression.

"""

marker = "## Critical"
if marker in content:
    new_content = content.replace(marker, block + marker, 1)
    action = "inserted before ## Critical"
else:
    if not content.endswith("\n"):
        content += "\n"
    new_content = content + "\n" + block.rstrip() + "\n"
    action = "appended to EOF (## Critical missing)"

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)
print(f"PATCHED: {path} — ## Forbidden {action}")
PY
```

### Step 2 — Patch `.claude/rules/general.md`

Extends the `- Process:` line with the forbid clause. Tolerates minor edits to the line but refuses to patch a shape it cannot recognize.

```bash
python3 <<'PY'
import os, re, sys

path = ".claude/rules/general.md"
if not os.path.isfile(path):
    print(f"SKIP: {path} not present")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if "no built-in Explore" in content:
    print(f"SKIP: {path} already patched")
    sys.exit(0)

# Find a Process line containing "never background agents".
pattern = re.compile(r"(-\s*Process:[^\n]*?)(never background agents)", re.IGNORECASE)
match = pattern.search(content)

if not match:
    print(f"WARN: {path} — no '- Process: ... never background agents' line found; left unchanged")
    sys.exit(0)

injection = "no built-in Explore/general-purpose/plugin agents (use proj-quick-check | proj-researcher), "
new_content = content[: match.start(2)] + injection + content[match.start(2):]

with open(path, "w", encoding="utf-8") as f:
    f.write(new_content)
print(f"PATCHED: {path} — Process line extended")
PY
```

### Step 3 — Patch `CLAUDE.md`

Adds `no-builtin-explore` to the Behavior list and a new anti-pattern bullet. Tolerant of both single-line telegraphic and multi-bullet forms.

```bash
python3 <<'PY'
import os, sys

path = "CLAUDE.md"
if not os.path.isfile(path):
    print(f"WARN: {path} not present — skipping")
    sys.exit(0)

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if "no-builtin-explore" in content:
    print(f"SKIP: {path} already patched")
    sys.exit(0)

changed = False

# 1. Inject no-builtin-explore after never-background-agents in the Behavior list.
if "never-background-agents" in content:
    content = content.replace("never-background-agents", "never-background-agents, no-builtin-explore", 1)
    changed = True
else:
    print(f"WARN: {path} — 'never-background-agents' token not found; Behavior list not patched")

# 2. Append the new anti-pattern bullet after the permission-seeking bullet.
lines = content.split("\n")
new_lines = []
injected_bullet = False
bullet = '- No built-in Explore fallback: code investigation → proj-quick-check (simple) | proj-researcher (complex); NEVER built-in Explore/general-purpose/plugin agents — they bypass project context + evidence tracking'

for line in lines:
    new_lines.append(line)
    if not injected_bullet and "No permission-seeking" in line:
        # Preserve leading whitespace from the matched bullet for alignment.
        prefix_len = len(line) - len(line.lstrip())
        prefix = line[:prefix_len]
        new_lines.append(f"{prefix}{bullet}")
        injected_bullet = True

if injected_bullet:
    content = "\n".join(new_lines)
    changed = True
else:
    print(f"WARN: {path} — 'No permission-seeking' bullet not found; anti-pattern bullet not added")

if changed:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"PATCHED: {path}")
else:
    print(f"SKIP: {path} — no recognizable markers")
PY
```

### Step 4 — Patch all dispatching skills

Globs `.claude/skills/*/SKILL.md`. For each, replaces the old 3-line `AGENT_DISPATCH_POLICY_BLOCK` with the strengthened 6-line block. Skips skills that either already have the new block or do not dispatch agents at all.

```bash
python3 <<'PY'
import glob, os

OLD = """**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents.
If custom agent missing → STOP + inform user. See `techniques/agent-design.md § Agent Dispatch Policy`."""

NEW = """**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `techniques/agent-design.md § Agent Dispatch Policy`."""

NEW_MARKER = "not during skill execution, not as a fallback"

patched = 0
skipped_already = 0
skipped_noblock = 0

for path in sorted(glob.glob(".claude/skills/*/SKILL.md")):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if NEW_MARKER in content:
        skipped_already += 1
        continue

    if OLD not in content:
        skipped_noblock += 1
        continue

    new_content = content.replace(OLD, NEW)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"PATCHED: {path}")
    patched += 1

print(f"SUMMARY: patched={patched} skipped_already={skipped_already} skipped_noblock={skipped_noblock}")
PY
```

### Step 5 — Update bootstrap-state.json

```bash
python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '009'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '009') or a == '009' for a in applied):
    applied.append({
        'id': '009',
        'applied_at': state['last_applied'],
        'description': 'forbid built-in Explore/general-purpose/plugin agent fallback — patch always-loaded rules + strengthen skill policy block'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=009')
PY
```

### Rules for migration scripts

- **Read-before-write** — every patch step reads the target file, detects existing markers, and only writes on change.
- **Idempotent** — re-running prints `SKIP: already patched` for each already-patched file; no duplicate insertions.
- **Tolerant of user edits** — Steps 2 and 3 use pattern/marker matching with explicit WARN-and-skip fallback when the expected shape is missing. Never corrupt a file Claude cannot recognize.
- **Glob all skills** — Step 4 never hardcodes a skill name. Any skill with the old policy block is upgraded.
- **No multi-line sed** — all multi-line edits go through python3 heredocs. Sed multi-line is fragile on Windows bash.
- **Abort on error** — `set -euo pipefail` in bash; python3 blocks exit non-zero on failure.
- **Scope lock** — only touches the four targets above + `bootstrap-state.json`. No agent renames, no technique re-sync, no unrelated cleanup.

### Required: register in migrations/index.json

Add an entry to the `migrations` array:

```json
{
  "id": "009",
  "file": "009-forbid-builtin-explore.md",
  "description": "Forbid built-in Explore/general-purpose/plugin agent fallback — patch CLAUDE.md + .claude/rules/skill-routing.md + .claude/rules/general.md to add always-loaded rule; strengthen AGENT_DISPATCH_POLICY_BLOCK in all dispatching skills.",
  "breaking": false
}
```

---

## Verify

```bash
set +e
fail=0

# 1. skill-routing.md contains ## Forbidden
if [[ -f ".claude/rules/skill-routing.md" ]] && grep -q '^## Forbidden' .claude/rules/skill-routing.md; then
  echo "PASS: .claude/rules/skill-routing.md contains ## Forbidden"
else
  echo "FAIL: .claude/rules/skill-routing.md missing ## Forbidden section"
  fail=1
fi

# 2. general.md Process line extended
if [[ -f ".claude/rules/general.md" ]] && grep -q 'no built-in Explore' .claude/rules/general.md; then
  echo "PASS: .claude/rules/general.md contains 'no built-in Explore'"
else
  echo "FAIL: .claude/rules/general.md missing 'no built-in Explore'"
  fail=1
fi

# 3. CLAUDE.md contains no-builtin-explore marker
if [[ -f "CLAUDE.md" ]] && grep -q 'no-builtin-explore' CLAUDE.md; then
  echo "PASS: CLAUDE.md contains no-builtin-explore"
else
  echo "FAIL: CLAUDE.md missing no-builtin-explore"
  fail=1
fi

# 4. At least one skill carries the new policy block — or 0 is acceptable if
#    this project has no dispatching skills.
skill_count=$(grep -l 'not during skill execution, not as a fallback' .claude/skills/*/SKILL.md 2>/dev/null | wc -l)
total_skills=$(ls .claude/skills/*/SKILL.md 2>/dev/null | wc -l)
if [[ "$skill_count" -gt 0 ]]; then
  echo "PASS: $skill_count skill(s) carry strengthened AGENT_DISPATCH_POLICY_BLOCK"
elif [[ "$total_skills" -eq 0 ]]; then
  echo "PASS: no skills in project (skill_count=0 acceptable)"
else
  # Accept 0 if no skill carried the old policy block either.
  old_block_count=$(grep -l 'If custom agent missing → STOP + inform user\. See' .claude/skills/*/SKILL.md 2>/dev/null | wc -l)
  if [[ "$old_block_count" -eq 0 ]]; then
    echo "PASS: no dispatching skills present (nothing to patch)"
  else
    echo "FAIL: $old_block_count skill(s) still carry old policy block"
    fail=1
  fi
fi

# 5. State file updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "009" ]]; then
  echo "PASS: last_migration = 009"
else
  echo "FAIL: last_migration = $last (expected 009)"
  fail=1
fi

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 009 verification: ALL PASS" || { echo "Migration 009 verification: FAILURES — state NOT updated"; exit 1; }
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → "009"
- append `{ "id": "009", "applied_at": "<ISO8601>", "description": "forbid built-in Explore/general-purpose/plugin agent fallback — patch always-loaded rules + strengthen skill policy block" }` to `applied[]`

---

## Rollback

Restore the patched files from version control or companion repo snapshot:

```bash
# Tracked strategy (files committed to project repo)
git checkout -- CLAUDE.md .claude/rules/skill-routing.md .claude/rules/general.md .claude/skills/

# Companion strategy — restore from companion repo snapshot
# cp -r ~/.claude-configs/<project>/CLAUDE.md ./
# cp -r ~/.claude-configs/<project>/.claude/rules/ ./.claude/
# cp -r ~/.claude-configs/<project>/.claude/skills/ ./.claude/
```

Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"008"` and remove the `009` entry from `applied[]`.

The migration is additive (inserts blocks and bullets, replaces a 3-line block with a 6-line block). No content is deleted from user files — rollback via git checkout is safe.
