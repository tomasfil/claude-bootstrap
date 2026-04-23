---
name: write-plan
description: >
  Use when you have requirements or a spec and need to break them into
  concrete implementation steps. Creates plan with dispatch batching.
  Use after /brainstorm or when starting from a clear spec. Dispatches proj-plan-writer.
argument-hint: "[spec-file-path]"
allowed-tools: Agent Read Write
model: opus
effort: xhigh
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
For any code exploration inside this skill: dispatch `proj-quick-check` (simple) | `proj-researcher` (deep). Read directly ONLY for known exact path (Tier 1 per main-thread-orchestrator.md). MCP-indexed projects: named-symbol lookups MUST go through cmm.search_graph (see mcp-routing.md). Never built-in `Explore` / `general-purpose` / plugin.
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
