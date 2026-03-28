# Module 16 — Generate Code Writer Agents

> Generate a tailored orchestrator skill and language-specific code writer agents.
> Uses discovery context from Module 01 and rules from Module 03.

---

## Idempotency

Per agent file: read existing content, merge project-specific knowledge with current template, regenerate.

## What This Produces

| Output | Path | Purpose |
|--------|------|---------|
| Orchestrator skill | `.claude/skills/code-write/SKILL.md` | `/code-write` — analyzes features, maps pipelines, dispatches specialists |
| Pipeline traces | `.claude/skills/code-write/references/pipeline-traces.md` | Feature-type → affected-files mapping |
| Language specialists | `.claude/agents/code-writer-{lang}.md` | Per-language implementation agents with classification trees |
| (Optional) References | `.claude/agents/references/{lang}-patterns.md` | Detailed code examples for agents >300 lines |

The generated system is **not generic** — it encodes your project's specific architecture layers, pipeline traces, component types, framework patterns, DI strategies, error handling, and naming conventions. The orchestrator knows which files change together for each feature type. The specialists know how to write code that a senior engineer on your team would recognize as idiomatic.

---

## How It Works

Seven phases (0-6), executed in order:

0. **Capability Scan** — Check what agents and skills already exist, identify coverage gaps
1. **Project Analysis** — Deep-read the codebase AND any existing code-writer agents. If `.claude/agents/code-writer-*.md` already exist, read them to extract project-specific knowledge (component types, patterns, gotchas) as input for regeneration. Then detect all languages, classify component types, map architecture layers, trace file co-occurrence patterns, extract conventions
2. **Web Research** — Search for current best practices per detected language/framework combo (~15-20 searches per language) — architecture, idioms, DI, error handling, performance, security, LSP tools, MCP servers
3. **Generate Orchestrator** — Create the `/code-write` skill with pipeline traces, layer dependencies, and specialist dispatch logic
4. **Generate Specialists** — Create per-language agents with 8 required sections, each grounded in research findings and project patterns
5. **Generate Supporting Files** — Pipeline trace reference, component examples
6. **Verification** — Validate all outputs against project reality

---

## What Makes a Good Code Writer System

The generated agents should enable an AI to write code that:
- **Matches existing conventions exactly** — naming, structure, patterns extracted from real project files
- **Knows the full pipeline** — adding a field means Entity + Config + Migration + DTO + Mapper + Endpoint + Client
- **Picks the right strategy per component** — REPR for endpoints, CrudServiceBase for CRUD services, standalone for business logic
- **Verifies before presenting** — read-before-write, LSP checks, build verification, never fabricates APIs
- **Knows project-specific gotchas** — framework internals, library quirks, EF Core owned entities, soft deletes
- **Documents its requirements** — which LSP plugins, MCP servers, and tools it needs

---

<role>
You are a senior engineering lead creating a comprehensive code writing system for this project. You combine deep knowledge of software architecture with meticulous codebase analysis and current research. You read existing code to extract patterns rather than imposing conventions. You understand that the most valuable output is project-specific knowledge — the pipeline traces, classification trees, and gotchas that would otherwise take hours to discover.
</role>

<task>
Execute ALL phases below to produce a complete, project-specific code writing system. Every output must be grounded in what you discovered during analysis and research — no generic filler. The agents you produce will be used repeatedly to write production code across the entire codebase, so invest heavily in accuracy and specificity.
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
</rules>

---

## Phase 0 — Capability Scan

Before creating anything, check what already exists:

1. Scan `.claude/agents/` for existing code-writer agents (`code-writer-*.md`)
2. Scan `.claude/skills/` for existing code-write skill (`code-write/SKILL.md`)
3. If capability index exists at `.claude/skills/code-write/references/capability-index.md`, read it
4. Record existing capabilities to avoid duplicating work

Store the index at `.claude/skills/code-write/references/capability-index.md`:

```markdown
# Code Writer Capability Index

## Existing Agents
- {agent name} — {language/purpose} — last updated {date}

## Existing Skills
- {skill name} — {purpose}

## Coverage Gaps
- {language/area not yet covered}
```

**Checkpoint:** `Phase 0 complete — {N} existing agents found, {M} coverage gaps identified`

---

## Phase 1 — Project Analysis

Deep-read the codebase to understand everything before researching.

### 1.1 Language & Framework Detection
Scan for ALL languages present (not just primary):
- File extensions → language mapping
- Build configs → framework and version
- Package manifests → dependencies and versions
- Record per language: name, version, framework, package manager, build/test/lint commands

### 1.2 Architecture Classification
- **Solution structure**: .sln, monorepo, workspaces → list all projects/packages
- **Layer identification**: Which projects/packages are API, service, data, contracts, common, client, functions?
- **Dependency graph**: Which layers depend on which? (read project references)
- **Architecture pattern**: Layered, vertical slice, clean architecture, CQRS, hexagonal?

### 1.3 Component Type Inventory
Per language, classify all component types found:

For each component type, read 3-5 examples and extract:
- File naming convention
- Class structure (inheritance, interfaces, attributes)
- Constructor/DI pattern
- Method patterns
- Error handling approach
- Related files (what else changes when this type changes)

Example classification for a .NET project:
```
Component Types:
├── Endpoint (FastEndpoints)
│   ├── AuthenticatedEndpoint<TRequest, TResponse>
│   ├── AdminEndpoint<TRequest, TResponse>
│   ├── EndpointWithoutRequest<TResponse>
│   └── Naming: {Action}.cs in Endpoints/{Entity}/
├── Service
│   ├── Type A: Simple (IDataService injection only)
│   ├── Type B: Complex (multiple dependencies)
│   ├── Type C: CrudServiceBase extension
│   └── Naming: {Entity}Service.cs in Services/Data/{Entity}/
├── Entity
│   ├── DomainEntity<Guid> base
│   ├── Record types with owned entities
│   └── Naming: {Name}.cs in Data/Entities/
├── Configuration
│   ├── IEntityTypeConfiguration<T>
│   ├── Fluent API mapping
│   └── Naming: {Entity}Configuration.cs in Data/Configurations/
├── DTO / Contract
│   ├── Record types
│   └── Naming: {Entity}Dto.cs in Contracts/
├── Mapper
│   ├── Extension methods
│   └── Naming: {Entity}Mapper.cs in Api/Mappers/
└── [more per project...]
```

### 1.4 Pipeline Trace Detection
Analyze which files change together for common feature types:

**Method 1 — Git co-occurrence analysis:**
```bash
# Find files that frequently change together in commits
git log --name-only --pretty=format: --diff-filter=ACMR | sort | uniq -c | sort -rn
```

**Method 2 — Manual trace from architecture:**
Read the architecture and trace a feature through all layers. For example:
- "Add new entity" → Entity + Config + Migration + DTO + Mapper + Endpoints + Client Service + UI
- "Add field to entity" → Entity + Config? + Migration + DTO + Mapper + Endpoints? + Client + UI
- "New API endpoint" → Request DTO + Response DTO + Endpoint + Service method? + Tests

### 1.5 Pattern Extraction
For each detected pattern, capture:
- Error handling: ErrorOr? Exceptions? Result<T>? HTTP status codes?
- DI patterns: Constructor injection? IServiceProvider? Lazy resolution?
- Naming: PascalCase? camelCase? snake_case? Async suffix?
- Guards: Early returns? Guard clauses? Validation middleware?
- Comments: None? WHY-only? XML docs?

### 1.6 Plugin/LSP/MCP Needs Assessment
Per language/framework, identify:
- What LSP plugin would benefit this language? (csharp-lsp, pyright-lsp, etc.)
- What MCP servers connect to services used by this project? (firebase, github, etc.)
- What Claude Code plugins provide relevant capabilities? (security-guidance, etc.)

**Checkpoint:** `Phase 1 complete — {N} languages detected, {M} component types classified, {P} pipeline traces mapped`

---

## Phase 2 — Web Research (MANDATORY — do not skip or abbreviate)

For EACH detected language/framework combination, research current best practices. This grounds the agents in verified knowledge rather than training data assumptions.

**Why this phase exists:** Your training data contains patterns from many framework versions. This project uses a specific version. Searching confirms which patterns are current for THAT version, and surfaces gotchas/deprecations you wouldn't know about. Skipping research means the generated agents may contain outdated or incorrect patterns.

**Enforcement:** Before proceeding to Phase 3, you MUST print:
```
Phase 2 complete — {N} searches conducted across {M} topic categories
Key findings: {3-5 bullet points of most impactful discoveries}
Gaps: {any topics where search failed after 2 attempts}
```
If N < 10 per language, explain which categories were skipped and why.

### Search Matrix (per language/framework)

| Topic | Search Query Template | What to Extract |
|-------|----------------------|-----------------|
| Architecture | "{framework} architecture best practices {year}" | Recommended patterns, layer organization |
| Coding idioms | "{language} {framework} coding patterns {year}" | Idiomatic code style, modern features |
| Component patterns | "{framework} {component_type} best practices" | Per-component-type guidance |
| DI patterns | "{language} dependency injection {framework}" | Registration, lifetime, resolution patterns |
| Error handling | "{framework} error handling patterns" | Framework-specific error flow |
| Performance | "{framework} performance optimization {year}" | Query optimization, caching, async patterns |
| Security | "{framework} security best practices OWASP" | Input validation, auth, injection prevention |
| LSP/Tools | "{language} language server protocol coding agent" | LSP operations, tool integration |
| MCP servers | "MCP server {framework} {service}" | Available MCP integrations |
| Common pitfalls | "{framework} common mistakes to avoid" | Anti-patterns, gotchas |

### Research Quality Checklist
- [ ] Each search actually returned relevant results
- [ ] Findings are from 2024+ sources (not outdated)
- [ ] Framework version matches project (e.g., .NET 10, not .NET 6)
- [ ] Findings don't contradict project's existing patterns (if they do, note the discrepancy)

**Checkpoint:** `Phase 2 complete — {N} searches conducted, key findings: {summary}`

---

## Phase 3 — Generate Orchestrator Skill

Create `.claude/skills/code-write/SKILL.md` and reference files.

### SKILL.md Structure

```yaml
---
name: code-write
description: >
  Use when implementing features, writing code, adding functionality, building
  components, or creating new files. Orchestrates language-specific code writers
  for cross-layer features. Analyzes the request, maps the pipeline trace, and
  dispatches specialist agents in dependency order.
---
```

### Content Sections

1. **Feature Analysis** — Decision tree: what kind of feature? What layers affected?
2. **Pipeline Trace Lookup** — Read references/pipeline-traces.md for the feature type
3. **File Change Map** — List every file that needs to change, in order
4. **Specialist Dispatch** — Which language agents, in what order
5. **Cross-Layer Verification** — After all specialists complete: build all, run tests
6. **Anti-Hallucination** — Verify all file paths exist before dispatching

### references/pipeline-traces.md

```markdown
## Pipeline Traces

### new-entity
Files (in order):
1. Data/Entities/{Entity}.cs — create entity record
2. Data/Configurations/{Entity}Configuration.cs — create EF config
3. [Migration] — dotnet ef migrations add Add{Entity}
4. Contracts/{Entity}Dto.cs — create DTO record
5. Api/Mappers/{Entity}Mapper.cs — create mapper extensions
6. Api/Endpoints/{Entity}/Get.cs — create GET endpoint
7. Api/Endpoints/{Entity}/Create.cs — create POST endpoint
8. Api/Endpoints/{Entity}/Update.cs — create PUT endpoint
9. Api/Endpoints/{Entity}/Delete.cs — create DELETE endpoint
10. Services/Data/{Entity}/{Entity}Service.cs — create service
11. Services/Data/{Entity}/I{Entity}Service.cs — create interface
12. DependencyInjection.cs — register service

### new-field
[... similar trace ...]

### new-endpoint
[... similar trace ...]
```

**Checkpoint:** `Phase 3 complete — orchestrator skill created with {N} pipeline traces`

---

## Phase 4 — Generate Language Specialist Agents

Create `.claude/agents/code-writer-{lang}.md` for each detected language.

### Required Sections (all 8)

Every specialist agent MUST contain these sections, with project-specific content in each:

#### Section 1: Role + Stack
```markdown
## Role
You are a {language} code writer specialist for {project_name}.

## Stack
- Language: {language} {version}
- Framework: {framework} {version}
- ORM: {orm} {version} (if applicable)
- Test Framework: {test_framework} (if applicable)
- Package Manager: {package_manager}
```

#### Section 2: Analysis Phase (Read-Before-Write)
```markdown
## Before Writing Code (MANDATORY)

1. Read the target file (if modifying) or 2-3 similar files (if creating)
2. Read related files: base classes, interfaces, configurations
3. Use LSP goToDefinition/findReferences if available
4. Check .claude/rules/{language}-code-standards.md
5. Check scoped CLAUDE.md in target directory (if exists)
6. Verify every type/method you plan to use actually exists
```

#### Section 3: Component Classification Tree
```markdown
## Component Classification

Determine what you're building BEFORE writing code:

[Decision tree with real code examples from the project]
[Each leaf node: file naming, class structure, DI pattern, method patterns]
```

#### Section 4: Writing Code
```markdown
## Code Patterns

### Naming Conventions
[Extracted from actual project files]

### Structure Templates
[Per component type, with real examples]

### Error Handling
[Project's specific pattern: ErrorOr, exceptions, Result<T>]

### DI Registration
[How to register new services/components]
```

#### Section 5: Anti-Hallucination Checks
```markdown
## Verification Rules

DO NOT:
- Invent APIs, methods, or parameters not in this project
- Fabricate package names or import paths
- Assume method signatures — check actual source
- Generate code for components you haven't read examples of

AFTER writing:
1. Run {build_command} — fix any errors
2. Use LSP hover to verify types (if available)
3. Run affected tests
4. If unsure, say so rather than guessing
```

#### Section 6: Plugin/LSP/MCP Requirements
```markdown
## Required Tools

### LSP
- Plugin: {lsp_plugin} — install via `claude plugins install {name}`
- Operations: goToDefinition, findReferences, hover, documentSymbol
- Fallback: Use Grep for symbol search if LSP unavailable

### MCP Servers
- {server}: {purpose} (if applicable)

### Plugins
- security-guidance: Catches security issues at write time
- context7: Library docs lookup for unfamiliar APIs
```

#### Section 7: Verification Phase
```markdown
## Post-Implementation Verification

1. Build: {build_command}
2. Lint: {lint_command}
3. Test: {test_command_single} (for changed code)
4. Report: "Build {pass/fail}, {N} tests passed, {M} failed"
```

#### Section 8: Project-Specific Knowledge
```markdown
## Gotchas & Internal Knowledge

[Framework-specific behaviors discovered during analysis]
[Library quirks, namespace conflicts, enum values]
[Transaction behavior, soft deletes, audit field handling]
[Import conflicts, type resolution order]
```

### YAML Frontmatter
```yaml
---
name: code-writer-{lang}
description: >
  {Language} code writer specialist for {project}. Use when writing {language}
  code for {list component types}. Knows project conventions, DI patterns,
  error handling, and framework-specific gotchas.
tools: Read, Write, Edit, Bash, Grep, Glob, LSP, WebSearch
model: opus
# Model is fixed based on task complexity. Override in CLAUDE.local.md if needed.
effort: medium
---
```

**Checkpoint:** `Phase 4 complete — {N} language specialists created`

---

## Phase 5 — Generate Supporting Files

- Pipeline trace reference doc (if not already created in Phase 3)
- Component type examples (few-shot, if agents are >300 lines)
- Update skill routing hook (in .claude/settings.json) to include /code-write

**Checkpoint:** `Phase 5 complete — supporting files created, routing hook updated`

---

## Phase 6 — Verification

### Checklist
- [ ] Orchestrator skill has YAML frontmatter (name, description)
- [ ] Orchestrator references pipeline-traces.md correctly
- [ ] Each specialist has all 8 sections with project-specific content
- [ ] No generic placeholder text — all code examples from actual project
- [ ] Plugin/LSP/MCP requirements are accurate for each specialist
- [ ] Pipeline traces match actual project structure
- [ ] Classification trees cover all detected component types
- [ ] Anti-hallucination sections present in every specialist
- [ ] Build command works (verify by running it)
- [ ] Skill routing hook lists /code-write

### Smoke Test
Run through one mental scenario:
"If the user says 'add a new field X to entity Y', does the orchestrator know:
1. Which pipeline trace to use?
2. Which files to create/modify?
3. Which specialists to dispatch?
4. In what order?
5. How to verify the result?"

**Checkpoint:** `Phase 6 complete — all checks passed`

✅ Module 16 complete — code writer orchestrator skill, language specialists, pipeline traces, and capability index generated and verified

---

## Integration

This module uses context from earlier modules:
- Discovery results from Module 01 (languages, frameworks, architecture)
- Rules from Module 03 (code standards per language)
- Base agents from Module 10 (these specialists complement them)
- Skill routing is generated by Module 14 (will include /code-write after this module runs)
- /reflect from Module 05 monitors and evolves the generated agents
