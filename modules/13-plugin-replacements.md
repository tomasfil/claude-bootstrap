# Module 13 — Plugin Replacement Skills

> Generate project-specific skills that replace generic methodology plugins.
> Each replacement is tailored to the project's actual frameworks, commands, and conventions.

---

## Idempotency

Per skill: if it exists, READ it to extract project-specific content, then REGENERATE
with that content PLUS all required sections from the current template. Skills from a
previous bootstrap version are upgraded, not preserved as-is.

## Skill Frontmatter Reference

All skills support these fields. Use what's relevant — omit fields that don't apply:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name and `/slash-command` identifier |
| `description` | Recommended | Trigger description — "Use when..." |
| `argument-hint` | No | Autocomplete hint (e.g., `[filename]`) |
| `allowed-tools` | No | Tools allowed without permission prompts |
| `model` | No | Model override: `haiku`, `sonnet`, `opus` |
| `effort` | No | Effort level: `low`, `medium`, `high`, `max` |
| `context` | No | `fork` runs skill in isolated subagent context |
| `agent` | No | Subagent type when `context: fork` |
| `paths` | No | Glob patterns for auto-activation |

**Key patterns:**
- Orchestrator skills (dispatch agents): use `context: fork` to keep main context clean
- Skills are folders (`SKILL.md` + `references/`) — use progressive disclosure
- Add a `### Gotchas` section to every skill — highest-signal content, accumulates over time

## Create Skills

Generate each skill below. Adapt templates using discovery context from Module 01.
Apply RCCF framework and anti-hallucination patterns from `techniques/`.

### 1. /brainstorm (replaces superpowers:brainstorming)

```bash
mkdir -p .claude/skills/brainstorm
```

`.claude/skills/brainstorm/SKILL.md`:
```yaml
---
name: brainstorm
description: >
  Explore and design features before implementing. Use when asked to design,
  plan, explore, or think through a feature, component, or change. Always
  brainstorm before implementing anything non-trivial.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Grep, Glob, Skill, Write
model: opus
effort: high
---
```
```markdown
## /brainstorm — Design Before Build

1. Clarify request — one question per message, prefer multiple choice
2. Explore context — read relevant files + architecture
3. Propose 2-3 approaches w/ trade-offs + recommendation
4. Present section by section — get approval after each
5. Save → `.claude/specs/{date}-{topic}.md`
   Specs → .claude/specs/ MUST use compressed telegraphic notation
6. Transition → invoke /write-plan

### Knowledge Base
Read `.claude/references/techniques/INDEX.md` (if exists) → decide relevant technique files. Starting-point knowledge, not definitive; skip if unrelated to architecture/prompt-engineering.

DO NOT write code until user approves design.
```

### 2. /write-plan (replaces superpowers:writing-plans)

```bash
mkdir -p .claude/skills/write-plan
```

`.claude/skills/write-plan/SKILL.md`:
```yaml
---
name: write-plan
description: >
  Create a detailed implementation plan from a design or spec. Use after
  brainstorming, when you have requirements and need to break them into
  concrete implementation steps.
argument-hint: "[spec-file-path]"
allowed-tools: Agent, Read, Write, Grep, Glob
model: opus
effort: medium
---
```
```markdown
## /write-plan — Implementation Planning

1. Read spec from `.claude/specs/` | conversation context
2. Read `.claude/skills/code-write/references/pipeline-traces.md` if exists
3. Break into tasks — each independently completable + verifiable
4. Order by dependency: data → API → UI
5. Assign verification command per task
6. Compute dispatch batches (see Batching below)
7. Save → `.claude/specs/{date}-{topic}-plan.md`
   Plans → .claude/specs/ MUST use compressed telegraphic notation

### Batching (token + turn efficiency)
Group tasks into dispatch batches:
- Same `Agent:` field → batch candidate
- Inter-task dependency blocks batching (B depends on A → different batches)
- Related scope (same subsystem | same file-type) preferred within batch
- Batch = single agent dispatch w/ merged prompt listing all task details
- Parallel batches (no inter-batch deps) → dispatch in ONE message (multiple Agent calls)

Output `### Dispatch Plan` section BEFORE task list:
```
### Dispatch Plan
- **Batch 1** (agent: {name}) — Tasks: 1,2,3. Depends on: none. Parallel w/: Batch 2.
- **Batch 2** (agent: {name}) — Tasks: 4. Depends on: none. Parallel w/: Batch 1.
- **Batch 3** (agent: {name}) — Tasks: 5. Depends on: Batch 1,2. Parallel w/: none.
```

### Task Format
```
## Task {N}: {title}
Files: {list of files to create/modify}
Depends on: {task numbers}
Verification: {build/test command}
Agent: {which specialist handles this — or "main"}
Batch: {batch-id}

### Steps
1. {step}
2. {step}
```

### Anti-Hallucination
- Verify referenced files exist before including in plan
- Every task needs concrete verification command
- Never plan changes to unread files
```

### 3. /execute-plan (replaces superpowers:executing-plans)

```bash
mkdir -p .claude/skills/execute-plan
```

`.claude/skills/execute-plan/SKILL.md`:
```yaml
---
name: execute-plan
description: >
  Execute a written implementation plan with review checkpoints. Use when
  you have a plan file and are ready to start implementing.
argument-hint: "[plan-file-path]"
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob, Skill
model: opus
effort: high
---
```
```markdown
## /execute-plan — Plan Execution

0. TaskCreate for each task in the plan before starting execution
1. Read plan from `.claude/specs/` | ask user for path
2. Confirm plan w/ user — still correct?
3. Execute batch by batch in dependency order (see Batch Dispatch Protocol below)
4. Verify each task — run verification command after completion
5. Checkpoint after each batch — print status, ask to continue
6. Final verification — full build + test suite
7. Invoke `/review` on all changed files — mandatory, not optional

### Batch Dispatch Protocol
- Read batch's tasks from Dispatch Plan
- Single agent call per batch w/ merged prompt: include ALL batch's tasks w/ full details (files, steps, verification)
- Parallel batches (no inter-batch deps) → dispatch as multiple Agent calls in ONE message
- Sequential batches → complete batch N, verify, then dispatch batch N+1
- Agent reports per-task status — verify each before marking batch complete
- TaskUpdate each task in batch as tasks complete

### Per-Task Protocol (within batch)
- Read-before-write: read all files in task's file list first
- MUST dispatch agent specified in `Agent:` field — never execute inline if agent specified
- Execute steps in order → run verification → fix + retry once on fail → ask user
- Mark complete → next task

### Plan Changes Mid-Execution
Stop → explain change + why → update plan file → get approval before continuing

### Post-Execution (mandatory)
1. Run `/review` on all changed files — DO NOT skip
2. Review finds issues → fix before proceeding
3. Only after review passes → tell user ready to `/commit`

NEVER say "ready to commit" without /review first.
```

### 4. /tdd (replaces superpowers:test-driven-development)

```bash
mkdir -p .claude/skills/tdd
```

`.claude/skills/tdd/SKILL.md`:
```yaml
---
name: tdd
description: >
  Test-driven development. Use when implementing a feature or bugfix where
  writing tests first would improve confidence. Red-green-refactor cycle.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
model: opus
effort: high
---
```
```markdown
## /tdd — Red-Green-Refactor

0. TaskCreate per RED-GREEN-REFACTOR cycle before starting

### RED — Failing Test
1. Read existing tests → match conventions (naming, structure, assertions)
2. Write test describing expected behavior
3. Run `{test_single_command}` — must FAIL
4. Passes → not testing new behavior, rethink

### GREEN — Minimal Pass
1. Read-before-write: understand codebase context
2. Write minimum code to pass test
3. Run `{test_single_command}` — must PASS
4. Fails → fix implementation, not test

### REFACTOR — Clean Up
1. Find duplication, unclear names, excess complexity
2. Refactor w/ tests green
3. Run tests after each refactoring step

Repeat per behavior/scenario.
```

### 5. /debug (replaces superpowers:systematic-debugging)

```bash
mkdir -p .claude/skills/debug
```

`.claude/skills/debug/SKILL.md`:
```yaml
---
name: debug
description: >
  Systematic debugging. Use when encountering a bug, test failure, or unexpected
  behavior. Investigates root cause before proposing fixes.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
model: opus
effort: high
---
```
```markdown
## /debug — Systematic Investigation

0. TaskCreate per debug phase (Reproduce → Locate → Diagnose → Fix)

### Phase 1: Reproduce
1. Identify symptom — expected vs actual behavior
2. Find minimal reproduction (test | command | input)
3. Run + capture EXACT error output

### Phase 2: Locate
1. Read error message — file, line, error type
2. Trace call stack via goToDefinition / findReferences / Grep
3. Identify exact divergence point
4. Read surrounding code for context

### Phase 3: Diagnose
1. Why does this line produce wrong result?
2. Which assumption violated?
3. Classify: logic | data | environment | timing error
4. Check `.learnings/log.md` — seen before?

### Phase 4: Fix
1. Write test reproducing bug (TDD red phase)
2. Fix root cause, not symptom
3. Run test → confirm pass
4. Run surrounding tests → confirm no regression
5. Log to `.learnings/log.md` if pattern

### Anti-Hallucination
- DO NOT propose fix before Phase 2 (Locate) complete
- DO NOT guess root cause — trace actual execution
- After 2 failed fix attempts → search web for known issues
```

### 6. /verify (replaces superpowers:verification-before-completion)

```bash
mkdir -p .claude/skills/verify
```

`.claude/skills/verify/SKILL.md`:
```yaml
---
name: verify
description: >
  Verify work is complete before claiming done. Use before committing, creating
  PRs, or telling the user that work is finished. Runs build, tests, and checks.
allowed-tools: Agent, Read, Bash, Grep, Glob
model: sonnet
effort: medium
---
```
```markdown
## /verify — Pre-Completion Checklist

Run ALL — never claim completion until all pass.

1. Build: `{build_command}` — zero errors
2. Lint: `{lint_command}` — pass (if applicable)
3. Tests: `{test_suite_command}` — minimum: tests related to changes
4. `git diff` — scan for accidental changes, debug code, TODOs
5. Common issues:
   - [ ] No hardcoded secrets/credentials
   - [ ] No console.log/print statements
   - [ ] No commented-out code
   - [ ] New files follow naming conventions
   - [ ] Pipeline trace complete (if multi-layer change)

### Report
```
Verification: {PASS / FAIL}
Build: {pass/fail}
Lint: {pass/fail/N/A}
Tests: {N passed, M failed}
Issues found: {list or "none"}
```

ANY check fails → fix before claiming done.
```

### 7. /commit (replaces commit-commands)

```bash
mkdir -p .claude/skills/commit
```

`.claude/skills/commit/SKILL.md`:
```yaml
---
name: commit
description: >
  Commit changes with project conventions. Use when asked to commit, save
  changes, or after completing a task that should be committed.
allowed-tools: Agent, Read, Bash, Grep, Glob
model: sonnet
effort: medium
---
```
```markdown
## /commit — Project-Aware Commit

> Assumes /review + /verify already ran per CLAUDE.md automation. Do not embed verify/review here.

1. `git status` — see changes
2. `git diff --staged` + `git diff` — understand changes
3. `git log --oneline -5` — match message style
4. Draft message:
   - Conventional commits: `type(scope): description`
   - Types: feat | fix | refactor | test | docs | chore | style
   - Subject < 72 chars; body explains WHY, not WHAT
5. Stage specific files (not `git add .`)
6. Create commit
7. If git_strategy = "companion" → export to companion repo

### DO NOT commit:
- .env, credentials, secrets
- Large binaries
- Unrelated changes (split into separate commits)
```

### 8. /pr (replaces pr-review-toolkit)

```bash
mkdir -p .claude/skills/pr
```

`.claude/skills/pr/SKILL.md`:
```yaml
---
name: pr
description: >
  Create a pull request with project template. Use when asked to create a PR,
  submit changes for review, or after finishing a feature branch.
allowed-tools: Read, Bash, Grep, Glob
model: sonnet
effort: medium
---
```
```markdown
## /pr — Create Pull Request

1. `git status` + `git log main..HEAD` — understand all changes
2. Draft PR: title < 70 chars; body = summary bullets + test plan + migration notes
3. Push if needed: `git push -u origin {branch}`
4. `gh pr create --title "..." --body "..."`
5. Return PR URL

### PR Body Template
```
## Summary
- {1-3 bullet points describing what changed and why}

## Test Plan
- [ ] {how to verify this works}

## Notes
- {migration steps, breaking changes, or "none"}
```
```

### 9. /review (replaces superpowers:requesting-code-review)

```bash
mkdir -p .claude/skills/review
```

`.claude/skills/review/SKILL.md`:
```yaml
---
name: review
description: >
  Request code review on current changes. Use when completing a task, before
  committing, or when you want to verify code quality. Dispatches the
  project-code-reviewer agent.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Grep, Glob, Bash
model: opus
effort: medium
---
```
```markdown
## /review — Request Code Review

1. `git diff` — identify changed files
2. Read `.claude/references/techniques/INDEX.md` (if exists) → decide relevant technique files
3. Dispatch `project-code-reviewer` agent w/:
   - Changed files list + change summary
   - Applicable code standards
   - Relevant technique refs (paths from INDEX.md)
4. Files in `.claude/` (agents/ | skills/ | rules/): flag full-sentence prose, missing RCCF structure, articles/filler. Severity: WARNING
5. Present review results
6. Issues found → fix → re-review
```

### 10. /migrate-bootstrap

```bash
mkdir -p .claude/skills/migrate-bootstrap
```

`.claude/skills/migrate-bootstrap/SKILL.md`:
```yaml
---
name: migrate-bootstrap
description: >
  Apply pending bootstrap migrations. Use when the bootstrap repo has been
  updated and you need to bring this project to the latest migration level.
  Also handles retrofit for pre-migration bootstrapped projects.
argument-hint: "[migration-id]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch
model: sonnet
effort: medium
---
```
```markdown
## /migrate-bootstrap — Apply Pending Migrations

### Step 1: Read migration state

Read `.claude/bootstrap-state.json`.

**Exists:** extract `last_migration` + `applied[]` → Step 2.

**Missing — retrofit detection:**
- `.claude/settings.json` exists + contains `"hooks"`
- `CLAUDE.md` exists + contains fingerprints ("self-improvement" | ".learnings/log.md" | "Module")
- BOTH pass → pre-migration bootstrap. Create `.claude/bootstrap-state.json`:
```json
{
  "bootstrap_repo": "tomasfil/claude-bootstrap",
  "last_migration": "000",
  "last_applied": "{current ISO-8601 timestamp}",
  "applied": [
    { "id": "000", "applied_at": "{current ISO-8601 timestamp}", "commit": "b622344" }
  ]
}
```
- DON'T pass → not bootstrapped. Tell user: "Run full bootstrap first via `claude-bootstrap.md`."

### Step 2: Fetch migration index

```bash
gh api repos/tomasfil/claude-bootstrap/contents/migrations --jq '[.[] | select(.name != "_template.md") | .name] | sort'
```

Fallback (no `gh`):
```
https://api.github.com/repos/tomasfil/claude-bootstrap/contents/migrations
```
Filter `_template.md`, sort by filename.

### Step 3: Identify pending

Extract numeric IDs from filenames (`001_best-practices-and-migrations.md` → `"001"`).
Filter IDs > `last_migration`, sort ascending.
None pending → "Already up to date at migration {last_migration}" → STOP.

### Step 4: Apply each in order

1. Fetch: `gh api repos/tomasfil/claude-bootstrap/contents/migrations/{filename} --jq '.content' | base64 -d`
   Fallback: `https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/migrations/{filename}`
2. `breaking: true` → warn user + STOP, wait for confirmation
3. Print `## Changes` summary
4. Execute `## Actions` — read-before-write for all file modifications
5. Run `## Verify` — any fail → STOP, do NOT update state
6. Update state: append `{ "id": "{id}", "applied_at": "{timestamp}", "commit": "{base_commit}" }` to `applied[]`, update `last_migration` + `last_applied`
7. Print `✅ Migration {id} applied — {description}`

### Step 5: Report

```
✅ Migrations complete: applied {N} migrations ({id_list})
Current state: migration {last_migration}
```

### Gotchas
- Strict numeric order — never skip
- Retrofit requires BOTH settings.json w/ hooks AND CLAUDE.md w/ fingerprints
- Fail mid-apply → state NOT updated — safe to retry
- `.claude/bootstrap-state.json` always tracked, never gitignored
```

### 11. /consolidate (learning system maintenance)

```bash
mkdir -p .claude/skills/consolidate
```

`.claude/skills/consolidate/SKILL.md`:
```yaml
---
name: consolidate
description: >
  Consolidate learnings into instincts and clean up the learning system. Use when
  session start reports CONSOLIDATE_DUE=true, or when manually invoked. Reviews raw
  learnings, merges duplicates, resolves contradictions, promotes/prunes instincts.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Grep, Glob
model: opus
effort: medium
---
```
```markdown
## /consolidate — Learning Consolidation

Dispatch `reflector` agent for analysis. Main thread applies approved changes.

### Phase 1: Orient
Read:
- `.learnings/log.md` — raw corrections + discoveries
- `.learnings/instincts/` — existing instinct files
- `.learnings/patterns.md` — recurring patterns
- MEMORY.md — auto-memory index

### Phase 2: Gather
Dispatch `reflector` w/ all learnings paths:
- Scan corrections, decisions, recurring themes
- Cluster by domain (code-style | testing | git | debugging | security | architecture | tooling)
- Identify instinct candidates (2+ similar corrections)
- Identify reinforcements (+0.1) | contradictions (-0.05)

### Phase 2b: Cluster Review Findings
- Filter log: category == `review-finding`, status == `pending review`
- Group by `Agent:` tag value
- Within each group, cluster entries by `Pattern:` similarity (same rule, same component type)
- Cluster w/ 2+ entries → **promotion candidate**
  - Target: agent's Known Gotchas section in `.claude/agents/{name}.md`
  - Pattern framework-specific + agent has sub-specialists → also flag as `/evolve-agents` candidate (note only — do not run)
- Single-entry findings → flag as one-off, schedule for pruning this cycle
- Output: promotion candidates list + one-offs list

### Phase 3: Consolidate
Present proposals to user:
- New instincts (initial confidence 0.5)
- Existing instincts to reinforce | contradict
- Duplicates to merge; contradictions to resolve
- **Review-finding promotions** (from Phase 2b): for each promotion candidate:
  - Show: agent name, pattern, evidence count, proposed text addition
  - Choices: promote to agent prompt (add to Known Gotchas) | dismiss | defer
  - If `/evolve-agents` flagged: surface recommendation alongside — do not auto-execute
  - If user approves: use Edit to add to agent's Known Gotchas section

Apply approved changes.

### Phase 4: Prune + Promote
- Confidence 0.8+ → propose promotion to `.claude/rules/`
- Confidence <0.3 → archive | remove
- Clear processed entries from `log.md` (delete after promoting/dismissing)
- Keep instinct index lean

### Phase 5: Update Tracking
- `date +%s` → write to `.learnings/.last-dream`
- Reset `.learnings/.session-count` to 0
- Write entry count (`grep -c '^##\+ [0-9]\{4\}-' .learnings/log.md`) → `.learnings/.last-reflect-lines`

### Anti-Hallucination
- Only analyze entries that exist in files
- Never invent patterns not in data
- Require 2+ similar entries before creating instinct
```

## Checkpoint

```
✅ Module 13 complete — Plugin replacement skills created:
  /brainstorm, /write-plan, /execute-plan, /tdd, /debug, /verify, /commit, /pr, /review, /migrate-bootstrap, /consolidate
  These replace: superpowers, claude-md-management, commit-commands, pr-review-toolkit
```
