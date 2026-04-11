# Migration 012 — Plan-writer packing enforcement

<!-- migration-id: 012-plan-writer-packing-enforcement -->


> Regenerate `.claude/agents/proj-plan-writer.md`, `.claude/skills/write-plan/SKILL.md`, and `.claude/skills/execute-plan/SKILL.md` with 3-layer packing enforcement: (A) agent Self-Audit process step + mandatory Tier Classification Table output + worked CORRECT/REJECTED example; (B) `/write-plan` Post-Dispatch Audit gate w/ loopback cap 2 + hard-fail; (C) remove legacy `task-NN-*.md` format + add `/execute-plan` Pre-Flight Audit w/ hard-reject. ALSO writes `.claude/rules/agent-scope-lock.md` + retrofits it into every `proj-*` agent's STEP 0 force-read block (prevents silent absorption of main-thread steps observed 2026-04-11 during this migration's own plan execution). Fixes 2026-04-11 regression where migration-010's packing algorithm was specified but unenforced — emitted 5 separate batch files for same-agent same-layer disjoint-dep micro tasks that should have packed into 1.

---

## Metadata

```yaml
id: "012"
breaking: false
affects: [agents, skills, rules]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Migration-010 shipped the First Fit Decreasing packing algorithm in `.claude/agents/proj-plan-writer.md` but packing was NOT mechanically enforced. First real use (mcp-routing-audit plan, 2026-04-11) emitted A1–A5 as 5 separate `batch-*.md` files despite all criteria for single-unit packing being met: same agent (`proj-code-writer-markdown`), same layer (`docs`), disjoint dep_sets (5 different files), tier ≤moderate, combined tasks=5, est context ~42K (<60K cap), file count=5 (<10 cap).

Result: 5× fixed dispatch overhead (~20-35K/ea), 5× rule-file reads, breach of 3-concurrent parallel cap. Exactly the failure migration-010 was meant to fix — but the algorithm lived in agent prose w/ no enforcement mechanism.

Fix: 3 reinforcing layers.

- **Layer C (output space)** — remove `task-NN-*.md` legacy format entirely. `batch-NN-*.md` is the ONLY accepted plan output. Removes cognitive escape hatch.
- **Layer A (agent cognition)** — (A1) mandatory `Tier Classification Table` section in master plan BEFORE `Dispatch Plan` (visible think-step forces honest classification); (A2) Self-Audit process step after emitting batch files, bounded to 5 passes, merges pairs satisfying merge criteria; (A3) worked CORRECT + REJECTED example in agent prompt.
- **Layer B (skill audit gate)** — `/write-plan` Post-Dispatch Audit parses emitted batch headers, re-applies merge criteria, loops back to plan-writer w/ violation list (cap 2), hard-fails on 3rd attempt. `/execute-plan` Pre-Flight Audit runs the same check, hard-rejects plans from prior sessions that violate packing.

Merge criteria (single source of truth — agent + both skills reference):
```
mergeable(Bi, Bj) ⟺
  same agent AND same layer AND disjoint dep_sets AND
  combined_tasks ≤5 AND combined_context <60K AND combined_files ≤10
```

Full brainstorm + approach: see the packing-enforcement spec in the bootstrap repo (`modules/05-core-agents.md` § Dispatch 2, `modules/06-skills.md` § Dispatch 16 + 17).

---

## Changes

1. Writes `.claude/rules/agent-scope-lock.md` — new rule enforcing strict batch-file scope on executing agents (forbids silent absorption of main-thread steps or adjacent work). Marker `# Agent Scope Lock`.
2. Retrofits every `.claude/agents/proj-*.md` (excluding `references/`) — injects `agent-scope-lock.md` rule line into the existing STEP 0 force-read block (after `token-efficiency.md`). Requires migration 011 already applied.
3. Regenerates `.claude/agents/proj-plan-writer.md` — adds Process step 10 `Self-Audit` (bounded 5 passes), adds `Tier Classification Table` as required master plan output (before Dispatch Plan), adds `FORBIDDEN at batch level` discipline bullet, adds CORRECT/REJECTED worked example, removes legacy `task-NN-*.md` acceptance sentence. Inline STEP 0 block already includes `agent-scope-lock.md`.
4. Regenerates `.claude/skills/write-plan/SKILL.md` — adds `## Post-Dispatch Audit` section (parse batch headers → detect merge violations → loopback ≤2 → hard-fail), removes legacy task-file format references, updates plan-writer produces block to include Tier Classification Table.
5. Regenerates `.claude/skills/execute-plan/SKILL.md` — adds `## Pre-Flight Audit` section (hard-reject on missing batch files OR merge-criteria violations), removes `Format Auto-Detection` section, removes `Legacy Per-Task Protocol` section, updates Steps numbering (old step 3 "Detect format" → new step 3 "Pre-Flight Audit").
6. Advances `.claude/bootstrap-state.json` → `last_migration: "012"` + appends to `applied[]`.

Idempotent: re-run detects marker headings (`# Agent Scope Lock`, `agent-scope-lock.md` inside STEP 0 blocks, `Tier Classification Table`, `Self-Audit`, `Post-Dispatch Audit`, `Pre-Flight Audit`) and prints `SKIP: already patched`. Breaking caveat: any in-flight plan file using legacy `task-NN-*.md` format will be hard-rejected by the new `/execute-plan` Pre-Flight Audit — user must re-run `/write-plan` to regenerate. Per packing-enforcement spec open question 5: this is acceptable (no retroactive fixup of existing plans; new enforcement only applies to new `/write-plan` runs).

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: no .claude/agents directory"; exit 1; }
[[ -d ".claude/skills" ]] || { echo "ERROR: no .claude/skills directory"; exit 1; }
[[ -f ".claude/agents/proj-plan-writer.md" ]] || { echo "ERROR: .claude/agents/proj-plan-writer.md missing — migration 010 must be applied first"; exit 1; }
[[ -d ".claude/skills/write-plan" ]] || { echo "ERROR: .claude/skills/write-plan missing — cannot migrate"; exit 1; }
[[ -d ".claude/skills/execute-plan" ]] || { echo "ERROR: .claude/skills/execute-plan missing — cannot migrate"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }

# Migrations 010 + 011 must be applied — 012 builds on the packing algorithm (010)
# and patches the STEP 0 force-read block introduced by 011.
python3 - <<'PY'
import json, sys
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
applied = state.get('applied', [])
has_010 = any(
    (isinstance(a, dict) and a.get('id') == '010') or a == '010'
    for a in applied
)
has_011 = any(
    (isinstance(a, dict) and a.get('id') == '011') or a == '011'
    for a in applied
)
if not has_010:
    print("ERROR: migration 010 (plan-writer dispatch units) not applied — cannot apply 012 on top of pre-010 state")
    sys.exit(1)
if not has_011:
    print("ERROR: migration 011 (agent rules audit) not applied — 012 requires the STEP 0 force-read block before it can patch agents")
    sys.exit(1)
print("OK: migrations 010 + 011 present in applied[]")
PY
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

agent_patched=0
write_patched=0
execute_patched=0

if [[ -f ".claude/agents/proj-plan-writer.md" ]] && \
   grep -q "Tier Classification Table" .claude/agents/proj-plan-writer.md && \
   grep -q "Self-Audit" .claude/agents/proj-plan-writer.md; then
  agent_patched=1
fi

if [[ -f ".claude/skills/write-plan/SKILL.md" ]] && \
   grep -q "Post-Dispatch Audit" .claude/skills/write-plan/SKILL.md; then
  write_patched=1
fi

if [[ -f ".claude/skills/execute-plan/SKILL.md" ]] && \
   grep -q "Pre-Flight Audit" .claude/skills/execute-plan/SKILL.md; then
  execute_patched=1
fi

if [[ "$agent_patched" -eq 1 && "$write_patched" -eq 1 && "$execute_patched" -eq 1 ]]; then
  echo "SKIP: migration 012 already applied (all three targets carry new markers)"
  exit 0
fi

echo "Applying migration 012: agent_patched=$agent_patched write_patched=$write_patched execute_patched=$execute_patched"
```

### Step 1 — Write `.claude/rules/agent-scope-lock.md`

Idempotent: skip if file exists AND contains marker `# Agent Scope Lock`. Otherwise write the full rule content. Mirrors `modules/02-project-config.md` Step 3 (the rules dispatch embeds the same content verbatim for fresh bootstraps).

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/rules/agent-scope-lock.md"
marker = "# Agent Scope Lock"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        if marker in f.read():
            print(f"SKIP: {path} already present")
            sys.exit(0)

content = """# Agent Scope Lock

## Rule
Executing agent touches ONLY files listed in its batch/task file `#### Files` sections. Nothing outside the listed scope — even trivial, even adjacent, even "helpful".

## Scope (applies to)
All `proj-*` executing/writer agents dispatched via `/execute-plan`, `/tdd`, `/code-write`, or direct skill-invocation. NOT `proj-plan-writer` (has its own separate scope lock in agent spec).

## Forbidden
- Files not listed in any Task `#### Files` → off-limits regardless of edit size
- Steps labeled `main-thread` in master plan Dispatch Plan → main thread only
- Silent absorption of adjacent work: 1-line JSON append, 1-char typo fix, trivial `.learnings/` update
- Adjacent refactoring, dead-code cleanup, stale-comment fix unless explicitly listed
- Being "helpful" outside task list — correctness does not justify scope expansion

## Required
- Need something off-scope → STOP, return message to main thread: `SCOPE EXPANSION NEEDED: {file|step} — reason: {short}`
- Batch verification commands cover only listed files; silent absorption creates coverage gap
- If a plan's Dispatch Plan lists `main-thread` steps, those belong to the main thread ONLY

## Example — CORRECT
Batch: `Task 1.1: edit A.md; Task 1.2: create B.md`. Master plan Dispatch Plan: `main-thread step: append one line to index.json`.
→ Agent edits A.md, creates B.md, returns. Agent does NOT touch index.json.

## Example — FORBIDDEN
Same batch. Agent thinks "index.json is 1 line, I'll just do it for convenience".
→ WRONG. Scope lock violated. Return without touching index.json. Main thread handles it.

## Rationale
- Silent absorption breaks batch-verification coverage (verification command lists only in-scope files)
- Dispatch Plan is the contract between plan-writer and execute-plan; absorption voids the contract
- Main-thread steps exist for deliberate reasons (trivial mechanical ops outside specialist domain, operations needing orchestrator context)
- Scope creep destroys plan→execution traceability, makes blast radius unpredictable
- Observed 2026-04-11: `proj-code-writer-markdown` absorbed main-thread index.json append during migration 012 batch. Correct outcome, wrong discipline. This rule exists to prevent recurrence.

## Enforcement
- Force-read: this rule is in the STEP 0 force-read list of every `proj-*` executing agent (via modules/05 + modules/07 templates; retrofit via migration 011 + 012)
- No skill-level mechanical check exists — scope lock is an agent-side discipline rule. Review-time catch: `/review` flags any file change outside the planned scope.
"""

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"WROTE: {path}")
PY
```

### Step 2 — Retrofit `agent-scope-lock.md` rule line into every sub-agent's STEP 0 block

Globs `.claude/agents/proj-*.md` (sub-specialist-safe; excludes `references/`). For each agent that has the `STEP 0 — Load critical rules` marker (added by migration 011) but does NOT yet contain `agent-scope-lock.md`, inject the new rule line immediately after the `token-efficiency.md` line inside the STEP 0 block. Guarded: only patches the first `token-efficiency.md` occurrence that follows the STEP 0 marker, preventing false-positive rewrites elsewhere in the file.

Idempotent: re-runs detect `agent-scope-lock.md` in the file and print `SKIP: already patched`.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import glob, os, sys

STEP0_MARKER = "STEP 0 — Load critical rules"
RULE_MARKER = "agent-scope-lock.md"
TOKEN_LINE_PREFIX = "- `.claude/rules/token-efficiency.md`"
NEW_LINE = "- `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)"

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
skipped_nostep0 = 0
skipped_notoken = 0

for path in candidates:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if RULE_MARKER in content:
        skipped_already += 1
        continue

    if STEP0_MARKER not in content:
        print(f"WARN: {path} — no STEP 0 marker (migration 011 not applied?); left unchanged")
        skipped_nostep0 += 1
        continue

    lines = content.split("\n")
    step0_idx = None
    for i, line in enumerate(lines):
        if STEP0_MARKER in line:
            step0_idx = i
            break

    # Locate the first token-efficiency.md line AFTER the STEP 0 marker.
    insert_after = None
    for i in range(step0_idx + 1, len(lines)):
        if lines[i].lstrip().startswith(TOKEN_LINE_PREFIX):
            insert_after = i
            break
        # Stop scanning at the closing --- of the STEP 0 block (avoid cross-block edits).
        if lines[i].strip() == "---" and i > step0_idx + 3:
            break

    if insert_after is None:
        print(f"WARN: {path} — STEP 0 block has no token-efficiency.md line; left unchanged")
        skipped_notoken += 1
        continue

    # Preserve indentation of the token-efficiency line (block may be indented under a parent list).
    indent = lines[insert_after][: len(lines[insert_after]) - len(lines[insert_after].lstrip())]
    lines.insert(insert_after + 1, indent + NEW_LINE)

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"PATCHED: {path}")
    patched += 1

print(f"SUMMARY: patched={patched} skipped_already={skipped_already} skipped_nostep0={skipped_nostep0} skipped_notoken={skipped_notoken} total_candidates={len(candidates)}")
PY
```

### Step 3 — Regenerate `.claude/agents/proj-plan-writer.md`

Read-before-write: checks for `Tier Classification Table` marker; skips if already present. Writes the full updated agent file via python3 heredoc (owns new state). Content mirrors `modules/05-core-agents.md` § Dispatch 2 (after task 01.1 of the packing-enforcement plan).

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/agents/proj-plan-writer.md"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        existing = f.read()
    if "Tier Classification Table" in existing:
        print(f"SKIP: {path} already patched")
        sys.exit(0)

content = '''---
name: proj-plan-writer
description: >
  Use when breaking a design or spec into concrete, ordered, verifiable
  implementation tasks. Takes spec + codebase context, produces dependency-ordered
  task list packed into dispatch-unit batch files for focused agent dispatch.
tools: Read, Write, Grep, Glob
model: sonnet
effort: high
maxTurns: 100
color: blue
---

## STEP 0 — Load critical rules (MANDATORY first action)

Before any task-specific work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
- `.claude/rules/code-standards-{your primary lang}.md` (if present)

Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

---

## Role
Senior architect — analyze specs + codebases → tier-classified, dep-ordered dispatch units (one agent invocation per unit executes N ordered tasks back-to-back).

## Reframe
Dispatch unit = execution primitive (one Agent call); task = planning primitive. A batch file carries 1-N ordered tasks the same agent runs sequentially, verifying once at the end. Ordering is preserved INSIDE a batch (dep-ordered top-down); batching is governed by tier + dep_set intersection, NOT agent type alone.

## Pass-by-Reference Contract
Write master plan to `.claude/specs/{branch}/{date}-{topic}-plan.md`.
Emit one `batch-NN-{summary}.md` per dispatch unit under `.claude/specs/{branch}/{date}-{topic}-plan/` (each batch holds 1-N ordered tasks). `batch-NN-*.md` is the ONLY accepted output format — legacy `task-NN-*.md` removed (packing-enforcement Layer C).
Return ONLY: master plan path + summary <100 chars.

## Before Writing (MANDATORY)
1. Read spec file completely
2. Read `claude-bootstrap.md` (if present) for current module list + structure
3. Read `.claude/rules/code-standards-markdown.md` for conventions
4. Scan affected files to understand current state — never plan changes to unread files

## Process
1. Read spec file completely
2. Scan codebase for affected files + patterns (Grep/Glob)
3. Break into tasks — each independently completable + verifiable
4. Order by dependency (data → API → UI)
5. Classify every task → Tier Classification (below)
6. Pack tasks into dispatch units → Dispatch Unit Packing (below)
7. Assign ONE verification command per dispatch unit (runs at end of batch)
8. Write master plan (index + execution order + dependency graph + Tier Classification Table + Dispatch Plan). Tier Classification Table MUST appear BEFORE Dispatch Plan — forces visible think-step output per task.
9. Write batch files (one per dispatch unit) — self-contained w/ all context the executing agent needs (rule files to read once, file paths, per-task sections, batch verification command)
10. **Self-Audit** (MANDATORY, bounded): re-read all emitted batch files. For each pair (Bi, Bj) check merge criteria:
    `same agent AND same layer AND disjoint dep_sets AND combined_tasks ≤5 AND combined_context <60K AND combined_files ≤10`
    If satisfied → merge Bi into Bj, delete Bi, update master plan Batch Index + Dispatch Plan. Repeat until no merges possible. **Cap: 5 passes** — if still converging after 5, plan is structurally broken → hard-fail + report reason.
    Rationale: packing was specified but unenforced regressed 2026-04-11 (5 batch files emitted for packable micro tasks). Self-audit makes enforcement mechanical. Defense-in-depth: `/write-plan` skill re-runs same audit gate.

## Tier Classification
5 signals ranked; tie-break: promote up a tier.

1. **Dependency topology** [HIGHEST PRIORITY] — does this task share files/symbols w/ any other task?
   - `independent`: no shared files/symbols → aggressively batchable
   - `local`: same module, different files → batch only within same dispatch unit
   - `global`: shares a file or symbol w/ another task → serialize, never co-batched
2. **Step count** as tool-call fan-out proxy (count of entries in task's Steps section)
   - 1-3 steps → micro
   - 4-10 steps → moderate
   - 11+ steps → complex
3. **Operation verb category** (from task title + Steps language)
   - create/add (new file, new method, new test, new enum value) → isolated, batchable
   - modify/update/refactor (existing symbol) → dependency check required
   - migrate/delete/rename/restructure → high blast radius, bias toward solo dispatch
4. **File count** (distinct paths in task's Files section)
   - 1 file → micro candidate
   - 2-5 files → moderate candidate, batch only w/ same-layer tasks
   - 6+ files → complex, solo dispatch
   - 10+ files → subagent overhead definitely warranted
5. **Layer identity** (assigned from file paths + intent):
   `schema | data | api | domain | ui | test | config | docs | infra`
   - Same-layer tasks share rule context → co-batch safely
   - Cross-layer co-batching permitted only for leftover lonely micro tasks w/ no shared deps

**FORBIDDEN in tier classification:** MUST NOT estimate LOC, token counts, or tool-call counts to tier a task. Plan-writer sees intent only, not generated code. Use intent-level signals ONLY (dep topology, step count, verb, file count, layer). Output size is not a planning-time signal.

## Dispatch Unit Packing
First Fit Decreasing over dep-isolated, layer-grouped bins.

1. **Solo-dispatch all complex tasks.** One dispatch unit per complex task.
2. **Pack moderate tasks.** Group by (agent, layer). Sort by dep order. For each task: find first existing moderate-unit where (a) no dep_set intersection w/ any task already in unit, (b) unit has <3 tasks, (c) estimated context budget <60K. Found → add. Else → open new unit.
3. **Pack micro tasks.** Group by (agent, layer). Sort by dep order. For each task: find first existing micro-unit where (a) no dep_set intersection, (b) unit has <5 tasks, (c) estimated context budget <60K. Found → add. Else → open new unit.
4. **Leftover cross-layer merging (micro only).** If ≤2 micro units have 1 task each, different layers, same agent, no shared deps → merge into one cross-layer micro unit. Avoids lonely-solo-dispatch waste.
5. **Global caps (override all):**
   - ≤5 tasks per dispatch unit regardless of tier mix
   - ≤60K estimated context per unit
   - ≤10 distinct files touched across unit
6. **Emit dispatch units** in dep-order layered batches for the Dispatch Plan section.

## Context Budget Estimator
Heuristic, conservative:
`25K + 2K·R + 0.5K·T + 2K·F` where
- R = distinct rule files needed (code-standards-*, data-access, etc.)
- T = tasks in unit
- F = distinct files touched across unit

Budget cap: 60K. Baseline 25K covers system + CLAUDE.md + agent frontmatter + MCP schemas. Never measured; deliberately conservative.

## Parallel-Batch Rule
Independent batches (no shared deps) may dispatch in parallel, up to 3 concurrent per agent type (consistent w/ Anthropic MAS 3-5 operating range).

## Retry Policy
On batch verification fail → agent reports which sub-task (NN.M) broke it + returns partial-success map. Main thread re-dispatches each failed task SOLO (no re-batching on retry). Prevents retry amplification.

## Output Format — Master Plan
```
## Plan: {feature}

### Tier Classification Table (REQUIRED — must appear BEFORE Dispatch Plan)
| task_id | agent | tier | layer | dep_set | step_count | verb |
|---|---|---|---|---|---|---|
| 01.1 | proj-code-writer-markdown | micro | docs | {files} | 3 | modify |
| 01.2 | proj-code-writer-markdown | micro | docs | {files} | 4 | modify |
| ... | ... | ... | ... | ... | ... | ... |

All tasks enumerated w/ explicit classification. Forces the think-step to produce visible, inspectable output — if N rows read `(same agent, same layer, disjoint deps, micro)`, packing becomes obvious + auditable. Missing table = plan rejected.

### Dispatch Plan
- Batch 1 (proj-code-writer-csharp, tier: micro, layer: domain, 5 tasks)
    Verification: `dotnet build Foo`. Deps: none. Parallel w/: Batch 2.
- Batch 2 (proj-code-writer-markdown, tier: moderate, layer: docs, 2 tasks)
    Verification: `markdownlint modules/`. Deps: none. Parallel w/: Batch 1.
- Batch 3 (proj-code-writer-csharp, tier: complex, layer: data, 1 task)
    Verification: `dotnet test`. Deps: Batch 1.

### Batch Index
- batch-01-{summary}.md — {agent, tier, task count}
- batch-02-{summary}.md — {agent, tier, task count}

### Dependency Graph
{ordered relationships, unclear deps flagged}

### Risks
- {anything unclear or potentially breaking}
```

## Output Format — Batch Files
Location: `.claude/specs/{branch}/{date}-{topic}-plan/batch-NN-{summary}.md`
Body cap: ≤200 lines per batch file (bounds intra-batch context rot).

```
## Batch {NN}: {summary}
### Agent: proj-{name}
### Tier: {micro|moderate|complex}
### Layer: {schema|data|api|domain|ui|test|config|docs|infra}
### Verification: `{single command run ONCE at end of batch}`
### Rule files to read (once at batch start): {list}
### Dependency set: {files+symbols touched by this batch}
---
### Task {NN}.1: {title}
#### Tier: {micro|moderate|complex}
#### Operation: {create|modify|migrate}
#### Context (1-3 sentences — what executing agent needs + WHY)
#### Contract (interface shapes, method signatures, data types — intent, NOT bodies)
#### Steps (imperative prose, 1-11+ depending on tier)
#### Files (paths + what changes — "add method X", NOT literal snippets)
#### Dep set: {files+symbols this specific task touches}

### Task {NN}.2: {title}
[...]
---
### Batch verification
Run `{command}` once after all tasks complete. On fail: report which task (NN.M) broke it; stop; return partial-success map.
```

## Task File Discipline — HARD RULES
Violated = plan rejected. Applies to each task sub-section inside a batch file.

- Task sections describe **INTENT not IMPLEMENTATION.** Specialist agents have domain knowledge; plan-writer does not.
- **FORBIDDEN in task sections:** method bodies, `using`/`import` statements, full class definitions, error-handling code, ready-to-paste code blocks, translated pseudo-code
- **FORBIDDEN at batch level:** emitting multiple batch files when self-audit merge criteria are satisfied. Batch files that could merge (same agent + same layer + disjoint dep_sets + combined tasks ≤5 + combined context <60K + combined files ≤10) MUST be merged before returning. Self-Audit process step (above) enforces this mechanically. Violation = plan rejected at skill-level audit gate.
- **ALLOWED:** signatures (`public async Task<X> Foo(Y y, CancellationToken ct)`), interface additions (`add byte[] GenerateCsvTemplate();` to IFoo), file paths, data shapes (`record Bar(int Id, string Name)`), step prose
- **Rationale:** specialist reads `.claude/rules/code-standards-{lang}.md` + framework rules. Plan-writer cannot. Pre-written bodies bypass specialist guardrails.
- **Size cap:** each individual Task sub-section ≤60 lines (hard warn at >80). Batch file as a whole ≤200 lines. If task needs more → split into sub-tasks or let specialist decide.
- **NEVER copy rule file content** into task sections. Reference path: `specialist MUST read .claude/rules/code-standards-csharp.md before writing`.
- **Good:** "Add `ReadAsync(byte[], Action<T>?, CT)` that sniffs PK magic bytes → dispatches to ReadExcelAsync or ReadCsvAsync".
- **Bad:** 30-line fenced C# block showing the byte check + if/else + delegation.

## Packing Examples (worked few-shot — CORRECT vs REJECTED)

**CORRECT** — 5 markdown edits to 5 different files, same agent (`proj-code-writer-markdown`), same layer (`docs`), disjoint dep_sets, all micro (1-3 steps each) → pack into 1 batch file `batch-01-markdown-edits.md` w/ 5 task sub-sections (Task 01.1 through 01.5). ONE dispatch, ONE verification run, one rule-file read. Merge criteria satisfied: same agent + same layer + disjoint deps + combined_tasks=5 + est_context ~42K (25K baseline + 2K·1R + 0.5K·5T + 2K·5F) < 60K cap + files=5 < 10 cap.

**REJECTED** — same 5 tasks emitted as 5 separate batch files (batch-01 through batch-05), each containing 1 task. Observed 2026-04-11 regression. Merge criteria fully satisfied but 5× dispatch overhead incurred (~20-35K/ea fixed), 5× rule-file reads, breaches 3-concurrent parallel cap. Self-Audit MUST merge these into 1 batch file before returning. `/write-plan` skill Post-Dispatch Audit re-checks + loops back (≤2) if agent skipped Self-Audit.

## Anti-Hallucination
- Verify all file paths exist before referencing (Glob/Read)
- Never plan changes to unread files
- Every dispatch unit needs ONE concrete verification command — no "check that it works"
- Unclear dependency → note in Risks, don't guess
- Only co-batch tasks w/ verified same agent + no dep_set intersection
- If a task sub-section exceeds 80 lines or contains complete method bodies or a batch file exceeds 200 lines → STOP and restructure (intent over implementation)

<use_parallel_tool_calls>
Batch all independent tool calls into one message.
Multiple Reads → batch. Multiple Greps → batch.
NEVER: Read A → respond → Read B. INSTEAD: Read A + B → respond.
</use_parallel_tool_calls>

## Scope Lock
Plan ONLY what's specified — no extras, no adjacent refactoring, no out-of-scope tasks.
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"PATCHED: {path}")
PY
```

### Step 4 — Regenerate `.claude/skills/write-plan/SKILL.md`

Read-before-write: checks for `Post-Dispatch Audit` marker; skips if already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/skills/write-plan/SKILL.md"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        existing = f.read()
    if "Post-Dispatch Audit" in existing:
        print(f"SKIP: {path} already patched")
        sys.exit(0)

content = '''---
name: write-plan
description: >
  Use when you have requirements or a spec and need to break them into
  concrete implementation steps. Creates plan with dispatch batching.
  Use after /brainstorm or when starting from a clear spec. Dispatches proj-plan-writer.
argument-hint: "[spec-file-path]"
allowed-tools: Agent Read Write
model: opus
effort: high
# Skill Class: main-thread — dispatches proj-plan-writer, writes plan files
---

## /write-plan — Implementation Planning

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Plan generation: `proj-plan-writer`

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `.claude/references/techniques/agent-design.md § Agent Dispatch Policy`.

### Steps
1. Read spec from `.claude/specs/{branch}/` | conversation context
2. Read `.claude/skills/code-write/references/pipeline-traces.md` (if exists)
3. Dispatch agent via `subagent_type="proj-plan-writer"` w/:
   - Spec content (file path reference)
   - Discovery context (languages, frameworks, commands)
   - Pipeline traces (if exist)
   - Write master plan to `.claude/specs/{branch}/{date}-{topic}-plan.md`
   - Write batch files to `.claude/specs/{branch}/{date}-{topic}-plan/`
     One file per dispatch unit: `batch-NN-{summary}.md` (1-N ordered tasks per file)
   - Return master plan path + summary
4. Run Post-Dispatch Audit (see below) — loopback ≤2 on violation, hard-fail on 3rd

### Plan-writer Produces
- **Master plan** = index + execution order + dependency graph + Tier Classification Table + Dispatch Plan + Batch Index. Tier Classification Table appears BEFORE Dispatch Plan (visible think-step).
- **Batch files** = self-contained dispatch units, agent gets ONLY its batch file as context. One batch file per dispatch unit; holds 1-N ordered tasks the same agent runs sequentially, verifying once at end. Batch files are the ONLY accepted output format — legacy `task-NN-*.md` removed (Layer C of packing enforcement spec).

### Batch File Format
```
## Batch {NN}: {summary}
### Agent: proj-{name}
### Tier: {micro|moderate|complex}
### Layer: {schema|data|api|domain|ui|test|config|docs|infra}
### Verification: `{single command run ONCE at end of batch}`
### Rule files to read (once at batch start): {list}
### Dependency set: {files+symbols touched by this batch}
---
### Task {NN}.1: {title}
#### Tier: {micro|moderate|complex}
#### Operation: {create|modify|migrate}
#### Context — 1-3 sentences (what + WHY)
#### Contract — signatures, data shapes, interface additions (INTENT, not bodies)
#### Steps — imperative prose, 1-11+ entries depending on tier
#### Files — paths + what changes ("add method X", NOT literal snippets)
#### Dep set — files+symbols this specific task touches
### Task {NN}.2: {title}
[...]
---
### Batch verification — run `{command}` ONCE after all tasks complete.
```

Size caps: batch file body ≤200 lines total; individual task sub-section ≤60 lines (hard warn at >80). Over cap → split or let specialist decide.

### Post-Dispatch Audit (MANDATORY — runs after `proj-plan-writer` returns)

1. Glob `batch-*.md` under the emitted plan directory
2. Parse each batch header: `Agent:`, `Layer:`, task count, `Dependency set:`
3. For every pair (Bi, Bj) check merge criteria:
   `same agent AND same layer AND disjoint dep_sets AND combined_tasks ≤5 AND combined_context <60K AND combined_files ≤10`
   (merge criteria live in `proj-plan-writer` spec — single source of truth)
4. No violations → pass plan to user, done
5. Violation found → re-dispatch `proj-plan-writer` w/ corrective prompt containing: (a) the specific violation list (which batches could merge + why); (b) pointer to the agent's Self-Audit process step (NOT raw merge list, NOT heavy-hand merge instructions — trust the agent to apply its own audit given the violation context). **Loopback cap: 2 attempts.**
6. After 2 failed loopbacks → **HARD-FAIL** w/ user-visible error listing every unmerged batch pair + merge criteria that matched + instruction to re-run `/write-plan` or inspect plan manually. Do NOT pass broken plan to user.

Rationale: defense-in-depth. Agent Self-Audit (Layer A, `proj-plan-writer` spec) trains cognition; this gate mechanically verifies. Both exist deliberately — see packing enforcement spec (`.claude/specs/main/2026-04-11-plan-writer-packing-enforcement-spec.md` in the bootstrap repo). Regression context: 2026-04-11 mcp-routing-audit plan emitted 5 batch files for packable micro tasks; this gate blocks that failure mode structurally.

### Dispatch Plan Section
```
### Dispatch Plan
- Batch 1 (proj-code-writer-csharp, tier: micro, layer: domain, 5 tasks)
    Verification: `dotnet build Foo`. Deps: none. Parallel w/: Batch 2.
- Batch 2 (proj-code-writer-markdown, tier: moderate, layer: docs, 2 tasks)
    Verification: `markdownlint modules/`. Deps: none. Parallel w/: Batch 1.
- Batch 3 (proj-code-writer-csharp, tier: complex, layer: data, 1 task)
    Verification: `dotnet test`. Deps: Batch 1.

### Batch Index
- batch-01-{summary}.md — {agent, tier, task count}
- batch-02-{summary}.md — {agent, tier, task count}
```

### Batching Rules
Plan-writer classifies each task by 5 signals (dep topology, step count, verb, file count, layer; tie-break → promote up a tier) then packs via First Fit Decreasing over dep-isolated, layer-grouped bins. Caps: 5 tasks/unit micro, 3/unit moderate, solo for complex, ≤60K context budget, ≤10 files/unit. Authoritative algorithm + signal definitions + Self-Audit merge criteria: see `proj-plan-writer` spec (`.claude/agents/proj-plan-writer.md`) — do NOT duplicate here. Parallel batches (no shared deps) may dispatch up to 3 concurrent per agent type.

### Anti-Hallucination
- Verify referenced files exist
- Every dispatch unit needs ONE concrete verification command
- Never plan changes to unread files
- Task sub-sections describe INTENT not method bodies (specialist owns implementation)
- Never pass a plan w/ Post-Dispatch Audit violations to the user — hard-fail after 2 failed loopbacks
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"PATCHED: {path}")
PY
```

### Step 5 — Regenerate `.claude/skills/execute-plan/SKILL.md`

Read-before-write: checks for `Pre-Flight Audit` marker; skips if already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/skills/execute-plan/SKILL.md"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        existing = f.read()
    if "Pre-Flight Audit" in existing:
        print(f"SKIP: {path} already patched")
        sys.exit(0)

content = '''---
name: execute-plan
description: >
  Use when you have a written plan and are ready to implement. Executes plan
  batch-by-batch with verification checkpoints. Mandatory /review at end.
argument-hint: "[plan-file-path]"
allowed-tools: Agent Read Write
model: opus
effort: high
# Skill Class: main-thread — batch dispatch orchestrator, interactive checkpoints
---

## /execute-plan — Plan Execution

## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.

## Dispatch Map
- Per-batch execution: agents named in each batch file header (dynamic — read `Agent:` field from batch file)
- Verification: `proj-verifier` (final full-suite run only; per-batch verification uses the single command in the batch header)
- Post-execution review: invoked via `/review` skill (which dispatches `proj-code-reviewer`)

**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `.claude/references/techniques/agent-design.md § Agent Dispatch Policy`.

### Steps
1. Read master plan from `.claude/specs/{branch}/` | ask user for path
2. Confirm plan w/ user — still correct?
3. **Pre-Flight Audit** (see below) — HARD REJECT on violation, do NOT proceed
4. Execute dispatch unit by dispatch unit in dep order (see Batch Dispatch Protocol)
5. Verify each batch — run the ONE verification command from batch header after agent returns; on fail → Batch Failure Handling
6. Checkpoint after each batch — print status, ask to continue
7. Final verification — full build + test suite
8. Invoke `/review` on all changed files — MANDATORY, not optional

### Pre-Flight Audit (MANDATORY — runs BEFORE any batch dispatch)

1. Glob `batch-*.md` under the plan directory. **No batch files found → HARD REJECT**: "Plan has no batch-*.md files. Legacy `task-NN-*.md` format removed (2026-04-11 packing enforcement). Re-run `/write-plan` to regenerate."
2. Parse each batch header: `Agent:`, `Layer:`, task count, `Dependency set:`
3. For every pair (Bi, Bj) apply the same merge criteria as `/write-plan` Post-Dispatch Audit:
   `same agent AND same layer AND disjoint dep_sets AND combined_tasks ≤5 AND combined_context <60K AND combined_files ≤10`
   (criteria definition lives in `proj-plan-writer` spec — single source of truth)
4. No violations → proceed to Batch Dispatch Protocol
5. **Violations found → HARD REJECT** (do NOT proceed, do NOT warn-and-continue). Print: "Plan violates packing enforcement. Unmerged batches: {list w/ pair + reason}. Re-run `/write-plan` to regenerate — packing must be resolved at plan-writer level, not execute-plan." Instruct user to re-run `/write-plan`.

Rationale: defense-in-depth w/ `/write-plan` Post-Dispatch Audit — catches plans from prior sessions or older agent versions. Consistency w/ `/write-plan` gate prevents silent 5× fan-out token waste. See packing enforcement spec for full reasoning.

### Batch Dispatch Protocol
- "Batch" here = dispatch unit (one Agent invocation executing 1-N ordered tasks), NOT a grouping of separate dispatches. One batch file → one Agent call.
- Read batch's `Agent:` + `Tier:` + `Verification:` fields from file header
- Dispatch agent named in batch header via `subagent_type="proj-{name}"`
- Pass batch file PATH (not task file paths, not inlined content) to the agent
- Agent runs all task sub-sections sequentially top-down in dep order within that single dispatch
- Agent runs the batch Verification command ONCE at end of batch (not per task)
- Independent batches (no shared deps): dispatch up to 3 concurrent per agent type in ONE message (parallel Agent calls). Code-writing batches sharing deps: SEQUENTIAL (each must leave build passing).
- Research/doc agent batches: parallel-safe by default

### Per-Batch Protocol (within one dispatch)
- **Read-before-write**: agent reads all rule files listed in batch header ONCE at batch start (deduped) + all files listed in the batch `Dependency set` header ONCE at batch start
- **MUST dispatch the agent named in the batch `Agent:` header field** — never execute inline, never substitute a different agent
- Specialist dispatch prompt MUST include: "Read `.claude/rules/code-standards-{lang}.md` + `.claude/rules/data-access.md` (if applicable) BEFORE writing any code. These rules override any code shown in task sub-sections."
- If task sub-section contains code snippets → treat as CONTRACT/HINT (signatures + intent), not MANDATE. Specialist applies domain rules + framework guardrails that plan-writer lacked.
- Agent executes task sub-sections top-down in dep order, then runs the batch verification command ONCE
- On success → agent returns PASS, checkpoint, next batch
- On verification fail → agent returns partial-success map (e.g. `NN.1 PASS, NN.2 FAIL, NN.3 NOT_RUN`) indicating which sub-task broke the batch — NOT just a single fail. Main thread handles via Batch Failure Handling below.

### Batch Failure Handling
- Agent partial-success map identifies failed + not-run sub-tasks
- Main thread re-dispatches each FAILED task SOLO (one Agent call per failed task, no re-batching on retry). Prevents retry amplification; gives each retry clean context.
- NOT_RUN tasks: re-dispatch SOLO in dep order after failed-task retries succeed
- Solo retry also fails → STOP, report to user, ask how to proceed (do NOT silently skip or continue past failing tasks)
- NEVER collapse multiple failed tasks back into one retry batch

### Plan Changes Mid-Execution
STOP → explain change + why → update plan file → get approval before continuing

### Post-Execution (MANDATORY)
1. Run `/review` on all changed files — DO NOT skip
2. Review finds issues → fix before proceeding
3. Only after review passes → tell user ready to `/commit`

NEVER say "ready to commit" without `/review` first.

### Anti-Hallucination
- Never claim batch PASS without reading the agent's returned partial-success map
- Never skip failed sub-tasks
- Never assume NOT_RUN tasks passed
- Verify every file claimed changed actually changed before `/review`
- Verify the plan file still matches current project state before executing
- Check that files listed in each task actually exist
- Task references code that has changed since plan written → stop and update plan
- Never bypass Pre-Flight Audit on a violating plan — hard-reject is mandatory, not advisory
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"PATCHED: {path}")
PY
```

### Step 6 — Update `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '012'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '012') or a == '012' for a in applied):
    applied.append({
        'id': '012',
        'applied_at': state['last_applied'],
        'description': 'plan-writer packing enforcement — regenerate proj-plan-writer + write-plan + execute-plan w/ Self-Audit step, Tier Classification Table, Post-Dispatch Audit gate (loopback ≤2), Pre-Flight Audit (hard reject), legacy task-NN-*.md format removed; write agent-scope-lock.md rule + retrofit into every proj-* agent STEP 0 block'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=012')
PY
```

### Rules for migration scripts

- **Read-before-write** — every patch step reads the target file, detects an existing marker (`Tier Classification Table`, `Post-Dispatch Audit`, `Pre-Flight Audit`), and only writes on change.
- **Idempotent** — re-running prints `SKIP: already patched` per file and `SKIP: migration 012 already applied` at the top.
- **Self-contained** — the new file content is inlined in python3 heredocs; no network fetch required. Safe to apply offline.
- **No gitignored-path fetch** — the migration never reads `.claude/` or `CLAUDE.md` from the bootstrap repo (those are gitignored there too). All new state owned inline.
- **No technique sync** — this migration modifies only agent + skill content. Technique files untouched → no risk of writing to the wrong path (bootstrap repo `techniques/*.md` vs client project `.claude/references/techniques/*.md`).
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on failure.
- **Scope lock** — touches only: `.claude/rules/agent-scope-lock.md` (new), `.claude/agents/proj-*.md` STEP 0 blocks (rule line injection), the three regenerated files (`proj-plan-writer.md`, `write-plan/SKILL.md`, `execute-plan/SKILL.md`), and `bootstrap-state.json`. No agent renames, no hook changes, no settings edits.

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. proj-plan-writer.md carries Tier Classification Table
if [[ -f ".claude/agents/proj-plan-writer.md" ]] && \
   grep -q "Tier Classification Table" .claude/agents/proj-plan-writer.md; then
  echo "PASS: proj-plan-writer.md contains Tier Classification Table"
else
  echo "FAIL: proj-plan-writer.md missing Tier Classification Table"
  fail=1
fi

# 2. proj-plan-writer.md carries Self-Audit step (Process step 10)
if [[ -f ".claude/agents/proj-plan-writer.md" ]] && \
   grep -q "Self-Audit" .claude/agents/proj-plan-writer.md; then
  echo "PASS: proj-plan-writer.md contains Self-Audit process step"
else
  echo "FAIL: proj-plan-writer.md missing Self-Audit"
  fail=1
fi

# 3. write-plan SKILL.md carries Post-Dispatch Audit
if [[ -f ".claude/skills/write-plan/SKILL.md" ]] && \
   grep -q "Post-Dispatch Audit" .claude/skills/write-plan/SKILL.md; then
  echo "PASS: write-plan/SKILL.md contains Post-Dispatch Audit"
else
  echo "FAIL: write-plan/SKILL.md missing Post-Dispatch Audit"
  fail=1
fi

# 4. execute-plan SKILL.md carries Pre-Flight Audit
if [[ -f ".claude/skills/execute-plan/SKILL.md" ]] && \
   grep -q "Pre-Flight Audit" .claude/skills/execute-plan/SKILL.md; then
  echo "PASS: execute-plan/SKILL.md contains Pre-Flight Audit"
else
  echo "FAIL: execute-plan/SKILL.md missing Pre-Flight Audit"
  fail=1
fi

# 5. execute-plan SKILL.md no longer carries Format Auto-Detection or Legacy Per-Task Protocol
if [[ -f ".claude/skills/execute-plan/SKILL.md" ]] && \
   ! grep -q "Format Auto-Detection\|Format auto-detection" .claude/skills/execute-plan/SKILL.md && \
   ! grep -q "Legacy Per-Task Protocol" .claude/skills/execute-plan/SKILL.md; then
  echo "PASS: execute-plan/SKILL.md legacy format sections removed"
else
  echo "FAIL: execute-plan/SKILL.md still contains legacy format sections"
  fail=1
fi

# 6. agent-scope-lock.md rule file present
if [[ -f ".claude/rules/agent-scope-lock.md" ]] && grep -q '^# Agent Scope Lock' .claude/rules/agent-scope-lock.md; then
  echo "PASS: .claude/rules/agent-scope-lock.md present"
else
  echo "FAIL: .claude/rules/agent-scope-lock.md missing or lacks header"
  fail=1
fi

# 7. At least one retrofitted sub-agent carries the agent-scope-lock.md line in its STEP 0 block
retrofitted=0
for agent in .claude/agents/proj-*.md; do
  [[ -f "$agent" ]] || continue
  case "$agent" in
    *references/*) continue ;;
  esac
  if grep -q 'agent-scope-lock.md' "$agent"; then
    retrofitted=$((retrofitted + 1))
  fi
done
if [[ "$retrofitted" -gt 0 ]]; then
  echo "PASS: $retrofitted sub-agent(s) carry agent-scope-lock.md line"
else
  echo "FAIL: no sub-agent carries agent-scope-lock.md line"
  fail=1
fi

# 8. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "012" ]]; then
  echo "PASS: last_migration = 012"
else
  echo "FAIL: last_migration = $last (expected 012)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 012 verification: ALL PASS"
else
  echo "Migration 012 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"012"`
- append `{ "id": "012", "applied_at": "<ISO8601>", "description": "plan-writer packing enforcement — regenerate proj-plan-writer + write-plan + execute-plan w/ Self-Audit step, Tier Classification Table, Post-Dispatch Audit gate (loopback ≤2), Pre-Flight Audit (hard reject), legacy task-NN-*.md format removed" }` to `applied[]`

---

## Rollback

Restore the three regenerated files from version control or companion-repo snapshot:

```bash
#!/usr/bin/env bash
# Tracked strategy (files committed to project repo)
git checkout -- \
  .claude/agents/ \
  .claude/rules/agent-scope-lock.md \
  .claude/skills/write-plan/SKILL.md \
  .claude/skills/execute-plan/SKILL.md
# If agent-scope-lock.md was untracked pre-migration, remove it:
# rm -f .claude/rules/agent-scope-lock.md

# Companion strategy — restore from companion repo snapshot
# cp ~/.claude-configs/<project>/.claude/agents/proj-plan-writer.md ./.claude/agents/
# cp ~/.claude-configs/<project>/.claude/skills/write-plan/SKILL.md ./.claude/skills/write-plan/
# cp ~/.claude-configs/<project>/.claude/skills/execute-plan/SKILL.md ./.claude/skills/execute-plan/
# cp -r ~/.claude-configs/<project>/.claude/agents/ ./.claude/
```

Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"011"` and remove the `012` entry from `applied[]`.

The migration is a full-file regeneration of three targets. Rollback via `git checkout` is safe provided the files were tracked before apply. In-flight plan files in `.claude/specs/` are unaffected by apply or rollback — Pre-Flight Audit only runs on execute-plan invocation, not at migration time.

---

## Breaking-Change Note

This migration removes the legacy `task-NN-*.md` plan format. Any existing plan files using `task-NN-*.md` (one task per file) will be hard-rejected by the new `/execute-plan` Pre-Flight Audit. Workaround: re-run `/write-plan` on the original spec to regenerate as `batch-NN-*.md`. Per packing-enforcement spec open question 5, retroactive fixup of existing plans is explicitly out-of-scope — the new enforcement only applies to new `/write-plan` runs. One legacy plan existed at 2026-04-11 (the dispatch-unit-batching plan itself) + was already executed, so this is not expected to affect live work.
