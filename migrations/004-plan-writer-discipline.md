# Migration 004 — Plan-Writer Discipline

> Strengthen proj-plan-writer discipline to forbid implementation code in task files, and update /execute-plan to instruct specialists to read domain rules before writing code.

---

## Metadata

```yaml
id: "004"
breaking: false
affects: [agents, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

`proj-plan-writer` was producing task files containing 90+ lines of full method bodies. Example observed in the field: a `task-02-base-import-csv-shim.md` task file included a complete `ReadCsvAsync` C# implementation — `CsvHelper` configuration, `XLWorkbook` loop, exception handling — before any specialist agent saw the task.

Downstream failure mode A: `execute-plan` paste path. Specialist `proj-code-writer-csharp` receives a task with pre-written code and pastes it verbatim. This bypasses `.claude/rules/code-standards-csharp.md` and any framework guardrails the specialist would normally apply — plan-writer runs without those rules loaded.

Downstream failure mode B: diverge path. Specialist sees the pre-written body and treats the task file as a spec mismatch, producing code that diverges from what the plan described, breaking traceability between plan and output.

Root cause: the agent prompt said "planning only" but did not explicitly forbid code blocks, did not cap task file size, and did not show a good/bad contrast. Sonnet drifts toward completeness under ambiguity; without a hard prohibition it fills in implementation detail it believes is helpful.

---

## Changes

1. **Pass A — Patch `.claude/agents/proj-plan-writer.md`**: if the file does not already contain a `Task File Discipline` block, inject the block before the first `## Anti-Hallucination` or `## Scope Lock` section, falling back to EOF append. Block contains hard prohibitions, allowed forms, rationale, size cap, and good/bad contrast.
2. **Pass B — Patch `.claude/skills/execute-plan/SKILL.md`**: in the Per-task protocol section, insert two bullets directing specialists to read `.claude/rules/code-standards-{lang}.md` + `data-access.md` before writing code, and to treat any code in task files as contract/hint not mandate. Falls back to appending under a new `## Per-Task Overrides` heading if anchor not found.
3. **State update** — `last_migration` → "004".

---

## Actions

### Prerequisites

```bash
set -euo pipefail
[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }

if [[ ! -f ".claude/agents/proj-plan-writer.md" ]]; then
  echo "SKIP: no proj-plan-writer.md — project uses different planning agent"
  PROJ_PLAN_WRITER=0
else
  PROJ_PLAN_WRITER=1
fi

if [[ ! -f ".claude/skills/execute-plan/SKILL.md" ]]; then
  echo "SKIP: no execute-plan skill — project did not generate /execute-plan"
  EXECUTE_PLAN=0
else
  EXECUTE_PLAN=1
fi

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Step 1 — Patch proj-plan-writer.md with discipline block

Idempotency: check for `Task file discipline` or `Task File Discipline` substring → skip if present. Otherwise find `## Anti-Hallucination` or `## Scope Lock` as insertion point; fall back to EOF append.

```bash
[[ "$PROJ_PLAN_WRITER" -eq 0 ]] && { echo "SKIP step 1: no proj-plan-writer.md"; } || python3 <<'PY'
import sys

DISCIPLINE_BLOCK = """
## Task File Discipline (HARD RULES)

Task files describe INTENT not IMPLEMENTATION. Specialist agents have domain knowledge; plan-writer does not.

**FORBIDDEN in task files:**
- Method bodies (full function implementations)
- `using` / `import` statements
- Complete class definitions
- Error-handling code blocks
- Ready-to-paste code snippets
- Translated pseudo-code

**ALLOWED:**
- Signatures: `public async Task<X> Foo(Y y, CancellationToken ct)`
- Interface additions: `add byte[] GenerateCsvTemplate();` to `IFoo`
- File paths + what changes ("add method X", "modify class Y")
- Data shapes: `record Bar(int Id, string Name)`
- Step prose (imperative ordered actions)

**Rationale:** specialist agents read `.claude/rules/code-standards-{lang}.md` and framework-specific rules. Plan-writer cannot. Pre-written bodies bypass specialist guardrails.

**Size cap:** task files <=60 lines. Hard warn at >80. Task needs more → split into sub-tasks or let the specialist decide the implementation shape.

**Never copy rule file content into task files.** Reference path: "specialist MUST read `.claude/rules/code-standards-csharp.md` before writing".

**Good:** "Add `ReadAsync(byte[], Action<T>?, CT)` that sniffs PK magic bytes → dispatches to ReadExcelAsync or ReadCsvAsync"

**Bad:** 30-line fenced C# block showing the byte check + if/else + delegation

Task files violating these rules → STOP and restructure.
"""

path = '.claude/agents/proj-plan-writer.md'
with open(path, encoding='utf-8') as f:
    content = f.read()

if 'Task file discipline' in content or 'Task File Discipline' in content:
    print('already applied: discipline block present in proj-plan-writer.md')
    sys.exit(0)

# Find insertion point: before ## Anti-Hallucination or ## Scope Lock
markers = ['## Anti-Hallucination', '## Scope Lock']
insert_pos = None
for marker in markers:
    idx = content.find('\n' + marker)
    if idx != -1:
        insert_pos = idx
        break

if insert_pos is not None:
    content = content[:insert_pos] + '\n' + DISCIPLINE_BLOCK.rstrip() + '\n' + content[insert_pos:]
else:
    # Fall back to EOF append
    content = content.rstrip('\n') + '\n' + DISCIPLINE_BLOCK.rstrip() + '\n'

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Step 1 complete: discipline block injected into proj-plan-writer.md')
PY
```

### Step 2 — Patch execute-plan SKILL.md with specialist-reads-rules bullets

Idempotency: check for `code-standards-{lang}` substring → skip if present. Find `Per-task protocol` heading or a `MUST dispatch` / `dispatch agent` anchor line; insert two bullets after it. Falls back to appending under `## Per-Task Overrides` heading.

```bash
[[ "$EXECUTE_PLAN" -eq 0 ]] && { echo "SKIP step 2: no execute-plan SKILL.md"; } || python3 <<'PY'
import sys, re

RULES_BULLETS = """\
  - Specialist dispatch prompt MUST include: "Read `.claude/rules/code-standards-{lang}.md` + `.claude/rules/data-access.md` (if applicable) BEFORE writing any code. These rules override any code shown in the task file."
  - If task file contains code snippets → treat as CONTRACT/HINT (signatures + intent), not MANDATE. Specialist applies domain rules + framework guardrails that plan-writer lacked."""

path = '.claude/skills/execute-plan/SKILL.md'
with open(path, encoding='utf-8') as f:
    content = f.read()

if 'code-standards-{lang}' in content:
    print('already applied: specialist-reads-rules bullets present in execute-plan SKILL.md')
    sys.exit(0)

lines = content.split('\n')

# Strategy 1: find "Per-task protocol" heading
per_task_idx = None
for i, line in enumerate(lines):
    if re.search(r'[Pp]er.task protocol', line):
        per_task_idx = i
        break

if per_task_idx is not None:
    # Find the first list item after the heading; insert after that item
    insert_after = per_task_idx
    for i in range(per_task_idx + 1, len(lines)):
        if re.match(r'\s*[-*]\s+', lines[i]):
            insert_after = i
            break
    new_lines = lines[:insert_after + 1] + RULES_BULLETS.split('\n') + lines[insert_after + 1:]
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print('Step 2 complete: specialist-reads-rules bullets inserted after Per-task protocol anchor')
    sys.exit(0)

# Strategy 2: find "MUST dispatch" / "dispatch agent" bullet
dispatch_idx = None
for i, line in enumerate(lines):
    if re.search(r'MUST dispatch|dispatch agent', line, re.IGNORECASE):
        dispatch_idx = i
        break

if dispatch_idx is not None:
    new_lines = lines[:dispatch_idx + 1] + RULES_BULLETS.split('\n') + lines[dispatch_idx + 1:]
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print('Step 2 complete: specialist-reads-rules bullets inserted after dispatch anchor')
    sys.exit(0)

# Fall back: append under new heading
print('WARNING: no Per-task protocol or dispatch anchor found — appending under ## Per-Task Overrides')
with open(path, 'a', encoding='utf-8') as f:
    f.write('\n\n## Per-Task Overrides\n\n')
    f.write(RULES_BULLETS + '\n')
print('Step 2 complete: specialist-reads-rules bullets appended (fallback)')
PY
```

### Step 3 — Update bootstrap-state.json

```bash
python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '004'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '004') or a == '004' for a in applied):
    applied.append({
        'id': '004',
        'applied_at': state['last_applied'],
        'description': 'plan-writer discipline — forbid implementation code in task files; execute-plan specialist reads rules'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=004')
PY
```

---

## Verify

```bash
set +e
fail=0

# 1. If plan-writer existed, discipline block present
if [[ -f ".claude/agents/proj-plan-writer.md" ]]; then
  if grep -qi "Task file discipline\|Task File Discipline" .claude/agents/proj-plan-writer.md; then
    echo "PASS: proj-plan-writer.md has discipline block"
  else
    echo "FAIL: proj-plan-writer.md missing discipline block"
    fail=1
  fi
else
  echo "SKIP: no proj-plan-writer.md in project"
fi

# 2. If execute-plan existed, specialist-reads-rules bullet present
if [[ -f ".claude/skills/execute-plan/SKILL.md" ]]; then
  if grep -q "code-standards-{lang}" .claude/skills/execute-plan/SKILL.md; then
    echo "PASS: execute-plan SKILL.md has specialist-reads-rules bullet"
  else
    echo "FAIL: execute-plan SKILL.md missing specialist-reads-rules bullet"
    fail=1
  fi
else
  echo "SKIP: no execute-plan SKILL.md in project"
fi

# 3. State file updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "004" ]]; then
  echo "PASS: last_migration = 004"
else
  echo "FAIL: last_migration = $last (expected 004)"
  fail=1
fi

echo "---"
[[ $fail -eq 0 ]] && echo "Migration 004 verification: ALL PASS" || { echo "Migration 004 verification: FAILURES — state NOT updated"; exit 1; }
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## Rules for migration scripts

- **Idempotent** — Step 1 and Step 2 check for marker strings before modifying; re-running is a safe no-op.
- **Glob agent filenames, never hardcode** — this migration targets a single named agent (`proj-plan-writer`) and a single named skill (`execute-plan`); no family iteration required.
- **Read-before-write** — every file is read by python3 before any rewrite.
- **Abort on error** — `set -euo pipefail` in all bash blocks; state update in Step 3 only runs after Steps 1 and 2 succeed.
- **Self-contained** — operates entirely on local `.claude/` files; no remote fetch.

### Required: register in migrations/index.json

Add to the `migrations` array in `migrations/index.json`:

```json
{
  "id": "004",
  "file": "004-plan-writer-discipline.md",
  "description": "Strengthen proj-plan-writer discipline to forbid implementation code in task files, and update /execute-plan to instruct specialists to read domain rules before writing code.",
  "breaking": false
}
```

---

## State Update

On success:
- `last_migration` → "004"
- append `{ "id": "004", "applied_at": "<ISO8601>", "description": "plan-writer discipline — forbid implementation code in task files; execute-plan specialist reads rules" }` to `applied[]`

---

## Rollback

Not automatic. Restore `.claude/agents/proj-plan-writer.md` and `.claude/skills/execute-plan/SKILL.md` from git. If `.claude/` is gitignored, restore from companion repo at `~/.claude-configs/{project}` or re-run the bootstrap module generation.
