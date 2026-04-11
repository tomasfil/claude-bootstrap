# Migration 010 — Plan-writer dispatch-unit batching

> Regenerate `.claude/agents/proj-plan-writer.md`, `.claude/skills/write-plan/SKILL.md`, and `.claude/skills/execute-plan/SKILL.md` with Tier Classification, Dispatch Unit Packing (FFD), batch-file output format, Per-Batch Protocol, and Batch Failure Handling. Fixes one-task-per-dispatch overhead on micro-task plans while preserving legacy task-file executor compat.

---

## Metadata

```yaml
id: "010"
breaking: false
affects: [agents, skills]
requires_mcp_json: false
min_bootstrap_version: "6.0"
```

---

## Problem

Plan-writer emits `task-NN-*.md` files one-per-task and `/execute-plan` dispatches one Agent call per task file. For plans full of 1-3 step micro tasks (e.g. markdown edits, enum additions, small refactors) this produces massive per-dispatch overhead — each dispatch spins up a fresh subagent, reloads rule files, re-primes context, runs verification — for a handful of tool calls of real work.

Fix: plan-writer now classifies every task by 5 intent-level signals (dep topology, step count, verb category, file count, layer) then packs tasks into **dispatch units** via First Fit Decreasing over dep-isolated, layer-grouped bins. Each dispatch unit = one Agent call executing 1-N ordered tasks back-to-back w/ a single end-of-batch verification command. Output format shifts from `task-NN-*.md` (one task per file) to `batch-NN-{summary}.md` (1-N ordered tasks per file). `/execute-plan` auto-detects the format: batch files present → new Per-Batch Protocol; legacy `task-NN-*.md` only → fall back to one-task-per-dispatch.

Full brainstorm + approach: see the `plan-writer-dispatch-unit-batching` spec in the bootstrap repo (`modules/05-core-agents.md` § Dispatch 2, `modules/06-skills.md` § Dispatch 16 + 17).

---

## Changes

1. Regenerates `.claude/agents/proj-plan-writer.md` — adds Tier Classification (5 signals), Dispatch Unit Packing (FFD algorithm), context budget estimator, parallel-batch rule, batch-file output format, per-dispatch-unit verification, retry policy, stricter task-file discipline.
2. Regenerates `.claude/skills/write-plan/SKILL.md` — new Batch File Format section, updated steps to write `batch-NN-*.md` under `{plan-dir}/`, batching rules reference pointing at agent spec (no duplication), legacy task file format noted as accepted but no longer emitted.
3. Regenerates `.claude/skills/execute-plan/SKILL.md` — adds Format Auto-Detection (glob batch files first, fall back to task files), Batch Dispatch Protocol (one Agent call per batch file, parallel up to 3 per agent type when independent), Per-Batch Protocol (read-once rule files, sequential task execution, single end-of-batch verification), Batch Failure Handling (partial-success maps, solo retries, no retry re-batching), Legacy Per-Task Protocol retained for backward compat.
4. Advances `.claude/bootstrap-state.json` → `last_migration: "010"`.

Idempotent: re-run detects marker headings (`Tier Classification`, `Per-Batch Protocol`) and prints `SKIP: already patched`. Additive only — pre-existing task-format plans in `.claude/specs/` continue to execute under legacy protocol unmodified.

---

## Actions

### Prerequisites

```bash
#!/usr/bin/env bash
set -euo pipefail

[[ -f ".claude/bootstrap-state.json" ]] || { echo "ERROR: not a bootstrapped project — run full bootstrap first"; exit 1; }
[[ -d ".claude/agents" ]] || { echo "ERROR: no .claude/agents directory"; exit 1; }
[[ -d ".claude/skills" ]] || { echo "ERROR: no .claude/skills directory"; exit 1; }
[[ -d ".claude/skills/write-plan" ]] || { echo "ERROR: .claude/skills/write-plan missing — cannot migrate"; exit 1; }
[[ -d ".claude/skills/execute-plan" ]] || { echo "ERROR: .claude/skills/execute-plan missing — cannot migrate"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required"; exit 1; }
```

### Idempotency check

```bash
#!/usr/bin/env bash
set -euo pipefail

agent_patched=0
write_patched=0
execute_patched=0

if [[ -f ".claude/agents/proj-plan-writer.md" ]] && \
   grep -q "Tier Classification" .claude/agents/proj-plan-writer.md && \
   grep -q "Dispatch Unit Packing" .claude/agents/proj-plan-writer.md; then
  agent_patched=1
fi

if [[ -f ".claude/skills/write-plan/SKILL.md" ]] && \
   grep -q "Batch file format\|Batch File Format" .claude/skills/write-plan/SKILL.md; then
  write_patched=1
fi

if [[ -f ".claude/skills/execute-plan/SKILL.md" ]] && \
   grep -q "Per-Batch Protocol" .claude/skills/execute-plan/SKILL.md && \
   grep -q "Batch Failure Handling" .claude/skills/execute-plan/SKILL.md; then
  execute_patched=1
fi

if [[ "$agent_patched" -eq 1 && "$write_patched" -eq 1 && "$execute_patched" -eq 1 ]]; then
  echo "SKIP: migration 010 already applied (all three targets carry new markers)"
  exit 0
fi

echo "Applying migration 010: agent_patched=$agent_patched write_patched=$write_patched execute_patched=$execute_patched"
```

### Step 1 — Regenerate `.claude/agents/proj-plan-writer.md`

Read-before-write: checks for `Tier Classification` marker; skips if already present. Writes the full updated agent file via python3 heredoc (owns new state). The new content mirrors `modules/05-core-agents.md` § Dispatch 2 (after task-01 of the dispatch-unit-batching plan).

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/agents/proj-plan-writer.md"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        existing = f.read()
    if "Tier Classification" in existing and "Dispatch Unit Packing" in existing:
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

## Role
Senior architect — analyze specs + codebases → tier-classified, dep-ordered dispatch units (one agent invocation per unit executes N ordered tasks back-to-back).

## Reframe
Dispatch unit = execution primitive (one Agent call); task = planning primitive. A batch file carries 1-N ordered tasks the same agent runs sequentially, verifying once at the end. Ordering is preserved INSIDE a batch (dep-ordered top-down); batching is governed by tier + dep_set intersection, NOT agent type alone.

## Pass-by-Reference Contract
Write master plan to `.claude/specs/{branch}/{date}-{topic}-plan.md`.
Emit one `batch-NN-{summary}.md` per dispatch unit under `.claude/specs/{branch}/{date}-{topic}-plan/` (each batch holds 1-N ordered tasks). Legacy `task-NN-*.md` layout still accepted for executor back-compat but `batch-NN-*.md` is the preferred output.
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
8. Write master plan (index + execution order + dependency graph + Dispatch Plan)
9. Write batch files (one per dispatch unit) — self-contained w/ all context the executing agent needs (rule files to read once, file paths, per-task sections, batch verification command)

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

## Output Format — Batch Files (preferred)
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
- **ALLOWED:** signatures (`public async Task<X> Foo(Y y, CancellationToken ct)`), interface additions (`add byte[] GenerateCsvTemplate();` to IFoo), file paths, data shapes (`record Bar(int Id, string Name)`), step prose
- **Rationale:** specialist reads `.claude/rules/code-standards-{lang}.md` + framework rules. Plan-writer cannot. Pre-written bodies bypass specialist guardrails.
- **Size cap:** each individual Task sub-section ≤60 lines (hard warn at >80). Batch file as a whole ≤200 lines. If task needs more → split into sub-tasks or let specialist decide.
- **NEVER copy rule file content** into task sections. Reference path: `specialist MUST read .claude/rules/code-standards-csharp.md before writing`.
- **Good:** "Add `ReadAsync(byte[], Action<T>?, CT)` that sniffs PK magic bytes → dispatches to ReadExcelAsync or ReadCsvAsync".
- **Bad:** 30-line fenced C# block showing the byte check + if/else + delegation.

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

### Step 2 — Regenerate `.claude/skills/write-plan/SKILL.md`

Read-before-write: checks for `Batch file format` marker; skips if already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/skills/write-plan/SKILL.md"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        existing = f.read()
    if "Batch file format" in existing or "Batch File Format" in existing:
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
See `techniques/agent-design.md § Agent Dispatch Policy`.

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

### Plan-writer Produces
- **Master plan** = index + execution order + dependency graph + Dispatch Plan + Batch Index
- **Batch files** = self-contained dispatch units, agent gets ONLY its batch file as context. One batch file per dispatch unit; holds 1-N ordered tasks the same agent runs sequentially, verifying once at end. Batch files are the preferred output.
- **Legacy task files** (`task-NN-*.md`, one task per dispatch) still accepted by `/execute-plan` for backward compat but no longer emitted by default.

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

### Legacy Task File Format
Still accepted, no longer emitted. `task-NN-{title}.md` w/ single Task section (Files / Depends on / Verification / Agent / Batch / Steps). `/execute-plan` auto-detects and falls back to one-task-per-dispatch.

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
Plan-writer classifies each task by 5 signals (dep topology, step count, verb, file count, layer; tie-break → promote up a tier) then packs via First Fit Decreasing over dep-isolated, layer-grouped bins. Caps: 5 tasks/unit micro, 3/unit moderate, solo for complex, ≤60K context budget, ≤10 files/unit. Authoritative algorithm + signal definitions: see `proj-plan-writer` spec (`.claude/agents/proj-plan-writer.md`) — do NOT duplicate here. Parallel batches (no shared deps) may dispatch up to 3 concurrent per agent type.

### Anti-Hallucination
- Verify referenced files exist
- Every dispatch unit needs ONE concrete verification command
- Never plan changes to unread files
- Task sub-sections describe INTENT not method bodies (specialist owns implementation)
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"PATCHED: {path}")
PY
```

### Step 3 — Regenerate `.claude/skills/execute-plan/SKILL.md`

Read-before-write: checks for `Per-Batch Protocol` + `Batch Failure Handling`; skips if already present.

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import os, sys

path = ".claude/skills/execute-plan/SKILL.md"

if os.path.isfile(path):
    with open(path, "r", encoding="utf-8") as f:
        existing = f.read()
    if "Per-Batch Protocol" in existing and "Batch Failure Handling" in existing:
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
See `techniques/agent-design.md § Agent Dispatch Policy`.

### Steps
1. Read master plan from `.claude/specs/{branch}/` | ask user for path
2. Confirm plan w/ user — still correct?
3. Detect plan format (see Format Auto-Detection below)
4. Execute dispatch unit by dispatch unit in dep order (see Batch Dispatch Protocol)
5. Verify each batch — run the ONE verification command from batch header after agent returns; on fail → Batch Failure Handling
6. Checkpoint after each batch — print status, ask to continue
7. Final verification — full build + test suite
8. Invoke `/review` on all changed files — MANDATORY, not optional

### Format Auto-Detection (backward compat)
- Glob `.claude/specs/{branch}/{plan-dir}/batch-NN-*.md` first
- Files present → NEW protocol: each file = one dispatch unit of 1-N tasks
- None found → glob `task-NN-*.md` → LEGACY protocol: each file = single task, one-task-per-dispatch, old per-task semantics
- Mixed (both present) → prefer batch files, warn user

### Batch Dispatch Protocol (NEW format)
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

### Legacy Per-Task Protocol (only when format detection → `task-NN-*.md`)
- One agent dispatch per task file, verification runs per-task
- Otherwise same rules: read-before-write, MUST dispatch agent from `Agent:` field, specialist code-standards reminder mandatory, fix+retry once on fail → ask user

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
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print(f"PATCHED: {path}")
PY
```

### Step 4 — Update `.claude/bootstrap-state.json`

```bash
#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import json, datetime
with open('.claude/bootstrap-state.json') as f:
    state = json.load(f)
state['last_migration'] = '010'
state['last_applied'] = datetime.datetime.utcnow().isoformat() + 'Z'
applied = state.setdefault('applied', [])
if not any((isinstance(a, dict) and a.get('id') == '010') or a == '010' for a in applied):
    applied.append({
        'id': '010',
        'applied_at': state['last_applied'],
        'description': 'plan-writer dispatch-unit batching — regenerate proj-plan-writer + write-plan + execute-plan w/ Tier Classification, Dispatch Unit Packing (FFD), batch-file format, Per-Batch Protocol, Batch Failure Handling'
    })
with open('.claude/bootstrap-state.json', 'w') as f:
    json.dump(state, f, indent=2)
print('State updated: last_migration=010')
PY
```

### Rules for migration scripts

- **Read-before-write** — every patch step reads the target file, detects an existing marker (`Tier Classification`, `Batch file format`, `Per-Batch Protocol`), and only writes on change.
- **Idempotent** — re-running prints `SKIP: already patched` per file and `SKIP: migration 010 already applied` at the top.
- **Self-contained** — the new file content is inlined in python3 heredocs; no network fetch required. Safe to apply offline.
- **No gitignored-path fetch** — the migration never reads `.claude/` or `CLAUDE.md` from the bootstrap repo (those are gitignored there too). All new state owned inline.
- **Abort on error** — `set -euo pipefail` in every bash block; python3 blocks exit non-zero on failure.
- **Scope lock** — touches only the three named files + `bootstrap-state.json`. No agent renames, no technique re-sync, no hook changes, no settings edits.

---

## Verify

```bash
#!/usr/bin/env bash
set +e
fail=0

# 1. proj-plan-writer.md carries Tier Classification + Dispatch Unit Packing
if [[ -f ".claude/agents/proj-plan-writer.md" ]] && \
   grep -q "Tier Classification" .claude/agents/proj-plan-writer.md && \
   grep -q "Dispatch Unit Packing" .claude/agents/proj-plan-writer.md; then
  echo "PASS: proj-plan-writer.md contains Tier Classification + Dispatch Unit Packing"
else
  echo "FAIL: proj-plan-writer.md missing Tier Classification or Dispatch Unit Packing"
  fail=1
fi

# 2. write-plan SKILL.md carries Batch File Format
if [[ -f ".claude/skills/write-plan/SKILL.md" ]] && \
   grep -q "Batch File Format\|Batch file format" .claude/skills/write-plan/SKILL.md; then
  echo "PASS: write-plan/SKILL.md contains Batch File Format"
else
  echo "FAIL: write-plan/SKILL.md missing Batch File Format section"
  fail=1
fi

# 3. execute-plan SKILL.md carries Per-Batch Protocol + Batch Failure Handling
if [[ -f ".claude/skills/execute-plan/SKILL.md" ]] && \
   grep -q "Per-Batch Protocol" .claude/skills/execute-plan/SKILL.md && \
   grep -q "Batch Failure Handling" .claude/skills/execute-plan/SKILL.md; then
  echo "PASS: execute-plan/SKILL.md contains Per-Batch Protocol + Batch Failure Handling"
else
  echo "FAIL: execute-plan/SKILL.md missing Per-Batch Protocol or Batch Failure Handling"
  fail=1
fi

# 4. execute-plan SKILL.md carries Format Auto-Detection (backward compat guard)
if [[ -f ".claude/skills/execute-plan/SKILL.md" ]] && \
   grep -q "Format Auto-Detection\|Format auto-detection" .claude/skills/execute-plan/SKILL.md; then
  echo "PASS: execute-plan/SKILL.md contains Format Auto-Detection"
else
  echo "FAIL: execute-plan/SKILL.md missing Format Auto-Detection"
  fail=1
fi

# 5. bootstrap-state.json updated
last=$(python3 -c "import json; print(json.load(open('.claude/bootstrap-state.json'))['last_migration'])" 2>/dev/null)
if [[ "$last" == "010" ]]; then
  echo "PASS: last_migration = 010"
else
  echo "FAIL: last_migration = $last (expected 010)"
  fail=1
fi

echo "---"
if [[ $fail -eq 0 ]]; then
  echo "Migration 010 verification: ALL PASS"
else
  echo "Migration 010 verification: FAILURES — state NOT updated"
  exit 1
fi
```

Any failure → `/migrate-bootstrap` aborts + does NOT update `bootstrap-state.json`. Safe to retry after manual fix.

---

## State Update

On success:
- `last_migration` → `"010"`
- append `{ "id": "010", "applied_at": "<ISO8601>", "description": "plan-writer dispatch-unit batching — regenerate proj-plan-writer + write-plan + execute-plan w/ Tier Classification, Dispatch Unit Packing (FFD), batch-file format, Per-Batch Protocol, Batch Failure Handling" }` to `applied[]`

---

## Rollback

Restore the three regenerated files from version control or companion-repo snapshot:

```bash
#!/usr/bin/env bash
# Tracked strategy (files committed to project repo)
git checkout -- \
  .claude/agents/proj-plan-writer.md \
  .claude/skills/write-plan/SKILL.md \
  .claude/skills/execute-plan/SKILL.md

# Companion strategy — restore from companion repo snapshot
# cp ~/.claude-configs/<project>/.claude/agents/proj-plan-writer.md ./.claude/agents/
# cp ~/.claude-configs/<project>/.claude/skills/write-plan/SKILL.md ./.claude/skills/write-plan/
# cp ~/.claude-configs/<project>/.claude/skills/execute-plan/SKILL.md ./.claude/skills/execute-plan/
```

Then manually reset `last_migration` in `.claude/bootstrap-state.json` to `"009"` and remove the `010` entry from `applied[]`.

The migration is a full-file regeneration of three targets. Rollback via `git checkout` is safe provided the files were tracked before apply. Legacy `task-NN-*.md` plan files in `.claude/specs/` are unaffected by apply or rollback — `/execute-plan` retains the legacy per-task protocol path at all times.
