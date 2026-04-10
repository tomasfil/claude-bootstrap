# Module 06 — Skills

> Generate ALL ~23 skills via proj-code-writer-markdown agent dispatches.
> Main = dispatch only. Batch by dependency. Absorbs v5 modules 05, 06, 07, 13.

---

## Idempotency

Per skill: READ existing → extract project-specific content → REGENERATE w/ current template + extracted knowledge.
Create if missing. Delete if superseded (v5 `/spec` → removed, absorbed by `/brainstorm`; v5 `/check-consistency` → removed, absorbed by `/verify`).

## Skill Frontmatter Requirements

All skills MUST include:
- `description:` starts w/ "Use when..." — native Skill tool routing trigger
- Keep body under 500 lines; split to `references/` subdirectory if longer
- `context: fork` + `agent: general-purpose` on orchestrator skills — NOTE: `context:fork` broken (claude-code#16803), skills run inline regardless; keep for forward compat
- Agent dispatch: use `Agent()` call w/ explicit prompt, NOT implicit `subagent_type` (inline during bootstrap, `subagent_type` post-bootstrap)

## Actions

### Pre-Flight

```bash
mkdir -p .claude/skills
```

Verify foundation agents exist (from Module 01):
```bash
for agent in proj-code-writer-markdown proj-researcher proj-code-writer-bash; do
  [[ -f ".claude/agents/${agent}.md" ]] || echo "MISSING: ${agent}.md — run Module 01 first"
done
```

If any missing → STOP. Module 01 must complete first.

### Dispatch Pattern

Each skill dispatched to proj-code-writer-markdown using inline BOOTSTRAP_DISPATCH_PROMPT from Module 01.

```
Agent(
  subagent_type: "proj-code-writer-markdown",
  description: "Create /skill-name skill",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT from Module 01, proj-code-writer-markdown section}

Create skill directory and write SKILL.md:
  mkdir -p .claude/skills/{skill-name}
  Write .claude/skills/{skill-name}/SKILL.md

{skill specification from sections below}

Read 2-3 existing skills in .claude/skills/ before writing for pattern consistency.
Read techniques/prompt-engineering.md for RCCF framework.
"
)
```

After each dispatch: verify SKILL.md exists, check frontmatter has `name` + `description` (starts "Use when...").

Skills dispatched in batches by dependency. Within each batch, dispatch ALL skills simultaneously (multiple Agent calls in one message — parallel, safe since they write to separate directories).

---

### AGENT_DISPATCH_POLICY_BLOCK

Reusable block injected into every skill that dispatches agents. Content:

```
**Agent Dispatch Policy**: Use `subagent_type="proj-<name>"` explicitly.
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents.
If custom agent missing → STOP + inform user. See `techniques/agent-design.md § Agent Dispatch Policy`.
```

Skill specs below reference this via `{AGENT_DISPATCH_POLICY_BLOCK — see top of module}` — agent generating the skill MUST expand the reference to the literal block above.

---

### Batch 1 — Independent Simple Skills (dispatch ALL simultaneously)

9 skills w/ no cross-skill dependencies. Inline execution (no agent dispatch within skill body).

---

#### Dispatch 01: /commit

**Spec for dispatch prompt:**

```
Skill: commit
Directory: .claude/skills/commit/SKILL.md

Frontmatter:
  name: commit
  description: >
    Use when asked to commit, save changes, or after completing a task.
    Creates conventional commits with project message style.

Body — ## /commit — Project-Aware Commit:
- Note: assumes /review + /verify already ran per CLAUDE.md automation
- Steps:
  1. git status — see changes
  2. git diff --staged + git diff — understand changes
  3. git log --oneline -5 — match message style
  4. Draft conventional commit: type(scope): description
     Types: feat | fix | refactor | test | docs | chore | style
     Subject < 72 chars; body explains WHY not WHAT
  5. Stage specific files (never git add .)
  6. Create commit
  7. If git_strategy == "companion" → export to companion repo

- DO NOT commit: .env, credentials, secrets; large binaries; unrelated changes (split)
- Anti-hallucination: verify staged files match intent before committing
```

---

#### Dispatch 02: /pr

**Spec for dispatch prompt:**

```
Skill: pr
Directory: .claude/skills/pr/SKILL.md

Frontmatter:
  name: pr
  description: >
    Use when asked to create a pull request, submit changes for review,
    or after finishing a feature branch. Creates PR with summary + test plan.

Body — ## /pr — Create Pull Request:
- Steps:
  1. git status + git log main..HEAD — understand all changes
  2. Draft PR: title < 70 chars; body = summary bullets + test plan + migration notes
  3. Push if needed: git push -u origin {branch}
  4. gh pr create --title "..." --body "..."
  5. Return PR URL

- PR body template:
  ## Summary
  - {1-3 bullet points}
  ## Test Plan
  - [ ] {verification steps}
  ## Notes
  - {migration steps, breaking changes, or "none"}
```

---

#### Dispatch 03: /audit-file

**Spec for dispatch prompt:**

```
Skill: audit-file
Directory: .claude/skills/audit-file/SKILL.md

Frontmatter:
  name: audit-file
  description: >
    Use when asked to review, audit, or check a specific file for quality,
    conventions, or issues. Reports violations with line numbers, severity, fixes.
  argument-hint: "[filename]"

Body — ## /audit-file — Source File Audit:
- Input: file path to audit. If none given, ask.
- Process:
  1. Read file in full
  2. Determine language from extension
  3. Read .claude/rules/code-standards-{lang}.md
  4. Read .claude/rules/data-access.md (if file touches data layer)
  5. LSP check (if available) → type errors, undefined references
  6. Scan violations against applicable rules

- Check categories:
  - Code standards: naming, structure, style per language rules; security + correctness
  - Claude-facing content (only for .claude/ files):
    telegraphic notation, RCCF structure, no article starters, no filler
    Severity: WARNING

- Report format per issue:
  [{SEVERITY}] Line {N}: {rule_name}
    Code: `{snippet}`
    Issue: {what's wrong}
    Fix: {how to fix}
  Severity: ERROR (must fix) | WARNING (should fix) | INFO (consider)

- Summary: Score: {N}/100, issue counts, top violation types
- Anti-hallucination: only cite rules that EXIST in .claude/rules/ — verify;
  only report line numbers that EXIST; unsure → INFO not ERROR
```

---

#### Dispatch 04: /audit-memory

**Spec for dispatch prompt:**

```
Skill: audit-memory
Directory: .claude/skills/audit-memory/SKILL.md

Frontmatter:
  name: audit-memory
  description: >
    Use when asked to check memory, review stored learnings, clean up stale
    entries, or verify memory system integrity. Checks .learnings/ and .claude/ health.

Body — ## /audit-memory — Memory Health Check:
- Process:
  1. Read .learnings/log.md — stuck pending, duplicates, missing status, contradictions
  2. Read .learnings/agent-usage.log — unused agents, high-frequency optimization candidates, missing entries
  3. Read CLAUDE.md — over 120 lines?, stale conventions, missing sections
  4. Read .claude/rules/ — files >40 lines?, contradictions, dead references
  5. Read .claude/agents/ — missing frontmatter, missing tool restrictions, description mismatch
  6. Check auto-memory (if accessible): ls ~/.claude/projects/*/memory/ — stale entries, duplicates

- Report:
  Memory Health: {score}/100
  .learnings/log.md: {N} entries (pending/promoted/dismissed counts)
  Agent usage: {N} tracked, {M} unused
  CLAUDE.md: {lines} lines (over/under budget)
  Rules: {N} files, {total_lines} total
  Agents: {N} agents, valid frontmatter: yes/no
  Issues: [{severity}] {description} — {recommended action}
```

---

#### Dispatch 05: /coverage

**Spec for dispatch prompt:**

```
Skill: coverage
Directory: .claude/skills/coverage/SKILL.md

Frontmatter:
  name: coverage
  description: >
    Use when asked about test coverage, structural validation, or to verify
    bootstrap completeness. Reports coverage of files, agents, skills, hooks.

Body — ## /coverage — Structural Validation Report:
- Scan .claude/ directory structure:
  1. Count agents: .claude/agents/*.md — list each w/ name, model, tools
  2. Count skills: .claude/skills/*/SKILL.md — list each w/ name, description snippet
  3. Count rules: .claude/rules/*.md — list each w/ line count
  4. Count hooks: check .claude/settings.json for hook entries
  5. Count techniques: .claude/references/techniques/*.md
  6. Verify CLAUDE.md exists + line count
  7. Verify .learnings/ structure complete

- Report: structured summary w/ counts, status per component category
- Flag: missing components vs expected (agents from Module 05, skills from Module 06)
```

---

#### Dispatch 06: /coverage-gaps

**Spec for dispatch prompt:**

```
Skill: coverage-gaps
Directory: .claude/skills/coverage-gaps/SKILL.md

Frontmatter:
  name: coverage-gaps
  description: >
    Use when asked what's missing from the development environment, what gaps
    exist in skills/agents/rules, or to identify improvement opportunities.

Body — ## /coverage-gaps — Gap Identification:
- Compare actual state vs expected:
  1. Read CLAUDE.md — extract referenced skills, agents, commands
  2. Glob .claude/agents/*.md — compare against agent-index.yaml (if exists)
  3. Glob .claude/skills/*/SKILL.md — compare against Module 06 skill list
  4. Read .claude/rules/ — compare against detected languages (code-standards-{lang}.md per language)
  5. Read .learnings/log.md — patterns w/o corresponding rules/instincts
  6. Check for languages detected in Module 01 w/o proj-code-writer-{lang} agent

- Report: gap list w/ severity + recommendation per gap
- Suggest: which /evolve-agents | /reflect | manual action addresses each gap
```

---

#### Dispatch 07: /sync (conditional)

**Spec for dispatch prompt:**

```
Skill: sync
Directory: .claude/skills/sync/SKILL.md

CONDITIONAL: only create if git_strategy == "companion" (from Module 01).
If git_strategy != "companion" → skip this dispatch entirely.

Frontmatter:
  name: sync
  description: >
    Use when syncing .claude/ config to companion repo or importing from it.
    Push/pull config between project and ~/.claude-configs/{project}/.
  argument-hint: "[push|pull|status|export|import]"

Body — ## /sync — Companion Repo Sync:
- Delegates to .claude/scripts/sync-config.sh
- Subcommands:
  - export: copy .claude/ → companion repo
  - import: copy companion repo → .claude/
  - push: export + git push companion
  - pull: git pull companion + import
  - status: show sync state (last sync time, dirty files)
- Anti-hallucination: verify sync-config.sh exists before running;
  if missing → tell user "Run Module 09 first" or create from Module 09 template
```

---

#### Dispatch 08: /write-ticket

**Spec for dispatch prompt:**

```
Skill: write-ticket
Directory: .claude/skills/write-ticket/SKILL.md

Frontmatter:
  name: write-ticket
  description: >
    Use when asked to write a ticket, issue, user story, or task description.
    Creates INVEST+C structured tickets with acceptance criteria.

Body — ## /write-ticket — INVEST+C Ticket Writing:
- Input: feature/bug description from user
- Process:
  1. Clarify scope if ambiguous
  2. Structure as INVEST+C:
     I — Independent (self-contained, no hidden deps)
     N — Negotiable (what, not how)
     V — Valuable (clear user/business value)
     E — Estimable (enough detail to size)
     S — Small (fits in one sprint/iteration)
     T — Testable (clear pass/fail criteria)
     C — Contextual (relevant codebase context, affected files/components)
  3. Include: title, description, acceptance criteria (Given/When/Then), affected components, test plan

- Output format:
  ## {Title}
  **Type:** feature | bug | chore
  **Priority:** P0-P3
  ### Description
  {1-3 sentences}
  ### Acceptance Criteria
  - [ ] Given {context} When {action} Then {result}
  ### Affected Components
  - {file/module list}
  ### Test Plan
  - {verification steps}

- Anti-hallucination: reference actual files/components from codebase, not invented ones
```

---

#### Dispatch 09: /write-prompt

**Spec for dispatch prompt:**

```
Skill: write-prompt
Directory: .claude/skills/write-prompt/SKILL.md

Frontmatter:
  name: write-prompt
  description: >
    Use when creating new skills, agents, subagent definitions, CI prompts,
    or any prompt/instruction file. Best practices for LLM instruction writing.
    Covers RCCF framework, anti-hallucination, token efficiency, testing.

Body — ## /write-prompt — LLM Instruction Writing Guide:
Reference skill — no agent dispatch, provides guidance for manual use.

Include these sections (from techniques/prompt-engineering.md + techniques/anti-hallucination.md):

- Skill structure: YAML frontmatter template w/ name, description ("Use when..."),
  argument-hint, allowed-tools, model, effort. Body: procedure steps, decision trees,
  templates, verification. References: references/ subdirectory for progressive disclosure.

- Agent structure: YAML frontmatter w/ name, description, tools, model, effort: high,
  maxTurns, color. Body: role, pass-by-reference contract, process, anti-hallucination,
  scope lock, parallel tool calls block.

- RCCF framework: Role (who) → Context (what) → Constraints (boundaries) → Format (output)

- Anti-hallucination (MUST include in every code-writing agent):
  1. Read-before-write mandate
  2. Negative instructions (DO NOT invent APIs)
  3. Build verification
  4. Confidence routing (unsure → check first)
  5. Fallback behavior (can't verify → say so)

- Claim-Evidence Ledger (for research-heavy skills):
  When-to-apply: external claims (stats, dates, quotes, API behaviors)
  Structure: id, claim, source_url, source_name, source_date, confidence, corroborated
  Integration: during research → mandatory audit → output w/ source attribution
  Absence documentation: "no results found" over fabrication

- Model selection table: haiku=quick lookup | sonnet=code generation | opus=complex reasoning

- Tool restrictions: research agents=Read,Grep,Glob; code writers=Read,Write,Edit,Bash,Grep,Glob,LSP;
  web access=add WebSearch,WebFetch; minimal=only what's needed

- Token efficiency: Claude-facing=compressed telegraphic; strip articles/filler;
  symbols: → | + ~ × w/; exception: code examples at full fidelity (quality cliff <65%)

- Output verification gate: scan for prose → rewrite telegraphic; no article starters;
  no filler; RCCF structure check

- Principles: explicit>implicit; one responsibility; full context; constrain agent;
  handle empty case; match effort; token-efficient
```

---

### Batch 2 — Skills That Reference Agents (dispatch ALL simultaneously)

5 skills that dispatch specific agents from Module 05. Dispatch after Batch 1.

---

#### Dispatch 10: /debug

**Spec for dispatch prompt:**

```
Skill: debug
Directory: .claude/skills/debug/SKILL.md

Frontmatter:
  name: debug
  description: >
    Use when encountering a bug, test failure, unexpected behavior, or error.
    Dispatches proj-quick-check for triage, then proj-debugger for root cause analysis.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
  model: opus
  effort: high

Body — ## /debug — Systematic Investigation:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Phase 1: Triage — dispatch agent via `subagent_type="proj-quick-check"` w/ error message/symptom
  Read proj-quick-check's text response → determine severity + likely area
- Phase 2: Deep investigation — dispatch agent via `subagent_type="proj-debugger"` w/:
  - Symptom description + proj-quick-check findings
  - Error output, affected files
  - Write diagnosis to .claude/reports/debug-{timestamp}.md
  - Return path + summary

- Debugger follows 4 phases:
  1. Reproduce: identify symptom, find minimal reproduction, capture exact error
  2. Locate: read error, trace call stack, identify divergence point
  3. Diagnose: why wrong result, which assumption violated, classify error type
     Check .learnings/log.md for similar past issues
  4. Fix: write reproducing test (TDD red), fix root cause, verify pass, run regression

- Anti-hallucination:
  DO NOT propose fix before Locate phase complete
  DO NOT guess root cause — trace actual execution
  After 2 failed fix attempts → search web for known issues
- Log to .learnings/log.md if pattern discovered
```

---

#### Dispatch 11: /tdd

**Spec for dispatch prompt:**

```
Skill: tdd
Directory: .claude/skills/tdd/SKILL.md

Frontmatter:
  name: tdd
  description: >
    Use when implementing a feature or bugfix where writing tests first improves
    confidence. Red-green-refactor cycle with test-driven development.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
  model: opus
  effort: high

Body — ## /tdd — Red-Green-Refactor:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Dispatch agent via `subagent_type="proj-tdd-runner"` w/:
  - Feature/behavior specification from user
  - Test conventions path: .claude/rules/code-standards-{lang}.md
  - Build command: {build_command}
  - Test single command: {test_single_command}
  - Test suite command: {test_suite_command}
  - Write results to .claude/reports/tdd-{timestamp}.md
  - Return path + summary

- TDD cycle (within agent):
  RED — write test describing expected behavior → run → must FAIL
  GREEN — write minimum code to pass → run → must PASS
  REFACTOR — clean up w/ tests green → run after each step
  Repeat per behavior/scenario

- Anti-hallucination: read existing tests first → match conventions;
  passes immediately → not testing new behavior, rethink
```

---

#### Dispatch 12: /review

**Spec for dispatch prompt:**

```
Skill: review
Directory: .claude/skills/review/SKILL.md

Frontmatter:
  name: review
  description: >
    Use when completing a task, before committing, or to verify code quality.
    Dispatches proj-code-reviewer agent for thorough review.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Grep, Glob, Bash
  model: opus
  effort: high

Body — ## /review — Request Code Review:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Steps:
  1. git diff — identify changed files
  2. Read .claude/references/techniques/INDEX.md (if exists) → pick relevant technique files
  3. Dispatch agent via `subagent_type="proj-code-reviewer"` w/:
     - Changed files list + change summary
     - Applicable code standards from .claude/rules/
     - Relevant technique ref paths
     - Write review to .claude/reports/review-{timestamp}.md
     - Return path + summary
  4. Read review report
  5. Files in .claude/ (agents/skills/rules): flag full-sentence prose,
     missing RCCF, articles/filler → severity WARNING
  6. Present review results to user
  7. Issues found → fix → re-review

- Anti-hallucination: only reference rules that exist; only cite lines that exist
```

---

#### Dispatch 13: /ci-triage

**Spec for dispatch prompt:**

```
Skill: ci-triage
Directory: .claude/skills/ci-triage/SKILL.md

Frontmatter:
  name: ci-triage
  description: >
    Use when CI/CD pipeline fails, build breaks in CI, or asked to investigate
    automated test/build failures. Reads CI output, identifies root cause.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Bash, Grep, Glob
  model: opus
  effort: high

Body — ## /ci-triage — CI Failure Investigation:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Steps:
  1. Get CI output — user provides URL or paste, or fetch via gh:
     gh run view {run-id} --log-failed 2>/dev/null
     gh api repos/{owner}/{repo}/actions/runs/{run-id}/jobs --jq '.jobs[] | select(.conclusion=="failure")'
  2. Parse failure: extract error messages, failing tests, exit codes
  3. Classify: build error | test failure | lint error | deploy error | infra/timeout
  4. Dispatch agent via `subagent_type="proj-debugger"` w/:
     - CI output (relevant section only, not full log)
     - Classification + hypothesis
     - Local reproduction command
     - Write diagnosis to .claude/reports/ci-triage-{timestamp}.md
     - Return path + summary
  5. Read diagnosis → present to user w/ fix recommendation
  6. If fix is clear → apply fix + verify locally before suggesting commit

- Anti-hallucination: reproduce locally before claiming fix;
  never assume CI environment matches local — check for env-specific issues
```

---

#### Dispatch 14: /module-write

**Spec for dispatch prompt:**

```
Skill: module-write
Directory: .claude/skills/module-write/SKILL.md

Frontmatter:
  name: module-write
  description: >
    Use when editing bootstrap modules, techniques, or agents in the bootstrap
    repo itself. Dispatches proj-code-writer-markdown for content creation.
    Bootstrap repo only — not for client projects.
  argument-hint: "[module-or-file-path]"
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
  model: opus
  effort: high

Body — ## /module-write — Bootstrap Content Editing:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Input: target file path + change description
- Steps:
  1. Read target file (if exists)
  2. Read 2-3 similar files for pattern consistency
  3. Read claude-bootstrap.md — verify module numbering, checklist
  4. Dispatch agent via `subagent_type="proj-code-writer-markdown"` w/:
     - Target file path
     - Change description
     - Context: similar files read, conventions detected
     - Write output to target path
     - Return path + summary
  5. Verify cross-references in written file exist
  6. Check claude-bootstrap.md checklist stays in sync

- Anti-hallucination: never invent module numbers; verify all cross-refs;
  read before write — always
```

---

### Batch 3 — Skills That Reference Other Skills (dispatch ALL simultaneously)

6 skills that reference skills from Batch 1-2. Dispatch after Batch 2.

---

#### Dispatch 15: /brainstorm (absorbs /spec)

**Spec for dispatch prompt:**

```
Skill: brainstorm
Directory: .claude/skills/brainstorm/SKILL.md

Frontmatter:
  name: brainstorm
  description: >
    Use when asked to design, plan, explore, think through, or brainstorm a
    feature, component, or change. Always brainstorm before implementing
    non-trivial changes. Absorbs /spec — when requirements clear, skips
    exploration and produces spec directly.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Grep, Glob
  model: opus
  effort: high

Body — ## /brainstorm — Design Before Build:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Decision tree:
  Requirements clear + well-defined → skip to Step 5 (spec output)
  Requirements unclear | complex | multiple approaches → full exploration

- Full exploration flow:
  1. Clarify request — one question per message, prefer multiple choice
  2. Dispatch agent via `subagent_type="proj-researcher"` w/:
     - Exploration scope (architecture, patterns, prior art)
     - Write findings to .claude/specs/{branch}/{date}-{topic}-research.md
     - Return path + summary
  3. Read research findings
  4. Propose 2-3 approaches w/ trade-offs + recommendation
     Present section by section — get approval after each
  5. Save spec → .claude/specs/{branch}/{date}-{topic}-spec.md
     Specs use compressed telegraphic notation
  6. Transition → invoke /write-plan

- Knowledge base: read .claude/references/techniques/INDEX.md (if exists) →
  pick relevant technique files. Starting-point knowledge, not definitive.

- DO NOT write code until user approves design
- Spec output format:
  # {Topic} Spec
  ## Problem / Goal
  ## Constraints
  ## Approach (approved)
  ## Components (files, interfaces, data flow)
  ## Open Questions
```

---

#### Dispatch 16: /write-plan

**Spec for dispatch prompt:**

```
Skill: write-plan
Directory: .claude/skills/write-plan/SKILL.md

Frontmatter:
  name: write-plan
  description: >
    Use when you have requirements or a spec and need to break them into
    concrete implementation steps. Creates plan with dispatch batching.
    Use after /brainstorm or when starting from a clear spec.
  argument-hint: "[spec-file-path]"
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Grep, Glob
  model: opus
  effort: high

Body — ## /write-plan — Implementation Planning:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Steps:
  1. Read spec from .claude/specs/{branch}/ | conversation context
  2. Read .claude/skills/code-write/references/pipeline-traces.md (if exists)
  3. Dispatch agent via `subagent_type="proj-plan-writer"` w/:
     - Spec content (file path reference)
     - Discovery context (languages, frameworks, commands)
     - Pipeline traces (if exist)
     - Write master plan to .claude/specs/{branch}/{date}-{topic}-plan.md
     - Write individual task files to .claude/specs/{branch}/{date}-{topic}-plan/
       One file per task/batch: task-NN-{title}.md
     - Return master plan path + summary

- Plan-writer produces:
  Master plan = index + execution order + dependency graph + dispatch plan
  Task files = self-contained, agent gets ONLY their task file as context

- Task file format:
  ## Task {N}: {title}
  Files: {create/modify list}
  Depends on: {task numbers}
  Verification: {build/test command}
  Agent: {specialist name}
  Batch: {batch-id}
  ### Steps
  1. {step}

- Dispatch plan section:
  ### Dispatch Plan
  - Batch 1 (agent: {name}) — Tasks: 1,2. Deps: none. Parallel w/: Batch 2.
  - Batch 2 (agent: {name}) — Tasks: 3. Deps: none. Parallel w/: Batch 1.
  - Batch 3 (agent: {name}) — Tasks: 4. Deps: Batch 1,2.

- Batching rules: same agent → batch candidate; inter-task deps block batching;
  related scope preferred within batch; parallel batches (no deps) → ONE message

- Anti-hallucination: verify referenced files exist; every task needs verification
  command; never plan changes to unread files
```

---

#### Dispatch 17: /execute-plan

**Spec for dispatch prompt:**

```
Skill: execute-plan
Directory: .claude/skills/execute-plan/SKILL.md

Frontmatter:
  name: execute-plan
  description: >
    Use when you have a written plan and are ready to implement. Executes plan
    batch-by-batch with verification checkpoints. Mandatory /review at end.
  argument-hint: "[plan-file-path]"
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob, Skill
  model: opus
  effort: high

Body — ## /execute-plan — Plan Execution:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Steps:
  1. Read master plan from .claude/specs/{branch}/ | ask user for path
  2. Confirm plan w/ user — still correct?
  3. Execute batch by batch in dependency order (see protocol below)
  4. Verify each task — run verification command after completion
  5. Checkpoint after each batch — print status, ask to continue
  6. Final verification — full build + test suite
  7. Invoke /review on all changed files — MANDATORY, not optional

- Batch dispatch protocol:
  - Read batch's task files from Dispatch Plan
  - Code-writing agents: dispatch SEQUENTIALLY (each must leave build passing)
  - Research/doc agents: dispatch in PARALLEL (multiple Agent calls, one message)
  - Agent receives ONLY its task file path reference (focused context)
  - Agent reports per-task status → verify each before marking batch complete

- Per-task protocol (within batch):
  - Read-before-write: read all files in task's file list first
  - MUST dispatch agent specified in Agent: field — never execute inline if agent specified
  - Execute steps → run verification → fix + retry once on fail → ask user
  - Mark complete → next task

- Plan changes mid-execution:
  STOP → explain change + why → update plan file → get approval before continuing

- Post-execution (MANDATORY):
  1. Run /review on all changed files — DO NOT skip
  2. Review finds issues → fix before proceeding
  3. Only after review passes → tell user ready to /commit

NEVER say "ready to commit" without /review first.
```

---

#### Dispatch 18: /verify (absorbs /check-consistency)

**Spec for dispatch prompt:**

```
Skill: verify
Directory: .claude/skills/verify/SKILL.md

Frontmatter:
  name: verify
  description: >
    Use before committing, creating PRs, or claiming work is done. Runs build,
    tests, cross-references, and consistency checks. Dispatches both proj-verifier
    and proj-consistency-checker agents.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Bash, Grep, Glob
  model: opus
  effort: high

Body — ## /verify — Pre-Completion Verification:
Run ALL checks — never claim completion until all pass.

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Phase 1: Build + Test verification
  Dispatch agent via `subagent_type="proj-verifier"` w/:
  - Build command: {build_command}
  - Lint command: {lint_command}
  - Test suite command: {test_suite_command}
  - Write report to .claude/reports/verification.md
  - Return path + summary

- Phase 2: Cross-reference + consistency (dispatch in PARALLEL w/ Phase 1)
  Dispatch agent via `subagent_type="proj-consistency-checker"` w/:
  - Scan: CLAUDE.md references, skill→agent dependencies, rule file integrity
  - Write report to .claude/reports/consistency.md
  - Return path + summary

- Phase 3: Merge results (main thread)
  Read both reports → merge into unified assessment:
  Build: {pass/fail}
  Lint: {pass/fail/N/A}
  Tests: {N passed, M failed}
  Consistency: {pass/fail}
  Cross-refs: {N checked, M broken}
  Common issues scanned:
  - [ ] No hardcoded secrets/credentials
  - [ ] No console.log/print debug statements
  - [ ] No commented-out code
  - [ ] New files follow naming conventions
  
  Verification: {PASS / FAIL}
  Issues found: {list or "none"}

ANY check fails → fix before claiming done.
```

---

#### Dispatch 19: /reflect

**Spec for dispatch prompt:**

```
Skill: reflect
Directory: .claude/skills/reflect/SKILL.md

Frontmatter:
  name: reflect
  description: >
    Use when asked to review learnings, improve the development environment,
    audit configuration, evolve agents, or optimize .claude/ setup.
    Run when SessionStart reports REFLECT_DUE=true.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Grep, Glob, Bash
  model: opus
  effort: high

Body — ## /reflect — Self-Improvement Protocol:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Step 1: Dispatch agent via `subagent_type="proj-reflector"` w/ paths:
  - .learnings/log.md — pending entries
  - .learnings/instincts/ — instinct files (if exists)
  - .learnings/observations.jsonl — tool usage patterns
  - .learnings/agent-usage.log — agent usage data
  - CLAUDE.md — rules + conventions
  - .claude/rules/ — standards
  - .claude/agents/ — agents + descriptions
  - For each proj-code-writer-* + proj-test-writer-* agent: check evolution heuristics:
    1. Line count (wc -l) — >500 = evolution candidate
    2. Classification tree branches — 3+ top-level framework branches = candidate
    3. Framework-specific corrections in .learnings/log.md — 3+ for same framework
    4. Dispatch count from .learnings/agent-usage.log — 10+ dispatches = mature enough
    5. Sub-specialists: check version drift (project manifest versions vs agent's Stack section)
    6. Sub-specialist research staleness — reference files older than 90 days
  - .claude/references/techniques/INDEX.md — pick relevant techniques for evaluation
  - User memory: ~/.claude/projects/ (project-specific MEMORY.md)
  - Write proposals to .claude/reports/reflect-proposals.md
  - Return path + summary

  Fallbacks:
  - .learnings/instincts/ missing → use log.md only
  - .claude/references/techniques/ missing → skip technique refs

- Step 2: Present proposals (main thread)
  Read proposals → group by category:
  Rules changes: add/update rule in {file} — reason
  Agent changes: create/retire/improve agent — reason
  Agent evolution candidates (detect only — user runs /evolve-agents):
    evolve/update {name} — reason → recommend /evolve-agents
  CLAUDE.md changes: add gotcha, update convention, move to @import
  Learnings promotion: promote/dismiss — reason
  Wait for user approval per proposal.

- Step 3: Apply approved changes (main thread)
  1. Update CLAUDE.md, rules, agents as approved
  2. Mark promoted entries in .learnings/log.md → promoted w/ destination
  3. Mark dismissed entries → dismissed w/ reason
  4. New skills/agents → update settings.json routing if needed

- Step 4: Instinct health report
  IF .learnings/instincts/ exists → analyze:
  Total count, confidence distribution, domain breakdown
  Prune candidates (confidence <0.3), promotion candidates (confidence 0.8+ → .claude/rules/)
  IF missing → skip.

- Report:
  Learnings: {N} promoted, {M} dismissed, {P} pending
  Rules: {N} added, {M} updated
  Agents: {N} created, {M} retired, {P} improved
  CLAUDE.md: {N} changes
  File sizes: within budget? (CLAUDE.md <120, rules <40, agents <500)
  Instincts: {total}, {prune}, {promote} (omit if no instincts dir)

- Update tracking: write entry count → .learnings/.last-reflect-lines

- Gotchas:
  - .learnings/instincts/ may not exist — check before reading
  - Single-occurrence corrections → DO NOT promote; require 2+ similar
  - Agent usage data may be empty if hook unwired — check first
  - Reflect proposes evolution — NEVER auto-splits; user runs /evolve-agents

- Anti-hallucination:
  READ before modifying — verify log entries exist before marking
  Confirm paths exist before writing
  Count entries via grep -c — never estimate
  Proposing agent changes → verify agent file exists first
  NEVER claim rule added w/o reading target file to confirm

- Companion repo integration (if git_strategy == "companion"):
  After applying changes → run sync-config.sh export
  Print: "Changes synced to companion repo"
  Remind: "Run /sync push to push to remote"
```

---

#### Dispatch 20: /consolidate

**Spec for dispatch prompt:**

```
Skill: consolidate
Directory: .claude/skills/consolidate/SKILL.md

Frontmatter:
  name: consolidate
  description: >
    Use when session start reports CONSOLIDATE_DUE=true, or when manually
    invoked. Reviews raw learnings, merges duplicates, resolves contradictions,
    promotes/prunes instincts.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Grep, Glob
  model: opus
  effort: high

Body — ## /consolidate — Learning Consolidation:
Dispatch agent via `subagent_type="proj-reflector"` for analysis. Main thread applies approved changes.

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Phase 1: Orient
  Read: .learnings/log.md, .learnings/instincts/, .learnings/patterns.md, MEMORY.md

- Phase 2: Gather
  Dispatch agent via `subagent_type="proj-reflector"` w/ all learnings paths:
  - Scan corrections, decisions, recurring themes
  - Cluster by domain (code-style | testing | git | debugging | security | architecture | tooling)
  - Identify instinct candidates (2+ similar corrections)
  - Identify reinforcements (+0.1) | contradictions (-0.05)
  - Write analysis to .claude/reports/consolidation-proposals.md
  - Return path + summary

- Phase 2b: Cluster review findings
  Filter log: category == review-finding, status == pending review
  Group by Agent: tag → cluster by Pattern: similarity
  Cluster w/ 2+ entries → promotion candidate (target: agent's Known Gotchas)
  Single-entry → flag as one-off, schedule for pruning
  Output: promotion candidates + one-offs list

- Phase 3: Consolidate
  Present proposals to user:
  - New instincts (initial confidence 0.5)
  - Existing instincts to reinforce | contradict
  - Duplicates to merge; contradictions to resolve
  - Review-finding promotions (from Phase 2b):
    Show: agent name, pattern, evidence count, proposed text
    Choices: promote to agent Known Gotchas | dismiss | defer
    If /evolve-agents flagged → surface recommendation (don't auto-execute)
  Apply approved changes.

- Phase 4: Prune + promote
  Confidence 0.8+ → propose promotion to .claude/rules/
  Confidence <0.3 → archive | remove
  Clear processed entries from log.md
  Keep instinct index lean

- Phase 5: Update tracking
  date +%s → .learnings/.last-dream
  Reset .learnings/.session-count to 0
  Write entry count → .learnings/.last-reflect-lines

- Anti-hallucination: only analyze entries that exist; never invent patterns;
  require 2+ similar before creating instinct
```

---

### Batch 4 — Complex Skills (dispatch sequentially)

3 skills w/ complex logic or dependencies on discovery context. Dispatch one at a time.

---

#### Dispatch 21: /code-write

**Spec for dispatch prompt:**

```
Skill: code-write
Directory: .claude/skills/code-write/SKILL.md

Frontmatter:
  name: code-write
  description: >
    Use when asked to implement, write, create, or modify code. Routes to the
    appropriate proj-code-writer-{lang} agent based on file type and scope. Dynamic
    discovery — globs .claude/agents/proj-code-writer-*.md for available specialists.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
  model: opus
  effort: high

Body — ## /code-write — Implementation Dispatcher:

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

NOTE: This is a PLACEHOLDER during Module 06. Module 07 (Code Specialists)
fills in the full routing logic + creates the proj-code-writer-{lang} agents +
generates references/ content (pipeline-traces.md, capability-index.md).

Placeholder behavior until Module 07 completes:
1. Accept implementation request from user
2. Glob .claude/agents/proj-code-writer-*.md → list available specialists
3. If agent-index.yaml exists → read for scope/routing info
4. If no specialists found (pre-Module 07) → execute inline w/ general knowledge
5. If specialists found → read scope: field from matching agent frontmatter →
   dispatch via `subagent_type="proj-code-writer-{lang}"` best match w/ implementation request

Post-Module 07 behavior (filled by Module 07):
1. Read .claude/skills/code-write/references/capability-index.md → routing table
2. Read .claude/skills/code-write/references/pipeline-traces.md → change patterns
3. Classify request by: file extension, framework, architecture layer
4. Route to best-match via `subagent_type="proj-code-writer-{lang}"` (or sub-specialist if exists)
5. Multi-file changes spanning languages → dispatch multiple specialists sequentially
6. Each specialist must leave build passing

Dynamic discovery (always):
- Glob .claude/agents/proj-code-writer-*.md → find all specialists
- Read scope: from each → build routing table at dispatch time
- New specialists auto-discovered w/o skill changes

Anti-hallucination:
- NEVER dispatch to agent that doesn't exist — glob first
- NEVER assume language from file content alone — check extension + project manifests
- If no matching specialist → execute inline, note gap for /evolve-agents
```

---

#### Dispatch 22: /evolve-agents

**Spec for dispatch prompt:**

```
Skill: evolve-agents
Directory: .claude/skills/evolve-agents/SKILL.md

Frontmatter:
  name: evolve-agents
  description: >
    Use when auditing agents for staleness, adding specialists for new frameworks,
    refreshing agent knowledge after dependency upgrades, or when /reflect
    recommends evolution. Post-bootstrap only — audit + create-new, NOT split.
  context: fork
  agent: general-purpose
  allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob
  model: opus
  effort: high

Body — ## /evolve-agents — Agent Audit + New Specialist Creation:
v6: agents are born right-sized. This skill audits + creates NEW, never splits.

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Phase 1: Audit existing specialists
  For each .claude/agents/proj-code-writer-*.md + proj-test-writer-*.md:
  1. Version drift: compare project manifest versions (package.json, *.csproj,
     pyproject.toml, go.mod, Cargo.toml) against agent's Role+Stack section
  2. Reference staleness: reference files older than 90 days
  3. Missing patterns: accumulated corrections in .learnings/log.md for this agent's scope
  4. Dispatch frequency: .learnings/agent-usage.log — retire if unused for N sessions

- Phase 2: Detect new frameworks
  Compare Module 01 discovery (or re-scan project manifests) against existing agents:
  - New language added since bootstrap → needs proj-code-writer-{lang}
  - New framework added to existing language → may need sub-specialist

- Phase 3: Create new specialists (if needed)
  Same pipeline as Module 07:
  1. Dispatch agent via `subagent_type="proj-researcher"` → local deep-dive + web research for new framework
     Write to .claude/skills/code-write/references/{lang}-{framework}-analysis.md
  2. Dispatch agent via `subagent_type="proj-researcher"` → web research (latest patterns, security, gotchas)
     Write to .claude/skills/code-write/references/{lang}-{framework}-research.md
  3. Dispatch agent via `subagent_type="proj-code-writer-markdown"` → generate agent from research references
     Write to .claude/agents/proj-code-writer-{lang}-{framework}.md

- Phase 4: Update index
  Read all agent frontmatter → regenerate .claude/agents/agent-index.yaml
  Update .claude/skills/code-write/references/capability-index.md

- Phase 5: Refresh stale agents (if flagged in Phase 1)
  Re-dispatch via `subagent_type="proj-researcher"` for updated web research
  Dispatch via `subagent_type="proj-code-writer-markdown"` to update agent w/ new findings
  Preserve agent's accumulated Known Gotchas section

- Report:
  Audited: {N} agents
  Stale: {list w/ reason}
  Created: {list of new agents}
  Refreshed: {list}
  Retired: {list}
  Index updated: yes/no

- Anti-hallucination:
  NEVER split existing agents — create NEW sub-specialists instead
  Verify agent files exist before modifying
  Verify framework actually exists in project before creating specialist
  Use glob for agent filenames — never hardcode specific names
```

---

#### Dispatch 23: /migrate-bootstrap

**Spec for dispatch prompt:**

```
Skill: migrate-bootstrap
Directory: .claude/skills/migrate-bootstrap/SKILL.md

Frontmatter:
  name: migrate-bootstrap
  description: >
    Use when applying bootstrap updates to this project from the bootstrap
    repo. Fetches pending migrations, applies in order, updates state.
  argument-hint: "[migration-id]"
  allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch
  model: sonnet
  effort: high

Body — ## /migrate-bootstrap — Apply Pending Migrations:
NOTE: v6 bootstrap repo ships with zero migrations. This skill exists for
FUTURE migrations applied to child projects.

- Step 1: Read migration state
  Read .claude/bootstrap-state.json
  Exists → extract last_migration + applied[] → Step 2
  Missing — retrofit detection:
    .claude/settings.json exists + contains "hooks"
    CLAUDE.md exists + contains fingerprints ("self-improvement" | ".learnings/log.md")
    Both pass → pre-migration bootstrap, create bootstrap-state.json:
    { bootstrap_repo, last_migration: "000", last_applied, applied: [{ id: "000", ... }] }
    Don't pass → not bootstrapped, tell user to run full bootstrap

- Step 2: Fetch migration index
  gh api repos/{bootstrap_repo}/contents/migrations --jq '[.[] | select(.name != "_template.md") | .name] | sort'
  Fallback (no gh): https://api.github.com/repos/{bootstrap_repo}/contents/migrations

- Step 3: Identify pending
  Extract numeric IDs from filenames, filter > last_migration, sort ascending
  None pending → "Already up to date" → STOP

- Step 4: Apply each in order
  1. Fetch content (gh api | raw.githubusercontent.com fallback)
  2. breaking: true → warn + STOP, wait for confirmation
  3. Print Changes summary
  4. Execute Actions — read-before-write for all modifications
  5. Run Verify — any fail → STOP, do NOT update state
  6. Update state: append to applied[], update last_migration + last_applied
  7. Print: Migration {id} applied — {description}

- Step 5: Report
  Migrations complete: applied {N} ({id_list})
  Current state: migration {last_migration}

- Gotchas:
  Strict numeric order — never skip
  Retrofit requires BOTH settings.json w/ hooks AND CLAUDE.md w/ fingerprints
  Fail mid-apply → state NOT updated — safe to retry
  .claude/bootstrap-state.json always tracked, never gitignored
```

---

### Post-Dispatch Verification

After all batches complete:

```bash
# Verify all skills created
expected_skills="brainstorm write-plan execute-plan tdd debug code-write verify review audit-file audit-memory commit pr reflect consolidate evolve-agents migrate-bootstrap coverage coverage-gaps write-ticket ci-triage write-prompt module-write"
for skill in $expected_skills; do
  [[ -f ".claude/skills/${skill}/SKILL.md" ]] || echo "MISSING: ${skill}"
done

# Conditional check
if [[ "{git_strategy}" == "companion" ]]; then
  [[ -f ".claude/skills/sync/SKILL.md" ]] || echo "MISSING: sync"
fi

# Verify all have "Use when" in description
for skill_file in .claude/skills/*/SKILL.md; do
  grep -q "Use when" "$skill_file" || echo "MISSING 'Use when': $skill_file"
done
```

Fix any missing skills by re-dispatching from the spec above.

---

## Checkpoint

```
✅ Module 06 complete — Skills created:
  Dev: /brainstorm, /write-plan, /execute-plan, /tdd, /debug, /code-write (placeholder)
  Quality: /verify, /review, /audit-file, /audit-memory
  Git: /commit, /pr
  Maintenance: /reflect, /consolidate, /evolve-agents, /migrate-bootstrap
  Reporting: /coverage, /coverage-gaps
  Utilities: /write-ticket, /ci-triage, /write-prompt, /module-write
  {/sync — if git_strategy == companion}
  Total: 22-23 skills via proj-code-writer-markdown dispatch
```
