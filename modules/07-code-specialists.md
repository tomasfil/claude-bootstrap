# Module 07 — Code Specialists

> Research-driven creation of per-language code-writer, test-writer, code-reviewer agents.
> Main = pure orchestrator. 7-phase pipeline w/ cross-language parallelism.
> Absorbs v5 modules 16 (code-writer), 17 (code-reviewer), 18 (evolve-agents → born right-sized).

---

## Idempotency

Per agent/skill file: READ existing → extract project-specific knowledge → REGENERATE w/ current template + extracted content.
Reference files (analysis, research): merge new findings w/ existing — never discard prior research.
Agent index: regenerate from current agent frontmatter on every run.

## What This Produces

| Output | Path | Purpose |
|--------|------|---------|
| Per-lang analysis refs | `.claude/skills/code-write/references/{lang}-analysis.md` | Local codebase findings |
| Per-lang research refs | `.claude/skills/code-write/references/{lang}-research.md` | Web research findings |
| Code writer agents | `.claude/agents/proj-code-writer-{lang}.md` | Per-language code writers (9 sections) |
| Code writer sub-specs | `.claude/agents/proj-code-writer-{lang}-{fw}.md` | Framework sub-specialists (if 3+ fw) |
| Test writer agents | `.claude/agents/proj-test-writer-{lang}.md` | Per-language test writers (8 sections) |
| Test writer sub-specs | `.claude/agents/proj-test-writer-{lang}-{fw}.md` | Framework sub-specialists (if 3+ fw) |
| Code reviewer | `.claude/agents/proj-code-reviewer.md` | Project-aware deep reviewer |
| Review checklist | `.claude/agents/references/review-checklist.md` | Per-component review items |
| Agent index | `.claude/agents/agent-index.yaml` | Dispatch routing index |
| Capability index | `.claude/skills/code-write/references/capability-index.md` | Agent inventory + gaps |
| Pipeline traces | `.claude/skills/code-write/references/pipeline-traces.md` | Feature-type file mapping |
| Code-write skill | `.claude/skills/code-write/SKILL.md` | `/code-write` orchestrator |
| Coverage skill | `.claude/skills/coverage/SKILL.md` | `/coverage` command |
| Coverage gaps skill | `.claude/skills/coverage-gaps/SKILL.md` | `/coverage-gaps` command |

---

## Pipeline Overview

7 phases. Main thread NEVER generates agent/skill content — all dispatched to agents.

| Phase | Actor | Parallelism | Purpose |
|-------|-------|-------------|---------|
| 0 | main | — | Capability scan + framework decision |
| 1 | proj-researcher | ALL langs simultaneously | Local codebase deep-dive |
| 2 | proj-researcher | ALL langs simultaneously | Web research (15-20 searches/lang) |
| 3 | proj-code-writer-markdown | SEQUENTIAL per lang | Generate proj-code-writer agents |
| 4 | proj-code-writer-markdown | SEQUENTIAL per lang | Generate proj-test-writer agents |
| 5 | proj-code-writer-markdown | single dispatch | Generate proj-code-reviewer |
| 6 | main | — | Agent index + references + skills |

**Parallelism rules:**
- Phases 1-2: ALL languages in parallel — researchers only READ, no build conflicts
- Phases 3-4: SEQUENTIAL per language — code agents may run build verification; each must leave project building
- Phase 5: single dispatch — reviewer reads ALL reference files

---

<role>
Senior engineering lead creating comprehensive code writing, testing, and review system.
Combines architecture knowledge + meticulous codebase analysis + current research.
Reads existing code to extract patterns — never imposes conventions.
</role>

<task>
Execute ALL phases below. Every output grounded in discovery + research — no generic filler.
You are the orchestrator on the main thread. Dispatch `proj-researcher` and `proj-code-writer-markdown`
agents via Agent tool. Do NOT perform analysis, research, or generation inline — agents ARE
the quality layer.
</task>

<rules>
1. Execute phases in order. Never skip research.
2. After each phase: `Phase N complete — {summary}`
3. If clarification needed → STOP + ask before continuing
4. Every code example from actual project, never invented
5. All generated files: YAML frontmatter w/ required fields
6. All agents: anti-hallucination sections (read-before-write, verification, negative instructions)
7. Write all generated content in compressed telegraphic notation — code examples full fidelity
8. NEVER create generic `code-writer.md` or `test-writer.md` — always `proj-code-writer-{lang}.md` / `proj-test-writer-{lang}.md`
9. Every language w/ 3+ owned source files MUST get both code-writer + test-writer
10. 3+ frameworks → sub-specialists IMMEDIATELY (born right-sized, not deferred)
11. When web research fails after 2 attempts on topic → move on, document gap
12. Dispatch agents from main thread. Phases 1-5 use Agent tool — never inline
</rules>

---

## Actions

### Phase 0 (main) — Capability Scan

#### 0.1 Language Detection

Scan project for languages w/ 3+ owned source files.

**Exclude from count:** `node_modules/`, `vendor/`, `wwwroot/lib/`, `bin/`, `obj/`, `.nuget/`, `packages/`, `dist/`, `build/`, `__pycache__/`, `.venv/`, `venv/`, `target/`, `.gradle/`, `out/`

Per detected language, record:
- Language + version (from build configs / package manifests)
- Framework(s) + version(s)
- Framework count → decision: 3+ = sub-specialists, 1-2 = single agent
- Test framework + mock library
- File count (owned source only)

#### 0.2 Existing Agent Scan

```bash
# Existing specialists
ls .claude/agents/proj-code-writer-*.md .claude/agents/proj-test-writer-*.md 2>/dev/null
# Existing skills
ls .claude/skills/code-write/SKILL.md .claude/skills/coverage/SKILL.md 2>/dev/null
# Capability index
[[ -f .claude/skills/code-write/references/capability-index.md ]] && echo "exists"
# Generic + legacy unprefixed agents (must delete)
ls .claude/agents/code-writer.md .claude/agents/test-writer.md .claude/agents/code-writer-*.md .claude/agents/test-writer-*.md 2>/dev/null && echo "LEGACY FOUND — will delete"
```

If generic `code-writer.md`, `test-writer.md`, or legacy unprefixed `code-writer-*.md` / `test-writer-*.md` found → DELETE immediately.

#### 0.3 Framework Decision Matrix

Per language, apply:

| Frameworks | Action |
|------------|--------|
| 1-2 | Single `proj-code-writer-{lang}.md` + `proj-test-writer-{lang}.md` |
| 3+ | Parent `proj-code-writer-{lang}.md` + sub-specialists `proj-code-writer-{lang}-{fw}.md` per major framework |

Record decision per language. Document in capability-index.md.

#### 0.4 Create Directories

```bash
mkdir -p .claude/skills/code-write/references
mkdir -p .claude/skills/coverage
mkdir -p .claude/skills/coverage-gaps
mkdir -p .claude/agents/references
```

#### 0.5 Write Initial Capability Index

Write `.claude/skills/code-write/references/capability-index.md`:

```markdown
# Code Writer Capability Index

## Language Manifest
| Language | Version | Framework(s) | Fw Count | Test Framework | Files | Sub-Specialist? |
|----------|---------|-------------|----------|----------------|-------|-----------------|
| {lang} | {ver} | {frameworks} | {N} | {test_fw} | {N} | {yes/no} |

## Existing Agents
- {agent name} — {scope} — last updated {date}

## Coverage Gaps
- {uncovered areas}

## Below Threshold (skipped)
- {lang} — {N} files (threshold: 3)
```

**Checkpoint:** `Phase 0 complete — {N} languages detected, {M} existing agents, sub-specialists planned for: {list}`

---

### Phase 1 (dispatch proj-researcher) — Local Analysis — ALL Languages Simultaneously

Dispatch ONE proj-researcher agent per detected language via `subagent_type="proj-researcher"`, ALL in a single message (parallel Agent calls).

Per language dispatch prompt (using BOOTSTRAP_DISPATCH_PROMPT from Module 01, proj-researcher section):

```
{BOOTSTRAP_DISPATCH_PROMPT — proj-researcher}

Deep-read the {lang} source files in this project. Analyze:
- Component types found (read 3-5 examples of each)
- File naming conventions per component type
- Class/function structure patterns (inheritance, interfaces, decorators)
- Constructor/DI patterns
- Method patterns + error handling approach
- Architecture layers + dependency graph
- Pipeline traces: which files change together for common feature types
- Existing test patterns (naming, structure, setup/teardown, fixtures, mocking)
- Test data patterns + custom utilities/helpers/base classes
- Error handling approach (exceptions? result types? HTTP status codes?)

Read existing proj-code-writer-{lang}.md and proj-test-writer-{lang}.md if they exist —
extract project-specific knowledge to carry forward.

Write findings to .claude/skills/code-write/references/{lang}-analysis.md
structured as YAML blocks per component type.

Include:
- Solution/workspace structure
- Layer identification (API, service, data, contracts, etc.)
- Plugin/LSP/MCP needs for this language
- Build, test, lint, coverage commands

Return path + summary.
```

Wait for ALL Phase 1 dispatches to complete.

Verify: all `{lang}-analysis.md` files exist + non-empty:
```bash
for lang in {detected_languages}; do
  [[ -s ".claude/skills/code-write/references/${lang}-analysis.md" ]] || echo "MISSING: ${lang}-analysis.md"
done
```

**Checkpoint:** `Phase 1 complete — {N} languages analyzed: {summaries}`

---

### Phase 2 (dispatch proj-researcher) — Web Research — ALL Languages Simultaneously

Dispatch ONE proj-researcher agent per detected language via `subagent_type="proj-researcher"`, ALL in a single message (parallel Agent calls).

Per language dispatch prompt:

```
{BOOTSTRAP_DISPATCH_PROMPT — proj-researcher}

Read .claude/skills/code-write/references/{lang}-analysis.md for framework+version info.

Search for current best practices (~15-20 searches) covering ALL categories:

CODE-WRITING TOPICS:
- "{framework} architecture best practices {year}"
- "{language} {framework} coding patterns {year}"
- "{framework} {component_type} best practices" (per major component type)
- "{language} dependency injection {framework}"
- "{framework} error handling patterns"
- "{framework} performance optimization {year}"
- "{framework} security best practices OWASP"
- "{language} language server protocol coding agent"
- "MCP server {framework} {service}"
- "{framework} common mistakes to avoid"

TESTING TOPICS:
- "{language} {test_framework} best practices {year}"
- "{language} {mocking_library} best practices"
- "{language} what to mock unit tests"
- "{framework} integration testing {year}"
- "{language} code coverage tool {year}"
- "{test_framework} async testing patterns"
- "{test_framework} parameterized tests"
- "{mocking_library} common gotchas"

Write findings to .claude/skills/code-write/references/{lang}-research.md.

You MUST print:
- Total search count
- Key findings (5-7 bullets covering both code-writing and testing)
- Gaps: topics where search failed after 2 attempts

Research Quality Checklist:
- Each search returned relevant results
- Findings from 2024+ sources
- Framework version matches project
- Findings don't contradict existing project patterns (note discrepancies)

Return path + summary.
```

Wait for ALL Phase 2 dispatches. Verify: all `{lang}-research.md` non-empty.

**Checkpoint:** `Phase 2 complete — {N} languages researched, {total_searches} searches conducted`

---

### Phase 3 (dispatch proj-code-writer-markdown) — Generate Code Writers — SEQUENTIAL Per Language

For each detected language, dispatch ONE proj-code-writer-markdown agent. SEQUENTIAL — each must complete before next starts. Build verification between dispatches.

Per language dispatch prompt:

```
{BOOTSTRAP_DISPATCH_PROMPT — proj-code-writer-markdown}

Read:
- .claude/skills/code-write/references/{lang}-analysis.md
- .claude/skills/code-write/references/{lang}-research.md
- techniques/agent-design.md (pass-by-reference contract, maxTurns table, agent index schema, MCP tool propagation)

Generate .claude/agents/proj-code-writer-{lang}.md with ALL 9 required sections below.
Use compressed telegraphic notation. Code examples at full fidelity.

YAML frontmatter:
---
name: proj-code-writer-{lang}
description: >
  {Language} code writer specialist for {project}. Use when writing {language}
  code for {list component types}. Knows project conventions, DI patterns,
  error handling, and framework-specific gotchas.
model: opus
effort: high
maxTurns: 100
color: blue
scope: "{comma-separated framework/concern areas}"
parent: ""
---

Tools: OMIT (inherit parent tools incl. MCP — write agent; `agent-scope-lock.md` enforces file-level scope restriction). Do NOT emit a `tools:` line in the frontmatter. Glob-style MCP entries (e.g. `mcp__<server>__<glob>`) are silently ignored by Claude Code at runtime — any explicit `tools:` whitelist would strip MCP access entirely. Inheritance is the only reliable way to grant write agents MCP tools.

Before the 9 sections below, inject the following block immediately after the frontmatter closing `---` (as the FIRST body content, pre-section — do NOT renumber the 9 sections). Replace `{your primary lang}` literally with this agent's language (e.g. `csharp`, `typescript`, `python`, `bash`, `markdown`) so the Read line resolves to the correct `code-standards-{lang}.md` file:

```markdown
## STEP 0 — Load critical rules (MANDATORY first action)

Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

Before any task-specific work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)
- `.claude/rules/code-standards-{your primary lang}.md` (if present)

Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

---
```

REQUIRED 9 SECTIONS (populate every section w/ project-specific content):

## Section 1: Role + Stack
Role: senior {language} specialist for {project}.
Stack: language, version, framework, ORM, test framework, package manager.

## Section 2: Pre-Work (Read-Before-Write) — MANDATORY
1. Read target file (if modifying) | 2-3 similar files (if creating)
2. Read related: base classes, interfaces, configurations
3. Use LSP goToDefinition/findReferences if available
4. Check .claude/rules/{language}-code-standards.md
5. Check scoped CLAUDE.md in target directory (if exists)
6. Verify every type/method planned for use actually exists

## Section 3: Component Classification Tree
Decision tree w/ real code examples from project.
Each leaf: file naming, class structure, DI pattern, method patterns.
Taxonomy-guided: Level 1 (layer) → Level 2 (type) → action.

## Section 4: Writing Code
Sub-sections: naming conventions, structure templates (per component type),
error handling (project's specific pattern), DI registration, guard patterns.
All extracted from actual project files.

## Section 5: Anti-Hallucination Checks
DO NOT / NEVER rules adapted to this language/framework.
Post-writing: build command, LSP verify, run affected tests.
Confidence routing: HIGH → proceed, MEDIUM → verify, LOW → research.

## Section 6: Plugin/LSP/MCP Requirements
LSP plugin + operations, MCP servers, recommended plugins.
Include fallback for when LSP unavailable.

## Section 7: Verification Phase
Build, lint, test commands specific to this project.
Report format: "Build {pass/fail}, {N} tests passed, {M} failed"

## Section 8: Technique References
- techniques/prompt-engineering.md → RCCF, token optimization
- techniques/anti-hallucination.md → verification patterns
- techniques/agent-design.md → subagent constraints

## Section 9: Project-Specific Knowledge (Gotchas)
Framework behaviors, library quirks, namespace conflicts, enum values,
transaction behavior, audit fields, import conflicts — everything
non-obvious discovered during analysis.

## Pass-by-Reference Contract
Write output to target path. Return ONLY: path + 1-line summary <100 chars.
Main reads file only if: needed for next dispatch | error | verification required.

{IF_SUB_SPECIALISTS}
This language has {N} frameworks detected (3+ threshold met).
ALSO generate sub-specialist agents:

Per major framework, create .claude/agents/proj-code-writer-{lang}-{fw}.md:
- Target: 100-200 lines embedded, deep patterns in reference files
- YAML frontmatter:
  ---
  name: proj-code-writer-{lang}-{fw}
  description: >
    {Framework} specialist for {project}. Use when writing {framework}-specific
    code: {scope items}. Knows {framework} patterns, gotchas, component lifecycle.
    Falls back to proj-code-writer-{lang} for cross-cutting concerns.
  model: opus
  effort: high
  maxTurns: 100
  color: blue
  scope: "{framework} components, {pattern1}, {pattern2}"
  parent: proj-code-writer-{lang}
  ---

  Tools: OMIT (same rationale as parent — inherit parent tools incl. MCP; `agent-scope-lock.md` enforces file-level scope restriction). Do NOT emit a `tools:` line.

Sub-specialist sections (all must be populated):
- Role + Stack (framework-scoped)
- Pre-Work: Load References (MANDATORY first action)
- Classification Tree (framework-scoped subset only)
- Anti-Hallucination (framework-specific DO NOT rules)
- Critical Gotchas (top 10-15, framework-specific only)
- Verification (framework-specific build/test commands)
{/IF_SUB_SPECIALISTS}

Write all agent file(s). Return paths + summaries.
```

After each language dispatch completes:
1. Verify agent file(s) exist
2. Check frontmatter has required fields (`name`, `description`, `tools`, `model`, `effort`, `maxTurns`, `scope`)
3. If sub-specialists created: verify each has `parent:` field pointing to `proj-code-writer-{lang}`

**Checkpoint:** `Phase 3 complete — {list of proj-code-writer agents created}`

---

### Phase 4 (dispatch proj-code-writer-markdown) — Generate Test Writers — SEQUENTIAL Per Language

Same sequential pattern as Phase 3. Each language one at a time.

Per language dispatch prompt:

```
{BOOTSTRAP_DISPATCH_PROMPT — proj-code-writer-markdown}

Read:
- .claude/skills/code-write/references/{lang}-analysis.md
- .claude/skills/code-write/references/{lang}-research.md
- techniques/agent-design.md (pass-by-reference contract, MCP tool propagation)

Generate .claude/agents/proj-test-writer-{lang}.md with ALL 8 required sections below.
Use compressed telegraphic notation. Code examples at full fidelity.

YAML frontmatter:
---
name: proj-test-writer-{lang}
description: >
  {Language} test writer specialist for {project}. Use when writing tests,
  improving coverage, or adding test cases for {language} code. Knows
  project test patterns, mocking strategies, and framework-specific gotchas.
model: opus
effort: high
maxTurns: 100
color: green
scope: "{comma-separated test concern areas}"
parent: ""
---

Tools: OMIT (inherit parent tools incl. MCP — write agent; `agent-scope-lock.md` enforces file-level scope restriction). Do NOT emit a `tools:` line in the frontmatter. Glob-style MCP entries (e.g. `mcp__<server>__<glob>`) are silently ignored by Claude Code at runtime — any explicit `tools:` whitelist would strip MCP access entirely. Inheritance is the only reliable way to grant write agents MCP tools.

Before the 8 sections below, inject the following block immediately after the frontmatter closing `---` (as the FIRST body content, pre-section — do NOT renumber the 8 sections). Replace `{your primary lang}` literally with this agent's language (e.g. `csharp`, `typescript`, `python`, `bash`, `markdown`) so the Read line resolves to the correct `code-standards-{lang}.md` file:

```markdown
## STEP 0 — Load critical rules (MANDATORY first action)

Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

Before any task-specific work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/skill-routing.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/agent-scope-lock.md` (enforces strict batch-file scope — NO adjacent work)
- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
- `.claude/rules/max-quality.md` (doctrine — output completeness > token efficiency; full scope; calibrated effort)
- `.claude/rules/code-standards-{your primary lang}.md` (if present)

Rationale: this sub-agent's body replaces the default system prompt. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface. Explicit Read lands content as conversation context and guarantees the policy is in scope. If a referenced rule doesn't exist, note it in the final report and continue — don't stop.

If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

---
```

REQUIRED 8 SECTIONS (populate every section w/ project-specific content):

## Section 1: Introduction Line
One line: language, test framework, mock library, assertion library,
coverage tool — exact version numbers from project manifest.

## Section 2: Analysis Phase (Understand Before Writing)
- Read source file, understand every public method
- Use LSP to trace dependencies (documentSymbol, goToDefinition, findReferences, hover)
- Read project rules/standards files
- Check existing tests for style + patterns to match
- Read project-specific reference docs

## Section 3: Service/Component Classification
Decision tree: pick testing strategy per component type.
Per type found in analysis:
- When this type applies
- Concrete mocking/setup pattern w/ code example from project
- Gotchas specific to this type

| Component Type | Strategy | Mock Boundary |
|----------------|----------|---------------|
| Pure logic | Direct test, no mocks | N/A |
| Service w/ injected deps | Mock interfaces | Constructor params |
| Data access | Integration test | Real DB or mock abstraction |
| API/Controller | Integration test | Test server |
| Infrastructure wrapper | Mock at boundary | External service |

## Section 4: Writing Tests
Sub-sections:
- Structure: AAA (or language equivalent), naming, variable naming (sut, result)
- What to test: happy path, edge cases, error paths, guard clauses, state transitions, dependency failures
- Assertion patterns: success + error assertions using project's error handling
- Code quality DO: extracted helpers, parameterized tests, fresh state, focused files
- Anti-patterns DO NOT: testing private methods, mocking SUT, shared mutable state, over-verifying, testing implementation over behavior

## Section 5: Critical Thinking Phase
Audit code while writing tests:
- Unreachable branches, logic errors (off-by-one, wrong operators)
- Race conditions, missing error handling
- Contract violations, silent data loss
When suspicious: write test documenting actual behavior, log findings,
create GitHub issues for bugs. Do NOT silently work around bugs.

## Section 6: Verification Phase
1. Build/compile test project
2. Run only new tests (filter command for test runner)
3. Diagnose + fix failures
4. Report: total, passed, failed, coverage gaps w/ reasons

## Section 7: Project-Specific Knowledge (Gotchas)
Internal framework behaviors (auto-transactions, event dispatch, audit fields),
library quirks, type/enum naming conflicts, import issues.

## Section 8: Mocking Gotchas
Library-specific mocking pitfalls from research + existing test code.
Include: async mock patterns, interface vs class mocking restrictions,
setup/verify ordering issues, common false-positive patterns.

## Pass-by-Reference Contract
Write output to target path. Return ONLY: path + 1-line summary <100 chars.

{IF_SUB_SPECIALISTS}
This language has {N} frameworks (3+ threshold). ALSO generate sub-specialists:
Per major framework, create .claude/agents/proj-test-writer-{lang}-{fw}.md:
- 100-200 lines, scope: and parent: (= proj-test-writer-{lang}) frontmatter
- Framework-specific test strategy, mocking patterns, gotchas
- Same section structure as parent, scoped to framework
- Tools: OMIT (same rationale as parent — inherit parent tools incl. MCP; `agent-scope-lock.md` enforces file-level scope restriction)
{/IF_SUB_SPECIALISTS}

Write all agent file(s). Return paths + summaries.
```

After each language: verify files exist, check frontmatter, verify parent linkage for sub-specialists.

**Checkpoint:** `Phase 4 complete — {list of proj-test-writer agents created}`

---

### Phase 5 (dispatch proj-code-writer-markdown) — Generate Project Code Reviewer

Single dispatch — reviewer reads ALL language references for cross-project awareness.

```
{BOOTSTRAP_DISPATCH_PROMPT — proj-code-writer-markdown}

Read ALL of these:
- All .claude/skills/code-write/references/{lang}-analysis.md files
- All .claude/skills/code-write/references/{lang}-research.md files
- All .claude/rules/*.md files
- .learnings/log.md (if exists)
- CLAUDE.md (gotchas section)

Generate .claude/agents/proj-code-reviewer.md w/ ALL 9 required sections.
Use compressed telegraphic notation.

YAML frontmatter:
---
name: proj-code-reviewer
description: >
  Deep code review w/ project-specific knowledge. Use after writing code,
  before committing, or when asked to review. Knows architecture layers,
  pipeline traces, security patterns, and common project bugs.
# NOTE — tool whitelist OMITTED per migration 007: reviewer is read-only per role table (techniques/agent-design.md § Skill Dispatch Reliability). Omit the whitelist line entirely → inherits parent + MCP. Edit intentionally dropped: reviewers propose changes via reports, never apply them directly.
model: opus
effort: high
maxTurns: 100
color: yellow
---

## STEP 0 — Load critical rules (MANDATORY first action)

Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

Before any review work, Read these rule files (in parallel where possible):
- `.claude/rules/general.md`
- `.claude/rules/code-standards-markdown.md`
- `.claude/rules/token-efficiency.md`
- `.claude/rules/mcp-routing.md` (if present — routes code discovery through MCP tools)
- `.claude/rules/max-quality.md` (doctrine — the rule THIS agent enforces via § 9 Completeness Check)
- Any language-specific `.claude/rules/code-standards-{lang}.md` files relevant to the files under review

Rationale: the Layer 6 enforcement agent must force-read the rule it enforces. `CLAUDE.md` still loads, but rules reached through `@import` chains may not reliably surface in subagent context. Explicit Read lands content as conversation context and guarantees the doctrine is in scope when § 9 Completeness Check runs. If a referenced rule doesn't exist, note it in the review report and continue.

If `mcp-routing.md` is loaded, it OVERRIDES any `Grep` / `Glob` / `Read`-first examples later in this file. Route through MCP tools per that rule before falling back to text search.

---

REQUIRED 9 SECTIONS:

## 1. Role + Project Context
Senior code reviewer for {project}. Knows architecture, conventions,
security patterns, common mistakes.

## 2. Pre-Review: Read Before Judging
BEFORE reviewing ANY code:
1. Read changed files in full
2. Read applicable rules from .claude/rules/
3. Read CLAUDE.md conventions + gotchas
4. Use LSP for type correctness (if available)
5. Check pipeline traces — is change complete across all layers?

## 3. Review Checklist (per component type)
Build per-component checklist from analysis files.
Each component type gets specific items (entity changes, endpoint changes,
service changes, data access changes, etc.).
All items project-specific — not generic checklists.

## 4. Security Review
- No hardcoded secrets/credentials
- No SQL/command injection
- No XSS (output encoding)
- Auth applied to all new endpoints
- Authz scopes user to their data
- No sensitive data in logs/errors
- File uploads validated
- Rate limiting considered

## 5. Architecture Review
- Dependencies flow correct direction
- No circular references
- New types in correct project/layer
- Interface defined for new services
- Service registered in DI

## 6. Common Project Bugs (from .learnings/)
Generate from .learnings/log.md — past mistakes as review items.

## 7. Report Format
### Pipeline Completeness: {COMPLETE / INCOMPLETE}
### Issues
- MUST FIX: {issue} — {file}:{line}
- SHOULD FIX: {issue} — {file}:{line}
- CONSIDER: {issue} — {file}:{line}
### Security: {PASS / ISSUES}
### Architecture: {PASS / ISSUES}
### Positives
### Verdict: {APPROVE / REQUEST CHANGES}

Log-Ready Finding Schema (for systematic findings):
### {date} — review-finding: {pattern name}
Status: pending review
Agent: {agent-name}
Pattern: {what rule violated}
Evidence: {file}:{line} — {description}
Domain: {code-style | security | architecture | testing | tooling}

## 8. Anti-Hallucination
- Only cite rules that EXIST in .claude/rules/ — read them first
- Only report line numbers for lines that EXIST — read file first
- Never invent security issues not actually present
- Use LSP to verify type issues before reporting
- If unsure about standard → check rules before citing

## 9. Completeness Check (Max Quality Doctrine enforcement)
Reviewer is the enforcement layer for `.claude/rules/max-quality.md`. Hook-based regex
checks lack LLM context judgment — TODO-link validation and weeks/days effort-context
detection live HERE, not in any Layer 2 hook.

Binary checklist (evaluate Y/N per file reviewed):
- All listed parts addressed? (every checklist item, every Files entry, every contract
  bullet — any omission = FAIL) → Y/N
- Pseudocode substitutions present? (any `// TODO: implement`, stub return, placeholder
  body masquerading as implementation) → Y/N
- `TODO:` markers without linked issue present? (reviewer evaluates w/ LLM judgment:
  `TODO: #123` or `TODO: link-to-issue` = PASS, bare `TODO:` or `TODO: will do later`
  = FAIL) → Y/N
- "for brevity" / elision phrases present? (`...`, `rest unchanged`, `for brevity`,
  `omitted for clarity`, `you get the idea` in delivered code/content) → Y/N
- Effort-pad language in effort-estimate context? (reviewer evaluates w/ LLM context
  judgment: `7 days` in cron config = PASS, `this will take 2 weeks` in a task
  description = FAIL) → Y/N
  Banned phrases in effort context: `days`, `weeks`, `months`, `significant time`,
  `complex effort`, `substantial effort`, `large undertaking`, `major investment`,
  `considerable work`, `non-trivial amount of time`.
  Carve-out: literal data values inside code/config (cron windows, retention periods,
  sleep durations) are NOT effort estimates and do not fail this check.

Reviewer LLM context advantage: hook regex cannot distinguish `TODO: #123` from bare
`TODO:`, cannot distinguish `7 days retention` config from `this will take 2 weeks`
effort narrative. Reviewer can. This is why TODO + effort-context detection MUST live
at the reviewer layer, NOT in a Layer 2 hook. Layer 2 hook remains regex-only
(trivially detectable patterns like `for brevity`, `...` ellipsis, `rest unchanged`).

Output line (append to Report Format §7 in the final reviewer output):
`COMPLETENESS: PASS|FAIL` — PASS only if all 5 checks are N (no violations found).
Any Y answer on the checklist → COMPLETENESS: FAIL + itemize the violations in the
MUST-FIX section alongside other blocking issues.

ALSO generate:
.claude/agents/references/review-checklist.md — full per-component-type checklist
(loadable separately, referenced by other agents).

Write files. Return paths + summaries.
```

**Checkpoint:** `Phase 5 complete — proj-code-reviewer.md + review-checklist.md generated`

---

### Phase 6 (main) — Agent Index + References + Skills

Main thread generates the wiring artifacts. No agent dispatch — these require reading all agent frontmatter.

#### 6.1 Generate Agent Index

Read all agent frontmatter:
```bash
for f in .claude/agents/*.md; do
  echo "=== $(basename "$f") ==="
  head -20 "$f" | grep -E "^name:|^model:|^scope:|^parent:|^description:"
done
```

Determine agent type from filename:
- `proj-code-writer-*` → type: code-writer
- `proj-test-writer-*` → type: test-writer
- `proj-code-reviewer` → type: review
- All others → type: utility

Write `.claude/agents/agent-index.yaml`:

```yaml
# Agent Index — generated by Module 07, updated by /evolve-agents
# Read by orchestrators for dispatch decisions
agents:
  - name: proj-code-writer-{lang}
    scope: "{lang} general — all components"
    model: opus
    parent: null
    type: code-writer
    last-updated: {today}
  - name: proj-code-writer-{lang}-{fw}
    scope: "{framework}-specific: {areas}"
    model: opus
    parent: proj-code-writer-{lang}
    type: code-writer
    last-updated: {today}
  - name: proj-test-writer-{lang}
    scope: "{lang} tests — all component types"
    model: opus
    parent: null
    type: test-writer
    last-updated: {today}
  - name: proj-code-reviewer
    scope: "all languages — architecture, security, pipeline completeness"
    model: opus
    parent: null
    type: review
    last-updated: {today}
  # ... all specialist agents
```

#### 6.2 Update Pipeline Traces

Write `.claude/skills/code-write/references/pipeline-traces.md`:

Per feature type found during Phase 1 analysis, trace through all layers:

```markdown
## Pipeline Traces

### {feature-type}
Language: {lang}
Files (in order):
1. {path/pattern} — {action}
2. {path/pattern} — {action}
...

### Example: new-entity (.NET)
Files (in order):
1. Data/Entities/{Entity}.cs — create entity record
2. Data/Configurations/{Entity}Configuration.cs — EF config
3. [Migration] — dotnet ef migrations add Add{Entity}
4. Contracts/{Entity}Dto.cs — create DTO
...

### Example: new-component (React/TS)
Files (in order):
1. src/components/{Component}/{Component}.tsx — component
2. src/components/{Component}/{Component}.test.tsx — tests
3. src/components/{Component}/{Component}.module.css — styles
4. src/components/index.ts — re-export
...
```

#### 6.3 Update Capability Index

Update `.claude/skills/code-write/references/capability-index.md` w/ all generated agents:
- Full inventory (name, scope, parent, type, file path)
- Coverage summary per language
- Remaining gaps

#### 6.4 Generate Code-Write Orchestrator Skill

Write `.claude/skills/code-write/SKILL.md`:

```yaml
---
name: code-write
description: >
  Use when implementing features, writing code, adding functionality, building
  components, or creating new files. Orchestrates language-specific code writers
  for cross-layer features. Analyzes request, maps pipeline trace, dispatches
  specialist agents in dependency order.
allowed-tools: Agent Read
model: opus
effort: high
paths: "src/**"
---
```

Frontmatter contract (per migration 007 + techniques/agent-design.md § Skill Dispatch Reliability): main-thread orchestrator → omit the `context` and `agent` fields entirely. `allowed-tools: Agent Read` only — orchestrator dispatches specialists and reads pipeline traces/agent-index; it does NOT write files itself (agents do).

Skill body sections:

0. **{PRE_FLIGHT_GATE_BLOCK — see top of modules/06-skills.md}** — FIRST executable step. Verify every agent in Dispatch Map exists under `.claude/agents/`; STOP w/ install instructions if missing. No inline fallback.

**Dispatch Map** (agents dispatched by this skill):
- Step 5 (code write): `proj-code-writer-{lang}` (+ sub-specialists `proj-code-writer-{lang}-{fw}` where scope matches)
- Step 6 (tests): `proj-test-writer-{lang}`
- Step 7 (review): `proj-code-reviewer`

1. **Feature Analysis** — what kind of feature? What layers affected?
2. **Agent Discovery** — BEFORE every dispatch:
   1. Read `.claude/agents/agent-index.yaml` for inventory
   2. Match request against `scope` field: exact match → sub-specialist; language-only → parent; no match → STOP per pre-flight gate
   3. Read `references/capability-index.md` for gap awareness
3. **Pipeline Trace Lookup** — read `references/pipeline-traces.md` for feature type
4. **File Change Map** — list every file to change, in order
5. **Specialist Dispatch** — `subagent_type="proj-code-writer-{lang}"` — do not perform inline. If no `proj-code-writer-{lang}` matches → STOP per pre-flight gate, instruct user to run `/evolve-agents` or `/migrate-bootstrap`. NEVER fall back to inline execution.
6. **Test Dispatch** — after code: `subagent_type="proj-test-writer-{lang}"` for affected code
7. **Review Dispatch** — after all specialists: dispatch proj-code-reviewer
8. **Cross-Layer Verification** — build all, run tests
9. **Anti-Hallucination** — verify all file paths exist before dispatching

#### 6.5 Generate Coverage Skills

**Coverage skill** — `.claude/skills/coverage/SKILL.md`:

```yaml
---
name: coverage
description: "Run code coverage on test projects and display a summary report. Use when the user says /coverage or asks about test coverage."
---
```

Content: language-aware coverage commands from `{lang}-analysis.md` files. Include clean → run → report steps per detected test framework.

**Coverage gaps skill** — `.claude/skills/coverage-gaps/SKILL.md`:

```yaml
---
name: coverage-gaps
description: "Parse coverage data to show uncovered lines per class/function. Use when the user says /coverage-gaps or asks what's missing from coverage."
---
```

Content: parse coverage format, display uncovered lines grouped by class/module, optional filter.

#### 6.6 Wire /review Skill

Update `.claude/skills/review/SKILL.md` (if exists from Module 06):
Set dispatch target to `proj-code-reviewer` agent.

**Checkpoint:** `Phase 6 complete — agent-index.yaml ({N} entries), pipeline-traces ({M} patterns), coverage skills, orchestrator skill generated`

---

## Verification Checklist

**Code Writer Agents:**
- [ ] Each `proj-code-writer-{lang}.md` has all 9 required sections w/ project-specific content
- [ ] No generic placeholder text — all code examples from actual project
- [ ] Classification trees cover all detected component types
- [ ] Anti-hallucination sections present in every specialist
- [ ] Sub-specialists (if any) have `scope:` + `parent:` in frontmatter

**Test Writer Agents:**
- [ ] Each `proj-test-writer-{lang}.md` has all 8 required sections
- [ ] Introduction line has exact version numbers
- [ ] Mocking gotchas section populated w/ real findings
- [ ] Critical thinking phase included

**Code Reviewer:**
- [ ] `proj-code-reviewer.md` has all 9 sections (incl. Completeness Check)
- [ ] Per-component checklist generated from actual component types
- [ ] Known gotchas from `.learnings/log.md` included
- [ ] Review-checklist reference file generated

**Negative Guard:**
- [ ] No generic `code-writer.md` exists → DELETE if found
- [ ] No generic `test-writer.md` exists → DELETE if found

**Agent Index:**
- [ ] `agent-index.yaml` lists ALL specialist agents
- [ ] Every agent has scope, model, parent, type, last-updated
- [ ] Sub-specialist parent references resolve to existing agents

**Reference Artifacts:**
- [ ] All `{lang}-analysis.md` files exist + non-empty
- [ ] All `{lang}-research.md` files exist + non-empty
- [ ] Pipeline traces reference correct paths
- [ ] Capability index is current w/ all agents

**Skills:**
- [ ] Orchestrator `/code-write` has Agent Discovery protocol
- [ ] Coverage skills use project-specific commands
- [ ] `/review` wired to `proj-code-reviewer`

**Build:**
- [ ] Build command works (verify by running)

---

## Integration

**Consumes from earlier modules:**
- Module 01 (`modules/01-discovery.md`) — languages, frameworks, architecture, foundation agents (proj-researcher, proj-code-writer-markdown, proj-code-writer-bash)
- Module 02 (`modules/02-project-config.md`) — CLAUDE.md, rules
- Module 04 (`modules/04-learnings.md`) — `.learnings/` structure
- Module 05 (`modules/05-core-agents.md`) — 7 core utility/diagnostic agents (proj-quick-check, proj-verifier, etc.)
- Module 06 (`modules/06-skills.md`) — `/code-write`, `/review`, `/coverage`, `/coverage-gaps` skill stubs

**Produces for later modules:**
- Module 08 (`modules/08-verification.md`) — agent-index.yaml, all agents for wiring verification
- `/evolve-agents` skill (from Module 06) — post-bootstrap audit consumes agent-index.yaml + reference files

---

## Checkpoint

```
✅ Module 07 complete — Code specialist pipeline
  Languages: {list}
  Code writers: {list} ({N} sub-specialists)
  Test writers: {list} ({N} sub-specialists)
  Code reviewer: proj-code-reviewer.md
  Agent index: agent-index.yaml ({N} entries)
  Coverage skills: updated
  Pipeline traces: {N} patterns
```
