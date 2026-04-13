---
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
0. **TaskCreate gate** (TASKCREATE_GATE_BLOCK — makes the execute-plan run observable in the harness task list).
   Run `ToolSearch("select:TaskCreate,TaskUpdate")` to load the TaskCreate / TaskUpdate schemas on demand.
   If the ToolSearch returns matching tools:
     - Call `TaskCreate(subject=f"execute-plan: {plan-basename}", description=f"Execute plan {plan-path} — {batch-count} batches")` where `{plan-basename}` = the plan filename without directory, `{plan-path}` = the full path passed as argument (resolved from `.claude/specs/{branch}/` or user reply), `{batch-count}` = number of `batch-*.md` files discovered during Pre-Flight Audit Step 1 (if Pre-Flight Audit has not yet run, glob the batch files now to compute the count — this is safe: Pre-Flight Audit also runs this glob).
     - Then call `TaskUpdate(taskId=<returned-id>, status="in_progress")`.
     - Remember the returned taskId in conversation state for the remainder of this skill run — referenced again in `### Post-Execution (MANDATORY)` step 4.
     - Set `TASK_TRACKING=true`.
   If ToolSearch returns no schemas OR TaskCreate raises InputValidationError:
     - Set `TASK_TRACKING=false`.
     - Print one warning line: `TaskCreate unavailable — continuing without harness task tracking`.
     - Continue to step 1 without creating any task entry.
   Do NOT fail the skill run on ToolSearch failure; the gate is observability, not a blocker.
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
4. **TaskCreate closeout** (TASKCREATE_GATE_BLOCK step 3/4):
   If `TASK_TRACKING=true` (set in Steps step 0):
     - On successful completion (all batches passed, `/review` clean, user told "ready to commit"):
       Call `TaskUpdate(taskId=<id>, status="completed")`. The harness task list closes the entry.
     - On abort / error / user-cancel / hard-fail (any batch fails solo retry, Pre-Flight Audit hard-rejects, user stops the run mid-batch, or `/review` surfaces issues that block progress):
       Call `TaskUpdate(taskId=<id>, status="in_progress", description=<original-description> + "\n\nBLOCKED: {reason}")`
       where `{reason}` is a one-sentence description of the failure (e.g. `"batch-03 sub-task 03.2 failed solo retry — SCOPE EXPANSION"`, `"user cancelled after batch-02 checkpoint"`, `"Pre-Flight Audit rejected plan: unmerged batches 01+02"`). Do NOT mark the task `completed` on abort — leaving it `in_progress` with a BLOCKED suffix surfaces the failure in the harness task list instead of silently closing it.
   If `TASK_TRACKING=false` → skip this step entirely (no task entry exists to close).

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
