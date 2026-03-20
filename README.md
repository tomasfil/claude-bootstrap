# Claude Code Bootstrap v4.0

A modular, self-improving bootstrap for Claude Code projects. Sets up CLAUDE.md, rules, hooks, skills, agents, and a learning loop — then gets out of your way.

## Quick Start

```bash
# Clone this repo somewhere accessible
git clone https://github.com/tomasfil/claude-bootstrap.git ~/claude-bootstrap

# Navigate to YOUR project
cd /path/to/your-project

# Run the bootstrap
claude -p "Read ~/claude-bootstrap/claude-bootstrap.md and execute it"
```

Or from within a Claude Code session:
```
Read ~/claude-bootstrap/claude-bootstrap.md and execute it
```

## What It Creates

```
your-project/
├── CLAUDE.md                    # Project context (<120 lines, loads every session)
├── CLAUDE.local.md              # Personal preferences (gitignored)
├── .claude/
│   ├── settings.json            # Hooks configuration
│   ├── hooks/                   # Hook scripts (guard-git, detect-env, track-agent)
│   ├── scripts/                 # Helpers (json-val.sh)
│   ├── skills/                  # /reflect, /audit-file, /audit-memory, /write-prompt
│   ├── agents/                  # code-reviewer, test-writer, researcher
│   └── rules/                   # general, code-standards, shell-standards, lsp-guidance
├── .learnings/                  # Correction & discovery log for /reflect
└── .mcp.json                   # MCP servers (if applicable)
```

## Three Modes

- **Mode A** — Existing project: discovers conventions, maps them into config
- **Mode B** — From scratch: asks what you're building, creates starter setup
- **Mode C** — Upgrade: audits existing `.claude/`, adds missing pieces, preserves customizations

## Repository Structure

```
claude-bootstrap/
├── claude-bootstrap.md          # Main entry point (~130 lines)
├── modules/                     # Step-by-step instructions (read on demand)
│   ├── 01-discovery.md          # Project analysis
│   ├── 02-claude-md.md          # CLAUDE.md creation
│   ├── 03-rules.md              # Rules setup
│   ├── 04-hooks.md              # Hook system
│   ├── 05-skills.md             # Skills (reflect, audit, write-prompt)
│   ├── 06-personal.md           # CLAUDE.local.md & scoped files
│   ├── 07-agents.md             # Subagent creation
│   ├── 08-learnings.md          # .learnings/ initialization
│   ├── 09-mcp-plugins.md        # MCP & plugin setup
│   └── 10-verification.md       # Wiring verification
├── modes/                       # Mode-specific decision logic
│   ├── mode-a-existing.md
│   ├── mode-b-new.md
│   └── mode-c-upgrade.md
└── reference/                   # Detailed docs (read on demand)
    ├── hook-reference.md
    ├── agent-reference.md
    ├── skill-reference.md
    ├── plugin-reference.md
    └── lsp-reference.md
```

## Key Design Decisions

**Modular**: Each step is a separate file. Claude reads only what it needs, keeping context lean.

**Specs over templates**: Written for Claude 4.6 Opus. Provides clear specs; trusts the model to generate appropriate content rather than copy-pasting verbose templates.

**Progressive disclosure**: Reference files are only loaded when needed during setup, not frontloaded.

**Self-improving**: The bootstrap creates a feedback loop (CLAUDE.md → .learnings/ → /reflect → CLAUDE.md) that improves over time through corrections and discoveries.

## After Bootstrap

- **`/reflect`** — Review learnings, evolve agents, audit plugins
- **`/audit-file <path>`** — Check a file against code standards
- **`/audit-memory`** — Clean up memory files
- **`/write-prompt`** — Best practices for writing skills/agents

## Changes from v3.1

- Modular structure (was monolithic 1,949-line file)
- Removed outdated "150-200 instructions" claim
- Fixed compaction thresholds to match actual defaults
- Added hook exit code 1 documentation (non-blocking error)
- Added missing hook events (PreCompact, PostToolUseFailure, InstructionsLoaded, etc.)
- Added full agent frontmatter fields (memory, isolation, background, permissionMode, maxTurns, skills)
- Added skill `context: fork` documentation
- Integrated with Auto Memory system
- Added `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` documentation
- Added settings.json `$schema` reference
- Steps reduced from 14 to 10 (merged related steps)
- ~40% total line reduction leveraging Claude 4.6 capabilities
