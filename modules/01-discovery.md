# Module 01 — Discover the Project

> Analyze the project environment, languages, frameworks, architecture, and user preferences.
> This module's output is consumed by ALL subsequent modules.

---

## Idempotency

Discovery is read-only — always runs fresh, no files to preserve.

## Actions

### 1. Detect the Environment (Dynamic — detected every session)

Run these commands to determine the runtime environment:

```bash
uname -s 2>/dev/null || echo Windows
echo "Shell: $SHELL"
echo "Path separator: /"  # Always / in bash, even on Windows
git rev-parse --show-toplevel 2>/dev/null || pwd
```

Record:
- OS: Windows / macOS / Linux
- Shell: bash / zsh / PowerShell
- Line endings: CRLF (Windows) / LF (Unix)
- These are DYNAMIC values — they go in the SessionStart hook, NOT in CLAUDE.md

### 2. Detect Languages and Frameworks

Scan the project for ALL languages present (not just primary):

```bash
# File extensions
find . -type f -name "*.cs" -o -name "*.ts" -o -name "*.js" -o -name "*.py" \
  -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" \
  -o -name "*.razor" -o -name "*.css" -o -name "*.html" 2>/dev/null | \
  sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
```

Read project manifests to identify frameworks and versions:
- `.sln`, `*.csproj` → .NET (check `<TargetFramework>` for version)
- `package.json` → Node.js/TypeScript (check dependencies for framework)
- `pyproject.toml`, `requirements.txt` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `Gemfile` → Ruby

For EACH detected language, record:
- Language name and version
- Framework and version
- Package manager
- Build command (verify it works: run it)
- Test command (single file + full suite)
- Lint command
- Format command

### 3. Detect Project Structure

**Multi-project detection:**
```bash
# .NET solution
find . -name "*.sln" -maxdepth 2 2>/dev/null
find . -name "*.csproj" -maxdepth 3 2>/dev/null

# Monorepo
ls package.json packages/*/package.json workspaces/*/package.json 2>/dev/null
ls lerna.json nx.json turbo.json pnpm-workspace.yaml 2>/dev/null
```

**Architecture layer mapping** (for multi-project solutions):
Read project references to identify layers:
```bash
# .NET: read ProjectReference from .csproj files
grep -r "ProjectReference" --include="*.csproj" . 2>/dev/null
```

Classify each project/package into:
- `presentation` — API endpoints, controllers, UI
- `business-logic` — services, use cases, domain logic
- `data-access` — entities, repositories, ORM configs, migrations
- `contracts` — DTOs, shared interfaces, API contracts
- `common` — helpers, constants, enums, extensions
- `client` — frontend apps (Blazor, React, etc.)
- `functions` — serverless functions, background jobs
- `tests` — test projects

### 4. Detect Pipeline Traces

Identify which files typically change together for a feature:

**Method 1 — Git co-occurrence (preferred if git history exists):**
```bash
# Find files that change together in recent commits
git log --oneline -50 --name-only --pretty=format:"---COMMIT---" | \
  awk '/---COMMIT---/{if(NR>1)for(i in files)for(j in files)if(i<j)print files[i]" + "files[j];delete files;next}{files[$0]=1}' | \
  sort | uniq -c | sort -rn | head -20
```

**Method 2 — Architecture trace (for new projects or thin git history):**
Read the architecture and manually trace a feature. For example, in a layered .NET project:
1. Adding new entity → Entity + Configuration + Migration + DTO + Mapper + Endpoints + Service + Client + UI
2. Adding field → Entity + Configuration? + Migration + DTO + Mapper
3. New endpoint → Request DTO + Response DTO + Endpoint + Service method

Record 3-5 pipeline traces that represent common feature types.

### 5. Detect Existing .claude/ Setup

```bash
ls -la .claude/ 2>/dev/null
ls -la .claude/rules/ .claude/skills/ .claude/agents/ .claude/hooks/ .claude/scripts/ 2>/dev/null
cat CLAUDE.md 2>/dev/null | head -5
cat .learnings/log.md 2>/dev/null | head -5
```

Record what exists — subsequent modules will use idempotency to handle it.

### 6. Check for Companion Repo

```bash
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
ls -la "$HOME/.claude-configs/$PROJECT_NAME/" 2>/dev/null
```

If companion config exists but `.claude/` doesn't, auto-import will happen via the user-level SessionStart hook (Module 15). Note this in the discovery output.

### 7. Ask User Preferences

Ask these questions. STOP and wait for answers before proceeding:

```
I've analyzed your project. Before I set up the environment, a few questions:

1. **Git strategy for .claude/ files:**
   A) Track in git — commit and push everything (personal projects)
   B) Gitignore + companion repo — persist privately at ~/.claude-configs/ (work projects)
   C) Gitignore + no sync — regenerate from bootstrap when needed (ephemeral)

2. **Auto-format on save?** Yes / No

3. **Block destructive SQL?** (DROP, TRUNCATE, DELETE without WHERE) Yes / No

4. **Any MCP servers to configure?** (e.g., database, JIRA, Slack — or "none")

5. **Any directories that should be read-only?** (e.g., vendor/, generated/)

```

Model selection is automatic — each agent uses the optimal model for its task complexity.
See `techniques/agent-design.md` for the decision rule. Override in CLAUDE.local.md if needed.

### 8. Output Discovery Summary

Print a structured summary for subsequent modules:

```
✅ Module 01 complete — Project discovered

Environment: {OS} / {shell}
Languages: {list with versions}
Frameworks: {list with versions}
Architecture: {type} with {N} projects/packages
Pipeline traces: {N} common patterns detected
Existing .claude/: {what exists}
Companion repo: {found / not found / N/A}
Git strategy: {track / companion / ephemeral}
Commands:
  Build: {command}
  Test (single): {command}
  Test (suite): {command}
  Lint: {command}
  Format: {command}
```
