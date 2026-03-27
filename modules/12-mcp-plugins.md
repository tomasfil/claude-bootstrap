# Module 12 — MCP Servers & Plugin Recommendations

> Configure MCP servers and recommend external plugins.
> ONLY recommend CONNECTOR plugins (LSP, MCP, docs). Methodology plugins are replaced by Module 13.

---

## Idempotency

Per config file: if .mcp.json exists, read existing servers, add missing entries from bootstrap, preserve custom entries. If missing, create from template.

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

### Detect & Suggest Uninstalling Replaced Plugins

Check if any methodology plugins from the "Do NOT Recommend" list are currently installed:

```bash
# Check installed plugins for methodology plugins that should be replaced
REPLACED_PLUGINS="superpowers claude-md-management feature-dev code-review commit-commands code-simplifier pr-review-toolkit frontend-design"

for plugin in $REPLACED_PLUGINS; do
  if cat ~/.claude/plugins/installed_plugins.json 2>/dev/null | grep -q "\"$plugin@"; then
    echo "⚠️  INSTALLED: $plugin — replaced by project-local equivalent"
  fi
done
```

For each found, present the user with:

```
The following installed plugins are now replaced by project-specific alternatives
created by this bootstrap. Keeping them active may cause conflicts (duplicate skills,
competing hooks, wasted context tokens).

⚠️  superpowers — replaced by: /brainstorm, /write-plan, /execute-plan, /tdd, /debug,
    /verify, /review + skill routing hook
⚠️  code-review — replaced by: project-code-reviewer agent (Module 18)
⚠️  commit-commands — replaced by: /commit, /pr skills
{...etc for each found}

Recommended action — disable for this project:
  claude plugins disable superpowers --scope project
  claude plugins disable code-review --scope project
  {...etc}

Or uninstall globally if you don't use them in other projects:
  claude plugins uninstall superpowers
  {...etc}

Would you like me to disable them for this project? (y/n)
```

Wait for the user's answer. If yes, run the disable commands. If no, note the potential conflicts and continue.

**IMPORTANT:** Use `disable --scope project` (not uninstall) by default — the user may use these plugins in other projects that haven't been bootstrapped yet.

### Conflict Check

If any recommended connector plugin has an agent/skill/hook name that collides with a project-local one:
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
Replaced plugins found installed: {list or "none"}
  Disabled: {list or "user declined"}
Conflicts detected: {list or "none"}
LSP prerequisites: {status}

To install recommended plugins:
  claude plugins install {plugin-name}
```
