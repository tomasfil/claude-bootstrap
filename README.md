# Claude Code Bootstrap v5

A modular, self-improving bootstrap system for [Claude Code](https://claude.ai/code). Paste one prompt into a Claude Code session and get a fully configured, self-contained development environment with project-specific code writers, test writers, and code reviewers — all with anti-hallucination patterns built in and no external plugin dependencies.

## Quick Start

### Method 1: Run directly from GitHub (no clone needed)

```bash
cd your-project
claude
```

Then paste this into the session:

```
Fetch and execute the Claude Code bootstrap from https://github.com/tomasfil/claude-bootstrap.
Read the orchestrator at modules/01 through 18 using:
  gh api repos/tomasfil/claude-bootstrap/contents/{path} --jq '.content' | base64 -d
Execute each module in order against this project.
```

Claude will fetch the orchestrator and all 18 modules directly from GitHub — nothing to clone or download.

### Method 2: Clone and pipe

```bash
git clone https://github.com/tomasfil/claude-bootstrap.git ~/claude-bootstrap
cd your-project
cat ~/claude-bootstrap/claude-bootstrap.md | claude -p "Execute this bootstrap for the current project"
```

### Method 3: Paste into Claude Code

```bash
cd your-project
claude
# Copy the contents of claude-bootstrap.md and paste into the session
```

The bootstrap will analyze your project, ask a few configuration questions, and then create everything automatically across 18 modules.

## What It Creates

```
your-project/
├── CLAUDE.md                              # Project config (<120 lines)
├── CLAUDE.local.md                        # Personal preferences (gitignored)
├── .claude/
│   ├── settings.json                      # Hooks: env detection, git guard, skill routing
│   ├── rules/                             # Per-language code standards + anti-hallucination
│   ├── skills/                            # 14 project-specific skills
│   │   ├── code-write/                    #   Feature implementation orchestrator
│   │   ├── reflect/                       #   Self-improvement engine
│   │   ├── brainstorm/                    #   Design before build
│   │   ├── tdd/                           #   Test-driven development
│   │   ├── debug/                         #   Systematic debugging
│   │   ├── verify/                        #   Pre-completion verification
│   │   ├── commit/, pr/, review/          #   Git workflow
│   │   ├── sync/                          #   Companion repo sync
│   │   └── ...                            #   And more
│   ├── agents/                            # Project-specific agents
│   │   ├── code-writer-{lang}.md          #   Per-language code writers (sonnet)
│   │   ├── test-writer.md                 #   Test writer matching project conventions
│   │   ├── project-code-reviewer.md       #   Deep reviewer with pipeline trace checks
│   │   ├── quick-check.md                 #   Fast lookups (haiku)
│   │   └── researcher.md                  #   Deep exploration (sonnet)
│   ├── hooks/                             # Automation scripts
│   └── scripts/                           # Helper scripts
├── .learnings/                            # Self-improvement log
└── .mcp.json                              # MCP server config (if needed)
```

## Key Features

### One Bootstrap, Everything Created

A single 120-line orchestrator reads 18 independent modules that create your entire development environment. No separate bootstraps to run — paste once, get everything.

### Project-Specific Agents via Web Research

Modules 16-18 perform **live web research** on your detected stack before generating agents. The code writer for a FastEndpoints project is fundamentally different from one for a Django project — because the bootstrap researched FastEndpoints patterns, not Django patterns.

### No Plugin Dependencies

Generates project-specific replacements for 8 common plugins:

| Replaced Plugin | Project-Specific Alternative |
|----------------|------------------------------|
| superpowers | 9 skills: brainstorm, write-plan, execute-plan, tdd, debug, verify, review, etc. |
| claude-md-management | /reflect + /audit-memory skills |
| feature-dev | /code-write orchestrator + researcher agent |
| code-review | project-code-reviewer with pipeline trace verification |
| commit-commands | /commit + /pr skills |
| pr-review-toolkit | /review skill |

External **connector** plugins (LSP, MCP, security-guidance) are still recommended.

### Automatic Skill Routing

A `UserPromptSubmit` hook analyzes every message and invokes the right skill. Say "add a field to Division" and `/code-write` activates, maps the pipeline trace, dispatches specialists, then auto-reviews the result.

### Anti-Hallucination Built In

Every generated agent includes research-backed verification patterns:
- **Read-before-write** — always read existing code before generating
- **Negative instructions** — "DO NOT invent APIs that don't exist"
- **LSP verification** — confirm types after writing
- **Build verification** — compile after every change
- **Pipeline trace checks** — reviewer catches incomplete cross-layer changes

### Companion Repo Sync

Can't push `.claude/` to your work repo? Configs sync to a private companion repo:

```
~/.claude-configs/
├── project-a/    # .claude/ for project A
├── project-b/    # .claude/ for project B
```

- Auto-imports on session start when `.claude/` is missing
- Auto-exports after `/reflect` promotes learnings
- Multi-machine sync via `git push/pull`

### Self-Improvement Loop

Three triggers continuously improve the environment:

1. **User correction** → logged, promoted to rules via `/reflect`
2. **Command failure** → root cause logged, environment updated
3. **Repeated pattern** → `/reflect` creates dedicated agent

### Pipeline Trace Awareness

The code-writer orchestrator understands full feature pipelines:

```
Entity → Config → Migration → DTO → Mapper → Endpoint → Client → UI
```

The code-reviewer verifies the pipeline is complete — catches "you updated the Entity but forgot the DTO."

## Architecture

```
claude-bootstrap.md                  # Root orchestrator (120 lines)
├── modules/
│   ├── 01-discovery.md              # Project analysis + user preferences
│   ├── 02-claude-md.md              # CLAUDE.md generation
│   ├── 03-rules.md                  # Per-language code standards
│   ├── 04-hooks.md                  # Deterministic hooks (env detection, git guard, agent tracking)
│   ├── 05-07                        # Skills: reflect, audit, write-prompt
│   ├── 08-09                        # Local config, scoped CLAUDE.md files
│   ├── 10-agents.md                 # Base agents (quick-check, researcher)
│   ├── 11-learnings.md              # Self-improvement log
│   ├── 12-mcp-plugins.md            # MCP servers + connector plugin recommendations
│   ├── 13-plugin-replacements.md    # 9 skills replacing methodology plugins
│   ├── 14-verification.md           # Wiring verification + generates skill routing hook
│   ├── 15-companion-repo.md         # Companion repo sync (conditional)
│   ├── 16-code-writer.md            # Code writer agents (web research)
│   ├── 17-test-writer.md            # Test writer agent (web research)
│   └── 18-code-reviewer.md          # Code reviewer (web research)
│
└── techniques/                      # Prompt engineering reference
    ├── prompt-engineering.md         # RCCF, structured outputs, taxonomy-guided
    ├── anti-hallucination.md         # CoVe, read-before-write, verification
    └── agent-design.md              # Subagent patterns, orchestration
```

Each module is **idempotent** — run the bootstrap any time and it creates, updates, or preserves as needed.

## Git Strategy Options

| Strategy | Best For | What Happens |
|----------|----------|-------------|
| **Track in git** | Personal projects | Everything committed normally |
| **Companion repo** | Work projects | Gitignored, synced to private `~/.claude-configs/` |
| **Ephemeral** | Quick experiments | Gitignored, re-bootstrap when needed |

## Supported Stacks

Detects and adapts to any stack. Multi-language projects fully supported with per-language specialist agents.

Tested with: .NET/C#, TypeScript/JavaScript, Python, Go, Rust, Java, Ruby

## Requirements

- [Claude Code](https://claude.ai/code) (CLI, desktop app, or web)
- A project to bootstrap
- Git (recommended)

## Contributing

Issues and PRs welcome.

## License

MIT
