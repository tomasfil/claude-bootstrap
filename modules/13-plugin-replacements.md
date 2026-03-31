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

1. **Understand the request** — ask clarifying questions one at a time
2. **Explore project context** — read relevant files, check architecture
3. **Propose 2-3 approaches** — with trade-offs and your recommendation
4. **Present design section by section** — get approval after each
5. **Save design** — write to `.claude/specs/{date}-{topic}.md`
6. **Transition** — invoke /write-plan to create implementation plan

### Knowledge Base
Before proposing approaches, read `.claude/references/techniques/INDEX.md` (if it exists) to discover available technique references. Then read the relevant technique files based on the task:
- Skill/agent/prompt design → `prompt-engineering.md`
- Code generation agents → `anti-hallucination.md`
- Agent architecture → `agent-design.md`

Use as design vocabulary — starting point, not definitive. Skip for tasks unrelated to architecture/prompt-engineering.

DO NOT write any code until the user approves the design.
Prefer multiple choice questions. One question per message.
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

1. **Read the spec** — from `.claude/specs/` or conversation context
2. **Identify pipeline traces** — read `.claude/skills/code-write/references/pipeline-traces.md` if it exists
3. **Break into tasks** — each task should be independently completable and verifiable
4. **Order by dependency** — data layer first, API second, UI last
5. **Assign verification** — each task has a build/test command to verify completion
6. **Write plan** — save to `.claude/specs/{date}-{topic}-plan.md`

### Task Format
```
## Task {N}: {title}
Files: {list of files to create/modify}
Depends on: {task numbers}
Verification: {build/test command}
Agent: {which specialist handles this — or "main"}

### Steps
1. {step}
2. {step}
```

### Anti-Hallucination
- Verify all referenced files exist before including in the plan
- Each task must have a concrete verification command
- Don't plan changes to files you haven't read
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

1. **Read the plan** — from `.claude/specs/` or ask user for path
2. **Review with user** — confirm the plan is still correct
3. **Execute task by task** — in dependency order
4. **Verify each task** — run the verification command after completing each task
5. **Checkpoint** — after each task, print status and ask if user wants to continue
6. **Final verification** — run full build + test suite at the end
7. **Review** — invoke `/review` on all changed files before suggesting commit. This is mandatory, not optional.

### Per-Task Protocol
- Read-before-write: read all files in the task's file list before starting
- Execute steps in order
- Run verification command
- If verification fails: fix, retry once, then ask user
- Mark task complete and move to next

### If plan needs to change mid-execution:
- Stop implementing
- Explain what changed and why
- Update the plan file
- Get user approval before continuing

### Post-Execution (mandatory)
After all tasks complete:
1. Run `/review` on all changed files — do NOT skip this
2. If review finds issues: fix them before proceeding
3. Only after review passes, tell the user changes are ready to `/commit`

Never say "ready to commit" without having run /review first.
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

### RED: Write a failing test
1. Read existing test files to match conventions (naming, structure, assertions)
2. Write the test that describes expected behavior
3. Run it: `{test_single_command}` — confirm it FAILS
4. If it passes, the test isn't testing new behavior — rethink

### GREEN: Write minimal code to pass
1. Read-before-write: understand the codebase context
2. Write the minimum code to make the test pass
3. Run the test: `{test_single_command}` — confirm it PASSES
4. If it fails, fix the implementation (not the test)

### REFACTOR: Clean up
1. Look for duplication, unclear names, or overly complex logic
2. Refactor while keeping tests green
3. Run tests after each refactoring step

### Repeat for each behavior/scenario
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

### Phase 1: Reproduce
1. Understand the symptom — what's expected vs what's happening
2. Find the minimal reproduction (test, command, input)
3. Run it and capture the EXACT error output

### Phase 2: Locate
1. Read the error message carefully — what file, line, type of error?
2. Trace the call stack — goToDefinition / findReferences / Grep
3. Identify the exact line where behavior diverges from expectation
4. Read surrounding code to understand context

### Phase 3: Diagnose
1. Why does this line produce the wrong result?
2. What assumption is violated?
3. Is it a logic error, data error, environment error, or timing error?
4. Check `.learnings/log.md` — has this been seen before?

### Phase 4: Fix
1. Write a test that reproduces the bug (TDD red phase)
2. Fix the root cause (not a symptom)
3. Run the test — confirm it passes
4. Run surrounding tests — confirm nothing else broke
5. Log the finding to `.learnings/log.md` if it's a pattern

### Anti-Hallucination
- Do NOT propose a fix before completing Phase 2 (Locate)
- Do NOT guess at the root cause — trace the actual execution
- After 2 failed fix attempts, search the web for known issues
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

Run ALL of these. Do not claim completion until all pass.

1. **Build**: `{build_command}` — must succeed with zero errors
2. **Lint**: `{lint_command}` — must pass (if applicable)
3. **Tests**: `{test_suite_command}` — run at minimum the tests related to changes
4. **Review changes**: `git diff` — scan for accidental changes, debug code, TODOs
5. **Check for common issues**:
   - [ ] No hardcoded secrets or credentials
   - [ ] No console.log / print statements left in
   - [ ] No commented-out code
   - [ ] All new files follow naming conventions
   - [ ] Pipeline trace complete (if multi-layer change)

### Report
```
Verification: {PASS / FAIL}
Build: {pass/fail}
Lint: {pass/fail/N/A}
Tests: {N passed, M failed}
Issues found: {list or "none"}
```

If ANY check fails, fix it before claiming done.
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

1. Run `git status` to see what's changed
2. Run `git diff --staged` and `git diff` to understand changes
3. Check recent commits: `git log --oneline -5` for message style
4. Draft commit message following project convention:
   - Use conventional commits: `type(scope): description`
   - Types: feat, fix, refactor, test, docs, chore, style
   - Keep subject < 72 chars
   - Body explains WHY, not WHAT
5. Stage relevant files (prefer specific files over `git add .`)
6. Create commit
7. If git_strategy is "companion": export to companion repo

### Do NOT commit:
- .env files, credentials, secrets
- Large binary files
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

1. Run `git status` and `git log main..HEAD` to understand all changes
2. Draft PR:
   - Title: < 70 chars, describes the change
   - Body: summary bullets, test plan, any migration notes
3. Push branch if needed: `git push -u origin {branch}`
4. Create PR: `gh pr create --title "..." --body "..."`
5. Return the PR URL

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

1. Run `git diff` to see what's changed
2. Dispatch the `project-code-reviewer` agent with:
   - List of changed files
   - Summary of what the changes do
   - Which code standards apply
3. Present the review results
4. If issues found: fix them, then re-review
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

**File exists:** extract `last_migration` + `applied[]`. Continue to Step 2.

**File missing — retrofit detection:**
- Check `.claude/settings.json` exists AND contains `"hooks"`
- Check `CLAUDE.md` exists AND contains bootstrap fingerprints (any of: "self-improvement", ".learnings/log.md", "Module")
- BOTH pass → project bootstrapped pre-migration. Create `.claude/bootstrap-state.json`:
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
- Conditions DON'T pass → not bootstrapped. Tell user: "This project has not been bootstrapped yet. Run the full bootstrap first by executing `claude-bootstrap.md`."

### Step 2: Fetch migration index

```bash
gh api repos/tomasfil/claude-bootstrap/contents/migrations --jq '[.[] | select(.name != "_template.md") | .name] | sort'
```

Fallback if `gh` unavailable — WebFetch:
```
https://api.github.com/repos/tomasfil/claude-bootstrap/contents/migrations
```
Filter out `_template.md`, sort by filename.

### Step 3: Identify pending migrations

Extract numeric IDs from filenames (e.g., `001_best-practices-and-migrations.md` → `"001"`).
Filter to IDs > `last_migration`. Sort ascending.
None pending → print "Already up to date at migration {last_migration}" and STOP.

### Step 4: Apply each pending migration in order

1. **Fetch** migration file: `gh api repos/tomasfil/claude-bootstrap/contents/migrations/{filename} --jq '.content' | base64 -d`
   Fallback: `https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/migrations/{filename}`
2. **If `breaking: true`** → warn user + STOP. Wait for explicit confirmation.
3. **Print** `## Changes` summary to user.
4. **Execute** `## Actions` — read-before-write for all file modifications.
5. **Run** `## Verify` — any check fails → STOP. Do NOT update state file.
6. **Update state**: append `{ "id": "{id}", "applied_at": "{timestamp}", "commit": "{base_commit}" }` to `applied[]`, update `last_migration` + `last_applied`.
7. **Print** `✅ Migration {id} applied — {description}`

### Step 5: Report summary

```
✅ Migrations complete: applied {N} migrations ({id_list})
Current state: migration {last_migration}
```

### Gotchas
- Migrations apply in strict numeric order — never skip
- Retrofit requires BOTH `.claude/settings.json` w/ hooks AND `CLAUDE.md` w/ fingerprints
- Migration fails mid-apply → state NOT updated — safe to retry
- `.claude/bootstrap-state.json` always tracked — never gitignored
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

Dispatch the `reflector` agent for heavy analysis. Main thread applies approved changes.

### Phase 1: Orient
Read current state:
- `.learnings/log.md` — raw corrections and discoveries
- `.learnings/instincts/` — existing instinct files
- `.learnings/patterns.md` — recurring patterns
- MEMORY.md — auto-memory index

### Phase 2: Gather
Dispatch `reflector` agent with all learnings paths. Agent:
- Scans for corrections, decisions, recurring themes
- Clusters entries by domain (code-style, testing, git, debugging, security, architecture, tooling)
- Identifies entries that should become instincts (2+ similar corrections)
- Identifies instincts to reinforce (+0.1) or contradict (-0.05)

### Phase 3: Consolidate
Present reflector's proposals to user:
- New instincts to create (with initial confidence 0.5)
- Existing instincts to reinforce or contradict
- Duplicate entries to merge
- Contradictions to resolve

Apply approved changes.

### Phase 4: Prune & Promote
- High-confidence instincts (0.8+) — propose promotion to `.claude/rules/`
- Low-confidence instincts (<0.3) — archive or remove
- Clear processed entries from `log.md` (move to archive)
- Keep instinct index lean

### Phase 5: Update Tracking
- Run `date +%s` and write the output (Unix epoch seconds) to `.learnings/.last-dream`
- Reset `.learnings/.session-count` to 0
- Write current entry count (`grep -c '^##\+ [0-9]\{4\}-' .learnings/log.md`) to `.learnings/.last-reflect-lines`

### Anti-Hallucination
- Only analyze entries that actually exist in the files
- Don't invent patterns not present in the data
- Don't create instincts from single occurrences — require 2+ similar entries
```

## Checkpoint

```
✅ Module 13 complete — Plugin replacement skills created:
  /brainstorm, /write-plan, /execute-plan, /tdd, /debug, /verify, /commit, /pr, /review, /migrate-bootstrap, /consolidate
  These replace: superpowers, claude-md-management, commit-commands, pr-review-toolkit
```
