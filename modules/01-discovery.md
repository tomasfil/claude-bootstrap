# Step 1 — Discover the Project

## 1a: Detect Environment

Gather and record:
- **OS**: `uname -s` / platform
- **Shell**: `$SHELL`, version
- **Line endings**: LF vs CRLF (check `.gitattributes`, sample files)
- **Package manager**: npm/yarn/pnpm/bun/pip/cargo/go/maven/gradle/mix/etc.
- **Path separator**: `/` vs `\`
- **Python**: `python3 --version` (needed for json-val.sh helper in Step 4)

## 1b: Detect Mode

| Mode | Signal | Action |
|------|--------|--------|
| **A — Map Existing** | Source files, package manager, build system, or git history exist | Discover and generate configs matching what exists |
| **B — Build From Scratch** | Empty dir or only README | Ask user what they're building |
| **C — Incremental Enhancement** | `.claude/` directory already exists | Audit, preserve customizations, fill gaps |

Read the appropriate mode file from the bootstrap repo: `modes/mode-{a,b,c}-*.md`

Announce the detected mode. If unsure, **ask**.

## 1c: Read Project Manifests

Scan for and read (if present):
- `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `mix.exs`, `pom.xml`, `build.gradle`, `Gemfile`, etc.
- `tsconfig.json`, `babel.config.*`, `webpack.config.*`, `vite.config.*`
- `Dockerfile`, `docker-compose.yml`, `.github/workflows/`

## 1d: Identify Commands

From manifests + config, identify the canonical commands for:
- **Build**, **Test**, **Lint**, **Typecheck**, **Format**
- Note: these populate CLAUDE.md and hooks later

## 1e: Directory Structure

Note top-level layout: `src/`, `lib/`, `test/`, `docs/`, monorepo packages, etc.

## 1f: Check Existing Config

Check for and read if present:
- `.claude/`, `CLAUDE.md`, `CLAUDE.local.md`
- `.cursorrules`, `AGENTS.md`, `.github/copilot-instructions.md`
- `.mcp.json`, `.claude/settings.json`
- Linter/formatter configs: `.eslintrc*`, `.prettierrc*`, `biome.json`, `ruff.toml`, `.rubocop.yml`, etc.

## 1g: Inventory Plugins

- Read `~/.claude/plugins/installed_plugins.json` (if exists)
- Note installed plugins and their capabilities
- Check marketplace availability: read `~/.claude/plugins/marketplace_cache.json` (if exists)
- Flag plugins relevant to detected project languages/frameworks

## 1h: Ask the User

STOP and ask:
1. Any style preferences not captured by existing linter configs?
2. MCP servers you use or want? (context7, GitHub, Sentry, etc.)
3. Workflow preferences? (PR-based, trunk-based, monorepo conventions)
4. Recommend plugins based on project signals? (list candidates with reasons)
5. Anything else Claude should know about this project?

Wait for answers before proceeding.

## Checkpoint

Print: `Step 1 complete — Project analyzed, environment detected`
Print: `Mode: {A|B|C}, Package manager: {x}, Languages: {y}, Build: {cmd}`
