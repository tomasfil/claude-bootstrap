# Module 03 — Create Rules

> Create `.claude/rules/` with scoped rule files based on discovery context.
> Rules are loaded contextually — they get high priority when relevant, low when not.

---

## Idempotency

Per rule file:
```
IF exists → READ, EXTRACT project-specific content, REGENERATE with current template + extracted knowledge
IF doesn't exist → CREATE
IF obsolete/superseded → DELETE
```

## Create Directory

```bash
mkdir -p .claude/rules
```

## Rule Files to Generate

### 1. `general.md` (always create)

```markdown
# General Rules

## Git
- {Adapt to project branching strategy: feature branches for team projects, direct main for solo/personal}
- Every commit → buildable state
- Conventional commits: type(scope): description
- Never force push shared branches

## Code Quality
- No dead code — delete, never comment out
- No TODO w/o linked issue
- English for all code, comments, docs
- Follow existing patterns before inventing new ones
- Check for existing similar code before adding — extend, don't duplicate

## Process
- READ_BEFORE_WRITE: understand existing code before modifying
- Run relevant test after every change
- After 2 failed fix attempts → search web for known solutions
- Log corrections → .learnings/log.md before continuing
```

### 2. `code-standards-{lang}.md` (one per detected language)

Generate a code standards file per language detected in Module 01. Name it with the language suffix (e.g., `code-standards-csharp.md`, `code-standards-typescript.md`).

Template — adapt to the detected language's idioms:

```markdown
# {Language} Code Standards

## Naming
{Extract from project analysis — e.g.:}
- Classes: PascalCase
- Methods: PascalCase, verb-noun (GetUser, ValidateInput)
- Variables: camelCase
- Constants: PascalCase | UPPER_SNAKE_CASE
- Booleans: is/has/should/can prefix (IsReady, HasPermission)
- Async methods: Async suffix (GetUserAsync)
- Files: match class name

## Structure
- Max function: 50 lines — split if longer
- Guard clauses + early returns over nested if-else
- File-scoped namespaces (C#) | single export per file (TS) | etc.
- One class/component per file

## Error Handling
- {Project's pattern: ErrorOr<T> | Result<T> | exceptions | HTTP status}
- Never swallow exceptions — always log w/ context
- Fail loudly — throw/return error, never silent fallback

## Constants
- No magic numbers | strings — extract to named constants
- Group related constants in dedicated files/classes

## Comments
- Comments: WHY only; if needs WHAT comment → refactor code instead
- No redundant comments (`// get the user` above `GetUser()`)
- XML docs | JSDoc | docstrings: public APIs only

## Style
{Start mostly empty — populated from real corrections via /reflect}
{Example entries after corrections:}
{- Use collection expressions [] over .ToList() (C# 14)}
{- Prefer pattern matching with is / switch expressions}

## Verification (Anti-Hallucination)
- ALWAYS read existing files before modifying | creating similar ones
- NEVER assume API/method/type exists — verify via LSP hover | Grep
- NEVER fabricate import paths — check actual namespace/module structure
- After writing code → run build: `{build_command}`
- LSP available → hover to confirm types correct
- Unsure if something exists → say so, never guess
```

### 3. `data-access.md` (conditional — if ORM detected)

Only create if EF Core, Prisma, SQLAlchemy, TypeORM, or similar detected.

```markdown
# Data Access Rules

## {ORM Name} Patterns
{Extract from project analysis — e.g. for EF Core:}
- Never inject DbContext directly — use IDataService<Context>
- Always .AsNoTracking() on read-only queries
- .Select() projections when full entities aren't needed
- Always parameterize queries — never string-interpolate SQL
- Extract configs → separate IEntityTypeConfiguration<T> classes
- Owned entities (OwnsMany/OwnsOne): still need .AsNoTracking() even in projections

## Migrations
- Review generated migration code before committing
- Descriptive names: Add{Entity}, Add{Field}To{Entity}
- Command: `{migration_command}`

## Repository Patterns
{Extract from project — e.g.:}
- InsertAsync() → new entities
- DeleteSoftAsync() → soft deletes (never hard delete)
- WhereAsQueryable() → filtered queries
- FirstOrDefaultAsync() → single entity lookup
- ExistsAsync() → existence checks

## Transactions
{Extract from project — e.g.:}
- TransactionMiddleware wraps HTTP requests — no manual transactions in endpoints
- Multi-operation services → SaveChangesAsync() once at end
```

### 4. `lsp-guidance.md` (conditional — only if LSP plugins detected or recommended)

Only create if LSP plugins are present or will be recommended in Module 12.

Check for installed LSP plugins:
```bash
cat ~/.claude/plugins/installed_plugins.json 2>/dev/null | grep -o '"[a-z]*-lsp"' | sort -u
```

For EACH detected language with an LSP plugin, add a section:

```markdown
# LSP Guidance

## When to Use LSP vs Grep
- goToDefinition → navigate to type/method/property definitions (precise, type-aware)
- findReferences → all usages of symbol (complete, not pattern-based)
- hover → check type info after writing code (verification)
- Grep → search file content, patterns, broad text search
- Default: LSP when available (semantics) > Grep (text only)

## {Language} ({lsp-plugin-name})
### Workspace Requirements
{e.g., for C#: .sln file must be in workspace root for OmniSharp to index properly}

### Effective Operations
- goToDefinition: class/method/property definitions
- findReferences: all usages across solution
- hover: type info + documentation
- documentSymbol: all symbols in file (classes, methods, properties)
- workspaceSymbol: search symbols across entire workspace

### Known Limitations
{e.g., for C#:}
- .razor.cs code-behind → may show false positive errors; verify w/ `dotnet build`
- Large solutions: ~30-60s to index on first load
- Deeply nested generics → slow type resolution

### Tips
- After writing code → hover on new type references to verify resolution
- Before renaming → findReferences to understand blast radius
- LSP seems stale → workspace may need re-indexing
```

**CRITICAL:** Only include language sections for languages ACTUALLY present in the project. Do not add sections for languages that aren't used.

### 5. `shell-standards.md` (conditional — only if bash scripts exist)

Only create if `.sh` files are found in the project:

```bash
find . -name "*.sh" -not -path "./.git/*" -not -path "./.claude/*" 2>/dev/null | head -5
```

```markdown
# Shell Script Standards

- Shebang: `#!/usr/bin/env bash`; `set -euo pipefail` at top
- Quote all variables: `"$var"` not `$var`
- `[[ ]]` for conditionals, not `[ ]`
- Check existence: `command -v tool >/dev/null 2>&1 || { echo "tool required"; exit 1; }`
- `local` for function variables; `printf` over `echo`
```

### 6. `token-efficiency.md` (always create)

Writing standard for all Claude-facing content. Loaded contextually when editing
rules, skills, agents, or CLAUDE.md files.

```markdown
# Token Efficiency Standards

## Scope
- Applies: CLAUDE.md, .claude/rules/, .claude/skills/, .claude/agents/, memory files
- NOT: conversation output, commits, PRs, user-facing docs

## Compression Rules
- Strip articles (a, an, the), filler, unnecessary prepositions
- Telegraphic: `READ_BEFORE_WRITE: modules,techniques` not full sentences
- Symbols: → (then/results in) | (or) + (and) ~ (approx) × (times) w/ (with)
- Key:value + bullets over prose; merge short rules w/ `;`
- YAML/markdown over JSON (11-20% fewer tokens)
- Abbreviate repeated terms; legend at top if needed
- One concept per bullet; multiple sub-points can share via `;`

## Stays Readable
- Conversation replies; commit messages + PRs; READMEs; code comments

## Why
- CLAUDE.md + rules load every conversation → 30-50% savings compounds across sessions
- Skills/agents load per invocation → savings × usage frequency
- Claude parses telegraphic identically to prose — no quality loss
- Subagents benefit doubly: smaller parent + child context
```

## Copy Technique References

Copy bootstrap technique files to `.claude/references/techniques/` — shared knowledge base
for skills like `/brainstorm`, `/write-prompt`, `/reflect`. These are research-synthesized
best practices, not project-verified truths.

```bash
mkdir -p .claude/references/techniques
```

**Idempotency:** If destination file exists w/ same content → skip. If older/different → overwrite.

Copy each file:
1. Read `techniques/INDEX.md` → write `.claude/references/techniques/INDEX.md`
2. Read `techniques/prompt-engineering.md` → write `.claude/references/techniques/prompt-engineering.md`
3. Read `techniques/anti-hallucination.md` → write `.claude/references/techniques/anti-hallucination.md`
4. Read `techniques/agent-design.md` → write `.claude/references/techniques/agent-design.md`

**If running from remote** (bootstrap repo not local):
```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/INDEX.md --jq '.content' | base64 -d > .claude/references/techniques/INDEX.md
gh api repos/tomasfil/claude-bootstrap/contents/techniques/prompt-engineering.md --jq '.content' | base64 -d > .claude/references/techniques/prompt-engineering.md
gh api repos/tomasfil/claude-bootstrap/contents/techniques/anti-hallucination.md --jq '.content' | base64 -d > .claude/references/techniques/anti-hallucination.md
gh api repos/tomasfil/claude-bootstrap/contents/techniques/agent-design.md --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
```

## Checkpoint

```
✅ Module 03 complete — Rules created: {list of rule files}; technique references copied to .claude/references/techniques/
```
