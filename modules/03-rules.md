# Step 3 — Create .claude/rules/

> **Mode C**: If rules exist, read them first. Add missing rules, don't overwrite customizations.

Create directory: `.claude/rules/`

## 3a: general.md

Create `.claude/rules/general.md`:

```markdown
# General Rules

- NEVER commit directly to main/master — always use feature branches
- Leave the codebase in a buildable, testable state after every change
- No orphan TODOs — every TODO must have: owner, date, and linked issue/reason
- Delete dead code — don't comment it out (git preserves history)
- All code, comments, and commit messages in English
- When uncertain about intent, ASK rather than assume
```

## 3b: code-standards.md

Create `.claude/rules/code-standards.md` with globs frontmatter matching project source files:

```markdown
---
globs: "{src,lib,app}/**/*.{ts,tsx,js,jsx,py,rs,go,rb,ex,exs}"
---
# Code Standards

## Style
{populated from user's style prefs and corrections — start with project conventions}
IMPORTANT: This section is the canonical home for style corrections. /reflect promotes learnings here.

## Naming
{language-appropriate: camelCase/snake_case, component naming, file naming}

## Functions
- Small, single-purpose functions (< 40 lines preferred)
- Pure functions where possible — minimize side effects
- Explicit return types (in typed languages)

## Error Handling
- No swallowed errors — always log or propagate
- Use language-idiomatic error patterns (Result/Option, try/catch, error returns)
- User-facing errors: actionable messages. Internal errors: include context for debugging.

## Constants
- No magic numbers/strings — extract to named constants
- Config values in config files, not scattered in code

## Comments
- Comments explain WHY, not WHAT
- Delete commented-out code (git has history)

## Idempotency
- Scripts and migrations must be safe to run multiple times

## Paths
- Use path.join / Path — never string-concatenate paths
- No hardcoded absolute paths

## Cleanup
- Remove unused imports, variables, files
- No console.log / print debugging left in committed code

## SQL (if applicable)
- Parameterized queries only — NEVER string-interpolate user input
- Migrations must be reversible where possible
```

Adjust globs and content for the actual project languages.

## 3c: shell-standards.md (Conditional)

**Only create if** the project contains bash/shell scripts.

Create `.claude/rules/shell-standards.md`:
```markdown
---
globs: "**/*.sh"
---
# Shell Standards

- Always start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Quote all variables: `"$var"` not `$var`
- Use `[[ ]]` not `[ ]` for conditionals
- Use `$(command)` not backticks
- Declare local variables in functions: `local var="value"`
- Check command existence with `command -v` not `which`
```

## 3d: lsp-guidance.md (Conditional)

**Only create if** LSP plugins are installed or recommended for this project.

Research the project's languages and installed/recommended LSP plugins, then generate `.claude/rules/lsp-guidance.md`:

- **When to Use LSP vs Grep**: LSP for type info, definitions, references, renames. Grep for pattern matching, string search, comments.
- **Workspace Requirements**: how to ensure the language server has indexed the project
- **Language-Specific Guidance**: generate for the actual languages in this project (don't copy generic examples)
- Reference `reference/lsp-reference.md` from the bootstrap repo for the full operations matrix

## Checkpoint

Print: `Step 3 complete — .claude/rules/ created ({list of files})`
