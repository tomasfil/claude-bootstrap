# Module 09 — Scoped CLAUDE.md Files

> Create directory-scoped CLAUDE.md files where distinct context is needed.
> SKIP IS VALID — only create if discovery detected directories with different conventions.

---

## Idempotency

Per directory: if scoped CLAUDE.md exists, extract project-specific rules, merge with bootstrap conventions, regenerate. If missing and conditions met, create.

## When to Create

Scan for directories that have distinctly different conventions from the root:

- **Test directories** — if testing conventions differ (different assertion style, fixtures, etc.)
- **Frontend directories** — if a different framework (Blazor vs React vs vanilla JS)
- **Script directories** — if shell scripts have different standards
- **Generated code directories** — "Do not modify files in this directory"
- **External/vendor directories** — "Read-only, do not modify"

## When NOT to Create

- If the root CLAUDE.md + rules/ covers everything adequately
- If the directory just uses the same conventions as the rest of the project
- If the directory is small (< 10 files)

## Template (each < 30 lines)

```markdown
# {Directory} Context

## Purpose
{What this directory contains and why it's different}

## Conventions
{Only rules SPECIFIC to this directory — don't repeat root CLAUDE.md}

## Commands
{Directory-specific commands if different from root}
```

## Example: Test Directory

```markdown
# Tests

## Conventions
- Test naming: Method_Scenario_ExpectedResult
- Use AAA pattern: Arrange, Act, Assert (separated by comments)
- For Type C services (CrudServiceBase): use real ServiceCollection, not direct mock
- Integration tests: wrap in using(var scope), commit, verify in separate scope with AsNoTracking()
- Never use InMemoryDatabase — always Testcontainers with real database

## Commands
- Run single: `dotnet test --filter "FullyQualifiedName~{ClassName}"`
- Run suite: `dotnet test`
```

## Checkpoint

```
✅ Module 09 complete — {N} scoped CLAUDE.md files created (or "skipped — not needed")
```
