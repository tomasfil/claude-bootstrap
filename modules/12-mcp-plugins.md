# Module 12 — MCP Servers & Plugin Recommendations

> Configure MCP servers and recommend external plugins.
> ONLY recommend CONNECTOR plugins (LSP, MCP, docs). Methodology plugins are replaced by Module 13.

---

## 1. MCP Servers

If the user requested MCP servers in Module 01, or if the project uses services that have MCP integrations, create `.mcp.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    }
  }
}
```

**Always recommend context7** — library docs lookup. Prevents hallucinated API calls.

**Detect and recommend based on project:**

| Signal | MCP Server |
|--------|-----------|
| Firebase SDK in dependencies | `firebase` MCP |
| GitHub remote | `github` MCP (if not already installed as plugin) |
| Slack integration | `slack` MCP |
| Database connection strings | Database-specific MCP |
| Jira/Linear references | `atlassian` or `linear` MCP |

## 2. Plugin Recommendations (CONNECTORS ONLY)

Check installed plugins:
```bash
cat ~/.claude/plugins/installed_plugins.json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for name in data.get('plugins', {}):
    print(name)
" 2>/dev/null || echo "No plugins file found"
```

### Recommend (external connectors — keep)

| Plugin | When to Recommend |
|--------|------------------|
| `csharp-lsp` | .cs files detected |
| `pyright-lsp` | .py files detected |
| `typescript-lsp` | .ts files detected |
| `clangd-lsp` | .c/.cpp files detected |
| `context7` | Always (library docs) |
| `security-guidance` | Always (security scanning hooks) |
| `playwright` | Browser testing / E2E tests detected |
| `firebase` | Firebase SDK in dependencies |
| `microsoft-docs` | .NET project |
| `github` | GitHub remote detected |

### Do NOT Recommend (replaced by Module 13)

| Plugin | Reason |
|--------|--------|
| `superpowers` | Replaced by project-local skills + routing hook |
| `claude-md-management` | Replaced by /reflect + /audit-memory |
| `feature-dev` | Replaced by /code-write orchestrator |
| `code-review` | Replaced by project-code-reviewer agent |
| `commit-commands` | Replaced by /commit skill |
| `code-simplifier` | Replaced by reviewer agent |
| `pr-review-toolkit` | Replaced by /pr skill |
| `frontend-design` | Replaced by code-writer-frontend specialist |

### Conflict Check

If any recommended plugin has an agent/skill/hook name that collides with a project-local one:
1. The project-local version takes precedence
2. Note the collision in the output
3. Suggest renaming if needed

### LSP Prerequisites

For each recommended LSP plugin, verify the language server binary is on PATH:
```bash
# C# — OmniSharp or csharp-ls
command -v dotnet >/dev/null 2>&1 && echo "dotnet available"

# Python — Pyright
command -v pyright >/dev/null 2>&1 || command -v npx >/dev/null 2>&1 && echo "pyright available via npx"

# TypeScript — tsserver
command -v npx >/dev/null 2>&1 && echo "tsserver available via npx"
```

If prerequisite is missing, note it in recommendations.

## Output

```
✅ Module 12 complete — MCP & Plugins

MCP servers configured: {list or "none"}
Plugins recommended (connectors): {list}
Plugins NOT recommended (replaced by project-local): {list}
Conflicts detected: {list or "none"}
LSP prerequisites: {status}

To install recommended plugins:
  claude plugins install {plugin-name}
```
