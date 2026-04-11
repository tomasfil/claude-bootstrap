# Module 02 — Project Configuration

> Generate CLAUDE.md, rules, CLAUDE.local.md, technique refs, .gitignore via agent dispatch.
> Main thread = pure orchestrator. All content generation by code-writer-markdown agent.

---

## Idempotency

Per file: read existing → extract project-specific content → merge + regenerate.
Goal: carry forward project knowledge into improved template. Generic boilerplate replaced;
project-specific rules, gotchas, conventions survive.

Foundation agents: already created in Module 01. This module dispatches them via inline prompts
(BOOTSTRAP_DISPATCH_PROMPT) since agent .md files aren't loaded mid-session (claude-code#6497).

## Actions

### 1. Prepare Discovery Context

Read Module 01 output (conversation context). Compile dispatch inputs:
- Languages + versions
- Frameworks + versions
- Commands (build, test-single, test-suite, lint, format)
- Architecture layers + project structure
- Pipeline traces summary
- Git strategy (track | companion | ephemeral)
- Auto-detected preferences (auto-format, sql-guard, read-only-dirs, MCP signals)
- Existing CLAUDE.md content (if any — extract project-specific sections)
- Existing `.claude/rules/` files (if any — extract project-specific rules)
- Existing CLAUDE.local.md (if any — PRESERVE as-is, personal preferences sacred)

### 2. Dispatch: CLAUDE.md

Dispatch code-writer-markdown via inline prompt (BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Generate CLAUDE.md",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT — code-writer-markdown}

Task: Write CLAUDE.md from discovery data below.
{discovery_context}

Requirements:
- <120 lines total — every line earns its place
- MANDATORY `@import` lines (always, regardless of language):
  - `@import .claude/rules/general.md`
  - `@import .claude/rules/skill-routing.md`
  - `@import .claude/rules/code-standards-{lang}.md` for each detected language
  - `@import .claude/rules/mcp-routing.md` (ONLY if `.mcp.json` exists at project root)
  These are required for /audit-agents A5 check — adding custom imports is fine, removing these is not.
- Compressed telegraphic notation throughout (Claude-facing, not human-facing)
- Language-agnostic — use {placeholders} filled from discovery, ZERO hardcoded examples

Sections (in order):
1. Architecture — lang, framework, db, deps, @import
2. Key Files — 5-10 critical paths (entry points, configs, core modules)
3. Commands — build, test-single, test-suite, lint, format, dev-server
4. Workflow — test strategy, compaction@~70%, commit convention, spec-first, TaskCreate
5. Conventions — 3-10 project-specific non-obvious rules (telegraphic)
6. Gotchas — known traps from discovery + .learnings/
7. Compact Instructions — PRESERVE list, CONSOLIDATE_DUE/REFLECT_DUE triggers
8. Skill Automation — auto-run list, active dev skills
9. Effort Scaling — 'Agents: always effort=high. Skills: effort matches task weight.'
10. Communication — 'Direct — lead w/ answer, no filler. Concise code.'
11. Behavior — READ_BEFORE_WRITE, verify-before-done, no-false-claims, collaborator,
    never-background-agents, no-builtin-explore, comments-WHY-only, output-lead-w/-answer,
    Claude-facing=compressed/human-facing=prose,
    'Main thread = pure orchestrator. Dispatches agents, handles questions. Never generates file content.',
    Anti-patterns (ban these escape hatches):
    - No ownership-dodging: don't deflect w/ "pre-existing issue" | "not caused by my changes" | "known limitation" — own it, fix it
    - No premature stopping: don't quit at "good stopping point" | "natural checkpoint" — push through to complete solution
    - No permission-seeking: don't ask "should I continue?" | "want me to keep going?" — if solvable, solve it
    - No built-in Explore fallback: code investigation → proj-quick-check (simple) | proj-researcher (complex); NEVER built-in Explore/general-purpose/plugin agents — they bypass project context + evidence tracking
12. Self-Improvement — .learnings/log.md gate, categories, hook auto-logs, 2-fail→web

Write to CLAUDE.md. Return ONLY: path + 1-line summary <100 chars."
)
```

Verify: `wc -l CLAUDE.md` < 120.

### 3. Dispatch: Rules Files

Dispatch code-writer-markdown via inline prompt (BOOTSTRAP_DISPATCH_PROMPT from Module 01):

```
Agent(
  description: "Generate rules files",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT — code-writer-markdown}

Task: Create rule files from discovery data below.
{discovery_context}

All files: compressed telegraphic notation, <40 lines each, no YAML frontmatter.
Language-agnostic — ZERO hardcoded language examples. Discovery data fills everything.

Create ALWAYS:
1. .claude/rules/general.md
   - Git: {branching strategy from git_strategy}, buildable commits, conventional commits, no force-push shared
   - Code quality: no dead code, no TODO w/o issue, English, follow existing patterns, extend not duplicate
   - Process: READ_BEFORE_WRITE, test after change, 2-fail→web, log corrections,
     dispatch agents when specified, no built-in Explore/general-purpose/plugin agents (use proj-quick-check | proj-researcher), never background agents

2. .claude/rules/code-standards-{lang}.md (one per detected language)
   - Naming conventions (from codebase analysis)
   - Structure (max fn length, guard clauses, file organization)
   - Error handling (project pattern)
   - Constants (no magic values)
   - Comments (WHY only, public API docs)
   - Style (start mostly empty — populated via /reflect from real corrections)
   - Verification (read-before-write, verify APIs exist, never fabricate imports, run build, LSP hover)

3. .claude/rules/token-efficiency.md
   - Scope: CLAUDE.md, .claude/rules/, skills/, agents/, memory files
   - NOT: conversation output, commits, PRs, user-facing docs
   - Compression rules: strip articles/filler, telegraphic, symbols (→|+~w/), key:value+bullets
   - Why: 30-50% savings, compounds across sessions + subagents

4. .claude/rules/skill-routing.md (~200 tokens, behavioral guidance ONLY)
   Content:
   # Skill Routing
   ## Rule
   Before starting implementation, check if skill applies via Skill tool.
   Skills orchestrate agents — bypassing = losing quality layer.
   ## When to check
   - Code changes → /code-write
   - Bug investigation → /debug
   - TDD → /tdd
   - Committing → /commit (after /verify + /review)
   - Planning → /write-plan, /brainstorm
   - Reviews → /review, /audit-file
   ## When NOT to check
   - Simple questions, file reads, explanations
   - Follow-up in active skill workflow
   - Design discussion (unless user asks to formalize)
   ## Forbidden
   NEVER use built-in `Explore` / `general-purpose` / plugin agents for code exploration.
   - Simple fact/lookup → proj-quick-check
   - Deep multi-source investigation → proj-researcher
   - Bug investigation → /debug (if disable-model-invocation blocks invocation → ask user to run /debug manually; do NOT fall back to Explore)
   - Plain code reading → Read/Grep/Glob directly
   Built-in agents bypass project evidence tracking + conventions = quality regression.
   ## Critical
   NEVER refuse or block because no skill matches.
   Uncertain → respond normally. False blocks worse than missed routing.

5. .claude/rules/mcp-routing.md (embed verbatim — DO NOT paraphrase)
   Content:
   # MCP Routing

   ## Rule
   MCP tools route through sub-agents — NEVER skill `allowed-tools:`.

   ## Skill layer (NEVER add mcp__* here)
   `allowed-tools:` controls skill's own invocation permissions — does NOT cascade to
   dispatched agents. Adding `mcp__*` to a skill's `allowed-tools:` is always wrong.

   ## Agent layer (write agents only)
   Write agents that need MCP access: keep `tools:` list + add `mcp__<server>__*` per
   `.mcp.json` `mcpServers` keys. One glob entry per server key.
   Read-only agents: OMIT `tools:` entirely → inherit parent tools incl. MCP.

   ## When .mcp.json changes
   Run `/migrate-bootstrap` (triggers migration-001 re-check) or `/audit-agents`
   to validate MCP propagation across all agents.

   ## Routing table
   If MCPs present, the routing table below is the single source for tool→action mappings.
   Populate per project during bootstrap or when new MCP servers are added.

   | MCP Server | Glob | Use for |
   |------------|------|---------|
   | {server}   | mcp__<server>__* | {description — fill from .mcp.json} |

6. .claude/rules/agent-scope-lock.md (embed verbatim — DO NOT paraphrase)
   Content:
   # Agent Scope Lock

   ## Rule
   Executing agent touches ONLY files listed in its batch/task file `#### Files` sections. Nothing outside the listed scope — even trivial, even adjacent, even "helpful".

   ## Scope (applies to)
   All `proj-*` executing/writer agents dispatched via `/execute-plan`, `/tdd`, `/code-write`, or direct skill-invocation. NOT `proj-plan-writer` (has its own separate scope lock in agent spec).

   ## Forbidden
   - Files not listed in any Task `#### Files` → off-limits regardless of edit size
   - Steps labeled `main-thread` in master plan Dispatch Plan → main thread only
   - Silent absorption of adjacent work: 1-line JSON append, 1-char typo fix, trivial `.learnings/` update
   - Adjacent refactoring, dead-code cleanup, stale-comment fix unless explicitly listed
   - Being "helpful" outside task list — correctness does not justify scope expansion

   ## Required
   - Need something off-scope → STOP, return message to main thread: `SCOPE EXPANSION NEEDED: {file|step} — reason: {short}`
   - Batch verification commands cover only listed files; silent absorption creates coverage gap
   - If a plan's Dispatch Plan lists `main-thread` steps, those belong to the main thread ONLY

   ## Example — CORRECT
   Batch: `Task 1.1: edit A.md; Task 1.2: create B.md`. Master plan Dispatch Plan: `main-thread step: append one line to index.json`.
   → Agent edits A.md, creates B.md, returns. Agent does NOT touch index.json.

   ## Example — FORBIDDEN
   Same batch. Agent thinks "index.json is 1 line, I'll just do it for convenience".
   → WRONG. Scope lock violated. Return without touching index.json. Main thread handles it.

   ## Rationale
   - Silent absorption breaks batch-verification coverage (verification command lists only in-scope files)
   - Dispatch Plan is the contract between plan-writer and execute-plan; absorption voids the contract
   - Main-thread steps exist for deliberate reasons (trivial mechanical ops outside specialist domain, operations needing orchestrator context)
   - Scope creep destroys plan→execution traceability, makes blast radius unpredictable
   - Observed 2026-04-11: `proj-code-writer-markdown` absorbed main-thread index.json append during migration 012 batch. Correct outcome, wrong discipline. This rule exists to prevent recurrence.

   ## Enforcement
   - Force-read: this rule is in the STEP 0 force-read list of every `proj-*` executing agent (via modules/05 + modules/07 templates; retrofit via migration 011 + 012)
   - No skill-level mechanical check exists — scope lock is an agent-side discipline rule. Review-time catch: `/review` flags any file change outside the planned scope.

Create CONDITIONALLY:
7. .claude/rules/shell-standards.md — only if .sh files exist
   - Shebang, set -euo pipefail, quote vars, [[ ]], command -v, local, printf
   - Hook scripts: JSON on stdin via cat, exit codes, settings format

8. .claude/rules/data-access.md — only if ORM detected
   - ORM patterns (never raw context, AsNoTracking, projections, parameterized queries)
   - Migration conventions
   - Repository patterns (from codebase analysis)

9. .claude/rules/lsp-guidance.md — only if LSP detected
   - When LSP vs Grep (semantics vs text)
   - Per-language: workspace requirements, effective operations, known limitations, tips

mkdir -p .claude/rules before writing.
Write all files. Return ONLY: paths + 1-line summary <100 chars."
)
```

Verify: `ls .claude/rules/` → general.md, skill-routing.md, mcp-routing.md, token-efficiency.md present minimum.

### 4. Dispatch: CLAUDE.local.md

IF CLAUDE.local.md exists → SKIP (personal preferences are sacred).

IF missing → dispatch code-writer-markdown via inline prompt:

```
Agent(
  description: "Generate CLAUDE.local.md",
  prompt: "{BOOTSTRAP_DISPATCH_PROMPT — code-writer-markdown}

Task: Write CLAUDE.local.md from auto-detected preferences.
{auto_detected_preferences}
{git_strategy}

Content (<30 lines):
# Personal Preferences

## Style
{auto-detected or default: 'Direct — no fluff, lead with the answer.'}

## Workflow
- {auto-detected workflow preferences}
- Auto-format: {yes/no — based on detected formatter}

## Notes
{space for personal notes — not committed for companion/ephemeral strategies}
Edit this file to override any bootstrap defaults.

Write to CLAUDE.local.md. Return ONLY: path + 1-line summary <100 chars."
)
```

### 5. Copy Technique References

Main thread copies bootstrap technique files → `.claude/references/techniques/`.
No agent dispatch needed — simple file copy.

```bash
mkdir -p .claude/references/techniques
```

Idempotent: destination exists w/ same content → skip. Older/different → overwrite.

Copy each:
1. `techniques/INDEX.md` → `.claude/references/techniques/INDEX.md`
2. `techniques/prompt-engineering.md` → `.claude/references/techniques/prompt-engineering.md`
3. `techniques/anti-hallucination.md` → `.claude/references/techniques/anti-hallucination.md`
4. `techniques/agent-design.md` → `.claude/references/techniques/agent-design.md`
5. `techniques/token-efficiency.md` → `.claude/references/techniques/token-efficiency.md`

Remote fetch (if bootstrap repo not local):
```bash
for name in INDEX prompt-engineering anti-hallucination agent-design token-efficiency; do
  gh api repos/tomasfil/claude-bootstrap/contents/techniques/${name}.md --jq '.content' | base64 -d > .claude/references/techniques/${name}.md
done
```

### 6. Update .gitignore

Based on git_strategy from Module 01:

**track** (personal projects):
```
CLAUDE.local.md
.claude/settings.local.json
.claude/reports/
```

**companion | ephemeral** (work projects):
```
CLAUDE.md
CLAUDE.local.md
.claude/
.learnings/
```

All strategies: `.claude/reports/` (transient agent output, never tracked).

Check before adding — don't duplicate:
```bash
for entry in {entries_for_strategy}; do
  grep -qxF "$entry" .gitignore 2>/dev/null || echo "$entry" >> .gitignore
done
```

## Checkpoint

```
✅ Module 02 complete — CLAUDE.md ({N} lines), {N} rule files, CLAUDE.local.md, technique refs copied, .gitignore updated for {git_strategy}
```
