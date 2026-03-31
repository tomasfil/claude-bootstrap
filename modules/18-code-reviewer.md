# Module 18 — Generate Project-Specific Code Reviewer

> Create a deep, research-driven code reviewer that knows the project's architecture,
> security patterns, common bugs, and pipeline traces. Runs automatically after
> code-writer agents complete and when /review is invoked.

---

## Idempotency

Per agent file: read existing content, merge project knowledge with template, regenerate.

## What This Produces

| Output | Path | Purpose |
|--------|------|---------|
| Enhanced reviewer agent | `.claude/agents/project-code-reviewer.md` | Replaces base reviewer with project-specific deep review |
| Review checklist | `.claude/agents/references/review-checklist.md` | Per-component-type review items |

## Why This Matters

The base reviewer from Module 10 knows generic quality rules. This module makes it **project-aware**:
- Knows the pipeline traces — catches "you updated the Entity but forgot the DTO"
- Knows framework-specific security patterns — catches FastEndpoints auth bypass, EF Core injection
- Knows common project bugs — from `.learnings/log.md` and web research
- Knows architecture constraints — catches dependency direction violations

## Phase 1 — Project Analysis

Read the project to understand what the reviewer needs to check:

1. **Read existing reviewer** — if `.claude/agents/project-code-reviewer.md` exists, extract project-specific checklists, gotchas, and patterns as input for regeneration
2. **Read all rules** from `.claude/rules/` — these are the standards to enforce
3. **Read pipeline traces** from `.claude/skills/code-write/references/pipeline-traces.md` — for completeness checks
4. **Read .learnings/log.md** — past mistakes are the best review checklist
5. **Read CLAUDE.md gotchas** — things that catch Claude off guard
6. **Analyze architecture layers** — identify dependency direction rules

## Phase 2 — Web Research (MANDATORY — do not skip or abbreviate)

Research project-specific review patterns. Before proceeding to Phase 3, print how many searches were conducted and key findings.


| Topic | Search Query |
|-------|-------------|
| Framework security | "{framework} security vulnerabilities common mistakes {year}" |
| ORM pitfalls | "{orm} common mistakes code review {year}" |
| API security | "{api_framework} authentication authorization bypass" |
| Data access review | "{orm} query performance review checklist" |
| Frontend security | "{frontend_framework} XSS prevention code review" |

## Phase 3 — Generate Enhanced Reviewer

Replace `.claude/agents/project-code-reviewer.md` with a comprehensive version:

```yaml
---
name: project-code-reviewer
description: >
  Deep code review with project-specific knowledge. Use after writing code,
  before committing, or when asked to review. Knows architecture layers,
  pipeline traces, security patterns, and common project bugs.
tools: Read, Grep, Glob, LSP
model: opus
# Model is fixed based on task complexity. Override in CLAUDE.local.md if needed.
effort: medium
---
```

### Required Sections

#### 1. Role + Project Context
```markdown
You are a senior code reviewer for {project_name}. You know this project's
architecture, conventions, security patterns, and common mistakes.
```

#### 2. Pre-Review: Read Before Judging
```markdown
BEFORE reviewing ANY code:
1. Read the changed files in full
2. Read the applicable rules from .claude/rules/
3. Read CLAUDE.md conventions and gotchas
4. Use LSP to check type correctness (if available)
5. Check pipeline traces — is the change complete across all layers?
```

#### 3. Review Checklist (per component type)

Build a checklist based on the project's component classification:

```markdown
## Review by Component Type

### Entity Changes
- [ ] Configuration updated if new properties added?
- [ ] Migration created for schema changes?
- [ ] DTO updated to include new properties?
- [ ] Mapper updated for new DTO fields?
- [ ] Endpoints updated if new queryable fields?
- [ ] Client service/model updated?
- [ ] Tests cover new behavior?

### Endpoint Changes
- [ ] Authentication/authorization applied correctly?
- [ ] Request validation present?
- [ ] Error handling follows project pattern (ErrorOr/exceptions)?
- [ ] Response mapped correctly (not leaking internal types)?
- [ ] No N+1 queries in the handler?

### Service Changes
- [ ] Using IDataService, not direct DbContext?
- [ ] AsNoTracking() on read-only queries?
- [ ] Projections used where appropriate?
- [ ] Error cases return proper ErrorOr errors?
- [ ] Audit fields not set manually?

### Data Access Changes
- [ ] Parameterized queries (no string interpolation)?
- [ ] Indexes needed for new query patterns?
- [ ] Soft delete behavior preserved?
- [ ] Transaction scope appropriate?
```

#### 4. Security Review
```markdown
## Security Checks (always run)
- [ ] No hardcoded secrets or credentials
- [ ] No SQL injection (parameterized queries only)
- [ ] No command injection (no shell exec with user input)
- [ ] No XSS (output encoding on user content)
- [ ] Authentication applied to all new endpoints
- [ ] Authorization checks scope user to their data
- [ ] No sensitive data in logs
- [ ] No sensitive data in error messages
- [ ] File uploads validated (type, size, content)
- [ ] Rate limiting considered for new endpoints
```

#### 5. Architecture Review
```markdown
## Architecture Checks
- [ ] Dependencies flow downward (API → Services → Data, never reverse)
- [ ] No circular references between projects/layers
- [ ] New types in correct project (Entity in Data, DTO in Contracts, etc.)
- [ ] Interface defined for new services
- [ ] Service registered in DI container
```

#### 6. Common Project Bugs (from .learnings/)
```markdown
## Known Gotchas
{Generated from .learnings/log.md — past mistakes as review items}
{e.g.:}
- [ ] Owned entities: AsNoTracking() needed even in projections
- [ ] Firebase JWT: email is at firebase.identities.email[0]
- [ ] .razor.cs LSP errors: verify with dotnet build before flagging
```

#### 7. Report Format
```markdown
## Review Report

### Pipeline Completeness: {COMPLETE / INCOMPLETE}
{If incomplete: "Missing: DTO update, Mapper update"}

### Issues
- 🔴 [MUST FIX] {issue} — {file}:{line}
- 🟡 [SHOULD FIX] {issue} — {file}:{line}
- 🔵 [CONSIDER] {issue} — {file}:{line}

### Security: {PASS / ISSUES FOUND}
### Architecture: {PASS / ISSUES FOUND}

### Positives
- ✅ {what was done well}

### Verdict: {APPROVE / REQUEST CHANGES}
```

#### 8. Anti-Hallucination
```markdown
- Only cite rules that EXIST in .claude/rules/ — read them first
- Only report line numbers for lines that EXIST — read the file first
- If unsure about a standard, check the rules before citing it
- Never invent security issues that aren't actually present
- Use LSP to verify type issues before reporting them
```

## Phase 4 — Generate Review Checklist Reference

Write `.claude/agents/references/review-checklist.md` with the full per-component-type checklist extracted from the enhanced reviewer. This allows the checklist to be loaded separately and referenced by other agents.

## Phase 5 — Integration

Update the `/code-write` orchestrator skill to dispatch the reviewer after specialists complete:

```markdown
After all specialist agents finish:
1. Run build verification
2. Dispatch project-code-reviewer with the list of all changed files
3. If review finds MUST FIX issues: fix them, then re-review
4. Report final review status
```

Set `agent: project-code-reviewer` in `.claude/skills/review/SKILL.md` YAML frontmatter. This routes /review directly to the enhanced reviewer — no body dispatch logic needed.

## Checkpoint

```
✅ Module 18 complete — Enhanced project-code-reviewer generated
  Review checklist: {N} items across {M} component types
  Security checks: {N} items
  Architecture checks: {N} items
  Known gotchas: {N} items (from .learnings/)
  Pipeline trace verification: enabled
  Auto-review after code-write: configured
```
