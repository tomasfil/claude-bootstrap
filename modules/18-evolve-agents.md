# Module 18 — Generate /evolve-agents Skill

> Generate the /evolve-agents skill for splitting bloated per-language agents into framework sub-specialists and auditing existing sub-specialists for drift.

---

## Idempotency

```
IF exists → READ, EXTRACT project-specific content, REGENERATE with current template + extracted knowledge
IF missing → CREATE
IF obsolete/superseded → DELETE
```

## What This Produces

| Output | Path | Purpose |
|--------|------|---------|
| Evolve-agents skill | `.claude/skills/evolve-agents/SKILL.md` | `/evolve-agents` dispatcher |
| Per-specialist extraction | `.claude/skills/code-write/references/{lang}-{fw}-extraction.md` | Phase 1 output (at runtime) |
| Per-specialist analysis | `.claude/skills/code-write/references/{lang}-{fw}-analysis.md` | Phase 2 output (at runtime) |
| Per-specialist research | `.claude/skills/code-write/references/{lang}-{fw}-research.md` | Phase 3 output (at runtime) |
| Per-specialist sources | `.claude/skills/code-write/references/{lang}-{fw}-sources.md` | Phase 4 output (at runtime) |
| Sub-specialist agents | `.claude/agents/code-writer-{lang}-{fw}.md` | Generated at runtime per approval |
| Sub-specialist test agents | `.claude/agents/test-writer-{lang}-{fw}.md` | Generated at runtime per approval |

---

## Create Skill

```bash
mkdir -p .claude/skills/evolve-agents
```

Write `.claude/skills/evolve-agents/SKILL.md`:

```yaml
---
name: evolve-agents
description: >
  Split bloated per-language code-writer and test-writer agents into
  framework-specific sub-specialists, or audit existing sub-specialists
  for version drift and stale research. Use when a language agent covers
  3+ frameworks, exceeds 500 lines, when /reflect proposes it, or to
  refresh sub-specialist knowledge after dependency upgrades.
context: fork
agent: general-purpose
allowed-tools: Agent, Read, Write, Edit, Bash, Grep, Glob, Skill
model: opus
effort: high
---
```

```markdown
## /evolve-agents — Framework Sub-Specialist Creation + Audit

### Step 1: Prerequisite Check

Verify `code-writer-markdown` agent exists:
```bash
ls .claude/agents/code-writer-markdown.md
```

IF missing → generate from Module 10 template:
```bash
gh api repos/tomasfil/claude-bootstrap/contents/modules/10-agents.md \
  --jq '.content' | base64 -d > /tmp/10-agents.md
```
Read `/tmp/10-agents.md` → extract `## 9. code-writer-markdown.md` section → write to `.claude/agents/code-writer-markdown.md`.

Verify technique references:
```bash
ls .claude/references/techniques/prompt-engineering.md \
   .claude/references/techniques/agent-design.md \
   .claude/references/techniques/anti-hallucination.md
```
IF missing → fetch each via `gh api repos/tomasfil/claude-bootstrap/contents/techniques/{name}.md`.

---

### Step 2: Analysis — Detect Split Candidates + Audit Existing

Scan `.claude/agents/` for `code-writer-*.md` + `test-writer-*.md`.

**2a — Split candidates** (agents WITHOUT `parent` field in frontmatter):

Per agent, measure:
1. **Line count** — `wc -l < .claude/agents/{agent}.md`; >500 = candidate
2. **Framework count** — parse classification tree for distinct framework branches; 3+ = candidate
3. **Correction density** — `grep -c '{agent-name}' .learnings/log.md`; 3+ for same framework = candidate
4. **Component type count** — count distinct types in classification tree; >8 = candidate (multi-framework signal)

Score: count how many thresholds exceeded (1-4). Rank by score descending.

**2b — Audit existing sub-specialists** (agents WITH `parent` field):

Per sub-specialist, check:
1. **Version mismatch** — read project manifests (`package.json`, `*.csproj`, `pyproject.toml`, `go.mod`, `Cargo.toml`) → compare framework/library versions against agent's Role+Stack section
2. **Reference staleness** — `stat .claude/skills/code-write/references/{lang}-{fw}-research.md`; >90 days = stale
3. **Missing patterns** — grep codebase for framework file patterns → compare count against analysis.md; new component types = gap
4. **Correction accumulation** — count `.learnings/log.md` entries mentioning this sub-specialist since last evolve-agents run

Output: ranked candidate list (splits) + audit report (updates) w/ scores + reasoning.

---

### Step 3: Proposal — Present Split + Update Recommendations

**For split candidates:**
```
code-writer-csharp (647 lines, 4 frameworks) → propose:
  - [ ] code-writer-csharp-blazor — Blazor components, render modes, JS interop
  - [ ] code-writer-csharp-api — FastEndpoints, REPR, middleware, validation
  - [ ] code-writer-csharp-data — EF Core entities, configurations, migrations

test-writer-csharp (523 lines, mixed strategies) → propose:
  - [ ] test-writer-csharp-unit — xUnit, NSubstitute, isolated service tests
  - [ ] test-writer-csharp-integration — WebApplicationFactory, real DB, bUnit
```

**For audit candidates:**
```
code-writer-csharp-blazor (audit):
  - [ ] Version drift: .NET 8 → .NET 9 detected in csproj
  - [ ] Research stale: csharp-blazor-research.md is 120 days old
  - [ ] 3 new corrections in learnings since last run
  → Re-run research pipeline (Phases 2-4) to refresh references + update agent
```

**Edge cases:**
- Single-framework language → "agent is appropriately scoped" — no split
- Parent <300 lines even w/ 3+ frameworks → "within ideal range per agent-design.md"
- Framework w/ <3 source files → skip w/ note in proposal
- User rejects all → exit cleanly, no files created

**WAIT for user approval.** Never proceed without explicit confirmation per proposal.

---

### Step 4: Research Pipeline (per approved specialist)

4 phases per NEW sub-specialist. For UPDATES: skip Phase 1, re-run Phases 2-4 merging new findings.

**Cross-specialist parallelism:** Phase 2+3 for DIFFERENT specialists CAN run in parallel (dispatch multiple researcher agents in one message). Within ONE specialist: Phase 2 → Phase 3 sequential (Phase 3 reads Phase 2 output).

#### Phase 1 — Extraction (main thread, NEW only)

Parse parent agent for framework-specific sections:
- Extract classification tree branches for this framework
- Extract gotchas, patterns, DO NOT rules specific to this framework
- Identify gaps — what parent glosses over for this framework

Output: `.claude/skills/code-write/references/{lang}-{fw}-extraction.md`
Format: YAML blocks, compressed telegraphic notation.

#### Phase 2 — Local Deep-Dive (dispatch `researcher` agent)

Prompt template:
```
Read `.claude/skills/code-write/references/{lang}-{fw}-extraction.md` for known gaps.

Deep-read every {framework}-specific file in this project:
- {file patterns for framework, e.g., **/*.razor, **/Components/**}
- Map sub-patterns parent agent lumped together
  (e.g., Blazor: static vs interactive vs streaming render modes as distinct types)
- Trace framework-specific dependency chains
  (which services injected into {framework} components specifically)
- Identify framework-specific test patterns
  (e.g., bUnit for Blazor vs WebApplicationFactory for API)
- Document framework-specific build/test/lint commands

Write to `.claude/skills/code-write/references/{lang}-{fw}-analysis.md`
Format: YAML blocks per component sub-type. Compressed telegraphic notation.
```

#### Phase 3 — Web Research (dispatch `researcher` agent)

Prompt template:
```
Read `.claude/skills/code-write/references/{lang}-{fw}-extraction.md` and
`.claude/skills/code-write/references/{lang}-{fw}-analysis.md`.

Execute 10-15 focused searches:

FRAMEWORK-SPECIFIC:
- "{framework} {version} best practices {year}"
- "{framework} {version} breaking changes migration guide"
- "{framework} component patterns advanced {year}"
- "{framework} common mistakes pitfalls {year}"
- "{framework} performance anti-patterns"
- "{framework} {specific_pattern_from_phase2} gotchas"

TOOLING/INTEGRATION:
- "MCP server {framework}"
- "{framework} language server features"
- "{framework} official documentation API reference"
- "{framework} testing {test_library} {year}"

DEEP CUTS:
- "{framework} internal lifecycle {version}"
- "{framework} vs {alternative_found_in_codebase} when to use"

Write to `.claude/skills/code-write/references/{lang}-{fw}-research.md`
Report: search count, key findings (5-7 bullets), gaps where search failed.
```

#### Phase 4 — Doc/MCP Pointer Resolution (main thread)

Compile from Phase 3 results:
```yaml
docs:
  official: {url}
  api_reference: {url}
mcp:
  available: {true/false}
  server: {name or "none found"}
lsp:
  features: [{framework-specific LSP features}]
  plugin: {recommended LSP plugin}
```

Output: `.claude/skills/code-write/references/{lang}-{fw}-sources.md`

**Verify all 4 reference files exist + non-empty before proceeding to Step 5.**

---

### Step 5: Agent Generation (dispatch `code-writer-markdown` per sub-specialist)

Per approved sub-specialist, dispatch `code-writer-markdown` agent w/ this prompt:

```
Read these reference files:
1. `.claude/skills/code-write/references/{lang}-{fw}-extraction.md`
2. `.claude/skills/code-write/references/{lang}-{fw}-analysis.md`
3. `.claude/skills/code-write/references/{lang}-{fw}-research.md`
4. `.claude/skills/code-write/references/{lang}-{fw}-sources.md`

Generate `.claude/agents/code-writer-{lang}-{fw}.md` (or `test-writer-{lang}-{fw}.md`).

Target: 100-200 lines embedded. Deep patterns live in reference files.
Use compressed telegraphic notation. Code examples at full fidelity.

YAML frontmatter:
---
name: code-writer-{lang}-{fw}
description: >
  {Framework} specialist for {project}. Use when writing {framework}-specific
  code: {list scope items}. Knows {framework} patterns, gotchas, component
  lifecycle. Falls back to code-writer-{lang} for cross-cutting concerns.
tools: Read, Write, Edit, Bash, Grep, Glob, LSP, WebSearch
model: opus
effort: medium
maxTurns: 30
color: blue
scope: "{framework} components, {pattern1}, {pattern2}, ..."
parent: code-writer-{lang}
---

REQUIRED EMBEDDED SECTIONS (all must be populated):

## Role + Stack
Senior {framework} specialist. Stack: {language} {version}, {framework} {version}, {test tools}.

## Pre-Work: Load References (MANDATORY — first action always)
BEFORE any work, read ALL of these:
1. `.claude/skills/code-write/references/{lang}-{fw}-analysis.md`
2. `.claude/skills/code-write/references/{lang}-{fw}-research.md`
3. `.claude/skills/code-write/references/{lang}-{fw}-sources.md`
4. `.claude/rules/{lang}-code-standards.md` (if exists)

## Classification Tree (framework-scoped subset only)
Decision tree covering ONLY this framework's component types.
Extracted from parent + refined w/ Phase 2 sub-patterns.

## Anti-Hallucination
Adapted from `.claude/references/techniques/anti-hallucination.md`:
- Read-before-write checklist
- Framework-specific DO NOT rules
- Confidence routing: HIGH → proceed, MEDIUM → verify, LOW → research
- Build/test verification commands

## Critical Gotchas (top 10-15)
Framework-specific gotchas from extraction + research.
Only ones that burn you — not general knowledge.

## Verification
Build: {command}
Test: {command}
Lint: {command}
Report format: "Build {pass/fail}, {N} tests passed, {M} failed"
```

For UPDATES: dispatch `code-writer-markdown` to update Role+Stack versions + critical gotchas from refreshed research. Merge — don't overwrite project-specific gotchas accumulated since last run.

---

### Step 6: Wiring

1. **Capability index** — `.claude/skills/code-write/references/capability-index.md`
   - Add sub-specialist entries w/ `scope` + `parent` fields
   - Mark parent scope as "general {lang}, cross-cutting concerns"
   - Add parent→child relationship notation

2. **Code-write orchestrator** — `.claude/skills/code-write/SKILL.md`
   - Verify dynamic discovery exists (Agent Discovery section from Module 16)
   - IF missing: add discovery protocol:
     1. Glob `.claude/agents/code-writer-*.md` → build inventory
     2. Read frontmatter `scope` per agent
     3. Scope match → sub-specialist; language-only match → parent
     4. Read capability-index.md for gap awareness

3. **UserPromptSubmit hook** — `.claude/settings.json`
   - Regenerate via Module 14 logic (scan `.claude/agents/*.md` + `.claude/skills/*/SKILL.md`)
   - New sub-specialists appear automatically (Module 14 scans disk)

4. **Pipeline traces** — `.claude/skills/code-write/references/pipeline-traces.md`
   - Add framework-specific traces if not present
   - Tag existing traces w/ responsible sub-specialist

5. **Code reviewer refs** (if Module 17 has run)
   - New reference files available for framework-specific review depth

---

### Anti-Hallucination

- Verify parent agent exists before proposing split — `ls .claude/agents/{parent}.md`
- Count lines/branches via Bash — NEVER estimate
- NEVER create sub-specialists without explicit user approval per proposal
- Phase 2 → Phase 3 sequential within one specialist (Phase 3 reads Phase 2 output)
- Verify all 4 reference files non-empty before Step 5: `wc -l` each, all >0
- After wiring: verify orchestrator discovery finds new agents — glob + check scope match
- DO NOT modify parent agent — sub-specialists extract from parent, parent stays as-is

### Gotchas

- `context: fork` broken (claude-code#16803) — skill runs inline, `agent:` field ignored. Keep field for forward compat
- Sub-specialists w/ `parent` field are NEVER re-split candidates (2b audits only)
- Phase 2+3 parallelism is ACROSS specialists (different frameworks = independent), not WITHIN one specialist
- Reference files MUST use compressed telegraphic notation (YAML blocks)
- `code-writer-markdown` prerequisite: if missing, fetch from bootstrap repo before proceeding (Step 1)
- Single-framework language agents → no split; report "appropriately scoped"
- Framework w/ <3 source files → skip w/ note; insufficient code for meaningful specialist
- Reference files already exist (update path) → merge new findings, don't discard prior research
```

---

## Integration

This module uses context from earlier modules:
- Module 05 (`modules/05-skills-reflect.md`) — `/reflect` detects evolution candidates + proposes running `/evolve-agents`
- Module 14 (`modules/14-verification.md`) — routing hook regeneration; scans `.claude/agents/*.md` dynamically
- Module 16 (`modules/16-code-writer.md`) — generates parent agents this skill splits; orchestrator gets dynamic discovery
- Module 17 (`modules/17-code-reviewer.md`) — consumes reference artifacts for framework-specific review depth

This module produces artifacts consumed by:
- Code-write orchestrator — sub-specialist routing via `scope` + `parent` fields
- Code reviewer — deeper framework-specific reference material
- Future migrations — MUST glob `code-writer-*.md` + `test-writer-*.md`, never hardcode filenames

## Checkpoint

```
✅ Module 18 complete — /evolve-agents skill created
```
