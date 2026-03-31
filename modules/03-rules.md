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
- Every commit must leave the project in a buildable state
- Use conventional commit messages: type(scope): description
- Never force push to shared branches

## Code Quality
- No dead code — delete it, don't comment it out
- No TODO without a linked issue
- Use English for all code, comments, and documentation
- Follow existing patterns before inventing new ones
- When adding functionality, check if similar code already exists — extend, don't duplicate

## Process
- Read before write — always understand existing code before modifying
- Run the relevant test after every change
- After 2 failed fix attempts, search the web for known solutions
- Log corrections to .learnings/log.md before continuing
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
- Constants: PascalCase or UPPER_SNAKE_CASE
- Booleans: is/has/should/can prefix (IsReady, HasPermission)
- Async methods: Async suffix (GetUserAsync)
- Files: match class name

## Structure
- Max function length: 50 lines — split if longer
- Guard clauses / early returns over nested if-else
- File-scoped namespaces (C#) / single export per file (TS) / etc.
- One class/component per file

## Error Handling
- {Project's pattern: ErrorOr<T> / Result<T> / exceptions / HTTP status}
- Never swallow exceptions — always log with context
- Fail loudly — throw/return error instead of silent fallbacks

## Constants
- No magic numbers or strings — extract to named constants
- Group related constants in dedicated files/classes

## Comments
- Comments explain WHY, not WHAT
- No redundant comments (don't comment `// get the user` above `GetUser()`)
- Use XML docs / JSDoc / docstrings only for public APIs

## Style
{Start mostly empty — populated from real corrections via /reflect}
{Example entries after corrections:}
{- Use collection expressions [] over .ToList() (C# 14)}
{- Prefer pattern matching with is / switch expressions}

## Verification (Anti-Hallucination)
- ALWAYS read existing files before modifying or creating similar ones
- NEVER assume an API/method/type exists — verify via LSP hover or Grep
- NEVER fabricate import paths — check actual namespace/module structure
- After writing code, run build: `{build_command}`
- If LSP available, use hover to confirm types are correct
- If unsure whether something exists, say so rather than guessing
```

### 3. `data-access.md` (conditional — if ORM detected)

Only create if EF Core, Prisma, SQLAlchemy, TypeORM, or similar detected.

```markdown
# Data Access Rules

## {ORM Name} Patterns
{Extract from project analysis — e.g. for EF Core:}
- Never inject DbContext directly — use IDataService<Context>
- Always use .AsNoTracking() on read-only queries
- Use .Select() projections when full entities aren't needed
- Always parameterize queries — never string-interpolate SQL
- Extract configurations to separate IEntityTypeConfiguration<T> classes
- Owned entities (OwnsMany/OwnsOne) still need .AsNoTracking() even in projections

## Migrations
- Always review generated migration code before committing
- Use descriptive migration names: Add{Entity}, Add{Field}To{Entity}
- Migration command: `{migration_command}`

## Repository Patterns
{Extract from project — e.g.:}
- InsertAsync() for new entities
- DeleteSoftAsync() for soft deletes (never hard delete)
- WhereAsQueryable() for filtered queries
- FirstOrDefaultAsync() for single entity lookup
- ExistsAsync() for existence checks

## Transactions
{Extract from project — e.g.:}
- TransactionMiddleware wraps HTTP requests — don't create manual transactions in endpoints
- For multi-operation services, call SaveChangesAsync() once at the end
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
- Use LSP goToDefinition for: navigating to type/method definitions (precise, type-aware)
- Use LSP findReferences for: finding all usages of a symbol (complete, not pattern-based)
- Use LSP hover for: checking type information after writing code (verification)
- Use Grep for: searching across file content, finding patterns, broad text search
- Default to LSP when available — it understands semantics, Grep only sees text

## {Language} ({lsp-plugin-name})
### Workspace Requirements
{e.g., for C#: .sln file must be in workspace root for OmniSharp to index properly}

### Effective Operations
- goToDefinition: Navigate to class/method/property definitions
- findReferences: Find all usages of a symbol across the solution
- hover: Check type information and documentation
- documentSymbol: List all symbols in a file (classes, methods, properties)
- workspaceSymbol: Search for symbols across the entire workspace

### Known Limitations
{e.g., for C#:}
- .razor.cs code-behind files may show false positive errors — verify with `dotnet build`
- Large solutions may take 30-60s to index on first load
- Generic type resolution can be slow for deeply nested generics

### Tips
- After writing code, use hover on new type references to verify they resolve
- Use findReferences before renaming to understand blast radius
- If LSP seems stale, the workspace may need re-indexing
```

**CRITICAL:** Only include language sections for languages ACTUALLY present in the project. Do not add sections for languages that aren't used.

### 5. `shell-standards.md` (conditional — only if bash scripts exist)

Only create if `.sh` files are found in the project:

```bash
find . -name "*.sh" -not -path "./.git/*" -not -path "./.claude/*" 2>/dev/null | head -5
```

```markdown
# Shell Script Standards

- Always start with `#!/usr/bin/env bash`
- Always `set -euo pipefail` at the top
- Quote all variables: "$var" not $var
- Use `[[ ]]` for conditionals, not `[ ]`
- Check command existence: `command -v tool >/dev/null 2>&1 || { echo "tool required"; exit 1; }`
- Use `local` for function variables
- Prefer `printf` over `echo` for portability
```

### 6. `token-efficiency.md` (always create)

Writing standard for all Claude-facing content. Loaded contextually when editing
rules, skills, agents, or CLAUDE.md files.

```markdown
# Token Efficiency Standards

## Scope
- Applies to: CLAUDE.md, .claude/rules/, .claude/skills/, .claude/agents/, memory files
- Does NOT apply to: conversation output, commit messages, PR descriptions, user-facing docs

## Compression Rules
- Strip articles (a, an, the), filler, unnecessary prepositions
- Telegraphic style: `READ_BEFORE_WRITE: modules,techniques` not full sentences
- Symbols: → (then/results in) | (or) + (and) ~ (approximately) × (times) w/ (with)
- Key:value + bullets over prose paragraphs
- Merge related short rules onto single lines w/ `;` separators
- YAML/markdown over JSON (11-20% fewer tokens)
- Abbreviate repeated terms; add legend at top if needed
- One concept per bullet — but multiple sub-points can share a bullet via `;`

## What Stays Readable
- Conversation replies to user
- Git commit messages + PR descriptions
- README and user-facing documentation
- Code comments (explain WHY, still in English)

## Why
- CLAUDE.md + rules load every conversation; 30-50% savings compounds across all sessions
- Skills/agents load on every invocation; savings multiply by usage frequency
- Claude parses telegraphic notation identically to prose — no quality loss
- Subagent prompts benefit doubly: smaller parent context + smaller child context
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
1. Read `techniques/prompt-engineering.md` → write `.claude/references/techniques/prompt-engineering.md`
2. Read `techniques/anti-hallucination.md` → write `.claude/references/techniques/anti-hallucination.md`
3. Read `techniques/agent-design.md` → write `.claude/references/techniques/agent-design.md`

**If running from remote** (bootstrap repo not local):
```bash
gh api repos/tomasfil/claude-bootstrap/contents/techniques/prompt-engineering.md --jq '.content' | base64 -d > .claude/references/techniques/prompt-engineering.md
gh api repos/tomasfil/claude-bootstrap/contents/techniques/anti-hallucination.md --jq '.content' | base64 -d > .claude/references/techniques/anti-hallucination.md
gh api repos/tomasfil/claude-bootstrap/contents/techniques/agent-design.md --jq '.content' | base64 -d > .claude/references/techniques/agent-design.md
```

## Checkpoint

```
✅ Module 03 complete — Rules created: {list of rule files}; technique references copied to .claude/references/techniques/
```
