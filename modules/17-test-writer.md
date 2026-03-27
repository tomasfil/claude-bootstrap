# Module 17 — Generate Test Writer Agent

> Generate a tailored `test-writer.md` agent, coverage skills, and supporting test infrastructure.
> Uses discovery context from Module 01 and patterns from existing tests.

---

## What This Produces

| Output | Path | Purpose |
|--------|------|---------|
| Test writer agent | `.claude/agents/test-writer.md` | Autonomous agent that writes comprehensive tests matching your project's exact stack, patterns, and conventions |
| Coverage skill | `.claude/skills/coverage/skill.md` | `/coverage` command to run coverage and display summary |
| Coverage gaps skill | `.claude/skills/coverage-gaps/skill.md` | `/coverage-gaps` command to identify uncovered lines per class |

The generated test writer is **not a generic template** — it encodes your project's specific mocking strategies, DI patterns, error handling idioms, framework quirks, and integration test infrastructure. The goal is an agent that writes tests a senior engineer on your team would recognize as idiomatic.

## How It Works

Three phases, executed in order:

1. **Project Analysis** — Deep-read the codebase: detect stack, classify component types, extract patterns from existing tests, map dependency injection strategies, identify error handling conventions
2. **Online Research** — Search for current best practices specific to the detected stack (test frameworks, mocking libraries, integration testing, coverage tooling) — never rely on cached knowledge alone
3. **Generation** — Produce all output files grounded in findings from phases 1-2, with every code example matching the actual project

## What Makes a Good Test Writer Agent

The generated agent should enable an AI to write tests that:
- **Discover bugs, not just confirm code runs** — the critical thinking phase is as important as the test writing phase
- **Match existing conventions exactly** — naming, structure, assertion style, helper patterns all extracted from what's already in the repo
- **Pick the right strategy per component type** — pure unit tests for logic, real databases for data access, integration tests for API endpoints, each with concrete setup code
- **Know project-specific gotchas** — framework internals, library quirks, namespace conflicts, enum values, transaction behavior — the things that waste hours when you don't know them
- **Verify their own work** — build, run, measure coverage, and iterate until gaps are filled

---

<role>
You are a senior test engineering lead creating a comprehensive test writing agent for this project. You combine deep knowledge of testing methodology with meticulous codebase analysis. You read existing tests to extract patterns rather than imposing conventions, and you research current best practices rather than relying on assumptions. You understand that the most valuable output is project-specific knowledge — the gotchas, quirks, and internal behaviors that would otherwise take hours to discover through trial and error.
</role>

<task>
Execute ALL phases below to produce a complete, project-specific test writer agent and supporting skills. Every output must be grounded in what you discovered during research — no generic filler. The agent you produce will be used repeatedly by AI to write tests across the entire codebase, so invest heavily in accuracy and specificity.
</task>

<rules>
1. Execute phases in order. Do not skip the research phase.
2. After each phase, print a checkpoint: `Phase N complete — {summary}`
3. If you need clarification from the user, STOP and ask before continuing.
4. Every recommendation must cite what you found (e.g., "per xUnit docs", "found in existing tests at path/to/file").
5. Do not invent patterns that contradict what already exists in the project.
6. All generated files must use YAML frontmatter with `name`, `description`, and relevant fields (`tools`, `model`, `effort`).
7. Prefer extracting patterns from existing tests over inventing new conventions.
8. Include exact version numbers from the project's package manifest — not approximations.
9. When documenting a gotcha, include the failure mode (what goes wrong if you don't know this) — not just the rule.
10. Every code example in the generated agent must compile against the project's actual types and APIs. Do not use hypothetical class names.
11. The generated agent should be self-contained — an AI reading only that file should be able to write correct tests without additional context beyond the source file under test and LSP.
</rules>

---

## Phase 1: Project Analysis

Understand the project before researching anything externally.

### 1.1 Language & Framework Detection

Detect:
- **Primary language(s)** — check file extensions, build configs, package manifests
- **Framework(s)** — web framework, ORM, API layer, DI container
- **Package manager** — npm, pip, cargo, NuGet, Maven, Go modules, etc.
- **Build system** — how to build and run tests
- **Existing test runner** — check for test configs, test directories, CI test commands

Record findings as a structured summary:

```
Language: ___
Framework(s): ___
Package manager: ___
Build command: ___
Test command: ___
Test runner/framework: ___
Assertion library: ___
Mocking library: ___
Test data library: ___
Coverage tool: ___
```

### 1.2 Existing Test Patterns

If tests already exist:
- Read 3-5 representative test files cover-to-cover
- Extract: naming conventions, file organization, setup/teardown patterns, assertion style
- Note: how mocks are created, what's mocked vs real, shared fixtures
- Note: any custom test utilities, base classes, or helpers
- Check for a testing section in README, CONTRIBUTING, or CLAUDE.md

If no tests exist:
- Note that the agent will need to establish conventions from scratch
- Check if there's a CI config that hints at intended test setup

### 1.3 Architecture Classification

Classify the codebase components that need testing:

| Component Type | Example | Mocking Strategy |
|---|---|---|
| Pure logic (no dependencies) | Helpers, utils, validators | Direct testing, no mocks |
| Service with injected deps | Business logic services | Mock injected interfaces |
| Data access layer | Repositories, DAOs | Integration test or mock DB abstraction |
| API/Controller layer | Endpoints, handlers | Integration test with test server |
| Infrastructure wrappers | Queue clients, blob storage | Mock at boundary |
| DI/Wiring | Container registration | Smoke test resolution |

For each component type found in the project, note:
- Which services/classes fall into this type
- What their dependencies are (use LSP or read constructors)
- The appropriate mocking boundary

### 1.4 Error Handling Pattern

Identify the project's error handling approach:
- Exceptions? Result types (ErrorOr, Result<T>, Either)? HTTP status codes? Error codes?
- This determines how test assertions should be structured

---

## Phase 2: Online Research

Research current best practices for the specific stack discovered in Phase 1. Do NOT skip this — testing ecosystems evolve fast and cached knowledge goes stale.

### 2.1 Language-Specific Testing Best Practices

Search for: `"{language} {test_framework} best practices {current_year}"`

Research and note:
- **Recommended test structure** — how the community organizes tests for this language
- **Naming conventions** — method naming, file naming, directory structure
- **Assertion idioms** — what's idiomatic for this language (fluent assertions, expect-style, assert-style)
- **Async testing** — how to properly test async code in this stack
- **Parameterized tests** — the framework's approach to data-driven tests
- **Setup/teardown** — constructor vs setup methods vs fixtures vs lifecycle hooks
- **Common pitfalls** — what the community warns against (e.g., "don't mock what you don't own", "avoid InMemoryDatabase for EF Core")

### 2.2 Mocking Best Practices

Search for: `"{language} {mocking_library} best practices"` and `"{language} what to mock unit tests"`

Research:
- What the mocking library's maintainers recommend
- Common gotchas with the specific mocking library
- When to mock vs when to use fakes/stubs vs when to use real implementations
- How to mock async operations in this stack

### 2.3 Integration Testing

Search for: `"{framework} integration testing {current_year}"`

Research:
- The framework's official recommendation for integration tests
- Test containers / in-memory alternatives and their trade-offs
- How to test database interactions (real DB vs mocked abstraction)
- How to test external service calls

### 2.4 Coverage Tooling

Search for: `"{language} code coverage tool {current_year}"`

Research:
- What coverage tool is standard for this stack
- How to generate coverage reports (text summary + HTML)
- How to parse coverage data to find gaps
- CI integration patterns

---

## Phase 3: Generate Test Writer Agent

Create `.claude/agents/test-writer.md` with the following structure. Every section must be populated with project-specific findings from Phase 1-2.

### Agent Frontmatter

```yaml
---
name: test-writer
description: "Write comprehensive tests for source files. Use when the user asks to add tests, improve coverage, or write test cases for new code."
tools: Read, Write, Edit, Bash, Grep, Glob, LSP
model: opus
effort: high
---
```

### Required Sections

The generated agent MUST include these sections, populated with project-specific content:

#### 1. Introduction Line
One line stating: language, test framework, mocking library, and any other key test dependencies with exact version numbers from the project's package manifest.

#### 2. Analysis Phase — Understand Before Writing

Instructions to analyze code before writing tests:
- Read the source file and understand every public method
- Use LSP to trace dependencies (documentSymbol, goToDefinition, goToImplementation, findReferences, hover)
- Read any project-specific reference docs (API references, architecture docs)
- Read project rules/standards files
- Check existing tests for style and patterns to match

#### 3. Service/Component Classification

A decision tree for picking the right testing strategy based on the component type. Include one subsection per component type found in Phase 1.3, with:
- Description of when this type applies
- Concrete mocking/setup pattern with code example from the actual project (or a realistic example matching the project's stack)
- Gotchas specific to this type

#### 4. Writing Tests

Sub-sections:
- **Structure** — AAA or equivalent for the language, naming conventions, variable naming (sut, result)
- **What to Test** — checklist per public method:
  - Happy path
  - Edge cases (null, empty, boundary values, type-specific edges)
  - Error paths (every distinct error the method can produce)
  - Guard clauses / validation
  - State transitions (if stateful)
  - External dependency failures
- **Assertion Patterns** — code examples for success and error assertions using the project's error handling pattern
- **Code Quality — DO** — extracted helpers, parameterized tests, fresh state per test, focused test files
- **Anti-Patterns — DO NOT** — testing private methods, mocking the SUT, shared mutable state, over-verifying, testing implementation over behavior

#### 5. Critical Thinking Phase

Instructions to actively audit the code while writing tests:
- Unreachable code branches
- Logic errors (off-by-one, wrong operators, inverted conditions)
- Race conditions
- Missing error handling
- Contract violations
- Silent data loss or state corruption

When something suspicious is found:
- Write a test that documents the actual behavior
- Log findings with severity classification
- For bugs: create GitHub issues (if the project uses GitHub)
- Do NOT silently work around bugs in tests

#### 6. Verification Phase

Steps to run after writing tests:
1. Build/compile the test project
2. Run only the new tests (with the appropriate filter command for the test runner)
3. If tests fail, diagnose and fix
4. Report: total tests, passed, failed, coverage gaps that couldn't be tested (with reasons)

#### 7. Project-Specific Knowledge

A section for facts that are essential for writing correct tests but not obvious from reading the code:
- Internal framework behaviors (e.g., auto-transactions, event dispatch, audit field management)
- Known quirks or gotchas with specific libraries
- Type/enum values that don't match intuitive names
- Import/namespace conflicts to watch for

#### 8. Mocking Gotchas

A section for library-specific mocking pitfalls discovered in Phase 2.2 and any found in existing test code.

---

## Phase 4: Generate Coverage Skill

Create `.claude/skills/coverage/skill.md`:

```yaml
---
name: coverage
description: "Run code coverage on test projects and display a summary report. Use when the user says /coverage or asks about test coverage."
---
```

Content must include:
1. Which test projects to cover (exclude integration tests if they require external resources)
2. Commands to clean previous results, run tests with coverage, generate reports
3. How to display the summary
4. All commands must use the project's actual test runner and coverage tool

---

## Phase 5: Generate Coverage Gaps Skill

Create `.claude/skills/coverage-gaps/skill.md`:

```yaml
---
name: coverage-gaps
description: "Parse coverage data to show uncovered lines per class/function. Use when the user says /coverage-gaps or asks what's missing from coverage."
---
```

Content must include:
1. How to verify coverage data exists
2. A script (in the project's language or Python as fallback) to parse the coverage format and display:
   - Classes/modules with uncovered lines, sorted by gap size
   - Line ranges grouped for readability
   - Fully covered classes as a summary
3. Optional filter by class/module name
4. Instructions to read source at uncovered lines when the user asks about specific gaps

---

## Phase 6: Verification

After generating all files, verify:

- [ ] `test-writer.md` agent has all 8 required sections populated with project-specific content
- [ ] No generic placeholder text remains — every code example matches the project's actual stack
- [ ] Coverage skill uses correct build/test commands for this project
- [ ] Coverage gaps skill parses the correct coverage format (Cobertura XML, lcov, JSON, etc.)
- [ ] All file paths referenced in the agent actually exist in the project
- [ ] If existing tests exist, the agent's conventions match them (don't fight existing patterns)

Print final summary:
```
Test Writer Bootstrap Complete
==============================
Agent: .claude/agents/test-writer.md
Skills: .claude/skills/coverage/skill.md, .claude/skills/coverage-gaps/skill.md
Language: {detected}
Test framework: {detected}
Mock library: {detected}
Component types covered: {count}
Project-specific gotchas documented: {count}
```

---

## Optional Extensions

After the core agent is generated, ask the user if they want any of these:

1. **E2E Testing Skill** — if the project has a UI or API that can be tested end-to-end
2. **Testing Strategy Spec** — a comprehensive plan for what to test across the entire codebase, prioritized by risk
3. **Code Reviewer Agent** — a review agent that checks code against project standards (complements the test writer)
4. **TDD Workflow Integration** — modify the test writer to support test-first development (write failing tests, then guide implementation)
