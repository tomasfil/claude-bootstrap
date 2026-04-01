# Claude Bootstrap

> A modular, self-maintaining bootstrap system for Claude Code environments.

## What This Does

One-command setup that analyzes your project and generates a complete Claude Code environment:

- **18 modules** -- systematic, dependency-ordered, idempotent (safe to re-run)
- **17 skills** -- slash commands for the full development lifecycle
- **11+ agents** -- each optimized for its task type (count varies by language)
- **3 technique docs** -- reference patterns for prompt engineering, anti-hallucination, and agent design

## Quick Start

### Option 1: `gh` CLI (recommended)

Requires [GitHub CLI](https://cli.github.com/) (`gh`). This fetches the orchestrator directly from the repo API.

```bash
cd your-project
gh api repos/tomasfil/claude-bootstrap/contents/claude-bootstrap.md --jq '.content' \
  | base64 -d | claude -p "Read and execute this bootstrap prompt for the current project"
```

### Option 2: Clone and pipe

```bash
git clone https://github.com/tomasfil/claude-bootstrap.git ~/claude-bootstrap
cd your-project
cat ~/claude-bootstrap/claude-bootstrap.md | claude -p "Read and execute this bootstrap prompt for the current project"
```

### Option 3: Interactive session

Start a Claude Code session in your project directory:

```bash
cd your-project
claude
```

Then paste the following prompt:

```
Fetch https://raw.githubusercontent.com/tomasfil/claude-bootstrap/main/claude-bootstrap.md
using WebFetch, then read and execute the bootstrap prompt it contains against this project.
```

> **Why not just paste the GitHub URL?** Claude doesn't automatically know what to do with a bare URL. You need to tell it to fetch the content and execute it as a bootstrap prompt. The instructions above do exactly that.

### What happens next

Claude reads `claude-bootstrap.md` (the orchestrator), which tells it to:
1. Check if this project was previously bootstrapped (migration state detection)
2. If fresh: execute all 18 modules in order, analyzing your project and generating the full environment
3. If already bootstrapped: run only pending migrations via `/migrate-bootstrap`

The bootstrap asks a few configuration questions, then creates everything. Re-running is safe — each module handles its own idempotency: creates if missing, updates if stale, preserves if customized.

---

## Key Features

### Self-Maintaining

- **Instinct-based learning**: Corrections become confidence-scored behaviors that evolve into rules automatically
- **Automatic consolidation**: Session hooks detect when maintenance is due -- zero manual intervention
- **Silent correction capture**: Every user correction is logged and clustered for pattern promotion

### Orchestrator-First Architecture

The main thread stays lightweight. Skills dispatch to specialist agents for heavy work:

| Agent | Model | Purpose |
|-------|-------|---------|
| code-writer-{lang} | opus | Per-language code generation with framework research |
| test-writer | opus | Test writing matching project conventions |
| project-code-reviewer | opus | Deep review with pipeline trace verification |
| debugger | opus | Bug tracing and root cause analysis |
| tdd-runner | opus | Red-green-refactor cycles |
| reflector | opus | Learning analysis and rule promotion |
| plan-writer | sonnet | Implementation planning from specs |
| researcher | sonnet | Deep codebase exploration |
| verifier | sonnet | Build/test/cross-reference validation |
| consistency-checker | sonnet | Internal reference integrity |
| quick-check | haiku | Fast lookups and existence checks |

### Anti-Hallucination Built In

Every generated agent includes verification patterns from `techniques/anti-hallucination.md`:

- **Read-before-write** -- always read existing code before generating
- **Negative instructions** -- "DO NOT invent APIs that don't exist"
- **LSP grounding** -- confirm types after writing
- **Build verification** -- compile after every change
- **Pipeline trace checks** -- reviewer catches incomplete cross-layer changes

### Automatic Model Selection

Models assigned by task complexity. No user configuration needed:

- **opus**: Code generation, debugging, review (judgment-heavy)
- **sonnet**: Planning, analysis, validation (analysis-heavy)
- **haiku**: Lookups, quick checks (mechanical)

### Full Development Lifecycle

```
/brainstorm -> /write-plan -> /execute-plan -> /tdd -> /review -> /commit -> /pr
```

Plus: `/debug`, `/verify`, `/code-write`, `/coverage`, `/coverage-gaps`, `/reflect`, `/audit-file`, `/audit-memory`

### Project-Specific Generation

Not generic templates. Modules 16-18 perform live web research on your detected stack before generating agents. A code writer for a FastEndpoints project is fundamentally different from one for a Django project -- because the bootstrap researched FastEndpoints patterns, not Django patterns.

Deep codebase analysis produces:
- Pipeline traces (which files change together for a feature)
- Component classification trees
- Framework-specific idioms and security patterns
- Architecture-aware dependency rules

### Automatic Skill Routing

A `UserPromptSubmit` hook analyzes every message and invokes the right skill. Say "add a field to Division" and `/code-write` activates -- maps the pipeline trace, dispatches specialists, then auto-reviews the result.

### No Plugin Dependencies

Generates project-specific replacements for common methodology plugins:

| Replaced Plugin | Generated Alternative |
|----------------|----------------------|
| superpowers | /brainstorm, /write-plan, /execute-plan, /tdd, /debug, /verify, /review |
| claude-md-management | /reflect + /audit-memory |
| feature-dev | /code-write orchestrator + researcher agent |
| code-review | project-code-reviewer with pipeline trace checks |
| commit-commands | /commit + /pr |
| pr-review-toolkit | /review |

External connector plugins (LSP, MCP servers) are still recommended.

---

## Architecture

```
claude-bootstrap.md          <- Entry point / orchestrator
├── modules/01-18            <- Sequential setup (discovery -> code reviewer)
├── techniques/              <- Reference docs (RCCF, anti-hallucination, agent design)
└── Generated per-project:
    ├── CLAUDE.md            <- Project instructions (<120 lines)
    ├── CLAUDE.local.md      <- Personal preferences (gitignored)
    ├── .claude/
    │   ├── settings.json    <- Hooks: env detection, git guard, skill routing
    │   ├── rules/           <- Per-language code standards
    │   ├── skills/          <- 17 slash command workflows
    │   ├── agents/          <- 11+ specialist agents
    │   ├── hooks/           <- Automation scripts
    │   └── scripts/         <- Helper scripts
    ├── .learnings/          <- Self-improvement system
    └── .mcp.json            <- MCP server config (if needed)
```

## Module Overview

| # | Module | What It Creates |
|---|--------|----------------|
| 01 | Discovery | Project analysis: OS, languages, frameworks, architecture, pipeline traces |
| 02 | CLAUDE.md | Root instructions file (<120 lines, self-improvement triggers) |
| 03 | Rules | Per-language code standards in `.claude/rules/` |
| 04 | Hooks | SessionStart, PreToolUse, PreCompact hooks in settings.json |
| 05 | Reflect Skill | `/reflect` -- self-improvement engine |
| 06 | Audit Skills | `/audit-file` + `/audit-memory` -- configuration auditing |
| 07 | Write-Prompt Skill | `/write-prompt` -- prompt engineering assistant |
| 08 | Local Config | `CLAUDE.local.md` for personal preferences, .gitignore updated |
| 09 | Scoped CLAUDE.md | Per-directory instructions for monorepos (skipped if not needed) |
| 10 | Base Agents | 8 utility agents: quick-check, researcher, plan-writer, debugger, verifier, reflector, consistency-checker, tdd-runner |
| 11 | Learnings | `.learnings/` directory with instinct system and confidence scoring |
| 12 | MCP Plugins | External tool integrations and connector recommendations |
| 13 | Plugin Replacements | 9 skills replacing methodology plugins: brainstorm, write-plan, execute-plan, tdd, debug, verify, commit, pr, review |
| 14 | Verification | Full wiring validation + skill routing hook generation |
| 15 | Companion Repo | Private config sync for work projects (conditional) |
| 16 | Code Writer | `/code-write` orchestrator + per-language specialist agents (web research) |
| 17 | Test Writer | `test-writer` agent + `/coverage` and `/coverage-gaps` skills (web research) |
| 18 | Code Reviewer | `project-code-reviewer` with pipeline trace verification (web research) |

## How Self-Improvement Works

```
User correction -> .learnings/log.md (raw entry)
                -> /reflect clusters patterns
                -> Instinct created (confidence: 0.5)
                -> Reinforced by similar corrections (+0.1 each)
                -> At 0.8+ -> promoted to .claude/rules/
                -> At <0.3 -> pruned automatically
```

SessionStart hook auto-triggers `/reflect` when new learnings accumulate.

## Updating an Existing Bootstrap

If your project is already bootstrapped, you don't re-run all 18 modules. Instead:

```bash
cd your-project
claude
# then type: /migrate-bootstrap
```

Or trigger it automatically by pasting the bootstrap prompt again — migration detection kicks in.

**How state tracking works:**
- `.claude/bootstrap-state.json` tracks which migrations have been applied (`last_migration` field)
- A fresh bootstrap stamps the state at the **latest** migration (all modules already reflect current changes)
- Each subsequent migration is applied incrementally and recorded in the `applied[]` array
- Migrations are idempotent — safe to re-run if interrupted

## Git Strategy Options

| Strategy | Best For | What Happens |
|----------|----------|-------------|
| **Track in git** | Personal projects | Everything committed normally |
| **Companion repo** | Work projects | Gitignored, synced to private `~/.claude-configs/` |
| **Ephemeral** | Quick experiments | Gitignored, re-bootstrap when needed |

## Supported Stacks

Detects and adapts to any stack. Multi-language projects get per-language specialist agents.

Tested with: .NET/C#, TypeScript/JavaScript, Python, Go, Rust, Java, Ruby.

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- A project to bootstrap
- Git (recommended)

## Contributing

Issues and PRs welcome.

## License

MIT
