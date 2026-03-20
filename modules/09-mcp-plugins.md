# Steps 12–13 — MCP Configuration & Plugin Recommendations

## MCP Configuration (Step 12)

> Mode C: read existing `.mcp.json`, only suggest additions.

### .mcp.json Structure

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@scope/mcp-server"],
      "env": { "API_KEY": "..." }
    }
  }
}
```

### Common MCP Servers

| Server | When to add |
|--------|-------------|
| GitHub MCP | Git remote is GitHub, PR/issue workflows needed |
| Database MCP | Database connection strings in env/config |
| Slack MCP | Slack integration or notification workflows |
| JIRA MCP | JIRA project keys detected in branch names or commits |

Only suggest servers with clear project signals. Do NOT add speculatively.

---

## Plugin Recommendations (Step 13)

Parse the **local marketplace cache** only — no network calls.

### Detection Signals

Scan for:
- File extensions (`.py`, `.ts`, `.go`, etc.)
- Dependencies (`package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`)
- Config files (`.eslintrc`, `tsconfig.json`, `pytest.ini`, `docker-compose.yml`)
- Git remote URL (GitHub, GitLab, Bitbucket)
- Framework keywords in source (`React`, `FastAPI`, `Rails`, `Spring`, etc.)

### 3-Tier Matching System

#### Tier 1 — LSP (auto-recommend by file extension)

| Extension | Plugin |
|-----------|--------|
| `.py` | `pyright-lsp` |
| `.ts` / `.tsx` | `typescript-lsp` |
| `.js` / `.jsx` | `typescript-lsp` |
| `.go` | `gopls-lsp` |
| `.rs` | `rust-analyzer-lsp` |
| `.java` | `jdtls-lsp` |
| `.rb` | `solargraph-lsp` |
| `.css` / `.scss` | `css-lsp` |

#### Tier 2 — Framework/Service (keyword match)

| Signal | Plugin |
|--------|--------|
| `stripe` in deps | `stripe` |
| `supabase` in deps/config | `supabase` |
| `firebase` in deps/config | `firebase` |
| `playwright` in deps | `playwright` |
| `prisma` in deps/schema | `prisma` |
| `tailwind` in deps/config | `tailwindcss` |
| `docker-compose.yml` exists | `docker` |

#### Tier 3 — Universal (broadly useful)

Always consider: `context7`, `code-review`, `code-simplifier`, `commit-commands`, `security-guidance`, `claude-md-management`

### Filtering

- Only recommend plugins with **>5,000 installs**
- Exclude already-installed plugins
- Check for conflicts:
  - **Agent name collisions** (e.g., `code-reviewer` from superpowers)
  - **Hook overlaps** (plugins registering same hook types)
  - **Skill name conflicts**
  - **SessionStart overhead** (too many SessionStart hooks slow startup)

### Presenting Recommendations

Group by tier. Example:

```
Recommended plugins:
  Tier 1 (LSP):       typescript-lsp, pyright-lsp
  Tier 2 (Framework):  playwright, prisma
  Tier 3 (Universal):  context7, commit-commands

  Conflicts: code-review plugin would collide with code-reviewer agent
             → Resolve: prefix agent as project-code-reviewer

Which would you like to install? (comma-separated, or 'all', or 'skip')
```

**Do NOT auto-install.** Always ask the user.

### Installation Process

1. Check prerequisites (e.g., LSP plugins need language server installed)
2. Handle collisions (rename agents with `project-` prefix if needed)
3. Run `/plugin install {name}` for each selected plugin
4. Reload and test — verify plugin loads without errors
5. If LSP plugins installed, generate LSP guidance rules (refer to Step 3d in `03-rules.md`)

### Plugin Compatibility

- Verify `.claude/` directory structure matches plugin conventions
- Plugins are **pinned to a SHA** — re-install to update
- See `reference/plugin-reference.md` for full details: LSP prerequisites table, Windows spawn bug, known issues

**Checkpoints**:
- `.mcp.json` reviewed/updated (or created if needed)
- Plugin recommendations presented by tier
- User confirmed selections
- Installed plugins load without errors
- No unresolved agent/hook/skill collisions
- LSP guidance rules generated if applicable
