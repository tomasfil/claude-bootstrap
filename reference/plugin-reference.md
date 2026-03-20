# Plugin Reference

## Plugin Architecture

Plugins are installed via `/plugin install {name}@claude-plugins-official`
and are user-scoped, stored in `~/.claude/plugins/`. They extend Claude Code
with additional skills, agents, hooks, commands, and integrations.

## Plugin Manifest Capabilities

A plugin manifest can provide any combination of:

- **skills** — Slash commands and triggered behaviors
- **agents** — Specialized subagents
- **hooks** — Lifecycle event handlers
- **commands** — CLI commands
- **mcpServers** — MCP server configurations
- **outputStyles** — Custom output formatting
- **lspServers** — Language Server Protocol configurations

## Official Marketplace

Repository: `github.com/anthropics/claude-plugins-official`

## Data Locations

| File | Location | Purpose |
|------|----------|---------|
| `marketplace.json` | `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json` | Plugin registry cache |
| `install-counts-cache.json` | `~/.claude/plugins/install-counts-cache.json` | Download statistics |
| `installed_plugins.json` | `~/.claude/plugins/installed_plugins.json` | Currently installed plugins |
| Plugin cache | `~/.claude/plugins/cache/` | Cached plugin assets |
| Blocklist | `~/.claude/plugins/blocklist.json` | Blocked plugins |

## Update Model

Plugins are pinned to a git SHA at install time. There is no `update`
command. To update a plugin, re-install it:

```
/plugin install {name}@claude-plugins-official
```

## Settings Schema

Add the schema reference to settings.json for editor validation:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

## LSP Plugin Prerequisites

Each LSP plugin requires a language server binary to be installed on the
system. The plugin provides configuration; the binary provides functionality.

| Plugin | Binary | Install (macOS/Linux) | Install (Windows) | Notes |
|--------|--------|-----------------------|-------------------|-------|
| `pyright-lsp` | `pyright` | `pip install pyright` | `pip install pyright` | Use pip, not npm on Windows |
| `typescript-lsp` | `typescript-language-server` | `npm i -g typescript-language-server typescript` | `npm i -g typescript-language-server typescript` | Clear cache on issues |
| `gopls-lsp` | `gopls` | `go install golang.org/x/tools/gopls@latest` | `go install golang.org/x/tools/gopls@latest` | Fastest startup |
| `csharp-lsp` | `OmniSharp` | `dotnet tool install -g csharp-ls` | `dotnet tool install -g csharp-ls` | Needs .sln or .csproj |
| `rust-analyzer-lsp` | `rust-analyzer` | `rustup component add rust-analyzer` | `rustup component add rust-analyzer` | High memory (~500MB+) |
| `clangd-lsp` | `clangd` | `brew install llvm` / `apt install clangd` | MSYS2 or LLVM installer | Needs compile_commands.json |
| `kotlin-lsp` | `kotlin-language-server` | `brew install kotlin-language-server` | Manual build | JVM dependency |
| `php-lsp` | `intelephense` | `npm i -g intelephense` | `npm i -g intelephense` | License for premium features |
| `swift-lsp` | `sourcekit-lsp` | Included with Xcode | N/A (macOS/Linux only) | Needs Package.swift or .xcodeproj |
| `ruby-lsp` | `ruby-lsp` | `gem install ruby-lsp` | `gem install ruby-lsp` | Needs Bundler project |
| `lua-lsp` | `lua-language-server` | `brew install lua-language-server` | Download from GitHub | Needs .luarc.json |
| `jdtls-lsp` | `jdtls` | `brew install jdtls` | Download from Eclipse | Slowest startup (~8s), high memory (~1GB+) |

## Windows Spawn Bug

Node.js `spawn()` without `shell: true` cannot resolve `.cmd`/`.bat`
wrappers. This affects npm-installed language servers on Windows.

**Workarounds:**
- Use `pip` instead of `npm` for Python-based servers (pyright)
- Patch `marketplace.json` for npm-only servers by adding shell wrapper paths
- Use WSL for a more reliable experience

## Known Plugin Issues

- **LSP on Windows** — spawn() bug affects most npm-installed servers
- **pyright-lsp on Windows** — Use pip install, not npm
- **typescript-lsp cache** — Stale cache causes phantom errors; clear
  `~/.cache/typescript-language-server/` to resolve
- **superpowers SessionStart injection** — Can conflict with other
  SessionStart hooks; check for ordering issues

## Plugins vs Bootstrap Components

Plugins and bootstrap components are complementary, not competing.

| Bootstrap Component | Complementary Plugin | Relationship |
|--------------------|--------------------|--------------|
| write-prompt (skill) | superpowers / writing-skills | Plugin adds templates; skill adds workflow |
| code-reviewer (agent) | code-review | Plugin adds automated checks; agent adds deep review |
| reflect (skill) | claude-md-management | Plugin manages file; skill drives reflection process |
| hooks (settings.json) | hookify | Plugin provides hook templates; bootstrap configures them |
| bootstrap (full system) | claude-code-setup | Plugin does quick setup; bootstrap does comprehensive setup |

## Recommended Plugin Combinations

### Minimal (any project)
`context7` — library docs lookup via MCP

### Python Development
`context7` + `pyright-lsp` + `code-review`

### TypeScript / React
`context7` + `typescript-lsp` + `frontend-design` + `code-review`

### Full-Featured
`context7` + language LSP + `code-review` + `code-simplifier` + `commit-commands`

### Heavy Workflow
All of the above + `superpowers` — note: injects ~115 lines via SessionStart hook. Document workflow priority in CLAUDE.local.md if using iterate-fast workflow.
