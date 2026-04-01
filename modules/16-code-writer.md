# Module 16 — Generate Code Writer + Test Writer Agents

> Generate per-language code-writer and test-writer specialist agents, an orchestrator skill,
> coverage skills, and supporting reference artifacts. Uses discovery context from Module 01,
> rules from Module 03, and dispatches agents from the main thread for quality.

---

## Idempotency

Per agent/skill file: read existing content, extract project-specific knowledge (component types, patterns, gotchas), merge w/ current template, regenerate.

## What This Produces

| Output | Path | Purpose |
|--------|------|---------|
| Per-language analysis refs | `.claude/skills/code-write/references/{lang}-analysis.md` | Local codebase findings per language |
| Per-language research refs | `.claude/skills/code-write/references/{lang}-research.md` | Web research findings per language |
| Orchestrator skill | `.claude/skills/code-write/SKILL.md` | `/code-write` dispatcher |
| Pipeline traces | `.claude/skills/code-write/references/pipeline-traces.md` | Feature-type → file mapping |
| Capability index | `.claude/skills/code-write/references/capability-index.md` | Agent inventory + gaps |
| Language specialists | `.claude/agents/code-writer-{lang}.md` | Per-language code writers (9 sections each) |
| Test specialists | `.claude/agents/test-writer-{lang}.md` | Per-language test writers (8 sections each) |
| Coverage skill | `.claude/skills/coverage/SKILL.md` | `/coverage` command |
| Coverage gaps skill | `.claude/skills/coverage-gaps/SKILL.md` | `/coverage-gaps` command |

The generated system is **not generic** — it encodes your project's specific architecture layers, pipeline traces, component types, framework patterns, DI strategies, error handling, naming conventions, mocking strategies, and test infrastructure. The orchestrator knows which files change together for each feature type. The specialists know how to write code and tests that a senior engineer on your team would recognize as idiomatic.

---

## How It Works

Nine phases (0-8), executed in order. Phases 1-4 repeat per detected language. Phases 3+4 dispatch in parallel within each language.

0. **Capability Scan** — detect languages, check existing agents, identify gaps
1. **Local Analysis** (per lang) — dispatch `researcher` agent to deep-read codebase
2. **Web Research** (per lang) — dispatch `researcher` agent for current best practices
3. **Generate Code Writer** (per lang) — dispatch `code-writer-markdown` agent
4. **Generate Test Writer** (per lang) — dispatch `code-writer-markdown` agent (PARALLEL w/ Phase 3)
5. **Generate Orchestrator** — create `/code-write` skill, pipeline traces, capability index
6. **Generate Coverage Skills** — create `/coverage` + `/coverage-gaps` skills
7. **Update Code Reviewer** — verify reference artifacts ready for Module 17
8. **Verification** — validate all outputs against project reality

---

## What Makes a Good Code Writer + Test Writer System

The generated agents should enable an AI to:
- **Match existing conventions exactly** — naming, structure, patterns extracted from real project files
- **Know the full pipeline** — adding a field means tracing through all affected layers
- **Pick the right strategy per component** — different component types get different patterns
- **Discover bugs, not just confirm code runs** — critical thinking phase in test writers
- **Verify before presenting** — read-before-write, LSP checks, build verification, never fabricates APIs
- **Know project-specific gotchas** — framework internals, library quirks, mocking pitfalls
- **Document requirements** — which LSP plugins, MCP servers, and tools each agent needs

---

<role>
You are a senior engineering lead creating a comprehensive code writing AND test writing system for this project. You combine deep knowledge of software architecture and testing methodology with meticulous codebase analysis and current research. You read existing code to extract patterns rather than imposing conventions. You understand that the most valuable output is project-specific knowledge — the pipeline traces, classification trees, mocking strategies, and gotchas that would otherwise take hours to discover.
</role>

<task>
Execute ALL phases below to produce a complete, project-specific code writing and test writing system. Every output must be grounded in what you discovered during analysis and research — no generic filler. The agents you produce will be used repeatedly to write production code and tests across the entire codebase, so invest heavily in accuracy and specificity.

**Execution model:** You are the orchestrator on the main thread. Use the Agent tool to dispatch `researcher` and `code-writer-markdown` agents for Phases 1-4. Do NOT perform analysis, research, or agent generation inline — the agents ARE the quality layer.
</task>

<rules>
1. Execute phases in order. Do not skip the research phase.
2. After each phase, print a checkpoint: `Phase N complete — {summary}`
3. If you need clarification from the user, STOP and ask before continuing.
4. Every code example must come from the actual project, not invented.
5. Do not invent patterns that contradict what exists in the project.
6. All generated files must use YAML frontmatter with required fields.
7. Every agent must include anti-hallucination sections (read-before-write, verification, negative instructions).
8. Every agent must document its plugin/LSP/MCP requirements.
9. Reference techniques/ docs for prompt engineering and anti-hallucination patterns.
10. When web research fails after 2 attempts on a topic, move on — don't block on a single search.
11. Write all generated agent/skill content in compressed telegraphic notation — Claude is the only reader. Strip articles/filler, use symbols (→ | + ~), key:value over sentences. Exception: code examples + few-shot patterns keep full fidelity. See `techniques/prompt-engineering.md` → Token Optimization.
12. For inter-stage data formats when only consumer is Claude: YAML for hierarchical data (11-20% savings vs JSON), TSV/TOON for flat/tabular arrays (30-60% savings), markdown for mixed prose+structure (16-38% savings). JSON only when tooling requires it.
13. **NEVER create generic `code-writer.md` or `test-writer.md`.** All agents MUST be `code-writer-{lang}.md` and `test-writer-{lang}.md`. If a generic file already exists, delete it.
14. **Every language with 3+ owned source files MUST get both specialists.** Skip languages below threshold but document in capability-index.md.
15. **Dispatch agents from main thread.** Phases 1-4 use Agent tool to dispatch researcher and code-writer-markdown agents. Do NOT attempt to do analysis/research/generation inline — the agents ARE the quality layer.
16. **Phases 3+4 MUST dispatch in parallel.** Use two Agent tool calls in a single message — they write different files and read the same inputs.
</rules>

---

## Phase 0 — Capability Scan

Before creating anything, detect languages and check what already exists.

### 0.1 Language Detection

Scan the project for languages with 3+ owned source files.

**Exclude from file count:** `node_modules/`, `vendor/`, `wwwroot/lib/`, `bin/`, `obj/`, `.nuget/`, `packages/`, `dist/`, `build/`, `__pycache__/`, `.venv/`, `venv/`

Per detected language, record:
- Language name
- Version (from build configs / package manifests)
- Framework(s) + version(s)
- Test framework + mock library
- File count (owned source files only)

### 0.2 Existing Agent Scan

1. Scan `.claude/agents/` for existing agents: `code-writer-*.md`, `test-writer-*.md`
2. Scan `.claude/skills/` for existing `code-write/SKILL.md`, `coverage/SKILL.md`, `coverage-gaps/SKILL.md`
3. If capability index exists at `.claude/skills/code-write/references/capability-index.md`, read it
4. Check for generic `code-writer.md` or `test-writer.md` — if found, mark for deletion

### 0.3 Output

Store language manifest + coverage gaps. Format:

```markdown
# Code Writer Capability Index

## Language Manifest
| Language | Version | Framework | Test Framework | File Count |
|----------|---------|-----------|----------------|------------|
| {lang} | {ver} | {framework} | {test_fw} | {N} |

## Existing Agents
- {agent name} — {language/purpose} — last updated {date}

## Coverage Gaps
- {language/area not yet covered}

## Below Threshold (skipped)
- {lang} — {N} files (threshold: 3)
```

**Checkpoint:** `Phase 0 complete — {N} languages detected, {M} existing agents found`

---

## Phases 1-4 — Per-Language Agent Generation

**For each detected language** (sequential — each language completes all sub-phases before starting the next):

### Phase 1 — Local Analysis (dispatch `researcher` agent)

Dispatch a `researcher` agent with this prompt template:

```
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

Write findings to `.claude/skills/code-write/references/{lang}-analysis.md`
structured as YAML blocks per component type.

Include:
- Solution/workspace structure
- Layer identification (API, service, data, contracts, etc.)
- Plugin/LSP/MCP needs for this language
- Build, test, lint, coverage commands

Read existing code-writer-{lang}.md and test-writer-{lang}.md if they exist —
extract project-specific knowledge to carry forward.
```

**Checkpoint:** `Phase 1 ({lang}) complete — {N} component types, {M} patterns extracted`

### Phase 2 — Web Research (dispatch `researcher` agent — MANDATORY)

Dispatch a `researcher` agent with this prompt template:

```
Read `.claude/skills/code-write/references/{lang}-analysis.md` for framework+version info.

Search for current best practices (~15-20 searches) covering ALL of these categories:

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

Write findings to `.claude/skills/code-write/references/{lang}-research.md`.

You MUST print:
- Total search count
- Key findings (5-7 bullets covering both code-writing and testing)
- Gaps: topics where search failed after 2 attempts

Research Quality Checklist:
- Each search returned relevant results
- Findings from 2024+ sources
- Framework version matches project
- Findings don't contradict existing project patterns (note discrepancies)
```

**Checkpoint:** `Phase 2 ({lang}) complete — {N} searches, key findings: {summary}`

### Phases 3+4 — Generate Specialists (dispatch TWO `code-writer-markdown` agents IN PARALLEL)

These MUST be dispatched in a single message (parallel Agent calls) — they read the same inputs and write different files.

**Agent A — Code Writer Specialist:**

```
Read `.claude/skills/code-write/references/{lang}-analysis.md` and
`.claude/skills/code-write/references/{lang}-research.md`.

Generate `.claude/agents/code-writer-{lang}.md` with ALL 9 required sections below.
Use compressed telegraphic notation. Code examples at full fidelity.

YAML frontmatter:
---
name: code-writer-{lang}
description: >
  {Language} code writer specialist for {project}. Use when writing {language}
  code for {list component types}. Knows project conventions, DI patterns,
  error handling, and framework-specific gotchas.
tools: Read, Write, Edit, Bash, Grep, Glob, LSP, WebSearch
model: opus
effort: medium
maxTurns: 30
color: blue
---

REQUIRED SECTIONS (populate every section with project-specific content):

## Section 1: Role + Stack
- Role statement: senior {language} specialist for {project}
- Stack: language, version, framework, ORM, test framework, package manager

## Section 2: Analysis Phase (Read-Before-Write)
MANDATORY pre-writing checklist:
1. Read target file (if modifying) | 2-3 similar files (if creating)
2. Read related files: base classes, interfaces, configurations
3. Use LSP goToDefinition/findReferences if available
4. Check .claude/rules/{language}-code-standards.md
5. Check scoped CLAUDE.md in target directory (if exists)
6. Verify every type/method planned for use actually exists

## Section 3: Component Classification Tree
Decision tree w/ real code examples from the project.
Each leaf: file naming, class structure, DI pattern, method patterns.
Use taxonomy-guided prompting (Level 1: layer → Level 2: type → action).

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
discovered during analysis that's non-obvious.
```

**Agent B — Test Writer Specialist:**

```
Read `.claude/skills/code-write/references/{lang}-analysis.md` and
`.claude/skills/code-write/references/{lang}-research.md`.

Generate `.claude/agents/test-writer-{lang}.md` with ALL 8 required sections below.
Use compressed telegraphic notation. Code examples at full fidelity.

YAML frontmatter:
---
name: test-writer-{lang}
description: >
  {Language} test writer specialist for {project}. Use when writing tests,
  improving coverage, or adding test cases for {language} code. Knows
  project test patterns, mocking strategies, and framework-specific gotchas.
tools: Read, Write, Edit, Bash, Grep, Glob, LSP
model: opus
effort: high
maxTurns: 30
color: green
---

REQUIRED SECTIONS (populate every section with project-specific content):

## Section 1: Introduction Line
One line: language, test framework, mock library, assertion library,
coverage tool — with exact version numbers from project manifest.

## Section 2: Analysis Phase (Understand Before Writing)
- Read source file, understand every public method
- Use LSP to trace dependencies (documentSymbol, goToDefinition, findReferences, hover)
- Read project rules/standards files
- Check existing tests for style + patterns to match
- Read any project-specific reference docs

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
- What to test: happy path, edge cases, error paths, guard clauses,
  state transitions, dependency failures
- Assertion patterns: success + error assertions using project's error handling
- Code quality DO: extracted helpers, parameterized tests, fresh state, focused files
- Anti-patterns DO NOT: testing private methods, mocking SUT, shared mutable state,
  over-verifying, testing implementation over behavior

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
library quirks, type/enum naming conflicts, import issues — everything
that wastes hours when you don't know it.

## Section 8: Mocking Gotchas
Library-specific mocking pitfalls from research + existing test code.
Include: async mock patterns, interface vs class mocking restrictions,
setup/verify ordering issues, common false-positive patterns.
```

**Checkpoint:** `Phases 3-4 ({lang}) complete — code-writer-{lang}.md + test-writer-{lang}.md generated`

---

## Phase 5 — Generate Orchestrator Skill

After all languages complete Phases 1-4, create the orchestrator on the main thread.

### 5.1 Read All Analysis Files

Read all `{lang}-analysis.md` files to build cross-language knowledge.

### 5.2 Create/Update `.claude/skills/code-write/SKILL.md`

```yaml
---
name: code-write
description: >
  Use when implementing features, writing code, adding functionality, building
  components, or creating new files. Orchestrates language-specific code writers
  for cross-layer features. Analyzes the request, maps the pipeline trace, and
  dispatches specialist agents in dependency order.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob, Skill
model: opus
effort: high
paths: "src/**"
---
```

### Content Sections

1. **Feature Analysis** — Decision tree: what kind of feature? What layers affected?
2. **Pipeline Trace Lookup** — Read `references/pipeline-traces.md` for the feature type
3. **File Change Map** — List every file that needs to change, in order
4. **Specialist Dispatch** — Step 4 MUST read: "MUST dispatch the appropriate code-writer-{lang} agent — do not perform this work inline". Exception: if no code-writer-* agents exist, include fallback clause allowing main-thread execution.
5. **Test Dispatch** — After code writing: dispatch test-writer-{lang} for affected code (or note for user to invoke separately)
6. **Cross-Layer Verification** — After all specialists complete: build all, run tests
7. **Anti-Hallucination** — Verify all file paths exist before dispatching

### 5.3 Create/Update `references/pipeline-traces.md`

Per feature type found during analysis, trace through all layers. Use language-agnostic format w/ concrete examples:

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

### 5.4 Update Capability Index

Update `.claude/skills/code-write/references/capability-index.md` with all generated agents.

**Checkpoint:** `Phase 5 complete — orchestrator skill with {N} pipeline traces`

---

## Phase 6 — Generate Coverage Skills

Create coverage skills. These are language-aware — detect which coverage tooling to use from the analysis files.

### 6.1 Coverage Skill

Create `.claude/skills/coverage/SKILL.md`:

```yaml
---
name: coverage
description: "Run code coverage on test projects and display a summary report. Use when the user says /coverage or asks about test coverage."
---
```

Content must include:
1. Which test projects to cover (exclude integration tests requiring external resources)
2. Commands to clean previous results, run tests w/ coverage, generate reports
3. How to display summary
4. All commands use project's actual test runner + coverage tool
5. Multi-language support if project has multiple test frameworks

### 6.2 Coverage Gaps Skill

Create `.claude/skills/coverage-gaps/SKILL.md`:

```yaml
---
name: coverage-gaps
description: "Parse coverage data to show uncovered lines per class/function. Use when the user says /coverage-gaps or asks what's missing from coverage."
---
```

Content must include:
1. How to verify coverage data exists
2. Script (in project's language or Python fallback) to parse coverage format and display:
   - Classes/modules w/ uncovered lines, sorted by gap size
   - Line ranges grouped for readability
   - Fully covered classes as summary
3. Optional filter by class/module name
4. Instructions to read source at uncovered lines when user asks about specific gaps

**Checkpoint:** `Phase 6 complete — coverage skills generated`

---

## Phase 7 — Update Code Reviewer

Module 17 (code reviewer) uses the per-language reference artifacts generated here. Verify:

1. `.claude/skills/code-write/references/` directory exists w/ all `{lang}-analysis.md` files
2. All `code-writer-{lang}.md` and `test-writer-{lang}.md` agents exist
3. Pipeline traces reference correct paths

Do NOT generate the code reviewer agent — that's Module 17's job.

**Checkpoint:** `Phase 7 complete — reference artifacts ready for Module 17`

---

## Phase 8 — Verification

### Checklist

**Code Writer Agents:**
- [ ] Each `code-writer-{lang}.md` has all 9 required sections w/ project-specific content
- [ ] No generic placeholder text — all code examples from actual project
- [ ] Plugin/LSP/MCP requirements accurate for each specialist
- [ ] Classification trees cover all detected component types
- [ ] Anti-hallucination sections present in every specialist
- [ ] Technique reference section present in every specialist

**Test Writer Agents:**
- [ ] Each `test-writer-{lang}.md` has all 8 required sections w/ project-specific content
- [ ] Introduction line has exact version numbers
- [ ] Mocking gotchas section populated w/ real findings
- [ ] Critical thinking phase included (not just "run tests")
- [ ] Component classification covers all types found in project

**Negative Guard:**
- [ ] No generic `code-writer.md` exists (if found → DELETE)
- [ ] No generic `test-writer.md` exists (if found → DELETE)

**Reference Artifacts:**
- [ ] All `{lang}-analysis.md` files exist
- [ ] All `{lang}-research.md` files exist
- [ ] Pipeline traces reference correct paths
- [ ] Capability index is current

**Skills:**
- [ ] Orchestrator skill has YAML frontmatter (name, description)
- [ ] Orchestrator references pipeline-traces.md correctly
- [ ] Coverage skill uses correct build/test commands
- [ ] Coverage gaps skill parses correct coverage format
- [ ] Skill routing hook lists /code-write

**Build:**
- [ ] Build command works (verify by running it)

### Smoke Test

Run through one mental scenario per generated language:
"If the user says 'add a new field X to entity Y', does the system know:
1. Which pipeline trace to use?
2. Which files to create/modify?
3. Which code-writer specialist to dispatch?
4. Which test-writer specialist to dispatch for new tests?
5. In what order?
6. How to verify the result?"

**Checkpoint:** `Phase 8 complete — all checks passed`

✅ Module 16 complete — per-language code-writer and test-writer agents, coverage skills, pipeline traces, and reference artifacts generated and verified

---

## Component Classification — Multi-Language Examples

### Generic Template
```
Component Types:
├── {TypeA}
│   ├── Subtypes found in project
│   ├── Naming: {convention}
│   └── Related files: {co-occurring files}
├── {TypeB}
│   ├── Subtypes
│   └── Naming: {convention}
└── [more per project...]
```

### Example: .NET Project
```
Component Types:
├── Endpoint (FastEndpoints)
│   ├── AuthenticatedEndpoint<TReq, TRes>
│   ├── AdminEndpoint<TReq, TRes>
│   └── Naming: {Action}.cs in Endpoints/{Entity}/
├── Service
│   ├── Type A: Simple (single IDataService)
│   ├── Type B: Complex (multiple deps)
│   ├── Type C: CrudServiceBase extension
│   └── Naming: {Entity}Service.cs in Services/Data/{Entity}/
├── Entity
│   ├── DomainEntity<Guid> base
│   └── Naming: {Name}.cs in Data/Entities/
└── Configuration
    ├── IEntityTypeConfiguration<T>
    └── Naming: {Entity}Configuration.cs in Data/Configurations/
```

### Example: TypeScript/React Project
```
Component Types:
├── Component
│   ├── Page component (route-level)
│   ├── Feature component (business logic)
│   ├── UI component (presentational)
│   └── Naming: {Name}.tsx in src/components/{Name}/
├── Hook
│   ├── Data hook (API calls)
│   ├── State hook (local state logic)
│   └── Naming: use{Name}.ts in src/hooks/
├── Service
│   ├── API service (HTTP client wrapper)
│   └── Naming: {name}.service.ts in src/services/
└── Store
    ├── Slice (Redux) | Atom (Jotai) | Store (Zustand)
    └── Naming: {name}.store.ts in src/store/
```

---

## Integration

This module uses context from earlier modules:
- Discovery results from Module 01 (languages, frameworks, architecture)
- Rules from Module 03 (code standards per language)
- Base agents from Module 10 (these specialists complement them — `researcher` and `code-writer-markdown` are dispatched here)
- Skill routing generated by Module 14 (includes /code-write after this module runs)
- /reflect from Module 05 monitors and evolves the generated agents, watches for drift in `{lang}-analysis.md` references

This module produces artifacts consumed by:
- Module 17 (code reviewer) — uses per-language references for deep project-specific review
