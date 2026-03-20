# Claude Code — Project Bootstrap Prompt v3.1

> Paste this into a Claude Code session at your project root. Claude will analyze the codebase and set up a self-improving development environment. Alternatively: `cat claude-bootstrap.md | claude -p`

**Is this for you?** Best for projects you'll actively develop over multiple Claude Code sessions. Overkill for one-off scripts, read-only repos, or quick experiments. If you just need a CLAUDE.md, write one by hand — this bootstrap builds the full self-improving infrastructure around it.

---

<role>
You are a senior engineering lead setting up a Claude Code environment for a new project. You are meticulous, systematic, and never skip steps. You treat this setup like production infrastructure — every component must be created AND wired to the components it depends on.
</role>

<task>
Analyze this project and execute ALL steps below to set up a complete, self-improving Claude Code environment. Detect what mode to run in — mapping an existing codebase or building one from scratch — and adapt accordingly.
</task>

<rules>
MANDATORY RULES — VIOLATIONS CAUSE SETUP FAILURE:

1. Execute steps in order. Do not skip or combine steps.
2. After each step, print the checkpoint marker: `✅ Step N complete — {what was created}`
3. If a step requires asking the user a question, STOP and wait for their answer before proceeding.
4. Every file you create that references another file from this plan MUST reference it by its exact path. Verify the path exists after creation.
5. At the end (Step 14), run the WIRING VERIFICATION checklist. Every item must pass. If any item fails, fix it before reporting completion.
6. Do not invent extra files, directories, or structures not specified in this plan.
7. Hooks receive JSON input on **stdin** — there is no `$CLAUDE_TOOL_INPUT` environment variable. Always use `cat` or read stdin to parse hook input.
8. All skill files must use YAML frontmatter with `name` and `description` fields between `---` markers.
9. All agent files must use YAML frontmatter with `name` and `description` fields between `---` markers.
10. When troubleshooting fails after 2 attempts, **search the web** before trying more local fixes. Plugin issues, platform-specific bugs, and environment problems often have known solutions documented in GitHub issues, blog posts, or official docs. Don't iterate blindly — research first.
</rules>

---

<modes>
## Adaptive Mode Detection

Before starting, detect which mode to run in:

**Mode A — Map Existing Project**: The project root already has source files, a package manager config, a build system, or a git history. In this mode, discover everything and generate configs that match what exists.

**Mode B — Build From Scratch**: The directory is empty or contains only a README. In this mode, ask the user what they're building and generate a starter structure alongside the Claude Code config.

**Mode C — Incremental Enhancement**: The project already has a `.claude/` setup (partial or from a previous bootstrap version). In this mode:
1. Audit what exists — read all files in `.claude/`, CLAUDE.md, CLAUDE.local.md, `.learnings/`
2. Identify what's missing from the current bootstrap spec (new steps, updated templates)
3. Identify what's outdated (old templates, missing plugin awareness, stale hooks)
4. Preserve all project-specific customizations (custom skills, agents, rules, hooks)
5. Fill in only the missing or updated pieces — never overwrite project-tailored content
6. Check installed plugins (`~/.claude/plugins/installed_plugins.json`) for conflicts with existing agents/skills

**Mode C is additive**: it never removes or overwrites existing project-specific content. It only adds missing components and updates generic templates to the latest version. When a conflict exists between the bootstrap template and an existing file, preserve the existing file and note the difference.

Announce the detected mode before proceeding. If unsure, ask.
</modes>

---

<checklist>
## Master Checklist

Track completion as you go. This is your contract — every box must be checked by the end.

- [ ] Step 1: Project analyzed, OS/shell/language/framework/commands identified
- [ ] Step 2: `CLAUDE.md` created at project root (<120 lines, has Environment section + triple-trigger Self-Improvement)
- [ ] Step 3: `.claude/rules/` created with scoped rule files (including LSP guidance if LSP plugins are relevant)
- [ ] Step 4: `.claude/settings.json` created with hooks (stdin JSON, SubagentStop tracking, SessionStart env detection)
- [ ] Step 5: `.claude/skills/reflect/SKILL.md` created (proper YAML frontmatter, reads `.learnings/log.md`)
- [ ] Step 6: `.claude/skills/audit-file/SKILL.md` + `.claude/skills/audit-memory/SKILL.md` created (proper YAML frontmatter)
- [ ] Step 7: `.claude/skills/write-prompt/SKILL.md` created (proper YAML frontmatter)
- [ ] Step 8: `CLAUDE.local.md` created at project root
- [ ] Step 9: Scoped `CLAUDE.md` files created (only if needed — skip is valid)
- [ ] Step 10: `.claude/agents/` created with starter subagents (proper YAML frontmatter)
- [ ] Step 11: `.learnings/log.md` created and wired
- [ ] Step 12: `.mcp.json` noted or created (only if MCP servers are relevant)
- [ ] Step 12b: Official plugins scanned, recommendations presented, conflicts checked, installed plugins tested
- [ ] Step 13: Plugin compatibility verified (structure is plugin-exportable)
- [ ] Step 14: All wiring verification checks pass (including plugin conflict checks)
</checklist>

---

## Step 1 — Discover the Project

Before creating anything, understand what exists.

**Actions:**
1. **Detect the environment**: Run `uname -s 2>/dev/null || echo Windows` to determine OS, shell, and path conventions. Record:
   - OS: Windows / macOS / Linux
   - Shell: PowerShell / cmd / bash / zsh
   - Path separator: `\` vs `/`
   - Line endings: CRLF vs LF
   - Package manager: npm / pip / cargo / go / dotnet / etc.
   This determines how ALL commands in CLAUDE.md and rules must be written.

2. **Detect mode** (A/B/C): Check for source files, `.claude/` directory, existing CLAUDE.md.

3. Read `README.md`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, `.csproj`, `.sln`, or any project manifest.

4. Identify the build, test, lint, typecheck, and format commands. Write them in OS-native syntax.

5. Note the directory structure and key modules.

6. Check for existing `.claude/`, `CLAUDE.md`, `.cursorrules`, `AGENTS.md`, or `.mcp.json` files — preserve useful content.

7. Check for existing linter/formatter configs (`.eslintrc`, `ruff.toml`, `.prettierrc`, `rustfmt.toml`, `.editorconfig`, etc.).

8. **Inventory installed plugins**: Read `~/.claude/plugins/installed_plugins.json` (if it exists) to see what plugins are already installed. Record their names, scopes, and cache paths. This informs Step 10 (agent naming) and Step 12b (plugin recommendations).

9. **Check marketplace availability**: Read `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json` (if it exists) and `~/.claude/plugins/install-counts-cache.json` to understand what's available. If neither exists, note that plugin recommendations will be skipped (user hasn't synced a marketplace yet).

10. **Ask the user** (STOP and wait for answer):
   - "Do you have coding style preferences beyond what the linter enforces? (brace style, early returns, ternary vs if/else, null handling idioms, etc.)"
   - "Do you use any MCP servers or external integrations? (databases, JIRA, Slack, GitHub, etc.)"
   - "What's your preferred workflow? (plan-first, iterate-fast, test-driven, etc.)"
   - "Do you want me to recommend official plugins based on your project? (I found {N} available in the marketplace)"

**Output:** Summarize findings and announce detected mode before proceeding.

```
✅ Step 1 complete — Mode {A/B/C}, {OS}/{shell}, {language}, {framework}, {N} commands identified
```

---

## Step 2 — Create `CLAUDE.md` (Project Root)

**Mode C**: If `CLAUDE.md` exists, read it first. Compare against the template below. Only add missing sections (Environment, Compact Instructions, Self-Improvement with triple triggers). Never overwrite project-specific content (Architecture, Key Files, Commands, Conventions, Gotchas).

Create a concise `CLAUDE.md` at the project root. This file loads every session — every line must earn its place. Keep it under 120 lines.

**Use this exact structure** (fill `{placeholders}` from Step 1):

```markdown
# {Project Name}

{One-sentence description.}

## Architecture

- Language: {detected}
- Framework: {detected}
- Key dependencies: {top 3-5}
- Database: {if any}

## Environment

Auto-detected on every session start via `.claude/hooks/detect-env.sh` (SessionStart hook).
Adapt all commands to match the detected OS and shell. Fallback values if hook fails:
- OS: {Windows / macOS / Linux}
- Shell: {PowerShell / bash / zsh / cmd}
- Path style: {backslash / forward-slash}
- IMPORTANT: All commands in this file and in `.claude/rules/` use {shell} syntax.

## Key Files

{List 5-10 most important files/dirs with one-line descriptions.}
{Use format: `path` — description}

{For detailed docs, use @import pointers instead of inlining content:}
- Project overview: @README.md
- API reference: @docs/api.md
- Available npm commands: @package.json
{@imports load the referenced file into context on demand — they keep this file lean while giving Claude access to detailed docs when needed.}

## Commands

- Build: `{command}`
- Test (single file): `{command} {file}` — prefer single test files over full suite
- Test (full suite): `{command}`
- Lint: `{command}`
- Typecheck: `{command}`
- Dev server: `{command}`
- Format: `{command}`

## Workflow

- Commit format: `{type}: {description}` (feat, fix, refactor, docs, chore, test)
- IMPORTANT: Run lint + typecheck before every commit
- IMPORTANT: Never commit .env, secrets, credentials, or dependency folders - some personal projects require it. As when bootstrapping how to handle current project.
- Prefer running single test files, not the full suite
- IMPORTANT: Compact proactively at ~70% context usage (`/compact`), don't wait for auto-compact. Auto-compact at ~85% loses more context and fires at bad times. Use `/context` to check usage.

## Conventions

{3-10 project-specific conventions Claude needs to know. Examples:}
{- Use named exports, not default exports}
{- All API responses follow the `{ data, error, meta }` shape}
{- State management via {library} — see `src/store/` for patterns}

## Gotchas

{Things that catch Claude off guard in this codebase. Add items here over time.}
{- Example: The `user` table has a soft-delete column — always filter by `deleted_at IS NULL`}
{- Example: Tests require `DATABASE_URL` env var even for unit tests}

## Compact Instructions

When compacting (manual or auto), ALWAYS preserve:
- The full list of modified files in this session
- The current implementation plan and its status
- Any test commands and their pass/fail results
- Error messages that haven't been resolved yet
- The active git branch and uncommitted changes context

{Add project-specific preservation rules here over time, e.g.:}
{- Preserve the database schema context if working on data layer}
{- Preserve the API contract if working on endpoints}

## Self-Improvement

IMPORTANT: The learning loop triggers on THREE events — not just user corrections:

**Trigger 1 — User corrects you or rejects an action:**
1. **Log it immediately**: Append an entry to `.learnings/log.md` with date, context, what went wrong, and the correction. Do this BEFORE continuing with the task.
2. **Assess urgency**: If the same mistake would recur in THIS session, also add a rule to the appropriate section of CLAUDE.md or `.claude/rules/` right now. Mark the `.learnings/` entry as "promoted".
3. **Batch the rest**: Non-urgent learnings stay in `.learnings/log.md` as "pending review" until the next `/reflect` run.

**Trigger 2 — Your own command or tool call fails:**
When a command returns a non-zero exit code, a tool call errors, or output is clearly wrong:
1. **Diagnose root cause**: Is it an environment issue (wrong OS syntax, missing tool), a logic error, or a transient failure?
2. **If environment/syntax**: Log to `.learnings/log.md` AND update the Environment section or Gotchas in CLAUDE.md immediately. These errors ALWAYS recur.
3. **If logic error**: Fix the command, then log the pattern to `.learnings/log.md` for review.
4. **Do NOT silently retry with a different command without logging the failure first.** The log is how the system learns.
5. **If 2 fix attempts fail, search the web.** Plugin issues, platform-specific bugs, and environment problems often have known solutions in GitHub issues or blog posts. Don't iterate blindly — research first.

**Trigger 3 — A task would benefit from a dedicated subagent:**
When you notice a task that is context-heavy, repetitive across sessions, or would benefit from isolated execution:
1. **Log it to `.learnings/log.md`** with tag `agent-candidate`, describing: what the task is, why a subagent would help (context isolation, parallelism, tool restriction), and a rough description of what the agent would do.
2. **Don't create the agent immediately** — let patterns accumulate. The `/reflect` skill reviews agent candidates and proposes new subagents when a pattern appears 2+ times.
3. **Signs a task needs its own agent**: it produces large output that clutters your main context, it's a read-only analysis task, it recurs across sessions, or multiple instances could run in parallel.

Run `/reflect` periodically to promote pending learnings, evolve subagents, prune rules Claude already follows, and tighten this file.

For each line in this file, ask: "Would removing this cause Claude to make mistakes?" If not, cut it.
```

**Guidelines for writing CLAUDE.md (context engineering):**

Research shows Claude can reliably follow ~150-200 instructions. Claude Code's own system prompt uses ~50 of those. Rules, plugins, skills, and user messages consume more. That leaves surprisingly few slots for CLAUDE.md — every line must earn its place.

- **120 lines max, audit ruthlessly**: For each line, ask "Would removing this cause Claude to make mistakes?" If not, cut it. Bloated CLAUDE.md files cause Claude to ignore ALL instructions uniformly, not just the new ones.
- **Use `@import` pointers, not inline content**: Don't paste API docs or code snippets into CLAUDE.md — they go stale and waste instruction slots. Instead: `See @docs/api.md for endpoint reference`. The `@path` syntax loads the file into context on demand.
- **Don't duplicate linter work**: Never send an LLM to do a linter's job. Code style rules belong in eslint/prettier/ruff configs and PostToolUse hooks, not in CLAUDE.md instructions.
- **Structured > narrative**: Compaction preserves structured content (lists, labeled sections) at ~92% fidelity vs ~71% for narrative paragraphs. Use scannable format.
- **Be specific, not vague**: "Use ES modules" not "follow best practices"
- **Use IMPORTANT/NEVER/ALWAYS for critical rules** — emphasis improves adherence
- **Don't tell Claude things it already knows** (language syntax, common patterns)
- **Prefer positive instructions with alternatives**: "Use `--baz` instead of `--foo-bar`" not "Never use `--foo-bar`" (Claude gets stuck without an alternative)
- **Skills > CLAUDE.md for domain knowledge**: CLAUDE.md loads every session. Domain knowledge that's only sometimes relevant belongs in skills (progressive disclosure — loaded on demand, ~100 tokens metadata cost vs full content).

**CRITICAL WIRING CHECK before moving on:** The Self-Improvement section MUST:
1. Mention `.learnings/log.md` by name
2. Say to log BEFORE continuing the task (Trigger 1)
3. Include Trigger 2 for command/tool failures (not just user corrections)
4. Include Trigger 3 for subagent evolution (agent-candidate tagging)
5. Say "Do NOT silently retry without logging"
6. Say "search the web" after failed fix attempts (Trigger 2, item 5)

The Context Management sections MUST:
6. Include a `## Compact Instructions` section listing what to preserve during compaction
7. Include proactive compaction at ~70% in the Workflow section
8. Use `@path` imports for any detailed docs (not inlined content)

Verify all eight are present. Fix if missing.

```
✅ Step 2 complete — CLAUDE.md created ({N} lines, under 120), Environment + Compact Instructions sections present, Self-Improvement wired with triple triggers, @imports used for detailed docs
```

---

## Step 3 — Create `.claude/rules/`

**Mode C**: If `.claude/rules/` exists, read each file. Only create missing rule files. For existing files, check if the Style section exists in `code-standards.md` and add it if missing. Never overwrite project-specific rules.

Create scoped rules files. Use `globs:` frontmatter to scope each file to relevant paths. Keep each file focused.

### 3a. `.claude/rules/general.md`

```markdown
# General Rules

- Never commit to main/master directly — always use feature branches
- Every commit must leave the repo in a buildable, testable state
- No TODO comments without a linked issue (TODO(#123): ...)
- Delete dead code — don't comment it out
- English for all code, comments, and commit messages
- When unsure about implementation, check existing patterns in the codebase first
```

### 3d. `.claude/rules/lsp-guidance.md` (conditional — only if LSP plugins are installed or recommended)

**When to create this file**: If Step 1 detected installed LSP plugins (from `installed_plugins.json`) or Step 12b will recommend LSP plugins, create this file. Skip if no LSP plugins are relevant.

**How to populate**: The bootstrap agent MUST research the project's languages and installed/recommended LSP plugins to generate **language-specific, accurate guidance**. Do NOT copy the template below verbatim — adapt it to the actual languages in the project. A Python+TypeScript project gets different guidance than a C#+Go project.

**Research process**:
1. Identify all source languages in the project (from file extensions detected in Step 1)
2. For each language with an LSP plugin (installed or recommended), research:
   - Which LSP operations work best with that language server
   - Known limitations or quirks (e.g., call hierarchy limitations in pyright, memory usage in rust-analyzer)
   - Language-specific best operations (e.g., `goToImplementation` is critical for interface-heavy languages like C#/Java, less useful for Go's implicit interfaces)
3. Use web search if needed — search for `"{language-server-name}" LSP capabilities limitations` to get current, accurate info
4. Generate the guidance with concrete, language-aware recommendations

**Template** (adapt to actual project languages):

```markdown
# LSP Tool Guidance

## When to Use LSP vs Grep
- **LSP** for type-aware analysis on code symbols (properties, methods, classes, interfaces):
  - "What uses this?" → `findReferences`
  - "Where is this defined?" → `goToDefinition`
  - "What implements this interface?" → `goToImplementation`
  - "What calls this method?" → `incomingCalls` / `outgoingCalls`
  - "What type is this?" → `hover`
  - "What symbols are in this file?" → `documentSymbol`
  - "Find a symbol by name across the project" → `workspaceSymbol`
- **Grep** for string literals, config keys, regex patterns, cross-language search, comments, or log messages
- LSP requires an exact position (file, line, character) — use Grep or Glob to locate the symbol first, then LSP to analyze it
- If LSP fails (server not running, unsupported type), fall back to Grep

## Workspace Requirements
{List the workspace config files each language server needs. Servers fail SILENTLY without these.}
{Examples:}
- C#: `.sln` or `.csproj` must be in or above the workspace root
- TypeScript: `tsconfig.json` must be in the workspace root (monorepos need per-workspace configs)
- Python: `pyproject.toml` or `pyrightconfig.json` for best results
- Go: `go.mod` must be in the workspace root
- Rust: `Cargo.toml` must be in the workspace root
- Java: Maven `pom.xml`, Gradle `build.gradle`, or Eclipse `.classpath`
- C/C++: `compile_commands.json` required — without it, many operations fail silently

## Language-Specific Guidance
{Generate this section based on the ACTUAL languages detected in the project. Examples below — use only the relevant ones.}

### {Language} ({language-server})
{For each language in the project, list:}
- **Best operations**: {which LSP operations are most valuable for this language}
- **Limitations**: {known limitations — be specific}
- **Tips**: {language-specific tips}

{Example entries — adapt or remove based on project:}

### C# (csharp-ls)
- **Best operations**: `goToImplementation` (critical — interface-heavy language), `findReferences`, `hover`, full call hierarchy
- **Limitations**: Can be slower on large solutions with many projects
- **Tips**: All operations work reliably. Prefer `goToImplementation` when tracing interface usage through DI

### Python (pyright)
- **Best operations**: `hover` (see inferred types), `findReferences`, `documentSymbol`, `workspaceSymbol`
- **Limitations**: Call hierarchy (`incomingCalls`/`outgoingCalls`) is incomplete — may miss dynamic dispatch. Memory-intensive on large projects
- **Tips**: `hover` is especially valuable since Python lacks explicit type annotations in many codebases

### TypeScript/JavaScript (typescript-language-server)
- **Best operations**: All operations work reliably. `findReferences` and `goToDefinition` are precise
- **Limitations**: Slower on projects with 10k+ files. Monorepo setups need correct `tsconfig.json` per workspace
- **Tips**: `goToImplementation` useful for class hierarchies; less useful in functional-style code

### Go (gopls)
- **Best operations**: `goToDefinition`, `findReferences`, `hover` — fast and reliable
- **Limitations**: `goToImplementation` less useful (Go has implicit interfaces — satisfying types aren't explicitly linked). Call hierarchy is partial
- **Tips**: Generally the fastest and most reliable LSP. Requires `go.mod` in workspace root

### Rust (rust-analyzer)
- **Best operations**: `goToDefinition`, `findReferences`, `hover` (excellent type info for complex generics)
- **Limitations**: Very memory-intensive (500MB+ on large projects). Call hierarchy operations may hang or timeout. Slow on first initialization (compiles project)
- **Tips**: Requires full Cargo project setup. Consider disabling if memory is constrained

### Java (jdtls)
- **Best operations**: `goToImplementation` (best-in-class — critical for interface-heavy Java), `findReferences`, full call hierarchy
- **Limitations**: ~8 second startup (JVM warmup). Can consume 1GB+ on large projects
- **Tips**: Most useful for tracing interface implementations across dependency injection

### C/C++ (clangd)
- **Best operations**: `goToDefinition`, `findReferences`, `hover` (good type info)
- **Limitations**: `goToImplementation` unreliable (C++ lacks a clear interface model). REQUIRES `compile_commands.json` — without it, many operations fail silently
- **Tips**: Generate `compile_commands.json` via `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` or `bear make`

## Multi-Language Projects
{If the project has multiple languages, add this section:}
- Each language server operates independently — LSP operations only work within their language boundary
- For cross-language references (e.g., TypeScript calling a Python API), use Grep
- When a symbol exists in multiple languages (e.g., shared type names), specify the file path to disambiguate
```

**CRITICAL**: Do not include language sections for languages NOT in the project. A C#-only project should only have the C# section. A Python+TypeScript project gets both Python and TypeScript sections. Research each included language server to ensure the guidance is accurate and current.

### 3b. `.claude/rules/code-standards.md`

Scope with `globs:` to your source files. Include only rules your linter does NOT already catch.

**IMPORTANT:** The Style section MUST exist even if mostly empty — it is populated from real corrections during usage.

```markdown
---
globs: "{src,lib,app}/**"
---
# Code Standards

## Style (populate from real corrections)
{Include any preferences the user provided in Step 1. If none, use these placeholders:}
- {This section starts nearly empty — add rules here when the user corrects style choices}
- IMPORTANT: When the user corrects a style choice, log it to .learnings/log.md AND add it here immediately

## Naming
- All names: descriptive English words, no abbreviations
- Functions: verb-noun pattern (fetchUser, validateInput, renderCard)
- Booleans: is/has/should/can prefix (isReady, hasPermission)

## Functions
- Max 50 lines — split if longer
- Single responsibility: if you need "and" to describe it, split it
- Docstrings on all public/exported functions

## Error Handling
- Never swallow errors — always log with context
- I/O operations always have explicit error handling
- Fail loudly: throw/raise errors instead of silent fallbacks

## Constants
- No magic numbers or strings — extract to named constants

## Comments
- Comments explain WHY, never WHAT
- NEVER leave commented-out code — delete it (git has history)

## Idempotency
- Check before creating: "does this already exist?"
- Operations that touch state should be safe to run twice

## Paths and Files
- Never hardcode absolute paths — use config or relative from project root
- Use path-joining utilities, not string concatenation
- Always specify encoding for file operations (UTF-8)

## Cleanup
- Remove unused imports, variables, functions, and types after every change
- When deleting a feature, also remove its tests, types, constants, and docs

## SQL (if applicable)
- NEVER string-format queries — always use parameterized queries
```

### 3c. `.claude/rules/shell-standards.md`

**Only create if the project uses bash/shell scripts.** If Windows-only, adapt to PowerShell conventions or skip.

```markdown
---
globs: "**/*.sh"
---
# Shell Standards

- Start with: `#!/usr/bin/env bash` + `set -euo pipefail`
- Quote all variables: `"${my_var}"` not `$my_var`
- Use `[[ ]]` for conditionals (not `[ ]`)
- Check command existence: `command -v tool >/dev/null 2>&1`
```

```
✅ Step 3 complete — {N} rules files created, Style section present in code-standards.md
```

---

## Step 4 — Create `.claude/settings.json` (Hooks)

**Mode C**: If `.claude/settings.json` exists, read it. Check for each required hook event (SessionStart, PreToolUse, SubagentStop). Only add missing hooks. If hooks exist but use inline commands instead of external scripts, propose extracting to `.claude/hooks/` scripts. Never remove existing project-specific hooks.

Hooks enforce rules deterministically — they run on every tool use, unlike CLAUDE.md which is advisory. Start with essential guards.

**CRITICAL**: Hooks receive JSON input on **stdin**, not via environment variables. Use `cat` to read stdin and the `.claude/scripts/json-val.sh` helper (created in this step) to parse fields. Do NOT use `jq` — it is not installed on all systems. The JSON input includes `tool_name`, `tool_input`, `session_id`, and other fields depending on the event.

**First**, create the portable JSON extraction helper at `.claude/scripts/json-val.sh`. This replaces `jq` using Python3 (always available as a project dependency):

```bash
#!/bin/bash
set -euo pipefail
# Portable jq replacement using Python3 (always available).
# Usage: echo '{"a":{"b":"val"}}' | bash .claude/scripts/json-val.sh a.b
#   → val
# Returns empty string for missing keys.
python3 -c "
import sys, json
data = json.load(sys.stdin)
for k in '${1}'.split('.'):
    if isinstance(data, dict):
        data = data.get(k, '')
    else:
        data = ''
        break
print('' if data is None else str(data))" 2>/dev/null || echo ""
```

**Hook event lifecycle** (ordered):
- `SessionStart` — session begins or resumes (**stdout is added as context Claude can see** — ideal for env detection)
- `Notification` — status updates during processing
- `UserPromptSubmit` — user sends a message (can modify/reject)
- `PreToolUse` — before a tool executes (can block with exit 2)
- `PostToolUse` — after a tool completes (can trigger automation)
- `SubagentStop` — a subagent finishes (input includes `agent_type`, `agent_id`, `agent_transcript_path`, `last_assistant_message` — **NOT** `agent_name`)
- `Stop` — session ends

**Hook types available**:
- `command` — run a shell command (stdin JSON, exit codes control flow)
- `prompt` — send to a Claude model for single-turn yes/no evaluation
- `http` — POST JSON to an HTTP endpoint
- `agent` — spawn a subagent that can use tools to verify conditions

**First**, create the git guard script at `.claude/hooks/guard-git.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# PreToolUse hook: block dangerous git operations
# Reads JSON from stdin, extracts the bash command, checks for violations.

INPUT=$(cat)
CMD=$(echo "$INPUT" | bash .claude/scripts/json-val.sh tool_input.command)

# Block force push/commit
if echo "$CMD" | grep -qE 'git\s+(push|commit)\s+.*(-f|--force)'; then
    echo "BLOCK: Force push/commit is not allowed" >&2
    exit 2
fi

# Block push directly to main/master (anchor to end of command or as standalone branch arg)
if echo "$CMD" | grep -qE 'git\s+push\s+\S+\s+(main|master)\s*($|;|&&|\|)'; then
    echo "BLOCK: Never push directly to main/master" >&2
    exit 2
fi

# Also block if current branch is main/master and pushing without explicit branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if echo "$CMD" | grep -qE 'git\s+push\s*$' && [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    echo "BLOCK: Cannot push from main/master branch" >&2
    exit 2
fi

exit 0
```

Make it executable: `chmod +x .claude/hooks/guard-git.sh`

Then create the settings.json:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/guard-git.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Ask the user** (STOP and wait for answer):
- "Should I add a PostToolUse hook to auto-format files after edits? (e.g., prettier, black, gofmt)"
- "Should I block destructive SQL (DROP, DELETE, TRUNCATE)?"
- "Any directories that should be read-only (migrations, generated code)?"
- "Should I add a prompt-based hook for code quality checks? (uses a fast model to evaluate output)"

Add additional hooks based on their answers. Example PostToolUse auto-format — create `.claude/hooks/auto-format.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# PostToolUse hook: auto-format files after Edit/Write
INPUT=$(cat)
FILE=$(echo "$INPUT" | bash .claude/scripts/json-val.sh tool_input.file_path)
if [ -z "$FILE" ]; then
    FILE=$(echo "$INPUT" | bash .claude/scripts/json-val.sh tool_input.path)
fi
if [ -n "$FILE" ] && [ -f "$FILE" ]; then
    npx prettier --write "$FILE" 2>/dev/null || true
fi
exit 0
```

Then add to settings.json:

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "command",
      "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/auto-format.sh\"",
      "timeout": 10
    }
  ]
}
```

Example prompt-based hook (uses a fast model as evaluator). Scope the evaluation to concrete risks, not vague "safe and appropriate":

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "prompt",
      "prompt": "The assistant is about to run a bash command. Check ONLY: (1) Does it modify files outside the project directory? (2) Does it delete files or directories? (3) Does it make network requests to unknown endpoints? If any apply, respond {\"decision\": \"block\", \"reason\": \"...\"}. Otherwise respond {\"decision\": \"allow\"}. Raw JSON only.",
      "timeout": 30
    }
  ]
}
```

**Do NOT add** a UserPromptSubmit hook for correction detection. While it seems useful in theory (using a prompt-type hook to classify whether the user's message is a correction), in practice the LLM classifier is too aggressive — it triggers on problem reports, investigation requests, and bug descriptions that aren't corrections of Claude's behavior. This causes the conversation to block until the user sends "continue", which is worse than the problem it tries to solve. The Self-Improvement section in CLAUDE.md already instructs Claude to log corrections; rely on that instead.

**Always add**: SubagentStop hook for agent usage tracking. Create `.claude/hooks/track-agent.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# SubagentStop hook: log agent usage for /reflect analysis
INPUT=$(cat)
AGENT_TYPE=$(echo "$INPUT" | bash .claude/scripts/json-val.sh agent_type)
AGENT_ID=$(echo "$INPUT" | bash .claude/scripts/json-val.sh agent_id)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "$TIMESTAMP | type=$AGENT_TYPE | id=$AGENT_ID" >> .learnings/agent-usage.log
exit 0
```

Make it executable: `chmod +x .claude/hooks/track-agent.sh`

Then add to settings.json:

```json
{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/track-agent.sh\""
    }
  ]
}
```

**Always add**: SessionStart hook for automatic environment detection. This injects OS, shell, and tooling info into Claude's context at zero LLM cost — critical when you switch between machines (Windows/macOS/Linux) or use web Claude Code sessions. SessionStart stdout is automatically added as context Claude can see.

First, create the detection script at `.claude/hooks/detect-env.sh`:

```bash
#!/usr/bin/env bash
# Lightweight environment detection — runs on every session start
# Output goes to Claude as context (SessionStart stdout is injected)

OS="unknown"; SHELL_NAME="unknown"; PATH_SEP="/"; LINE_ENDINGS="LF"

case "$(uname -s 2>/dev/null)" in
  Linux*)   OS="Linux" ;;
  Darwin*)  OS="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) OS="Windows"; PATH_SEP="\\"; LINE_ENDINGS="CRLF" ;;
  *)        OS="$(uname -s 2>/dev/null || echo 'unknown')" ;;
esac

# Detect shell (this script runs in bash — PowerShell detection relies on MINGW/MSYS/CYGWIN uname above)
if [ -n "$BASH_VERSION" ]; then SHELL_NAME="bash"
elif [ -n "$ZSH_VERSION" ]; then SHELL_NAME="zsh"
else SHELL_NAME="$(basename "${SHELL:-sh}" 2>/dev/null || echo 'sh')"
fi

# Detect if running in web/remote Claude Code session
REMOTE=""
if [ -n "$CLAUDE_CODE_REMOTE" ]; then REMOTE=" (remote/web session)"; fi

# Detect key tools
TOOLS=""
command -v node >/dev/null 2>&1 && TOOLS="$TOOLS node/$(node -v 2>/dev/null)"
command -v python3 >/dev/null 2>&1 && TOOLS="$TOOLS python/$(python3 --version 2>/dev/null | cut -d' ' -f2)"
command -v npm >/dev/null 2>&1 && TOOLS="$TOOLS npm"
command -v jq >/dev/null 2>&1 && TOOLS="$TOOLS jq" # optional, hooks use json-val.sh instead
command -v git >/dev/null 2>&1 && TOOLS="$TOOLS git"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
CHANGED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

echo "[Environment] OS=$OS | Shell=$SHELL_NAME | Path=$PATH_SEP | Endings=$LINE_ENDINGS${REMOTE} | Branch=$BRANCH | Uncommitted=$CHANGED | Tools:$TOOLS"
```

Make it executable: `chmod +x .claude/hooks/detect-env.sh`

Then add the SessionStart hook:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/detect-env.sh\"",
      "timeout": 5
    }
  ]
}
```

The full `settings.json` should include hooks under **all** of these events at minimum:

```json
{
  "hooks": {
    "SessionStart": [ ... ],
    "PreToolUse": [ ... ],
    "SubagentStop": [ ... ]
  }
}
```

```
✅ Step 4 complete — .claude/settings.json created with {N} hook(s) including SubagentStop tracking and SessionStart env detection, using stdin JSON input
```

---

## Step 5 — Create Self-Improvement Skill (`.claude/skills/reflect/SKILL.md`)

**Mode C**: If `.claude/skills/reflect/SKILL.md` exists, read it and compare against the template below. Check specifically for: step 6 (plugin audit) — this was added in v3 and may be missing from older bootstraps. Add missing sections without overwriting project-specific customizations.

This skill powers the self-improvement loop. It follows the official Agent Skills format with YAML frontmatter for progressive disclosure: the `name` and `description` are always in context (~100 tokens), but the full body only loads when triggered.

```markdown
---
name: reflect
description: "Analyze recent work and improve project configuration — including rules, conventions, AND subagent evolution. Use when the user says /reflect, asks to review learnings, wants to improve CLAUDE.md or rules, or after sessions with repeated mistakes, corrections, or friction. Also use proactively when .learnings/log.md has pending entries."
---

# Reflect and Improve

Analyze the current CLAUDE.md, rules, and agent roster, then propose improvements based on accumulated learnings and usage patterns.

## Process

1. **Read the learnings log**: Read `.learnings/log.md`. This is the primary input — it contains corrections, discoveries, and agent-candidate entries from recent sessions.
2. **Read agent usage log**: Read `.learnings/agent-usage.log` (if it exists). This is written by the SubagentStop hook and shows which agents are actually being used.
3. **Review current state**: Read CLAUDE.md, all files in `.claude/rules/`, and all files in `.claude/agents/`
4. **Promote pending learnings**: For each "pending review" entry in `.learnings/log.md`:
   - Decide where it belongs: CLAUDE.md (Conventions, Gotchas, Workflow), `.claude/rules/`, or nowhere (one-off)
   - Draft the rule following the meta-rules below
   - Mark the entry as "promoted to {file}" or "dismissed — {reason}"
5. **Evolve subagents**: Review entries tagged `agent-candidate` in `.learnings/log.md` and correlate with `.learnings/agent-usage.log`:
   - **Create new agents**: If 2+ `agent-candidate` entries describe similar tasks, propose a new subagent. Draft the agent file with name, description, tools, and system prompt.
   - **Retire unused agents**: If an agent hasn't been used in the last N sessions (check agent-usage.log), propose removing or merging it.
   - **Improve existing agents**: If learnings entries mention an agent producing poor results, propose updates to its system prompt or tool restrictions.
   - **Suggest parallelization**: If multiple agents could run simultaneously on a task, note this as a workflow improvement.
6. **Plugin audit**: Check the official marketplace for plugins that match or conflict with the current project setup. All data is read from local cache — no network access required.
   a. **Read marketplace data**:
      - `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json` — master index of all available plugins (name, description, category, lspServers)
      - `~/.claude/plugins/install-counts-cache.json` — popularity data for quality filtering
      - `~/.claude/plugins/installed_plugins.json` — currently installed plugins
   b. **Detect project signals**: Scan the project for:
      - File extensions (`.py`, `.ts`, `.go`, `.rs`, etc.) — match against `lspServers.*.extensionToLanguage` in marketplace.json
      - Dependency files (`package.json`, `pyproject.toml`, `requirements.txt`, `composer.json`, `Cargo.toml`, `go.mod`)
      - Config files (`vercel.json`, `.sentryclirc`, `firebase.json`, `supabase/` dir)
      - Git remote URL (`git remote get-url origin`) — GitHub vs GitLab
      - Framework keywords in dependency names (react, vue, angular, django, fastapi, laravel, etc.)
   c. **Match using 3-tier system**:
      - **Tier 1 — LSP** (auto-recommend if matching files exist): Direct `extensionToLanguage` lookup. Zero false positives.
      - **Tier 2 — Framework/Service** (keyword match against deps + configs):
        | Signal | Plugin |
        |---|---|
        | `.py`/`.pyi` files | `pyright-lsp` |
        | `.ts`/`.tsx` files | `typescript-lsp` |
        | `stripe` in deps | `stripe` |
        | `supabase` in deps/config | `supabase` |
        | `firebase` in deps | `firebase` |
        | `@playwright/test` in devDeps | `playwright` |
        | `laravel` in composer.json | `laravel-boost` |
        | GitHub remote | `github` |
        | GitLab remote | `gitlab` |
        | `vercel.json` exists | `vercel` |
        | `sentry` in deps | `sentry` |
        | Frontend files (HTML/CSS/JSX) | `frontend-design` |
      - **Tier 3 — Universal** (always relevant, recommend top by install count >50k):
        `context7`, `code-review`, `code-simplifier`, `commit-commands`, `security-guidance`, `claude-md-management`
      - Filter all candidates by >5,000 installs to avoid low-quality entries
   d. **Check for conflicts with installed plugins**:
      - Agent name collisions: compare project `.claude/agents/*.md` names against plugin `agents/*.md` files (read from each plugin's cache path in installed_plugins.json)
      - Hook overlaps: compare project `.claude/settings.json` hook events+matchers against plugin `hooks/hooks.json` files
      - Skill name overlaps: compare project `.claude/skills/` directory names against plugin `skills/` directories
      - SessionStart overhead: count total instructions injected by all plugin SessionStart hooks
   e. **Check for unused installed plugins**: Cross-reference installed plugins against `.learnings/agent-usage.log` and session patterns. Flag plugins whose agents/skills haven't been used.
   f. **Check for stale plugin versions**: For each installed plugin, compare its `gitCommitSha` (from `installed_plugins.json`) against the marketplace source. If the marketplace repo has been updated since the plugin was installed (compare `installedAt` timestamp against marketplace `lastUpdated` in `~/.claude/plugins/known_marketplaces.json`), flag the plugin as potentially outdated. Recommend re-install to get the latest version:
      ```
      /plugin install {name}@claude-plugins-official
      ```
      Note: There is no dedicated update command — re-install IS the update mechanism.
   g. **Check LSP prerequisites**: For any installed or recommended LSP plugin, verify the required binary exists on PATH:
      ```bash
      # Example for pyright-lsp
      command -v pyright-langserver >/dev/null 2>&1 && echo "ready" || echo "needs: pip install pyright"
      ```
      If missing, include the install command in the report. See Appendix E for the full LSP prerequisites table.
   h. **Report in the "Plugin Audit" section**:
      ```yaml
      Plugin Audit:
        install_candidates:
          - plugin: {name} ({installs} installs)
            reason: "{why it matches this project}"
            install: "/plugin install {name}@claude-plugins-official"
            prerequisites: "{binary needed + install command, if LSP}"
        update_candidates:
          - plugin: {name}
            installed: "{date}"
            reason: "Marketplace updated since install — re-install for latest"
            update: "/plugin install {name}@claude-plugins-official"
        uninstall_candidates:
          - plugin: {name}
            reason: "{not relevant to project / unused for N sessions}"
            uninstall: "/plugin uninstall {name}@claude-plugins-official"
        conflict_warnings:
          - plugin: {name}
            issue: "{what conflicts — agent name, hook, skill}"
            fix: "{how to resolve — rename project agent, adjust hook, etc.}"
        lsp_prerequisites_missing:
          - plugin: {name}
            binary: "{required binary name}"
            install: "{install command}"
        complementary_notes:
          - "{e.g., project /write-prompt + plugin writing-skills are complementary, not duplicates}"
      ```
7. **Identify additional gaps**: Look for:
   - Rules too vague to be actionable
   - Missing conventions the codebase follows but aren't documented
   - Rules that duplicate what linters already enforce (remove these)
   - Sections grown too long (split or prune)
   - Gotchas section — does it cover known pain points?
8. **Check file sizes and context budget**: CLAUDE.md should be <120 lines. Rules files <40 lines each. Run `wc -l CLAUDE.md` and verify. If over 120 lines:
   - Move domain-specific knowledge into skills (progressive disclosure)
   - Replace inline content with `@path` import pointers
   - Remove rules that duplicate linter/formatter behavior
   - Move rarely-needed reference content to `.claude/skills/` reference files
   - Remember: Claude reliably follows ~150-200 instructions total. The system prompt uses ~50. Every CLAUDE.md line competes for the remaining slots.
9. **Mine session history** (if available): Search `~/.claude/projects/` JSONL logs for patterns — repeated corrections, recurring friction, tasks that consumed excessive context.
10. **Propose changes**: Present ALL changes (rule promotions + agent evolution + plugin recommendations + other improvements) with what, where, and why. Group them:
   - **Rules & conventions**: changes to CLAUDE.md and .claude/rules/
   - **Agent evolution**: new agents, retired agents, improved agents
   - **Plugin recommendations**: install, uninstall, conflict resolution
   - **Cleanup**: pruning, merging, deduplication
11. **Wait for approval**: Don't modify files until the user confirms.
12. **Apply approved changes**: Edit files. Clean up promoted entries from `.learnings/log.md` — remove or archive them so the log doesn't grow unbounded. Clear processed entries from `.learnings/agent-usage.log`.

## Meta-Rules for Writing Rules

- Lead with WHY (context), then WHAT (the rule)
- Use NEVER or ALWAYS for critical rules
- One rule per line — scannable, not paragraph-form
- If a rule needs an example, use BAD/GOOD format
- Prefer positive instructions ("do X") over negative ("don't do Y")
- Test: would removing this rule cause a mistake? If not, don't add it

## Meta-Rules for Proposing Agents

- An agent must have a clear, single responsibility — if you need "and" to describe it, split it
- Read-only agents (review, analysis, research) should have restricted tools: Read, Grep, Glob
- Agents with side effects (write, deploy) need explicit tool lists — never inherit all
- Prefer fewer, well-defined agents over many narrow ones — 3-5 project agents is the sweet spot
- The description must be specific enough that Claude routes correctly, but broad enough to be useful
```

**CRITICAL WIRING CHECK:** Verify that:
- Step 1 says "Read `.learnings/log.md`"
- Step 2 says "Read `.learnings/agent-usage.log`"
- Step 5 covers agent evolution (create, retire, improve)
- Step 6 covers plugin audit (marketplace scan, conflict detection, recommendations)
- Step 12 says to clean up promoted entries

```
✅ Step 5 complete — reflect skill created with proper YAML frontmatter, reads .learnings/log.md in step 1, evolves agents in step 5, audits plugins in step 6
```

---

## Step 6 — Create Audit Skills

**Mode C**: If these skills exist, skip. They are generic templates unlikely to have project-specific customizations worth preserving.

```markdown
---
name: audit-file
description: "Audit a source file against project code standards. Use when the user says /audit-file, asks to review code quality, wants a file checked against standards, or mentions 'audit', 'review', or 'check standards' for a specific file."
---

# Audit Source File

Audit `$ARGUMENTS` against the standards in `.claude/rules/code-standards.md`.

## Process

1. Read the target file and `.claude/rules/code-standards.md`
2. Check each standard against the file
3. Report findings:

```yaml
file: {path}
lines: {count}
issues:
  - line: {N}
    severity: critical | high | medium | low
    rule: "{which rule violated}"
    snippet: "{offending code}"
    fix: "{how to fix}"
score: "{N}/10"
```

Focus on issues that matter — skip nitpicks that formatters handle.
```

```
✅ Step 6 complete — audit-file skill created with proper YAML frontmatter
```

### Also create: `.claude/skills/audit-memory/SKILL.md`

This skill audits the project memory system for staleness, broken links, and promotion candidates. It works with Claude Code's auto-memory (`~/.claude/projects/` memory files) and the project's `.learnings/` system.

```markdown
---
name: audit-memory
description: "Audit project memory files for staleness, duplicates, and promotion candidates. Use when cleaning up memory or validating its current state."
allowed-tools: Read, Grep, Glob, Write, Edit
user-invocable: true
---

# Audit Memory

Review all project memory and learnings for staleness, accuracy, and actionability.

## Process

### 1. Inventory
Read all memory sources:
- The project's auto-memory directory (path varies by project — check `~/.claude/projects/`)
- `MEMORY.md` index file
- `.learnings/log.md` (pending learnings)
- `.learnings/agent-usage.log` (agent usage data)

### 2. Validate Memory Index
- Every file listed in `MEMORY.md` must exist
- Every memory file in the directory must be listed in `MEMORY.md`
- Report orphans and broken links

### 3. Validate Individual Memories
For each memory file, check:
- **Frontmatter**: Has `name`, `description`, `type` fields
- **Type correctness**: Content matches declared type (user/feedback/project/reference)
- **Staleness**: Cross-check against current codebase state (paths, tools, facts)
- **Duplicates**: Two memories covering the same topic — propose merging
- **Contradictions**: Memory says X but codebase shows Y — flag

### 4. Review Learnings Log
- Pending entries that should be promoted to rules or memories
- Entries older than 30 days still "pending review" — propose promote or dismiss

### 5. Review Agent Usage
- Which agents are used most/least
- Patterns suggesting a missing agent

### 6. Report
Group findings by severity: Critical, Stale, Housekeeping, Promotion candidates, Agent insights.

### 7. Wait for Approval
Present all proposed changes. Don't modify anything until the user confirms.

### 8. Apply
Execute approved changes.
```

```
✅ Step 6b complete — audit-memory skill created with proper YAML frontmatter
```

---

## Step 7 — Create Prompting Skill (`.claude/skills/write-prompt/SKILL.md`)

**Mode C**: If this skill exists, read it and check if project-specific content was added (e.g., cron MD patterns, custom workflow references). Preserve any customizations. Only update the generic template sections if outdated.

**Complementary plugins** (not replacements — these add methodology, this skill adds structure):
- If `superpowers` is installed, its `writing-skills` skill adds TDD methodology for skill creation (pressure testing, CSO description optimization). This skill covers structural and prompting principles that `writing-skills` does not: subagent authoring, workflow patterns (sequential/parallel/evaluator-optimizer), invocation control, and project-specific instructions (cron MDs, agent task files, CI prompts).
- If `skill-creator` is installed, it adds eval frameworks and benchmarking for skills. Use `/write-prompt` for quick reference when writing any LLM instruction, `skill-creator` for full create-test-iterate lifecycle on reusable skills.

```markdown
---
name: write-prompt
description: "Best practices for writing LLM instructions — skills, subagents, CI prompts, or agent task files. Use when the user asks to create a skill, write a prompt, author agent instructions, create a subagent, or build any instruction file an LLM will execute."
---

# Writing Effective LLM Instructions

Apply these principles when writing skills, subagent definitions, CI prompts, or any instruction file.

## Skill Structure (Agent Skills format)

```
skill-name/
├── SKILL.md (required — YAML frontmatter + markdown instructions)
├── references/ (optional — docs loaded into context as needed)
├── scripts/ (optional — executable code, runs without loading into context)
└── assets/ (optional — templates, icons, fonts used in output)
```

### Progressive Disclosure
Skills use three-level loading:
1. **Metadata** (name + description from YAML frontmatter) — always in context (~100 tokens)
2. **SKILL.md body** — loaded when skill triggers (<500 lines ideal)
3. **Bundled resources** — loaded as needed (scripts execute without entering context)

### YAML Frontmatter (required)
```yaml
---
name: skill-name          # lowercase, hyphens, max 64 chars, becomes /slash-command
description: "What this skill does and WHEN to use it. Be pushy — include trigger phrases."
---
```

The description is the primary triggering mechanism. Include both what the skill does AND specific contexts/phrases that should activate it.

### Invocation Control
- Default: both user (/skill-name) and Claude can invoke
- `disable-model-invocation: true` — only user can invoke (for side-effects: deploy, commit)
- `user-invocable: false` — only Claude can invoke (background knowledge)
- `context: fork` — runs in a subagent with its own context window

## Subagent Structure (.claude/agents/)

```yaml
---
name: agent-name
description: "When this agent should be invoked and what it specializes in"
tools: Read, Grep, Glob     # optional — omit to inherit all tools
model: sonnet                # optional — defaults to current model
---

You are a [role description]...

[Detailed system prompt with checklists, patterns, constraints]
```

## Principles

### Be Explicit, Not Implicit
- BAD: "Process the pending items"
- GOOD: "Run `python src/pipeline.py list-pending --format json`. For each item with status 'ready', run `python src/pipeline.py process --id {item_id}`."

### One Task, One Responsibility
- Each instruction file does exactly one thing
- If a task needs "and" to describe it, split into separate instructions

### Provide All Context — Assume No Memory
- Every session is stateless — include all references
- Include exact file paths, exact commands, exact schemas

### Constrain the Agent
- List exactly which commands to run — no improvisation
- Define what NOT to do
- Set clear success/failure criteria

### Handle the Empty Case
- Always define what happens when there's nothing to process

### Match Effort to Complexity
- Simple tasks: short instructions, minimal reasoning
- Complex tasks: detailed steps, verification at each stage
- If you need >1 page of instructions, split the task

### Workflow Patterns (choose based on task structure)
- **Sequential**: Tasks have dependencies — step B needs step A's output
- **Parallel**: Tasks are independent — run subagents simultaneously, aggregate results
- **Evaluator-Optimizer**: Output needs iterative refinement — generator + evaluator loop
```

```
✅ Step 7 complete — write-prompt skill created with progressive disclosure and workflow patterns
```

---

## Step 8 — Create `CLAUDE.local.md` (Personal Preferences)

**Mode C**: If `CLAUDE.local.md` exists, skip entirely. This file contains personal preferences accumulated over time — never overwrite.

Create `CLAUDE.local.md` in the project root. This file is gitignored — personal preferences only.

```markdown
# Local Preferences

Personal style and workflow preferences. These supplement CLAUDE.md for this developer only.

## Style Preferences

{Fill from user's Step 1 answers. If none provided, use these placeholders:}
{- Prefer explicit braces on all if/else blocks, even single-line}
{- Prefer readable method chains over terse syntax}

## Workflow

{- I prefer seeing the plan before you start coding}
{- Don't run tests automatically — I'll tell you when}

<!-- What goes where:
  CLAUDE.md          — Team conventions, architecture, commands, gotchas (committed)
  CLAUDE.local.md    — Personal code style, workflow habits (gitignored)
  .claude/rules/     — Objective code standards applying to everyone (committed)
  .claude/settings.json     — Hooks shared by team (committed)
  .claude/settings.local.json — Personal hook overrides (gitignored)
-->
```

Ensure `.gitignore` includes:
```
CLAUDE.local.md
.claude/settings.local.json
```

```
✅ Step 8 complete — CLAUDE.local.md created
```

---

## Step 9 — Create Scoped CLAUDE.md Files (If Needed)

Only create these if the directory has distinct context that doesn't belong in root CLAUDE.md. Keep each under 30 lines. **Skipping this step is valid.**

Good candidates:
- `tests/CLAUDE.md` — Test patterns, fixtures, setup conventions
- `src/CLAUDE.md` — Module boundaries, internal API contracts
- `scripts/CLAUDE.md` — Script conventions, required env vars

```
✅ Step 9 complete — {created N scoped files | skipped: project doesn't need scoped files}
```

---

## Step 10 — Create `.claude/agents/` (Subagents)

**Mode C**: If `.claude/agents/` exists, read all agent files. Only create agents that don't already exist. For existing agents, preserve them — they likely have project-specific system prompts. Still run the plugin collision pre-flight check below.

Subagents are specialized AI assistants that run in their own context window with custom system prompts and tool restrictions. They help you preserve context (keeping exploration out of your main conversation), enforce constraints, and parallelize work.

**Create 2-3 practical starter agents** based on the project type. Each agent is a markdown file with YAML frontmatter.

**Key design principles:**
- Subagents get their own context window — the parent's conversation doesn't carry over
- The only channel from parent to subagent is the prompt string — include all needed context
- The parent receives the subagent's final message as the tool result
- Subagents cannot spawn other subagents (no infinite nesting)
- Scope tools per agent — read-only agents should only get Read, Grep, Glob

### Pre-flight: Check for plugin agent name collisions

Before creating agents, check if any installed plugin provides an agent with the same name. This prevents ambiguous routing where Claude might dispatch to the wrong agent.

```bash
# Check installed plugins for agent files
for plugin_path in $(python3 -c "
import json, sys
try:
    data = json.load(open('$HOME/.claude/plugins/installed_plugins.json'))
    for name, entries in data.get('plugins', {}).items():
        for e in entries:
            print(e.get('installPath', ''))
except: pass
"); do
    if [ -d "$plugin_path/agents" ]; then
        echo "Plugin agents in $plugin_path:"
        ls "$plugin_path/agents/" 2>/dev/null
    fi
done
```

If a collision would occur (e.g., both plugin and project define `code-reviewer`), prefix the project agent: `project-code-reviewer.md`. The plugin version is community-maintained and generic; the project version is tailored to your codebase standards.

**Known collisions** to watch for:
- `superpowers` plugin provides a `code-reviewer` agent (generic plan-validation reviewer)
- `code-simplifier` plugin provides a `code-simplifier` agent
- `code-review` plugin provides a PR review command (not an agent, but uses the same namespace)

### Always create: `.claude/agents/code-reviewer.md` (or `project-code-reviewer.md` if collision detected)

```markdown
---
name: code-reviewer
description: "Review code changes for quality, security, and adherence to project standards. Use when reviewing PRs, auditing recent changes, or checking code before committing."
tools: Read, Grep, Glob
---

You are a senior code reviewer for this project. Your job is to review code changes thoroughly and provide actionable feedback.

## Review Checklist

1. **Read the project standards**: Read `.claude/rules/code-standards.md` first
2. **Understand the change**: Read all modified files and understand the intent
3. **Check against standards**: Verify naming, error handling, function size, comments
4. **Security review**: Look for injection risks, exposed secrets, unsafe operations
5. **Edge cases**: Check boundary handling — empty inputs, nulls, large values
6. **Cleanup**: Verify no dead code, unused imports, or orphaned tests

## Output Format

For each file, report:
- **Severity**: critical / high / medium / low
- **Line**: specific line number
- **Issue**: what's wrong
- **Fix**: how to fix it

End with an overall assessment: APPROVE, REQUEST_CHANGES, or NEEDS_DISCUSSION.
```

### Create if applicable: `.claude/agents/test-writer.md`

```markdown
---
name: test-writer
description: "Write comprehensive tests for source files. Use when the user asks to add tests, improve coverage, or write test cases for new code."
tools: Read, Write, Edit, Bash, Grep, Glob
---

You are a testing specialist for this project. You write thorough, maintainable tests.

## Process

1. Read the target source file and understand its public API
2. Read existing tests in the project to match style and conventions
3. Write tests covering:
   - Happy path for each public function
   - Edge cases: empty input, null/undefined, boundary values
   - Error cases: what should throw/reject
   - Integration points: mock external dependencies
4. Run the tests to verify they pass
5. Report coverage summary
```

### Create if applicable: `.claude/agents/researcher.md`

```markdown
---
name: researcher
description: "Research codebase questions by exploring files, reading docs, and summarizing findings. Use when you need to understand how something works, find patterns across the codebase, or gather context before making changes."
tools: Read, Grep, Glob
---

You are a codebase researcher. Your job is to explore the codebase thoroughly and return a clear, concise summary.

Given a research question:
1. Search for relevant files using Grep and Glob
2. Read the most important files
3. Trace call chains and data flow
4. Return a structured summary:
   - **Answer**: Direct answer to the question
   - **Key files**: List of relevant files with one-line descriptions
   - **Patterns found**: Conventions or patterns observed
   - **Concerns**: Anything that looks problematic
```

```
✅ Step 10 complete — {N} subagent(s) created in .claude/agents/ with proper YAML frontmatter
```

---

## Step 11 — Initialize `.learnings/` (Self-Improvement Log)

**Mode C**: If `.learnings/log.md` already exists, preserve it — it contains accumulated project learnings. Only create if missing.

Create `.learnings/log.md` and `.learnings/agent-usage.log`. The log file is where Claude logs corrections and failures automatically (directed by the Self-Improvement section in CLAUDE.md). The agent-usage file is appended to by the SubagentStop hook.

```bash
mkdir -p .learnings
touch .learnings/agent-usage.log
```

```markdown
# Learnings Log

Corrections, discoveries, and patterns. Claude logs here on every correction AND every command failure.
Promote to CLAUDE.md or rules via `/reflect`. Prune after promoting.

---

{Example entries — delete after first real entry:}

### {date} — Style: brace omission corrected
- **Trigger**: user correction
- **Context**: Writing an if/else block in UserService
- **Correction**: User said "never omit braces on if/else, even single-line"
- **Status**: promoted to .claude/rules/code-standards.md (Style section)

### {date} — Gotcha: soft-delete filter missing
- **Trigger**: user correction
- **Context**: Querying users table without filtering deleted records
- **Correction**: `deleted_at IS NULL` must always be included
- **Status**: pending review

### {date} — Environment: command syntax failed
- **Trigger**: command failure (exit code 1)
- **Context**: Ran a command with wrong syntax for this OS
- **Fix**: Use the correct OS-native equivalent
- **Status**: promoted to CLAUDE.md Environment/Gotchas

### {date} — Agent candidate: dependency update analysis
- **Trigger**: agent-candidate
- **Context**: Spent 3 turns analyzing outdated npm packages, checking changelogs, and evaluating breaking changes — consumed significant context
- **Why agent**: Read-only analysis, produces large output, could run in parallel with other work, recurs monthly
- **Proposed agent**: dependency-auditor — reads package.json, checks for outdated/vulnerable deps, summarizes breaking changes
- **Status**: pending review (waiting for 2+ occurrences before creating)
```

**CRITICAL WIRING CHECK:** Verify that:
1. `.learnings/log.md` exists on disk
2. CLAUDE.md's Self-Improvement section references `.learnings/log.md` by name
If either fails, fix now.

```
✅ Step 11 complete — .learnings/log.md created and wired
```

---

## Step 12 — Note MCP Configuration (`.mcp.json`)

**Mode C**: If `.mcp.json` exists, read it and note configured servers. Only suggest additions — never remove existing MCP servers.

MCP (Model Context Protocol) servers let Claude connect to external tools like databases, JIRA, GitHub, Slack, etc. This step configures integrations if the user indicated they use them in Step 1.

**If no MCP servers needed**: Skip and note why.

**If MCP servers are relevant**: Create `.mcp.json` in the project root (committed to git for team sharing):

```json
{
  "mcpServers": {
    "{server-name}": {
      "command": "{command}",
      "args": ["{args}"],
      "env": {
        "{KEY}": "{value}"
      }
    }
  }
}
```

Common MCP servers to suggest:
- **GitHub**: For issue tracking, PR management
- **Database**: For direct SQL access
- **Slack**: For notifications and context
- **JIRA**: For ticket management

```
✅ Step 12 complete — {.mcp.json created with N servers | skipped: no MCP servers needed}
```

---

## Step 12b — Recommend Official Plugins

Scan the local marketplace cache to recommend plugins matching this project. This step requires that the user has synced the official marketplace at least once (`/plugin` command in Claude Code). If no marketplace data exists, skip and note why.

**Actions:**

1. **Parse marketplace data** (all local, no network):
   ```bash
   # Check if marketplace exists
   MARKETPLACE="$HOME/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json"
   COUNTS="$HOME/.claude/plugins/install-counts-cache.json"
   INSTALLED="$HOME/.claude/plugins/installed_plugins.json"

   if [ ! -f "$MARKETPLACE" ]; then
       echo "No marketplace synced. Skip plugin recommendations."
       echo "User can sync later: /plugin install context7@claude-plugins-official"
       exit 0
   fi
   ```

2. **Detect project signals**:
   - File extensions present in the project (use `find . -name "*.py" -o -name "*.ts" | head -1` etc.)
   - Dependencies from manifest files (package.json, pyproject.toml, requirements.txt, etc.)
   - Config files (vercel.json, firebase.json, .sentryclirc, supabase/ dir)
   - Git remote URL (`git remote get-url origin 2>/dev/null`) — GitHub vs GitLab
   - Existing `.claude/` setup (skills, agents, hooks already configured)

3. **Match using 3-tier system**:

   **Tier 1 — LSP** (auto-recommend if matching files exist):
   Parse `lspServers.*.extensionToLanguage` from marketplace.json. Match against project file extensions.
   | Extension | Plugin |
   |---|---|
   | `.py`, `.pyi` | `pyright-lsp` |
   | `.ts`, `.tsx`, `.js`, `.jsx`, `.mts`, `.cts` | `typescript-lsp` |
   | `.go` | `gopls-lsp` |
   | `.rs` | `rust-analyzer-lsp` |
   | `.cs` | `csharp-lsp` |
   | `.java` | `jdtls-lsp` |
   | `.kt`, `.kts` | `kotlin-lsp` |
   | `.php` | `php-lsp` |
   | `.swift` | `swift-lsp` |
   | `.rb`, `.rake`, `.gemspec` | `ruby-lsp` |
   | `.c`, `.cpp`, `.h`, `.hpp` | `clangd-lsp` |
   | `.lua` | `lua-lsp` |

   **Tier 2 — Framework/Service** (keyword match against deps/configs):
   | Signal | Plugin | Min installs |
   |---|---|---|
   | `stripe` in deps | `stripe` | 16k |
   | `supabase` in deps or `supabase/` dir | `supabase` | 43k |
   | `firebase` or `@firebase/*` in deps | `firebase` | 11k |
   | `@playwright/test` in devDeps | `playwright` | 102k |
   | `laravel` in composer.json or `artisan` file | `laravel-boost` | 12k |
   | `transformers` or `huggingface_hub` in Python deps | `huggingface-skills` | 13k |
   | `@sentry/*` or `sentry-sdk` in deps | `sentry` | 17k |
   | `vercel.json` exists | `vercel` | 24k |
   | GitHub remote URL | `github` | 126k |
   | GitLab remote URL | `gitlab` | 16k |
   | Frontend files (HTML/CSS/JSX/Vue/Svelte) | `frontend-design` | 324k |
   | `@linear/sdk` or Linear workflow | `linear` | 22k |
   | Atlassian/Jira in workflow | `atlassian` | 38k |
   | `@anthropic-ai/sdk` or `anthropic` in deps | `agent-sdk-dev` | 36k |

   **Tier 3 — Universal** (broadly useful, recommend by install count >50k):
   These don't need project-specific signals — they're useful for any codebase:
   - `context7` (168k) — library docs lookup via MCP
   - `code-review` (148k) — multi-agent PR review
   - `code-simplifier` (121k) — code cleanup agent
   - `commit-commands` (78k) — git workflow commands
   - `security-guidance` (77k) — security hooks
   - `claude-md-management` (76k) — CLAUDE.md quality auditing

4. **Filter**: Exclude already-installed plugins. Only recommend plugins with >5,000 installs.

5. **Check for conflicts** before recommending (same checks as /reflect step 6d):
   - Agent name collisions with project agents
   - Hook event+matcher overlaps with project hooks
   - Skill name overlaps with project skills
   - Note: `superpowers` plugin injects ~115 lines via SessionStart hook — flag if user has iterate-fast workflow preference

6. **Present recommendations** grouped by tier:
   ```
   Plugin Recommendations:

   Tier 1 — Language Support:
     ✦ pyright-lsp (48k installs) — Python type checking and code intelligence
       Install: /plugin install pyright-lsp@claude-plugins-official

   Tier 2 — Framework/Service:
     ✦ github (126k installs) — GitHub MCP: issues, PRs, repo management
       Install: /plugin install github@claude-plugins-official
     ✦ frontend-design (324k installs) — Production-grade UI generation
       Install: /plugin install frontend-design@claude-plugins-official
       ⚠ Note: complementary with your existing CSS/HTML workflow, not a replacement

   Tier 3 — Universal:
     ✦ context7 (168k installs) — Library docs lookup
       Install: /plugin install context7@claude-plugins-official
     ✦ code-review (148k installs) — Multi-agent PR review
       Install: /plugin install code-review@claude-plugins-official
       ⚠ Conflict: You have .claude/agents/code-reviewer.md — consider renaming to project-code-reviewer.md

   Already installed: superpowers, ralph-loop, typescript-lsp
     ⚠ typescript-lsp: No .ts files found in project — consider uninstalling
   ```

7. **Ask the user** which to install. Do NOT auto-install. The user may install now or later.

8. **Generate LSP guidance rules**: If any LSP plugins are installed or being recommended, check if `.claude/rules/lsp-guidance.md` exists. If not, create it following the instructions in Step 3d. Unlike non-LSP plugins (which are self-describing via skill/agent descriptions and auto-route correctly), LSP plugins are pure configuration shims — they configure the language server but add **zero behavioral guidance**. Claude will not automatically prefer LSP `findReferences` over Grep for symbol lookups unless a rule explicitly says to. This is the one plugin category that needs a complementary rules file.

9. **If the user wants to install plugins**, handle prerequisites and installation:

   a. **Install LSP prerequisites FIRST** (before `/plugin install`):
      - Detect OS (from Step 1 environment detection)
      - For each LSP plugin the user wants, install the language server binary using the **platform-appropriate** command (see Step 13 LSP prerequisites table — Windows requires different install methods than macOS/Linux)
      - Verify the binary is on PATH and is a real executable (not a `.cmd` wrapper on Windows):
        ```bash
        # Verify it's a real executable, not just a .cmd wrapper
        file "$(which pyright-langserver)" 2>/dev/null || where pyright-langserver
        ```
      - If the binary installs to a non-PATH location, copy it to a directory on PATH

   b. **Handle agent name collisions**: If any recommended plugin has agent name conflicts with project agents (e.g., `code-review` plugin vs `code-reviewer.md`), rename the project agent BEFORE installing the plugin:
      ```bash
      mv .claude/agents/code-reviewer.md .claude/agents/project-code-reviewer.md
      ```
      Update the `name:` field in the YAML frontmatter to match.

   c. **Install plugins**: List the `/plugin install` commands for the user to run (these are interactive CLI commands that cannot be run via Bash tool):
      ```
      /plugin install {name}@claude-plugins-official
      ```

   d. **Reload and test**: After the user runs the install commands:
      - Ask the user to run `/reload-plugins`
      - **Test LSP plugins** by running an LSP operation on a source file:
        ```
        LSP → hover on a function in a core source file
        LSP → documentSymbol on the same file
        ```
      - If LSP fails with `ENOENT`, this is the Windows `.cmd` spawn bug. **Search the web** for the specific error + plugin name before attempting local fixes. The fix is usually: use `pip` instead of `npm`, or patch `marketplace.json` (see Step 13).
      - **Test MCP plugins** by checking if their tools appear after reload (use ToolSearch)
      - Non-LSP/non-MCP plugins (skills, agents, hooks) activate automatically — verify they appear in the skill/agent list after reload

   e. **Verify LSP guidance exists**: After LSP plugin installation, confirm `.claude/rules/lsp-guidance.md` was created in step 8. If not, create it now following Step 3d instructions. This is the one plugin type that needs explicit behavioral rules — without them, Claude defaults to Grep for symbol analysis even when LSP would give precise, type-aware results

```
✅ Step 12b complete — {N} plugins recommended, {N} conflicts flagged, {N} already installed, {N} tested working
```

---

## Step 13 — Verify Plugin Compatibility

The `.claude/` structure you've created is compatible with the Claude Code plugin format. This means skills, agents, and hooks can be exported as a shareable plugin later.

**Verify the structure matches plugin conventions:**
```
.claude/
├── settings.json          # hooks
├── hooks/                 # hook scripts (executable, committed)
│   ├── detect-env.sh
│   ├── guard-git.sh
│   └── track-agent.sh
├── scripts/               # portable helpers (json-val.sh etc.)
│   └── json-val.sh
├── skills/                # skills (directories with SKILL.md)
│   ├── reflect/SKILL.md
│   ├── audit-file/SKILL.md
│   ├── audit-memory/SKILL.md
│   └── write-prompt/SKILL.md
├── agents/                # subagents (markdown with YAML frontmatter)
│   ├── code-reviewer.md (or project-code-reviewer.md if plugin collision)
│   └── ...
└── rules/                 # scoped rules
    ├── general.md
    ├── code-standards.md
    └── shell-standards.md
```

If the user wants to share this setup as a plugin later, they can add a `.claude-plugin/plugin.json` manifest. **Do NOT create the plugin manifest now** — just confirm the structure is compatible.

### Plugin update model

Plugins from the official marketplace are **not auto-updated**. Updates work as follows:
- Plugins are pinned to a git commit SHA at install time
- The marketplace repo (`~/.claude/plugins/marketplaces/claude-plugins-official/`) syncs when you run `/plugin` commands
- To update an installed plugin: `/plugin install {name}@claude-plugins-official` (re-install fetches latest)
- There is no `plugin update` command — re-install is the update mechanism
- The `/reflect` skill's plugin audit (step 6) can detect when an installed plugin's SHA is older than the marketplace's latest and suggest re-installation

### LSP plugin prerequisites

LSP plugins require their language server binary installed separately. The plugin provides the integration; the server must exist on PATH.

**CRITICAL — Windows `.cmd` spawn bug**: Claude Code uses Node.js `child_process.spawn()` without `shell: true`. On Windows, `spawn()` can only find real `.exe` files — it CANNOT resolve `.cmd` or `.bat` wrappers that npm creates for global packages. This means **npm-installed language servers will fail with `ENOENT`** on Windows. Always use `pip` (creates `.exe`) instead of `npm` (creates `.cmd`) for Python LSP tools on Windows. For Node.js-based servers (typescript-lsp), you may need to copy the `.exe` from pip's Scripts dir to a PATH location, or use the workaround below.

| Plugin | Required binary | Install command (macOS/Linux) | Install command (Windows) | Notes |
|---|---|---|---|---|
| `pyright-lsp` | `pyright-langserver` | `pip install pyright` or `npm i -g pyright` | `pip install pyright` (MUST use pip, not npm) | npm creates .cmd wrapper that spawn() can't find |
| `typescript-lsp` | `typescript-language-server` | `npm i -g typescript-language-server typescript` | `npm i -g typescript-language-server typescript` then see Windows workaround | Same .cmd issue — may need manual fix |
| `gopls-lsp` | `gopls` | `go install golang.org/x/tools/gopls@latest` | Same | Creates real .exe on all platforms |
| `csharp-lsp` | `csharp-ls` | `dotnet tool install --global csharp-ls` | Same | Creates real .exe on all platforms |
| `rust-analyzer-lsp` | `rust-analyzer` | `rustup component add rust-analyzer` | Same | Creates real .exe on all platforms |
| `clangd-lsp` | `clangd` | System package manager | `choco install llvm` or manual | Creates real .exe |

**Windows workaround for npm-only servers** (e.g., typescript-lsp):
If `pip` doesn't provide the binary, you can patch `marketplace.json` to use `node` directly:
```json
"command": "node",
"args": ["C:/Users/{user}/AppData/Roaming/npm/node_modules/{package}/dist/index.js", "--stdio"]
```
This bypasses the `.cmd` wrapper. The patch survives until the next `/plugin install` command triggers a marketplace sync.

When recommending LSP plugins in Step 12b, check if the binary exists on PATH:
```bash
command -v pyright-langserver >/dev/null 2>&1 && echo "pyright: ready" || echo "pyright: needs install"
```
If the binary is missing, include the platform-appropriate install command in the recommendation.

```
✅ Step 13 complete — structure is plugin-compatible, plugin update model documented
```

---

## Step 14 — Wiring Verification and Report

This is the final step. Run every check below. **ALL must pass.** If any fails, fix it.

### File Existence Checks
- [ ] `CLAUDE.md` exists at project root
- [ ] `CLAUDE.local.md` exists at project root
- [ ] `.claude/rules/general.md` exists
- [ ] `.claude/rules/code-standards.md` exists
- [ ] `.claude/settings.json` exists
- [ ] `.claude/skills/reflect/SKILL.md` exists
- [ ] `.claude/skills/audit-file/SKILL.md` exists
- [ ] `.claude/skills/audit-memory/SKILL.md` exists
- [ ] `.claude/skills/write-prompt/SKILL.md` exists
- [ ] `.claude/agents/code-reviewer.md` exists
- [ ] `.claude/scripts/json-val.sh` exists and is executable
- [ ] `.claude/hooks/detect-env.sh` exists and is executable
- [ ] `.claude/hooks/guard-git.sh` exists and is executable
- [ ] `.claude/hooks/track-agent.sh` exists and is executable
- [ ] `.learnings/log.md` exists
- [ ] `.learnings/agent-usage.log` exists (can be empty)

### YAML Frontmatter Checks
- [ ] Every SKILL.md has `name:` and `description:` in YAML frontmatter
- [ ] Every agent .md has `name:` and `description:` in YAML frontmatter
- [ ] Skill names are lowercase with hyphens, max 64 chars
- [ ] Skill descriptions include trigger phrases (are "pushy" about when to activate)

### Wiring Checks (the feedback loop)
- [ ] CLAUDE.md Self-Improvement section contains the string `.learnings/log.md`
- [ ] CLAUDE.md Self-Improvement section contains "BEFORE" (log before continuing)
- [ ] CLAUDE.md Self-Improvement section contains "Trigger 2" (command/tool failures)
- [ ] CLAUDE.md Self-Improvement section contains "Trigger 3" (agent-candidate tagging)
- [ ] CLAUDE.md Self-Improvement section contains "Do NOT silently retry"
- [ ] CLAUDE.md Self-Improvement section contains "search the web" (Trigger 2, after failed attempts)
- [ ] CLAUDE.md has an `## Environment` section referencing auto-detection via SessionStart hook (with fallback OS, shell, path style)
- [ ] `.claude/skills/reflect/SKILL.md` step 1 reads `.learnings/log.md`
- [ ] `.claude/skills/reflect/SKILL.md` step 2 reads `.learnings/agent-usage.log`
- [ ] `.claude/skills/reflect/SKILL.md` step 5 covers agent evolution (create, retire, improve)
- [ ] `.claude/skills/reflect/SKILL.md` step 6 covers plugin audit (marketplace scan, conflict detection, install/uninstall recommendations)
- [ ] `.claude/skills/reflect/SKILL.md` step 12 mentions cleaning up promoted entries
- [ ] `.claude/rules/code-standards.md` has a `## Style` section
- [ ] `.claude/rules/code-standards.md` Style section mentions `.learnings/log.md`

### Context Management Checks
- [ ] CLAUDE.md has a `## Compact Instructions` section listing what to preserve during compaction
- [ ] CLAUDE.md Workflow section mentions proactive compaction at ~70%
- [ ] CLAUDE.md is under 120 lines (count with `wc -l CLAUDE.md`)
- [ ] CLAUDE.md uses `@path` imports for detailed docs instead of inlining content
- [ ] No code snippets are pasted inline in CLAUDE.md (use `@path` or skill references instead)
- [ ] No code style rules in CLAUDE.md that the linter/formatter already enforces

### Hook Checks
- [ ] Hooks in `.claude/settings.json` delegate to external scripts (no inline one-liners >80 chars)
- [ ] Hook scripts use `.claude/scripts/json-val.sh` to parse tool input from stdin (NOT `jq` — not portable)
- [ ] PreToolUse guard scripts exit with code 2 to block (not code 1)
- [ ] SubagentStop hook exists (`.claude/hooks/track-agent.sh`) and logs to `.learnings/agent-usage.log`
- [ ] SubagentStop hook uses `agent_type` and `agent_id` (NOT `agent_name` — that field does not exist)
- [ ] SessionStart hook exists and runs `.claude/hooks/detect-env.sh`
- [ ] All hook scripts are executable (`chmod +x`)

### Plugin Checks
- [ ] No agent name collisions between `.claude/agents/` and installed plugin agents
- [ ] Plugin hooks don't block or shadow project hooks on same event+matcher
- [ ] If `superpowers` is installed, CLAUDE.md or CLAUDE.local.md documents workflow priority (iterate-fast vs. ceremony)
- [ ] Step 12b plugin recommendations were presented to user
- [ ] `/reflect` skill step 6 references marketplace.json and install-counts-cache.json paths
- [ ] If LSP plugins were installed: LSP hover/documentSymbol returns results (not ENOENT)
- [ ] If LSP plugins on Windows: binary is a real `.exe` (not `.cmd` wrapper) — verified with `file $(which binary)` or `where binary`
- [ ] If MCP plugins were installed: MCP tools appear in ToolSearch after `/reload-plugins`
- [ ] All installed plugin prerequisites are on PATH and functional

### LSP Guidance Checks
- [ ] If any LSP plugins are installed: `.claude/rules/lsp-guidance.md` exists
- [ ] LSP guidance only includes language sections for languages actually present in the project
- [ ] LSP guidance includes "When to Use LSP vs Grep" section with operation mapping
- [ ] LSP guidance includes "Workspace Requirements" listing required config files per language (servers fail silently without these)
- [ ] LSP guidance includes language-specific limitations (not generic copy-paste)
- [ ] For multi-language projects: LSP guidance includes "Multi-Language Projects" section noting cross-language boundary limitations

### Command Checks
- [ ] Build command in CLAUDE.md runs without error (or marked N/A)
- [ ] Lint command in CLAUDE.md runs without error (or marked N/A)

### Gitignore Check
- [ ] `.gitignore` includes `CLAUDE.local.md`
- [ ] `.gitignore` includes `.claude/settings.local.json`

### Report

After all checks pass, print:

```
========================================
BOOTSTRAP COMPLETE
========================================
Mode: {A: Existing Project | B: From Scratch | C: Incremental}
Files created: {list all created files}
Files updated: {list all updated files — Mode C only}
Files preserved: {list existing files kept unchanged — Mode C only}
Feedback loop: CLAUDE.md → .learnings/log.md → /reflect → CLAUDE.md ✓
Hooks active: {list hooks with types — command/prompt/http/agent}
Env detection: SessionStart → .claude/hooks/detect-env.sh ✓
Skills available: /reflect, /audit-file, /audit-memory, /write-prompt
Subagents available: {list agents}
MCP servers: {list or "none configured"}
Plugin-compatible: yes
Plugins installed: {list or "none"}
Plugins tested: {list with pass/fail status, e.g., "pyright-lsp ✓ (LSP hover working)"}
Plugins recommended: {N pending — run Step 12b recommendations}
Plugin conflicts: {list or "none"}
Style preferences captured: {yes/no — from Step 1}
Scoped CLAUDE.md files: {list or "none needed"}
========================================
```

Then ask:
1. "Setup is complete. Want me to run `/audit-file` on any existing source file to test the audit skill?"
2. "Want me to run the code-reviewer agent on recent changes?"
3. "Any additional skills or agents you'd like me to create for your specific workflow?"
4. "Want me to install any of the recommended plugins now?"

```
✅ Step 14 complete — all wiring checks passed, bootstrap complete
```

---

## Appendix A — Creating Additional Skills Later

When you identify a repeated workflow, capture it as a skill:

```
.claude/skills/{skill-name}/
├── SKILL.md              # Required: YAML frontmatter + instructions (<500 lines)
├── references/            # Optional: docs loaded on demand
│   └── detailed-guide.md
├── scripts/               # Optional: executable code (runs without loading into context)
│   └── validate.py
└── assets/                # Optional: templates, fonts, etc.
```

**Key skill authoring rules:**
- `name` in frontmatter: lowercase, hyphens, max 64 chars. Cannot contain "anthropic" or "claude"
- `description` in frontmatter: be "pushy" — include both what it does AND specific trigger phrases
- Keep SKILL.md body under 500 lines. If approaching this limit, split into reference files
- Reference files clearly from SKILL.md with guidance on when to read them
- For scripts: they execute via bash without loading into context — only output consumes tokens
- Add `disable-model-invocation: true` for skills with side effects (deploy, commit, send)
- Add `context: fork` to run the skill in its own subagent context window

## Appendix B — Creating Additional Subagents Later

Good candidates for custom subagents are tasks that:
- Produce large output that would consume main context (test runs, log analysis)
- Are isolated review/analysis work (security audit, dependency check)
- Are repetitive multi-file operations (migration generation, bulk refactoring)
- Can run in parallel with other subagents

```markdown
---
name: {agent-name}
description: "{When to invoke and what it specializes in}"
tools: {comma-separated list, or omit to inherit all}
model: {sonnet | opus | haiku — optional, defaults to current}
---

{System prompt: role description, expertise, checklists, constraints}
```

Place in `.claude/agents/` (project-level) or `~/.claude/agents/` (user-level, all projects).

## Appendix C — Workflow Patterns for Complex Tasks

When orchestrating multi-step work, choose the right pattern:

**Sequential** (default): Tasks have dependencies. Each step passes output to the next.
- Good for: data pipelines, draft-review-polish cycles, multi-stage builds
- Tradeoff: adds latency (each step waits)

**Parallel**: Tasks are independent. Run subagents simultaneously, aggregate results.
- Good for: code review (security + style + tests in parallel), multi-file analysis
- Tradeoff: costs more tokens, needs an aggregation strategy
- Design aggregation before implementing: majority vote? specialized agent wins?

**Evaluator-Optimizer**: Output needs iterative refinement. Generator + evaluator loop.
- Good for: documentation, customer communications, code against strict standards
- Tradeoff: multiplies token usage
- Always set max iterations and quality thresholds to avoid expensive loops

Start with the simplest pattern. A single agent call is often enough. Only add complexity when you can measure the improvement.

## Appendix D — Context Engineering Quick Reference

Context is the #1 factor in Claude Code quality. Here's what the research shows:

**The instruction budget**: Claude reliably follows ~150-200 instructions. The system prompt uses ~50. Skills metadata, rules, and plugins consume more. Your CLAUDE.md gets whatever's left. Fewer, better instructions > many mediocre ones.

**The context window** (200K tokens typical):
- System prompt + tools: ~17K tokens (8.5%)
- CLAUDE.md + memory: ~4-8K tokens (2-4%)
- Conversation history: grows as you work
- Auto-compact buffer: ~33K tokens reserved (16.5%)
- Usable before compaction: ~167K tokens
- Run `/context` to see actual breakdown at any time

**Compaction behavior**:
- Auto-compact fires at ~75-85% usage (varies by model — Opus earlier, Sonnet later)
- Compaction preserves structured content (lists, labels) at ~92% fidelity
- Narrative paragraphs survive at only ~71% fidelity
- Your `## Compact Instructions` section tells Claude what to prioritize preserving
- `/compact focus on {topic}` lets you direct what survives

**Context hygiene rules**:
- Compact proactively at ~70% — don't wait for auto-compact
- Delegate context-heavy work to subagents (they get their own window)
- Use `@path` imports instead of pasting content into CLAUDE.md
- Move domain knowledge into skills (loaded on demand, not every session)
- Long sessions degrade quality — prefer focused 30-45 minute sessions per task
- If you've corrected Claude 2+ times on the same issue, `/clear` and restart fresh

**The `@import` syntax**:
```markdown
# In CLAUDE.md
See @docs/api.md for endpoint reference
See @README.md for project overview
Personal overrides: @~/.claude/my-project-instructions.md
```
`@path` loads the referenced file into context on demand. It keeps CLAUDE.md lean (~100 tokens per pointer) while giving Claude access to arbitrarily detailed docs when needed. Use it for anything longer than 2-3 lines that doesn't need to be in every single session.

## Appendix E — Official Plugin Ecosystem

### Plugin Architecture

Plugins are installed via `/plugin install {name}@claude-plugins-official`. They are **user-scoped** (`~/.claude/plugins/`) and available across all projects. A plugin can provide any combination of: skills, agents, hooks, commands, and MCP servers.

### Plugin Data Locations

| File | Purpose | Survives uninstall? |
|---|---|---|
| `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json` | Master index of all available plugins | Yes (marketplace repo) |
| `~/.claude/plugins/install-counts-cache.json` | Popularity data per plugin | Yes (API cache) |
| `~/.claude/plugins/installed_plugins.json` | Currently installed plugins | Updated on install/uninstall |
| `~/.claude/plugins/cache/{marketplace}/{name}/{version}/` | Full plugin content | Persists after uninstall (cache) |
| `~/.claude/plugins/blocklist.json` | Server-blocked plugins | Yes (API cache) |

### Update Model

Plugins are **not auto-updated**:
- Pinned to a git commit SHA at install time
- `/plugin install {name}@claude-plugins-official` re-installs to latest version
- No dedicated update command exists
- The `/reflect` skill's plugin audit can detect stale versions

### LSP Plugin Prerequisites

LSP plugins only provide the Claude Code integration — the language server binary must be installed separately and available on PATH. The plugin will not work without its prerequisite.

**CRITICAL — Windows spawn bug**: Claude Code uses Node.js `spawn()` without `shell: true`. On Windows, `spawn()` cannot resolve `.cmd`/`.bat` wrappers — only real `.exe` files. npm global installs create `.cmd` wrappers, NOT `.exe` files. Always prefer `pip` over `npm` for installing language servers on Windows, as pip creates proper `.exe` binaries. See Step 13 for the full explanation and workarounds.

| Plugin | Required binary | Install (macOS/Linux) | Install (Windows) | Notes |
|---|---|---|---|---|
| `pyright-lsp` | `pyright-langserver` | `pip install pyright` or `npm i -g pyright` | `pip install pyright` (MUST use pip) | npm .cmd fails on Windows |
| `typescript-lsp` | `typescript-language-server` | `npm i -g typescript-language-server typescript` | npm + marketplace.json patch (see Step 13) | npm .cmd fails on Windows |
| `gopls-lsp` | `gopls` | `go install golang.org/x/tools/gopls@latest` | Same | go builds real .exe |
| `csharp-lsp` | `csharp-ls` | `dotnet tool install --global csharp-ls` | Same | dotnet builds real .exe |
| `rust-analyzer-lsp` | `rust-analyzer` | `rustup component add rust-analyzer` | Same | rustup builds real .exe |
| `clangd-lsp` | `clangd` | System package manager (apt/brew) | `choco install llvm` | Real .exe |
| `kotlin-lsp` | `kotlin-lsp` | Manual build from source | Same | |
| `php-lsp` | `intelephense` | `npm i -g intelephense` | npm + marketplace.json patch | npm .cmd fails on Windows |
| `swift-lsp` | `sourcekit-lsp` | Comes with Xcode/Swift toolchain | N/A (macOS only) | |
| `ruby-lsp` | `ruby-lsp` | `gem install ruby-lsp` | Same | gem creates real .exe on Windows |
| `lua-lsp` | `lua-language-server` | `brew install lua-language-server` | `choco install lua-language-server` | |
| `jdtls-lsp` | `jdtls` | Download from Eclipse | Same | Java .exe launcher |

When recommending LSP plugins, always check if the binary exists, detect the OS, and include the **platform-appropriate** install command if missing.

### LSP Plugin Architecture — Why They Need Complementary Rules

Unlike other plugin types (skills, agents, MCP servers) which are **self-describing** — Claude auto-discovers them via skill/agent `description` fields and routes to them automatically — LSP plugins are **pure configuration shims**. An LSP plugin typically contains just a README and a LICENSE file. It tells Claude Code "for `.cs` files, use the `csharp-ls` language server" — nothing more.

The actual `LSP` tool is **built into Claude Code** as a deferred tool (loaded on demand). It wraps any configured language server and exposes these operations:

| Operation | Purpose | Best for |
|---|---|---|
| `goToDefinition` | Jump to where a symbol is defined | Understanding unfamiliar code |
| `findReferences` | Find all usages of a symbol (type-aware) | Impact analysis, refactoring |
| `goToImplementation` | Find concrete implementations of interfaces/abstract methods | Interface-heavy languages (C#, Java) |
| `hover` | Get type info and documentation | Dynamic languages (Python), complex generics (Rust) |
| `documentSymbol` | List all symbols in a file | File structure overview |
| `workspaceSymbol` | Search for symbols by name across the project | Finding symbols without knowing their file |
| `prepareCallHierarchy` | Establish call graph entry point | Pre-step for incoming/outgoing calls |
| `incomingCalls` | Which functions call this function | Tracing callers, blast radius |
| `outgoingCalls` | Which functions this function calls | Understanding dependencies |

**The gap**: Nothing in the plugin or Claude Code tells Claude **when to prefer LSP over Grep**. Without explicit rules, Claude defaults to Grep for "find all usages of X" — which returns string matches including migrations, designer files, comments, and other noise. LSP `findReferences` returns only real, type-aware code references.

This is why Step 3d creates `.claude/rules/lsp-guidance.md` — it's the one plugin category that needs a complementary rules file to be effective.

### LSP Operations — Language Server Capabilities Matrix

Not all language servers support all operations equally. This matrix shows what works well vs. what has limitations:

| Operation | C# | Python | TS/JS | Go | Rust | Java | C/C++ |
|---|---|---|---|---|---|---|---|
| `goToDefinition` | Excellent | Good | Excellent | Excellent | Excellent | Excellent | Good* |
| `findReferences` | Excellent | Good | Excellent | Excellent | Excellent | Excellent | Good* |
| `goToImplementation` | Excellent | Limited | Good | Limited** | Good | Excellent | Weak |
| `hover` | Good | Excellent | Good | Good | Excellent | Good | Good |
| `documentSymbol` | Good | Good | Good | Good | Good | Good | Good |
| `workspaceSymbol` | Good | Good | Good | Fast | Good | Good | Good* |
| `incomingCalls` | Good | Incomplete | Good | Partial | Unstable | Good | Good* |
| `outgoingCalls` | Good | Incomplete | Good | Partial | Unstable | Good | Good* |

\* Requires `compile_commands.json` — without it, many operations fail **silently**
\** Go has implicit interfaces — satisfying types aren't explicitly linked, making implementation-finding less useful

**Performance characteristics**:
- **Fastest**: Go (gopls) — minimal config, fast startup, low memory
- **Slowest startup**: Java (jdtls) — ~8s JVM warmup
- **Most memory**: Rust (rust-analyzer) — 500MB+ on large projects; Java (jdtls) — 1GB+ on large projects
- **Most reliable overall**: Go, TypeScript, C#

### Recommended Plugin Combinations

**Minimal (any project)**: `context7` (library docs)

**Python project**: `context7` + `pyright-lsp` + `code-review`

**TypeScript/React project**: `context7` + `typescript-lsp` + `frontend-design` + `code-review`

**Full-featured**: `context7` + language LSP + `code-review` + `code-simplifier` + `commit-commands`

**Heavy workflow** (large multi-step features): add `superpowers` — but note it injects ~115 lines via SessionStart hook and has aggressive "always use skills" instructions. If your workflow is iterate-fast, document in CLAUDE.local.md that superpowers skills are opt-in.

### Plugins vs. Bootstrap Components — Complementary, Not Replacements

| Bootstrap component | Complementary plugin | Why both coexist |
|---|---|---|
| `/write-prompt` skill | `superpowers/writing-skills` | Bootstrap covers structure + project-specific prompts (cron MDs, agent tasks). Plugin adds TDD methodology for reusable skills. |
| `/write-prompt` skill | `skill-creator` | Bootstrap is quick reference. Plugin is full create-test-iterate lifecycle. |
| `code-reviewer` agent | `code-review` plugin | Bootstrap agent reviews local files pre-commit. Plugin reviews GitHub PRs with multi-agent pipeline. |
| `/reflect` skill | `claude-md-management` | Bootstrap owns the full learning loop + agent/plugin evolution. Plugin adds deep CLAUDE.md quality scoring. |
| Step 4 hooks | `hookify` | Bootstrap creates structural hooks (SessionStart, SubagentStop, auto-format). Hookify adds ad-hoc behavioral guards with better UX. |
| Entire bootstrap | `claude-code-setup` | Bootstrap builds everything. Plugin is a read-only advisor — useful as post-bootstrap "second opinion". |

### Known Plugin Issues

- **All LSP plugins on Windows**: Node.js `spawn()` without `shell: true` cannot resolve `.cmd`/`.bat` wrappers that npm creates. Use `pip` instead of `npm` for Python-based servers (creates real `.exe`). For npm-only servers, patch `marketplace.json` to use `node` directly with the full path to the server's entry point JS file. See Step 13 for details.
- `pyright-lsp` **on Windows**: `npm i -g pyright` creates `pyright-langserver.cmd` which fails with `ENOENT: uv_spawn 'pyright-langserver'`. Fix: `pip install pyright` creates `pyright-langserver.exe`. If pip installs to a non-PATH location (e.g., Python user scripts), copy the `.exe` to a directory already on PATH (e.g., `AppData/Roaming/npm/`).
- `typescript-lsp`: May install with incomplete cache (only README + LICENSE). Reinstall if LSP features don't work. Same Windows `.cmd` issue applies.
- `superpowers`: SessionStart hook injects entire "using-superpowers" skill (~115 lines). Competes with lean CLAUDE.md philosophy. Mitigate by documenting workflow priority in CLAUDE.local.md.
- Agent name `code-reviewer` is used by `superpowers`, potentially by `code-review` plugin, AND by the bootstrap template. Always use prefixed names for project agents when plugins are installed.