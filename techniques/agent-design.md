# Agent Design Techniques Reference

> Referenced by bootstrap modules when generating agents and skills. Covers constraints, patterns, and templates.

---

## Subagent Constraints (Hard Rules)

These are architectural constraints in Claude Code — not suggestions:

1. **Subagents CANNOT spawn other subagents** — Agent tool is removed at spawn time
2. **Subagents CANNOT ask the user questions** — AskUserQuestion tool removed
3. **Subagents CANNOT enter plan mode** — EnterPlanMode tool removed
4. **Each subagent gets its own isolated context window** (~200K tokens)
5. **Subagent system prompt = the .md file body** (NOT the full Claude Code system prompt)
6. **On Windows, very long agent .md files may fail** via `--agents` CLI flag (8191 char limit) — use file-based agents instead

### Exception: Main-Thread Agents
When run via `claude --agent agent-name`, agents ARE the main thread and CAN:
- Spawn subagents using the Agent tool
- Restrict spawnable types: `tools: Agent(worker, researcher), Read, Bash`
- This is useful for orchestrator agents, but changes the UX

---

## Orchestrator-as-Skill Pattern (Recommended)

**Why:** Skills run in the main conversation where the Agent tool IS available. This lets the skill orchestrate specialist agents without hitting the "no nested subagents" constraint.

**Structure:**

```
.claude/skills/code-write/
├── SKILL.md                    # Orchestrator logic (~100-200 lines)
└── references/
    ├── pipeline-traces.md      # Feature-type → file mapping
    └── layer-dependencies.md   # Which layers depend on which
```

**SKILL.md Template:**

```yaml
---
name: code-write
description: >
  Use when implementing features, writing code, adding functionality,
  building components, or creating new files. Orchestrates language-specific
  code writers for cross-layer features. MUST be invoked for any code
  generation task.
---
```

```markdown
## Orchestrator Protocol

1. **Analyze the request** — what kind of feature? What layers affected?
2. **Load pipeline trace** — read references/pipeline-traces.md
3. **Map file changes** — which files need to be created/modified?
4. **Determine specialists** — which language agents needed?
5. **Check file ownership** — no two agents should edit the same file
6. **Dispatch specialists** — in dependency order (data layer first, UI last)
7. **Verify integration** — build all, run tests, check cross-layer wiring
```

---

## Agent YAML Frontmatter Template

```yaml
---
name: code-writer-dotnet
description: >
  .NET/C# code writer specialist. Use when writing C# code for FastEndpoints
  APIs, EF Core entities/configurations, services, DTOs, mappers, or any
  .cs file. Knows project conventions, DI patterns, error handling.
tools: Read, Write, Edit, Bash, Grep, Glob, LSP, WebSearch
model: sonnet
effort: medium
---
```

### Field Reference

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Lowercase, hyphens, <64 chars |
| `description` | Yes | "Pushy" — include trigger words for when to use |
| `tools` | No | Allowlist. Default: inherit all from main conversation |
| `disallowedTools` | No | Denylist. Alternative to `tools` |
| `model` | No | `haiku`, `sonnet`, `opus`. Default: inherit from parent |
| `effort` | No | `low`, `medium`, `high`, `max`. Default: inherit |
| `isolation` | No | `worktree` for isolated git worktree |
| `background` | No | **Do not use.** Always dispatch foreground. See "Foreground-Only Dispatch" section |
| `maxTurns` | No | Limit agent iterations |

### Model Selection Guidelines

Model assignment depends on the user's preference (asked in Module 01 discovery):

| Agent Purpose | Max Quality | Balanced | Cost Efficient |
|--------------|-------------|----------|----------------|
| Quick lookup / search | haiku | haiku | haiku |
| Code generation | opus | sonnet | sonnet |
| Test writing | opus | sonnet | sonnet |
| Code review | opus | sonnet | sonnet |
| Research / exploration | opus | sonnet | haiku |
| Orchestration | opus | sonnet | sonnet |

---

## Foreground-Only Dispatch (Critical)

**Always dispatch agents in foreground. Never use `run_in_background: true`.**

Background agents cannot prompt the user for permission. Any tool that requires permission approval (Write, Edit, Bash, WebSearch, WebFetch) will **silently block** a background agent forever. Even read-only tools like WebSearch require permission, making background dispatch unreliable for most agents.

Foreground agents can run in parallel — launch multiple Agent tool calls in a single message for concurrency. This gives the same performance benefit as background dispatch without the permission problem.

### Why Not Background?
1. **Permission prompts silently block** — the agent hangs, wastes tokens, returns nothing
2. **No progress visibility** — you cannot see what a background agent is doing
3. **Foreground parallel works** — multiple foreground Agent calls in one message run concurrently
4. **No real benefit** — background only helps if you need to do other work while waiting, but in practice the orchestrator should wait for agent results before proceeding

### Permission-Gated Tools (any of these block background agents)
`Write`, `Edit`, `Bash`, `NotebookEdit`, `Agent`, `WebSearch`, `WebFetch`

### Auto-Allowed Tools (never prompt)
`Read`, `Grep`, `Glob`, `LSP`

---

## Tool Restriction Patterns

### Minimal (Research Only)
```yaml
tools: Read, Grep, Glob
```
Use for: code reviewers, researchers, quick-check agents

### Standard (Code Writer)
```yaml
tools: Read, Write, Edit, Bash, Grep, Glob, LSP
```
Use for: implementation agents, test writers

### Extended (With Web Access)
```yaml
tools: Read, Write, Edit, Bash, Grep, Glob, LSP, WebSearch, WebFetch
```
Use for: agents that need to research current docs/APIs

### Orchestrator (Can Dispatch — main thread only)
```yaml
tools: Agent(code-writer-dotnet, code-writer-frontend), Read, Grep, Glob, Bash
```
Use for: main-thread orchestrator agents (via `claude --agent`)

---

## Communication Patterns

### File-Based (Most Reliable)
Agents read/write shared files. No direct messaging needed.
- Agent A writes `output-a.md`
- Agent B reads `output-a.md` as input
- Works across subagents, teams, and sessions

### Task-Based (Agent Teams Only)
Shared task list with status tracking.
- Lead creates tasks
- Workers self-assign
- Status visible to all teammates
- NOT available for regular subagents

### Sequential Chaining (Subagents)
Main conversation chains subagents:
1. Dispatch Agent A → wait for result
2. Use result to inform Agent B dispatch → wait for result
3. Synthesize both results

### Parallel Dispatch (Independent Work)
```markdown
When tasks have NO dependencies and NO shared files:
- Dispatch all specialists in a single message
- Each gets clear, complete instructions
- Each owns distinct files
- Main thread synthesizes results after all complete
```

---

## Invocation Quality (Critical)

Most subagent failures come from poor invocations, not execution failures.

### Bad Invocation
```
"Fix the Division service"
```

### Good Invocation
```
"In MyProject.Services/Data/Divisions/DivisionService.cs,
add a new method `GetActiveDivisionsForBrandAsync(Guid brandId)` that:
1. Queries divisions where BrandId == brandId AND IsActive == true
2. Uses AsNoTracking() (read-only query)
3. Returns Task<List<Division>>
4. Follows the existing pattern in GetDivisionsByBrandAsync (line 45)
5. Uses IDataService<AppDbContext>.Entity<Division, Guid>().WhereAsQueryable()

Reference files:
- Current service: Services/Data/Divisions/DivisionService.cs
- Interface: Services/Data/Divisions/IDivisionService.cs (add to interface too)
- Pattern example: Services/Data/Brands/BrandService.cs:GetActiveBrandsAsync

After implementation, run: dotnet build MyProject.Services"
```

### Invocation Checklist
Every subagent dispatch should include:
- [ ] Specific file paths
- [ ] Expected behavior / success criteria
- [ ] Reference files for pattern matching
- [ ] Build/test command to verify
- [ ] What to do if something unexpected is found

---

## Agent File Size Guidelines

| Lines | Assessment | Action |
|-------|-----------|--------|
| <100 | Too sparse | May lack context for reliable generation |
| 100-300 | Ideal | Focused, sufficient context |
| 300-500 | Acceptable | For complex projects with many component types |
| 500+ | Consider splitting | Break into agent + reference files |

For agents >300 lines, use the reference file pattern:
```
.claude/agents/code-writer-dotnet.md          # Core logic (200 lines)
.claude/agents/references/dotnet-patterns.md   # Detailed examples (300 lines)
```
Agent reads references on demand rather than having everything in the system prompt.

---

## Sources
- Claude Code Docs: sub-agents, agent-teams, tools-reference
- claudefa.st: sub-agent best practices
- OpenDev Paper (arxiv 2603.05344)
- Anthropic: Building Effective AI Agents
- lst97/claude-code-sub-agents (resource metrics)
- wshobson/agents (large-scale agent architecture)
