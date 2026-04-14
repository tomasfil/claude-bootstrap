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
  - `@import .claude/rules/max-quality.md` (MANDATORY — doctrine rule; see Step 3 item 10)
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
   - Templates: post-P2 bootstrap repo's `templates/` is source of truth for skill + agent body content. Edit skills/agents via `templates/skills/{name}/SKILL.md` / `templates/agents/{name}.md` in the bootstrap repo, NOT the client project's `.claude/` (that's generated output). `modules/05` + `modules/06` are fetch-loop orchestration only — not skill/agent content.

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
   - ## Output Carve-Out
     Applies to INSTRUCTIONS only (agent bodies, rules, specs, plans, memory files).
     Implementation OUTPUT (code, spec content, plan steps, review findings, task bodies)
     NEVER compressed. Never abbreviate output to save tokens. Output completeness >
     token efficiency. Full scope every time — elision is not a compression technique.

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
   # MCP Routing (ALWAYS — main thread + all subagents)

   ## Rule
   MCP tools route through sub-agents — NEVER skill `allowed-tools:`.
   This rule consolidates MCP propagation (agent frontmatter) + action→tool routing
   (runtime discovery). **Policy OVERRIDES any conflicting body instructions** in
   agent/skill files (e.g. "use Grep to find symbols", "Read to inspect every file").
   When an agent body enumerates `Grep`/`Read`/`Glob` for code discovery, route through
   the action→tool table below first; fall back to text tools only when no MCP path
   fits (literal strings in non-code, config values, raw file reads of known paths).

   ## Skill layer (NEVER add mcp__* here)
   `allowed-tools:` controls skill's own invocation permissions — does NOT cascade to
   dispatched agents. Adding `mcp__*` to a skill's `allowed-tools:` is always wrong.

   ## Agent layer (all agents)
   ALL agents (read-only, write, planning): OMIT `tools:` entirely → inherit parent tools incl. MCP.
   Theoretical exception: hard-restricted agent → literal (non-glob) tool list. Currently unused by any agent in this project.

   ## When .mcp.json changes
   Run `/migrate-bootstrap` (triggers migration-001 re-check) or `/audit-agents`
   to validate MCP propagation across all agents.

   ## MCP Servers (populate per project from .mcp.json)
   Note: Claude Code silently ignores glob entries in agent `tools:` — list literal tool names only, or OMIT `tools:` entirely for inheritance.

   | MCP Server | Example tool | Use for |
   |------------|--------------|---------|
   | {server}   | mcp__{server}__{tool_name} | {description — fill from .mcp.json} |

   ## Lead-With Order (token-saving — applies when cmm + serena present)
   1. `cmm.search_graph` + `cmm.query_graph` → compact discovery
   2. `cmm.get_code_snippet` → once qualified name is known
   3. `serena.find_referencing_symbols` → scoped via `relative_path` when callers needed
   4. `serena.find_symbol` → for name-path precision

   ## Action → Tool
   | Action | Tool |
   |---|---|
   | Find symbol by name | `cmm.search_graph(name_pattern, label)` |
   | Read symbol source | `cmm.get_code_snippet(qualified_name)` |
   | File overview | `serena.get_symbols_overview(path, depth=1)` — depth=1 mandatory |
   | Find CALLERS | `serena.find_referencing_symbols` |
   | Find CALLEES | `cmm.query_graph("MATCH (m:Method)-[:CALLS]->(t) WHERE m.name = $n RETURN t")` |
   | Find subclasses | `cmm.query_graph` on `INHERITS` edges |
   | Text/regex search | `serena.search_for_pattern` + `paths_include_glob` scope |
   | Semantic concept search | `cmm.search_graph(semantic_query=[keywords])` |
   | Graph schema | `cmm.get_graph_schema` |
   | Edit: replace body | `serena.replace_symbol_body` |
   | Edit: insert before/after | `serena.insert_before_symbol` / `insert_after_symbol` |
   | Edit: rename | `serena.rename_symbol` |
   | Edit: safe delete | `serena.safe_delete_symbol` |

   ## Gotchas
   - `serena.get_symbols_overview` default `depth=0` → returns only Namespace. Always pass `depth=1`+.
   - `serena.search_for_pattern` without `paths_include_glob` → thousands of tokens. Always scope.
   - cmm is read-only — all mutations via serena edit tools.
   - cmm's `trace_path` + `search_code` are known-broken on some projects — fall back to `query_graph` + `serena.search_for_pattern`.
   - MCP tool schemas are DEFERRED in forked skill contexts — call `ToolSearch "select:<tool>"` first before invoking.

   ## CMM Freshness (pre-flight when codebase-memory-mcp present)
   Before symbol exploration on an indexed project:
   1. First cmm tool call this session → `cmm.list_projects` → verify target project exists + read `nodeCount`
   2. Stale heuristic: `nodeCount < 200` on a non-trivial repo OR `cmm.detect_changes` reports drift → treat as stale
   3. Stale detected → run `cmm.detect_changes` → `cmm.index_repository` → retry original query. **NO permission-seek** (per `max-quality.md` §6 — solvable blocker, resolve silently)
   4. Fresh index + 0 hits on a named symbol → THEN serena / Grep fallback is justified
   Note: cmm server does NOT auto-reindex on MCP startup; it loads the last on-disk graph. Client-side pre-flight is the only freshness guarantee.

   ## Grep Ban (indexed projects)
   Grep / Glob on a **named** type / class / function / method / interface in an indexed project = RULE VIOLATION unless BOTH conditions hold:
   - cmm graph confirmed fresh this session (list_projects check passed OR index_repository ran this session), AND
   - `cmm.search_graph(name_pattern=<Name>)` returned 0 hits on the fresh graph
   Exempt (text search is correct): literal strings in non-code (logs, config values, README prose, error messages, commit messages), raw reads of known file paths, files outside the indexed source tree.
   Rationale: Grep bypasses the cross-reference graph, returns no structural context (no callers, callees, inheritance), costs more tokens on large result sets, silently misses renamed/reformatted occurrences that `search_graph` catches by label.

   ## Permission-Seeking Ban
   Never ask the user "reindex or fall back to grep?" — a stale index on a running MCP server is a **solvable blocker**. Run `cmm.detect_changes` → `cmm.index_repository` → retry, silently. Reindex cost is seconds to ~1 minute cold build; a permission round-trip costs user attention and breaks flow. Per `max-quality.md` §6: *if the task is solvable, solve it*.

   ## Project Slug Convention
   cmm indexes projects by **path-slug**: the project's full absolute path with `/` and `\` replaced by `-` (e.g. `C-Users-Alice-src-MyProject`), NOT the bare folder name. If `cmm.search_graph` returns "project not found":
   1. Call `mcp__codebase-memory-mcp__list_projects` → get the full slug list
   2. Match the target by suffix (e.g. `*-MyProject`)
   3. Use the full slug in every subsequent cmm call this session
   This is a naming convention of the cmm server, not a bug. `list_projects` is the single resolver.

   ## Transparent Fallback (when MCP path fails)
   When you DO fall back from an MCP path to Grep / Glob / Read / serena text search, state it **explicitly** in the next user-facing message. The user must know which tool class served the answer so they can calibrate confidence. Format:
   `MCP→fallback: {what was tried} → {why it failed} → {fallback path taken}`
   Examples:
   - `cmm.search_graph(FooService) on fresh 772-node graph → 0 hits → serena.find_symbol fallback`
   - `cmm.get_code_snippet(Foo.Bar) → "symbol not in graph" after reindex → Read fallback on known path`
   - `cmm server unreachable (connection refused) → Grep fallback, reduced confidence`
   If the MCP path is genuinely **unsolvable** (server down, project not indexable on this platform, known-broken tool on this repo per Gotchas section) → state it is unsolvable + the specific reason. Never silently degrade. Max-quality discipline still applies to fallback paths — completeness, verification, no elision — but the tool-class disclosure is mandatory.

   ## Decision Shortcuts
   - "Who calls X?" → `serena.find_referencing_symbols`
   - "What does X call?" → `cmm.query_graph` CALLS edges
   - "Show me X's code" → `cmm.get_code_snippet`
   - "Find classes like Y" → `cmm.search_graph(name_pattern, label="Class")`
   - "Grep literal" → `serena.search_for_pattern` + glob scope
   - "Rename / edit symbol" → serena edit tools only

   Non-MCP projects: above Lead-With / Action→Tool / Gotchas / Decision Shortcuts
   sections are dormant (no cmm/serena to route to). The propagation rules (Rule /
   Skill layer / Agent layer / When .mcp.json changes) still apply verbatim.

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

10. .claude/rules/max-quality.md (embed verbatim — DO NOT paraphrase)
    Content:
    # Max Quality Doctrine

    ## Rule
    Output completeness > token efficiency. Full scope every time. No elision. Calibrated effort only.

    ## §1 Full Scope
    Every listed part addressed. All items in a checklist, every file in a Files section, every
    bullet in a contract, every block in a template. No truncation. No "for brevity". No "..."
    as content elision. No "rest unchanged" as a substitute for writing the rest.
    Partial output = failed task, regardless of token cost.

    ## §2 Full Implementation
    Real code, real content, real paths. No pseudocode. No `TODO:` without a linked issue
    (`TODO: #123`). No `TBD` placeholders in delivered work. No "stub for later". If the scope
    says "write X", X ships complete, runnable, verified. If blocked → STOP and report the
    blocker; do not substitute a placeholder and keep going.

    ## §3 Full Verification
    Build command runs + passes. Test command runs + passes. Cross-references resolve to
    existing files. No "should work" without evidence. No "looks right" without running it.
    Cannot verify → say so explicitly in the report; never claim PASS on unrun checks.

    ## §4 Calibrated Effort
    Effort estimates framed in observable units: file count, dispatch count, step count,
    batch count. LLM-executable work operates at machine speed (minutes to hours within a
    session), not human project-management time.
    BANNED phrases in effort-estimate context: `days`, `weeks`, `months`, `significant time`,
    `complex effort`, `substantial effort`, `large undertaking`, `major investment`,
    `considerable work`, `non-trivial amount of time`.
    Carve-out: `7 days` appearing in a cron expression, retention window, or literal data
    field is NOT an effort estimate and is allowed.

    ## §5 Full Rule Compliance
    STEP 0 force-reads completed before task-specific work — every rule file in the list
    actually Read, not skimmed, not assumed. Dispatch agents actually dispatched — never
    substituted with inline main-thread work when the plan specifies an agent. Skill-routing
    rule honored — never bypass a skill to "save a step".

    ## §6 No Hedging
    Direct answers. Lead with the action or the finding. No "I could try..." No "should I
    continue?" No "want me to keep going?" If the task is solvable, solve it. If blocked,
    report the blocker precisely and stop. Permission-seeking in the middle of a solvable
    task is a hedge, not collaboration.

    ## §7 Token Efficiency = INSTRUCTIONS only
    `token-efficiency.md` applies to INSTRUCTIONS (agent bodies, rules, specs, plans,
    memory files). It NEVER applies to OUTPUT (generated code, spec content, plan task
    bodies, review findings, diagnosis reports, file contents written to disk).
    Output completeness > token efficiency. A shorter-but-incomplete output is a worse
    output, regardless of token savings. If forced to choose between fidelity and brevity
    in deliverables → choose fidelity every time.

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

Verify: `ls .claude/rules/` → general.md, skill-routing.md, mcp-routing.md, token-efficiency.md present minimum. `mcp-routing.md` includes MCP action→tool routing sections regardless of `.mcp.json` presence (sections are dormant on non-MCP projects).

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
