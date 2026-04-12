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
- **Skill Class**: every skill MUST declare class — `main-thread` (interactive, multi-dispatch, needs AskUserQuestion or user clarification) OR `forkable` (single bounded autonomous task, no user interaction). See `techniques/agent-design.md` § Skill Dispatch Reliability for the canonical classification table.
- **Main-thread orchestrators** (default): NO `context:` field, NO `agent:` field, `allowed-tools: Agent Read Write` (Write only for output files). Body MUST start with the pre-flight gate (see PRE_FLIGHT_GATE_BLOCK below).
- **Forkable analytical skills**: `context: fork` + `agent: proj-<specialist>` per the mapping in § Skill Dispatch Reliability. Single bounded task; no user interaction.
- Agent dispatch: use `Agent()` call w/ explicit prompt, NOT implicit `subagent_type` (inline during bootstrap, `subagent_type` post-bootstrap)
- **`allowed-tools` is SPACE-separated** per Claude Code skill spec (`allowed-tools: Read Write Grep`), never comma-separated. NOTE: skill `allowed-tools:` is space-separated; agent `tools:` is comma-separated (`tools: Read, Grep, Glob`). They are different fields with different separators per Claude Code spec — do not unify.

**Canonical dispatch form** (enforced by migration 003 verify):
- Procedure text MUST use literal `Dispatch agent via \`subagent_type="proj-<name>"\` w/ …` — NEVER weak prose like `**Dispatch proj-X**`, `Dispatch **proj-X** agent`, or bare `**Dispatch X**` without the `subagent_type=` annotation. Weak prose gives the main agent permission to misroute to built-in `Explore` / `general-purpose` or to inline the work.
- Skill description frontmatter MUST use `proj-*` prefix for every agent name (e.g. `Dispatches proj-quick-check`, never bare `quick-check`).
- Every dispatching skill MUST contain the `AGENT_DISPATCH_POLICY_BLOCK` at the top of the body (after the `# /skill-name` title). Block is a literal directive forbidding built-in `Explore`/`general-purpose` substitution.

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
NEVER substitute built-in `Explore` / `general-purpose` / plugin agents — not during skill execution, not as a fallback, not for "quick" lookups.
If custom agent missing → STOP + inform user.
If this skill has `disable-model-invocation` and the main thread cannot invoke it → STOP + ask user to run the slash command manually; do NOT fall back to Explore / general-purpose / inline work.
For any code exploration inside this skill: use Read/Grep/Glob directly OR dispatch `proj-quick-check` (simple) / `proj-researcher` (deep) — never built-in.
See `techniques/agent-design.md § Agent Dispatch Policy`.
```

Skill specs below reference this via `{AGENT_DISPATCH_POLICY_BLOCK — see top of module}` — agent generating the skill MUST expand the reference to the literal block above.

---

### PRE_FLIGHT_GATE_BLOCK

Reusable block injected as the FIRST executable section of every main-thread orchestrator skill body. Content:

```
## Pre-flight (REQUIRED — before any other step)

For each agent name this skill dispatches (see Dispatch Map below):
  If `.claude/agents/<agent-name>.md` does NOT exist → STOP.
  Tell user: "Required agent <name> missing. Run /migrate-bootstrap or /module-write."
  Do NOT proceed. Do NOT fall back to inline work. Do NOT substitute another agent.
```

Skill specs below reference this via `{PRE_FLIGHT_GATE_BLOCK — see top of module}` — agent generating the skill MUST expand the reference to the literal block above.

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
  context: fork
  agent: proj-code-reviewer
  allowed-tools: Read Grep Glob
  model: sonnet
  effort: medium
  # Skill Class: forkable — single bounded autonomous audit, no user interaction

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
  context: fork
  agent: proj-consistency-checker
  allowed-tools: Read Grep Glob
  model: sonnet
  effort: medium
  # Skill Class: forkable — single bounded autonomous scan

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
  context: fork
  agent: proj-consistency-checker
  allowed-tools: Read Grep Glob
  model: sonnet
  effort: medium
  # Skill Class: forkable — single bounded autonomous gap analysis

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
  argument-hint, allowed-tools (SPACE-separated single line — `allowed-tools: Read Write Grep`,
  per Claude Code skill spec; never comma-separated, breaks on `Bash(git add *)` patterns),
  model, effort. Body: procedure steps, decision trees, templates, verification.
  References: references/ subdirectory for progressive disclosure.

- Agent structure: YAML frontmatter w/ name, description, tools, model, effort: high,
  maxTurns, color. `tools:` is COMMA-separated (`tools: Read, Grep, Glob`) per Claude Code
  sub-agents spec — DIFFERENT from skill `allowed-tools:` which is space-separated. The
  spec is inconsistent across file types; don't try to unify. Body: role, pass-by-reference
  contract, process, anti-hallucination, scope lock, parallel tool calls block.

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

#### Dispatch 09a: /test-fork (Bash probe — proves tool restriction)

**Spec for dispatch prompt:**

```
Skill: test-fork
Directory: .claude/skills/test-fork/SKILL.md

Frontmatter:
  name: test-fork
  description: >
    Probe whether `context: fork` + `agent:` dispatches to a named custom agent.
    Manually invoke via /test-fork only — never auto-invoke. Diagnostic skill.
  context: fork
  agent: proj-quick-check
  allowed-tools: Bash
  model: haiku
  effort: low
  disable-model-invocation: true
  # Skill Class: forkable — diagnostic probe

Body — ## /test-fork — Fork Dispatch Probe:
Single section; one Bash command:
  `echo "FORK_PROBE pid=$$ ppid=$PPID time=$(date +%s)"`
Return output verbatim. Do NOTHING else.

Expected behavior:
  Forks to proj-quick-check. Quick-check has tools: OMIT (read-only inheritance — no Bash).
  Skill body requests Bash → fork dispatches → quick-check refuses ("Bash tool not available").
  Refusal IS the success signal: proves fork happened to restricted agent context.
```

---

#### Dispatch 09b: /test-fork-success (Read probe — proves positive fork execution)

**Spec for dispatch prompt:**

```
Skill: test-fork-success
Directory: .claude/skills/test-fork-success/SKILL.md

Frontmatter:
  name: test-fork-success
  description: >
    Probe positive fork execution — agent successfully runs in fork.
    Manually invoke via /test-fork-success only.
  context: fork
  agent: proj-quick-check
  allowed-tools: Read
  model: haiku
  effort: low
  disable-model-invocation: true
  # Skill Class: forkable — diagnostic probe

Body — ## /test-fork-success — Fork Execution Probe:
Use Read tool to read first line of `.claude/bootstrap-state.json` (or other tiny known file).
Return: "FORK_SUCCESS — agent ran, read line: <first-line>"

Expected behavior:
  Forks to proj-quick-check. Read is in quick-check's inherited tool set.
  Returns positive marker proving fork execution succeeded.
```

---

### Batch 2 — Skills That Reference Agents (dispatch ALL simultaneously)

6 skills that dispatch specific agents from Module 05. Dispatch after Batch 1.

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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — multi-dispatch orchestrator, interactive synthesis

Body — ## /debug — Systematic Investigation:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Phase 1 triage: `proj-quick-check`
- Phase 2 root-cause: `proj-debugger`

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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-tdd-runner, synthesizes results

Body — ## /tdd — Red-Green-Refactor:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Red-Green-Refactor cycle: `proj-tdd-runner`

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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-code-reviewer, interactive fix loop

Body — ## /review — Request Code Review:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Code review: `proj-code-reviewer`

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
  allowed-tools: Agent Read Write Bash
  model: opus
  effort: high
  # Skill Class: main-thread — needs Bash for `gh run view`, dispatches proj-debugger

Body — ## /ci-triage — CI Failure Investigation:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Root-cause analysis: `proj-debugger`

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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-code-writer-markdown, verifies cross-refs

Body — ## /module-write — Bootstrap Content Editing:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Content generation: `proj-code-writer-markdown`

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

#### Dispatch 14a: /audit-agents

**Spec for dispatch prompt:**

```
Skill: audit-agents
Directory: .claude/skills/audit-agents/SKILL.md

Frontmatter:
  name: audit-agents
  description: >
    Use when auditing agents for missing force-read blocks, MCP tool propagation
    issues, skill anti-patterns, or rule file gaps. Dispatches
    proj-consistency-checker with a widened audit brief.
  allowed-tools: Agent Read
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-consistency-checker, interactive report review

Body — ## /audit-agents — Agent Rules + MCP Propagation Audit:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Audit report: `proj-consistency-checker`

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Dispatch agent via `subagent_type="proj-consistency-checker"` w/ audit task brief:
  - **A1 — STEP 0 force-read presence**: for every `.claude/agents/*.md` (exclude
    `references/` subtree), verify body contains marker `STEP 0 — Load critical rules`.
    Report agents missing the marker w/ `file:line` evidence (line = frontmatter close).
  - **A2 — Rule file existence**: parse every `.claude/rules/<name>.md` reference
    inside STEP 0 blocks. Verify each referenced file exists in `.claude/rules/`.
    Report dangling refs w/ source agent + rule path.
    Note: `mcp-tool-routing.md` is conditional on `.mcp.json` — A2 treats it as optional (PASS when absent).
  - **A3 — MCP tool propagation**: if `.mcp.json` exists — parse `mcpServers` keys.
    Three-state rule per `.claude/agents/*.md`:
      1. No `tools:` line → PASS (agent inherits parent tools incl. MCP).
      2. Has `tools:` line w/ literal `mcp__<server>__<name>` entries (no wildcards) → PASS.
      3. Has `tools:` line containing any glob pattern like `mcp__<server>__<glob>` → FAIL.
         Globs are silently ignored by Claude Code at runtime — known limitation.
    Do NOT flag "has `tools:` but missing MCP entry" as a violation — the correct fix
    for write agents is to drop `tools:` entirely (see `mcp-routing.md` Agent layer).
    Report FAIL offenders w/ agent path + offending tools entry.
    No `.mcp.json` → skip A3 w/ INFO.
  - **A4 — Skill anti-pattern**: scan every `.claude/skills/*/SKILL.md` frontmatter
    `allowed-tools:` value. FAIL if any value contains `mcp__*` (skills must not
    name MCP tools directly — MCPs belong on agents). Report offenders w/ file:line.
  - **A5 — CLAUDE.md imports**: verify `CLAUDE.md` exists at project root and
    `@import`s `general.md` + `skill-routing.md`. If `.mcp.json` present, also
    verify `@import .claude/rules/mcp-routing.md`. Report missing imports.
  - **A6 — cmm index status**: if `.mcp.json` configures a cmm-compatible MCP
    (serena, code-context, etc.), verify repo is indexed (server-specific probe
    or presence of index artifacts). Absent cmm MCP → skip w/ WARN.

- Output: agent writes YAML-ish report to
  `.claude/reports/audit-agents-{timestamp}.md` via Bash heredoc. Format:

  ```yaml
  audit: agent-rules-mcp
  timestamp: {ISO8601}
  checks:
    A1_force_read:   {PASS|FAIL|SKIP}
    A2_rule_exists:  {PASS|FAIL|SKIP}
    A3_mcp_tools:    {PASS|FAIL|SKIP}
    A4_skill_mcp:    {PASS|FAIL|SKIP}
    A5_claude_md:    {PASS|FAIL|SKIP}
    A6_cmm_index:    {PASS|WARN|SKIP}
  findings:
    - check: A1
      severity: FAIL
      evidence: "{file}:{line}"
      detail: "{what's missing}"
  ```

- Return: report path + 1-line summary (PASS count / FAIL count / WARN count).
- Agent does NOT auto-patch — reports only. Main thread presents findings to user.

- Anti-hallucination: only cite files that exist; only report line numbers via
  actual grep output; uncertain check → SKIP not FAIL; no speculation about
  MCP servers not declared in `.mcp.json`.
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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — interactive clarification + research dispatch + spec write

Body — ## /brainstorm — Design Before Build:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Research: `proj-researcher`

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

#### Dispatch 15a: /deep-think

**Spec for dispatch prompt:**

```
Skill: deep-think
Directory: .claude/skills/deep-think/SKILL.md

Frontmatter:
  name: deep-think
  description: >
    Use when a problem requires multi-pass adversarial ideation: parallel
    divergent exploration, evidence-gated shortlisting, deepening of top
    candidates, and iterative gap-hunting until no HIGH-severity critiques
    remain. Trigger on: "deeply think", "innovate", "improve", "upgrade",
    "research X thoroughly", or when /brainstorm feels insufficient for a
    genuinely uncertain/multi-layer problem. Dispatches proj-researcher
    across 7 phases including an adversarial critic loop.
  argument-hint: "[topic] [--passes=N] [--max-critic=N] [--sequential] [--no-critic] [--quick]"
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — multi-dispatch iterative orchestrator w/ interactive user-gate

Body — ## /deep-think — Multi-Pass Adversarial Gap-Hunting Ideation:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Research: `proj-researcher` (sole dispatch target across all 7 phases)

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Main-thread orchestrator; 7 phases; sole dispatch target: proj-researcher
- Pre-flight gate: verify proj-researcher exists (verbatim PRE_FLIGHT_GATE_BLOCK)
- Agent dispatch policy block (verbatim AGENT_DISPATCH_POLICY_BLOCK)
- Capability checks: WebSearch available? MCP code-search available? → set mode
- Argument parsing: --passes=N, --max-critic=N, --sequential, --no-critic, --quick
- Phase 0: evidence-first local scan (1 researcher, no web)
- Phase 1: parallel divergent ideation (5 persona researchers, error handling)
- Phase 2: evaluator scoring + clustering + user gate + shortlist.md checkpoint
- Phase 3: deepen top-N (Reflexion critique injected)
- Phase 4: adversarial critic dispatch + convergence check
- Phase 5: gap resolution loop (≤5 critic iterations, ≤15 total dispatches)
- Phase 6: dual-artifact synthesis — proposals.md + spec.md (brainstorm-format)
- Phase 7: handoff (suggest /write-plan, do NOT auto-invoke)
- References: .claude/skills/deep-think/references/personas.md, dispatch-templates.md
- Anti-hallucination: verify artifact paths before writing; cite file:line
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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-plan-writer, writes plan files

Body — ## /write-plan — Implementation Planning:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Plan generation: `proj-plan-writer`

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Steps:
  1. Read spec from .claude/specs/{branch}/ | conversation context
  2. Read .claude/skills/code-write/references/pipeline-traces.md (if exists)
  3. Dispatch agent via `subagent_type="proj-plan-writer"` w/:
     - Spec content (file path reference)
     - Discovery context (languages, frameworks, commands)
     - Pipeline traces (if exist)
     - Write master plan to .claude/specs/{branch}/{date}-{topic}-plan.md
     - Write batch files to .claude/specs/{branch}/{date}-{topic}-plan/
       One file per dispatch unit: batch-NN-{summary}.md (1-N ordered tasks per file)
     - Return master plan path + summary

- Plan-writer produces:
  Master plan = index + execution order + dependency graph + Tier Classification
    Table + Dispatch Plan + Batch Index. Tier Classification Table appears BEFORE
    Dispatch Plan (visible think-step).
  Batch files = self-contained dispatch units, agent gets ONLY its batch file as context.
    One batch file per dispatch unit; holds 1-N ordered tasks the same agent runs
    sequentially, verifying once at end. Batch files are the ONLY accepted output
    format — legacy task-NN-*.md removed (Layer C of packing enforcement spec).

- Batch file format:
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
  On fail: agent reports which sub-task (NN.M) broke it, stops, returns partial-
  success map.
  Size caps: batch file body ≤200 lines total; individual task sub-section ≤60
  lines (hard warn at >80). Over cap → split or let specialist decide.

- Post-Dispatch Audit (MANDATORY — runs after proj-plan-writer returns):
  1. Glob `batch-*.md` under the emitted plan directory
  2. Parse each batch header: `Agent:`, `Layer:`, task count, `Dependency set:`
  3. For every pair (Bi, Bj) check merge criteria:
     `same agent AND same layer AND disjoint dep_sets AND combined_tasks ≤5 AND
      combined_context <60K AND combined_files ≤10`
     (merge criteria live in `proj-plan-writer` spec — single source of truth)
  4. No violations → pass plan to user, done
  5. Violation found → re-dispatch `proj-plan-writer` w/ corrective prompt
     containing: (a) the specific violation list (which batches could merge +
     why); (b) pointer to the agent's Self-Audit process step (NOT raw merge
     list, NOT heavy-hand merge instructions — trust the agent to apply its own
     audit given the violation context). Loopback cap: 2 attempts.
  6. After 2 failed loopbacks → HARD-FAIL w/ user-visible error listing every
     unmerged batch pair + merge criteria that matched + instruction to re-run
     `/write-plan` or inspect plan manually. Do NOT pass broken plan to user.
  Rationale: defense-in-depth. Agent Self-Audit (Layer A, `proj-plan-writer`
  spec) trains cognition; this gate mechanically verifies. Both exist
  deliberately — see `.claude/specs/main/2026-04-11-plan-writer-packing-enforcement-spec.md`.
  Regression context: 2026-04-11 mcp-routing-audit plan emitted 5 batch files
  for packable micro tasks; this gate blocks that failure mode structurally.

- Dispatch plan section:
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

- Batching rules: plan-writer classifies each task by 5 signals (dep topology,
  step count, verb, file count, layer; tie-break → promote up a tier) then packs
  via First Fit Decreasing over dep-isolated, layer-grouped bins. Caps: 5 tasks/
  unit micro, 3/unit moderate, solo for complex, ≤60K context budget, ≤10 files/
  unit. Authoritative algorithm + signal definitions: see `proj-plan-writer` spec
  in module 05 (`.claude/agents/proj-plan-writer.md`) — do NOT duplicate here.
  Parallel batches (no shared deps) may dispatch up to 3 concurrent per agent type.

- Anti-hallucination: verify referenced files exist; every dispatch unit needs
  ONE concrete verification command; never plan changes to unread files; task
  sub-sections describe INTENT not method bodies (specialist owns implementation).
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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — batch dispatch orchestrator, interactive checkpoints

Body — ## /execute-plan — Plan Execution:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Per-batch execution: agents named in each batch file header (dynamic — read
  `Agent:` field from batch file)
- Verification: `proj-verifier` (final full-suite run only; per-batch verification
  uses the single command in the batch header)
- Post-execution review: invoked via `/review` skill (which dispatches `proj-code-reviewer`)

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

- Steps:
  1. Read master plan from .claude/specs/{branch}/ | ask user for path
  2. Confirm plan w/ user — still correct?
  3. Pre-Flight Audit (see below) — HARD REJECT on violation, do NOT proceed
  4. Execute dispatch unit by dispatch unit in dep order (see Batch Dispatch Protocol)
  5. Verify each batch — run the ONE verification command from batch header after
     agent returns; on fail → Batch Failure Handling
  6. Checkpoint after each batch — print status, ask to continue
  7. Final verification — full build + test suite
  8. Invoke /review on all changed files — MANDATORY, not optional

- Pre-Flight Audit (MANDATORY — runs BEFORE any batch dispatch):
  1. Glob `batch-*.md` under the plan directory. No batch files found → HARD
     REJECT: "Plan has no batch-*.md files. Legacy task-NN-*.md format removed
     (2026-04-11 packing enforcement). Re-run /write-plan to regenerate."
  2. Parse each batch header: `Agent:`, `Layer:`, task count, `Dependency set:`
  3. For every pair (Bi, Bj) apply the same merge criteria as /write-plan
     Post-Dispatch Audit (see Dispatch 16): same agent + same layer + disjoint
     dep_sets + combined_tasks ≤5 + combined_context <60K + combined_files ≤10.
     Criteria definition lives in `proj-plan-writer` spec — single source of truth.
  4. No violations → proceed to Batch Dispatch Protocol
  5. Violations found → HARD REJECT (do NOT proceed, do NOT warn-and-continue).
     Print: "Plan violates packing enforcement. Unmerged batches: {list w/ pair +
     reason}. Re-run /write-plan to regenerate — packing must be resolved at
     plan-writer level, not execute-plan." Instruct user to re-run /write-plan.
     Rationale: defense-in-depth w/ /write-plan Post-Dispatch Audit — catches
     plans from prior sessions / older agent versions. Consistency w/ /write-plan
     gate prevents silent 5× fan-out token waste. See packing enforcement spec.

- Batch Dispatch Protocol:
  - "Batch" here = dispatch unit (one Agent invocation executing 1-N ordered tasks),
    NOT a grouping of separate dispatches. One batch file → one Agent call.
  - Read batch's Agent: + Tier: + Verification: fields from file header
  - Dispatch agent named in batch header via subagent_type="proj-{name}"
  - Pass batch file PATH (not task file paths, not inlined content) to the agent
  - Agent runs all task sub-sections sequentially top-down in dep order within
    that single dispatch
  - Agent runs the batch Verification command ONCE at end of batch (not per task)
  - Independent batches (no shared deps): dispatch up to 3 concurrent per agent
    type in ONE message (parallel Agent calls). Code-writing batches sharing deps:
    SEQUENTIAL (each must leave build passing).
  - Research/doc agent batches: parallel-safe by default

- Per-Batch Protocol (within one dispatch):
  - Read-before-write: agent reads all rule files listed in batch header ONCE at
    batch start (deduped) + all files listed in the batch `Dependency set` header
    ONCE at batch start
  - MUST dispatch the agent named in the batch `Agent:` header field — never
    execute inline, never substitute a different agent
  - Specialist dispatch prompt MUST include: "Read `.claude/rules/code-standards-
    {lang}.md` + `.claude/rules/data-access.md` (if applicable) BEFORE writing any
    code. These rules override any code shown in task sub-sections."
  - If task sub-section contains code snippets → treat as CONTRACT/HINT
    (signatures + intent), not MANDATE. Specialist applies domain rules + framework
    guardrails that plan-writer lacked.
  - Agent executes task sub-sections top-down in dep order, then runs the batch
    verification command ONCE
  - On success → agent returns PASS, checkpoint, next batch
  - On verification fail → agent returns partial-success map
    (e.g. `NN.1 PASS, NN.2 FAIL, NN.3 NOT_RUN`) indicating which sub-task broke
    the batch — NOT just a single fail. Main thread handles via Batch Failure
    Handling below.

- Batch Failure Handling (NEW):
  - Agent partial-success map identifies failed + not-run sub-tasks
  - Main thread re-dispatches each FAILED task SOLO (one Agent call per failed
    task, no re-batching on retry). Prevents retry amplification; gives each
    retry clean context per research recommendation.
  - NOT_RUN tasks: re-dispatch SOLO in dep order after failed-task retries succeed
  - Solo retry also fails → STOP, report to user, ask how to proceed (do NOT
    silently skip or continue past failing tasks)
  - NEVER collapse multiple failed tasks back into one retry batch

- Plan changes mid-execution:
  STOP → explain change + why → update plan file → get approval before continuing

- Post-execution (MANDATORY):
  1. Run /review on all changed files — DO NOT skip
  2. Review finds issues → fix before proceeding
  3. Only after review passes → tell user ready to /commit

- Anti-hallucination: never claim batch PASS without reading the agent's returned
  partial-success map; never skip failed sub-tasks; never assume NOT_RUN tasks
  passed; verify every file claimed changed actually changed before /review.

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
    tests, cross-references, and consistency checks via proj-verifier.
  context: fork
  agent: proj-verifier
  allowed-tools: Read Bash Grep Glob
  model: sonnet
  effort: medium
  # Skill Class: forkable — bounded verification run, no user interaction

Body — ## /verify — Pre-Completion Verification:
Run ALL checks — never claim completion until all pass.

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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-reflector, interactive proposal approval

Body — ## /reflect — Self-Improvement Protocol:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Learning analysis + proposals: `proj-reflector`

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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-reflector, interactive consolidation approval

Body — ## /consolidate — Learning Consolidation:
Dispatch agent via `subagent_type="proj-reflector"` for analysis. Main thread applies approved changes.

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Learning cluster analysis: `proj-reflector`

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
  allowed-tools: Agent Read
  model: opus
  effort: high
  # Skill Class: main-thread — dispatches proj-code-writer-{lang}, no inline code work

Body — ## /code-write — Implementation Dispatcher:

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Code generation: `proj-code-writer-{lang}` (dynamic — discovered via glob of `.claude/agents/proj-code-writer-*.md`)

NOTE: Module 07 (Code Specialists) overrides this spec with the full routing version.
This placeholder applies contract + pre-flight + dispatch-map; Module 07 fills routing logic.

{AGENT_DISPATCH_POLICY_BLOCK — see top of module}

NOTE: This is a PLACEHOLDER during Module 06. Module 07 (Code Specialists)
fills in the full routing logic + creates the proj-code-writer-{lang} agents +
generates references/ content (pipeline-traces.md, capability-index.md).

Placeholder behavior until Module 07 completes:
1. Accept implementation request from user
2. Glob .claude/agents/proj-code-writer-*.md → list available specialists
3. If agent-index.yaml exists → read for scope/routing info
4. If no specialists found → STOP per pre-flight gate. Tell user: "Run Module 07 (Code Specialists) to generate proj-code-writer-{lang} agents." NEVER fall back to inline.
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
- If no matching specialist → STOP per pre-flight gate. Tell user to run /evolve-agents to create the missing specialist. NEVER fall back to inline execution.
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
  allowed-tools: Agent Read Write
  model: opus
  effort: high
  # Skill Class: main-thread — multi-dispatch research + creation pipeline

Body — ## /evolve-agents — Agent Audit + New Specialist Creation:
v6: agents are born right-sized. This skill audits + creates NEW, never splits.

{PRE_FLIGHT_GATE_BLOCK — see top of module}

## Dispatch Map
- Phase 3 research: `proj-researcher` (local deep-dive + web research)
- Phase 3 agent generation: `proj-code-writer-markdown`
- Phase 5 refresh: `proj-researcher` + `proj-code-writer-markdown`

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
  allowed-tools: Read Write Edit Bash Grep Glob WebFetch
  model: sonnet
  effort: high
  # Skill Class: main-thread — inline migration executor, no custom agent dispatch (exempt from pre-flight gate)

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
  Read bootstrap_repo from .claude/bootstrap-state.json
  Primary: gh api repos/${bootstrap_repo}/contents/migrations/index.json --jq '.content' | base64 -d > /tmp/mig-index.json
  Fallback (no gh): curl -sSL https://raw.githubusercontent.com/${bootstrap_repo}/main/migrations/index.json -o /tmp/mig-index.json
  Parse JSON → extract .migrations array (each entry: { id, file, description, breaking })
  Empty array → "No migrations defined in bootstrap repo" → STOP

- Step 3: Identify pending
  Filter entries where id > last_migration (string compare works for zero-padded IDs)
  Sort ascending by id
  None pending → "Already up to date" → STOP

- Step 4: Apply each in order
  1. Use entry.breaking flag from index — true → warn + STOP, wait for confirmation
  2. Fetch migration content: gh api repos/${bootstrap_repo}/contents/migrations/${entry.file} --jq '.content' | base64 -d
     Fallback: curl -sSL https://raw.githubusercontent.com/${bootstrap_repo}/main/migrations/${entry.file}
  3. Print Changes summary (parse Changes section from fetched file)
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
expected_skills="brainstorm deep-think write-plan execute-plan tdd debug code-write verify review audit-file audit-memory audit-agents commit pr reflect consolidate evolve-agents migrate-bootstrap coverage coverage-gaps write-ticket ci-triage write-prompt module-write"
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
  Dev: /brainstorm, /deep-think, /write-plan, /execute-plan, /tdd, /debug, /code-write (placeholder)
  Quality: /verify, /review, /audit-file, /audit-memory, /audit-agents
  Git: /commit, /pr
  Maintenance: /reflect, /consolidate, /evolve-agents, /migrate-bootstrap
  Reporting: /coverage, /coverage-gaps
  Utilities: /write-ticket, /ci-triage, /write-prompt, /module-write
  {/sync — if git_strategy == companion}
  Total: 24-25 skills via proj-code-writer-markdown dispatch
```
